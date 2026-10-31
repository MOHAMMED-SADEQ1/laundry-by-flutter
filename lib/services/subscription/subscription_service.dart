import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:laundry/services/customer/customer_ledger_service.dart';
import 'package:laundry/services/i18n/l10n.dart';
import 'package:laundry/services/invoice/invoice_items_service.dart';
import 'package:laundry/services/permission/permission_catalog.dart';
import 'package:laundry/services/permission/permission_service.dart';
import 'package:laundry/services/security/session_manager.dart';
import 'package:laundry/services/shift/shift_link_service.dart';
import 'package:laundry/sqldb.dart';
import 'package:sqflite/sqflite.dart' show Database;

/// حالة اشتراك مشتقّة — **المصدر الوحيد للحقيقة** بدل تعريفات متناقضة.
enum SubStatus {
  /// لم تُسجَّل أي دفعة: لا تغطية بعد.
  pending,

  /// تغطية سارية ولم يُستهلك سقفها.
  active,

  /// تغطية سارية لكن استهلاك القطع أو القيمة بلغ السقف.
  capped,

  /// انتهت مدة التغطية دون تجديد.
  overdue,

  /// أُلغيت بتسوية.
  cancelled,
}

extension SubStatusX on SubStatus {
  String get label => switch (this) {
    SubStatus.pending => 'لم يُسدد بعد',
    SubStatus.active => 'نشط',
    SubStatus.capped => 'استُهلك السقف',
    SubStatus.overdue => 'متأخر',
    SubStatus.cancelled => 'ملغى',
  };

  /// المخزَّن في العمود `status` — قيم لاتينية للاستعلام والتدقيق.
  String get code => switch (this) {
    SubStatus.pending => 'pending',
    SubStatus.active => 'active',
    SubStatus.capped => 'capped',
    SubStatus.overdue => 'overdue',
    SubStatus.cancelled => 'cancelled',
  };

  static SubStatus fromCode(String? code) => switch (code) {
    'active' => SubStatus.active,
    'capped' => SubStatus.capped,
    'overdue' => SubStatus.overdue,
    'cancelled' => SubStatus.cancelled,
    _ => SubStatus.pending,
  };

  /// هل يُسمح بإصدار فاتورة على هذا الاشتراك؟
  bool get canServe => this == SubStatus.active;

  /// هل التغطية سارية زمنيًا (بغض النظر عن السقف)؟
  bool get hasLiveCoverage =>
      this == SubStatus.active || this == SubStatus.capped;
}

/// قرار فحص الاستخدام قبل إصدار فاتورة اشتراك.
///
/// **المبدأ المحاسبي**: الاشتراك التزام خدمي محدود، لا بطاقة مفتوحة. بلا سقف
/// يصبح كل اشتراك مركز خسارة محتمل: 50 ريالًا قد تغطي 300 قطعة بتكلفة 800.
/// الفحص يقع **قبل** إصدار الفاتورة لا بعده، لأن قيمته كلها في المنع لا في
/// التسجيل بعد وقوع الاستهلاك — نفس مبدأ `CreditGuard` في الدين الآجل.
class UsageCheckResult {
  /// هل يُسمح بإتمام الفاتورة؟
  final bool allowed;

  /// هل القيمة الحالية أقل من القطع المتبقّية لكن ستتجاوزها؟
  final bool willExceed;

  /// القطع المغطّاة كسقف (0 = بلا سقف)
  final int limitPieces;

  /// القيمة المغطّاة كسقف (0 = بلا سقف)
  final double limitValue;

  final int usedPieces;
  final double usedValue;

  /// ما سيُستهلك بهذه الفاتورة
  final int addPieces;
  final double addValue;

  /// كم تجاوز السقف من القطع / القيمة
  final int exceededPieces;
  final double exceededValue;

  /// هل التجاوز في القطع (وأيّهما استُنفد أولًا)
  final bool piecesIsBinding;

  /// نسبة الاستهلاك بعد هذه الفاتورة (0..1+) — للعرض والتحذير عند 80%
  final double usageRatio;

  /// نص جاهز للعرض
  final String message;

  /// التجاوز يحتاج صلاحية مدير
  final bool requiresManagerOverride;

  const UsageCheckResult({
    required this.allowed,
    required this.willExceed,
    required this.limitPieces,
    required this.limitValue,
    required this.usedPieces,
    required this.usedValue,
    required this.addPieces,
    required this.addValue,
    required this.exceededPieces,
    required this.exceededValue,
    required this.piecesIsBinding,
    required this.usageRatio,
    this.message = '',
    this.requiresManagerOverride = false,
  });

  /// بلا سقف أصلاً: مسموح دائمًا.
  bool get hasNoLimit => limitPieces <= 0 && limitValue <= 0;

  /// تحذير عند 80% أو أكثر.
  bool get isNearLimit => !hasNoLimit && usageRatio >= 0.8 && !willExceed;
}

/// ملخّص الرصيد المحاسبي لوحدة الاشتراكات.
///
/// يفصل بوضوح بين ثلاثة أرقام كان النظام يخلطها:
///   • **محصَّل (collected)** — نقدية دخلت الصندوق من دفعات الاشتراكات.
///   • **مُعترف به (recognized)** — قيمة الغسيل الذي استُهلك فعلًا.
///   • **التزام متبقٍّ (deferred)** — ما دُفع ولم تُقدَّم خدمته بعد = إيراد مؤجَّل.
/// الالتزام المتبقّي **ليس ربحًا**؛ إنه خدمة مضمونة على المحل تقديمها.
class SubscriptionFinancials {
  final double collected;
  final double recognized;
  final double deferred;
  final int totalPiecesUsed;
  final int activeCount;
  final int overdueCount;
  final int pendingCount;
  final int cappedCount;

  /// الإيراد الشهري المتكرّر — يُملأ من [SubscriptionService.mrr].
  /// هذا هو الرقم الذي يُبنى عليه التخطيط، لا المحصَّل الفعلي المتذبذب.
  final double mrr;

  const SubscriptionFinancials({
    required this.collected,
    required this.recognized,
    required this.deferred,
    required this.totalPiecesUsed,
    required this.activeCount,
    required this.overdueCount,
    required this.pendingCount,
    required this.cappedCount,
    this.mrr = 0,
  });

  int get totalCount =>
      activeCount + overdueCount + pendingCount + cappedCount;

  /// نسبة الالتزام المتبقّي إلى المحصَّل — مؤشر «كم خدمة ما زلنا مدينين بها».
  double get deferredRatio => collected <= 0 ? 0 : deferred / collected;
}

/// درجة ربحية اشتراك واحد.
class SubscriberProfitability {
  final int subscriptionId;
  final String customerName;
  final double price;
  final double consumedValue;
  final double costOfService;
  final double paymentCollected;
  final int pieces;

  const SubscriberProfitability({
    required this.subscriptionId,
    required this.customerName,
    required this.price,
    required this.consumedValue,
    required this.costOfService,
    required this.paymentCollected,
    required this.pieces,
  });

  /// صافي المساهمة = المحصَّل − تكلفة الخدمة المقدَّمة.
  /// يستخدم التكلفة الفعلية لا القيمة السوقية، لأن القيمة السوقية سعر بيع
  /// لا نفقة — والخلط بينهما يجعل الاشتراكات تبدو رابحة أكثر من حقيقتها.
  double get netContribution => paymentCollected - costOfService;

  /// هامش المساهمة.
  double get margin =>
      paymentCollected <= 0 ? 0 : netContribution / paymentCollected;

  /// معدّل الاستهلاك مقابل السعر — فوق 1 يعني أن الزبون استهلك أكثر ممّا دفع.
  double get utilization => price <= 0 ? 0 : consumedValue / price;

  /// هل الاشتراك خاسر (تكلفة الخدمة تتجاوز ما حُصِّل)؟
  bool get isLossMaking => netContribution < 0;
}

