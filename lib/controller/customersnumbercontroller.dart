import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:laundry/core/theme/app_colors.dart';
import 'package:laundry/services/customer/customer_search.dart';
import 'package:laundry/services/customer/customer_ledger_service.dart';
import 'package:laundry/sqldb.dart';

class CustomersNumberController extends GetxController {
  TextEditingController neme = TextEditingController();
  TextEditingController number1 = TextEditingController();
  TextEditingController number2 = TextEditingController();

  final SqlDB _db = SqlDB();

  /// قائمة الزبائن النشطين — حالة تفاعلية تُحدَّث فوراً بعد الإضافة أو الحذف
  final RxList<Map<String, dynamic>> customers = <Map<String, dynamic>>[].obs;
  final RxBool loadingCustomers = false.obs;

  /// خريطة ذمم الزبائن: customer_id → مجموع المتبقي (مشتقّ من الفواتير)
  final RxMap<int, double> debts = <int, double>{}.obs;

  /// إجمالي ديون كل الزبائن
  final RxDouble totalDebt = 0.0.obs;

  /// عدد الزبائن المدينين
  final RxInt debtorsCount = 0.obs;

  @override
  void onInit() {
    super.onInit();
    loadCustomers();
  }

  Future<void> loadCustomers() async {
    loadingCustomers.value = true;
    try {
      final rows = await _db.readData(
        'SELECT * FROM customers WHERE is_active = 1 ORDER BY customer_name',
      );
      customers.assignAll(rows);
      await _loadDebts();
    } catch (e) {
      debugPrint('loadCustomers error: $e');
    } finally {
      loadingCustomers.value = false;
    }
  }

  /// تحميل ذمم كل الزبائن في استعلام واحد (لا استعلام لكل زبون)
  Future<void> _loadDebts() async {
    try {
      final rows = await _db.readData(
        'SELECT customer_id, COALESCE(SUM(remaining_amount), 0) AS due '
        'FROM invoices '
        'WHERE subscription_id IS NULL AND remaining_amount > 0.004 '
        'AND customer_id IS NOT NULL '
        'GROUP BY customer_id',
      );
      final map = <int, double>{};
      double total = 0;
      for (final r in rows) {
        final id = r['customer_id'] as int?;
        if (id == null) continue;
        final due = ((r['due'] ?? 0) as num).toDouble();
        if (due > 0) {
          map[id] = due;
          total += due;
        }
      }
      debts.assignAll(map);
      totalDebt.value = total;
      debtorsCount.value = map.length;
    } catch (e) {
      debugPrint('_loadDebts error: $e');
    }
  }

  /// ذمة زبون معيّن (صفر إن لم يكن مدينًا)
  double debtOf(dynamic customerId) {
    if (customerId == null) return 0;
    return debts[customerId as int] ?? 0;
  }

  /// هل الزبون له رصيد سلفة؟
  double creditOf(Map<String, dynamic> customer) {
    final b = ((customer['balance'] ?? 0) as num).toDouble();
    return b > 0 ? b : 0;
  }

  /// حفظ الزبون — يعرض رسالة واضحة عند الفشل ويُعيد true عند النجاح
  /// حتى يغلق المستدعي الحوار بنفسه (لا نغلقه من داخل طبقة التحكم).
  Future<bool> writeData() async {
    if (neme.text.trim().isEmpty) {
      messagefailer('اسم الزبون مطلوب');
      return false;
    }
    SqlDB db = SqlDB();
    final response = await db.insertData(
      "INSERT INTO customers (customer_name, phone_1, phone_2, join_date) "
      "VALUES (?, ?, ?, ?)",
      [
        neme.text.trim(),
        number1.text,
        number2.text,
        DateTime.now().toIso8601String(),
      ],
    );
    if (response > 0) {
      neme.clear();
      number1.clear();
      number2.clear();
      await loadCustomers();
      messageSuccessfully();
      return true;
    }
    messagefailer('لم يتم تنفيذ العملية بنجاح!');
    return false;
  }

  Future<List<Map<String, dynamic>>> readData() async {
    SqlDB db = SqlDB();
    List<Map<String, dynamic>> response = await db.readData(
      'SELECT * FROM customers WHERE is_active = 1 ORDER BY customer_name',
    );
    return response;
  }

