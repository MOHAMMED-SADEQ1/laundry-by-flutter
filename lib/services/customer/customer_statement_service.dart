import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:laundry/sqldb.dart';

/// بند صنف داخل فاتورة (اسم الصنف + العدد + القيمة).
class StatementItem {
  final String name;
  final int count;
  final double value;

  const StatementItem({
    required this.name,
    required this.count,
    required this.value,
  });
}

/// فاتورة واحدة في كشف الحساب.
class StatementInvoice {
  final int id;
  final String date;
  final double total;
  final double paid;
  final double remaining;
  final String paymentMethod;
  final bool isSubscription;

  /// قيمة/قطع الاشتراك المستهلكة في هذه الفاتورة (0 لغير الاشتراكية)
  final int subPieces;
  final double subValue;

  final List<StatementItem> items;

  const StatementInvoice({
    required this.id,
    required this.date,
    required this.total,
    required this.paid,
    required this.remaining,
    required this.paymentMethod,
    required this.isSubscription,
    required this.subPieces,
    required this.subValue,
    required this.items,
  });

  bool get isFullyPaid => remaining <= 0.004;

  /// مجموع قطع هذه الفاتورة — مشتقّ من بنودها.
  int get pieces => items.fold(0, (s, e) => s + e.count);
}

/// دفعة في دفتر الأستاذ.
class StatementPayment {
  final String date;
  final double amount;
  final String method;
  final String source;
  final String note;
  final String userName;
  final int? invoiceId;

  const StatementPayment({
    required this.date,
    required this.amount,
    required this.method,
    required this.source,
    required this.note,
    required this.userName,
    required this.invoiceId,
  });

  /// هل هذه الدفعة نقدية دخلت الصندوق فعلًا؟
  ///
  /// `credit_use` = استهلاك سلفة (تسوية دفاتر لا نقدية)، و`cancel_refund`
  /// = استرداد إلغاء اشتراك. كلاهما **لا** يُحسب ضمن «المسدَّد نقدًا».
  bool get isCash =>
      source != 'credit_use' && source != 'cancel_refund' && method != 'رصيد';
}

/// سطر في سجل استهلاك الاشتراك (القطع التي غُسلت).
class StatementUsage {
  final String date;
  final int subscriptionId;
  final int pieces;
  final double value;
  final int? invoiceId;

  const StatementUsage({
    required this.date,
    required this.subscriptionId,
    required this.pieces,
    required this.value,
    required this.invoiceId,
  });
}

/// إجمالي صنف على مستوى الكشف كله (الأصناف التي أخذها الزبون مجمَّعة).
class ItemSummary {
  final String name;
  int count = 0;
  double value = 0;

  ItemSummary(this.name);
}

/// كشف حساب زبون كامل — كل الأرقام مشتقّة من الفواتير ودفتر الدفعات.
///
/// **الفترة (اختيارية)**: عند تمرير [rangeFrom]/[rangeTo] تصير القوائم
/// والتدفّقات محصورة بالفترة، بينما تبقى **الأرصدة لحظية**: الذمة من
/// [debtNow] (مجموع مستقل غير مقيَّد بالفترة) والرصيد الدائن من
/// `customers.balance`. السبب: «المشتريات/المسدَّد» تدفّق يخصّ الفترة، أما
/// «الذمة/السلفة» فرصيد لحظي — وخلطهما يُظهر ذمة الفترة وكأنها الذمة كلها.
class CustomerStatement {
  final Map<String, dynamic> customer;
  final List<StatementInvoice> invoices;
  final List<StatementPayment> payments;
  final List<StatementUsage> usages;
  final List<Map<String, dynamic>> subscriptions;
  final List<ItemSummary> itemSummary;

  /// الذمة القائمة **الآن** — مجموع `remaining_amount` لكل فواتير الزبون
  /// غير الاشتراكية، **بغضّ النظر عن الفترة**.
  final double debtNow;

  /// حدود الفترة المطلوبة (null = الكشف كامل بلا تقييد).
  final DateTime? rangeFrom;
  final DateTime? rangeTo;

  const CustomerStatement({
    required this.customer,
    required this.invoices,
    required this.payments,
    required this.usages,
    required this.subscriptions,
    required this.itemSummary,
    required this.debtNow,
    this.rangeFrom,
    this.rangeTo,
  });

