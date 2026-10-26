import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:laundry/services/customer/customer_ledger_service.dart';
import 'package:laundry/services/customer/customer_search.dart';
import 'package:laundry/services/customer/debt_report_service.dart';
import 'package:laundry/sqldb.dart';

/// متحكم تقرير الذمم: أعمار الديون + المطابقة + الإصلاح.
///
/// يحمل الحالة التفاعلية للشاشة، ويبقى منطق الحساب كله في
/// `DebtReportService` — فلا تُكرَّر قاعدة محاسبية في طبقة العرض.
class DebtReportController extends GetxController {
  final SqlDB _db = SqlDB();

  // ─── حالة أعمار الديون ───
  final RxList<CustomerAgingRow> agingRows = <CustomerAgingRow>[].obs;
  final Rxn<AgingSummary> summary = Rxn<AgingSummary>();
  final RxBool loadingAging = false.obs;

  // ─── حالة المطابقة ───
  final Rxn<ReconciliationReport> reconciliation = Rxn<ReconciliationReport>();
  final RxBool loadingReconciliation = false.obs;
  final RxBool repairing = false.obs;

  /// نسبة المخصص المشكوك في تحصيله — تُقرأ من الإعدادات
  final RxDouble provisionRate = 0.25.obs;

  /// كاش أسماء الزبائن للبحث السريع في تقرير الأعمار
  final RxString searchQuery = ''.obs;

  @override
  void onInit() {
    super.onInit();
    loadAll();
  }

  Future<void> loadAll() async {
    await Future.wait([loadAging(), loadReconciliation()]);
  }

  /// تحميل تقرير أعمار الديون
  Future<void> loadAging() async {
    loadingAging.value = true;
    try {
      provisionRate.value = await DebtReportService.instance.provisionRate();
      final rows = await DebtReportService.instance.agingReport();
      agingRows.assignAll(rows);
      summary.value = DebtReportService.instance.summarize(rows);
    } catch (e) {
      debugPrint('loadAging error: $e');
    } finally {
      loadingAging.value = false;
    }
  }

  /// تحميل تقرير المطابقة
  Future<void> loadReconciliation() async {
    loadingReconciliation.value = true;
    try {
      reconciliation.value = await DebtReportService.instance.reconcile();
    } catch (e) {
      debugPrint('loadReconciliation error: $e');
    } finally {
      loadingReconciliation.value = false;
    }
  }

  /// إصلاح الأرصدة المختلّة — يعيد الاشتقاق من الفواتير ثم يُحدّث الشاشة.
  ///
  /// يرجع عدد الصفوف التي صُحّحت، أو **`-1`** عند رفض الصلاحية (فيُفرّق
  /// المستدعي بين «لا شيء لتصحيحه» و«لم أُنفّذ»)، أو `-2` عند خطأ فعلي.
  Future<int> repairBalances() async {
    repairing.value = true;
    try {
      final fixed = await DebtReportService.instance.repairBalances();
      await loadAll();
      return fixed;
    } catch (e) {
      debugPrint('repairBalances error: $e');
      return -2;
    } finally {
      repairing.value = false;
    }
  }

  /// الصفوف بعد تطبيق البحث النصي (اسم أو أي من الرقمين).
  ///
  /// تمرّ عبر محرّك البحث الموحّد `CustomerSearch` (خالص) فلا نسخة ثانية من
  /// المنطق: كانت `r.phone.contains(q)` — و`phone` رقم واحد فقط، وبمطابقة
  /// حرفية لا تتجاوز الفواصل ولا الأرقام العربية ⇒ رقم الزبون الثاني كان
  /// **غير قابل للبحث** و`0509 999 999` لا يجده `0509999999`.
  List<CustomerAgingRow> get filteredAging {
    final q = searchQuery.value.trim();
    if (q.isEmpty) return agingRows;
    return agingRows
        .where(
          (r) =>
              CustomerSearch.matches(r.toSearchMap(), q) ||
              r.customerId.toString() == q,
        )
        .toList(growable: false);
  }

  /// إجماليات الصفوف المعروضة بعد البحث — حتى لا تتناقض الترويسة مع الجدول
  AgingSummary get filteredSummary =>
      DebtReportService.instance.summarize(filteredAging);

  /// تسجيل دفعة سريعة لزبون من داخل تقرير الأعمار.
  ///
  /// تمرّ عبر نفس مسار المحرّك المحاسبي — لا منطق مالي مكرّر في الواجهة.
  /// ترتيب العمليات مقدّس: **سجل الدفتر أولًا** ثم التوزيع، وإلا اختلّت
  /// مطابقة الصندوق لأن الفاتورة تحمل مدفوعًا بلا حركة مقابلة.
  Future<bool> recordQuickPayment({
    required int customerId,
    required double amount,
    required int? userId,
  }) async {
    final cents = CustomerLedgerService.toCents(amount);
    if (cents <= 0) return false;
    try {
      await _db.safeInsert('customer_payments', {
        'customer_id': customerId,
        'amount': CustomerLedgerService.fromCents(cents),
        'payment_method': 'كاش',
        'payment_date': DateTime.now().toIso8601String(),
        'notes': 'دفعة سريعة من تقرير الذمم',
        'recorded_by': userId,
        'source': 'manual',
      });

      await CustomerLedgerService.instance.allocatePaymentFifo(
        customerId,
        cents,
      );

      await _db.logAudit(
        userId: userId,
        action: 'customer_payment',
        tableName: 'customers',
        recordId: customerId,
        newValues:
            '{"amount":${CustomerLedgerService.fromCents(cents)},"via":"debt_report_quick_pay"}',
      );

      await loadAll();
      return true;
    } catch (e) {
      debugPrint('recordQuickPayment error: $e');
      return false;
    }
  }
}