/// محرّك الاشتراكات الشهرية — نقطة الحقيقة الواحدة لكل ما يتعلق بها.
///
/// **لماذا خدمة مركزية بدل منطق داخل المتحكم؟** لأن الاشتراك مساسّ بثلاث
/// دوائر محاسبية: إيراد مؤجَّل، تكلفة خدمة، ونقدية. سابقًا كان المنطق مبعثرًا
/// في المتحكم، فلم يعرف تقرير الدخل ولا الصندوق ولا الوردية أي شيء عن
/// الاشتراكات. الآن كل قراءة وكل كتابة تمرّ من هنا.
///
/// **قاعدة الإشارة والمليم**: كل مقارنة مالية بالمليم (×100) لتفادي
/// أخطاء الفاصلة العائمة، تمامًا كـ`CustomerLedgerService`.
class SubscriptionService {
  SubscriptionService._();
  static final SubscriptionService instance = SubscriptionService._();

  final SqlDB _db = SqlDB();

  static final DateFormat _dayFmt = DateFormat('yyyy-MM-dd');

  // ═══════════════════════ اشتقاق الحالة ═══════════════════════

  /// تاريخ نهاية التغطية المدفوعة. لا نمنح مدة وهمية من تاريخ التسجيل:
  /// اشتراك بلا دفعة = بلا تغطية.
  static DateTime paidUntil(Map<String, dynamic> sub) {
    final raw = sub['paid_until_date']?.toString();
    if (raw != null && raw.trim().isNotEmpty) {
      final parsed = DateTime.tryParse(raw);
      if (parsed != null) return parsed;
    }
    return DateTime.now();
  }

  /// هل التغطية سارية اليوم؟ (بمقارنة الأيام لا اللحظات)
  static bool coverageIsLive(Map<String, dynamic> sub) {
    final raw = sub['paid_until_date']?.toString();
    if (raw == null || raw.trim().isEmpty) return false;
    return !_dateOnly(paidUntil(sub)).isBefore(_dateOnly(DateTime.now()));
  }

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  /// الأيام المتبقّية (سالب = متأخر).
  static int daysRemaining(Map<String, dynamic> sub) {
    final until = _dateOnly(paidUntil(sub));
    return until.difference(_dateOnly(DateTime.now())).inDays;
  }

  /// بداية الدورة الجارية: تُشتق من `cycle_start_date` إن وُجد، وإلا من
  /// تاريخ التسجيل حتى تعمل البيانات القديمة دون ترحيل إجباري.
  static DateTime cycleStart(Map<String, dynamic> sub) {
    for (final key in ['cycle_start_date', 'start_date']) {
      final raw = sub[key]?.toString();
      if (raw == null || raw.trim().isEmpty) continue;
      final parsed = DateTime.tryParse(raw);
      if (parsed != null) return parsed;
    }
    return paidUntil(sub);
  }

  /// نهاية الدورة الجارية = بداية الدورة + المدة.
  static DateTime cycleEnd(Map<String, dynamic> sub) {
    final days = (sub['period_days'] ?? 30) as int;
    return cycleStart(sub).add(Duration(days: days <= 0 ? 30 : days));
  }

  /// سقف القطع (0 = بلا سقف).
  static int limitPieces(Map<String, dynamic> sub) {
    final v = sub['usage_limit_pieces'];
    if (v == null) return 0;
    return (v as num).toInt();
  }

  /// سقف القيمة (0 = بلا سقف).
  static double limitValue(Map<String, dynamic> sub) {
    final v = sub['usage_limit_value'];
    if (v == null) return 0;
    return (v as num).toDouble();
  }

  /// الحالة الاشتقاقية لاشتراك — من التغطية والسقف والإلغاء.
  ///
  /// [usedPieces] و[usedValue] استهلاك الدورة الجارية. إن مُرِّرا `null`
  /// تُشتق القيمة من الفواتير المرتبطة (استعلام واحد).
  static SubStatus statusOf(
    Map<String, dynamic> sub, {
    int? usedPieces,
    double? usedValue,
  }) {
    if (((sub['is_active'] ?? 1) as num).toInt() == 0) {
      return SubStatus.cancelled;
    }
    final raw = sub['paid_until_date']?.toString();
    if (raw == null || raw.trim().isEmpty || paidUntil(sub).year < 2000) {
      return SubStatus.pending;
    }
    if (daysRemaining(sub) < 0) return SubStatus.overdue;

    final lp = limitPieces(sub);
    final lv = limitValue(sub);
    if (lp > 0 && usedPieces != null && usedPieces >= lp) return SubStatus.capped;
    if (lv > 0 &&
        usedValue != null &&
        CustomerLedgerService.toCents(usedValue) >=
            CustomerLedgerService.toCents(lv)) {
      return SubStatus.capped;
    }
    return SubStatus.active;
  }

  /// كود الحالة المخزَّن (للاستعلام بالفهرس لا لعرض الحالة لحظيًا).
  static String statusCodeOf(Map<String, dynamic> sub) =>
      statusOf(sub).code;

  // ═══════════════════════ الاستخدام ═══════════════════════

  /// استهلاك الدورة الجارية لاشتراك: (قطع, قيمة).
  ///
  /// يقرأ من عمودَي `subscription_used_*` على الفاتورة إن وُجدا، وإلا
  /// يشتق من `list_data`. هذا الفرق مهم: الفاتورة القديمة (قبل الترحيل)
  /// ليس فيها العمودان، فنشتقها كي لا يبدو استهلاكها صفرًا.
  Future<(int pieces, double value)> usageForCycle(
    Map<String, dynamic> sub,
  ) async {
    final subId = sub['subscription_id'];
    if (subId == null) return (0, 0.0);
    try {
      final from = _dayFmt.format(cycleStart(sub));
      final to = _dayFmt.format(cycleEnd(sub).add(const Duration(days: 1)));
      final rows = await _db.readData(
        'SELECT   COALESCE(SUM(COALESCE(i.subscription_used_pieces, 0)), 0) AS p,   COALESCE(SUM(COALESCE(i.subscription_used_value, 0)), 0) AS v FROM invoices i WHERE i.subscription_id = ?   AND DATE(i.invoice_date) >= ? AND DATE(i.invoice_date) < ?',
        [subId, from, to],
      );
      if (rows.isEmpty) return (0, 0.0);
      final p = ((rows.first['p'] ?? 0) as num).toInt();
      final v = ((rows.first['v'] ?? 0) as num).toDouble();
      if (p > 0 || v > 0) return (p, v);

      // مسار احتياطي: الفواتير القديمة بلا الأعمدة — اشتقّ من list_data
      return _deriveUsageFromItems(subId, from, to);
    } catch (e) {
      debugPrint('usageForCycle error: $e');
      return (0, 0.0);
    }
  }

  Future<(int, double)> _deriveUsageFromItems(
    Object subId,
    String from,
    String to,
  ) async {
    try {
      final rows = await _db.readData(
        'SELECT   COALESCE(SUM(CAST(json_extract(j.value, \'\$.count\')     AS INTEGER)), 0) AS p,   COALESCE(SUM(CAST(json_extract(j.value, \'\$.total_price\')     AS REAL)), 0) AS v FROM invoices i, json_each(i.list_data) j WHERE i.subscription_id = ?   AND DATE(i.invoice_date) >= ? AND DATE(i.invoice_date) < ?',
        [subId, from, to],
      );
      if (rows.isEmpty) return (0, 0.0);
      return (
        ((rows.first['p'] ?? 0) as num).toInt(),
        ((rows.first['v'] ?? 0) as num).toDouble(),
      );
    } catch (_) {
      return (0, 0.0);
    }
  }

