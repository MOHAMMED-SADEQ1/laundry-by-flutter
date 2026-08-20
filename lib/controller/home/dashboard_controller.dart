import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
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
      ]);

      todayAverage.value =
          todayInvoices.value > 0
              ? todaySales.value / todayInvoices.value
              : 0.0;

      todayProfit.value = (todaySales.value - todayCost.value).clamp(
        0,
        double.infinity,
      );
    } catch (e) {
      debugPrint('Dashboard error: $e');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> _loadTodaySales() async {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final result = await _db.readData(
      'SELECT COALESCE(SUM(total_price), 0) as total FROM invoices WHERE DATE(invoice_date) = ?',
      [today],
    );
    todaySales.value = (result.first['total'] ?? 0).toDouble();
  }

  Future<void> _loadTodayInvoices() async {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final result = await _db.readData(
      'SELECT COUNT(*) as count FROM invoices WHERE DATE(invoice_date) = ?',
      [today],
    );
    todayInvoices.value = result.first['count'] ?? 0;
  }

  /// تكلفة القطع المباعة اليوم (مواد التشغيل حسب تكلفة كل قطعة)
  Future<void> _loadTodayCost() async {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    try {
      final result = await _db.readData(
        '''
        SELECT COALESCE(SUM(json_extract(j.value, '\$.count') * COALESCE(c.cost_price, 0)), 0) as cost
        FROM invoices i, json_each(i.list_data) j, clothing c
        WHERE DATE(i.invoice_date) = ? AND json_extract(j.value, '\$.vestments') = c.clothing_name
      ''',
        [today],
      );
      todayCost.value = (result.first['cost'] ?? 0).toDouble();
    } catch (e) {
      todayCost.value = 0;
      debugPrint('cost error: $e');
    }
  }

  Future<void> _loadCustomerCount() async {
    final result = await _db.readData(
      'SELECT COUNT(*) as count FROM customers WHERE is_active = 1',
    );
    totalCustomers.value = result.first['count'] ?? 0;
  }

  Future<void> _loadWeeklySales() async {
    final result = await _db.readData('''
      SELECT DATE(invoice_date) as day, SUM(total_price) as total, COUNT(*) as count
      FROM invoices
      WHERE invoice_date >= DATE('now', '-7 days')
      GROUP BY DATE(invoice_date)
      ORDER BY day ASC
    ''');
    weeklySales.assignAll(List<Map<String, dynamic>>.from(result));
  }

  Future<void> _loadMonthlySales() async {
    final result = await _db.readData('''
      SELECT strftime('%Y-%m', invoice_date) as month, SUM(total_price) as total, COUNT(*) as count
      FROM invoices
      WHERE invoice_date >= DATE('now', '-12 months')
      GROUP BY strftime('%Y-%m', invoice_date)
      ORDER BY month ASC
    ''');
    monthlySales.assignAll(List<Map<String, dynamic>>.from(result));
  }

  Future<void> _loadTopItems() async {
    final result = await _db.readData(
      "SELECT json_extract(value, '\$.vestments') as item_name, SUM(json_extract(value, '\$.total_price')) as total_revenue, SUM(json_extract(value, '\$.count')) as total_count FROM invoices, json_each(list_data) WHERE invoice_date >= DATE('now', '-30 days') GROUP BY item_name ORDER BY total_revenue DESC LIMIT 10",
    );
    topItems.assignAll(List<Map<String, dynamic>>.from(result));
  }

  Future<void> _loadPaymentMethods() async {
    final result = await _db.readData('''
      SELECT payment_method, COUNT(*) as count, SUM(total_price) as total
      FROM invoices
      WHERE DATE(invoice_date) = DATE('now')
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
      'SELECT COALESCE(SUM(total_price), 0) as total FROM invoices WHERE DATE(invoice_date) = ?',
      [yesterday],
    );
    yesterdaySales.value = (yResult.first['total'] ?? 0).toDouble();

    // Last week
    final lastWeek = await _db.readData('''
      SELECT COALESCE(SUM(total_price), 0) as total FROM invoices
      WHERE DATE(invoice_date) BETWEEN DATE('now', '-14 days') AND DATE('now', '-7 days')
    ''');
    lastWeekSales.value = (lastWeek.first['total'] ?? 0).toDouble();

    // Last month
    final lastMonth = await _db.readData('''
      SELECT COALESCE(SUM(total_price), 0) as total FROM invoices
      WHERE DATE(invoice_date) BETWEEN DATE('now', '-60 days') AND DATE('now', '-30 days')
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
        WHERE invoice_date >= DATE('now', '-7 days')
        GROUP BY hour
        ORDER BY count DESC
        LIMIT 6
      ''');
      peakHours.assignAll(List<Map<String, dynamic>>.from(result));
    } catch (e) {
      debugPrint('peak hours error: $e');
    }
  }

  /// توقع مبيعات اليوم: متوسط آخر 3 أيام في نفس الوقت من اليوم
  Future<void> _loadForecast() async {
    try {
      final currentHour = DateTime.now().hour;
      final total = await _db.readData(
        '''
        SELECT COALESCE(SUM(total_price), 0) as t FROM invoices
        WHERE invoice_date >= DATE('now', '-3 days')
          AND CAST(strftime('%H', invoice_date) AS INTEGER) <= ?
      ''',
        [currentHour],
      );
      forecastToday.value = (total.first['t'] ?? 0).toDouble() / 3.0;
    } catch (e) {
      debugPrint('forecast error: $e');
    }
  }
}
