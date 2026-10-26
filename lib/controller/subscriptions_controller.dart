import 'dart:convert';

import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:laundry/services/customer/customer_ledger_service.dart';
import 'package:laundry/services/i18n/l10n.dart';
import 'package:laundry/services/security/session_manager.dart';
import 'package:laundry/services/subscription/subscription_service.dart';
import 'package:laundry/sqldb.dart';

/// اشتراكات الزبائن الشهرية — تسجيل + تتبع استحقاق + مدفوعات + سقف استهلاك.
///
/// كل منطق محاسبي/هندسي يقع في [SubscriptionService]، وهذا المتحكم مسؤول عن
/// **حالة الواجهة** فقط: التحميل، الترتيب، والعرض. سبب هذا الفصل أن الاشتراك
/// يمسّ الإيراد المؤجَّل والتكلفة والصندوق، فلا يجوز أن يُحتسب مرتين بمنطقين.
class SubscriptionsController extends GetxController {
  final SqlDB _db = SqlDB();
  final SubscriptionService _svc = SubscriptionService.instance;

  final RxList<Map<String, dynamic>> subscriptions =
      <Map<String, dynamic>>[].obs;
  final RxList<Map<String, dynamic>> customers = <Map<String, dynamic>>[].obs;
  final RxList<Map<String, dynamic>> payments = <Map<String, dynamic>>[].obs;
  final RxBool isLoading = false.obs;

  /// الرصيد المحاسبي للوحدة (محصَّل / مُعترف به / التزام متبقٍّ).
  final Rxn<SubscriptionFinancials> financials =
      Rxn<SubscriptionFinancials>();

  /// الإيراد الشهري المتكرّر.
  final RxDouble mrr = 0.0.obs;

  /// اشتراكات بلغت 80% من سقفها أو تجاوزته.
  final RxList<Map<String, dynamic>> watchlist = <Map<String, dynamic>>[].obs;

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

  // ═══════════════ واجهات اشتقاق الحالة (تفويض للخدمة) ═══════════════
  // هذه الأغلفة موجودة لأن الواجهة تستدعيها مباشرةً. المنطق كله في الخدمة.

  /// تاريخ نهاية التغطية المدفوعة. لا مدة وهمية من تاريخ التسجيل.
  DateTime paidUntil(Map<String, dynamic> sub) =>
      SubscriptionService.paidUntil(sub);

  /// الأيام المتبقّية (سالب = متأخر).
  int daysRemaining(Map<String, dynamic> sub) =>
      SubscriptionService.daysRemaining(sub);

  /// هل سُجِّلت أي دفعة؟
  bool hasPayment(Map<String, dynamic> sub) {
    final id = sub['subscription_id'];
    return payments.any((p) => p['subscription_id'] == id);
  }

  /// هل التغطية سارية اليوم (زمنيًا)؟
  bool hasCoverage(Map<String, dynamic> sub) =>
      SubscriptionService.coverageIsLive(sub);

  /// متأخر = له دفعة لكن انتهت تغطيته، أو لا دفعة إطلاقًا.
  bool isOverdue(Map<String, dynamic> sub) =>
      SubscriptionService.statusOf(sub) == SubStatus.overdue;

  /// الحالة الاشتقاقية الكاملة — تشمل السقف.
  SubStatus statusOf(Map<String, dynamic> sub) =>
      SubscriptionService.statusOf(sub);

  int limitPieces(Map<String, dynamic> sub) =>
      SubscriptionService.limitPieces(sub);

  double limitValue(Map<String, dynamic> sub) =>
      SubscriptionService.limitValue(sub);

  // ═══════════════════════════ التحميل ═══════════════════════════

