import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:laundry/services/customer/customer_ledger_service.dart';
import 'package:laundry/services/customer/customer_statement_service.dart';
import 'package:laundry/services/i18n/l10n.dart';
import 'package:laundry/sqldb.dart';
import 'package:laundry/services/security/session_manager.dart';

/// حساب الزبون: كشف الذمم + سجل الدفعات + تسجيل دفعة.
///
/// **المبدأ المحاسبي المُصلَّح:** كل دفعة تُوزَّع FIFO على الفواتير الآجلة
/// (الأقدم أولًا)، و`customers.balance` **يُشتقّ دائمًا من الفواتير** بعد كل
/// عملية — فلا يتباعد الرصيد عن مجموع المتبقي أبدًا.
class CustomerAccountController extends GetxController {
  final SqlDB _db = SqlDB();
  final CustomerLedgerService _ledger = CustomerLedgerService.instance;

  final Rxn<Map<String, dynamic>> customer = Rxn<Map<String, dynamic>>();
  final RxList<Map<String, dynamic>> invoices = <Map<String, dynamic>>[].obs;
  final RxList<Map<String, dynamic>> payments = <Map<String, dynamic>>[].obs;
  final RxBool isLoading = false.obs;

  /// كشف الحساب الكامل (كل الفواتير + الأصناف + سجل قطع الاشتراك).
  /// يُبنى عبر `CustomerStatementService` — لا حساب مالي مكرَّر هنا.
  final Rxn<CustomerStatement> statement = Rxn<CustomerStatement>();

  /// مجموع الذمة — مشتقّ من الفواتير (لا من عمود مخزَّن)
  double get totalRemaining => invoices.fold(
    0.0,
    (sum, e) => sum + ((e['remaining_amount'] ?? 0) as num).toDouble(),
  );

  /// مجموع الدفعات المسجَّلة في دفتر الدفعات
  double get totalPaid => payments.fold(
    0.0,
    (sum, e) => sum + ((e['amount'] ?? 0) as num).toDouble(),
  );

  /// الرصيد الدائن المتاح (سلفة لم تُستهلَك) — صفر أو موجب
  double get availableCredit {
    final b = ((customer.value?['balance'] ?? 0) as num).toDouble();
    return b > 0 ? b : 0;
  }

  /// حدّ الدين المسموح (0 = بلا حد)
  double get creditLimit =>
      ((customer.value?['credit_limit'] ?? 0) as num).toDouble();

  /// إجمالي مشتريات الزبون منذ الاشتراك (عمود `total_spent` المُحدَّث عند
  /// كل إصدار فاتورة). كان مخزَّنًا ولا يُعرض في أي شاشة.
  double get totalSpent =>
      ((customer.value?['total_spent'] ?? 0) as num).toDouble();

  /// نقاط الولاء المتراكمة (نقطة لكل `loyalty_rate` ريال)
  int get loyaltyPoints =>
      ((customer.value?['loyalty_points'] ?? 0) as num).toInt();

  /// الشريحة الحالية: bronze / silver / gold
  String get tier {
    final t = customer.value?['tier']?.toString();
    if (t == null || t.isEmpty) return 'bronze';
    return t;
  }

  /// هل تجاوز الزبون حدّه الآجل؟
  bool get isOverLimit {
    if (creditLimit <= 0) return false;
    return CustomerLedgerService.toCents(totalRemaining) >
        CustomerLedgerService.toCents(creditLimit);
  }

  @override
  void onInit() {
    super.onInit();
    final customerId = Get.arguments as int?;
    if (customerId != null) {
      loadCustomerAccount(customerId);
    }
  }

