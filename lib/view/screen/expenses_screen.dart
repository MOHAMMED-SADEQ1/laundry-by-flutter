import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:laundry/controller/expense/expense_controller.dart';
import 'package:laundry/core/theme/app_colors.dart';
import 'package:laundry/services/expense/expense_service.dart';
import 'package:laundry/view/widget/customappbar.dart';

/// شاشة المصروفات التشغيلية.
///
/// **لماذا:** جدول `expenses` كان موجودًا بلا أي شاشة إدخال — فلم يكن يُسجَّل
/// إيجار ولا رواتب ولا كهرباء ولا مواد، والرقم المعروض كـ«صافي الربح» كان
/// ربحًا مساهمًا لا ربحًا فعليًا. هذه الشاشة تُغلق تلك الفجوة.
class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen({super.key});

  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  late final ExpenseController c;

  @override
  void initState() {
    super.initState();
    c = Get.put(ExpenseController());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppbar(title: 'المصروفات'),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddSheet(),
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          'مصروف جديد',
          style: TextStyle(
            fontFamily: 'cairo',
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFF8FAFC), AppColors.background],
          ),
        ),
        child: Obx(() {
          if (c.isLoading.value && c.expenses.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          return RefreshIndicator(
            onRefresh: c.load,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 90),
              children: [
                _rangeSelector(),
                const SizedBox(height: 12),
                _summaryCard(),
                const SizedBox(height: 12),
                if (c.summary.value.byCategory.isNotEmpty) ...[
                  _categoryBreakdown(),
                  const SizedBox(height: 12),
                ],
                _expenseList(),
              ],
            ),
          );
        }),
      ),
    );
  }

  // ═══════════════ اختيار الفترة ═══════════════

  Widget _rangeSelector() {
    return Obx(() {
      final current = c.range.value;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 38,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: ExpenseRange.values.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final r = ExpenseRange.values[i];
                final active = r == current;
                return GestureDetector(
                  onTap: () {
                    if (r == ExpenseRange.custom) {
                      _pickCustomRange();
                    } else {
                      c.setRange(r);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 9,
                    ),
                    decoration: BoxDecoration(
                      color: active ? AppColors.primary : AppColors.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: active ? AppColors.primary : AppColors.border,
                      ),
                    ),
                    child: Row(
                      children: [
                        if (r == ExpenseRange.custom)
                          Padding(
                            padding: const EdgeInsets.only(left: 4),
                            child: Icon(
                              Icons.date_range,
                              size: 13,
                              color: active
                                  ? Colors.white
                                  : AppColors.textSecondary,
                            ),
                          ),
                        Text(
                          r.label,
                          style: TextStyle(
                            fontFamily: 'cairo',
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: active
                                ? Colors.white
                                : AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          if (current == ExpenseRange.custom)
            Padding(
              padding: const EdgeInsets.only(top: 6, right: 4),
              child: Text(
                c.rangeLabel,
                style: const TextStyle(
                  fontFamily: 'cairo',
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
        ],
      );
    });
  }

  Future<void> _pickCustomRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 3),
      lastDate: now,
      initialDateRange: DateTimeRange(start: c.customFrom.value, end: c.customTo.value),
      // ⚠️ بلا `locale`: تمرير `Locale('ar')` بلا `flutter_localizations`
      // يُنهي التطبيق — التفصيل في `customer_statement_sheet._pickPeriod`.
    );
    if (picked != null) {
      await c.setCustomRange(picked.start, picked.end);
    }
  }

  // ═══════════════ بطاقة الملخّص ═══════════════

  Widget _summaryCard() {
    return Obx(() {
      final s = c.summary.value;
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: AppColors.dangerGradient,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.payments_outlined,
                  color: Colors.white70,
                  size: 18,
                ),
                const SizedBox(width: 6),
                Text(
                  'إجمالي مصروفات الفترة',
                  style: TextStyle(
                    fontFamily: 'cairo',
                    fontSize: 12.5,
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ),
                const Spacer(),
                Text(
                  '${s.count} بند',
                  style: TextStyle(
                    fontFamily: 'cairo',
                    fontSize: 11.5,
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '${s.total.toStringAsFixed(2)} ر.س',
              style: const TextStyle(
                fontFamily: 'cairo',
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            if (s.nonCashTotal > 0) ...[
              const SizedBox(height: 6),
              Text(
                'منها نقدي: ${s.cashTotal.toStringAsFixed(2)}  •  '
                'غير نقدي: ${s.nonCashTotal.toStringAsFixed(2)}',
                style: TextStyle(
                  fontFamily: 'cairo',
                  fontSize: 11,
                  color: Colors.white.withValues(alpha: 0.85),
                ),
              ),
            ],
          ],
        ),
      );
    });
  }

  // ═══════════════ التوزيع على التصنيفات ═══════════════

  Widget _categoryBreakdown() {
    return Obx(() {
      final s = c.summary.value;
      final max = s.byCategory.isEmpty ? 1.0 : s.byCategory.first.value;
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'التوزيع حسب التصنيف',
              style: TextStyle(
                fontFamily: 'cairo',
                fontSize: 13.5,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 10),
            ...s.byCategory.map((e) {
              final pct = max <= 0 ? 0.0 : e.value / max;
              return Padding(
                padding: const EdgeInsets.only(bottom: 9),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            e.key,
                            style: const TextStyle(
                              fontFamily: 'cairo',
                              fontSize: 12,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        Text(
                          '${e.value.toStringAsFixed(2)} ر.س',
                          style: const TextStyle(
                            fontFamily: 'cairo',
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.danger,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: pct,
                        minHeight: 5,
                        backgroundColor: AppColors.surfaceSoft,
                        valueColor: const AlwaysStoppedAnimation(
                          AppColors.danger,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      );
    });
  }

  // ═══════════════ قائمة المصروفات ═══════════════

  Widget _expenseList() {
    return Obx(() {
      final list = c.expenses;
      if (list.isEmpty) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 40),
          alignment: Alignment.center,
          child: Column(
            children: [
              Icon(
                Icons.receipt_long_outlined,
                size: 52,
                color: AppColors.textMuted.withValues(alpha: 0.6),
              ),
              const SizedBox(height: 10),
              const Text(
                'لا توجد مصروفات في هذه الفترة',
                style: TextStyle(
                  fontFamily: 'cairo',
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'أضف مصروفًا ليُخصم من صافي الربح',
                style: TextStyle(
                  fontFamily: 'cairo',
                  fontSize: 11,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
        );
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(right: 4, bottom: 8),
            child: Text(
              'البنود',
              style: TextStyle(
                fontFamily: 'cairo',
                fontSize: 13.5,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          ...list.map(_expenseTile),
        ],
      );
    });
  }

  Widget _expenseTile(ExpenseRow e) {
    final date = DateTime.tryParse(e.date);
    final dateLabel = date == null
        ? e.date
        : DateFormat('yyyy-MM-dd').format(date);
    final isCash = e.paymentMethod == 'كاش';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _showAddSheet(existing: e),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: AppColors.danger.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.arrow_upward,
                  color: AppColors.danger,
                  size: 17,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      e.category,
                      style: const TextStyle(
                        fontFamily: 'cairo',
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(
                          dateLabel,
                          style: const TextStyle(
                            fontFamily: 'cairo',
                            fontSize: 10.5,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color:
                                (isCash ? AppColors.success : AppColors.info)
                                    .withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Text(
                            e.paymentMethod,
                            style: TextStyle(
                              fontFamily: 'cairo',
                              fontSize: 9.5,
                              fontWeight: FontWeight.bold,
                              color: isCash
                                  ? AppColors.success
                                  : AppColors.info,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (e.description.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        e.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'cairo',
                          fontSize: 10.5,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    e.amount.toStringAsFixed(2),
                    style: const TextStyle(
                      fontFamily: 'cairo',
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.danger,
                    ),
                  ),
                  Text(
                    'ر.س',
                    style: TextStyle(
                      fontFamily: 'cairo',
                      fontSize: 9.5,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════ إضافة / تعديل ═══════════════

  void _showAddSheet({ExpenseRow? existing}) {
    final amountCtrl = TextEditingController(
      text: existing == null ? '' : existing.amount.toString(),
    );
    final descCtrl = TextEditingController(text: existing?.description ?? '');
    var category = existing?.category ?? ExpenseCategory.materials;
    var method = existing?.paymentMethod ?? 'كاش';
    var date = DateTime.tryParse(existing?.date ?? '') ?? DateTime.now();
    final isEdit = existing != null;

    Get.bottomSheet(
      Directionality(
        textDirection: TextDirection.rtl,
        child: StatefulBuilder(
          builder: (ctx, setSheet) {
            return Container(
              decoration: const BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 14,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 18,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 44,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppColors.border,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Icon(
                          isEdit ? Icons.edit_outlined : Icons.add_circle_outline,
                          color: AppColors.primary,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          isEdit ? 'تعديل المصروف' : 'مصروف جديد',
                          style: const TextStyle(
                            fontFamily: 'cairo',
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const Spacer(),
                        if (isEdit)
                          IconButton(
                            tooltip: 'حذف',
                            onPressed: () async {
                              Get.back();
                              final ok = await Get.dialog<bool>(
                                    AlertDialog(
                                      title: const Text(
                                        'حذف المصروف؟',
                                        style: TextStyle(fontFamily: 'cairo'),
                                      ),
                                      content: const Text(
                                        'سيُحذف البند نهائيًا ويُعاد حساب الربح.',
                                        style: TextStyle(fontFamily: 'cairo'),
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Get.back(result: false),
                                          child: const Text('إلغاء'),
                                        ),
                                        TextButton(
                                          onPressed: () =>
                                              Get.back(result: true),
                                          child: const Text(
                                            'حذف',
                                            style: TextStyle(
                                              color: AppColors.danger,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ) ??
                                  false;
                              if (ok && existing.expenseId != null) {
                                await c.deleteExpense(existing.expenseId!);
                              }
                            },
                            icon: const Icon(
                              Icons.delete_outline,
                              color: AppColors.danger,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // التصنيف
                    const _Label('التصنيف'),
                    Wrap(
                      spacing: 7,
                      runSpacing: 7,
                      children: ExpenseCategory.all.map((cat) {
                        final active = cat == category;
                        return GestureDetector(
                          onTap: () => setSheet(() => category = cat),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 11,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: active
                                  ? AppColors.primary
                                  : AppColors.surfaceSoft,
                              borderRadius: BorderRadius.circular(9),
                              border: Border.all(
                                color: active
                                    ? AppColors.primary
                                    : AppColors.border,
                              ),
                            ),
                            child: Text(
                              cat,
                              style: TextStyle(
                                fontFamily: 'cairo',
                                fontSize: 11.5,
                                fontWeight: FontWeight.bold,
                                color: active
                                    ? Colors.white
                                    : AppColors.textSecondary,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 14),

                    // المبلغ
                    const _Label('المبلغ (ر.س)'),
                    TextField(
                      controller: amountCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      style: const TextStyle(
                        fontFamily: 'cairo',
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      decoration: _inputDecoration('0.00'),
                    ),
                    const SizedBox(height: 12),

                    // البيان
                    const _Label('البيان (اختياري)'),
                    TextField(
                      controller: descCtrl,
                      style: const TextStyle(fontFamily: 'cairo', fontSize: 13),
                      decoration: _inputDecoration('مثال: فاتورة كهرباء شهر 9'),
                    ),
                    const SizedBox(height: 12),

                    // التاريخ + طريقة الدفع
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const _Label('التاريخ'),
                              InkWell(
                                onTap: () async {
                                  final picked = await showDatePicker(
                                    context: ctx,
                                    initialDate: date,
                                    firstDate: DateTime(
                                      DateTime.now().year - 3,
                                    ),
                                    lastDate: DateTime.now(),
                                    // ⚠️ بلا `locale` (سبب الانهيار مفصول
                                    // في `customer_statement_sheet`).
                                  );
                                  if (picked != null) {
                                    setSheet(() => date = picked);
                                  }
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 13,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.surfaceSoft,
                                    borderRadius: BorderRadius.circular(11),
                                    border: Border.all(color: AppColors.border),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.calendar_today_outlined,
                                        size: 15,
                                        color: AppColors.textSecondary,
                                      ),
                                      const SizedBox(width: 7),
                                      Text(
                                        DateFormat('yyyy-MM-dd').format(date),
                                        style: const TextStyle(
                                          fontFamily: 'cairo',
                                          fontSize: 12.5,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const _Label('طريقة الدفع'),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceSoft,
                                  borderRadius: BorderRadius.circular(11),
                                  border: Border.all(color: AppColors.border),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: method,
                                    isExpanded: true,
                                    style: const TextStyle(
                                      fontFamily: 'cairo',
                                      fontSize: 12.5,
                                      color: AppColors.textPrimary,
                                    ),
                                    items: const [
                                      DropdownMenuItem(
                                        value: 'كاش',
                                        child: Text('نقدي (من الدرج)'),
                                      ),
                                      DropdownMenuItem(
                                        value: 'شبكة',
                                        child: Text('شبكة / تحويل'),
                                      ),
                                      DropdownMenuItem(
                                        value: 'رصيد',
                                        child: Text('تسوية دفاتر'),
                                      ),
                                    ],
                                    onChanged: (v) =>
                                        setSheet(() => method = v ?? 'كاش'),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (method != 'كاش')
                      Container(
                        padding: const EdgeInsets.all(9),
                        decoration: BoxDecoration(
                          color: AppColors.info.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(9),
                          border: Border.all(
                            color: AppColors.info.withValues(alpha: 0.25),
                          ),
                        ),
                        child: const Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              size: 14,
                              color: AppColors.info,
                            ),
                            SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'المصروف غير النقدي يُخصم من الربح ولا يُخصم من درج النقد.',
                                style: TextStyle(
                                  fontFamily: 'cairo',
                                  fontSize: 10.5,
                                  color: AppColors.info,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 16),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () async {
                          final amount =
                              double.tryParse(amountCtrl.text.trim()) ?? 0;
                          if (amount <= 0) {
                            Get.snackbar(
                              'تنبيه',
                              'أدخل مبلغًا صحيحًا أكبر من صفر',
                            );
                            return;
                          }
                          Get.back();
                          if (isEdit && existing.expenseId != null) {
                            await c.updateExpense(
                              expenseId: existing.expenseId!,
                              category: category,
                              amount: amount,
                              description: descCtrl.text,
                              date: date,
                              paymentMethod: method,
                            );
                          } else {
                            await c.addExpense(
                              category: category,
                              amount: amount,
                              description: descCtrl.text,
                              date: date,
                              paymentMethod: method,
                            );
                          }
                        },
                        child: Text(
                          isEdit ? 'حفظ التعديل' : 'تسجيل المصروف',
                          style: const TextStyle(
                            fontFamily: 'cairo',
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
    );
  }

  InputDecoration _inputDecoration(String hint) => InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(
      fontFamily: 'cairo',
      fontSize: 12.5,
      color: AppColors.textMuted,
    ),
    filled: true,
    fillColor: AppColors.surfaceSoft,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(11),
      borderSide: const BorderSide(color: AppColors.border),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(11),
      borderSide: const BorderSide(color: AppColors.border),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(11),
      borderSide: const BorderSide(color: AppColors.primary),
    ),
  );
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6, right: 2),
    child: Text(
      text,
      style: const TextStyle(
        fontFamily: 'cairo',
        fontSize: 11.5,
        fontWeight: FontWeight.bold,
        color: AppColors.textSecondary,
      ),
    ),
  );
}
