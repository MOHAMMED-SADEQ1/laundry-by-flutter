import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:laundry/controller/previousinvoicecontroller.dart';
import 'package:laundry/controller/printInvoicecontroller.dart';
import 'package:laundry/controller/shift_controller.dart';
import 'package:laundry/core/theme/app_colors.dart';
import 'package:laundry/view/widget/common/animation_wrappers.dart';
import 'package:laundry/view/widget/common/common_widgets.dart';
import 'package:laundry/view/widget/customappbar.dart';

class ShiftsHistoryScreen extends StatelessWidget {
  const ShiftsHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ShiftController controller = Get.put(ShiftController());
    controller.fetchClosedShifts();

    return Scaffold(
      appBar: CustomAppbar(
        title: "سجل الورديات",
        subtitle: 'الورديات المغلقة وملخصاتها المالية',
      ),
      body: Obx(() {
        if (controller.isLoadingShifts.value) {
          return const Center(child: CircularProgressIndicator(strokeWidth: 3));
        }
        if (controller.closedShifts.isEmpty) {
          return const EmptyState(
            icon: Icons.history_outlined,
            title: "لا توجد ورديات سابقة",
            subtitle: 'ستظهر هنا الورديات بعد إغلاقها من القائمة الجانبية',
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(14),
          itemCount: controller.closedShifts.length,
          itemBuilder: (context, index) {
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
                            'وردية رقم ${shift['shift_id']}',
                            style: const TextStyle(
                              fontFamily: 'cairo',
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            tooltip: 'عرض فواتير الوردية',
                            onPressed:
                                () => _showShiftInvoices(controller, shift),
                            icon: const Icon(
                              Icons.receipt_long_outlined,
                              color: Colors.white,
                              size: 19,
                            ),
                          ),
                          IconButton(
                            tooltip: 'طباعة الملخص',
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
                                  'البداية',
                                  startTime,
                                ),
                              ),
                              Expanded(
                                child: _timeRow(
                                  Icons.stop,
                                  'النهاية',
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
                                  label: 'كاش',
                                  value: cash,
                                  color: AppColors.success,
                                  icon: Icons.payments_outlined,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _moneyBox(
                                  label: 'شبكة',
                                  value: network,
                                  color: AppColors.info,
                                  icon: Icons.credit_card,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _moneyBox(
                                  label: 'الفواتير',
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
                                const Text(
                                  'إجمالي الوردية',
                                  style: TextStyle(
                                    fontFamily: 'cairo',
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                Text(
                                  '${(cash + network).toStringAsFixed(2)} ر.س',
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
                      const Text(
                        'فواتير الوردية',
                        style: TextStyle(
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
                        tooltip: 'إغلاق',
                      ),
                    ],
                  ),
                  Text(
                    'الوردية رقم ${shift['shift_id']}',
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
                              'لا توجد فواتير في هذه الوردية',
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
    final isCash = invoice['payment_method'] == 'كاش';
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
                      : 'عميل نقدي',
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
                        ? '${listdata.first['vestments']} — ${listdata.first['content']}'
                        : '${listdata.first['vestments']} و ${listdata.length - 1} أصناف أخرى',
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
            text: invoice['payment_method']?.toString() ?? 'كاش',
            color: color,
            icon: isCash ? Icons.payments : Icons.credit_card,
          ),
          const SizedBox(width: 6),
          Text(
            '${paid.toStringAsFixed(2)} ر.س',
            style: TextStyle(
              fontFamily: 'cairo',
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            tooltip: 'إعادة طباعة',
            onPressed: () => _reprintInvoice(mapdata, listdata),
            icon: Icon(Icons.print_outlined, color: AppColors.info, size: 20),
          ),
        ],
      ),
    );
  }

  void _reprintInvoice(
    Map<String, dynamic>? mapdata,
    List<Map<String, dynamic>> listdata,
  ) {
    if (mapdata == null) {
      Get.snackbar('خطأ', 'بيانات الفاتورة غير مكتملة');
      return;
    }
    final data = {
      'payment': mapdata['payment'],
      'logoImage': PrintInvoiceController.logoImageBytes!,
      'riyalImage': PrintInvoiceController.riyalImageBytes!,
      'arabicFont': PrintInvoiceController.arabicFont!,
      'invoiceItems': listdata,
      'summation': mapdata['summation'],
      'invoiceNumber': invoice['invoices_id'],
      'customername': mapdata['customername'],
      'date': mapdata['date'],
    };
    final printCtrl =
        Get.isRegistered<PreviousInvoiceController>()
            ? Get.find<PreviousInvoiceController>()
            : Get.put(PreviousInvoiceController());
    printCtrl.printPDF(data);
  }
}