  /// تحميل الاشتراكات **بلا استعلامات N+1**.
  ///
  /// كان التنفيذ السابق يستدعي ثلاثة استعلامات لكل اشتراك (قطع + أصناف +
  /// فواتير) ⇒ 600 استعلام لـ200 مشترك. الآن: استعلام واحد لكل الجداول
  /// ثم تجميع في Dart — تعقيد ثابت لا خطّي.
  Future<void> loadSubscriptions() async {
    isLoading.value = true;
    try {
      // ─── 0. زامن الحالة المخزَّنة مع الواقع (متأخر/مستهلك السقف) ───
      await SubscriptionService.refreshStatuses();

      // ─── 1. الدفعات كلها مرة واحدة ───
      final pays = await _db
          .safeRead('subscription_payments', orderBy: 'paid_date DESC')
          .catchError((_) => <Map<String, dynamic>>[]);
      payments.assignAll(pays);

      // ─── 2. الاشتراكات النشطة مرة واحدة ───
      final rows = await _db
          .safeRead(
            'subscriptions',
            where: 'is_active = 1',
            orderBy: 'customer_name COLLATE NOCASE ASC',
          )
          .catchError((_) => <Map<String, dynamic>>[]);

      if (rows.isEmpty) {
        subscriptions.assignAll([]);
        financials.value = await _svc.financials();
        mrr.value = await _svc.mrr();
        watchlist.assignAll([]);
        return;
      }

      // ─── 3. كل فواتير الاشتراكات مرة واحدة، مجمَّعة بالمعرّف ───
      final subIds = rows
          .map((s) => s['subscription_id'])
          .whereType<int>()
          .toList();
      final invoicesBySub = await _invoicesBySubscription(subIds);
      final piecesBySub = <int, int>{};
      final valueBySub = <int, double>{};
      final topBySub = <int, String>{};

      for (final entry in invoicesBySub.entries) {
        var pieces = 0;
        var value = 0.0;
        final top = <String, int>{};
        for (final inv in entry.value) {
          // الأعمدة المخزَّنة = المرجع وقت الإصدار (المصدر الأدقّ)
          final storedP = (inv['subscription_used_pieces'] as num?)?.toInt();
          final storedV = (inv['subscription_used_value'] as num?)?.toDouble();
          var invPieces = 0;
          var invValue = 0.0;
          if (storedP != null && (storedP > 0 || (storedV ?? 0) > 0)) {
            invPieces = storedP;
            invValue = storedV ?? 0;
          } else {
            // مسار احتياطي للفواتير القديمة: اشتقّ من البنود
            final parsed = _parseItems(inv['list_data']);
            for (final it in parsed) {
              final c = _asInt(it['count']);
              invPieces += c;
              invValue += _asDouble(it['total_price']);
              final name = '${it['vestments'] ?? ''}'.trim();
              if (name.isNotEmpty) {
                top[name] = (top[name] ?? 0) + c;
              }
            }
          }
          pieces += invPieces;
          value += invValue;
        }
        piecesBySub[entry.key] = pieces;
        valueBySub[entry.key] = value;
        if (top.isNotEmpty) {
          final sorted = top.entries.toList()
            ..sort((a, b) => b.value.compareTo(a.value));
          topBySub[entry.key] = sorted
              .take(3)
              // الاسم بلغة الواجهة (القاموس)، والفاصل يتبع اللغة كذلك.
              .map((e) => '${localizedText(e.key, null)} ×${e.value}')
              .join(L10n.isRtl ? '، ' : ', ');
        }
      }

      // ─── 4. تجميع البطاقات ───
      final now = DateTime.now();
      final monthStart = DateTime(now.year, now.month, 1);
      final enriched = rows.map((s) {
        final id = s['subscription_id'] as int?;
        final monthInvs = id == null
            ? <Map<String, dynamic>>[]
            : _invoicesInMonth(invoicesBySub[id] ?? const [], monthStart);
        var invValue = 0.0;
        for (final inv in monthInvs) {
          invValue += _invoiceValue(inv);
        }
        final usedP = id == null ? 0 : (piecesBySub[id] ?? 0);
        final usedV = id == null ? 0.0 : (valueBySub[id] ?? 0.0);
        return <String, dynamic>{
          ...s,
          'pieces_count': usedP,
          'used_value': usedV,
          'top_pieces': topBySub[id] ?? '',
          'paid_this_month': _paidThisMonth(s, pays),
          'invoices_count': monthInvs.length,
          'invoices_value': invValue,
          'status': SubscriptionService.statusOf(
            s,
            usedPieces: usedP,
            usedValue: usedV,
          ).code,
          'usage_ratio': _usageRatio(s, usedP, usedV),
        };
      }).toList();

      // الأكثر إلحاحًا أولًا: المتأخر ثم المستهلك للسقف ثم الأقرب للانتهاء
      enriched.sort((a, b) {
        final ra = _urgencyRank(a);
        final rb = _urgencyRank(b);
        if (ra != rb) return ra.compareTo(rb);
        return SubscriptionService.daysRemaining(a)
            .compareTo(SubscriptionService.daysRemaining(b));
      });
      subscriptions.assignAll(enriched);

      // ─── 5. المؤشرات المالية + قائمة المتابعة ───
      financials.value = await _svc.financials();
      mrr.value = await _svc.mrr();
      watchlist.assignAll(await _svc.usageWatchlist());
    } catch (e) {
      Get.log('loadSubscriptions error: $e');
    } finally {
      isLoading.value = false;
    }
  }

