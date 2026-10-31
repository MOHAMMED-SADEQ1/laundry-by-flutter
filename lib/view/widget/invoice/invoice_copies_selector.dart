// اختيار عدد نسخ فاتورة العميل — واجهة فقط، والقيمة تُحفظ في
// `settings.invoice_copies` من الحوار الذي يستضيفه.
//
// **لماذا ودجة منفصلة:** العيب الصامت هو أن يبدو الزرّ عاملًا ثم لا تُطبَع
// النسخة الثانية. هنا نختبر الحدّين (1 و5) وأن كل نقرة تُرجع القيمة الصحيحة،
// ويبقى ربط الحفظ والطباعة في `_PaymentMethodDialog` و`InvoiceOutputService`.

import 'package:flutter/material.dart';
import 'package:laundry/core/theme/app_colors.dart';
import 'package:laundry/services/i18n/l10n.dart';

/// صفّ بسيط: «عدد نسخ الفاتورة» مع زرَّي − و+ وقيمة بينهما.
class InvoiceCopiesSelector extends StatelessWidget {
  /// القيمة الحالية (1..[max]).
  final int value;

  /// تُنادى بالقيمة الجديدة عند الضغط على − أو +.
  final ValueChanged<int> onChanged;

  /// حدود النسخ — تطابق حدود إعداد `invoice_copies` في السجل.
  final int min;
  final int max;

  const InvoiceCopiesSelector({
    super.key,
    required this.value,
    required this.onChanged,
    this.min = 1,
    this.max = 5,
  });

  /// مفاتيح قابلة للاختبار.
  static const Key minusKey = Key('invoice-copies-minus');
  static const Key plusKey = Key('invoice-copies-plus');
  static const Key valueKey = Key('invoice-copies-value');

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surfaceSoft,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.print_outlined,
            size: 16,
            color: AppColors.primary,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              tr('عدد نسخ الفاتورة'),
              style: const TextStyle(
                fontFamily: 'cairo',
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          _step(
            key: minusKey,
            icon: Icons.remove,
            enabled: value > min,
            onTap: () => onChanged(value - 1),
          ),
          SizedBox(
            key: valueKey,
            width: 30,
            child: Text(
              '$value',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'cairo',
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
          ),
          _step(
            key: plusKey,
            icon: Icons.add,
            enabled: value < max,
            onTap: () => onChanged(value + 1),
          ),
        ],
      ),
    );
  }

  Widget _step({
    required Key key,
    required IconData icon,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    return Material(
      key: key,
      color:
          enabled
              ? AppColors.primary.withValues(alpha: 0.1)
              : Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: enabled ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.all(5),
          child: Icon(
            icon,
            size: 16,
            color: enabled ? AppColors.primary : AppColors.textMuted,
          ),
        ),
      ),
    );
  }
}