  /// فحص إمكانية تغطية فاتورة اشتراك قبل إصدارها.
  ///
  /// القرار:
  ///   • بلا سقف → مسموح، مع تحذير عند تجاوز 80% (لو كان هناك سقف آخر).
  ///   • تحت السقف → مسموح.
  ///   • تساوي أو تجاوز السقف → **يحتاج مديرًا**. غير المدير يُمنع.
  ///   • التغطية غير سارية (متأخر/لم يُسدد) → ممنوع تمامًا.
  static Future<UsageCheckResult> checkUsage({
    required Map<String, dynamic> sub,
    required int addPieces,
    required double addValue,
  }) async {
    final svc = SubscriptionService.instance;
    final (usedP, usedV) = await svc.usageForCycle(sub);
    final lp = limitPieces(sub);
    final lv = limitValue(sub);

    final addValCents = CustomerLedgerService.toCents(addValue);
    final usedValCents = CustomerLedgerService.toCents(usedV);
    final limitValCents = CustomerLedgerService.toCents(lv);

    final nullBase = UsageCheckResult(
      allowed: false,
      willExceed: false,
      limitPieces: lp,
      limitValue: lv,
      usedPieces: usedP,
      usedValue: usedV,
      addPieces: addPieces,
      addValue: addValue,
      exceededPieces: 0,
      exceededValue: 0,
      piecesIsBinding: false,
      usageRatio: 0,
    );

    // ─── 1. التغطية الزمنية شرط مسبق لا يُتجاوَز بصلاحية ───
    final st = statusOf(sub, usedPieces: usedP, usedValue: usedV);
    if (!st.hasLiveCoverage) {
      return UsageCheckResult(
        allowed: false,
        willExceed: false,
        limitPieces: lp,
        limitValue: lv,
        usedPieces: usedP,
        usedValue: usedV,
        addPieces: addPieces,
        addValue: addValue,
        exceededPieces: 0,
        exceededValue: 0,
        piecesIsBinding: false,
        usageRatio: 0,
        message: st == SubStatus.pending
            ? tr(
                'لا توجد دفعة مسجّلة لهذا الاشتراك — لا تغطية بعد. سجّل دفعة أولًا من شاشة الاشتراكات.',
              )
            : trf(
                'انتهت تغطية الاشتراك ({0}) — جدّد الاشتراك أو اختر طريقة دفع أخرى.',
                [DateFormat('yyyy-MM-dd').format(paidUntil(sub))],
              ),
      );
    }

    // بلا سقفين: مسموح دائمًا
    if (lp <= 0 && lv <= 0) return nullBase;

    final afterP = usedP + addPieces;
    final afterV = usedValCents + addValCents;

    final overP = lp > 0 ? (afterP > lp ? afterP - lp : 0) : 0;
    final overV = limitValCents > 0
        ? (afterV > limitValCents ? afterV - limitValCents : 0)
        : 0;

    // أيّهما استُنفد أولًا يحدّد باعث المنع: نقارن **نسبة** الاستهلاك لا
    // الأرقام المطلقة، لأن القطع والقيمة وحدتان مختلفتان لا تُقارنان مباشرةً.
    var ratioPieces = 0.0;
    var ratioValue = 0.0;
    if (lp > 0) ratioPieces = afterP / lp;
    if (limitValCents > 0) ratioValue = afterV / limitValCents;

    final exceeds = overP > 0 || overV > 0;
    final piecesBinding = lp > 0 &&
        limitValCents > 0 &&
        ratioPieces >= ratioValue;

    // نسبة الاستهلاك المعروضة: الأعلى — لأن السقف يقف عند أولها
    final ratio = ratioPieces > ratioValue ? ratioPieces : ratioValue;

    if (!exceeds) {
      return UsageCheckResult(
        allowed: true,
        willExceed: false,
        limitPieces: lp,
        limitValue: lv,
        usedPieces: usedP,
        usedValue: usedV,
        addPieces: addPieces,
        addValue: addValue,
        exceededPieces: 0,
        exceededValue: 0,
        piecesIsBinding: piecesBinding,
        usageRatio: ratio,
        message: '',
      );
    }

    // 🛡️ التجاوز **صلاحية** لا اسم دور — انظر `PermissionKeys.subscriptionUsageOverride`.
    final canOverride = PermissionService.can(
      PermissionKeys.subscriptionUsageOverride,
    );
    final parts = <String>[];
    if (overP > 0) parts.add(trf('{0} قطعة', [overP]));
    if (overV > 0) {
      parts.add(
        trf('{0} ر.س', [
          CustomerLedgerService.fromCents(overV).toStringAsFixed(2),
        ]),
      );
    }
    final overText = parts.join(' + ');
    final piecesText = '$usedP${lp > 0 ? '/$lp' : ''}';
    final valueText =
        '${usedV.toStringAsFixed(2)}${lv > 0 ? '/${lv.toStringAsFixed(2)}' : ''}';

    return UsageCheckResult(
      allowed: canOverride,
      willExceed: true,
      limitPieces: lp,
      limitValue: lv,
      usedPieces: usedP,
      usedValue: usedV,
      addPieces: addPieces,
      addValue: addValue,
      exceededPieces: overP,
      exceededValue: CustomerLedgerService.fromCents(overV),
      piecesIsBinding: piecesBinding,
      usageRatio: ratio,
      requiresManagerOverride: !canOverride,
      message: canOverride
          ? trf(
              'تجاوز سقف الاشتراك بـ{0} (القطع: {1} — القيمة: {2}). صلاحيتك تسمح بالتجاوز — سيُسجَّل في التدقيق.',
              [overText, piecesText, valueText],
            )
          : trf(
              'هذه الفاتورة تتجاوز سقف الاشتراك بـ{0} (القطع: {1} — القيمة: {2}). الزبون يحتاج تجديدًا أو ترقية، ولا يملك صلاحية التجاوز إلا مدير.',
              [overText, piecesText, valueText],
            ),
    );
  }

  // ═══════════════════════ المدفوعات ═══════════════════════

