import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:laundry/services/expense/expense_service.dart';
import 'package:laundry/services/invoice/invoice_items_service.dart';
import 'package:laundry/services/permission/permission_catalog.dart';
import 'package:laundry/services/permission/permission_service.dart';
import 'package:laundry/services/tax/vat_return.dart';
import 'package:laundry/services/subscription/subscription_service.dart';
import 'package:laundry/sqldb.dart';

class ReportController extends GetxController {
  final SqlDB _db = SqlDB();

  var dailyReport = <String, dynamic>{}.obs;
  var weeklyReport = <String, dynamic>{}.obs;
  var monthlyReport = <String, dynamic>{}.obs;
  var annualReport = <String, dynamic>{}.obs;
  var customerReport = <String, dynamic>{}.obs;
  var itemReport = <String, dynamic>{}.obs;
  var isLoading = false.obs;

  /// يُنقّي مقاييس التقرير بحسب الصلاحيات **قبل** أن تصل إلى الواجهة.
  ///
  /// 🛡️ `reports.profit` و`reports.tax` كانا **معلنَين بلا إنفاذ**: أي مستخدم
  /// يفتح شاشة التقارير (`reports.view`) يرى هامش الربح والضريبة، ولو أُسقطت
  /// عنه الصلاحيتان من شاشة الأدوار. حزمة «كاشير» لا تحمل `reports.profit`
  /// أصلًا — لكن الفحص في الواجهة وحدها لا يكفي، فالتنقية هنا في المتحكّم:
  /// القيمة **لا تُحسب في الخريطة** التي تصل إلى الشاشة إطلاقًا.
  ///
  /// الحجب بـ`null` لا بالصفر: الصفر رقم كاذب («ربحت صفرًا») و`null` يعني
  /// «غير مصرَّح»، والواجهة تُخفي بطاقته كليًّا.
  Map<String, dynamic> _guardMetrics(Map<String, dynamic> report) {
    final out = Map<String, dynamic>.from(report);
    if (!PermissionService.can(PermissionKeys.reportsProfit)) {
      out['total_cost'] = null;
      out['gross_profit'] = null;
      out['net_profit'] = null;
      out['expenses'] = null;
    }
    if (!PermissionService.can(PermissionKeys.reportsTax)) {
      out['total_tax'] = null;
    }
    return out;
  }

  /// تكلفة القطع المُغسلة في فترة محددة (تكلفة كل قطعة × كميتها)،
  /// بنفس منطق لوحة التحكم، وتُستخدم لخصمها من المبيعات لحساب صافي الربح.
  /// مرّر `singleDate` ليوم واحد، أو `startStr`/`endStr` لفترة.
  ///
  /// [includeSubscriptions] — **إصلاح جوهري**: المبيعات (`total_sales`) تستثني
  /// فواتير الاشتراكات `subscription_id IS NULL`، لكن التكلفة كانت **تشملها**
  /// دائمًا. النتيجة: كل فاتورة اشتراك كانت تُخصم كمصروف بلا إيراد يقابلها،
  /// فيظهر صافي الربح سالبًا على الدوام. الآن الاستثناء متطابق على الطرفين،
  /// والتكلفة تُحسب صراحةً للجانبين ثم تُقارن بالرقمين المقابلين.
  Future<double> _costForRange({
    String? singleDate,
    String? startStr,
    String? endStr,
    bool includeSubscriptions = false,
  }) async {
    try {
      final String clause;
      final List<dynamic> args;
      if (singleDate != null) {
        clause = 'DATE(i.invoice_date) = ?';
        args = [singleDate];
      } else if (endStr != null) {
        clause =
            'DATE(i.invoice_date) >= ? AND DATE(i.invoice_date) <= ?';
        args = [startStr, endStr];
      } else {
        clause = 'DATE(i.invoice_date) >= ?';
        args = [startStr];
      }
      // مطابقة الطرفين: نفس فلتر الاشتراكات المُطبَّق على المبيعات
      final subClause = includeSubscriptions
          ? 'AND i.subscription_id IS NOT NULL'
          : 'AND i.subscription_id IS NULL';
      // ─── التكلفة من لقطة البنود لا من الربط بالاسم ───
      // الربط بالاسم كان يصفّر التكلفة عند إعادة تسمية صنف، ويقرأ
      // `cost_price` الحالية فيُعيد كتابة أرباح الماضي عند تعديلها.
      // والخدمة تُبقي رجوعًا احتياطيًا للفواتير بلا لقطة.
      return await InvoiceItemsService.instance.costFor(
        where: '$clause $subClause',
        args: args,
      );
    } catch (e) {
      debugPrint('report cost error: $e');
      return 0;
    }
  }

