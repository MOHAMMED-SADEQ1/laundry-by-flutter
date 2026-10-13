import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:laundry/services/invoice/invoice_items_service.dart';
import 'package:laundry/services/subscription/subscription_service.dart';
import 'package:laundry/sqldb.dart';
import 'package:intl/intl.dart';

class DashboardController extends GetxController {
  final SqlDB _db = SqlDB();

  // KPIs
  final RxDouble todaySales = 0.0.obs;
  final RxInt todayInvoices = 0.obs;
  final RxDouble todayAverage = 0.0.obs;
  final RxDouble todayProfit = 0.0.obs;
  final RxDouble todayCost = 0.0.obs;
  final RxInt totalCustomers = 0.obs;
  final RxInt activeShift = 0.obs;

  // ─── مؤشرات الاشتراكات الشهرية ───
  // كانت غائبة تمامًا: كل استعلامات اللوحة تشترط `subscription_id IS NULL`،
  // فلم يرَ صاحب المحل أي أثر لإيراد الاشتراكات في اللوحة الرئيسية.
  /// الإيراد المُعترف به من الاشتراكات اليوم (خدمة مُستهلكة).
  final RxDouble todaySubscriptionRevenue = 0.0.obs;

  /// النقدية المحصَّلة من دفعات الاشتراكات اليوم.
  final RxDouble todaySubscriptionCollected = 0.0.obs;

  /// الإيراد الشهري المتكرّر — أساس التخطيط.
  final RxDouble subscriptionMrr = 0.0.obs;

  /// الالتزام المتبقّي (إيراد مؤجَّل): خدمة مضمونة لم تُقدَّم بعد.
  final RxDouble subscriptionLiability = 0.0.obs;

  /// تكلفة خدمة الاشتراكات اليوم — **حقل مستقل** لا يُضاف إلى `todayCost`.
  ///
  /// **إصلاح سباق (race):** كان `_loadSubscriptionKpis` يكتب
  /// `todayCost.value = todayCost.value + subCostToday`، بينما
  /// `_loadTodayCost` يكتب `todayCost.value = <القيمة>`. والاثنان يعملان
  /// معًا داخل `Future.wait` بلا ترتيب مضمون، ومع إعادة تحميل اللوحة
  /// النتيجة تتغيّر: إمّا تُلغى تكلفة الاشتراك (إن سبق `_loadTodayCost`)
  /// أو تُضاف مرتين (إن تكرّرت). الآن كل حقل يُكتب بمصدره الواحد،
  /// والجمع يحدث لحظة العرض في `todayProfit` و`todayTotalCost`.
  final RxDouble todaySubscriptionCost = 0.0.obs;

  /// عدد المشتركين بتغطية سارية.
  final RxInt activeSubscribers = 0.obs;

  /// اشتراكات متأخّرة عن السداد.
  final RxInt overdueSubscriptions = 0.obs;

  // Charts data
  final RxList<Map<String, dynamic>> weeklySales = <Map<String, dynamic>>[].obs;
  final RxList<Map<String, dynamic>> monthlySales =
      <Map<String, dynamic>>[].obs;
  final RxList<Map<String, dynamic>> topItems = <Map<String, dynamic>>[].obs;
  final RxList<Map<String, dynamic>> paymentMethods =
      <Map<String, dynamic>>[].obs;

  // ساعات الذروة + التوقع
  final RxList<Map<String, dynamic>> peakHours = <Map<String, dynamic>>[].obs;
  final RxDouble forecastToday = 0.0.obs;

  final RxList<Map<String, dynamic>> topCustomers =
      <Map<String, dynamic>>[].obs;

  // Comparison data
  final RxDouble yesterdaySales = 0.0.obs;
  final RxDouble lastWeekSales = 0.0.obs;
  final RxDouble lastMonthSales = 0.0.obs;

  final isLoading = false.obs;

  @override
  void onInit() {
    super.onInit();
    loadDashboardData();
  }

