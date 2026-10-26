import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:laundry/controller/daily_cash_controller.dart';
import 'package:laundry/core/theme/app_colors.dart';
import 'package:laundry/services/i18n/l10n.dart';
import 'package:laundry/services/payment/payment_method.dart';
import 'package:laundry/view/widget/customappbar.dart';

class DailyCashScreen extends StatefulWidget {
  const DailyCashScreen({super.key});

  @override
  State<DailyCashScreen> createState() => _DailyCashScreenState();
}

class _DailyCashScreenState extends State<DailyCashScreen> {
  late final DailyCashController controller;

  @override
  void initState() {
    super.initState();
    controller = Get.put(DailyCashController());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Obx يُرجع Widget وليس PreferredSizeWidget ⇒ نلفّه بـPreferredSize
      // بنفس ارتفاع CustomAppbar (64) وإلا فشل التحقق النوعي.
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(64),
        child: Obx(
          () => CustomAppbar(
            title: tr('الصندوق'),
            subtitle: controller.isShiftMode
                ? tr('عرض بالوردية')
                : tr('عرض بالتاريخ'),
          ),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [const Color(0xFFF8FAFC), AppColors.background],
          ),
        ),
        child: Column(
          children: [
            // اختيار وضع العرض: بالتاريخ أم بالوردية
            _ViewModeToggle(controller: controller),
            // المحدِّد التابع للوضع (تاريخ أو وردية)
            Obx(
              () => controller.isShiftMode
                  ? _ShiftSelector(controller: controller)
                  : _DateSelector(controller: controller),
            ),
            // المحتوى
            Expanded(
              child: Obx(() {
                if (controller.isLoading.value) {
                  return const Center(child: CircularProgressIndicator());
                }
                return _CashSummary(controller: controller);
              }),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── تبديل وضع العرض (تاريخ / وردية) ───
class _ViewModeToggle extends StatelessWidget {
  final DailyCashController controller;
  const _ViewModeToggle({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Obx(() {
        final isShift = controller.isShiftMode;
        return Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Expanded(
                child: _ModeButton(
                  label: tr('بالتاريخ'),
                  icon: Icons.calendar_today,
                  selected: !isShift,
                  onTap: () =>
                      controller.changeViewMode(CashViewMode.byDate),
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: _ModeButton(
                  label: tr('بالوردية'),
                  icon: Icons.lock_clock,
                  selected: isShift,
                  onTap: () =>
                      controller.changeViewMode(CashViewMode.byShift),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}

class _ModeButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _ModeButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: selected ? Colors.white : AppColors.textMuted,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'cairo',
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: selected ? Colors.white : AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── اختيار الوردية ───
class _ShiftSelector extends StatelessWidget {
  final DailyCashController controller;
  const _ShiftSelector({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final shift = controller.selectedShift;
      final isOpen = shift != null && shift['end_time'] == null;
      final hasShifts = controller.shifts.isNotEmpty;

      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        color: Colors.white,
        child: Row(
          children: [
            // الأقدم ← (shift_id أكبر = أحدث، والقائمة تنازلية)
            IconButton(
              icon: const Icon(Icons.chevron_right),
              tooltip: tr('الوردية الأقدم'),
              onPressed: hasShifts ? () => controller.stepShift(1) : null,
            ),
            Expanded(
              child: hasShifts
                  ? GestureDetector(
                      onTap: () => _pickShift(context),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: (isOpen
                                          ? AppColors.success
                                          : AppColors.textMuted)
                                      .withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  isOpen ? tr('مفتوحة') : tr('مُقفَلة'),
                                  style: TextStyle(
                                    fontFamily: 'cairo',
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: isOpen
                                        ? AppColors.success
                                        : AppColors.textMuted,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Icon(
                                Icons.keyboard_arrow_down,
                                size: 18,
                                color: AppColors.textMuted,
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            controller.selectedShiftLabel,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontFamily: 'cairo',
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    )
                  : Text(
                      tr('لا توجد ورديات مسجّلة'),
                      style: const TextStyle(
                        fontFamily: 'cairo',
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                    ),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_left),
              tooltip: tr('الوردية الأحدث'),
              onPressed: hasShifts ? () => controller.stepShift(-1) : null,
            ),
          ],
        ),
      );
    });
  }

  Future<void> _pickShift(BuildContext context) async {
    final selected = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) => _ShiftPickerSheet(controller: controller),
    );
    if (selected != null) {
      await controller.selectShift(selected);
    }
  }
}

// ─── قائمة اختيار الوردية ───
class _ShiftPickerSheet extends StatelessWidget {
  final DailyCashController controller;
  const _ShiftPickerSheet({required this.controller});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Text(
            tr('اختر الوردية'),
            style: const TextStyle(
              fontFamily: 'cairo',
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Divider(height: 1),
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: controller.shifts.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final s = controller.shifts[i];
                final id = (s['shift_id'] as num).toInt();
                final isOpen = s['end_time'] == null;
                final isCurrent = controller.selectedShiftId.value == id;
                return ListTile(
                  leading: Icon(
                    isOpen ? Icons.lock_open : Icons.lock,
                    color: isOpen ? AppColors.success : AppColors.textMuted,
                  ),
                  title: Text(
                    trf('وردية #{0}', ['$id']),
                    style: const TextStyle(
                      fontFamily: 'cairo',
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: Text(
                    '${_shiftTimeLabel(s['start_time'])}${isOpen ? tr(' · مفتوحة الآن') : ' → ${_shiftTimeLabel(s['end_time'])}'}',
                    style: const TextStyle(fontFamily: 'cairo', fontSize: 12),
                  ),
                  trailing: isCurrent
                      ? const Icon(Icons.check, color: AppColors.primary)
                      : Text(
                          ((s['total_cash'] ?? 0) as num).toStringAsFixed(2),
                          style: const TextStyle(
                            fontFamily: 'cairo',
                            fontSize: 12,
                            color: AppColors.textMuted,
                          ),
                        ),
                  onTap: () => Navigator.pop(context, id),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  static String _shiftTimeLabel(Object? raw) {
    final str = raw?.toString() ?? '';
    if (str.isEmpty) return '';
    try {
      return DateFormat('dd/MM hh:mm a').format(DateTime.parse(str));
    } catch (_) {
      return str;
    }
  }
}

// ─── اختيار التاريخ ───
class _DateSelector extends StatelessWidget {
  final DailyCashController controller;
  const _DateSelector({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final current = controller.selectedDate.value;
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        color: Colors.white,
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_right),
              onPressed: () {
                final prev = DateTime.parse(current)
                    .subtract(const Duration(days: 1));
                controller.changeDate(DateFormat('yyyy-MM-dd').format(prev));
              },
            ),
            Expanded(
              child: Center(
                child: Text(
                  _formatDateArabic(current),
                  style: const TextStyle(
                    fontFamily: 'cairo',
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_left),
              onPressed: () {
                final next =
                    DateTime.parse(current).add(const Duration(days: 1));
                controller.changeDate(DateFormat('yyyy-MM-dd').format(next));
              },
            ),
          ],
        ),
      );
    });
  }

  String _formatDateArabic(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      final now = DateTime.now();
      final today = DateFormat('yyyy-MM-dd').format(now);
      final yesterday =
          DateFormat('yyyy-MM-dd').format(now.subtract(const Duration(days: 1)));

      String prefix = '';
      if (dateStr == today) {
        prefix = tr('اليوم — ');
      } else if (dateStr == yesterday) {
        prefix = tr('أمس — ');
      }

      final months = [
        '',
        tr('يناير'),
        tr('فبراير'),
        tr('مارس'),
        tr('أبريل'),
        tr('مايو'),
        tr('يونيو'),
        tr('يوليو'),
        tr('أغسطس'),
        tr('سبتمبر'),
        tr('أكتوبر'),
        tr('نوفمبر'),
        tr('ديسمبر'),
      ];
      final days = [
        '',
        tr('الأحد'),
        tr('الإثنين'),
        tr('الثلاثاء'),
        tr('الأربعاء'),
        tr('الخميس'),
        tr('الجمعة'),
        tr('السبت'),
      ];

      return '$prefix${days[date.weekday]} ${date.day} ${months[date.month]} ${date.year}';
    } catch (_) {
      return dateStr;
    }
  }
}

// ─── ملخص الصندوق ───
class _CashSummary extends StatelessWidget {
  final DailyCashController controller;
  const _CashSummary({required this.controller});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // رصيد الافتتاح
        _OpeningBalance(controller: controller),
        const SizedBox(height: 12),
        // إيداعات (فواتير كاش)
        _OperationSection(
          title: tr('إيداعات (فواتير كاش)'),
          icon: Icons.arrow_downward,
          color: AppColors.success,
          items: controller.cashIn,
          itemBuilder: (item) => _InvoiceRow(item: item),
          total: controller.cashIn.fold(0.0,
              (sum, e) => sum + ((e['paid_amount'] ?? 0) as num).toDouble()),
        ),
        const SizedBox(height: 12),
        // مدفوعات ديون الزبائن
        _OperationSection(
          title: tr('سداد ديون الزبائن'),
          icon: Icons.payments,
          color: AppColors.info,
          items: controller.debtPayments,
          itemBuilder: (item) => _DebtPaymentRow(item: item),
          total: controller.debtPayments
              .where((e) => (e['source'] ?? 'manual') != 'credit_use')
              .fold(0.0, (sum, e) => sum + ((e['amount'] ?? 0) as num).toDouble()),
        ),
        const SizedBox(height: 12),
        // دفعات الاشتراكات الشهرية — نقدية دخلت الدرج
        if (controller.subscriptionPayments.isNotEmpty) ...[
          _OperationSection(
            title: tr('دفعات الاشتراكات'),
            icon: Icons.autorenew,
            color: AppColors.violet,
            items: controller.subscriptionPayments,
            itemBuilder: (item) => _SubscriptionPaymentRow(item: item),
            total: controller.subscriptionCashTotal,
          ),
          const SizedBox(height: 12),
        ],
        // سحوبات
        _OperationSection(
          title: tr('سحوبات (مصروفات)'),
          icon: Icons.arrow_upward,
          color: AppColors.danger,
          items: controller.cashOut,
          itemBuilder: (item) => _ExpenseRow(item: item),
          total: controller.totalCashOut,
        ),
        const SizedBox(height: 12),
        // الإجماليات
        _TotalsSection(controller: controller),
      ],
    );
  }
}

// ─── رصيد الافتتاح ───
class _OpeningBalance extends StatelessWidget {
  final DailyCashController controller;
  const _OpeningBalance({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final hasShift = controller.shiftSummary.value != null;
      final balance = controller.openingBalance;
      final isShiftMode = controller.isShiftMode;
      final shiftId = controller.shiftSummary.value?['shift_id'];
      final dayShifts = controller.dayShifts.length;
      final String title;
      if (!hasShift) {
        title = isShiftMode
            ? tr('لا توجد وردية محددة')
            : tr('لا توجد وردية في هذا اليوم');
      } else if (isShiftMode) {
        title = trf('رصيد افتتاح وردية #{0}', ['$shiftId']);
      } else {
        // تاريخ الصندوق = تاريخ فتح الوردية: الافتتاح هو افتتاح أول وردية
        // فُتحت في اليوم (كل وردية تالية ترحّل نقد سابقتها).
        title = dayShifts > 1
            ? trf('رصيد افتتاح يوم العمل ({0} ورديات)', ['$dayShifts'])
            : trf('رصيد افتتاح وردية #{0}', [
                '${controller.dayShifts.first['shift_id']}',
              ]);
      }
      return Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: hasShift
                ? AppColors.primaryGradient
                : LinearGradient(
                    colors: [Colors.grey.shade400, Colors.grey.shade500]),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Icon(
                hasShift ? Icons.lock_clock : Icons.lock_open,
                color: Colors.white,
                size: 28,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontFamily: 'cairo',
                        fontSize: 14,
                        color: Colors.white70,
                      ),
                    ),
                    Text(
                      trf('{0} ريال', [balance.toStringAsFixed(2)]),
                      style: const TextStyle(
                        fontFamily: 'cairo',
                        fontSize: 22,
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
      );
    });
  }
}

// ─── قسم العمليات ───
class _OperationSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final List<Map<String, dynamic>> items;
  final Widget Function(Map<String, dynamic>) itemBuilder;
  final double total;

  const _OperationSection({
    required this.title,
    required this.icon,
    required this.color,
    required this.items,
    required this.itemBuilder,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // العنوان
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.08),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(14)),
            ),
            child: Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontFamily: 'cairo',
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                const Spacer(),
                Text(
                  trf('{0} ريال', [total.toStringAsFixed(2)]),
                  style: TextStyle(
                    fontFamily: 'cairo',
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
          // العناصر
          if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.all(20),
              child: Center(
                child: Text(
                  tr('لا توجد عمليات'),
                  style: const TextStyle(
                    fontFamily: 'cairo',
                    color: Colors.grey,
                  ),
                ),
              ),
            )
          else
            ...items.map(itemBuilder),
        ],
      ),
    );
  }
}