  Future<void> loadCustomerAccount(int customerId) async {
    isLoading.value = true;
    try {
      // بيانات الزبون
      final custRows = await _db.safeRead(
        'customers',
        where: 'customer_id = ?',
        whereArgs: [customerId],
      );
      if (custRows.isNotEmpty) customer.value = custRows.first;

      // إصلاح وقائي: زامن الرصيد مع الفواتير قبل العرض
      await _ledger.syncBalance(customerId);
      final refreshed = await _db.safeRead(
        'customers',
        where: 'customer_id = ?',
        whereArgs: [customerId],
      );
      if (refreshed.isNotEmpty) customer.value = refreshed.first;

      // فواتيره الآجلة (remaining_amount > 0) — بالمعرّف لا بالاسم
      final invRows = await _db.readData(
        'SELECT * FROM invoices WHERE customer_id = ? AND subscription_id IS NULL AND remaining_amount > 0.004 ORDER BY invoice_date ASC',
        [customerId],
      );
      invoices.assignAll(invRows);

      // سجل مدفوعاته
      final payRows = await _db.readData(
        'SELECT cp.*, u.full_name as user_name FROM customer_payments cp LEFT JOIN users u ON cp.recorded_by = u.user_id WHERE cp.customer_id = ? ORDER BY cp.payment_date DESC',
        [customerId],
      );
      payments.assignAll(payRows);

      // كشف الحساب الكامل — كل الفواتير (لا الآجلة فقط) + بنود الأصناف
      // + سجل قطع الاشتراك. مصدره خدمة القراءة وحدها.
      statement.value = await CustomerStatementService.instance.build(
        customerId,
      );
    } catch (e) {
      debugPrint('loadCustomerAccount error: $e');
    } finally {
      isLoading.value = false;
    }
  }

  /// تسجيل دفعة من الزبون.
  ///
  /// الخطوات:
  /// 1. قيّد الدفعة في `customer_payments` (دفتر الأستاذ) أولًا.
  /// 2. اطرح أي سلفة قائمة (`balance > 0`) قبل توزيع النقد.
  /// 3. وزّع الباقي FIFO على الفواتير الأقدم.
  /// 4. أي فائض بعد سداد كل الفواتير → سلفة (رصيد موجب).
  /// 5. أعِد اشتقاق `balance` من الفواتير — لا تحسبه يدويًا.
  Future<bool> recordPayment({
    required int customerId,
    required double amount,
    required String paymentMethod,
    String? notes,
  }) async {
    final amountCents = CustomerLedgerService.toCents(amount);
    if (amountCents <= 0) {
      Get.snackbar(
        tr('خطأ'),
        tr('المبلغ يجب أن يكون أكبر من صفر'),
        snackPosition: SnackPosition.BOTTOM,
      );
      return false;
    }

    try {
      final userId = SessionManager.currentUserId;
      final now = DateTime.now().toIso8601String();

      // 0. الذمة القائمة **قبل** الدفعة — تُقرأ لتُحسب حصة الفائض للعرض فقط.
      //    (إدراج صف الدفعة لا يغيّر الفواتير، فالقراءة قبل أو بعد سواء.)
      final debtBeforeCents = await _ledger.debtCents(customerId);

      // 1. قيد الدفعة في دفتر الأستاذ
      await _db.safeInsert('customer_payments', {
        'customer_id': customerId,
        'amount': amount,
        'payment_method': paymentMethod,
        'payment_date': now,
        'notes': notes,
        'recorded_by': userId,
        'source': 'manual',
      });

      await _db.logAudit(
        userId: userId,
        action: 'customer_payment',
        tableName: 'customer_payments',
        newValues:
            '{"customer_id":$customerId,"amount":$amount,"method":"$paymentMethod"}',
      );

      // 2. التوزيع FIFO — **عبر المحرّك المركزي وحده**.
      //
      // **إصلاح عيب محاسبي (2026-10-01):** كان هنا نسخة مُكرَّرة من حلقة
      // التوزيع، وكانت عند انعدام الفائض تُسند `balance = -debtNow`
      // مباشرةً ⇒ **تمحو أي سلفة قائمة على الزبون صامتًا**. مثال مُثبَت:
      // سلفة 100 + ذمة 50 + دفعة 10 ⇒ الشاشة تعطي صافي **-40** بينما
      // المحرّك يعطي **+60** (خسارة 100 ريال بلا تحذير).
      //
      // السبب الجذري للتباعد: المحرّك يستدعي `syncBalance(keepCredit: true)`
      // التي تُبقي الرصيد الموجب، والنسخة المكرّرة كانت تُلغيه. وهذا يناقض
      // القاعدة المكتوبة في `CustomerLedgerService` صراحةً:
      // «لا تكرّر منطق التوزيع في مكان آخر».
      //
      // الحصّة الموزَّعة = الأصغر بين المبلغ والذمة القائمة، لأن FIFO تغطّي
      // كل الذمم. والفائض = ما زاد ⇒ يُقيَّد سلفة داخل المحرّك نفسه.
      final allocatedCents = amountCents < debtBeforeCents
          ? amountCents
          : debtBeforeCents;
      final surplusCents = amountCents - allocatedCents;

      await _ledger.allocatePaymentFifo(customerId, amountCents);

      final surplus = CustomerLedgerService.fromCents(surplusCents);
      final debtNow = await _ledger.debtCents(customerId);

      // 5. سجل حركة الرصيد للتدقيق
      final balanceAfter = await _ledger.storedBalanceCents(customerId);
      await _db.safeInsert('customer_balance_log', {
        'customer_id': customerId,
        'change_amount': amount,
        'balance_after': CustomerLedgerService.fromCents(balanceAfter),
        'reason': 'payment',
        'reference_id': null,
        'created_at': now,
        'created_by': userId,
      });

      // 6. إعادة تحميل البيانات
      await loadCustomerAccount(customerId);

      final remainingAfter = CustomerLedgerService.fromCents(debtNow);
      Get.snackbar(
        tr('نجاح'),
        surplus > 0
            ? trf(
                'تم تسجيل {0} — بقي للزبون رصيد {1} ر.س كسلفة',
                [amount.toStringAsFixed(2), surplus.toStringAsFixed(2)],
              )
            : trf('تم تسجيل الدفعة — الذمة المتبقية {0} ر.س', [
                remainingAfter.toStringAsFixed(2),
              ]),
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: const Color(0xFF16A34A),
        colorText: Colors.white,
      );
      return true;
    } catch (e) {
      debugPrint('recordPayment error: $e');
      Get.snackbar(
        tr('خطأ'),
        trf('فشل في تسجيل الدفعة: {0}', [e]),
        snackPosition: SnackPosition.BOTTOM,
      );
      return false;
    }
  }