  int get customerId => (customer['customer_id'] ?? 0) as int;
  String get customerName => '${customer['customer_name'] ?? 'غير محدد'}';
  String get phone {
    for (final k in ['phone_1', 'phone_2', 'customer_phone']) {
      final v = '${customer[k] ?? ''}'.trim();
      if (v.isNotEmpty) return v;
    }
    return '';
  }

  /// هل الكشف مقيَّد بفترة؟
  bool get hasRange => rangeFrom != null || rangeTo != null;

  // ─── الإجماليات ───

  /// إجمالي المشتريات (سعر البيع النهائي لكل الفواتير غير الاشتراكية)
  double get totalPurchases =>
      invoices.where((e) => !e.isSubscription).fold(0.0, (s, e) => s + e.total);

  /// إجمالي المسدَّد على الفواتير (مشتقّ من `paid_amount`)
  double get totalPaidOnInvoices =>
      invoices.where((e) => !e.isSubscription).fold(0.0, (s, e) => s + e.paid);

  /// الذمة القائمة (ما عليه) — **رصيد لحظي** لا تدفّق.
  double get totalDebt => debtNow;

  /// الرصيد الدائن المتاح (ما له) — سلفة لم تُستهلَك
  double get creditBalance {
    final b = ((customer['balance'] ?? 0) as num).toDouble();
    return b > 0 ? b : 0;
  }

  /// صافي الموقف: موجب = له، سالب = عليه.
  ///
  /// عند وجود سلفة **و** ذمة معًا (حالة مشروعة لأن السلفة لا تُستهلك تلقائيًا)
  /// نعرض الصافي = السلفة − الذمة، وهو الرقم الذي يفهمه الزبون.
  double get netPosition =>
      creditBalance > 0 ? creditBalance - totalDebt : -totalDebt;

  /// إجمالي الدفعات النقدية المسجَّلة في دفتر الدفعات
  double get totalCashPayments =>
      payments.where((e) => e.isCash).fold(0.0, (s, e) => s + e.amount);

  /// مجموع استهلاك السلفة (تسويات غير نقدية)
  double get totalCreditUsed => payments
      .where((e) => e.source == 'credit_use')
      .fold(0.0, (s, e) => s + e.amount);

  /// مجموع قطع الاشتراكات المُستهلكة
  int get totalSubscriptionPieces =>
      usages.fold(0, (s, e) => s + e.pieces);

  /// مجموع قيمة الاشتراكات المُستهلكة
  double get totalSubscriptionValue =>
      usages.fold(0.0, (s, e) => s + e.value);

  /// مجموع القطع في الفواتير غير الاشتراكية
  int get totalPieces => invoices
      .where((e) => !e.isSubscription)
      .fold(0, (s, e) => s + e.pieces);

  /// عدد الفواتير غير المسدَّدة
  int get openInvoices =>
      invoices.where((e) => !e.isSubscription && !e.isFullyPaid).length;

  /// تاريخ أقدم ذمة قائمة — يحدّد «منذ متى» لا «كم فقط»
  String? get oldestDebtDate {
    final open = invoices
        .where((e) => !e.isSubscription && !e.isFullyPaid)
        .toList();
    if (open.isEmpty) return null;
    return open.first.date;
  }

  bool get hasDebt => totalDebt > 0.004;
  bool get hasCredit => creditBalance > 0.004;
}

/// بناء كشف حساب الزبون — **قراءة فقط**، لا يكتب شيئًا في القاعدة.
///
/// مصدر الحقيقة: الفواتير (`final_amount`/`paid_amount`/`remaining_amount`)
/// ودفتر الدفعات (`customer_payments`). الرصيد الدائن من `customers.balance`
/// لأنه يمثّل سلفة لا تظهر في الفواتير.
class CustomerStatementService {
  CustomerStatementService._();
  static final CustomerStatementService instance = CustomerStatementService._();

  final SqlDB _db = SqlDB();

