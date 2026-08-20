import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:laundry/sqldb.dart';

/// اشتراكات الزبائن الشهرية — تسجيل + تتبع استحقاق + مدفوعات جزئية + قطع الغسيل
class SubscriptionsController extends GetxController {
  final SqlDB _db = SqlDB();

  final RxList<Map<String, dynamic>> subscriptions =
      <Map<String, dynamic>>[].obs;
  final RxList<Map<String, dynamic>> customers = <Map<String, dynamic>>[].obs;
  final RxList<Map<String, dynamic>> payments = <Map<String, dynamic>>[].obs;
  final RxBool isLoading = false.obs;

  @override
  void onInit() {
    super.onInit();
    loadSubscriptions();
    _loadCustomers();
  }

  Future<void> _loadCustomers() async {
    final rows = await _db
        .safeRead('customers', where: 'is_active = 1', orderBy: 'customer_name')
        .catchError((_) => <Map<String, dynamic>>[]);
    customers.assignAll(rows);
  }

  /// تاريخ نهاية التغطية المدفوعة للاشتراك
  DateTime paidUntil(Map<String, dynamic> sub) {
    try {
      final raw = sub['paid_until_date']?.toString();
      if (raw != null && raw.trim().isNotEmpty) {
        final parsed = DateTime.tryParse(raw);
        if (parsed != null) return parsed;
      }
      final start = DateTime.parse(sub['start_date'].toString());
      final billed = DateTime.tryParse(
        sub['last_billed_date']?.toString() ?? '',
      );
      final base = billed ?? start;
      return base.add(Duration(days: (sub['period_days'] ?? 30) as int));
    } catch (_) {
      return DateTime.now();
    }
  }

  /// هل سُجلت أي دفعة لهذا الاشتراك؟
  bool hasPayment(Map<String, dynamic> sub) {
    final id = sub['subscription_id'];
    return payments.any((p) => p['subscription_id'] == id);
  }

  /// الأيام المتبقية من التغطية المدفوعة (سالب = متأخر)
  int daysRemaining(Map<String, dynamic> sub) {
    final until = paidUntil(sub);
    final now = DateTime.now();
    final a = DateTime(until.year, until.month, until.day);
    final b = DateTime(now.year, now.month, now.day);
    return a.difference(b).inDays;
  }

  bool isOverdue(Map<String, dynamic> sub) {
    if (!hasPayment(sub)) return true;
    return daysRemaining(sub) < 0;
  }