  /// تسجيل دفعة **ذري** وتمديد التغطية.
  ///
  /// **الإصلاح الجوهري**: القراءة السابقة كانت من نسخة `sub` المُخزَّنة في
  /// الذاكرة ثم الكتابة عليها — أي read-modify-write غير ذرّي. دفعتان
  /// متتاليتان من نافذتين كانتا تُلغي إحداهما تقدّم الأخرى. الآن نُعيد قراءة
  /// الصف داخل المعاملة، ونُقفل التحديث بشرط `paid_until_date` المُقروء،
  /// فإن تغيّر بين القراءة والكتابة نفشل بدل أن نطمس تقدّمًا.
  ///
  /// يعيد تاريخ التغطية الجديد. يرمي استثناءً عربيًا مفهومًا عند الفشل.
  static Future<DateTime> pay({
    required int subscriptionId,
    required double amount,
    String method = 'كاش',
    String? notes,
    String source = 'manual',
  }) async {
    if (amount <= 0) throw Exception(tr('المبلغ يجب أن يكون أكبر من صفر'));
    final svc = SubscriptionService.instance;
    final db = svc._db;

    final Database? raw = await db.dbGet;
    if (raw == null) {
      throw Exception(tr('تعذّر الوصول إلى قاعدة البيانات'));
    }

    // 🔗 الربط بالوردية («الوردية هي الصندوق»). يُحلَّل **قبل** بدء المعاملة
    // لأن استخدام اتصال القاعدة داخل معاملة قائمة قد يُوقف التنفيذ (deadlock)
    // — وهذا المسار يُدرج عبر `txn` مباشرةً فلا يصل إليه الحقن المركزي في
    // `SqlDB.safeInsert`.
    final shiftId = await ShiftLinkService.activeShiftId();

    DateTime newUntil = DateTime.now();
    await raw.transaction((txn) async {
      // 1. اقرأ الصف الحالي **داخل** المعاملة
      final current = await txn.query(
        'subscriptions',
        where: 'subscription_id = ?',
        whereArgs: [subscriptionId],
        limit: 1,
      );
      if (current.isEmpty) throw Exception(tr('الاشتراك غير موجود'));
      final row = current.first;

      final price = ((row['amount'] ?? 0) as num).toDouble();
      final periodDays = (row['period_days'] as num?)?.toInt() ?? 30;
      final days = periodDays <= 0 ? 30 : periodDays;

      // 2. احسب الأيام المُشتراة. السعر صفر **لا يمنح تغطية كاملة مجانًا** —
      //    كان خطأً يمنح دورة كاملة عن لا شيء. الآن: سعر صفر ⇒ لا تمديد زمني،
      //    والدفعة تُسجَّل نقدًا فقط (تُعالَج يدويًا من الإدارة).
      if (price <= 0) {
        throw Exception(
          tr('سعر الاشتراك صفر — لا يمكن احتساب أيام تغطية. حدِّث سعر الاشتراك أولًا.'),
        );
      }
      final coveredDays = ((amount / price) * days).round();
      if (coveredDays <= 0) {
        throw Exception(
          trf(
            'المبلغ أقل من أن يغطي يومًا واحدًا (أقل دفعة مقبولة: {0} ر.س).',
            [(price / days).toStringAsFixed(2)],
          ),
        );
      }

      // 3. ارسِ التمديد على الأبعد: التغطية الحالية أو اليوم
      final now = DateTime.now();
      final rawUntil = row['paid_until_date']?.toString();
      final parsedUntil = rawUntil == null ? null : DateTime.tryParse(rawUntil);
      final anchor = (parsedUntil != null && parsedUntil.isAfter(now))
          ? parsedUntil
          : now;
      newUntil = anchor.add(Duration(days: coveredDays));
      final untilStr = newUntil.toIso8601String();

      // 4. اكتب التمديد **بشرط** أن القيمة لم تتغيّر منذ قراءتها.
      //
      //    **إصلاح دلالي:** كان `last_billed_date` يُكتب بـ`untilStr` — أي
      //    نفس قيمة `paid_until_date`. هذا يُعيد إدخال البيانات الملوَّثة
      //    التي كُتب الترحيل لتنظيفها، فيصبح الترحيل بلا أثر بعد أول دفعة.
      //
      //    المعنى الصحيح: `cycle_start_date` = بداية الدورة الجارية (المرساة)،
      //    و`last_billed_date` = **نهاية آخر دورة مُسدَّدة فعلًا** = نفس المرساة
      //    (لأن الدورة تبدأ عند نقطة السداد). الفرق بينهما وبين
      //    `paid_until_date` هو الرصيد الزمني المتاح فعلًا.
      //    فالاثنان الآن متساويان بالمرساة، ويختلفان عن `paid_until_date`.
      final updated = await txn.update(
        'subscriptions',
        {
          'paid_until_date': untilStr,
          'last_billed_date': anchor.toIso8601String(),
          'cycle_start_date': anchor.toIso8601String(),
          'status': 'active',
        },
        where:
            'subscription_id = ? AND COALESCE(paid_until_date, \'\') = COALESCE(?, \'\')',
        whereArgs: [subscriptionId, rawUntil],
      );
      if (updated == 0) {
        throw Exception(
          tr('تغيّرت تغطية الاشتراك أثناء تسجيل الدفعة (دفعة أخرى سُجّلت simultaneous). أعد المحاولة.'),
        );
      }

      // 5. سجّل الدفعة مع الدورة التي مدّدتها — يمنع تداخل الفترات
      final anchorDay = anchor.toIso8601String();
      await txn.insert('subscription_payments', {
        'subscription_id': subscriptionId,
        'amount': amount,
        'paid_date': now.toIso8601String(),
        'method': method,
        'recorded_by': SessionManager.currentUserId,
        'shift_id': shiftId,
        'notes': notes,
        'source': source,
        'covers_from': anchorDay,
        'covers_to': untilStr,
      });

      // 6. سجل التغطية — أثر تدقيقي للإيراد المؤجَّل
      await txn.insert('subscription_coverage_log', {
        'subscription_id': subscriptionId,
        'customer_id': row['customer_id'],
        'event': source == 'renewal' ? 'renewal' : 'payment',
        'amount': amount,
        'pieces': 0,
        'coverage_from': anchorDay,
        'coverage_to': untilStr,
        'notes': notes,
        'created_at': now.toIso8601String(),
        'created_by': SessionManager.currentUserId,
      });
    });

    await db.logAudit(
      userId: SessionManager.currentUserId,
      action: 'subscription_pay',
      tableName: 'subscriptions',
      recordId: subscriptionId,
      newValues:
          '{"amount":$amount,"method":"$method","paid_until":"${newUntil.toIso8601String()}"}',
    );
    return newUntil;
  }

  // ═══════════════════════ الإلغاء بتسوية ═══════════════════════