  int _urgencyRank(Map<String, dynamic> s) => switch (s['status']) {
    'pending' => 0,
    'overdue' => 1,
    'capped' => 2,
    'active' => 3,
    _ => 4,
  };

  double _usageRatio(Map<String, dynamic> s, int pieces, double value) {
    final lp = SubscriptionService.limitPieces(s);
    final lv = SubscriptionService.limitValue(s);
    var ratio = 0.0;
    if (lp > 0) ratio = pieces / lp;
    if (lv > 0 && value / lv > ratio) ratio = value / lv;
    return ratio;
  }

  /// كل فواتير الاشتراكات المعنيّة في استعلام واحد مجمَّعة بالاشتراك.
  Future<Map<int, List<Map<String, dynamic>>>> _invoicesBySubscription(
    List<int> subIds,
  ) async {
    if (subIds.isEmpty) return {};
    try {
      final placeholders = List.filled(subIds.length, '?').join(',');
      final rows = await _db.readData(
        'SELECT invoices_id, subscription_id, invoice_date, total_price,   final_amount, subscription_used_value, subscription_used_pieces,   list_data FROM invoices WHERE subscription_id IN ($placeholders) ORDER BY invoice_date DESC',
        subIds,
      );
      final map = <int, List<Map<String, dynamic>>>{};
      for (final r in rows) {
        final id = (r['subscription_id'] as num?)?.toInt();
        if (id == null) continue;
        (map[id] ??= []).add(r);
      }
      return map;
    } catch (e) {
      Get.log('_invoicesBySubscription error: $e');
      return {};
    }
  }

  List<Map<String, dynamic>> _invoicesInMonth(
    List<Map<String, dynamic>> all,
    DateTime monthStart,
  ) {
    final next = DateTime(monthStart.year, monthStart.month + 1, 1);
    return all.where((inv) {
      final d = DateTime.tryParse('${inv['invoice_date']}');
      if (d == null) return false;
      return !d.isBefore(monthStart) && d.isBefore(next);
    }).toList();
  }

  static double _invoiceValue(Map<String, dynamic> inv) {
    final stored = (inv['subscription_used_value'] as num?)?.toDouble() ?? 0;
    if (stored > 0) return stored;
    final items = _parseItems(inv['list_data']);
    if (items.isEmpty) {
      return _asDouble(inv['final_amount'] ?? inv['total_price']);
    }
    var v = 0.0;
    for (final it in items) {
      v += _asDouble(it['total_price']);
    }
    return v;
  }

  static List<Map<String, dynamic>> _parseItems(Object? raw) {
    if (raw == null) return const [];
    final text = raw.toString().trim();
    if (text.isEmpty) return const [];
    try {
      return List<Map<String, dynamic>>.from(jsonDecode(text));
    } catch (_) {
      return const [];
    }
  }

  static int _asInt(Object? v) => int.tryParse('$v') ?? 0;
  static double _asDouble(Object? v) =>
      double.tryParse('$v'.replaceAll(',', '.')) ?? 0;

  // ═══════════════════════════ الكتابة ═══════════════════════════