  Future<void> loadDashboardData() async {
    isLoading.value = true;
    try {
      await Future.wait([
        _loadTodaySales(),
        _loadTodayInvoices(),
        _loadTodayCost(),
        _loadCustomerCount(),
        _loadWeeklySales(),
        _loadMonthlySales(),
        _loadTopItems(),
        _loadPaymentMethods(),
        _loadComparisonData(),
        _loadPeakHours(),
        _loadForecast(),
        _loadSubscriptionKpis(),
      ]);

      todayAverage.value =
          todayInvoices.value > 0
              ? todaySales.value / todayInvoices.value
              : 0.0;

      // 💰 صافي الربح يجب أن يرى **إيراد الاشتراكات وتكلفتها** أيضًا.
      // سابقًا كان: (مبيعات عادية − تكلفة تشمل الاشتراكات) ⇒ سالب دائمًا.
      //
      // الجمع يتم هنا لحظة العرض، لا بالكتابة في الحقول — فلا أثر لترتيب
      // تنفيذ الاستعلامات المتوازية.
      //
      // **لا `.clamp`**: قصّ القيمة عند صفر كان يُخفي الأيام الخاسرة تمامًا،
      // فيرى المالك «0» بينما التقرير يعرض الرقم السالب بالأحمر — تناقض
      // يُخفي خسارة حقيقية. الواجهة تتكفّل بعرض السالب بلونه التحذيري.
      todayProfit.value =
          todaySales.value +
          todaySubscriptionRevenue.value -
          todayCost.value -
          todaySubscriptionCost.value;
    } catch (e) {
      debugPrint('Dashboard error: $e');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> _loadTodaySales() async {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final result = await _db.readData(
      // final_amount (بعد الخصم) — نفس أساس التقارير. كان total_price
      // (قبل الخصم) ⇒ «مبيعات اليوم» في اللوحة تتجاوز «المبيعات» في
      // التقرير لنفس اليوم بمقدار الخصومات.
      'SELECT COALESCE(SUM(final_amount), 0) as total FROM invoices '
      "WHERE DATE(invoice_date) = ? AND subscription_id IS NULL",
      [today],
    );
    todaySales.value = (result.first['total'] ?? 0).toDouble();
  }

  Future<void> _loadTodayInvoices() async {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final result = await _db.readData(
      // `subscription_id IS NULL`: بدونه يُقسم إجمالي المبيعات العادية على
      // عدد يشمل فواتير الاشتراك ⇒ متوسط الفاتورة أقل من الحقيقة دائمًا.
      'SELECT COUNT(*) as count FROM invoices '
      "WHERE DATE(invoice_date) = ? AND subscription_id IS NULL",
      [today],
    );
    todayInvoices.value = result.first['count'] ?? 0;
  }

  /// تكلفة القطع المباعة اليوم (مواد التشغيل حسب تكلفة كل قطعة).
  ///
  /// **إصلاح**: كانت تشمل فواتير الاشتراكات بينما الإيراد يستثنيها ⇒ ربح سالب.
  /// الآن تُحسب على الفواتير **غير** المرتبطة باشتراك، وتكلفة الاشتراكات
  /// تُحتسب منفصلة في [_loadSubscriptionKpis]، ثم تُجمع في `todayCost`.
  Future<void> _loadTodayCost() async {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    try {
      // التكلفة من **لقطة البنود** (`invoice_items`) لا من الربط بالاسم مع
      // `clothing` — الربط بالاسم كان يصفّر التكلفة عند إعادة تسمية صنف.
      todayCost.value = await InvoiceItemsService.instance.costFor(
        where: 'DATE(i.invoice_date) = ? AND i.subscription_id IS NULL',
        args: [today],
      );
    } catch (e) {
      todayCost.value = 0;
      debugPrint('cost error: $e');
    }
  }

  /// مؤشرات الاشتراكات: إيراد مُعترف به + محصَّل + MRR + التزام متبقٍّ.
  ///
  /// سبب الفصل: الإيراد المُعترف به (خدمة مُقدَّمة) والمحصَّل (نقدية) رقمان
  /// مختلفان تمامًا في المحاسبة، وخلطهما هو ما يجعل التقارير كاذبة.
  Future<void> _loadSubscriptionKpis() async {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    try {
      final svc = await SubscriptionService.instance.financials();

      // الإيراد المُعترف به اليوم: قيمة الغسيل المُستهلك من فواتير الاشتراكات
      final recognized = await _db.readData(
        'SELECT COALESCE(SUM(COALESCE(i.subscription_used_value, 0)), 0) '
        '  AS v '
        'FROM invoices i '
        'WHERE DATE(i.invoice_date) = ? AND i.subscription_id IS NOT NULL',
        [today],
      );
      todaySubscriptionRevenue.value =
          (recognized.firstOrNull?['v'] as num?)?.toDouble() ?? 0;

      // تكلفة خدمة الاشتراكات اليوم — من لقطة البنود (لا الربط بالاسم)
      todaySubscriptionCost.value = await InvoiceItemsService.instance.costFor(
        where: 'DATE(i.invoice_date) = ? AND i.subscription_id IS NOT NULL',
        args: [today],
      );

      final collected = await _db.readData(
        'SELECT COALESCE(SUM(amount), 0) AS t FROM subscription_payments '
        "WHERE DATE(paid_date) = ? AND COALESCE(source,'manual') "
        "  != 'cancel_refund'",
        [today],
      );
      todaySubscriptionCollected.value =
          (collected.firstOrNull?['t'] as num?)?.toDouble() ?? 0;

      subscriptionMrr.value = await SubscriptionService.instance.mrr();
      subscriptionLiability.value = svc.deferred;
      activeSubscribers.value = svc.activeCount + svc.cappedCount;
      overdueSubscriptions.value = svc.overdueCount + svc.pendingCount;
    } catch (e) {
      debugPrint('subscription kpis error: $e');
    }
  }

  Future<void> _loadCustomerCount() async {
    final result = await _db.readData(
      'SELECT COUNT(*) as count FROM customers WHERE is_active = 1',
    );
    totalCustomers.value = result.first['count'] ?? 0;
  }

  Future<void> _loadWeeklySales() async {
    // ⚠️ **قاعدة الفلترة الزمنية:** `DATE(invoice_date)` **بلا** `'localtime'`،
    // بينما `DATE('now', 'localtime')` **تبقى** — `'now'` في SQLite وقت UTC
    // فعلًا فتحويله للمحلي صواب، أما `invoice_date` فمخزَّن **محليًا** أصلًا
    // (لا `toUtc()` في المشروع كله)، فإضافة `'localtime'` عليه تحويل مزدوج
    // يزيح كل فاتورة بعد 21:00 محليًا (UTC+3) إلى اليوم التالي.
    // القياس العددي في `tool/verify_localtime_removal.py`.
    final result = await _db.readData('''
      SELECT DATE(invoice_date) as day,
             SUM(final_amount) as total, COUNT(*) as count
      FROM invoices
      WHERE DATE(invoice_date) >= DATE('now', 'localtime', '-7 days')
        AND subscription_id IS NULL
      GROUP BY DATE(invoice_date)
      ORDER BY day ASC
    ''');
    weeklySales.assignAll(List<Map<String, dynamic>>.from(result));
  }

  Future<void> _loadMonthlySales() async {
    final result = await _db.readData('''
      SELECT strftime('%Y-%m', invoice_date) as month,
             SUM(final_amount) as total, COUNT(*) as count
      FROM invoices
      WHERE DATE(invoice_date) >= DATE('now', 'localtime', '-12 months')
        AND subscription_id IS NULL
      GROUP BY strftime('%Y-%m', invoice_date)
      ORDER BY month ASC
    ''');
    monthlySales.assignAll(List<Map<String, dynamic>>.from(result));
  }

  Future<void> _loadTopItems() async {
    // الترتيب الثانوي بـ item_name يجعل الناتج حتميًا عند تعادل الإيراد
    // (كان الترتيب غير معرَّف عند التعادل فيتغيّر بين تحميل وآخر).
    final result = await _db.readData(
      "SELECT json_extract(value, '\$.vestments') as item_name, "
      "  SUM(json_extract(value, '\$.total_price')) as total_revenue, "
      "  SUM(json_extract(value, '\$.count')) as total_count "
      "FROM invoices, json_each(list_data) "
      "WHERE DATE(invoice_date) >= DATE('now', 'localtime', '-30 days') "
      "  AND subscription_id IS NULL "
      "GROUP BY item_name "
      "ORDER BY total_revenue DESC, item_name ASC LIMIT 10",
    );
    topItems.assignAll(List<Map<String, dynamic>>.from(result));
  }

  Future<void> _loadPaymentMethods() async {
    final result = await _db.readData('''
      SELECT payment_method, COUNT(*) as count, SUM(final_amount) as total
      FROM invoices
      WHERE DATE(invoice_date) = DATE('now', 'localtime')
        AND subscription_id IS NULL
      GROUP BY payment_method
    ''');
    paymentMethods.assignAll(List<Map<String, dynamic>>.from(result));
  }

  Future<void> _loadComparisonData() async {
    // Yesterday
    final yesterday = DateFormat(
      'yyyy-MM-dd',
    ).format(DateTime.now().subtract(Duration(days: 1)));
    final yResult = await _db.readData(
      "SELECT COALESCE(SUM(final_amount), 0) as total FROM invoices "
      "WHERE DATE(invoice_date) = ? AND subscription_id IS NULL",
      [yesterday],
    );
    yesterdaySales.value = (yResult.first['total'] ?? 0).toDouble();

    // Last week — نطاق [‎-14, -8] لا [‎-14, -7]:
    // كانت BETWEEN ضامّة للطرفين فيُحسب يوم ‎-7 في الأسبوعين معًا (ازدواج).
    // النطاق الصحيح: 7 أيام كاملة تنتهي أمس.
    final lastWeek = await _db.readData('''
      SELECT COALESCE(SUM(final_amount), 0) as total FROM invoices
      WHERE DATE(invoice_date)
            BETWEEN DATE('now', 'localtime', '-14 days')
                AND DATE('now', 'localtime', '-8 days')
        AND subscription_id IS NULL
    ''');
    lastWeekSales.value = (lastWeek.first['total'] ?? 0).toDouble();

    // Last month — 30 يومًا كاملة تنتهي ‎-30 (النطاق السابق [‎-60,‎-30] كان
    // 31 يومًا ويضمّ حدًّا مشتركًا مع الشهر الحالي).
    final lastMonth = await _db.readData('''
      SELECT COALESCE(SUM(final_amount), 0) as total FROM invoices
      WHERE DATE(invoice_date)
            BETWEEN DATE('now', 'localtime', '-60 days')
                AND DATE('now', 'localtime', '-31 days')
        AND subscription_id IS NULL
    ''');
    lastMonthSales.value = (lastMonth.first['total'] ?? 0).toDouble();
  }

  // Refresh all data
  Future<void> refreshData() async {
    await loadDashboardData();
  }

  /// توزيع الفواتير على ساعات اليوم (آخر 7 أيام)
  Future<void> _loadPeakHours() async {
    try {
      final result = await _db.readData('''
        SELECT CAST(strftime('%H', invoice_date) AS INTEGER) as hour, COUNT(*) as count
        FROM invoices
        WHERE DATE(invoice_date) >= DATE('now', 'localtime', '-7 days')
          AND subscription_id IS NULL
        GROUP BY hour
        ORDER BY count DESC, hour ASC
        LIMIT 6
      ''');
      peakHours.assignAll(List<Map<String, dynamic>>.from(result));
    } catch (e) {
      debugPrint('peak hours error: $e');
    }
  }

  /// توقع مبيعات اليوم: متوسط آخر 7 أيام ماضية **في نفس الوقت من اليوم**.
  ///
  /// كان يجمع `>= DATE('now','-3 days')` وهو ما يشمل 3 أيام كاملة **زائد
  /// اليوم الحالي**، ثم يقسم على 3 — فتزداد النتيجة بمقدار ⅓ يوم حالي
  /// مزدوج. الآن: نافذة [‎-7, أمس] (7 أيام كاملة، لا تشمل اليوم) ÷ 7.
  Future<void> _loadForecast() async {
    try {
      final currentHour = DateTime.now().hour;
      final total = await _db.readData(
        '''
        SELECT COALESCE(SUM(final_amount), 0) as t FROM invoices
        WHERE DATE(invoice_date)
              BETWEEN DATE('now', 'localtime', '-7 days')
                  AND DATE('now', 'localtime', '-1 days')
          AND CAST(strftime('%H', invoice_date) AS INTEGER) <= ?
          AND subscription_id IS NULL
      ''',
        [currentHour],
      );
      forecastToday.value = (total.first['t'] ?? 0).toDouble() / 7.0;
    } catch (e) {
      debugPrint('forecast error: $e');
    }
  }
}