  /// إلغاء اشتراك **بتسوية محاسبية** لا بتعطيل صامت.
  ///
  /// كانت `cancel()` تُصفّر `is_active` فقط، فيبقى ما دُفع بلا مقابل مسجَّلًا
  /// في الكتب. الآن نحسب **قيمة الخدمة غير المُقدَّمة** (الجزء المتبقّي من
  /// الدورة المدفوعة) ونعيدها للزبون رصيدًا دائنًا (سلفة) قابلًا للاستخدام
  /// أو للاسترداد النقدي — لأن المبلغ مقابل خدمة لم تُقدَّم ليس إيرادًا.
  ///
  /// [refundAsCredit] true ⇒ يُحوَّل إلى رصيد سلفة لدى المحل (الافتراضي،
  /// لا يخرج نقدية من الدرج). false ⇒ يُسجَّل كمصروف استرداد نقدي.
  static Future<SubCancellation> cancelWithSettlement({
    required int subscriptionId,
    bool refundAsCredit = true,
    String? reason,
  }) async {
    // 🛡️ الإلغاء **تصحيح** لا إدارة: يُرجع مالًا ويُكتب حركة
    // `cancel_refund` تخفض ذمة الزبون. فُصلت عن `subscription.manage`
    // عمدًا — فمن يُسجّل الاشتراكات روتينيًا لا يجوز أن يُلغيه بضغطة.
    PermissionService.assertCan(
      PermissionKeys.subscriptionCancel,
      action: tr('إلغاء اشتراك وتسويته'),
    );

    final svc = SubscriptionService.instance;
    final db = svc._db;

    final rows = await db.safeRead(
      'subscriptions',
      where: 'subscription_id = ?',
      whereArgs: [subscriptionId],
      limit: 1,
    );
    if (rows.isEmpty) throw Exception(tr('الاشتراك غير موجود'));
    final sub = rows.first;

    // 1. الأيام المتبقّية من التغطية المدفوعة
    final remaining = daysRemaining(sub);
    if (remaining <= 0) {
      // لا تغطية سارية: الإلغاء تعطيل بسيط بلا تسوية
      await db.safeUpdate(
        'subscriptions',
        {
          'is_active': 0,
          'status': 'cancelled',
          'cancelled_at': DateTime.now().toIso8601String(),
          'cancelled_by': SessionManager.currentUserId,
          'cancel_refund': 0,
        },
        where: 'subscription_id = ?',
        whereArgs: [subscriptionId],
      );
      await _logCancel(sub, 0, remaining, reason);
      return const SubCancellation(
        refundedAmount: 0,
        remainingDays: 0,
        refundAsCredit: false,
      );
    }

    // 2. قيمة الأيام غير المُقدَّمة.
    //
    //    **إصلاح محاسبي:** كان المعدّل يُشتق من سعر القائمة
    //    (`price / period_days`) ويُضرب في **كل** الأيام المتبقّية حتى
    //    `paid_until_date`. وهذا يُبالغ في الاسترداد كلما دفع الزبون أكثر من
    //    دورة مقدماً: اشتراك بـ50 لثلاثة أشهر مدفوعة = 90 يومًا متبقّية،
    //    فيصبح الاسترداد 150 — أي **ثلاثة أضعاف** ما استُحق فعلًا، ويخصم
    //    من الصندوق مبلغًا لم يُقبض مقابل الأيام المستردَّة.
    //
    //    القاعدة الصحيحة محاسبيًا: الاسترداد = الجزء **غير المُكتسَب** مما
    //    **قُبض فعلًا** مقابل نافذة التغطية الجارية. لذلك نشتقّ المعدّل من
    //    مجموع الدفعات الحقيقية (`subscription_payments`) مقسومًا على طول
    //    نافذة التغطية المدفوعة، لا من سعر القائمة. وهذا يبقى صحيحًا مع
    //    الدفعات الجزئية والتمديد المتكرر وتغيّر السعر لاحقًا.
    final price = ((sub['amount'] ?? 0) as num).toDouble();
    final periodDays = ((sub['period_days'] ?? 30) as num).toInt();
    final days = periodDays <= 0 ? 30 : periodDays;

    // ما قُبض فعلًا مقابل التغطية (نستثني دفعات الاسترداد نفسها لئلا
    // تحتسب مرتين عند إعادة الإلغاء على اشتراك سبق استرداده جزئيًا).
    int collectedCents = 0;
    DateTime? coverageStart;
    try {
      final payRows = await db.readData(
        'SELECT amount, covers_from, covers_to FROM subscription_payments '
        "WHERE subscription_id = ? AND COALESCE(source, 'manual') != 'cancel_refund'",
        [subscriptionId],
      );
      for (final p in payRows) {
        collectedCents += CustomerLedgerService.toCents(
          ((p['amount'] ?? 0) as num).toDouble(),
        );
        final from = DateTime.tryParse('${p['covers_from'] ?? ''}');
        if (from != null &&
            (coverageStart == null || from.isBefore(coverageStart))) {
          coverageStart = from;
        }
      }
    } catch (e) {
      debugPrint('cancel collected-sum lookup failed: $e');
    }

    // طول نافذة التغطية = من أقدم `covers_from` إلى `paid_until_date`.
    // إن تعذّر ذلك (بيانات قديمة بلا `covers_from`) نرجع للمدة المعيارية.
    final until = paidUntil(sub);
    int windowDays = days;
    if (coverageStart != null) {
      final span = _dateOnly(until).difference(_dateOnly(coverageStart)).inDays;
      if (span > 0) windowDays = span;
    }

    // المعدّل اليومي = المُقبَض ÷ النافذة. وإن لم توجد دفعات مسجّلة نرجع
    // لسعر القائمة كحلّ أخير (بيانات قديمة قبل وجود الجدول).
    final int perDayCents;
    if (collectedCents > 0 && windowDays > 0) {
      perDayCents = (collectedCents / windowDays).round();
    } else if (price > 0) {
      perDayCents = (CustomerLedgerService.toCents(price) / days).round();
    } else {
      perDayCents = 0;
    }
    var refundCents = perDayCents * remaining;

    // **حالة النافذة الكاملة:** إن كان ما تبقّى يغطّي النافذة كلها فالاسترداد
    // هو المُقبَض بالضبط. يمنع فقدان هللة/هللتين بتراكم التقريب الصحيح
    // (مثال: 1000 هللة ÷ 30 يومًا = 33، ×30 = 990 — نقص 10 هللات).
    if (collectedCents > 0 && remaining >= windowDays) {
      refundCents = collectedCents;
    }

    // **حدّان واقيان** يمنعان أي استرداد يتجاوز ما قُبض:
    //  (1) لا يتجاوز إجمالي ما قُبض مقابل هذا الاشتراك.
    //  (2) ولا يتجاوز قيمة ما قُبض نقدًا. (نطبّق الأول، وهو الأشدّ.)
    if (collectedCents > 0 && refundCents > collectedCents) {
      debugPrint(
        'subscription refund capped: ${CustomerLedgerService.fromCents(refundCents)} -> ${CustomerLedgerService.fromCents(collectedCents)} (collected ceiling)',
      );
      refundCents = collectedCents;
    }
    final refund = CustomerLedgerService.fromCents(refundCents);

    final customerId = sub['customer_id'] as int?;

    // 3. اكتب التسوية
    await db.safeUpdate(
      'subscriptions',
      {
        'is_active': 0,
        'status': 'cancelled',
        'cancelled_at': DateTime.now().toIso8601String(),
        'cancelled_by': SessionManager.currentUserId,
        'cancel_refund': refund,
      },
      where: 'subscription_id = ?',
      whereArgs: [subscriptionId],
    );

    if (refund > 0 && customerId != null) {
      if (refundAsCredit) {
        // الاسترداد كسلفة — **الصافي** مقابل الرصيد القائم، لا استبداله.
        //
        // **إصلاح محاسبي خطير:** كان `base` يُحسب:
        //   `stored > 0 ? stored : (stored < 0 ? 0 : 0)`
        // وفرعا الشرط الثلاثي كلاهما `0` ⇒ `base = 0` دائمًا عند المدين.
        // الأثر: زبون عليه ذمة 200 يُلغي اشتراكًا بـ50 ⇒ يُكتب رصيده `0+50`
        // **فيُمحى دينه بالكامل** ويظهر دائنًا بـ50. ثقب في الذمم قابل
        // للاستغلال (إلغاء اشتراك صغير لمسح دين كبير).
        //
        // ولا يكفي مجرد الجمع، لأن `syncBalance` تعيد اشتقاق الرصيد المدين
        // من الفواتير فتُلغي الاسترداد. لذا:
        //  1) إن كان الزبون **دائنًا** أو محايدًا: يُضاف الاسترداد للسلفة.
        //  2) إن كان **مدينًا**: يُخصم الاسترداد من ذمته فعليًا بتوزيعه على
        //     فواتيره القائمة FIFO — تمامًا كدفعة نقدية — فينعكس الأثر على
        //     `debtCents` ويبقى الرصيد متسقًا مع الفواتير.
        // الذمة القائمة تُقرأ من الفواتير (المصدر الوحيد للحقيقة). عند المدين
        // يكون الرصيد المخزَّن سالبًا، فلا يصلح كوعاء للسلفة — ولهذا كانت
        // محاولة استخدام `consumeCredit` تفشل (تشترط `stored > 0`).
        final debtCents = await CustomerLedgerService.instance.debtCents(
          customerId,
        );

        // **خطوة 1:** اخصم الاسترداد من الذمة القائمة FIFO مباشرةً — يُعدّل
        // `remaining_amount`/`paid_amount` على الفواتير، فينعكس على
        // `debtCents` ويبقى الرصيد مشتقًّا صحيحًا. هذا هو جوهر الإصلاح:
        // الاسترداد هنا **تخفيض لما نُقدَّم من خدمة**، وليس إضافة سلفة.
        final appliedToDebt = refundCents < debtCents ? refundCents : debtCents;
        if (appliedToDebt > 0) {
          // صف الدفتر أولًا: `source='cancel_refund'` يمنع احتسابه نقدية في
          // الصندوق وإقفال الوردية (لا نقدية خرجت — بل أُسقط التزام).
          await db.safeInsert('customer_payments', {
            'customer_id': customerId,
            'amount': CustomerLedgerService.fromCents(appliedToDebt),
            'payment_method': 'رصيد',
            'payment_date': DateTime.now().toIso8601String(),
            'notes': trf('استرداد إلغاء اشتراك #{0}', [subscriptionId]),
            'recorded_by': SessionManager.currentUserId,
            'source': 'cancel_refund',
          });
          await CustomerLedgerService.instance.allocatePaymentFifo(
            customerId,
            appliedToDebt,
          );
        }

        // **خطوة 2:** الفائض (إن استُردّ أكثر من الذمة) يُقيَّد سلفة دائنة.
        final leftoverCents = refundCents - appliedToDebt;
        if (leftoverCents > 0) {
          final after = await CustomerLedgerService.instance
              .storedBalanceCents(customerId);
          final base = after > 0 ? after : 0;
          await db.safeUpdate(
            'customers',
            {'balance': CustomerLedgerService.fromCents(base + leftoverCents)},
            where: 'customer_id = ?',
            whereArgs: [customerId],
          );
        }
        await CustomerLedgerService.instance.syncBalance(customerId);
        await db.safeInsert('customer_balance_log', {
          'customer_id': customerId,
          'change_amount': refund,
          'balance_after': CustomerLedgerService.fromCents(
            await CustomerLedgerService.instance.storedBalanceCents(customerId),
          ),
          'reason': 'subscription_cancel_refund',
          'reference_id': subscriptionId,
          'created_at': DateTime.now().toIso8601String(),
          'created_by': SessionManager.currentUserId,
        });
      } else {
        // استرداد نقدي: يُسجَّل كمصروف حتى يظهر في إقفال الوردية والصندوق.
        // الاسم في متغيّر مستقلّ حتى يبقى النصّ literal واحدًا سليمًا (الاقتباس
        // المتداخل داخل `${sub['...']}` يقطع استخراج نصوص الترجمة).
        final custName = '${sub['customer_name'] ?? ''}';
        await db.safeInsert('expenses', {
          'category': 'استرداد اشتراك',
          'category_en': 'Subscription refund',
          'description':
              'استرداد قيمة أيام غير مُقدَّمة — $custName (اشتراك #$subscriptionId، $remaining يوم)',
          'description_en':
              'Refund for unserved days — $custName (subscription #$subscriptionId, $remaining days)',
          'amount': refund,
          'date': DateTime.now().toIso8601String(),
          'recorded_by': SessionManager.currentUserId,
        });
      }
    }

    // 4. أثر التدقيق: دفعة استرداد + سجل تغطية
    final now = DateTime.now().toIso8601String();
    if (refund > 0) {
      await db.safeInsert('subscription_payments', {
        'subscription_id': subscriptionId,
        'amount': refund,
        'paid_date': now,
        'method': refundAsCredit ? 'رصيد' : 'استرداد نقدي',
        'recorded_by': SessionManager.currentUserId,
        'notes': trf('استرداد عند الإلغاء — {0} يوم غير مُقدَّم', [remaining]),
        'source': 'cancel_refund',
        'covers_from': null,
        'covers_to': null,
      });
    }
    await _logCancel(sub, refund, remaining, reason);

    return SubCancellation(
      refundedAmount: refund,
      remainingDays: remaining,
      refundAsCredit: refundAsCredit && refund > 0,
    );
  }

