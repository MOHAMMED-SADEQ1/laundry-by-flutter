import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:laundry/core/navigation/route_dismissal.dart';
import 'package:laundry/core/theme/app_colors.dart';
import 'package:laundry/services/i18n/currency.dart';
import 'package:laundry/services/i18n/l10n.dart';
import 'package:laundry/view/widget/common/app_dialog.dart';

/// اختيار المستخدم في حوار الإرجاع.
typedef ReturnChoice = ({String reason, bool refundAsCredit});

/// حوار «إرجاع فاتورة / إشعار دائن».
///
/// يرجع `null` عند الإلغاء، وإلا خيار المستخدم. **لا يكتب شيئًا في القاعدة**
/// — كل الكتابة في `CreditNoteService.returnInvoice` بعد التأكيد، كي يبقى
/// القرار المحاسبي في طبقة واحدة قابلة للاختبار.
Future<ReturnChoice?> showInvoiceReturnDialog({
  required Map<String, dynamic> invoice,
}) {
  final invoiceId = invoice['invoices_id'];
  final total = _num(invoice['final_amount']);
  final paid = _num(invoice['paid_amount']);
  final remaining = _num(invoice['remaining_amount']);
  final hasCustomer = (invoice['customer_id'] as num?)?.toInt() != null;

  return Get.dialog<ReturnChoice>(
    Builder(
      builder: (dialogContext) {
        var refundAsCredit = hasCustomer;
        final reasonCtrl = TextEditingController();

        return StatefulBuilder(
          builder: (context, setState) => AppFormDialog(
            title: trf('إرجاع الفاتورة #{0}', [invoiceId]),
            icon: Icons.assignment_return_outlined,
            gradient: AppColors.dangerGradient,
            maxWidth: 460,
            actions: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => dismissRoute(dialogContext),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: AppColors.border),
                      foregroundColor: AppColors.textSecondary,
                    ),
                    child: Text(
                      tr('إلغاء'),
                      style: const TextStyle(fontFamily: 'cairo', fontSize: 14),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => dismissRoute(
                      dialogContext,
                      result: (
                        reason: reasonCtrl.text.trim(),
                        refundAsCredit: hasCustomer && refundAsCredit,
                      ),
                    ),
                    icon: const Icon(Icons.check, size: 18),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.danger,
                      foregroundColor: Colors.white,
                    ),
                    label: Text(
                      tr('تأكيد الإرجاع'),
                      style: const TextStyle(fontFamily: 'cairo', fontSize: 14),
                    ),
                  ),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                _SummaryRow(
                  label: tr('إجمالي الفاتورة'),
                  value: _money(total),
                  strong: true,
                ),
                _SummaryRow(label: tr('المدفوع'), value: _money(paid)),
                _SummaryRow(label: tr('المتبقي'), value: _money(remaining)),

                const SizedBox(height: 12),

                // ─── طريقة ردّ المبلغ ───
                Text(
                  tr('طريقة ردّ المبلغ'),
                  style: TextStyle(
                    fontFamily: 'cairo',
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                if (!hasCustomer)
                  _Note(
                    text: tr(
                      'الفاتورة بلا زبون — لا حساب لتقييد الرصيد، فيُردّ المبلغ نقدًا من الصندوق.',
                    ),
                  )
                else ...[
                  _ChoiceTile(
                    title: tr('رصيد للزبون (سلفة)'),
                    subtitle: tr(
                      'لا تخرج نقدية من الدرج — يُخصم الرصيد من فواتيره القادمة.',
                    ),
                    selected: refundAsCredit,
                    onTap: () => setState(() => refundAsCredit = true),
                  ),
                  const SizedBox(height: 6),
                  _ChoiceTile(
                    title: tr('نقدًا من الصندوق'),
                    subtitle: tr('يُخصم المبلغ من نقدية الوردية الحالية.'),
                    selected: !refundAsCredit,
                    onTap: () => setState(() => refundAsCredit = false),
                  ),
                ],

                const SizedBox(height: 12),

                // ─── السبب ───
                TextField(
                  controller: reasonCtrl,
                  maxLines: 2,
                  style: const TextStyle(fontFamily: 'cairo', fontSize: 13),
                  decoration: InputDecoration(
                    labelText: tr('سبب الإرجاع (اختياري)'),
                    labelStyle: const TextStyle(fontFamily: 'cairo'),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    isDense: true,
                  ),
                ),

                const SizedBox(height: 10),
                _Note(
                  text: tr(
                    'سيُنشأ إشعار دائن سالب ويُبرَّأ ما تبقّى على الفاتورة. الفاتورة الأصلية لا تُحذف ولا تُعدَّل.',
                  ),
                  color: AppColors.warning,
                  icon: Icons.info_outline,
                ),
              ],
            ),
          ),
        );
      },
    ),
    barrierColor: Colors.black54,
  );
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final bool strong;

  const _SummaryRow({
    required this.label,
    required this.value,
    this.strong = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(
              fontFamily: 'cairo',
              fontSize: strong ? 13.5 : 12.5,
              color: AppColors.textSecondary,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              fontFamily: 'cairo',
              fontSize: strong ? 14.5 : 13,
              fontWeight: strong ? FontWeight.bold : FontWeight.w600,
              color: strong ? AppColors.danger : AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _ChoiceTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  const _ChoiceTile({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color:
              selected
                  ? AppColors.primary.withValues(alpha: 0.07)
                  : AppColors.surfaceSoft,
          border: Border.all(
            color:
                selected
                    ? AppColors.primary.withValues(alpha: 0.55)
                    : AppColors.border,
            width: selected ? 1.4 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              selected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              size: 18,
              color: selected ? AppColors.primary : AppColors.textMuted,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontFamily: 'cairo',
                      fontSize: 12.5,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontFamily: 'cairo',
                      fontSize: 10.5,
                      color: AppColors.textSecondary,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Note extends StatelessWidget {
  final String text;
  final Color color;
  final IconData icon;

  const _Note({
    required this.text,
    this.color = AppColors.textSecondary,
    this.icon = Icons.lock_outline,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontFamily: 'cairo',
                fontSize: 11,
                color: color,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

double _num(dynamic v) {
  if (v is num) return v.toDouble();
  return double.tryParse('${v ?? ''}') ?? 0.0;
}

String _money(double v) => '${v.toStringAsFixed(2)} ${Currency.symbol}';
