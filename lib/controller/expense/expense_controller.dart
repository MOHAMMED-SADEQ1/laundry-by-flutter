import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:laundry/services/expense/expense_service.dart';
import 'package:laundry/services/i18n/l10n.dart';

/// أنواع الفترات المتاحة في شاشة المصروفات
enum ExpenseRange { today, week, month, year, custom }

extension ExpenseRangeX on ExpenseRange {
  String get label => switch (this) {
    ExpenseRange.today => 'اليوم',
    ExpenseRange.week => 'آخر 7 أيام',
    ExpenseRange.month => 'هذا الشهر',
    ExpenseRange.year => 'هذه السنة',
    ExpenseRange.custom => 'فترة مخصّصة',
  };

  /// بداية ونهاية الفترة بتوقيت محلي
  (DateTime, DateTime) bounds() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return switch (this) {
      ExpenseRange.today => (today, today),
      ExpenseRange.week => (
        today.subtract(const Duration(days: 6)),
        today,
      ),
      ExpenseRange.month => (DateTime(now.year, now.month, 1), today),
      ExpenseRange.year => (DateTime(now.year, 1, 1), today),
      // الفترة المخصّصة تُدار بحقلي from/to في المتحكّم
      ExpenseRange.custom => (today, today),
    };
  }
}

class ExpenseController extends GetxController {
  final ExpenseService _service = ExpenseService.instance;

  final RxList<ExpenseRow> expenses = <ExpenseRow>[].obs;
  final Rx<ExpenseSummary> summary = const ExpenseSummary().obs;
  final RxBool isLoading = false.obs;

  final Rx<ExpenseRange> range = ExpenseRange.month.obs;
  final RxString categoryFilter = ''.obs;

  /// الفترة المخصّصة
  final Rx<DateTime> customFrom = DateTime(
    DateTime.now().year,
    DateTime.now().month,
    1,
  ).obs;
  final Rx<DateTime> customTo = DateTime.now().obs;

  /// الفترة الفعلية الحالية
  (DateTime, DateTime) get activeBounds {
    if (range.value == ExpenseRange.custom) {
      return (customFrom.value, customTo.value);
    }
    return range.value.bounds();
  }

  String get rangeLabel {
    final (f, t) = activeBounds;
    return '${ExpenseService.dayKey(f)} ← ${ExpenseService.dayKey(t)}';
  }

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> setRange(ExpenseRange r) async {
    range.value = r;
    await load();
  }

  Future<void> setCustomRange(DateTime from, DateTime to) async {
    customFrom.value = from;
    customTo.value = to;
    range.value = ExpenseRange.custom;
    await load();
  }

  Future<void> setCategoryFilter(String c) async {
    categoryFilter.value = c;
    await load();
  }

  Future<void> load() async {
    isLoading.value = true;
    try {
      final (from, to) = activeBounds;
      final filter = categoryFilter.value;
      expenses.assignAll(
        await _service.list(
          from: from,
          to: to,
          category: filter.isEmpty ? null : filter,
        ),
      );
      // الملخّص دائمًا على الفترة كاملة بلا فلتر تصنيف — حتى لا يبدو الإجمالي
      // ناقصًا عند اختيار تصنيف واحد.
      summary.value = await _service.summary(from: from, to: to);
    } catch (e) {
      debugPrint('ExpenseController.load error: $e');
    } finally {
      isLoading.value = false;
    }
  }

  Future<bool> addExpense({
    required String category,
    required double amount,
    String description = '',
    String categoryEn = '',
    String descriptionEn = '',
    DateTime? date,
    String paymentMethod = 'cash',
  }) async {
    try {
      await _service.add(
        category: category,
        amount: amount,
        description: description,
        categoryEn: categoryEn,
        descriptionEn: descriptionEn,
        date: date,
        paymentMethod: paymentMethod,
      );
      await load();
      _success(tr('تم تسجيل المصروف'));
      return true;
    } catch (e) {
      _error('$e'.replaceFirst('Exception: ', ''));
      return false;
    }
  }

  Future<bool> updateExpense({
    required int expenseId,
    required String category,
    required double amount,
    String description = '',
    String categoryEn = '',
    String descriptionEn = '',
    DateTime? date,
    String paymentMethod = 'cash',
  }) async {
    try {
      final ok = await _service.update(
        expenseId: expenseId,
        category: category,
        amount: amount,
        description: description,
        categoryEn: categoryEn,
        descriptionEn: descriptionEn,
        date: date,
        paymentMethod: paymentMethod,
      );
      if (!ok) {
        _error(tr('تعذّر تعديل المصروف'));
        return false;
      }
      await load();
      _success(tr('تم تعديل المصروف'));
      return true;
    } catch (e) {
      _error('$e'.replaceFirst('Exception: ', ''));
      return false;
    }
  }

  Future<bool> deleteExpense(int expenseId) async {
    try {
      final ok = await _service.delete(expenseId);
      if (!ok) {
        _error(tr('تعذّر حذف المصروف'));
        return false;
      }
      await load();
      _success(tr('تم حذف المصروف'));
      return true;
    } catch (e) {
      _error('$e');
      return false;
    }
  }

  void _success(String m) => Get.snackbar(tr('نجاح'), m);
  void _error(String m) => Get.snackbar(tr('خطأ'), m);
}