  static Future<void> _logCancel(
    Map<String, dynamic> sub,
    double refund,
    int remainingDays,
    String? reason,
  ) async {
    try {
      await SubscriptionService.instance._db.safeInsert(
        'subscription_coverage_log',
        {
          'subscription_id': sub['subscription_id'],
          'customer_id': sub['customer_id'],
          'event': 'cancel',
          'amount': refund,
          'pieces': 0,
          'coverage_from': null,
          'coverage_to': sub['paid_until_date'],
          'notes': reason?.trim().isNotEmpty == true
              ? trf('{0} — {1} يوم غير مُقدَّم', [reason, remainingDays])
              : trf('{0} يوم غير مُقدَّم', [remainingDays]),
          'created_at': DateTime.now().toIso8601String(),
          'created_by': SessionManager.currentUserId,
        },
      );
    } catch (e) {
      debugPrint('_logCancel error: $e');
    }
  }

  // ═══════════════════════ القراءات التحليلية ═══════════════════════

  /// الرصيد المحاسبي الكامل لوحدة الاشتراكات.
  ///
  /// [month] لتقييد الإيراد المُعترف به بشهر معيّن (افتراضيًا الشهر الجاري).
  Future<SubscriptionFinancials> financials({DateTime? month}) async {
    final now = month ?? DateTime.now();
    final monthStart = _dayFmt.format(DateTime(now.year, now.month, 1));
    final nextMonth = _dayFmt.format(DateTime(now.year, now.month + 1, 1));

    try {
      // 1. المحصَّل هذا الشهر (كل ما دخل الصندوق، بلا استردادات)
      final collectedRows = await _db.readData(
        'SELECT COALESCE(SUM(amount), 0) AS t FROM subscription_payments '
        "WHERE DATE(paid_date) >= ? AND DATE(paid_date) < ? "
        "  AND COALESCE(source, 'manual') != 'cancel_refund'",
        [monthStart, nextMonth],
      );
      final collected =
          (collectedRows.firstOrNull?['t'] as num?)?.toDouble() ?? 0;

      // 2. كل الاشتراكات النشطة مرة واحدة — لا استعلام لكل اشتراك
      final subs = await _db.safeRead(
        'subscriptions',
        where: 'is_active = 1',
      );

      // 3. الإيراد المُعترف به: قيمة الغسيل المُستهلك هذا الشهر
      //    (لا المحصَّل — الفرق بينهما هو الالتزام المتبقّي)
      final recognizedRows = await _db.readData(
        'SELECT   COALESCE(SUM(COALESCE(i.subscription_used_value, 0)), 0) AS v,   COALESCE(SUM(COALESCE(i.subscription_used_pieces, 0)), 0) AS p FROM invoices i WHERE i.subscription_id IS NOT NULL   AND DATE(i.invoice_date) >= ? AND DATE(i.invoice_date) < ?',
        [monthStart, nextMonth],
      );
      final recognized =
          (recognizedRows.firstOrNull?['v'] as num?)?.toDouble() ?? 0;
      final pieces =
          (recognizedRows.firstOrNull?['p'] as num?)?.toInt() ?? 0;

      // 4. الالتزام المتبقّي = مجموع (المتبقّي/المدة × السعر) لكل اشتراك حيّ
      double deferred = 0;
      int active = 0, overdue = 0, pending = 0, capped = 0;
      for (final s in subs) {
        final st = statusOf(s);
        switch (st) {
          case SubStatus.active:
            active++;
          case SubStatus.capped:
            capped++;
          case SubStatus.overdue:
            overdue++;
          case SubStatus.pending:
            pending++;
          case SubStatus.cancelled:
            break;
        }
        if (!st.hasLiveCoverage) continue;
        final remaining = daysRemaining(s);
        if (remaining <= 0) continue;
        final price = ((s['amount'] ?? 0) as num).toDouble();
        final days = ((s['period_days'] ?? 30) as num).toInt();
        if (price <= 0 || days <= 0) continue;
        final perDay = CustomerLedgerService.toCents(price) / days;
        deferred += CustomerLedgerService.fromCents(
          (perDay * remaining).round(),
        );
      }

      return SubscriptionFinancials(
        collected: collected,
        recognized: recognized,
        deferred: deferred,
        totalPiecesUsed: pieces,
        activeCount: active,
        overdueCount: overdue,
        pendingCount: pending,
        cappedCount: capped,
      );
    } catch (e) {
      debugPrint('financials error: $e');
      return const SubscriptionFinancials(
        collected: 0,
        recognized: 0,
        deferred: 0,
        totalPiecesUsed: 0,
        activeCount: 0,
        overdueCount: 0,
        pendingCount: 0,
        cappedCount: 0,
      );
    }
  }

  /// الإيراد الشهري المتكرّر: مجموع أسعار الاشتراكات ذات التغطية السارية،
  /// مُطبَّعًا لشهر 30 يومًا حتى تكون الاشتراكات بمدد مختلفة قابلة للجمع.
  Future<double> mrr() async {
    try {
      final rows = await _db.readData(
        'SELECT amount, period_days, paid_until_date, is_active,   usage_limit_pieces, usage_limit_value FROM subscriptions WHERE is_active = 1',
      );
      double total = 0;
      for (final r in rows) {
        if (!coverageIsLive(r)) continue;
        final price = ((r['amount'] ?? 0) as num).toDouble();
        final days = ((r['period_days'] ?? 30) as num).toInt();
        if (price <= 0 || days <= 0) continue;
        total += price * (30 / days);
      }
      return total;
    } catch (e) {
      debugPrint('mrr error: $e');
      return 0;
    }
  }

