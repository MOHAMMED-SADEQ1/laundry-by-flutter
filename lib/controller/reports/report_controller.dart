import 'package:get/get.dart';
import 'package:intl/intl.dart';
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

  Future<Map<String, dynamic>> generateDailyReport({DateTime? date}) async {
    isLoading.value = true;
    try {
      final targetDate = date ?? DateTime.now();
      final dateStr = DateFormat('yyyy-MM-dd').format(targetDate);

      final salesData = await _db.readData(
        'SELECT COALESCE(SUM(final_amount), 0) AS total_sales, '
        'COALESCE(SUM(paid_amount), 0) AS total_paid, '
        'COALESCE(SUM(remaining_amount), 0) AS total_remaining, '
        'COUNT(*) AS invoice_count '
        'FROM invoices WHERE DATE(invoice_date) = ?',
        [dateStr],
      );

      final topItems = await _db.readData(
        'SELECT c.clothing_name, COUNT(*) AS times_sold '
        'FROM invoices i, json_each(i.list_data) j, clothing c '
        'WHERE json_extract(j.value, \'\$.vestments\') = c.clothing_name '
        'AND DATE(i.invoice_date) = ? '
        'GROUP BY c.clothing_name ORDER BY times_sold DESC LIMIT 10',
        [dateStr],
      );

      final paymentBreakdown = await _db.readData(
        'SELECT payment_method, COUNT(*) AS count, '
        'COALESCE(SUM(final_amount), 0) AS total '
        'FROM invoices WHERE DATE(invoice_date) = ? '
        'GROUP BY payment_method',
        [dateStr],
      );

      final totalSales = (salesData.first['total_sales'] ?? 0).toDouble();

      final subRevenue = await _db.readData(
        'SELECT COALESCE(SUM(amount), 0) AS total FROM subscription_payments '
        'WHERE DATE(paid_date) = ?',
        [dateStr],
      );

      final report = {
        'date': dateStr,
        'total_sales': totalSales,
        'total_paid': (salesData.first['total_paid'] ?? 0).toDouble(),
        'total_remaining': (salesData.first['total_remaining'] ?? 0).toDouble(),
        'invoice_count': salesData.first['invoice_count'] ?? 0,
        'net_profit': totalSales,
        'subscription_revenue': (subRevenue.first['total'] ?? 0).toDouble(),
        'top_items': topItems,
        'payment_breakdown': paymentBreakdown,
      };

      dailyReport.value = report;
      return report;
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
        'SELECT COALESCE(SUM(final_amount), 0) AS total_sales, '
        'COALESCE(SUM(paid_amount), 0) AS total_paid, '
        'COALESCE(SUM(remaining_amount), 0) AS total_remaining, '
        'COUNT(*) AS invoice_count '
        'FROM invoices WHERE DATE(invoice_date) BETWEEN ? AND ?',
        [startStr, endStr],
      );

      final dailyBreakdown = await _db.readData(
        'SELECT DATE(invoice_date) AS day, '
        'COALESCE(SUM(final_amount), 0) AS sales, '
        'COUNT(*) AS invoices '
        'FROM invoices WHERE DATE(invoice_date) BETWEEN ? AND ? '
        'GROUP BY DATE(invoice_date) ORDER BY day',
        [startStr, endStr],
      );

      final totalSales = (salesData.first['total_sales'] ?? 0).toDouble();

      final subRevenue = await _db.readData(
        'SELECT COALESCE(SUM(amount), 0) AS total FROM subscription_payments '
        'WHERE DATE(paid_date) BETWEEN ? AND ?',
        [startStr, endStr],
      );

      final report = {
        'start_date': startStr,
        'end_date': endStr,
        'total_sales': totalSales,
        'total_paid': (salesData.first['total_paid'] ?? 0).toDouble(),
        'total_remaining': (salesData.first['total_remaining'] ?? 0).toDouble(),
        'invoice_count': salesData.first['invoice_count'] ?? 0,
        'net_profit': totalSales,
        'subscription_revenue': (subRevenue.first['total'] ?? 0).toDouble(),
        'daily_breakdown': dailyBreakdown,
      };

      weeklyReport.value = report;
      return report;
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
        'SELECT COALESCE(SUM(final_amount), 0) AS total_sales, '
        'COALESCE(SUM(paid_amount), 0) AS total_paid, '
        'COALESCE(SUM(remaining_amount), 0) AS total_remaining, '
        'COUNT(*) AS invoice_count '
        'FROM invoices WHERE DATE(invoice_date) >= ? AND DATE(invoice_date) < ?',
        ['$monthStr-01', '$nextMonth-01'],
      );

      final weeklyBreakdown = await _db.readData(
        'SELECT strftime("%W", invoice_date) AS week, '
        'COALESCE(SUM(final_amount), 0) AS sales, '
        'COUNT(*) AS invoices '
        'FROM invoices WHERE DATE(invoice_date) >= ? AND DATE(invoice_date) < ? '
        'GROUP BY strftime("%W", invoice_date) ORDER BY week',
        ['$monthStr-01', '$nextMonth-01'],
      );

      final topItems = await _db.readData(
        'SELECT c.clothing_name, COUNT(*) AS times_sold '
        'FROM invoices i, json_each(i.list_data) j, clothing c '
        'WHERE json_extract(j.value, \'\$.vestments\') = c.clothing_name '
        'AND DATE(i.invoice_date) >= ? AND DATE(i.invoice_date) < ? '
        'GROUP BY c.clothing_name ORDER BY times_sold DESC LIMIT 10',
        ['$monthStr-01', '$nextMonth-01'],
      );

      final totalSales = (salesData.first['total_sales'] ?? 0).toDouble();

      final subRevenue = await _db.readData(
        'SELECT COALESCE(SUM(amount), 0) AS total FROM subscription_payments '
        'WHERE DATE(paid_date) >= ? AND DATE(paid_date) < ?',
        ['$monthStr-01', '$nextMonth-01'],
      );

      final report = {
        'year': targetYear,
        'month': targetMonth,
        'total_sales': totalSales,
        'total_paid': (salesData.first['total_paid'] ?? 0).toDouble(),
        'total_remaining': (salesData.first['total_remaining'] ?? 0).toDouble(),
        'invoice_count': salesData.first['invoice_count'] ?? 0,
        'net_profit': totalSales,
        'subscription_revenue': (subRevenue.first['total'] ?? 0).toDouble(),
        'weekly_breakdown': weeklyBreakdown,
        'top_items': topItems,
      };

      monthlyReport.value = report;
      return report;
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
        'SELECT COALESCE(SUM(final_amount), 0) AS total_sales, '
        'COALESCE(SUM(paid_amount), 0) AS total_paid, '
        'COALESCE(SUM(remaining_amount), 0) AS total_remaining, '
        'COUNT(*) AS invoice_count '
        'FROM invoices WHERE DATE(invoice_date) BETWEEN ? AND ?',
        [startStr, endStr],
      );

      final monthlyBreakdown = await _db.readData(
        'SELECT strftime("%m", invoice_date) AS month, '
        'COALESCE(SUM(final_amount), 0) AS sales, '
        'COUNT(*) AS invoices '
        'FROM invoices WHERE DATE(invoice_date) BETWEEN ? AND ? '
        'GROUP BY strftime("%m", invoice_date) ORDER BY month',
        [startStr, endStr],
      );

      final topItems = await _db.readData(
        'SELECT c.clothing_name, COUNT(*) AS times_sold '
        'FROM invoices i, json_each(i.list_data) j, clothing c '
        'WHERE json_extract(j.value, \'\$.vestments\') = c.clothing_name '
        'AND DATE(i.invoice_date) BETWEEN ? AND ? '
        'GROUP BY c.clothing_name ORDER BY times_sold DESC LIMIT 10',
        [startStr, endStr],
      );

      final totalSales = (salesData.first['total_sales'] ?? 0).toDouble();

      final subRevenue = await _db.readData(
        'SELECT COALESCE(SUM(amount), 0) AS total FROM subscription_payments '
        'WHERE DATE(paid_date) BETWEEN ? AND ?',
        [startStr, endStr],
      );

      final report = {
        'year': targetYear,
        'total_sales': totalSales,
        'total_paid': (salesData.first['total_paid'] ?? 0).toDouble(),
        'total_remaining': (salesData.first['total_remaining'] ?? 0).toDouble(),
        'invoice_count': salesData.first['invoice_count'] ?? 0,
        'net_profit': totalSales,
        'subscription_revenue': (subRevenue.first['total'] ?? 0).toDouble(),
        'monthly_breakdown': monthlyBreakdown,
        'top_items': topItems,
      };

      annualReport.value = report;
      return report;
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
        'SELECT COALESCE(SUM(final_amount), 0) AS total_spent, '
        'COUNT(*) AS invoice_count, '
        'COALESCE(SUM(remaining_amount), 0) AS total_remaining '
        'FROM invoices WHERE customer_id = ?',
        [customerId],
      );

      final recentInvoices = await _db.readData(
        'SELECT * FROM invoices WHERE customer_id = ? '
        'ORDER BY invoice_date DESC LIMIT 10',
        [customerId],
      );

      final favoriteItems = await _db.readData(
        'SELECT c.clothing_name, COUNT(*) AS times_ordered '
        'FROM invoices i, json_each(i.list_data) j, clothing c '
        'WHERE json_extract(j.value, \'\$.vestments\') = c.clothing_name '
        'AND i.customer_id = ? '
        'GROUP BY c.clothing_name ORDER BY times_ordered DESC LIMIT 5',
        [customerId],
      );

      final report = {
        'customer': customerData.first,
        'total_spent': (invoiceData.first['total_spent'] ?? 0).toDouble(),
        'invoice_count': invoiceData.first['invoice_count'] ?? 0,
        'total_remaining':
            (invoiceData.first['total_remaining'] ?? 0).toDouble(),
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

      final salesData = await _db.readData(
        'SELECT COUNT(*) AS times_sold, '
        'COALESCE(SUM(i.final_amount), 0) AS total_revenue '
        'FROM invoices i, json_each(i.list_data) j, clothing c '
        'WHERE json_extract(j.value, \'\$.vestments\') = c.clothing_name '
        'AND c.clothing_name = ?',
        [itemName],
      );

      final dailySales = await _db.readData(
        'SELECT DATE(i.invoice_date) AS day, COUNT(*) AS count '
        'FROM invoices i, json_each(i.list_data) j, clothing c '
        'WHERE json_extract(j.value, \'\$.vestments\') = c.clothing_name '
        'AND c.clothing_name = ? '
        'GROUP BY DATE(i.invoice_date) ORDER BY day DESC LIMIT 30',
        [itemName],
      );

      final report = {
        'item': itemData.first,
        'times_sold': salesData.first['times_sold'] ?? 0,
        'total_revenue': (salesData.first['total_revenue'] ?? 0).toDouble(),
        'daily_sales': dailySales,
      };

      itemReport.value = report;
      return report;
    } finally {
      isLoading.value = false;
    }
  }
}
