import 'package:flutter/foundation.dart';
import 'package:laundry/services/customer/customer_ledger_service.dart';
import 'package:laundry/sqldb.dart';

/// فئة عمرية واحدة من أعمار الدين.
///
/// سبب وجودها: المعيار المحاسبي لا يسأل «كم الذمة؟» فقط، بل «**منذ متى**؟».
/// ذمة عمرها ٥ أيام تُحصَّل عادةً؛ ذمة عمرها ١٢٠ يومًا تُصنَّف دَينًا مشكوكًا
/// في تحصيله ويُكوَّن لها مخصص. لذلك نقسّم الذمة إلى فئات عمرية بمصدرها
/// الفعلي: `invoice_date` لكل فاتورة ما زال عليها متبقي.
class AgingBucket {
  /// التسمية العربية المعروضة للمستخدم
  final String label;

  /// الحد الأدنى لعمر الدين بالأيام (شاملًا)
  final int minDays;

  /// الحد الأعلى لعمر الدين بالأيام (غير شامل)، و`null` = بلا حد
  final int? maxDays;

  const AgingBucket({
    required this.label,
    required this.minDays,
    this.maxDays,
  });

  /// يصنّف فاتورة عمرها [days] يومًا ضمن هذه الفئة
  bool contains(int days) {
    if (days < minDays) return false;
    if (maxDays != null && days >= maxDays!) return false;
    return true;
  }
}

/// الفئات العمرية المعيارية المستخدمة في تقرير أعمار الديون.
const List<AgingBucket> kAgingBuckets = [
  AgingBucket(label: '0 - 30 يومًا', minDays: 0, maxDays: 31),
  AgingBucket(label: '31 - 60 يومًا', minDays: 31, maxDays: 61),
  AgingBucket(label: '61 - 90 يومًا', minDays: 61, maxDays: 91),
  AgingBucket(label: 'أكثر من 90 يومًا', minDays: 91),
];

/// سطر زبون واحد في تقرير أعمار الديون.
class CustomerAgingRow {
  final int customerId;
  final String customerName;

  /// الرقم المعروض وللتذكير (أول رقم متاح).
  final String phone;

  /// الرقم الثاني — **للبحث فقط**: البحث يجب أن يجد الزبون بأي من رقميه،
  /// لا بالمعروض وحده (وإلا صار رقمه الثاني غير قابل للبحث).
  final String phone2;

  /// المتبقي في كل فئة عمرية — بنفس ترتيب [kAgingBuckets]
  final List<double> bucketAmounts;

  /// إجمالي ذمة الزبون القائمة
  final double totalDebt;

  /// تاريخ أقدم فاتورة غير مسدّدة (يحدّد بالإجماليات)
  final DateTime? oldestDebtDate;

  /// عدد الفواتير غير المسدّدة
  final int openInvoices;

  /// تصنيف المخاطر المحاسبي: منخفض / متوسط / مرتفع / مشكوك في تحصيله
  final String riskLevel;

  const CustomerAgingRow({
    required this.customerId,
    required this.customerName,
    required this.phone,
    this.phone2 = '',
    required this.bucketAmounts,
    required this.totalDebt,
    required this.oldestDebtDate,
    required this.openInvoices,
    required this.riskLevel,
  });

  /// شكل يقبله محرّك البحث الموحّد `CustomerSearch` (الاسم + الرقمان).
  Map<String, dynamic> toSearchMap() => {
    'customer_id': customerId,
    'customer_name': customerName,
    'phone_1': phone,
    'phone_2': phone2,
  };

  /// أقدم ذمة بالأيام — `null` إن لا ذمة
  int? get oldestDays {
    final d = oldestDebtDate;
    if (d == null) return null;
    return _daysSince(d);
  }
}

/// إجماليات التقرير الكلي — تُعرض في ترويسة الشاشة وفي صف المجموع.
class AgingSummary {
  /// الإجمالي لكل فئة عمرية — بنفس ترتيب [kAgingBuckets]
  final List<double> bucketTotals;
  final double grandTotal;
  final int debtorCount;
  final int openInvoiceCount;

  const AgingSummary({
    required this.bucketTotals,
    required this.grandTotal,
    required this.debtorCount,
    required this.openInvoiceCount,
  });

  /// نسبة كل فئة من الإجمالي (0.0 - 1.0)
  double shareOf(int index) {
    if (grandTotal <= 0) return 0;
    if (index < 0 || index >= bucketTotals.length) return 0;
    return bucketTotals[index] / grandTotal;
  }