  /// إضافة اشتراك جديد — مع التحقق من عدم وجود اشتراك نشط مكرّر للزبون.
  Future<void> addSubscription({
    required int customerId,
    required String customerName,
    required double amount,
    required int periodDays,
    int usageLimitPieces = 0,
    double usageLimitValue = 0,
    String? notes,
  }) async {
    if (amount <= 0) {
      throw Exception(tr('المبلغ الشهري يجب أن يكون أكبر من صفر'));
    }
    final days = periodDays <= 0 ? 30 : periodDays;

    // حماية من الاشتراك المزدوج: زبون واحد باشتراكين يضاعف التغطية ويُفقد
    // السقف معناه (يُستهلك من اثنين). لا نمنع، لكن نُنبّه صاحب القرار.
    final existing = await _db.safeRead(
      'subscriptions',
      where: 'is_active = 1 AND customer_id = ?',
      whereArgs: [customerId],
      limit: 1,
    );
    if (existing.isNotEmpty) {
      final other = existing.first;
      throw Exception(
        trf(
          '«{0}» لديه اشتراك نشط بالفعل (#{1} بمبلغ {2}). أوقف الاشتراك القديم أولًا أو جدّد نفسه.',
          [customerName, other['subscription_id'], other['amount']],
        ),
      );
    }

    final now = DateTime.now().toIso8601String();
    final id = await _db.safeInsert('subscriptions', {
      'customer_id': customerId,
      'customer_name': customerName,
      'amount': amount,
      'period_days': days,
      'start_date': now,
      'cycle_start_date': now,
      'last_billed_date': now,
      'paid_until_date': null,
      'usage_limit_pieces': usageLimitPieces,
      'usage_limit_value': usageLimitValue,
      'notes': notes,
      'is_active': 1,
      'status': 'pending',
    });

    await _db.logAudit(
      userId: SessionManager.currentUserId,
      action: 'subscription_create',
      tableName: 'subscriptions',
      recordId: id,
      newValues:
          '{"customer":"$customerName","amount":$amount,"days":$days,"limit_pieces":$usageLimitPieces,"limit_value":$usageLimitValue}',
    );

    await _db.safeInsert('subscription_coverage_log', {
      'subscription_id': id,
      'customer_id': customerId,
      'event': 'create',
      'amount': 0,
      'pieces': 0,
      'coverage_from': null,
      'coverage_to': null,
      'notes': notes,
      'created_at': now,
      'created_by': SessionManager.currentUserId,
    });

    await loadSubscriptions();
  }

  /// تعديل سقف الاستخدام — قرار إداري يحتاج أثرًا تدقيقيًا.
  Future<void> updateUsageLimits({
    required int subscriptionId,
    required int limitPieces,
    required double limitValue,
  }) async {
    final before = await _db.safeRead(
      'subscriptions',
      where: 'subscription_id = ?',
      whereArgs: [subscriptionId],
      limit: 1,
    );
    final oldP = before.isEmpty
        ? 0
        : SubscriptionService.limitPieces(before.first);
    final oldV = before.isEmpty
        ? 0.0
        : SubscriptionService.limitValue(before.first);

    await _db.safeUpdate(
      'subscriptions',
      {
        'usage_limit_pieces': limitPieces,
        'usage_limit_value': limitValue,
      },
      where: 'subscription_id = ?',
      whereArgs: [subscriptionId],
    );
    await _db.logAudit(
      userId: SessionManager.currentUserId,
      action: 'subscription_limit_change',
      tableName: 'subscriptions',
      recordId: subscriptionId,
      oldValues: '{"limit_pieces":$oldP,"limit_value":$oldV}',
      newValues: '{"limit_pieces":$limitPieces,"limit_value":$limitValue}',
    );
    await loadSubscriptions();
  }

  /// تسجيل دفعة (جزئية أو كاملة) وتمديد التغطية بنسبة المبلغ.
  /// التفويض للخدمة لأن التمديد عملية ذرّية (معاملة قاعدة بيانات).
  Future<DateTime> pay({
    required Map<String, dynamic> sub,
    required double amount,
    String method = 'cash',
    String? notes,
  }) async {
    final id = sub['subscription_id'] as int?;
    if (id == null) throw Exception(tr('معرّف الاشتراك غير صالح'));
    final until = await SubscriptionService.pay(
      subscriptionId: id,
      amount: amount,
      method: method,
      notes: notes,
    );
    await loadSubscriptions();
    return until;
  }

  /// إلغاء بتسوية — استرداد قيمة الأيام غير المُقدَّمة رصيدًا دائنًا أو نقدًا.
  Future<SubCancellation> cancel(
    int subscriptionId, {
    bool refundAsCredit = true,
    String? reason,
  }) async {
    final result = await SubscriptionService.cancelWithSettlement(
      subscriptionId: subscriptionId,
      refundAsCredit: refundAsCredit,
      reason: reason,
    );
    await loadSubscriptions();
    return result;
  }

  // ═══════════════════════════ فحص الاستخدام ═══════════════════════════

