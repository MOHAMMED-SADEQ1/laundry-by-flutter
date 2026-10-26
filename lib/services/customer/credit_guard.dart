import 'package:flutter/foundation.dart';
import 'package:laundry/services/customer/customer_ledger_service.dart';
import 'package:laundry/services/i18n/currency.dart';
import 'package:laundry/services/i18n/l10n.dart';
import 'package:laundry/services/security/session_manager.dart';
import 'package:laundry/sqldb.dart';

/// نتيجة فحص حدّ الائتمان قبل إتمام بيع آجل.
///
/// **لماذا فحص مسبق منفصل؟** القاعدة المحاسبية «لا تبع آجلًا لمن تجاوز حدّه»
/// يجب أن تُطبَّق في **نقطة واحدة** يمرّ بها كل مسار بيع. لو تُركت لكل شاشة
/// لاختلف السلوك بين الكاشير وشاشة الفواتير، وتسرّبت المبيعات الآجلة فوق
/// الحد بلا ضابط.
class CreditCheckResult {
  /// هل يُسمح بإتمام البيع؟
  final bool allowed;

  /// المبلغ الذي سيُضاف إلى الذمة (المتبقي على الفاتورة)
  final double newDebtAmount;

  /// الذمة الحالية قبل البيع
  final double currentDebt;

  /// الذمة بعد البيع
  final double debtAfter;

  /// حدّ الائتمان (0 = بلا حد)
  final double limit;

  /// المبلغ الذي تجاوز الحد (0 إن لا تجاوز)
  final double exceededBy;

  /// سبب المنع أو التحذير — جاهز للعرض
  final String message;

  /// هل المنع مطلق أم يحتاج تجاوزًا من مدير؟
  final bool requiresManagerOverride;

  const CreditCheckResult({
    required this.allowed,
    required this.newDebtAmount,
    required this.currentDebt,
    required this.debtAfter,
    required this.limit,
    required this.exceededBy,
    required this.message,
    this.requiresManagerOverride = false,
  });

  /// هل البيع مسموح لكن مع تحذير (تجاوز الحد بصلاحية مدير)؟
  bool get isWarning => exceededBy > 0 && allowed;
}

/// حارس حدّ الائتمان — نقطة القرار الوحيدة لكل بيع آجل.
///
/// **المبدأ المحاسبي**: حدّ الائتمان أداة **ضبط وقائي** للدين المعدوم، لا
/// مجرّد رقم معروض. فائدته كلها في منع وقوع الذمة الزائدة، لا في تسجيلها
/// بعد وقوعها. ولذلك يُفحص قبل إتمام البيع، لا بعده.
class CreditGuard {
  CreditGuard._();

  static final SqlDB _db = SqlDB();

  /// مبلغ منسَّق برمز العملة بلغة الواجهة — يُستعمل في الرسائل الموجّهة للمستخدم.
  static String _money(double v) =>
      '${v.toStringAsFixed(2)} ${Currency.symbol}';

  /// حدّ الدين الافتراضي حين لا يُحدَّد للزبون (0 = بلا حد).
  /// يُقرأ مرة واحدة ويُخزَّن مؤقتًا لأن استعلام الإعداد ليس مجانيًا.
  static const String _spDefaultLimit = 'default_credit_limit';

  /// فحص إمكانية إتمام بيع آجل بمبلغ متبقٍ [remainingAmount] لزبون.
  ///
  /// يرجع نتيجة جاهزة للعرض مع قرار واضح:
  ///   • بلا حد (0) → مسموح دائمًا مع تحذير إن كانت الذمة قائمة
  ///   • تجاوز الحد → يتطلب تجاوز مدير (admin/manager)، وإلا يُمنع
  ///   • الذمة كانت قائمة أصلًا وتدفع لزيادتها → تحذير دائم
  static Future<CreditCheckResult> check({
    required int customerId,
    required double remainingAmount,
  }) async {
    try {
      final rows = await _db.readData(
        'SELECT customer_name, COALESCE(credit_limit, 0) AS lim FROM customers WHERE customer_id = ?',
        [customerId],
      );
      if (rows.isEmpty) {
        return const CreditCheckResult(
          allowed: false,
          newDebtAmount: 0,
          currentDebt: 0,
          debtAfter: 0,
          limit: 0,
          exceededBy: 0,
          message: 'الزبون غير موجود في السجل',
        );
      }
      final name = (rows.first['customer_name'] ?? 'الزبون').toString();
      var limit = ((rows.first['lim'] ?? 0) as num).toDouble();
      if (limit <= 0) limit = await _defaultLimit();

      final currentCents = await CustomerLedgerService.instance.debtCents(
        customerId,
      );
      final current = CustomerLedgerService.fromCents(currentCents);
      final addCents = remainingAmount > 0
          ? CustomerLedgerService.toCents(remainingAmount)
          : 0;
      final afterCents = currentCents + addCents;
      final after = CustomerLedgerService.fromCents(afterCents);

      // بلا حد ائتمان: نسمح، لكن ننبّه إن كانت ذمة قائمة أصلًا
      if (limit <= 0) {
        return CreditCheckResult(
          allowed: true,
          newDebtAmount: CustomerLedgerService.fromCents(addCents),
          currentDebt: current,
          debtAfter: after,
          limit: 0,
          exceededBy: 0,
          message: current > 0
              ? trf(
                  '«{0}» عليه ذمة قائمة {1}. لا حدّ ائتمان مضبوط له — يُنصح بتحديد حدّ.',
                  [name, _money(current)],
                )
              : '',
        );
      }

      final limitCents = CustomerLedgerService.toCents(limit);
      if (afterCents <= limitCents) {
        return CreditCheckResult(
          allowed: true,
          newDebtAmount: CustomerLedgerService.fromCents(addCents),
          currentDebt: current,
          debtAfter: after,
          limit: limit,
          exceededBy: 0,
          message: '',
        );
      }

      final exceeded = CustomerLedgerService.fromCents(afterCents - limitCents);
      final canOverride = SessionManager.isManager;

      return CreditCheckResult(
        allowed: canOverride,
        newDebtAmount: CustomerLedgerService.fromCents(addCents),
        currentDebt: current,
        debtAfter: after,
        limit: limit,
        exceededBy: exceeded,
        requiresManagerOverride: !canOverride,
        message: canOverride
            ? trf(
                'تجاوزُ حدّ الائتمان لـ«{0}» بمقدار {1} (الحد {2} — بعد البيع {3}). تسجيلك يسمح بالتجاوز.',
                [name, _money(exceeded), _money(limit), _money(after)],
              )
            : trf(
                '«{0}» سيتجاوز حدّ ائتمانه بمقدار {1} (الحد {2} — بعد البيع {3}). لا يملك صلاحية التجاوز إلا مدير.',
                [name, _money(exceeded), _money(limit), _money(after)],
              ),
      );
    } catch (e) {
      debugPrint('CreditGuard.check error: $e');
      // عند أي خطأ غير متوقّع لا نُعطّل البيع — لكن نسجّل الحالة للتدقيق.
      return const CreditCheckResult(
        allowed: true,
        newDebtAmount: 0,
        currentDebt: 0,
        debtAfter: 0,
        limit: 0,
        exceededBy: 0,
        message: '',
      );
    }
  }