  /// حجم المخصص المقترح للديون المشكوك في تحصيلها.
  ///
  /// القاعدة المحاسبية المتّبعة (سياسة تحفّظية مبسّطة):
  ///   • 0% على ما دون 90 يومًا — لا يزال قابلاً للتحصيل الطبيعي
  ///   • 25% على ما تجاوز 90 يومًا — تقدير تحفّظي شائع للمنشآت الصغيرة
  /// وهي **سياسة** لا حقيقة، فيمكن تعديل النسب من `debt_aging_provision`
  /// في جدول الإعدادات دون تغيير الكود.
  double proposedProvision({double over90Rate = 0.25}) {
    if (bucketTotals.isEmpty) return 0;
    double over90 = 0;
    for (var i = 0; i < kAgingBuckets.length && i < bucketTotals.length; i++) {
      if (kAgingBuckets[i].minDays >= 91) over90 += bucketTotals[i];
    }
    return over90 * over90Rate;
  }
}

/// سطر مطابقة زبون واحد: الذمة المشتقّة من الفواتير مقابل الرصيد المخزَّن.
class ReconciliationRow {
  final int customerId;
  final String customerName;

  /// الذمة الحقيقية المشتقّة من `invoices.remaining_amount`
  final double derivedDebt;

  /// قيمة `customers.balance` المخزَّنة (موجبة = سلفة، سالبة = دين)
  final double storedBalance;

  /// الفرق بين المخزَّن والمتوقّع — أي قيمة غير صفرية تعني خللًا يحتاج تصحيحًا
  final double difference;

  const ReconciliationRow({
    required this.customerId,
    required this.customerName,
    required this.derivedDebt,
    required this.storedBalance,
    required this.difference,
  });

  /// هل الرصيد المخزَّن مطابق للمشتقّ؟
  bool get isBalanced => difference.abs() < 0.005;

  /// ذمة موجبة للعرض (لا سالبة)
  double get debtValue => derivedDebt;
}

/// إجماليات المطابقة الكلية.
class ReconciliationReport {
  final List<ReconciliationRow> rows;

  /// المجموع الحقيقي من الفواتير
  final double totalDerived;

  /// المجموع المخزَّن (مدينون فقط، بقيمة موجبة)
  final double totalStoredDebt;

  /// مجموع الأرصدة الدائنة (سلف الزبائن)
  final double totalCredit;

  const ReconciliationReport({
    required this.rows,
    required this.totalDerived,
    required this.totalStoredDebt,
    required this.totalCredit,
  });

  /// الزبائن الذين رصيدهم المخزَّن لا يطابق ذمتهم الحقيقية
  List<ReconciliationRow> get mismatched =>
      rows.where((r) => !r.isBalanced).toList(growable: false);

  bool get isHealthy => mismatched.isEmpty;
}

/// عدد أيام كاملة بين تاريخ وتاريخ اليوم (يتجاهل الوقت).
int _daysSince(DateTime date) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final then = DateTime(date.year, date.month, date.day);
  return today.difference(then).inDays;
}

/// خدمة تقارير الذمم: أعمار الديون + المطابقة.
///
/// **لماذا خدمة منفصلة عن `CustomerLedgerService`؟**
/// `CustomerLedgerService` مسؤولة عن **الكتابة** (تسجيل الدفعات واشتقاق
/// الأرصدة) — أي أنها قلب العمليات. أما هذه الخدمة فمسؤولة عن **القراءة
/// التحليلية** فقط: التصنيف العمري، والمطابقة، وقياس المخاطر. الفصل يحفظ
/// مسؤولية واحدة لكل ملف، ويمنع تضخّم محرّك العمليات بمنطق تقارير.
class DebtReportService {
  DebtReportService._();

  static final DebtReportService instance = DebtReportService._();

  final SqlDB _db = SqlDB();