  /// فحص إمكانية تغطية فاتورة اشتراك — يُستدعى **قبل** إصدار الفاتورة.
  Future<UsageCheckResult> checkUsage({
    required Map<String, dynamic> sub,
    required int addPieces,
    required double addValue,
  }) => SubscriptionService.checkUsage(
    sub: sub,
    addPieces: addPieces,
    addValue: addValue,
  );

  /// الاشتراك النشط بتغطية سارية لزبون معيّن.
  Map<String, dynamic>? activeSubscriptionFor(int? customerId) {
    if (customerId == null) return null;
    for (final s in subscriptions) {
      if (s['customer_id'] != customerId) continue;
      if (!hasPayment(s)) continue;
      final st = SubscriptionService.statusOf(
        s,
        usedPieces: (s['pieces_count'] as num?)?.toInt(),
        usedValue: (s['used_value'] as num?)?.toDouble(),
      );
      if (st.hasLiveCoverage) return s;
    }
    return null;
  }

  /// هل للزبون تغطية سارية؟
  bool hasActiveCoverage(int? customerId) =>
      activeSubscriptionFor(customerId) != null;

  /// كل اشتراكات زبون (نشطة وغير نشطة) — لكشف الاشتراك المزدوج.
  Future<List<Map<String, dynamic>>> subscriptionsOf(int customerId) async {
    try {
      return await _db.safeRead(
        'subscriptions',
        where: 'customer_id = ?',
        whereArgs: [customerId],
        orderBy: 'is_active DESC, start_date DESC',
      );
    } catch (_) {
      return [];
    }
  }

  // ═══════════════════════════ القراءات ═══════════════════════════