  /// بحث الزبائن بالاسم أو أي من الرقمين — منفّذ على القاعدة مباشرة.
  ///
  /// بناء الشرط وقيم `?` في `services/customer/customer_search.dart` (منطق
  /// خالص مُختبَر)، فلا تُدمج قيمة واحدة في نص SQL هنا.
  Future<List<Map<String, dynamic>>> searchByText(
    String query, {
    int limit = 25,
  }) async {
    final q = CustomerSearch.normalize(query);
    if (q.isEmpty) return <Map<String, dynamic>>[];
    final spec = CustomerSearch.buildQuery(q);
    return _db.safeRead(
      'customers',
      where: 'is_active = 1 AND (${spec.where})',
      whereArgs: spec.args,
      orderBy: 'customer_name',
      limit: limit,
    );
  }

  /// بحث فوري باقتراحات الزبائن في شريط الفاتورة (الاسم أو أي من الرقمين).
  Future<List<Map<String, dynamic>>> searchSuggestions(String query) =>
      searchByText(query, limit: 6);

  /// رسالة نجاح موحّدة — تقبل نصاً مخصّصاً اختيارياً
  void messageSuccessfully([String message = 'تمت العملية بنجاح']) {
    Get.snackbar(
      "تمت العملية",
      message,
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: AppColors.success,
      colorText: Colors.white,
      duration: const Duration(seconds: 3),
      icon: const Icon(Icons.check_circle, color: Colors.white),
    );
  }

  messagefailer([String message = 'لم يتم تنفيذ العملية بنجاح!']) {
    Get.snackbar(
      "فشل العملية",
      message,
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: Colors.red,
      colorText: Colors.white,
      duration: Duration(seconds: 3),
      icon: Icon(Icons.close, color: Colors.white),
    );
  }

  /// حذف زبون (حذف ناعم) — **مع حماية**: لا يُخفى زبون عليه ذمة قائمة.
  ///
  /// سبب الحماية: الحذف الناعم كان يُخفي الزبون من القائمة بينما ذمته
  /// تبقى في الفواتير، فتضيع المطالبة ويختل تقرير الديون الكلي.
  Future<void> delete(int id) async {
    // 1. فحص الذمة الحقيقية من الفواتير
    final debt = await CustomerLedgerService.instance.debtCents(id);
    if (debt > 0) {
      final amount = CustomerLedgerService.fromCents(debt);
      Get.snackbar(
        'لا يمكن الحذف',
        'على هذا الزبون ذمة قائمة بقيمة ${amount.toStringAsFixed(2)} ر.س. '
            'سدّد الذمم أولًا ثم أعد المحاولة.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppColors.danger,
        colorText: Colors.white,
        duration: const Duration(seconds: 4),
        icon: const Icon(Icons.block, color: Colors.white),
      );
      return;
    }

    // 2. فحص الرصيد الدائن (سلفة) — تحذير لا منع
    final balance = await CustomerLedgerService.instance.storedBalanceCents(id);
    if (balance > 0) {
      final credit = CustomerLedgerService.fromCents(balance);
      final confirmed = await _confirmCreditLoss(credit);
      if (confirmed != true) return;
    }

    final response = await _db.updateData(
      "UPDATE customers SET is_active = 0 WHERE customer_id = ?",
      [id],
    );
    if (response > 0) {
      await loadCustomers();
      messageSuccessfully('تم حذف الزبون — سجل فواتيره محفوظ للتقارير');
    } else {
      messagefailer();
    }
  }

  Future<bool?> _confirmCreditLoss(double credit) {
    return Get.dialog<bool>(
      AlertDialog(
        title: const Text(
          'تنبيه: رصيد غير مستخدم',
          style: TextStyle(fontFamily: 'cairo', fontSize: 16),
        ),
        content: Text(
          'لهذا الزبون رصيد ${credit.toStringAsFixed(2)} ر.س لم يُستخدَم. '
          'إذا حذفته سيبقى الرصيد مسجَّلًا لكنه لن يظهر في القائمة. '
          'هل تريد المتابعة؟',
          style: const TextStyle(
            fontFamily: 'cairo',
            fontSize: 13,
            height: 1.6,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text('إلغاء', style: TextStyle(fontFamily: 'cairo')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Get.back(result: true),
            child: const Text(
              'حذف رغم ذلك',
              style: TextStyle(fontFamily: 'cairo', color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