  /// الحدّ الافتراضي العام من الإعدادات (0 = بلا حد).
  static Future<double> _defaultLimit() async {
    try {
      final saved = await _db.getSetting(_spDefaultLimit);
      final parsed = double.tryParse(saved ?? '');
      if (parsed != null && parsed > 0) return parsed;
    } catch (_) {}
    return 0;
  }

  /// ضبط حدّ ائتمان زبون. `0` = يلغي الحدّ.
  /// يسجّل التغيير في سجل التدقيق لأن الحدّ قرار ائتماني يحتاج أثرًا.
  static Future<bool> setLimit({
    required int customerId,
    required double limit,
    int? userId,
  }) async {
    if (limit < 0) return false;
    try {
      final before = await _db.readData(
        'SELECT COALESCE(credit_limit, 0) AS lim FROM customers WHERE customer_id = ?',
        [customerId],
      );
      final old = before.isEmpty
          ? 0
          : ((before.first['lim'] ?? 0) as num).toDouble();

      final rows = await _db.safeUpdate(
        'customers',
        {'credit_limit': limit},
        where: 'customer_id = ?',
        whereArgs: [customerId],
      );
      if (rows > 0) {
        await _db.logAudit(
          userId: userId,
          action: 'credit_limit_change',
          tableName: 'customers',
          recordId: customerId,
          oldValues: '{"credit_limit":$old}',
          newValues: '{"credit_limit":$limit}',
        );
      }
      return rows > 0;
    } catch (e) {
      debugPrint('CreditGuard.setLimit error: $e');
      return false;
    }
  }

  /// قراءة حدّ زبون (0 = بلا حد، مع احتساب الافتراضي العام).
  static Future<double> limitOf(int customerId) async {
    try {
      final rows = await _db.readData(
        'SELECT COALESCE(credit_limit, 0) AS lim FROM customers WHERE customer_id = ?',
        [customerId],
      );
      if (rows.isEmpty) return 0;
      final own = ((rows.first['lim'] ?? 0) as num).toDouble();
      if (own > 0) return own;
      return _defaultLimit();
    } catch (_) {
      return 0;
    }
  }

  /// ضبط الحدّ الافتراضي العام لكل الزبائن بلا حدّ خاص.
  static Future<void> setDefaultLimit(double value, {int? userId}) async {
    await _db.updateSetting(_spDefaultLimit, value.toString());
    await _db.logAudit(
      userId: userId,
      action: 'default_credit_limit_change',
      tableName: 'settings',
      newValues: '{"default_credit_limit":$value}',
    );
  }

  /// الزبائن المتجاوزون لحدّهم حاليًا — للعرض في تقرير المتابعة.
  static Future<List<Map<String, dynamic>>> overLimitCustomers() async {
    try {
      return await _db.readData(
        'SELECT c.customer_id, c.customer_name, c.phone_1,   COALESCE(c.credit_limit, 0) AS lim,   COALESCE((SELECT SUM(i.remaining_amount) FROM invoices i     WHERE i.customer_id = c.customer_id       AND i.subscription_id IS NULL       AND i.remaining_amount > 0.004), 0) AS debt FROM customers c WHERE COALESCE(c.is_active, 1) = 1   AND COALESCE(c.credit_limit, 0) > 0   AND COALESCE((SELECT SUM(i.remaining_amount) FROM invoices i     WHERE i.customer_id = c.customer_id       AND i.subscription_id IS NULL       AND i.remaining_amount > 0.004), 0)     > COALESCE(c.credit_limit, 0) ORDER BY debt DESC',
      );
    } catch (e) {
      debugPrint('CreditGuard.overLimitCustomers error: $e');
      return [];
    }
  }
}