  /// ضريبة القيمة المضافة على مبيعات نطاق زمني.
  ///
  /// **لماذا تُخصم من الربح؟** لأن `final_amount` هو ما دفعه الزبون
  /// **شاملًا** الضريبة، والضريبة **التزام** على المنشأة تُورَّد للهيئة لا
  /// إيراد لها. إغفالها يجعل «صافي الربح» أعلى من الحقيقة بمقدار الضريبة
  /// كلها — أي ربحًا وهميًا يظهر في كل تقرير.
  ///
  /// وتُعاد صفرًا تلقائيًا حين يكون `tax_enabled` معطَّلًا، لأن العمود يبقى
  /// صفرًا في كل فاتورة.
  Future<double> _taxForRange({
    String? singleDate,
    String? startStr,
    String? endStr,
    bool includeSubscriptions = false,
  }) async {
    try {
      final String clause;
      final List<dynamic> args;
      if (singleDate != null) {
        clause = 'DATE(invoice_date) = ?';
        args = [singleDate];
      } else if (endStr != null) {
        clause = 'DATE(invoice_date) >= ? AND DATE(invoice_date) <= ?';
        args = [startStr, endStr];
      } else {
        clause = 'DATE(invoice_date) >= ?';
        args = [startStr];
      }
      // مطابقة الطرفين: نفس فلتر الاشتراكات المُطبَّق على المبيعات
      final subClause = includeSubscriptions
          ? 'AND subscription_id IS NOT NULL'
          : 'AND subscription_id IS NULL';
      final rows = await _db.readData(
        'SELECT COALESCE(SUM(COALESCE(tax_amount, 0)), 0) AS tax FROM invoices WHERE $clause $subClause',
        args,
      );
      return (rows.firstOrNull?['tax'] as num?)?.toDouble() ?? 0;
    } catch (e) {
      debugPrint('report tax error: $e');
      return 0;
    }
  }

  /// **الإقرار الضريبي** لفترة: ضريبة مخرجات (الفواتير) − ضريبة مدخلات
  /// (المصروفات) = الصافي المستحق.
  ///
  /// يُجمَّع داخل القاعدة بلا تحميل صفوف، ويُعاد صفرًا تلقائيًا حين تكون
  /// الضريبة معطَّلة أو الأعمدة غائبة (قاعدة قديمة).
  Future<VatReturn> vatReturnFor({
    required String startStr,
    required String endStr,
  }) async {
    try {
      final invoiceRows = await _db.readData(
        'SELECT COALESCE(SUM(COALESCE(tax_base, 0)), 0) AS base, COALESCE(SUM(COALESCE(tax_amount, 0)), 0) AS tax, COALESCE(SUM(COALESCE(tax_exempt_amount, 0)), 0) AS exempt, COUNT(*) AS n FROM invoices WHERE DATE(invoice_date) >= ? AND DATE(invoice_date) <= ?',
        [startStr, endStr],
      );
      final inv = invoiceRows.firstOrNull ?? const {};
      final from = DateTime.tryParse(startStr) ?? DateTime.now();
      final to = DateTime.tryParse(endStr) ?? DateTime.now();
      final inputTax = await ExpenseService.instance.inputVatFor(
        from: from,
        to: to,
      );
      final expenseTotal = await _expensesFor(startStr, endStr);
      return VatReturn.compute(
        salesBase: (inv['base'] as num?)?.toDouble() ?? 0,
        outputTax: (inv['tax'] as num?)?.toDouble() ?? 0,
        exemptSales: (inv['exempt'] as num?)?.toDouble() ?? 0,
        invoiceCount: (inv['n'] as num?)?.toInt() ?? 0,
        purchasesBase: expenseTotal - inputTax,
        inputTax: inputTax,
      );
    } catch (e) {
      debugPrint('vatReturnFor error: $e');
      return VatReturn.empty;
    }
  }