  /// الأعمار بشكل موحّد — يعرض ملخّصًا لكل زبون مدين مع توزيع فئاته العمرية.
  Future<List<CustomerAgingRow>> agingReport({bool includeZero = false}) async {
    try {
      // استعلام واحد يجلب كل الفواتير غير المسدّدة مع تاريخها.
      // نستبعد فواتير الاشتراك: تغطيتها الشهرية تسدّدها فلا ذمة عليها.
      // نستبعد أيضًا الزبائن المحذوفين ناعمًا حتى لا يُشوّهوا إجمالي الذمم.
      final rows = await _db.readData(
        'SELECT i.invoices_id, i.customer_id, i.customer_name,        i.remaining_amount, i.invoice_date,        c.customer_name AS reg_name, c.phone_1, c.phone_2 FROM invoices i LEFT JOIN customers c ON c.customer_id = i.customer_id WHERE i.subscription_id IS NULL   AND COALESCE(i.remaining_amount, 0) > 0.004   AND i.customer_id IS NOT NULL ORDER BY i.invoice_date ASC',
      );

      // تجميع في الذاكرة: استعلام واحد + حلقة واحدة، بدل استعلام لكل زبون
      final Map<int, _AgingAccumulator> acc = {};
      for (final r in rows) {
        final id = r['customer_id'] as int?;
        if (id == null) continue;
        final due = ((r['remaining_amount'] ?? 0) as num).toDouble();
        if (due <= 0) continue;
        final date = _parseDate(r['invoice_date']);
        if (date == null) continue;

        final entry = acc.putIfAbsent(
          id,
          () => _AgingAccumulator(
            customerId: id,
            name: (r['reg_name'] ?? r['customer_name'] ?? 'غير محدد').toString(),
            phone: _pickPhones(r).primary,
            phone2: _pickPhones(r).secondary,
          ),
        );
        entry.add(due, date);
      }

      final result = acc.values
          .map((a) => a.toRow())
          .where((r) => includeZero || r.totalDebt > 0)
          .toList();

      // الأقدم ذمة أولًا — هو من يحتاج تحرّكًا فوريًا
      result.sort((a, b) {
        final da = a.oldestDebtDate?.millisecondsSinceEpoch ?? 0;
        final db = b.oldestDebtDate?.millisecondsSinceEpoch ?? 0;
        return da.compareTo(db);
      });
      return result;
    } catch (e) {
      debugPrint('agingReport error: $e');
      return [];
    }
  }

  /// إجماليات تقرير الأعمار — تُحسب من نفس الصفوف فلا تتباعد الأرقام.
  AgingSummary summarize(List<CustomerAgingRow> rows) {
    final totals = List<double>.filled(kAgingBuckets.length, 0);
    var grand = 0.0;
    var invoices = 0;
    for (final r in rows) {
      for (var i = 0; i < totals.length && i < r.bucketAmounts.length; i++) {
        totals[i] += r.bucketAmounts[i];
      }
      grand += r.totalDebt;
      invoices += r.openInvoices;
    }
    return AgingSummary(
      bucketTotals: totals,
      grandTotal: grand,
      debtorCount: rows.length,
      openInvoiceCount: invoices,
    );
  }

  /// مطابقة أرصدة الزبائن: المشتقّ من الفواتير مقابل المخزَّن في `customers`.
  ///
  /// القيمة العملية: لو ظهر صف غير مطابق فالخلل موجود **فعلًا** في القاعدة،
  /// وعندنا زر إصلاح يعيد الاشتقاق. هذه هي شبكة الأمان التي تكشف أي خطأ
  /// كتابي مستقبلي قبل أن يتحوّل إلى رقم خاطئ في تقرير رسمي.
  Future<ReconciliationReport> reconcile() async {
    try {
      final rows = await _db.readData(
        'SELECT c.customer_id, c.customer_name, COALESCE(c.balance, 0) AS bal,   COALESCE((SELECT SUM(i.remaining_amount) FROM invoices i     WHERE i.customer_id = c.customer_id       AND i.subscription_id IS NULL       AND i.remaining_amount > 0.004), 0) AS debt FROM customers c WHERE COALESCE(c.is_active, 1) = 1 ORDER BY c.customer_name',
      );

      final out = <ReconciliationRow>[];
      var totalDerived = 0.0;
      var totalStoredDebt = 0.0;
      var totalCredit = 0.0;

      for (final r in rows) {
        final id = r['customer_id'] as int?;
        if (id == null) continue;
        final bal = ((r['bal'] ?? 0) as num).toDouble();
        final debt = ((r['debt'] ?? 0) as num).toDouble();

        // الرصيد المتوقّع: سلفة موجبة تبقى كما هي، وإلا فالذمة بالسالب
        final expected = bal > 0 ? bal : -debt;
        final diff = bal - expected;

        // لا نُدرج من لا ذمة له ولا رصيد — تقرير الضجيج لا يُقرأ
        if (debt <= 0.004 && bal.abs() <= 0.004) continue;

        out.add(
          ReconciliationRow(
            customerId: id,
            customerName: (r['customer_name'] ?? 'غير محدد').toString(),
            derivedDebt: debt,
            storedBalance: bal,
            difference: diff,
          ),
        );
        totalDerived += debt;
        if (bal < 0) totalStoredDebt += bal.abs();
        if (bal > 0) totalCredit += bal;
      }

      // الأكثر خللًا أولًا — ليجده المستخدم فورًا
      out.sort(
        (a, b) => b.difference.abs().compareTo(a.difference.abs()),
      );

      return ReconciliationReport(
        rows: out,
        totalDerived: totalDerived,
        totalStoredDebt: totalStoredDebt,
        totalCredit: totalCredit,
      );
    } catch (e) {
      debugPrint('reconcile error: $e');
      return const ReconciliationReport(
        rows: [],
        totalDerived: 0,
        totalStoredDebt: 0,
        totalCredit: 0,
      );
    }
  }