  Future<void> loadSubscriptions() async {
    isLoading.value = true;
    try {
      final pays = await _db
          .safeRead('subscription_payments', orderBy: 'paid_date DESC')
          .catchError((_) => <Map<String, dynamic>>[]);
      payments.assignAll(pays);

      final rows = await _db
          .safeRead(
            'subscriptions',
            where: 'is_active = 1',
            orderBy: 'customer_name COLLATE NOCASE ASC',
          )
          .catchError((_) => <Map<String, dynamic>>[]);

      final enriched = <Map<String, dynamic>>[];
      for (final s in rows) {
        enriched.add({
          ...s,
          'pieces_count': await _piecesForWindow(s),
          'top_pieces': await _topPieces(s),
          'paid_this_month': _paidThisMonth(s, pays),
        });
      }
      subscriptions.assignAll(enriched);
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> addSubscription({
    required int customerId,
    required String customerName,
    required double amount,
    required int periodDays,
    String? notes,
  }) async {
    final now = DateTime.now().toIso8601String();
    await _db.safeInsert('subscriptions', {
      'customer_id': customerId,
      'customer_name': customerName,
      'amount': amount,
      'period_days': periodDays,
      'start_date': now,
      'last_billed_date': now,
      'paid_until_date': null,
      'notes': notes,
      'is_active': 1,
    });
    await loadSubscriptions();
  }

  /// تسجيل دفعة (جزئية أو كاملة) وتمديد التغطية بنسبة المبلغ
  Future<DateTime> pay({
    required Map<String, dynamic> sub,
    required double amount,
    String method = 'كاش',
    String? notes,
  }) async {
    final price = (sub['amount'] ?? 0).toDouble();
    final periodDays = (sub['period_days'] ?? 30) as int;
    if (amount <= 0) throw Exception('المبلغ يجب أن يكون أكبر من صفر');

    final now = DateTime.now();
    final current = paidUntil(sub);
    // ترسيخ: إما التغطية الحالية (مدفوعة مسبقاً) أو تاريخ اليوم
    final anchor = current.isAfter(now) ? current : now;
    final coveredDays = price <= 0
        ? periodDays
        : ((amount / price) * periodDays).round();
    final newUntil = anchor.add(Duration(days: coveredDays));

    await _db.safeInsert('subscription_payments', {
      'subscription_id': sub['subscription_id'],
      'amount': amount,
      'paid_date': now.toIso8601String(),
      'method': method,
      'notes': notes,
    });
    final untilStr = newUntil.toIso8601String();
    await _db.safeUpdate(
      'subscriptions',
      {'paid_until_date': untilStr, 'last_billed_date': untilStr},
      where: 'subscription_id = ?',
      whereArgs: [sub['subscription_id']],
    );
    await loadSubscriptions();
    return newUntil;
  }

  Future<void> cancel(int subscriptionId) async {
    await _db.safeUpdate(
      'subscriptions',
      {'is_active': 0},
      where: 'subscription_id = ?',
      whereArgs: [subscriptionId],
    );
    await loadSubscriptions();
  }

  // ───────────────────────── قطع الغسيل في الفترة ─────────────────────────

  /// نافذة آخر فترة مدفوعة: [التغطية - المدة, التغطية)
  (DateTime, DateTime) periodWindow(Map<String, dynamic> sub) {
    final until = paidUntil(sub);
    final periodDays = (sub['period_days'] ?? 30) as int;
    return (until.subtract(Duration(days: periodDays)), until);
  }

  Future<int> _piecesForWindow(Map<String, dynamic> sub) async {
    try {
      final (start, end) = periodWindow(sub);
      final sql =
          'SELECT COALESCE(SUM(CAST(json_extract(j.value, \'\$.count\') AS INTEGER)), 0) AS pieces '
          'FROM invoices i, json_each(i.list_data) j '
          'WHERE i.customer_id = ? AND DATE(i.invoice_date) >= ? AND DATE(i.invoice_date) < ?';
      final rows = await _db.readData(sql, [
        sub['customer_id'],
        DateFormat('yyyy-MM-dd').format(start),
        DateFormat('yyyy-MM-dd').format(end),
      ]);
      if (rows.isEmpty) return 0;
      return (rows.first['pieces'] ?? 0) as int;
    } catch (_) {
      return 0;
    }
  }

  Future<String> _topPieces(Map<String, dynamic> sub) async {
    try {
      final (start, end) = periodWindow(sub);
      final sql =
          'SELECT json_extract(j.value, \'\$.vestments\') AS name, '
          'SUM(CAST(json_extract(j.value, \'\$.count\') AS INTEGER)) AS pieces '
          'FROM invoices i, json_each(i.list_data) j '
          'WHERE i.customer_id = ? AND DATE(i.invoice_date) >= ? AND DATE(i.invoice_date) < ? '
          'GROUP BY name ORDER BY pieces DESC LIMIT 3';
      final rows = await _db.readData(sql, [
        sub['customer_id'],
        DateFormat('yyyy-MM-dd').format(start),
        DateFormat('yyyy-MM-dd').format(end),
      ]);
      return rows
          .map((r) => '${r['name']} ×${r['pieces']}')
          .join('، ');
    } catch (_) {
      return '';
    }
  }

  /// مجموع دفعات الاشتراك في الشهر الميلادي الحالي
  double _paidThisMonth(
    Map<String, dynamic> sub,
    List<Map<String, dynamic>> pays,
  ) {
    final id = sub['subscription_id'];
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);
    final nextMonth = DateTime(now.year, now.month + 1, 1);
    return pays
        .where((p) {
          if (p['subscription_id'] != id) return false;
          final d = DateTime.tryParse('${p['paid_date']}');
          if (d == null) return false;
          return !d.isBefore(monthStart) && d.isBefore(nextMonth);
        })
        .fold<double>(0, (sum, p) => sum + (p['amount'] ?? 0).toDouble());
  }

  /// دراسة نهاية الشهر: ملخص كامل لكل اشتراك نشط
  List<Map<String, dynamic>> monthStudy() {
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);
    final nextMonth = DateTime(now.year, now.month + 1, 1);
    return subscriptions.map((s) {
      final paidInMonth = payments
          .where((p) {
            if (p['subscription_id'] != s['subscription_id']) return false;
            final d = DateTime.tryParse('${p['paid_date']}');
            if (d == null) return false;
            return !d.isBefore(monthStart) && d.isBefore(nextMonth);
          })
          .fold<double>(0, (sum, p) => sum + (p['amount'] ?? 0).toDouble());
      final until = paidUntil(s);
      return {
        'subscription': s,
        'customer_name': s['customer_name'],
        'price': (s['amount'] ?? 0).toDouble(),
        'period_days': s['period_days'] ?? 30,
        'pieces': s['pieces_count'] ?? 0,
        'top_pieces': s['top_pieces'] ?? '',
        'paid_this_month': paidInMonth,
        'paid_until': until,
        'days_remaining': daysRemaining(s),
        'status': isOverdue(s) ? 'متأخر' : 'نشط',
      };
    }).toList();
  }

  /// إجمالي القطع المُغسلة عبر كل الاشتراكات في شهر تقويمي معين
  Future<int> totalPiecesInMonth(DateTime month) async {
    try {
      final start = DateTime(month.year, month.month, 1);
      final end = DateTime(month.year, month.month + 1, 1);
      final rows = await _db.readData(
        'SELECT COALESCE(SUM(CAST(json_extract(j.value, \'\$.count\') AS INTEGER)), 0) AS pieces '
        'FROM invoices i, json_each(i.list_data) j '
        'WHERE DATE(i.invoice_date) >= ? AND DATE(i.invoice_date) < ?',
        [DateFormat('yyyy-MM-dd').format(start), DateFormat('yyyy-MM-dd').format(end)],
      );
      if (rows.isEmpty) return 0;
      return (rows.first['pieces'] ?? 0) as int;
    } catch (_) {
      return 0;
    }
  }

  /// إجمالي مستحقات الشهر الحالي (الاشتراكات المتأخرة عن السداد)
  Future<List<Map<String, dynamic>>> overdueReport() async {
    final list = subscriptions.where(isOverdue).toList();
    return list;
  }
}