  /// ضبط حدّ الدين الآجل للزبون (0 = بلا حد)
  Future<void> setCreditLimit(int customerId, double limit) async {
    try {
      await _db.safeUpdate(
        'customers',
        {'credit_limit': limit < 0 ? 0 : limit},
        where: 'customer_id = ?',
        whereArgs: [customerId],
      );
      await loadCustomerAccount(customerId);
      Get.snackbar(
        tr('تم'),
        limit <= 0
            ? tr('أُلغي حدّ الدين الآجل')
            : trf('حُدّد حدّ الدين الآجل بـ {0} ر.س', [
                limit.toStringAsFixed(2),
              ]),
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: const Color(0xFF16A34A),
        colorText: Colors.white,
      );
    } catch (e) {
      debugPrint('setCreditLimit error: $e');
    }
  }

  /// استهلاك السلفة على الذمم القائمة (زر «استخدم الرصيد»)
  Future<void> applyCreditToDebts(int customerId) async {
    final used = await _ledger.consumeCredit(customerId);
    if (used <= 0) {
      Get.snackbar(
        tr('لا يوجد رصيد'),
        tr('الزبون لا يملك سلفة قابلة للاستخدام'),
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: const Color(0xFFF59E0B),
        colorText: Colors.white,
      );
      return;
    }
    await loadCustomerAccount(customerId);
    Get.snackbar(
      tr('تم'),
      trf('استُخدم {0} ر.س من رصيد الزبون في سداد ذممه', [
        used.toStringAsFixed(2),
      ]),
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: const Color(0xFF16A34A),
      colorText: Colors.white,
    );
  }

  /// فحص مطابقة الرصيد مع الفواتير (للتشخيص)
  Future<DebtReconciliation> reconcile() async {
    final id = customer.value?['customer_id'] as int?;
    if (id == null) {
      return const DebtReconciliation(
        debtCents: 0,
        storedCents: 0,
        expectedCents: 0,
        isBalanced: true,
      );
    }
    return _ledger.reconcile(id);
  }

  Color get balanceColor {
    final b = ((customer.value?['balance'] ?? 0) as num).toDouble();
    if (b > 0) return const Color(0xFF16A34A); // له رصيد
    if (b < 0) return const Color(0xFFDC2626); // مدين
    return const Color(0xFF6B7280); // مُسدَّد
  }
}