// ─── صف فاتورة ───
class _InvoiceRow extends StatelessWidget {
  final Map<String, dynamic> item;
  const _InvoiceRow({required this.item});

  @override
  Widget build(BuildContext context) {
    final customer = item['customer_name']?.toString().isNotEmpty == true
        ? item['customer_name']
        : tr('غير مسجل');
    final user = item['user_name']?.toString() ?? '';
    final amount = ((item['paid_amount'] ?? 0) as num).toDouble();
    final time = _formatTime(item['invoice_date']?.toString());

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFF0F0F0))),
      ),
      child: Row(
        children: [
          // رقم الفاتورة
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                '#${item['invoices_id'] ?? ''}',
                style: TextStyle(
                  fontFamily: 'cairo',
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: AppColors.success,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          // التفاصيل
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  customer,
                  style: const TextStyle(
                    fontFamily: 'cairo',
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    if (user.isNotEmpty) ...[
                      Icon(Icons.person, size: 12, color: AppColors.textMuted),
                      const SizedBox(width: 3),
                      Text(
                        user,
                        style: TextStyle(
                          fontFamily: 'cairo',
                          fontSize: 11,
                          color: AppColors.textMuted,
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Icon(Icons.access_time, size: 12, color: AppColors.textMuted),
                    const SizedBox(width: 3),
                    Text(
                      time,
                      style: TextStyle(
                        fontFamily: 'cairo',
                        fontSize: 11,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // المبلغ
          Text(
            '+${amount.toStringAsFixed(2)}',
            style: TextStyle(
              fontFamily: 'cairo',
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppColors.success,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── صف دفعة دين زبون ───
class _DebtPaymentRow extends StatelessWidget {
  final Map<String, dynamic> item;
  const _DebtPaymentRow({required this.item});

  @override
  Widget build(BuildContext context) {
    final customer = item['customer_name']?.toString().isNotEmpty == true
        ? item['customer_name']
        : tr('غير محدد');
    final user = item['user_name']?.toString() ?? '';
    final amount = ((item['amount'] ?? 0) as num).toDouble();
    final method = item['payment_method']?.toString() ?? PaymentMethod.cash.key;
    final time = _formatTime(item['payment_date']?.toString());
    // استهلاك السلفة ليس نقدية — نوسمه بوضوح حتى لا يُحتسب في الدرج
    final isCreditUse = (item['source'] ?? 'manual') == 'credit_use';
    final sourceLabel = isCreditUse
        ? tr('من الرصيد (ليست نقدية)')
        : switch (item['source']) {
            'delivery' => tr('سداد عند التسليم'),
            _ => tr('دفعة يدوية'),
          };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFF0F0F0))),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.info.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              PaymentMethods.isCash(method)
                  ? Icons.money
                  : Icons.credit_card,
              size: 18,
              color: AppColors.info,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isCreditUse
                      ? trf('استهلاك رصيد — {0}', [customer])
                      : trf('سداد دين — {0}', [customer]),
                  style: const TextStyle(
                    fontFamily: 'cairo',
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    if (user.isNotEmpty) ...[
                      Icon(Icons.person, size: 12, color: AppColors.textMuted),
                      const SizedBox(width: 3),
                      Text(
                        user,
                        style: TextStyle(
                          fontFamily: 'cairo',
                          fontSize: 11,
                          color: AppColors.textMuted,
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Icon(Icons.access_time, size: 12, color: AppColors.textMuted),
                    const SizedBox(width: 3),
                    Text(
                      time,
                      style: TextStyle(
                        fontFamily: 'cairo',
                        fontSize: 11,
                        color: AppColors.textMuted,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      sourceLabel,
                      style: TextStyle(
                        fontFamily: 'cairo',
                        fontSize: 11,
                        color: isCreditUse
                            ? AppColors.warning
                            : AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Text(
            '+${amount.toStringAsFixed(2)}',
            style: TextStyle(
              fontFamily: 'cairo',
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppColors.info,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── صف دفعة اشتراك ───
class _SubscriptionPaymentRow extends StatelessWidget {
  final Map<String, dynamic> item;
  const _SubscriptionPaymentRow({required this.item});

  @override
  Widget build(BuildContext context) {
    final customer = item['customer_name']?.toString().isNotEmpty == true
        ? item['customer_name']
        : tr('غير محدد');
    final user = item['user_name']?.toString() ?? '';
    final amount = ((item['amount'] ?? 0) as num).toDouble();
    final method = item['method']?.toString() ?? PaymentMethod.cash.key;
    final time = _formatTime(item['paid_date']?.toString());
    final source = '${item['source'] ?? 'manual'}';
    final isRefund = source == 'cancel_refund';
    // الاسترداد كسلفة تسوية دفاتر لا نقدية — نوسمه حتى لا يُحتسب في الدرج
    final isCreditRefund =
        isRefund && PaymentMethods.tryParse(method) == PaymentMethod.balance;
    final sourceLabel = switch (source) {
      'renewal' => tr('تجديد اشتراك'),
      'cancel_refund' =>
        isCreditRefund
            ? tr('استرداد كسلفة (ليست نقدية)')
            : tr('استرداد نقدي'),
      _ => tr('دفعة اشتراك'),
    };
    final accent = isRefund ? AppColors.danger : AppColors.violet;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFF0F0F0))),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              isRefund
                  ? Icons.undo
                  : (PaymentMethods.isCash(method)
                        ? Icons.money
                        : Icons.credit_card),
              size: 18,
              color: accent,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isRefund
                      ? trf('استرداد — {0}', ['$customer'])
                      : trf('اشتراك — {0}', ['$customer']),
                  style: const TextStyle(
                    fontFamily: 'cairo',
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    if (user.isNotEmpty) ...[
                      Icon(Icons.person, size: 12, color: AppColors.textMuted),
                      const SizedBox(width: 3),
                      Text(
                        user,
                        style: TextStyle(
                          fontFamily: 'cairo',
                          fontSize: 11,
                          color: AppColors.textMuted,
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Icon(Icons.access_time, size: 12, color: AppColors.textMuted),
                    const SizedBox(width: 3),
                    Text(
                      time,
                      style: TextStyle(
                        fontFamily: 'cairo',
                        fontSize: 11,
                        color: AppColors.textMuted,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        sourceLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'cairo',
                          fontSize: 11,
                          color: isCreditRefund
                              ? AppColors.warning
                              : AppColors.textMuted,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Text(
            '${isRefund ? '−' : '+'}${amount.toStringAsFixed(2)}',
            style: TextStyle(
              fontFamily: 'cairo',
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: accent,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── صف مصروف ───
class _ExpenseRow extends StatelessWidget {
  final Map<String, dynamic> item;
  const _ExpenseRow({required this.item});

  @override
  Widget build(BuildContext context) {
    final category = item['category']?.toString() ?? '';
    final description = item['description']?.toString() ?? '';
    final user = item['user_name']?.toString() ?? '';
    final amount = ((item['amount'] ?? 0) as num).toDouble();
    final time = _formatTime(item['date']?.toString());

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFF0F0F0))),
      ),
      child: Row(
        children: [
          // أيقونة التصنيف
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.danger.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.receipt_long,
              size: 18,
              color: AppColors.danger,
            ),
          ),
          const SizedBox(width: 10),
          // التفاصيل
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  category.isNotEmpty ? category : description,
                  style: const TextStyle(
                    fontFamily: 'cairo',
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    if (user.isNotEmpty) ...[
                      Icon(Icons.person, size: 12, color: AppColors.textMuted),
                      const SizedBox(width: 3),
                      Text(
                        user,
                        style: TextStyle(
                          fontFamily: 'cairo',
                          fontSize: 11,
                          color: AppColors.textMuted,
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Icon(Icons.access_time, size: 12, color: AppColors.textMuted),
                    const SizedBox(width: 3),
                    Text(
                      time,
                      style: TextStyle(
                        fontFamily: 'cairo',
                        fontSize: 11,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // المبلغ
          Text(
            '-${amount.toStringAsFixed(2)}',
            style: TextStyle(
              fontFamily: 'cairo',
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppColors.danger,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── الإجماليات ───
class _TotalsSection extends StatelessWidget {
  final DailyCashController controller;
  const _TotalsSection({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _TotalRow(
              label: tr('إيداعات'),
              amount: controller.totalCashIn,
              color: AppColors.success,
              icon: Icons.arrow_downward,
            ),
            // تفصيل مساهمات الاشتراكات في الإيداعات — يجعل مطابقة الدرج
            // ممكنة بلا تخمين: كم منها اشتراكات وكم استُرد نقدًا.
            if (controller.subscriptionCashTotal > 0 ||
                controller.subscriptionRefundTotal > 0) ...[
              const Divider(),
              if (controller.subscriptionCashTotal > 0)
                _TotalRow(
                  label: tr('منها اشتراكات'),
                  amount: controller.subscriptionCashTotal,
                  color: AppColors.violet,
                  icon: Icons.autorenew,
                ),
              if (controller.subscriptionRefundTotal > 0)
                _TotalRow(
                  label: tr('استردادات اشتراكات نقدية'),
                  amount: controller.subscriptionRefundTotal,
                  color: AppColors.danger,
                  icon: Icons.undo,
                ),
            ],
            const Divider(),
            _TotalRow(
              label: tr('سحوبات نقدية'),
              amount: controller.totalCashOut,
              color: AppColors.danger,
              icon: Icons.arrow_upward,
            ),
            // إفصاح: مصروفات مدفوعة بغير النقد لا تمسّ الدرج
            if (controller.nonCashExpenseTotal > 0) ...[
              const Divider(),
              _TotalRow(
                label: tr('مصروفات غير نقدية'),
                amount: controller.nonCashExpenseTotal,
                color: AppColors.textMuted,
                icon: Icons.credit_card,
              ),
            ],
            const Divider(),
            _TotalRow(
              label: tr(controller.netLabel),
              amount: controller.totalCashIn - controller.totalCashOut,
              color: AppColors.primary,
              icon: Icons.account_balance_wallet,
              bold: true,
            ),
            const Divider(),
            _TotalRow(
              label: tr('رصيد الافتتاح'),
              amount: controller.openingBalance,
              color: AppColors.textMuted,
              icon: Icons.lock,
            ),
            const Divider(),
            _TotalRow(
              label: tr('الرصيد الختامي'),
              amount: controller.closingBalance,
              color: AppColors.primary,
              icon: Icons.savings,
              bold: true,
            ),
            // ─── جرد الأدراج: الجزء المخزَّن الوحيد غير القابل للاشتقاق ───
            // يعرض في وضع «بالتاريخ» مجمّعًا لورديات اليوم. لا نُظهِر معدومًا
            // («لم يُجرَد») كصفر لأن الفرق بينهما معلومة محاسبية حقيقية.
            if (!controller.isShiftMode && controller.hasDayStocktake) ...[
              const Divider(),
              if (controller.dayStocktakeCount > 0) ...[
                _TotalRow(
                  label: trf('المعدود فعليًا ({0} وردية)', [
                    '${controller.dayStocktakeCount}',
                  ]),
                  amount: controller.dayCountedCash.value,
                  color: AppColors.textSecondary,
                  icon: Icons.calculate_outlined,
                ),
                _TotalRow(
                  label: controller.dayCashDifference.abs() < 0.01
                      ? tr('فروق الجرد (مطابقة)')
                      : controller.dayCashDifference > 0
                      ? tr('فروق الجرد (زيادة)')
                      : tr('فروق الجرد (عجز)'),
                  amount: controller.dayCashDifference.value,
                  color: controller.dayCashDifference.abs() < 0.01
                      ? AppColors.success
                      : AppColors.danger,
                  icon: Icons.balance,
                  bold: true,
                ),
              ],
              if (controller.dayUnstockedCount > 0)
                _TotalRow(
                  label: tr('ورديات أُقفلت بلا جرد'),
                  amount: controller.dayUnstockedCount.toDouble(),
                  color: AppColors.warning,
                  icon: Icons.help_outline,
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TotalRow extends StatelessWidget {
  final String label;
  final double amount;
  final Color color;
  final IconData icon;
  final bool bold;

  const _TotalRow({
    required this.label,
    required this.amount,
    required this.color,
    required this.icon,
    this.bold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            fontFamily: 'cairo',
            fontSize: bold ? 14 : 13,
            fontWeight: bold ? FontWeight.bold : FontWeight.normal,
            color: color,
          ),
        ),
        const Spacer(),
        Text(
          trf('{0} ريال', [amount.toStringAsFixed(2)]),
          style: TextStyle(
            fontFamily: 'cairo',
            fontSize: bold ? 16 : 14,
            fontWeight: bold ? FontWeight.bold : FontWeight.normal,
            color: color,
          ),
        ),
      ],
    );
  }
}

// ─── دالة مساعدة لتنسيق الوقت ───
String _formatTime(String? dateTimeStr) {
  if (dateTimeStr == null || dateTimeStr.isEmpty) return '';
  try {
    final dt = DateTime.parse(dateTimeStr);
    return DateFormat('hh:mm a').format(dt);
  } catch (_) {
    return '';
  }
}
