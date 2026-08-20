import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:laundry/controller/subscriptions_controller.dart';
import 'package:laundry/core/theme/app_colors.dart';
import 'package:laundry/view/widget/common/animation_wrappers.dart';
import 'package:laundry/view/widget/common/common_widgets.dart';
import 'package:laundry/view/widget/customappbar.dart';

/// شاشة الاشتراكات الشهرية للزبائن
class SubscriptionsScreen extends StatelessWidget {
  const SubscriptionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(SubscriptionsController());

    return Scaffold(
      appBar: CustomAppbar(
        title: 'الاشتراكات الشهرية',
        subtitle: 'متابعة فواتير الاشتراكات واستحقاقاتها',
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFF8FAFC), AppColors.background],
          ),
        ),
        child: Obx(() {
          if (controller.isLoading.value && controller.subscriptions.isEmpty) {
            return const Center(
              child: CircularProgressIndicator(strokeWidth: 3),
            );
          }
          if (controller.subscriptions.isEmpty) {
            return EmptyState(
              icon: Icons.card_membership,
              title: 'لا توجد اشتراكات',
              subtitle: 'اضغط زر + لإضافة اشتراك لزبون محدد',
            );
          }
          // ─── ملخص ───
          final overdue =
              controller.subscriptions
                  .where((s) => controller.isOverdue(s))
                  .toList();
          final active = controller.subscriptions.length;
          final monthlyTotal = controller.subscriptions.fold<double>(
            0,
            (sum, s) => sum + (s['amount'] ?? 0).toDouble(),
          );

          return Column(
            children: [
Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
                child: Row(
                  children: [
                    _MiniStat(
                      label: 'اشتراكات نشطة',
                      value: '$active',
                      color: AppColors.info,
                    ),
                    const SizedBox(width: 8),
                    _MiniStat(
                      label: 'مستحقات متأخرة',
                      value: '${overdue.length}',
                      color: AppColors.danger,
                    ),
                    const SizedBox(width: 8),
                    _MiniStat(
                      label: 'إيراد الشهر المقطوع',
                      value: monthlyTotal.toStringAsFixed(0),
                      color: AppColors.success,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(42),
                    side: BorderSide(
                      color: AppColors.primary.withValues(alpha: 0.5),
                    ),
                  ),
                  onPressed: () => _showStudyDialog(controller),
                  icon: const Icon(Icons.assessment, size: 17),
                  label: const Text(
                    'دراسة نهاية الشهر',
                    style: TextStyle(fontFamily: 'cairo', fontSize: 12.5),
                  ),
                ),
              ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: controller.loadSubscriptions,
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(14, 8, 14, 90),
                    itemCount: controller.subscriptions.length,
                    itemBuilder: (context, i) {
                      final sub = controller.subscriptions[i];
                      return FadeInUp(
                        delayMs: (i % 10) * 40,
                        child: _SubscriptionCard(
                          controller: controller,
                          sub: sub,
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          );
        }),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddDialog(controller),
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          'اشتراك جديد',
          style: TextStyle(
            fontFamily: 'cairo',
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  /// حوار دراسة نهاية الشهر — ملخص كامل للاشتراكات
  void _showStudyDialog(SubscriptionsController controller) {
    final rows = controller.monthStudy();
    double totalPaid = 0;
    int totalPieces = 0;
    for (final r in rows) {
      totalPaid += (r['paid_this_month'] ?? 0).toDouble();
      totalPieces += (r['pieces'] ?? 0) as int;
    }

    Get.dialog(
      Dialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560, maxHeight: 640),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 12),
                decoration: const BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.assessment,
                      color: Colors.white,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'دراسة نهاية الشهر — ${DateFormat('yyyy-MM').format(DateTime.now())}',
                        style: const TextStyle(
                          fontFamily: 'cairo',
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Get.back(),
                      icon: const Icon(Icons.close, color: Colors.white),
                    ),
                  ],
                ),
              ),
              // الملخص
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
                child: Row(
                  children: [
                    _MiniStat(
                      label: 'اشتراكات نشطة',
                      value: '${rows.length}',
                      color: AppColors.info,
                    ),
                    const SizedBox(width: 8),
                    _MiniStat(
                      label: 'قطع الغسيل',
                      value: '$totalPieces',
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 8),
                    _MiniStat(
                      label: 'مدفوع هذا الشهر',
                      value: totalPaid.toStringAsFixed(0),
                      color: AppColors.success,
                    ),
                  ],
                ),
              ),
              const Divider(height: 18),
              // الجدول
              Flexible(
                child: rows.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(28),
                        child: Text(
                          'لا توجد اشتراكات نشطة',
                          style: TextStyle(
                            fontFamily: 'cairo',
                            fontSize: 13,
                            color: AppColors.textMuted,
                          ),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(14, 0, 14, 18),
                        itemCount: rows.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, i) {
                          final r = rows[i];
                          final overdue = (r['status'] as String) == 'متأخر';
                          return Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceSoft,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: overdue
                                    ? AppColors.danger.withValues(alpha: 0.3)
                                    : AppColors.border,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        '${r['customer_name']}',
                                        style: TextStyle(
                                          fontFamily: 'cairo',
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                    ),
                                    LabelChip(
                                      text: r['status'] as String,
                                      color: overdue
                                          ? AppColors.danger
                                          : AppColors.success,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  'الاشتراك: ${r['price'].toStringAsFixed(0)} ر.س / '
                                  '${r['period_days']} يوم — يغطي حتى '
                                  '${DateFormat('yyyy-MM-dd').format(r['paid_until'] as DateTime)}',
                                  style: TextStyle(
                                    fontFamily: 'cairo',
                                    fontSize: 10.5,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'قطع الغسيل: ${r['pieces']} قطعة — مدفوع هذا الشهر: '
                                  '${r['paid_this_month'].toStringAsFixed(2)} ر.س',
                                  style: TextStyle(
                                    fontFamily: 'cairo',
                                    fontSize: 10.5,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                if ('${r['top_pieces']}'.trim().isNotEmpty) ...[
                                  const SizedBox(height: 3),
                                  Text(
                                    'الأصناف: ${r['top_pieces']}',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontFamily: 'cairo',
                                      fontSize: 10,
                                      color: AppColors.textMuted,
                                    ),
                                  ),
                                ],
                              ],
                            ),
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

  void _showAddDialog(SubscriptionsController controller) {
    final nameCtrl = TextEditingController();
    final amountCtrl = TextEditingController(text: '50');
    final periodCtrl = TextEditingController(text: '30');
    int? selectedId;
    String selectedName = '';

    Get.dialog(
      Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'إضافة اشتراك شهري',
                style: TextStyle(
                  fontFamily: 'cairo',
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 14),
              // اختيار الزبون
              DropdownButtonFormField<int>(
                initialValue: selectedId,
                isExpanded: true,
                hint: const Text(
                  'اختر الزبون...',
                  style: TextStyle(fontFamily: 'cairo', fontSize: 12.5),
                ),
                items:
                    controller.customers
                        .map(
                          (c) => DropdownMenuItem<int>(
                            value: c['customer_id'],
                            child: Text(
                              '${c['customer_name']}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontFamily: 'cairo',
                                fontSize: 12.5,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                onChanged: (v) {
                  selectedId = v;
                  final c = controller.customers.firstWhere(
                    (x) => x['customer_id'] == v,
                  );
                  selectedName = c['customer_name']?.toString() ?? '';
                  nameCtrl.text = selectedName;
                },
                decoration: InputDecoration(
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  prefixIcon: const Icon(
                    Icons.person_search,
                    size: 18,
                    color: AppColors.primary,
                  ),
                  filled: true,
                  fillColor: AppColors.surfaceSoft,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppColors.border),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: nameCtrl,
                      enabled: false,
                      decoration: const InputDecoration(
                        labelText: 'اسم الزبون (من السجل)',
                        labelStyle: TextStyle(
                          fontFamily: 'cairo',
                          fontSize: 12,
                        ),
                        isDense: true,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: amountCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'المبلغ الشهري (ر.س)',
                        labelStyle: TextStyle(
                          fontFamily: 'cairo',
                          fontSize: 12,
                        ),
                        isDense: true,
                        prefixIcon: Icon(Icons.payments, size: 18),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: periodCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'المدة بالأيام',
                        labelStyle: TextStyle(
                          fontFamily: 'cairo',
                          fontSize: 12,
                        ),
                        isDense: true,
                        prefixIcon: Icon(Icons.calendar_month, size: 18),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Get.back(),
                      child: const Text(
                        'إلغاء',
                        style: TextStyle(fontFamily: 'cairo'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                      ),
                      onPressed: () async {
                        if (selectedId == null) {
                          Get.snackbar(
                            'تنبيه',
                            'يجب اختيار زبون من سجل الزبائن',
                            snackPosition: SnackPosition.BOTTOM,
                            backgroundColor: AppColors.warning,
                            colorText: Colors.white,
                          );
                          return;
                        }
                        final amount =
                            double.tryParse(
                              amountCtrl.text.replaceAll(',', '.'),
                            ) ??
                            0;
                        final period = int.tryParse(periodCtrl.text) ?? 30;
                        if (amount <= 0) {
                          Get.snackbar(
                            'تنبيه',
                            'أدخل مبلغاً صحيحاً',
                            snackPosition: SnackPosition.BOTTOM,
                            backgroundColor: AppColors.warning,
                            colorText: Colors.white,
                          );
                          return;
                        }
                        await controller.addSubscription(
                          customerId: selectedId!,
                          customerName:
                              selectedName.isEmpty
                                  ? nameCtrl.text.trim()
                                  : selectedName,
                          amount: amount,
                          periodDays: period,
                        );
                        Get.back();
                      },
                      child: const Text(
                        'إضافة الاشتراك',
                        style: TextStyle(
                          fontFamily: 'cairo',
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      barrierColor: Colors.black54,
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _MiniStat({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontFamily: 'cairo',
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'cairo',
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SubscriptionCard extends StatelessWidget {
  final SubscriptionsController controller;
  final Map<String, dynamic> sub;
  const _SubscriptionCard({required this.controller, required this.sub});

  @override
  Widget build(BuildContext context) {
    final amount = (sub['amount'] ?? 0).toDouble();
    final days = controller.daysRemaining(sub);
    final hasPaid = controller.hasPayment(sub);
    final overdue = !hasPaid || days < 0;
    final statusColor =
        hasPaid && !overdue
            ? days <= 7
                  ? AppColors.warning
                  : AppColors.success
            : AppColors.danger;
    final statusText =
        !hasPaid
            ? 'لم يُسدد بعد'
            : overdue
            ? 'متأخر عن السداد'
            : days <= 7
            ? 'سداد قريب ($days يوم)'
            : 'نشط ($days يوم)';

    return SoftCard(
      margin: const EdgeInsets.symmetric(vertical: 5),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.card_membership,
                  color: Colors.white,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${sub['customer_name']}',
                      style: TextStyle(
                        fontFamily: 'cairo',
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      'اشتراك #${sub['subscription_id']} — $amount ر.س / ${sub['period_days']} يوم',
                      style: TextStyle(
                        fontFamily: 'cairo',
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              LabelChip(
                text: statusText,
                color: statusColor,
                icon: overdue ? Icons.error_outline : Icons.verified_user,
              ),
            ],
          ),
          if (sub['notes'] != null && '${sub['notes']}'.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              '${sub['notes']}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'cairo',
                fontSize: 10.5,
                color: AppColors.textMuted,
              ),
            ),
          ],
          const SizedBox(height: 10),
          // ─── قطع الغسيل ودفعات الشهر ───
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.surfaceSoft,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.local_laundry_service,
                      size: 14,
                      color: AppColors.info,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'قطع الغسيل في آخر فترة: ${sub['pieces_count'] ?? 0} قطعة',
                        style: const TextStyle(
                          fontFamily: 'cairo',
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
                if (sub['top_pieces'] != null &&
                    '${sub['top_pieces']}'.trim().isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    '${sub['top_pieces']}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'cairo',
                      fontSize: 10,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
                const SizedBox(height: 5),
                Row(
                  children: [
                    const Icon(
                      Icons.payments,
                      size: 14,
                      color: AppColors.success,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'مدفوع هذا الشهر: ${(sub['paid_this_month'] ?? 0).toStringAsFixed(2)} ر.س',
                        style: const TextStyle(
                          fontFamily: 'cairo',
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _ActionBtn(
                  label: 'تسجيل دفعة',
                  icon: Icons.payment_rounded,
                  color: AppColors.success,
                  onTap: () => _showPaymentDialog(controller, sub),
                ),
              ),
              const SizedBox(width: 8),
              _ActionBtn(
                label: 'إلغاء',
                icon: Icons.close,
                color: AppColors.danger,
                onTap: () {
                  Get.defaultDialog(
                    title: 'إلغاء الاشتراك؟',
                    middleText: 'سيتم تعطيل اشتراك ${sub['customer_name']}',
                    textConfirm: 'إلغاء الاشتراك',
                    textCancel: 'تراجع',
                    confirmTextColor: Colors.white,
                    buttonColor: AppColors.danger,
                    onConfirm: () {
                      Get.back();
                      controller.cancel(sub['subscription_id']);
                    },
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─────────────────────── حوار تسجيل دفعة ───────────────────────

  void _showPaymentDialog(SubscriptionsController controller, sub) {
    final price = (sub['amount'] ?? 0).toDouble();
    final amountCtrl = TextEditingController(text: price.toStringAsFixed(2));
    String method = 'كاش';
    String notes = '';

    Get.dialog(
      Dialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: StatefulBuilder(
          builder: (context, setState) {
            void setAmount(double v) {
              setState(() {
                amountCtrl.text = v.toStringAsFixed(2);
              });
            }

            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'تسجيل دفعة — ${sub['customer_name']}',
                      style: TextStyle(
                        fontFamily: 'cairo',
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'الاشتراك: $price ر.س / ${sub['period_days']} يوم — '
                      'التغطية الحالية حتى ${DateFormat('yyyy-MM-dd').format(controller.paidUntil(sub))}',
                      style: TextStyle(
                        fontFamily: 'cairo',
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'مبلغ الدفعة (ر.س)',
                      style: TextStyle(
                        fontFamily: 'cairo',
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _QuickAmtChip(
                          label: 'ربع (${(price * 0.25).toStringAsFixed(0)})',
                          onTap: () => setAmount(price * 0.25),
                        ),
                        _QuickAmtChip(
                          label: 'نصف (${(price * 0.5).toStringAsFixed(0)})',
                          onTap: () => setAmount(price * 0.5),
                        ),
                        _QuickAmtChip(
                          label: 'ثلاثة أرباع '
                              '(${(price * 0.75).toStringAsFixed(0)})',
                          onTap: () => setAmount(price * 0.75),
                        ),
                        _QuickAmtChip(
                          label: 'كامل (${price.toStringAsFixed(0)})',
                          selected: true,
                          onTap: () => setAmount(price),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: amountCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        isDense: true,
                        prefixIcon: const Icon(Icons.payments, size: 18),
                        labelStyle: const TextStyle(fontFamily: 'cairo'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'طريقة الدفع',
                      style: TextStyle(
                        fontFamily: 'cairo',
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        _MethodChip(
                          label: 'كاش',
                          selected: method == 'كاش',
                          onTap: () => setState(() => method = 'كاش'),
                        ),
                        const SizedBox(width: 8),
                        _MethodChip(
                          label: 'شبكة',
                          selected: method == 'شبكة',
                          onTap: () => setState(() => method = 'شبكة'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      onChanged: (v) => notes = v,
                      decoration: const InputDecoration(
                        isDense: true,
                        labelText: 'ملاحظة (اختياري)',
                        labelStyle: TextStyle(
                          fontFamily: 'cairo',
                          fontSize: 12,
                        ),
                        prefixIcon: Icon(Icons.sticky_note_2, size: 18),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Get.back(),
                            child: const Text(
                              'إلغاء',
                              style: TextStyle(fontFamily: 'cairo'),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.success,
                            ),
                            onPressed: () async {
                              final amt =
                                  double.tryParse(
                                    amountCtrl.text.replaceAll(',', '.'),
                                  ) ??
                                  0;
                              if (amt <= 0) {
                                Get.snackbar(
                                  'تنبيه',
                                  'أدخل مبلغاً صحيحاً أكبر من صفر',
                                  snackPosition: SnackPosition.BOTTOM,
                                  backgroundColor: AppColors.warning,
                                  colorText: Colors.white,
                                );
                                return;
                              }
                              final until = await controller.pay(
                                sub: sub,
                                amount: amt,
                                method: method,
                                notes: notes.trim().isEmpty ? null : notes.trim(),
                              );
                              if (context.mounted) Get.back();
                              Get.snackbar(
                                'تم تسجيل الدفعة',
                                '$amt ر.س — التغطية حتى '
                                    '${DateFormat('yyyy-MM-dd').format(until)}',
                                snackPosition: SnackPosition.BOTTOM,
                                backgroundColor: AppColors.success,
                                colorText: Colors.white,
                              );
                            },
                            child: const Text(
                              'تسجيل الدفعة',
                              style: TextStyle(
                                fontFamily: 'cairo',
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
      barrierColor: Colors.black54,
    );
  }
}

class _QuickAmtChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool selected;
  const _QuickAmtChip({
    required this.label,
    required this.onTap,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.success : AppColors.textSecondary;
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: color.withValues(alpha: selected ? 0.8 : 0.3),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'cairo',
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: selected ? AppColors.success : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _MethodChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _MethodChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.primary.withValues(alpha: 0.12)
                : AppColors.surfaceSoft,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.border,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontFamily: 'cairo',
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: selected ? AppColors.primary : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _ActionBtn({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [color, color.withValues(alpha: 0.8)]),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 9),
            child: Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 5,
              children: [
                Icon(icon, color: Colors.white, size: 15),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'cairo',
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