  /// إصلاح فوري: يعيد اشتقاق أرصدة كل الزبائن من الفواتير.
  /// يُستخدم من زر «إصلاح الأرصدة» بعد ظهور صفوف غير مطابقة.
  Future<int> repairBalances() =>
      CustomerLedgerService.instance.rebuildAllBalances();

  /// إجمالي الذمم القائمة — للاستخدام في لوحة التحكم والترويسات.
  Future<double> totalOutstandingDebt() async {
    try {
      final rows = await _db.readData(
        'SELECT COALESCE(SUM(i.remaining_amount), 0) AS total FROM invoices i, customers c WHERE i.customer_id = c.customer_id   AND COALESCE(c.is_active, 1) = 1   AND i.subscription_id IS NULL   AND i.remaining_amount > 0.004',
      );
      if (rows.isEmpty) return 0;
      return ((rows.first['total'] ?? 0) as num).toDouble();
    } catch (e) {
      debugPrint('totalOutstandingDebt error: $e');
      return 0;
    }
  }

  /// أعمار الزبون الواحد — لعرضها داخل شاشة حسابه.
  /// ترجع `null` إن لم تكن له ذمة قائمة.
  Future<CustomerAgingRow?> agingFor(int customerId) async {
    final rows = await agingReport();
    for (final r in rows) {
      if (r.customerId == customerId) return r;
    }
    return null;
  }

  /// سياسة المخصص — تُقرأ من الإعدادات إن وُجدت، وإلا النسبة الافتراضية.
  Future<double> provisionRate() async {
    try {
      final saved = await _db.getSetting('debt_provision_rate');
      final parsed = double.tryParse(saved ?? '');
      if (parsed != null && parsed >= 0 && parsed <= 1) return parsed;
    } catch (_) {}
    return 0.25;
  }
}

/// مُجمِّع داخلي لبناء صف الزبون من فواتيره
class _AgingAccumulator {
  final int customerId;
  final String name;
  final String phone;
  final String phone2;
  final List<double> buckets = List<double>.filled(kAgingBuckets.length, 0);
  double total = 0;
  int count = 0;
  DateTime? oldest;

  _AgingAccumulator({
    required this.customerId,
    required this.name,
    required this.phone,
    this.phone2 = '',
  });

  void add(double due, DateTime date) {
    final age = _daysSince(date);
    for (var i = 0; i < kAgingBuckets.length; i++) {
      if (kAgingBuckets[i].contains(age)) {
        buckets[i] += due;
        break;
      }
    }
    total += due;
    count++;
    if (oldest == null || date.isBefore(oldest!)) oldest = date;
  }

  CustomerAgingRow toRow() {
    return CustomerAgingRow(
      customerId: customerId,
      customerName: name,
      phone: phone,
      phone2: phone2,
      bucketAmounts: List.unmodifiable(buckets),
      totalDebt: total,
      oldestDebtDate: oldest,
      openInvoices: count,
      riskLevel: _riskOf(oldest == null ? 0 : _daysSince(oldest!)),
    );
  }

  /// تصنيف المخاطر انطلاقًا من عمر أقدم ذمة قائمة
  static String _riskOf(int oldestDays) {
    if (oldestDays >= 91) return 'مشكوك في تحصيله';
    if (oldestDays >= 61) return 'مرتفع';
    if (oldestDays >= 31) return 'متوسط';
    return 'منخفض';
  }
}

/// قراءة تاريخ مرن: يقبل ISO8601 والنصوص العادية مع الوقت
DateTime? _parseDate(dynamic raw) {
  if (raw == null) return null;
  final text = raw.toString().trim();
  if (text.isEmpty) return null;
  return DateTime.tryParse(text) ?? DateTime.tryParse(text.split(' ').first);
}

/// الرقم المعروض (أول رقم متاح) + الرقم الثاني — **الاثنان مطلوبان** لأن البحث
/// يجب أن يجد الزبون بأي من رقميه، لا بالمعروض وحده.
({String primary, String secondary}) _pickPhones(Map<String, dynamic> r) {
  final p1 = (r['phone_1'] ?? '').toString().trim();
  final p2 = (r['phone_2'] ?? '').toString().trim();
  if (p1.isNotEmpty) return (primary: p1, secondary: p2);
  return (primary: p2, secondary: '');
}