  /// [from]/[to] اختياريان: عند تمريرهما تُقيَّد القوائم والتدفّقات بالفترة
  /// (شاملًا يومَي البداية والنهاية)، وتبقى الأرصدة لحظية.
  Future<CustomerStatement?> build(
    int customerId, {
    DateTime? from,
    DateTime? to,
  }) async {
    try {
      final custRows = await _db.safeRead(
        'customers',
        where: 'customer_id = ?',
        whereArgs: [customerId],
        limit: 1,
      );
      if (custRows.isEmpty) return null;
      final customer = custRows.first;

      // ─── حدود الفترة ───
      // الطوابع مخزَّنة **محلية** بصيغة ISO (`toIso8601String`) ⇒ المقارنة
      // النصّية صحيحة ترتيبيًا (وتعمل أيضًا لو خُزّن التاريخ `yyyy-MM-dd`).
      // والحد الأعلى **حصري** (بداية اليوم التالي) ليشمل كل ثواني يوم النهاية
      // بلا حاجة لتنسيق كسور الثواني.
      final fromIso = from == null
          ? null
          : DateTime(from.year, from.month, from.day).toIso8601String();
      final toIso = to == null
          ? null
          : DateTime(
              to.year,
              to.month,
              to.day,
            ).add(const Duration(days: 1)).toIso8601String();
      final rangeArgs = <Object?>[
        if (fromIso != null) fromIso,
        if (toIso != null) toIso,
      ];

      /// شرط الفترة لعمود معيّن. `col` اسم عمود ثابت في الكود لا قيمة مستخدم
      /// ⇒ الإدراج النصّي آمن، والقيم كلها تبقى في `?`.
      String andRange(String col) =>
          (fromIso == null ? '' : ' AND $col >= ?') +
          (toIso == null ? '' : ' AND $col < ?');

      // ─── الفواتير (غير الاشتراكية) ───
      final invRows = await _db.readData(
        'SELECT invoices_id, invoice_date, final_amount, paid_amount, '
        '  remaining_amount, payment_method, subscription_id '
        'FROM invoices WHERE customer_id = ? AND subscription_id IS NULL'
        '${andRange('invoice_date')} '
        'ORDER BY invoice_date ASC',
        [customerId, ...rangeArgs],
      );

      // ─── بنود كل فاتورة في استعلام واحد (تفادي N+1) ───
      final itemsByInvoice = <int, List<StatementItem>>{};
      final summary = <String, ItemSummary>{};
      final itemRows = await _db.readData(
        "SELECT i.invoices_id AS iid, "
        "  json_extract(j.value, '\$.vestments') AS name, "
        "  CAST(json_extract(j.value, '\$.count') AS INTEGER) AS qty, "
        "  CAST(json_extract(j.value, '\$.total_price') AS REAL) AS val "
        'FROM invoices i, json_each(i.list_data) j '
        'WHERE i.customer_id = ? AND i.subscription_id IS NULL'
        '${andRange('i.invoice_date')} '
        'ORDER BY i.invoice_date ASC',
        [customerId, ...rangeArgs],
      );
      for (final r in itemRows) {
        final iid = (r['iid'] as num?)?.toInt();
        if (iid == null) continue;
        final name = '${r['name'] ?? ''}'.trim();
        final qty = (r['qty'] as num?)?.toInt() ?? 0;
        final val = (r['val'] as num?)?.toDouble() ?? 0;
        if (name.isEmpty && qty == 0) continue;

        (itemsByInvoice[iid] ??= <StatementItem>[]).add(
          StatementItem(name: name.isEmpty ? 'غير محدد' : name, count: qty, value: val),
        );
        if (name.isNotEmpty) {
          final s = summary.putIfAbsent(name, () => ItemSummary(name));
          s.count += qty;
          s.value += val;
        }
      }

      final invoices = invRows
          .map(
            (r) => StatementInvoice(
              id: (r['invoices_id'] ?? 0) as int,
              date: '${r['invoice_date'] ?? ''}',
              total: ((r['final_amount'] ?? 0) as num).toDouble(),
              paid: ((r['paid_amount'] ?? 0) as num).toDouble(),
              remaining: ((r['remaining_amount'] ?? 0) as num).toDouble(),
              paymentMethod: '${r['payment_method'] ?? ''}',
              isSubscription: r['subscription_id'] != null,
              subPieces: 0,
              subValue: 0,
              items: itemsByInvoice[(r['invoices_id'] as num?)?.toInt()] ?? const [],
            ),
          )
          .toList();

      // ─── دفتر الدفعات ───
      final payRows = await _db.readData(
        'SELECT cp.payment_date, cp.amount, cp.payment_method, cp.source, '
        '  cp.notes, cp.invoice_id, COALESCE(u.full_name, \'\') AS user_name '
        'FROM customer_payments cp '
        'LEFT JOIN users u ON cp.recorded_by = u.user_id '
        'WHERE cp.customer_id = ?${andRange('cp.payment_date')} '
        'ORDER BY cp.payment_date ASC',
        [customerId, ...rangeArgs],
      );
      final payments = payRows
          .map(
            (r) => StatementPayment(
              date: '${r['payment_date'] ?? ''}',
              amount: ((r['amount'] ?? 0) as num).toDouble(),
              method: '${r['payment_method'] ?? ''}',
              source: '${r['source'] ?? 'manual'}',
              note: '${r['notes'] ?? ''}',
              userName: '${r['user_name'] ?? ''}',
              invoiceId: (r['invoice_id'] as num?)?.toInt(),
            ),
          )
          .toList();

      // ─── سجل استهلاك الاشتراكات (القطع التي غُسلت) ───
      final useRows = await _db.readData(
        'SELECT created_at, subscription_id, pieces, amount, reference_id '
        'FROM subscription_coverage_log '
        "WHERE customer_id = ? AND event = 'usage'${andRange('created_at')} "
        'ORDER BY created_at ASC',
        [customerId, ...rangeArgs],
      );
      final usages = useRows
          .map(
            (r) => StatementUsage(
              date: '${r['created_at'] ?? ''}',
              subscriptionId: (r['subscription_id'] as num?)?.toInt() ?? 0,
              pieces: (r['pieces'] as num?)?.toInt() ?? 0,
              value: ((r['amount'] ?? 0) as num).toDouble(),
              invoiceId: (r['reference_id'] as num?)?.toInt(),
            ),
          )
          .toList();

      // ─── اشتراكاته (للعرض في الترويسة) ───
      final subs = await _db.readData(
        'SELECT * FROM subscriptions WHERE customer_id = ? '
        'ORDER BY subscription_id DESC',
        [customerId],
      );

      // ─── الذمة **الآن** (غير مقيَّدة بالفترة) ───
      // مجموع مستقل حتى لا تُخلط «ذمة الفترة» بالذمة كلها.
      final debtRows = await _db.readData(
        'SELECT COALESCE(SUM(remaining_amount), 0) AS debt FROM invoices '
        'WHERE customer_id = ? AND subscription_id IS NULL',
        [customerId],
      );
      final debtNow = ((debtRows.isEmpty ? 0 : debtRows.first['debt']) as num?)
              ?.toDouble() ??
          0;

      final itemSummary = summary.values.toList()
        ..sort((a, b) => b.count.compareTo(a.count));

      return CustomerStatement(
        customer: customer,
        invoices: invoices,
        payments: payments,
        usages: usages,
        subscriptions: subs,
        itemSummary: itemSummary,
        debtNow: debtNow,
        rangeFrom: from,
        rangeTo: to,
      );
    } catch (e) {
      debugPrint('CustomerStatementService.build error: $e');
      return null;
    }
  }

  /// قائمة الزبائن الذين لهم ذمة أو رصيد — لاختيار من يُطبع كشفه.
  Future<List<Map<String, dynamic>>> debtorsWithBalance() async {
    try {
      return await _db.readData(
        'SELECT c.customer_id, c.customer_name, c.phone_1, '
        '  COALESCE(c.balance, 0) AS balance, '
        '  COALESCE((SELECT SUM(i.remaining_amount) FROM invoices i '
        '    WHERE i.customer_id = c.customer_id '
        '      AND i.subscription_id IS NULL '
        '      AND i.remaining_amount > 0.004), 0) AS debt '
        'FROM customers c '
        'WHERE COALESCE(c.is_active, 1) = 1 '
        'ORDER BY c.customer_name',
      );
    } catch (e) {
      debugPrint('debtorsWithBalance error: $e');
      return [];
    }
  }

  /// فكّ بنود فاتورة من `list_data` — للاستخدام في الشاشات.
  static List<Map<String, dynamic>> decodeItems(dynamic raw) {
    if (raw == null) return const [];
    try {
      final decoded = raw is String ? jsonDecode(raw) : raw;
      if (decoded is List) {
        return decoded.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
      }
    } catch (_) {}
    return const [];
  }
}
