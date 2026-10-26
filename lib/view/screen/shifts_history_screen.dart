import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:laundry/controller/previousinvoicecontroller.dart';
import 'package:laundry/controller/shift_controller.dart';
import 'package:laundry/core/theme/app_colors.dart';
import 'package:laundry/services/i18n/l10n.dart';
import 'package:laundry/services/payment/payment_method.dart';
import 'package:laundry/view/widget/common/animation_wrappers.dart';
import 'package:laundry/view/widget/common/common_widgets.dart';
import 'package:laundry/view/widget/common/developer_credit.dart';
import 'package:laundry/view/widget/customappbar.dart';

class ShiftsHistoryScreen extends StatelessWidget {
  const ShiftsHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ShiftController controller = Get.put(ShiftController());
    controller.fetchClosedShifts();

    return Scaffold(
      appBar: CustomAppbar(
        title: tr('سجل الورديات'),
        subtitle: tr('الورديات المغلقة وملخصاتها المالية'),
      ),
      body: Obx(() {
        if (controller.isLoadingShifts.value) {
          return const Center(child: CircularProgressIndicator(strokeWidth: 3));
        }
        if (controller.closedShifts.isEmpty) {
          return EmptyState(
            icon: Icons.history_outlined,
            title: tr('لا توجد ورديات سابقة'),
            subtitle: tr('ستظهر هنا الورديات بعد إغلاقها من القائمة الجانبية'),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(14),
          // عنصر أخير إضافي = حقوق المطوّر أسفل سجل الورديات
          itemCount: controller.closedShifts.length + 1,
          itemBuilder: (context, index) {
            if (index == controller.closedShifts.length) {
              return const DeveloperCredit(
                fontSize: 12,
                padding: EdgeInsets.only(top: 18, bottom: 8),
              );
            }
            final shift = controller.closedShifts[index];
            final startTime = DateFormat(
              'yyyy-MM-dd hh:mm a',
            ).format(DateTime.parse(shift['start_time']));
            final endTime =
                shift['end_time'] != null
                    ? DateFormat(
                      'yyyy-MM-dd hh:mm a',
                    ).format(DateTime.parse(shift['end_time']))
                    : '—';
            final cash = (shift['total_cash'] ?? 0).toDouble();
            final network = (shift['total_network'] ?? 0).toDouble();
            final count = shift['invoice_count'] ?? 0;

            return FadeInUp(
              delayMs: (index % 10) * 50,
              child: SoftCard(
                margin: const EdgeInsets.symmetric(vertical: 6),
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    // ─── الرأس ───
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: const BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(16),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.timelapse,
                            color: Colors.white,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            trf('وردية رقم {0}', ['${shift['shift_id']}']),
                            style: const TextStyle(
                              fontFamily: 'cairo',
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            tooltip: tr('عرض فواتير الوردية'),
                            onPressed:
                                () => _showShiftInvoices(controller, shift),
                            icon: const Icon(
                              Icons.receipt_long_outlined,
                              color: Colors.white,
                              size: 19,
                            ),
                          ),
                          IconButton(
                            tooltip: tr('طباعة الملخص'),
                            onPressed: () => controller.printShift(shift),
                            icon: const Icon(
                              Icons.print_outlined,
                              color: Colors.white,
                              size: 19,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: _timeRow(
                                  Icons.play_arrow,
                                  tr('البداية'),
                                  startTime,
                                ),
                              ),
                              Expanded(
                                child: _timeRow(
                                  Icons.stop,
                                  tr('النهاية'),
                                  endTime,
                                  invert: true,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _moneyBox(
                                  label: PaymentMethod.cash.label,
                                  value: cash,
                                  color: AppColors.success,
                                  icon: Icons.payments_outlined,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _moneyBox(
                                  label: PaymentMethod.card.label,
                                  value: network,
                                  color: AppColors.info,
                                  icon: Icons.credit_card,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _moneyBox(
                                  label: tr('الفواتير'),
                                  value: count.toDouble(),
                                  color: AppColors.warning,
                                  icon: Icons.receipt_long,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          // ─── الإجمالي ───
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              gradient: AppColors.primaryGradient,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  tr('إجمالي الوردية'),
                                  style: const TextStyle(
                                    fontFamily: 'cairo',
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                Text(
                                  trf('{0} ر.س', [
                                    (cash + network).toStringAsFixed(2),
                                  ]),
                                  style: const TextStyle(
                                    fontFamily: 'cairo',
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          // ─── جرد الدرج (الجزء المخزَّن عند الإقفال) ───
                          _stocktakeBox(shift),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      }),
    );
  }

  Widget _timeRow(
    IconData icon,
    String label,
    String time, {
    bool invert = false,
  }) {
    return Row(
      mainAxisAlignment:
          invert ? MainAxisAlignment.end : MainAxisAlignment.start,
      children: [
        Icon(icon, size: 14, color: AppColors.textMuted),
        const SizedBox(width: 5),
        Column(
          crossAxisAlignment:
              invert ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontFamily: 'cairo',
                fontSize: 10,
                color: AppColors.textMuted,
              ),
            ),
            Text(
              time,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'cairo',
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// صندوق جرد الدرج للوردية المقفَلة.
  ///
  /// `expected` **مشتق** من المخزَّن: `counted − difference` (لأن
  /// `difference = counted − expected`). لم نخزّن «المتوقع» مباشرةً لأن
  /// إعادة حسابه من الحركات قد تتغيّر مع أي تعديل لاحق، بينما لقطة الإقفال
  /// يجب أن تبقى ثابتة. والفرق بين «أُقفل بلا جرد» (counted = null) و
  /// «جُرِد وطابق» (difference = 0) معلومة حقيقية لا تُدمج.
  Widget _stocktakeBox(Map<String, dynamic> shift) {
    final counted = (shift['counted_cash'] as num?)?.toDouble();
    final difference = (shift['cash_difference'] as num?)?.toDouble() ?? 0.0;
    final reason = '${shift['difference_reason'] ?? ''}'.trim();

    if (counted == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.warning.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.help_outline, size: 16, color: AppColors.warning),
            const SizedBox(width: 8),
            Text(
              tr('أُقفلت بلا جرد للدرج'),
              style: TextStyle(
                fontFamily: 'cairo',
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.warning,
              ),
            ),
          ],
        ),
      );
    }

    final expected = counted - difference;
    final balanced = difference.abs() < 0.01;
    final color = balanced
        ? AppColors.success
        : (difference > 0 ? AppColors.info : AppColors.danger);
    final diffLabel = balanced
        ? tr('مطابق')
        : difference > 0
        ? trf('زيادة {0}', [difference.toStringAsFixed(2)])
        : trf('عجز {0}', [difference.abs().toStringAsFixed(2)]);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.calculate_outlined, size: 16, color: color),
              const SizedBox(width: 8),
              Text(
                tr('جرد الدرج'),
                style: TextStyle(
                  fontFamily: 'cairo',
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Text(
                diffLabel,
                style: TextStyle(
                  fontFamily: 'cairo',
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Text(
                  trf('المتوقع: {0}', [expected.toStringAsFixed(2)]),
                  style: TextStyle(
                    fontFamily: 'cairo',
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  trf('المعدود: {0}', [counted.toStringAsFixed(2)]),
                  textAlign: TextAlign.end,
                  style: TextStyle(
                    fontFamily: 'cairo',
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          if (reason.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              trf('السبب: {0}', [reason]),
              style: TextStyle(
                fontFamily: 'cairo',
                fontSize: 11,
                color: AppColors.textMuted,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _moneyBox({
    required String label,
    required double value,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(height: 5),
          Text(
            value.toStringAsFixed(1),
            style: TextStyle(
              fontFamily: 'cairo',
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'cairo',
              fontSize: 10,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

/// فتح حوار يعرض فواتير الوردية
void _showShiftInvoices(
  ShiftController shiftController,
  Map<String, dynamic> shift,
) {
  Get.dialog(
    Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 520),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: const BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.receipt_long,
                        color: Colors.white,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        tr('فواتير الوردية'),
                        style: const TextStyle(
                          fontFamily: 'cairo',
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () => Get.back(),
                        icon: const Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 20,
                        ),
                        tooltip: tr('إغلاق'),
                      ),
                    ],
                  ),
                  Text(
                    trf('الوردية رقم {0}', ['${shift['shift_id']}']),
                    style: TextStyle(
                      fontFamily: 'cairo',
                      fontSize: 11.5,
                      color: Colors.white.withValues(alpha: 0.85),
                    ),
                  ),
                ],
              ),
            ),
            Flexible(
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: shiftController.fetchShiftInvoices(shift['shift_id']),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.all(30),
                      child: Center(
                        child: CircularProgressIndicator(strokeWidth: 3),
                      ),
                    );
                  }
                  final invoices = snapshot.data ?? [];
                  if (invoices.isEmpty) {
                    return Padding(
                      padding: EdgeInsets.all(30),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.receipt_long_outlined,
                              size: 40,
                              color: AppColors.border,
                            ),
                            SizedBox(height: 8),
                            Text(
                              tr('لا توجد فواتير في هذه الوردية'),
                              style: TextStyle(
                                fontFamily: 'cairo',
                                fontSize: 13,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.all(10),
                    itemCount: invoices.length,
                    itemBuilder:
                        (context, i) => _ShiftInvoiceRow(invoice: invoices[i]),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    ),
    barrierColor: Colors.black54,
  );
}

/// صف فاتورة داخل حوار الوردية مع إعادة الطباعة
class _ShiftInvoiceRow extends StatelessWidget {
  final Map<String, dynamic> invoice;
  const _ShiftInvoiceRow({required this.invoice});

  @override
  Widget build(BuildContext context) {
    final paid = (invoice['paid_amount'] ?? 0).toDouble();
    final method = invoice['payment_method']?.toString() ?? PaymentMethod.cash.key;
    final isCash = PaymentMethods.isCash(method);
    final color = isCash ? AppColors.success : AppColors.info;

    Map<String, dynamic>? mapdata;
    List<Map<String, dynamic>> listdata = [];
    try {
      mapdata = json.decode(invoice['map_data']) as Map<String, dynamic>;
    } catch (_) {}
    try {
      listdata = List<Map<String, dynamic>>.from(
        json.decode(invoice['list_data']),
      );
    } catch (_) {}

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceSoft,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Text(
              '#${invoice['invoices_id']}',
              style: const TextStyle(
                fontFamily: 'cairo',
                fontSize: 11.5,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  invoice['customer_name']?.toString().isNotEmpty == true
                      ? invoice['customer_name']
                      : tr('عميل نقدي'),
                  style: TextStyle(
                    fontFamily: 'cairo',
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  mapdata?['date'] ?? '',
                  style: TextStyle(
                    fontFamily: 'cairo',
                    fontSize: 10.5,
                    color: AppColors.textMuted,
                  ),
                ),
                if (listdata.isNotEmpty)
                  Text(
                    listdata.length == 1
                        ? '${localized(listdata.first, 'vestments')} — ${localized(listdata.first, 'content')}'
                        : trf('{0} و {1} أصناف أخرى', [
                            localized(listdata.first, 'vestments'),
                            '${listdata.length - 1}',
                          ]),
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'cairo',
                      fontSize: 10.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          LabelChip(
            text: PaymentMethods.label(method),
            color: color,
            icon: isCash ? Icons.payments : Icons.credit_card,
          ),
          const SizedBox(width: 6),
          Text(
            trf('{0} ر.س', [paid.toStringAsFixed(2)]),
            style: TextStyle(
              fontFamily: 'cairo',
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            tooltip: tr('إعادة طباعة'),
            onPressed: _reprintInvoice,
            icon: Icon(Icons.print_outlined, color: AppColors.info, size: 20),
          ),
        ],
      ),
    );
  }

  Future<void> _reprintInvoice() async {
    // الصفّ المخزَّن نفسه يُمرَّر كاملًا، فيُبنى منه كل شيء: المقاس والهاتف
    // ورمز الاستلام والضريبة ولقطة الأصناف — وورقة المغسلة معه إن كانت
    // مفعّلة، بدل حمولة عرض ناقصة تُنتج فاتورة بلا تفاصيل.
    final printCtrl =
        Get.isRegistered<PreviousInvoiceController>()
            ? Get.find<PreviousInvoiceController>()
            : Get.put(PreviousInvoiceController());
    await printCtrl.printInvoice(invoice);
  }
}