  /// مجموع دفعات الاشتراك في الشهر الميلادي الحالي.
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
          if ('${p['source']}' == 'cancel_refund') return false;
          final d = DateTime.tryParse('${p['paid_date']}');
          if (d == null) return false;
          return !d.isBefore(monthStart) && d.isBefore(nextMonth);
        })
        .fold<double>(0, (sum, p) => sum + _asDouble(p['amount']));
  }

  /// فواتير مشترك — بكل تفاصيلها.
  Future<List<Map<String, dynamic>>> subscriberInvoices(
    int subscriptionId, {
    DateTime? from,
    DateTime? to,
  }) async {
    try {
      final where = [
        'subscription_id = ?',
        if (from != null) 'DATE(invoice_date) >= ?',
        if (to != null) 'DATE(invoice_date) < ?',
      ].join(' AND ');
      final args = [
        subscriptionId,
        if (from != null) DateFormat('yyyy-MM-dd').format(from),
        if (to != null) DateFormat('yyyy-MM-dd').format(to),
      ];
      return await _db.safeRead(
        'invoices',
        where: where,
        whereArgs: args,
        orderBy: 'invoice_date DESC',
      );
    } catch (_) {
      return [];
    }
  }

  /// دراسة نهاية الشهر: ملخص كل اشتراك نشط مع الاستهلاك والسقف.
  List<Map<String, dynamic>> monthStudy() {
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);
    final nextMonth = DateTime(now.year, now.month + 1, 1);
    return subscriptions.map((s) {
      final paidInMonth = payments
          .where((p) {
            if (p['subscription_id'] != s['subscription_id']) return false;
            if ('${p['source']}' == 'cancel_refund') return false;
            final d = DateTime.tryParse('${p['paid_date']}');
            if (d == null) return false;
            return !d.isBefore(monthStart) && d.isBefore(nextMonth);
          })
          .fold<double>(0, (sum, p) => sum + _asDouble(p['amount']));
      final st = SubscriptionService.statusOf(
        s,
        usedPieces: (s['pieces_count'] as num?)?.toInt(),
        usedValue: (s['used_value'] as num?)?.toDouble(),
      );
      return {
        'subscription': s,
        'customer_name': s['customer_name'],
        'price': _asDouble(s['amount']),
        'period_days': s['period_days'] ?? 30,
        'pieces': s['pieces_count'] ?? 0,
        'used_value': s['used_value'] ?? 0,
        'top_pieces': s['top_pieces'] ?? '',
        'paid_this_month': paidInMonth,
        'paid_until': SubscriptionService.paidUntil(s),
        'days_remaining': SubscriptionService.daysRemaining(s),
        'status': st.label,
        'status_code': st.code,
        'usage_ratio': s['usage_ratio'] ?? 0,
        'limit_pieces': SubscriptionService.limitPieces(s),
        'limit_value': SubscriptionService.limitValue(s),
      };
    }).toList();
  }

  /// إجمالي القطع المُغسلة عبر **فواتير الاشتراكات** في شهر تقويمي.
  Future<int> totalPiecesInMonth(DateTime month) async {
    try {
      final start = DateTime(month.year, month.month, 1);
      final end = DateTime(month.year, month.month + 1, 1);
      final rows = await _db.readData(
        'SELECT COALESCE(SUM(COALESCE(i.subscription_used_pieces, 0)), 0)   AS pieces FROM invoices i WHERE i.subscription_id IS NOT NULL   AND DATE(i.invoice_date) >= ? AND DATE(i.invoice_date) < ?',
        [
          DateFormat('yyyy-MM-dd').format(start),
          DateFormat('yyyy-MM-dd').format(end),
        ],
      );
      if (rows.isEmpty) return 0;
      final stored = (rows.first['pieces'] as num?)?.toInt() ?? 0;
      if (stored > 0) return stored;
      // احتياطي للفواتير القديمة
      final fallback = await _db.readData(
        'SELECT COALESCE(SUM(CAST(json_extract(j.value, \'\$.count\')   AS INTEGER)), 0) AS pieces FROM invoices i, json_each(i.list_data) j WHERE i.subscription_id IS NOT NULL   AND DATE(i.invoice_date) >= ? AND DATE(i.invoice_date) < ?',
        [
          DateFormat('yyyy-MM-dd').format(start),
          DateFormat('yyyy-MM-dd').format(end),
        ],
      );
      return (fallback.firstOrNull?['pieces'] as num?)?.toInt() ?? 0;
    } catch (_) {
      return 0;
    }
  }

  /// الاشتراكات المتأخّرة — للعرض والمتابعة.
  Future<List<Map<String, dynamic>>> overdueReport() async =>
      subscriptions.where(isOverdue).toList();

  /// بطاقة تحليل مشترك: فواتيره كاملة + الاستهلاك + المدفوع + الربحية.
  ///
  /// أُضيفت [SubscriberProfitability] لأن المقارنة السابقة كانت تقابل
  /// المدفوع بـ**القيمة السوقية** لا بالتكلفة، فيبدو الاشتراك رابحًا ولو كان
  /// يبيع 100 ريال بخدمة كلّفت 200.
  Future<Map<String, dynamic>> subscriberStudy(
    Map<String, dynamic> sub, {
    DateTime? month,
  }) async {
    final now = month ?? DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);
    final nextMonth = DateTime(now.year, now.month + 1, 1);

    final invoices = await subscriberInvoices(
      sub['subscription_id'] as int,
      from: monthStart,
      to: nextMonth,
    );

    double itemsValue = 0;
    int pieces = 0;
    final detailed = <Map<String, dynamic>>[];
    for (final inv in invoices) {
      final storedP = (inv['subscription_used_pieces'] as num?)?.toInt();
      final storedV = (inv['subscription_used_value'] as num?)?.toDouble();
      var invValue = 0.0;
      var invPieces = 0;
      if (storedP != null && (storedP > 0 || (storedV ?? 0) > 0)) {
        invPieces = storedP;
        invValue = storedV ?? 0;
      } else {
        final items = _parseItems(inv['list_data']);
        for (final it in items) {
          invPieces += _asInt(it['count']);
          invValue += _asDouble(it['total_price']);
        }
        if (invValue == 0) {
          invValue = _asDouble(inv['final_amount'] ?? inv['total_price']);
        }
      }
      itemsValue += invValue;
      pieces += invPieces;
      detailed.add({...inv, '_value': invValue, '_pieces': invPieces});
    }

    final paidInMonth = payments
        .where((p) {
          if (p['subscription_id'] != sub['subscription_id']) return false;
          if ('${p['source']}' == 'cancel_refund') return false;
          final d = DateTime.tryParse('${p['paid_date']}');
          if (d == null) return false;
          return !d.isBefore(monthStart) && d.isBefore(nextMonth);
        })
        .fold<double>(0, (sum, p) => sum + _asDouble(p['amount']));

    // الربحية بدورة الاشتراك و«هذا الشهر» معًا — الزبون قد يكون في دورة
    // بدأت الشهر الماضي، فالمقارنة الشهرية وحدها مضلّلة.
    final profitCycle = await _svc.profitabilityOf(sub);
    final profitMonth = await _svc.profitabilityOf(
      sub,
      from: monthStart,
      to: nextMonth,
    );

    final price = _asDouble(sub['amount']);
    final st = SubscriptionService.statusOf(
      sub,
      usedPieces: pieces,
      usedValue: itemsValue,
    );
    return {
      'subscription': sub,
      'customer_name': sub['customer_name'],
      'price': price,
      'period_days': sub['period_days'] ?? 30,
      'invoices': detailed,
      'invoices_count': invoices.length,
      'pieces': pieces,
      'items_value': itemsValue,
      'paid_this_month': paidInMonth,
      'difference': price - itemsValue,
      'status': st.label,
      'status_code': st.code,
      'paid_until': SubscriptionService.paidUntil(sub),
      // ─── الطبقة المحاسبية الجديدة ───
      'cost_cycle': profitCycle.costOfService,
      'net_cycle': profitCycle.netContribution,
      'margin_cycle': profitCycle.margin,
      'utilization_cycle': profitCycle.utilization,
      'is_loss_making': profitCycle.isLossMaking,
      'cost_month': profitMonth.costOfService,
      'net_month': profitMonth.netContribution,
    };
  }

  /// تنبيهات الواجهة: اشتراكات قاربت سقفها أو انتهت تغطيتها.
  ///
  /// تُستدعى عند فتح الشاشة لعرض الإجراء المطلوب بدل أن يكتشفه الكاشير
  /// لحظة إصدار الفاتورة (حين يكون الزبون واقفًا على الكاشير).
  Future<List<Map<String, dynamic>>> alertsForAction() async {
    final out = <Map<String, dynamic>>[];
    for (final s in subscriptions) {
      final st = SubscriptionService.statusOf(
        s,
        usedPieces: (s['pieces_count'] as num?)?.toInt(),
        usedValue: (s['used_value'] as num?)?.toDouble(),
      );
      final ratio = (s['usage_ratio'] as num?)?.toDouble() ?? 0;
      if (st == SubStatus.pending) {
        out.add({
          'kind': 'unpaid',
          'subscription': s,
          'message': tr('اشتراك بلا دفعة — لا تغطية'),
          'severity': 0,
        });
      } else if (st == SubStatus.overdue) {
        out.add({
          'kind': 'overdue',
          'subscription': s,
          'message': trf('انتهت التغطية منذ {0} يوم', [
            SubscriptionService.daysRemaining(s).abs(),
          ]),
          'severity': 1,
        });
      } else if (st == SubStatus.capped) {
        out.add({
          'kind': 'capped',
          'subscription': s,
          'message': tr('استُهلك سقف الاستخدام'),
          'severity': 2,
        });
      } else if (ratio >= 0.8) {
        out.add({
          'kind': 'near_limit',
          'subscription': s,
          'message': trf('بلغ {0}% من السقف', [(ratio * 100).round()]),
          'severity': 3,
        });
      }
    }
    out.sort(
      (a, b) => (a['severity'] as int).compareTo(b['severity'] as int),
    );
    return out;
  }

  /// الرصيد المتبقّي من التزام الاشتراك (إيراد مؤجَّل) لزبون — يُعرض في
  /// كشف حسابه حتى لا يبدو ما دفعه «رصيدًا مجانيًا» بلا مقابل.
  Future<double> deferredForCustomer(int customerId) async {
    try {
      final subs = await _db.safeRead(
        'subscriptions',
        where: 'is_active = 1 AND customer_id = ?',
        whereArgs: [customerId],
      );
      double total = 0;
      for (final s in subs) {
        if (!SubscriptionService.coverageIsLive(s)) continue;
        final remaining = SubscriptionService.daysRemaining(s);
        if (remaining <= 0) continue;
        final price = _asDouble(s['amount']);
        final days = (_asInt(s['period_days']) == 0 ? 30 : _asInt(s['period_days']));
        if (price <= 0) continue;
        total += CustomerLedgerService.fromCents(
          ((CustomerLedgerService.toCents(price) / days) * remaining).round(),
        );
      }
      return total;
    } catch (_) {
      return 0;
    }
  }
}