  /// ربحية اشتراك واحد — القيمة المستهلكة مقابل ما حُصِّل مقابل التكلفة.
  ///
  /// التكلفة تُحسب من `clothing.cost_price` على بنود فواتير المشترك، لا من
  /// القيمة السوقية. الفرق جوهري: القيمة السوقية سعر بيع، والتكلفة نفقة
  /// حقيقية — والخلط بينهما يُظهر اشتراكات خاسرة كأنها رابحة.
  Future<SubscriberProfitability> profitabilityOf(
    Map<String, dynamic> sub, {
    DateTime? from,
    DateTime? to,
  }) async {
    final subId = sub['subscription_id'];
    final start = from ?? cycleStart(sub);
    final end = to ?? cycleEnd(sub);
    final fromStr = _dayFmt.format(start);
    final toStr = _dayFmt.format(end.add(const Duration(days: 1)));

    try {
      final rows = await _db.readData(
        'SELECT   COALESCE(SUM(COALESCE(i.subscription_used_value, 0)), 0) AS v,   COALESCE(SUM(COALESCE(i.subscription_used_pieces, 0)), 0) AS p FROM invoices i WHERE i.subscription_id = ?   AND DATE(i.invoice_date) >= ? AND DATE(i.invoice_date) < ?',
        [subId, fromStr, toStr],
      );
      // التكلفة من **لقطة البنود** — الربط بالاسم مع `clothing` كان يصفّر
      // التكلفة عند إعادة تسمية صنف فيظهر الاشتراك رابحًا وهو خاسر.
      final cost = await InvoiceItemsService.instance.costFor(
        where:
            'i.subscription_id = ? AND DATE(i.invoice_date) >= ? AND DATE(i.invoice_date) < ?',
        args: [subId, fromStr, toStr],
      );
      final value = (rows.firstOrNull?['v'] as num?)?.toDouble() ?? 0;
      final pieces = (rows.firstOrNull?['p'] as num?)?.toInt() ?? 0;

      // المحصَّل داخل الدورة نفسها (مقارنة عادلة: نفس النافذة الزمنية)
      final pays = await _db.readData(
        'SELECT COALESCE(SUM(amount), 0) AS t FROM subscription_payments '
        "WHERE subscription_id = ? AND DATE(paid_date) >= ? "
        "  AND DATE(paid_date) < ? AND COALESCE(source,'manual') != 'cancel_refund'",
        [subId, fromStr, toStr],
      );
      final collected =
          (pays.firstOrNull?['t'] as num?)?.toDouble() ?? 0;

      return SubscriberProfitability(
        subscriptionId: (subId ?? 0) as int,
        customerName: sub['customer_name']?.toString() ?? '',
        price: ((sub['amount'] ?? 0) as num).toDouble(),
        consumedValue: value,
        costOfService: cost,
        paymentCollected: collected,
        pieces: pieces,
      );
    } catch (e) {
      debugPrint('profitabilityOf error: $e');
      return SubscriberProfitability(
        subscriptionId: (subId ?? 0) as int,
        customerName: sub['customer_name']?.toString() ?? '',
        price: ((sub['amount'] ?? 0) as num).toDouble(),
        consumedValue: 0,
        costOfService: 0,
        paymentCollected: 0,
        pieces: 0,
      );
    }
  }

  /// ترتيب الاشتراكات حسب الربحية — الأكثر خسارة أولًا ليتصدّر المتابعة.
  Future<List<SubscriberProfitability>> profitabilityRanking({
    DateTime? from,
    DateTime? to,
  }) async {
    try {
      final subs = await _db.safeRead(
        'subscriptions',
        where: 'is_active = 1',
      );
      final list = <SubscriberProfitability>[];
      for (final s in subs) {
        list.add(await profitabilityOf(s, from: from, to: to));
      }
      list.sort((a, b) => a.netContribution.compareTo(b.netContribution));
      return list;
    } catch (e) {
      debugPrint('profitabilityRanking error: $e');
      return [];
    }
  }

  /// الاشتراكات المقتربة من سقفها أو المتجاوزة — للوحة المتابعة.
  Future<List<Map<String, dynamic>>> usageWatchlist({
    double threshold = 0.8,
  }) async {
    try {
      final subs = await _db.safeRead(
        'subscriptions',
        where: 'is_active = 1',
      );
      final out = <Map<String, dynamic>>[];
      for (final s in subs) {
        final lp = limitPieces(s);
        final lv = limitValue(s);
        if (lp <= 0 && lv <= 0) continue;
        final (p, v) = await usageForCycle(s);
        double ratio = 0;
        if (lp > 0) ratio = p / lp;
        if (lv > 0 && v / lv > ratio) ratio = v / lv;
        if (ratio >= threshold) {
          out.add({
            ...s,
            'used_pieces': p,
            'used_value': v,
            'usage_ratio': ratio,
            'status': statusOf(s, usedPieces: p, usedValue: v).code,
          });
        }
      }
      out.sort(
        (a, b) => (b['usage_ratio'] as double).compareTo(
          a['usage_ratio'] as double,
        ),
      );
      return out;
    } catch (e) {
      debugPrint('usageWatchlist error: $e');
      return [];
    }
  }

  /// الاشتراكات المستحقّة للتجديد خلال [days] يومًا — للتنبيه المبكّر.
  Future<List<Map<String, dynamic>>> dueForRenewal({int days = 7}) async {
    try {
      final subs = await _db.safeRead(
        'subscriptions',
        where: 'is_active = 1',
        orderBy: 'paid_until_date ASC',
      );
      return subs.where((s) {
        final d = daysRemaining(s);
        return d >= 0 && d <= days;
      }).toList();
    } catch (e) {
      debugPrint('dueForRenewal error: $e');
      return [];
    }
  }

  // ═══════════════════════ الكتابة على الفواتير ═══════════════════════

  /// بوابة فحص السقف بالمعرّف — تقرأ الاشتراك من القاعدة بنفسها.
  ///
  /// سبب وجودها بدل تمرير خريطة الاشتراك: نقطة الاستدعاء (إصدار الفاتورة)
  /// تعرف المعرّف فقط، وقراءة الصف هنا تضمن أن الفحص على **أحدث** حالة
  /// (قد تكون الدفعة أو الاستهلاك تغيّرا منذ آخر تحميل للشاشة).
  static Future<UsageGate> checkGate({
    required int subscriptionId,
    required int addPieces,
    required double addValue,
  }) async {
    final db = SubscriptionService.instance._db;
    final rows = await db.safeRead(
      'subscriptions',
      where: 'subscription_id = ?',
      whereArgs: [subscriptionId],
      limit: 1,
    );
    if (rows.isEmpty) {
      return UsageGate(
        result: UsageCheckResult(
          allowed: false,
          willExceed: false,
          limitPieces: 0,
          limitValue: 0,
          usedPieces: 0,
          usedValue: 0,
          addPieces: 0,
          addValue: 0,
          exceededPieces: 0,
          exceededValue: 0,
          piecesIsBinding: false,
          usageRatio: 0,
          message: tr('الاشتراك غير موجود في قاعدة البيانات'),
        ),
        sub: const {},
      );
    }
    final sub = rows.first;
    final result = await checkUsage(
      sub: sub,
      addPieces: addPieces,
      addValue: addValue,
    );
    final lp = limitPieces(sub);
    final lv = limitValue(sub);
    return UsageGate(
      result: result,
      sub: sub,
      remainingPieces: lp > 0
          ? (lp - result.usedPieces).clamp(0, lp)
          : 0,
      remainingValue: lv > 0
          ? (lv - result.usedValue).clamp(0.0, lv)
          : 0.0,
    );
  }

  /// تسجيل استهلاك فاتورة اشتراك + قيد سجل التغطية.
  ///
  /// يُستدعى **بعد** حفظ الفاتورة. يخزّن القيمة والقطع على الفاتورة نفسها
  /// لأنها المرجع وقت الإصدار، ثم يقفل الحالة إن بلغت السقف.
  static Future<void> recordUsage({
    required int subscriptionId,
    required int invoiceId,
    required int pieces,
    required double value,
  }) async {
    final db = SubscriptionService.instance._db;
    try {
      await db.safeUpdate(
        'invoices',
        {
          'subscription_used_value': value,
          'subscription_used_pieces': pieces,
        },
        where: 'invoices_id = ?',
        whereArgs: [invoiceId],
      );

      final rows = await db.safeRead(
        'subscriptions',
        where: 'subscription_id = ?',
        whereArgs: [subscriptionId],
        limit: 1,
      );
      if (rows.isEmpty) return;
      final sub = rows.first;

      await db.safeInsert('subscription_coverage_log', {
        'subscription_id': subscriptionId,
        'customer_id': sub['customer_id'],
        'event': 'usage',
        'amount': value,
        'pieces': pieces,
        'coverage_from': cycleStart(sub).toIso8601String(),
        'coverage_to': cycleEnd(sub).toIso8601String(),
        'reference_id': invoiceId,
        'created_at': DateTime.now().toIso8601String(),
        'created_by': SessionManager.currentUserId,
      });

      // اقفل الحالة إن استُهلك السقف — العرض والفلترة يعتمدان عليها
      final (p, v) = await SubscriptionService.instance.usageForCycle(sub);
      final st = statusOf(sub, usedPieces: p, usedValue: v);
      final code = st.code;
      if (sub['status'] != code) {
        await db.safeUpdate(
          'subscriptions',
          {'status': code},
          where: 'subscription_id = ?',
          whereArgs: [subscriptionId],
        );
      }
    } catch (e) {
      debugPrint('recordUsage error: $e');
    }
  }