  /// مصروفات التشغيل في نطاق زمني.
  ///
  /// التواريخ تصل بصيغة `yyyy-MM-dd` (نصية) بينما `expenses.date` مخزَّن
  /// ISO8601 — لذا نقارن بـ`DATE(date)` **بلا** `'localtime'` ليتوافق الطرفان.
  ///
  /// ⚠️ `'localtime'` هنا كانت تحويلًا **مزدوجًا**: `expenses.date` مخزَّن
  /// محليًا أصلًا (لا `toUtc()` في المشروع)، فإضافة `'localtime'` تُزيح كل
  /// مصروف بعد 21:00 محليًا (UTC+3) إلى اليوم التالي فيسقط من نطاقه.
  /// القياس في `tool/verify_localtime_removal.py`.
  ///
  /// `endStr` قد يكون فاتح الشهر التالي (نهاية حصرية) فنطرح يومًا واحدًا.
  Future<double> _expensesFor(String startStr, String endStr) async {
    try {
      final start = DateTime.tryParse(startStr);
      var end = DateTime.tryParse(endStr);
      if (start == null || end == null) return 0;
      // النطاق حصري في النهاية عند تمرير فاتح الشهر التالي
      if (endStr.endsWith('-01') && !_sameDay(end, start)) {
        end = end.subtract(const Duration(days: 1));
      }
      final s = ExpenseService.dayKey(start);
      final e = ExpenseService.dayKey(end);
      final rows = await _db.readData(
        'SELECT COALESCE(SUM(amount), 0) AS total FROM expenses '
        "WHERE DATE(date) >= ? AND DATE(date) <= ?",
        [s, e],
      );
      return (rows.first['total'] ?? 0).toDouble();
    } catch (e) {
      debugPrint('_expensesFor error: $e');
      return 0;
    }
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  /// إجمالي أرصدة الزبائن الموجبة (ما لنا عليهم من أرصدة)
  Future<double> _totalCustomerCredits() async {
    try {
      final rows = await _db.readData(
        'SELECT COALESCE(SUM(balance), 0) AS total FROM customers WHERE balance > 0',
      );
      return (rows.first['total'] ?? 0).toDouble();
    } catch (e) {
      return 0;
    }
  }

  /// 💰 الإيراد **المُعترف به** من الاشتراكات في فترة.
  ///
  /// المبدأ المحاسبي (revenue recognition): الدفعة المقدَّمة مقابل خدمة تُقدَّم
  /// لاحقًا **ليست إيرادًا** لحظة قبضها، بل التزام (إيراد مؤجَّل). الإيراد
  /// يُعترف به عند **تقديم الخدمة**، أي عند استهلاك الغسيل فعلًا.
  ///
  /// لذلك نقيس الإيراد بقيمة الغسيل المُستهلك من الفواتير المرتبطة
  /// (`subscription_used_value`)، لا بمجموع `subscription_payments`. هذا
  /// يُطابق الإيراد بالتكلفة في نفس الفترة، فيصبح صافي الربح ذا معنى.
  Future<double> _recognizedSubRevenue(String startStr, String endStr) async {
    try {
      // ⚠️ **COALESCE على مستوى الصف لا على مستوى الإجمالي.**
      //
      // الكود السابق كان:
      //   final stored = SUM(subscription_used_value);
      //   if (stored > 0) return stored;          // ← الشرط على الإجمالي
      //   return DERIVED_FROM_list_data;          // ← يستبدل المجموع كله
      //
      // الدلالة: `subscription_used_value` = القيمة المستهلكة **من رصيد
      // الاشتراك المدفوع مقدمًا**، و`list_data.total_price` = **سعر القائمة**.
      // الخدمة المغطّاة بالكامل داخل الاشتراك لها مخزَّن = **صفر مشروع** (لم
      // تُخصم من الرصيد لأنها داخل السقف) بينما سعر قائمتها مرتفع. فإذا كان
      // مجموع الفترة صفرًا — أو كانت كل الصفوف حديثة بقيمة صفر — كان الشرط
      // يفشل فيُرجع **سعر القائمة كله** إيرادًا معترفًا به.
      //
      // الأثر المُثبَت عدديًا (tool/verify_report_revenue_fallback.py):
      //   خدمة مجانية سعر قائمتها 500 ⇒ الإيراد المبلَّغ عنه 500 (والصحيح 0)
      //   فترة مختلطة ⇒ 130 بدل 50
      //
      // الصحيح: يأخذ المخزَّن **إن وُجد** (حتى لو صفرًا — وهو صفر مشروع)،
      // ويشتقّ فقط للصفوف القديمة التي لا تملك العمود أصلًا.
      final rows = await _db.readData(
        'SELECT COALESCE(SUM(COALESCE(i.subscription_used_value, (  SELECT COALESCE(SUM(CAST(json_extract(j.value, \'\$.total_price\')     AS REAL)), 0) FROM json_each(i.list_data) j))), 0) AS total FROM invoices i WHERE i.subscription_id IS NOT NULL '
        "  AND DATE(i.invoice_date) >= ? "
        "  AND DATE(i.invoice_date) <= ?",
        [startStr, endStr],
      );
      return (rows.first['total'] ?? 0).toDouble();
    } catch (e) {
      debugPrint('_recognizedSubRevenue error: $e');
      return 0;
    }
  }

  /// النقدية **المحصَّلة** فعليًا من دفعات الاشتراكات (لا الإيراد المُعترف به).
  /// يُعرض للتدقيق النقدي ومطابقة إقفال الوردية، لا لحساب الربح.
  Future<double> _collectedSubPayments(String startStr, String endStr) async {
    try {
      final rows = await _db.readData(
        'SELECT COALESCE(SUM(amount), 0) AS total FROM subscription_payments '
        "WHERE DATE(paid_date) >= ? AND DATE(paid_date) <= ? "
        "  AND COALESCE(source, 'manual') != 'cancel_refund'",
        [startStr, endStr],
      );
      return (rows.first['total'] ?? 0).toDouble();
    } catch (e) {
      debugPrint('_collectedSubPayments error: $e');
      return 0;
    }
  }

  /// الالتزام المتبقّي لوحدة الاشتراكات (إيراد مؤجَّل) — خدمة مضمونة لم
  /// تُقدَّم بعد. يُطرح من الربح في التقارير الإدارية لأنه ليس ملكًا للمحل بعد.
  Future<double> subscriptionLiability() async {
    try {
      final svc = await SubscriptionService.instance.financials();
      return svc.deferred;
    } catch (e) {
      debugPrint('subscriptionLiability error: $e');
      return 0;
    }
  }

  Future<Map<String, dynamic>> generateDailyReport({DateTime? date}) async {
    isLoading.value = true;
    try {
      final targetDate = date ?? DateTime.now();
      final dateStr = DateFormat('yyyy-MM-dd').format(targetDate);

      final salesData = await _db.readData(
        'SELECT COALESCE(SUM(final_amount), 0) AS total_sales, COALESCE(SUM(paid_amount), 0) AS total_paid, COALESCE(SUM(remaining_amount), 0) AS total_remaining, COUNT(CASE WHEN COALESCE(credit_note_of, 0) = 0 THEN 1 END) AS invoice_count FROM invoices WHERE DATE(invoice_date) = ? AND subscription_id IS NULL',
        [dateStr],
      );

      final topItems = await _db.readData(
        'SELECT c.clothing_name, COUNT(*) AS times_sold FROM invoices i, json_each(i.list_data) j, clothing c WHERE json_extract(j.value, \'\$.vestments\') = c.clothing_name AND COALESCE(i.credit_note_of, 0) = 0 AND DATE(i.invoice_date) = ? GROUP BY c.clothing_name ORDER BY times_sold DESC LIMIT 10',
        [dateStr],
      );

      final paymentBreakdown = await _db.readData(
        'SELECT payment_method, COUNT(*) AS count, COALESCE(SUM(final_amount), 0) AS total FROM invoices WHERE DATE(invoice_date) = ? GROUP BY payment_method',
        [dateStr],
      );

      final totalSales = (salesData.first['total_sales'] ?? 0).toDouble();

      // 💰 إيراد الاشتراكات = **المُعترف به** (قيمة الغسيل المُستهلك) لا
      // المحصَّل. الفرق هو الالتزام المتبقّي: ما دُفع ولم تُقدَّم خدمته بعد
      // ليس ربحًا، بل خدمة مضمونة على المحل. الاعتراف بالمحصَّل كان يضخّم
      // الربح ويخفي الالتزام.
      final subRevenue = await _recognizedSubRevenue(dateStr, dateStr);

      final totalCost = await _costForRange(singleDate: dateStr);
      final subCost = await _costForRange(
        singleDate: dateStr,
        includeSubscriptions: true,
      );
      // الضريبة ليست إيرادًا — تُخصم من المبيعات قبل حساب الربح
      final totalTax = await _taxForRange(singleDate: dateStr);
      final customerCredits = await _totalCustomerCredits();
      // مصروفات التشغيل — كانت **غائبة تمامًا** من كل حساب ربح، فكان
      // «صافي الربح» ربحًا مساهمًا لا ربحًا. الآن تُخصم فعليًا.
      final expenseTotal = await _expensesFor(dateStr, dateStr);

      final report = {
        'date': dateStr,
        'total_sales': totalSales,
        // إجمالي الإيراد المُعترف به = مبيعات عادية + خدمة اشتراكات مُستهلكة
        'total_revenue': totalSales + subRevenue,
        'total_paid': (salesData.first['total_paid'] ?? 0).toDouble(),
        'total_remaining': (salesData.first['total_remaining'] ?? 0).toDouble(),
        'invoice_count': salesData.first['invoice_count'] ?? 0,
        'total_cost': totalCost,
        'subscription_cost': subCost,
        'expenses': expenseTotal,
        'total_tax': totalTax,
        // الربح المساهم = الإيراد **صافي الضريبة** − تكلفة الخدمة
        'gross_profit':
            (totalSales - totalTax) + subRevenue - totalCost - subCost,
        // صافي الربح = الربح المساهم − مصروفات التشغيل
        'net_profit':
            (totalSales - totalTax) +
            subRevenue -
            totalCost -
            subCost -
            expenseTotal,
        'subscription_revenue': subRevenue,
        'subscription_collected': await _collectedSubPayments(
          dateStr,
          dateStr,
        ),
        'customer_credits': customerCredits,
        'top_items': topItems,
        'payment_breakdown': paymentBreakdown,
      };

      final guarded = _guardMetrics(report);
      dailyReport.value = guarded;
      return guarded;
    } finally {
      isLoading.value = false;
    }
  }

  Future<Map<String, dynamic>> generateWeeklyReport({
    DateTime? startDate,
  }) async {
    isLoading.value = true;
    try {
      final targetStart =
          startDate ??
          DateTime.now().subtract(Duration(days: DateTime.now().weekday - 1));
      final targetEnd = targetStart.add(const Duration(days: 6));
      final startStr = DateFormat('yyyy-MM-dd').format(targetStart);
      final endStr = DateFormat('yyyy-MM-dd').format(targetEnd);

      final salesData = await _db.readData(
        'SELECT COALESCE(SUM(final_amount), 0) AS total_sales, COALESCE(SUM(paid_amount), 0) AS total_paid, COALESCE(SUM(remaining_amount), 0) AS total_remaining, COUNT(CASE WHEN COALESCE(credit_note_of, 0) = 0 THEN 1 END) AS invoice_count FROM invoices WHERE DATE(invoice_date) BETWEEN ? AND ? AND subscription_id IS NULL',
        [startStr, endStr],
      );

      final dailyBreakdown = await _db.readData(
        'SELECT DATE(invoice_date) AS day, COALESCE(SUM(final_amount), 0) AS sales, COUNT(CASE WHEN COALESCE(credit_note_of, 0) = 0 THEN 1 END) AS invoices FROM invoices WHERE DATE(invoice_date) BETWEEN ? AND ? GROUP BY DATE(invoice_date) ORDER BY day',
        [startStr, endStr],
      );

      final totalSales = (salesData.first['total_sales'] ?? 0).toDouble();

      // الإيراد المُعترف به من الاشتراكات (خدمة مُستهلكة لا نقدية مقبوضة)
      final subRevenue = await _recognizedSubRevenue(startStr, endStr);

      final totalCost = await _costForRange(startStr: startStr, endStr: endStr);
      final subCost = await _costForRange(
        startStr: startStr,
        endStr: endStr,
        includeSubscriptions: true,
      );
      // الضريبة ليست إيرادًا — تُخصم من المبيعات قبل حساب الربح
      final totalTax = await _taxForRange(startStr: startStr, endStr: endStr);
      final customerCredits = await _totalCustomerCredits();
      final expenseTotal = await _expensesFor(startStr, endStr);

      final report = {
        'start_date': startStr,
        'end_date': endStr,
        'total_sales': totalSales,
        'total_revenue': totalSales + subRevenue,
        'total_paid': (salesData.first['total_paid'] ?? 0).toDouble(),
        'total_remaining': (salesData.first['total_remaining'] ?? 0).toDouble(),
        'invoice_count': salesData.first['invoice_count'] ?? 0,
        'total_cost': totalCost,
        'subscription_cost': subCost,
        'expenses': expenseTotal,
        'total_tax': totalTax,
        'gross_profit':
            (totalSales - totalTax) + subRevenue - totalCost - subCost,
        'net_profit':
            (totalSales - totalTax) +
            subRevenue -
            totalCost -
            subCost -
            expenseTotal,
        'subscription_revenue': subRevenue,
        'subscription_collected': await _collectedSubPayments(startStr, endStr),
        'customer_credits': customerCredits,
        'daily_breakdown': dailyBreakdown,
      };

      final guarded = _guardMetrics(report);
      weeklyReport.value = guarded;
      return guarded;
    } finally {
      isLoading.value = false;
    }
  }

  Future<Map<String, dynamic>> generateMonthlyReport({
    int? year,
    int? month,
  }) async {
    isLoading.value = true;
    try {
      final now = DateTime.now();
      final targetYear = year ?? now.year;
      final targetMonth = month ?? now.month;
      final monthStr = DateFormat(
        'yyyy-MM',
      ).format(DateTime(targetYear, targetMonth));
      final nextMonth = DateFormat(
        'yyyy-MM',
      ).format(DateTime(targetYear, targetMonth + 1));

      final salesData = await _db.readData(
        'SELECT COALESCE(SUM(final_amount), 0) AS total_sales, COALESCE(SUM(paid_amount), 0) AS total_paid, COALESCE(SUM(remaining_amount), 0) AS total_remaining, COUNT(CASE WHEN COALESCE(credit_note_of, 0) = 0 THEN 1 END) AS invoice_count FROM invoices WHERE DATE(invoice_date) >= ? AND DATE(invoice_date) < ? AND subscription_id IS NULL',
        ['$monthStr-01', '$nextMonth-01'],
      );

      final weeklyBreakdown = await _db.readData(
        'SELECT strftime("%W", invoice_date) AS week, COALESCE(SUM(final_amount), 0) AS sales, COUNT(CASE WHEN COALESCE(credit_note_of, 0) = 0 THEN 1 END) AS invoices FROM invoices WHERE DATE(invoice_date) >= ? AND DATE(invoice_date) < ? GROUP BY strftime("%W", invoice_date) ORDER BY week',
        ['$monthStr-01', '$nextMonth-01'],
      );

      final topItems = await _db.readData(
        'SELECT c.clothing_name, COUNT(*) AS times_sold FROM invoices i, json_each(i.list_data) j, clothing c WHERE json_extract(j.value, \'\$.vestments\') = c.clothing_name AND COALESCE(i.credit_note_of, 0) = 0 AND DATE(i.invoice_date) >= ? AND DATE(i.invoice_date) < ? GROUP BY c.clothing_name ORDER BY times_sold DESC LIMIT 10',
        ['$monthStr-01', '$nextMonth-01'],
      );

      final totalSales = (salesData.first['total_sales'] ?? 0).toDouble();

      // نطاق الشهر كاملًا: [أول الشهر, آخر لحظة قبل الشهر التالي)
      final monthEnd = DateFormat('yyyy-MM-dd').format(
        DateTime(targetYear, targetMonth + 1, 0),
      );
      final subRevenue = await _recognizedSubRevenue(
        '$monthStr-01',
        monthEnd,
      );

      final totalCost = await _costForRange(
        startStr: '$monthStr-01',
        endStr: '$nextMonth-01',
      );
      final subCost = await _costForRange(
        startStr: '$monthStr-01',
        endStr: '$nextMonth-01',
        includeSubscriptions: true,
      );
      // الضريبة ليست إيرادًا — تُخصم من المبيعات قبل حساب الربح
      final totalTax = await _taxForRange(
        startStr: '$monthStr-01',
        endStr: '$nextMonth-01',
      );
      final customerCredits = await _totalCustomerCredits();
      final expenseTotal = await _expensesFor('$monthStr-01', '$nextMonth-01');

      final report = {
        'year': targetYear,
        'month': targetMonth,
        'total_sales': totalSales,
        'total_revenue': totalSales + subRevenue,
        'total_paid': (salesData.first['total_paid'] ?? 0).toDouble(),
        'total_remaining': (salesData.first['total_remaining'] ?? 0).toDouble(),
        'invoice_count': salesData.first['invoice_count'] ?? 0,
        'total_cost': totalCost,
        'subscription_cost': subCost,
        'expenses': expenseTotal,
        'total_tax': totalTax,
        'gross_profit':
            (totalSales - totalTax) + subRevenue - totalCost - subCost,
        'net_profit':
            (totalSales - totalTax) +
            subRevenue -
            totalCost -
            subCost -
            expenseTotal,
        'subscription_revenue': subRevenue,
        'subscription_collected': await _collectedSubPayments(
          '$monthStr-01',
          monthEnd,
        ),
        // الإيراد المؤجَّل = خدمة مضمونة لم تُقدَّم بعد — ليس ربحًا
        'subscription_liability': await subscriptionLiability(),
        'customer_credits': customerCredits,
        'weekly_breakdown': weeklyBreakdown,
        'top_items': topItems,
      };

      final guarded = _guardMetrics(report);
      monthlyReport.value = guarded;
      return guarded;
    } finally {
      isLoading.value = false;
    }
  }

  Future<Map<String, dynamic>> generateAnnualReport({int? year}) async {
    isLoading.value = true;
    try {
      final targetYear = year ?? DateTime.now().year;
      final startStr = '$targetYear-01-01';
      final endStr = '$targetYear-12-31';

      final salesData = await _db.readData(
        'SELECT COALESCE(SUM(final_amount), 0) AS total_sales, COALESCE(SUM(paid_amount), 0) AS total_paid, COALESCE(SUM(remaining_amount), 0) AS total_remaining, COUNT(CASE WHEN COALESCE(credit_note_of, 0) = 0 THEN 1 END) AS invoice_count FROM invoices WHERE DATE(invoice_date) BETWEEN ? AND ? AND subscription_id IS NULL',
        [startStr, endStr],
      );

      final monthlyBreakdown = await _db.readData(
        'SELECT strftime("%m", invoice_date) AS month, COALESCE(SUM(final_amount), 0) AS sales, COUNT(CASE WHEN COALESCE(credit_note_of, 0) = 0 THEN 1 END) AS invoices FROM invoices WHERE DATE(invoice_date) BETWEEN ? AND ? GROUP BY strftime("%m", invoice_date) ORDER BY month',
        [startStr, endStr],
      );

      final topItems = await _db.readData(
        'SELECT c.clothing_name, COUNT(*) AS times_sold FROM invoices i, json_each(i.list_data) j, clothing c WHERE json_extract(j.value, \'\$.vestments\') = c.clothing_name AND COALESCE(i.credit_note_of, 0) = 0 AND DATE(i.invoice_date) BETWEEN ? AND ? GROUP BY c.clothing_name ORDER BY times_sold DESC LIMIT 10',
        [startStr, endStr],
      );

      final totalSales = (salesData.first['total_sales'] ?? 0).toDouble();

      final subRevenue = await _recognizedSubRevenue(startStr, endStr);

      final totalCost = await _costForRange(startStr: startStr, endStr: endStr);
      final subCost = await _costForRange(
        startStr: startStr,
        endStr: endStr,
        includeSubscriptions: true,
      );
      // الضريبة ليست إيرادًا — تُخصم من المبيعات قبل حساب الربح
      final totalTax = await _taxForRange(startStr: startStr, endStr: endStr);
      final customerCredits = await _totalCustomerCredits();
      final expenseTotal = await _expensesFor(startStr, endStr);

      final report = {
        'year': targetYear,
        'total_sales': totalSales,
        'total_revenue': totalSales + subRevenue,
        'total_paid': (salesData.first['total_paid'] ?? 0).toDouble(),
        'total_remaining': (salesData.first['total_remaining'] ?? 0).toDouble(),
        'invoice_count': salesData.first['invoice_count'] ?? 0,
        'total_cost': totalCost,
        'subscription_cost': subCost,
        'expenses': expenseTotal,
        'total_tax': totalTax,
        'gross_profit':
            (totalSales - totalTax) + subRevenue - totalCost - subCost,
        'net_profit':
            (totalSales - totalTax) +
            subRevenue -
            totalCost -
            subCost -
            expenseTotal,
        'subscription_revenue': subRevenue,
        'subscription_collected': await _collectedSubPayments(
          startStr,
          endStr,
        ),
        'subscription_liability': await subscriptionLiability(),
        'customer_credits': customerCredits,
        'monthly_breakdown': monthlyBreakdown,
        'top_items': topItems,
      };

      final guarded = _guardMetrics(report);
      annualReport.value = guarded;
      return guarded;
    } finally {
      isLoading.value = false;
    }
  }

  Future<Map<String, dynamic>> getCustomerReport(int customerId) async {
    isLoading.value = true;
    try {
      final customerData = await _db.readData(
        'SELECT * FROM customers WHERE customer_id = ?',
        [customerId],
      );

      if (customerData.isEmpty) {
        return {};
      }

      final invoiceData = await _db.readData(
        'SELECT COALESCE(SUM(final_amount), 0) AS total_spent, COUNT(CASE WHEN COALESCE(credit_note_of, 0) = 0 THEN 1 END) AS invoice_count, COALESCE(SUM(remaining_amount), 0) AS total_remaining FROM invoices WHERE customer_id = ?',
        [customerId],
      );

      final recentInvoices = await _db.readData(
        'SELECT * FROM invoices WHERE customer_id = ? ORDER BY invoice_date DESC LIMIT 10',
        [customerId],
      );

      final favoriteItems = await _db.readData(
        "SELECT c.clothing_name, COUNT(*) AS times_ordered "
        "FROM invoices i, json_each(i.list_data) j, clothing c "
        "WHERE json_extract(j.value, '\$.vestments') = c.clothing_name "
        "AND i.customer_id = ? "
        "GROUP BY c.clothing_name ORDER BY times_ordered DESC LIMIT 5",
        [customerId],
      );

      // جلب إجمالي المدفوعات من سجل الدفعات
      final paymentData = await _db.readData(
        'SELECT COALESCE(SUM(amount), 0) AS total_paid FROM customer_payments WHERE customer_id = ?',
        [customerId],
      );

      final customerBalance =
          ((customerData.first['balance'] ?? 0) as num).toDouble();

      final report = {
        'customer': customerData.first,
        'total_spent': (invoiceData.first['total_spent'] ?? 0).toDouble(),
        'invoice_count': invoiceData.first['invoice_count'] ?? 0,
        'total_remaining':
            (invoiceData.first['total_remaining'] ?? 0).toDouble(),
        'total_paid': (paymentData.first['total_paid'] ?? 0).toDouble(),
        'customer_balance': customerBalance,
        'recent_invoices': recentInvoices,
        'favorite_items': favoriteItems,
      };

      customerReport.value = report;
      return report;
    } finally {
      isLoading.value = false;
    }
  }

  Future<Map<String, dynamic>> getItemReport(String itemName) async {
    isLoading.value = true;
    try {
      final itemData = await _db.readData(
        'SELECT * FROM clothing WHERE clothing_name = ?',
        [itemName],
      );

      if (itemData.isEmpty) {
        return {};
      }

      // ⚠️ كان الاستعلام:
      //   COUNT(*) AS times_sold, SUM(i.final_amount) AS total_revenue
      //   FROM invoices i, json_each(i.list_data) j, clothing c
      //   WHERE json_extract(j.value,'$.vestments') = c.clothing_name
      //
      // مشكلة مزدوجة بسبب تفريع `json_each`:
      //   • COUNT(*) تعدّ **صفوف البنود** بعد التفريع، لا الفواتير ⇒ فاتورة
      //     فيها 3 بنود لنفس الصنف تُحسب ×3.
      //   • SUM(i.final_amount) تُكرّر **مبلغ الفاتورة كاملًا** لكل بند مطابق
      //     ⇒ الإيراد يتضاعف بعدد بنود نفس الصنف في الفاتورة.
      //
      // الصحيح: تجميع على مستوى الفاتورة أولًا (بـ EXISTS لكشف مطابقة الصنف)،
      // ثم الجمع والعدّ **مرة واحدة لكل فاتورة**.
      final salesData = await _db.readData(
        'SELECT COUNT(*) AS times_sold, COALESCE(SUM(i.final_amount), 0) AS total_revenue FROM invoices i WHERE i.subscription_id IS NULL   AND EXISTS (SELECT 1 FROM json_each(i.list_data) j '
        "              WHERE json_extract(j.value, '\$.vestments') = ?)",
        [itemName],
      );

      // الكميات المباعة فعلًا من هذا الصنف (مجموع count في البنود)
      final qtyRow = await _db.readData(
        'SELECT COALESCE(SUM(CAST(json_extract(j.value, \'\$.count\') AS REAL)), 0)   AS total_qty FROM invoices i, json_each(i.list_data) j WHERE json_extract(j.value, \'\$.vestments\') = ?   AND i.subscription_id IS NULL',
        [itemName],
      );

      final dailySales = await _db.readData(
        "SELECT DATE(i.invoice_date) AS day, COUNT(*) AS count "
        'FROM invoices i WHERE i.subscription_id IS NULL   AND EXISTS (SELECT 1 FROM json_each(i.list_data) j '
        "              WHERE json_extract(j.value, '\$.vestments') = ?) "
        "GROUP BY DATE(i.invoice_date) ORDER BY day DESC LIMIT 30",
        [itemName],
      );

      final report = {
        'item': itemData.first,
        'times_sold': salesData.first['times_sold'] ?? 0,
        'total_revenue': (salesData.first['total_revenue'] ?? 0).toDouble(),
        // الكمية = القطع فعلًا (كانت COUNT(*) تُظهر عدد البنود وهو رقم مختلف)
        'total_qty': (qtyRow.first['total_qty'] ?? 0).toDouble(),
        'daily_sales': dailySales,
      };

      itemReport.value = report;
      return report;
    } finally {
      isLoading.value = false;
    }
  }
}