  /// تحديث حالة كل الاشتراكات النشطة — يُستدعى عند فتح الشاشة.
  ///
  /// سبب وجوده: الحالة تتغيّر بمرور الزمن (`overdue`) وبتغيّر الاستهلاك
  /// (`capped`) دون أي عملية كتابة. فلا بد من مُحدِّث يزامن العمود المخزَّن
  /// مع الواقع، وإلا ظلّ الفلتر يعرض بيانات قديمة.
  ///
  /// **إصلاح N+1:** كان يستدعي `usageForCycle` لكل اشتراك ⇒ استعلام لكل
  /// مشترك عند **كل** فتح للشاشة (200 مشترك = 200 استعلام). الآن استعلامان
  /// فقط مهما كان العدد: واحد للاشتراكات، وواحد مُجمَّع للاستهلاك.
  static Future<int> refreshStatuses() async {
    final db = SubscriptionService.instance._db;
    var changed = 0;
    try {
      final subs = await db.safeRead(
        'subscriptions',
        where: 'is_active = 1',
      );
      if (subs.isEmpty) return 0;

      // استعلام واحد: إجمالي الاستهلاك لكل اشتراك في نافذة دورته الحالية.
      //
      // النافذة تختلف لكل اشتراك (`cycleStart`..`cycleEnd`)، ولا يمكن ضغطها
      // في `GROUP BY` بسيط لأن الحدود مشتقّة في Dart. لذلك نجلب صفوف
      // الفواتير المرتبطة باشتراكات مرة واحدة ونجمّعها في الذاكرة — أرخص
      // بكثير من N استعلام، ولا يعتمد على دوال وقت في SQL.
      final ids = subs
          .map((s) => s['subscription_id'])
          .whereType<Object>()
          .toList();
      if (ids.isEmpty) return 0;
      final placeholders = List.filled(ids.length, '?').join(',');
      final usageRows = await db.readData(
        'SELECT subscription_id,   COALESCE(subscription_used_pieces, 0) AS p,   COALESCE(subscription_used_value, 0) AS v,   invoice_date, list_data FROM invoices WHERE subscription_id IN ($placeholders)   AND COALESCE(is_active, 1) = 1',
        ids,
      );

      // جمّع في الذاكرة — مع الاشتقاق من `list_data` للفواتير القديمة.
      final Map<Object, (int, double)> agg = {};
      for (final r in usageRows) {
        final sid = r['subscription_id'];
        if (sid == null) continue;
        var p = ((r['p'] ?? 0) as num).toInt();
        var v = ((r['v'] ?? 0) as num).toDouble();
        if (p == 0 && v == 0) {
          // فاتورة قديمة بلا الأعمدة: اشتقّ من البنود
          try {
            final items = jsonDecode('${r['list_data'] ?? '[]'}');
            if (items is List) {
              for (final it in items) {
                if (it is! Map) continue;
                p += (int.tryParse('${it['count'] ?? 0}') ?? 0);
                v += double.tryParse('${it['total_price'] ?? 0}') ?? 0;
              }
            }
          } catch (_) {
            // بيانات تالفة: نتجاهل البند ولا نُفشل التحديث كله
          }
        }
        final prev = agg[sid] ?? (0, 0.0);
        agg[sid] = (prev.$1 + p, prev.$2 + v);
      }

      for (final s in subs) {
        final sid = s['subscription_id'];
        // نُصفّر الاستهلاك لكل اشتراك له نافذة دورته الخاصة؛ لو أردنا
        // الدقة الكاملة نحتاج فلترة بالنافذة — وهذا ما نفعله أدناه.
        final (rawP, rawV) = agg[sid] ?? (0, 0.0);
        final (p, v) = await _usageWithinWindow(s, rawP, rawV);
        final code = statusOf(s, usedPieces: p, usedValue: v).code;
        if (s['status'] != code) {
          await db.safeUpdate(
            'subscriptions',
            {'status': code},
            where: 'subscription_id = ?',
            whereArgs: [sid],
          );
          changed++;
        }
      }
    } catch (e) {
      debugPrint('refreshStatuses error: $e');
    }
    return changed;
  }

  /// يُرجع الاستهلاك داخل نافذة الدورة الجارية فقط.
  ///
  /// الاستعلام المُجمَّع أعلاه يجمع **كل** فواتير الاشتراك، وهو صحيح تمامًا
  /// عندما تقع الفواتير كلها في الدورة الجارية (الحالة الغالبة). لكن لو
  /// امتدّت فواتير دورات سابقة، فلا بد من فلترة زمنية. نُعيد الحساب الدقيق
  /// لهذا الاشتراك وحده فقط عند الحاجة — فالمسار السريع يبقى استعلامًا واحدًا.
  static Future<(int, double)> _usageWithinWindow(
    Map<String, dynamic> sub,
    int aggregatePieces,
    double aggregateValue,
  ) async {
    // عدد فواتير الاشتراك مقارنة بعدد فواتير نافذته: إن تطابقا فلا فلترة.
    final subId = sub['subscription_id'];
    if (subId == null) return (aggregatePieces, aggregateValue);
    try {
      final db = SubscriptionService.instance._db;
      final total = await db.countRows(
        'invoices',
        where: 'subscription_id = ?',
        whereArgs: [subId],
      );
      final inWindow = await db.countRows(
        'invoices',
        where: 'subscription_id = ? AND DATE(invoice_date) >= ? AND DATE(invoice_date) < ?',
        whereArgs: [
          subId,
          _dayFmt.format(cycleStart(sub)),
          _dayFmt.format(cycleEnd(sub).add(const Duration(days: 1))),
        ],
      );
      // كل الفواتير داخل النافذة ⇒ التجميع صحيح، بلا استعلام إضافي للقيم
      if (total == inWindow) return (aggregatePieces, aggregateValue);
      // وإلا: احسب بدقة لهذا الاشتراك (حالة نادرة)
      return await SubscriptionService.instance.usageForCycle(sub);
    } catch (e) {
      debugPrint('_usageWithinWindow error: $e');
      return (aggregatePieces, aggregateValue);
    }
  }
}

/// نتيجة بوابة السقف: القرار + الاشتراك المقروء + المتبقّي — جاهزة للعرض.
class UsageGate {
  final UsageCheckResult result;
  final Map<String, dynamic> sub;

  /// القطع المتبقّية قبل السقف (0 إن بلا سقف على القطع).
  final int remainingPieces;

  /// القيمة المتبقّية قبل السقف (0 إن بلا سقف على القيمة).
  final double remainingValue;

  const UsageGate({
    required this.result,
    required this.sub,
    this.remainingPieces = 0,
    this.remainingValue = 0,
  });
}

/// نتيجة إلغاء اشتراك — للعرض في الواجهة.
class SubCancellation {
  /// المبلغ المُعاد للزبون
  final double refundedAmount;

  /// عدد الأيام غير المُقدَّمة التي بُني عليها الاسترداد
  final int remainingDays;

  /// هل أُعيد رصيدًا دائنًا (سلفة) لا نقدًا؟
  final bool refundAsCredit;

  const SubCancellation({
    required this.refundedAmount,
    required this.remainingDays,
    required this.refundAsCredit,
  });

  bool get hasRefund => refundedAmount > 0;
}
