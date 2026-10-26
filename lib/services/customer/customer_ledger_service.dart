import 'package:flutter/foundation.dart';
import 'package:laundry/services/permission/permission_catalog.dart';
import 'package:laundry/services/permission/permission_service.dart';
import 'package:laundry/services/security/session_manager.dart';
import 'package:laundry/sqldb.dart';
import 'package:laundry/services/i18n/l10n.dart';

/// نتيجة بند ذمة واحد
class DebtItem {
  final int invoiceId;
  final String date;
  final double finalAmount;
  final double paidAmount;
  final double due; // المتبقي على هذه الفاتورة

  const DebtItem({
    required this.invoiceId,
    required this.date,
    required this.finalAmount,
    required this.paidAmount,
    required this.due,
  });

  Map<String, dynamic> toMap() => {
    'invoices_id': invoiceId,
    'invoice_date': date,
    'final_amount': finalAmount,
    'paid_amount': paidAmount,
    'remaining_amount': due,
  };
}

/// محرّك الذمم والأرصدة للزبائن.
///
/// المبدأ المحاسبي المطبَّق هنا:
///   • **الذمة (debt)** = مجموع (final_amount − paid_amount) لكل فاتورة مؤجّلة.
///   • **الرصيد الدائن (credit)** = مبلغ دفعه الزبون زيادةً ولم يُخصم بعد.
///   • الإشارة الموحّدة لعمود `customers.balance`:
///       balance < 0  → الزبون **مدين** لنا بمقدار |balance|
///       balance > 0  → الزبون له **رصيد** عندنا (credit)
///       balance = 0  → مُسدَّد بالكامل
///
/// لا يُخزَّن أي مبلغ "مُشتقّ" بلا مصدر: كل تغيير يمرّ من هنا ويُسجَّل في
/// سجل التدقيق، ودائمًا بالمليم (×100) لتجنّب أخطاء الفاصلة العائمة.
class CustomerLedgerService {
  CustomerLedgerService._();
  static final CustomerLedgerService instance = CustomerLedgerService._();

  final SqlDB _db = SqlDB();

  /// تحويل مبلغ إلى مليم (عدد صحيح) — يمنع أخطاء 0.0000001 في المقارنات
  static int toCents(double amount) => (amount * 100).round();

  static double fromCents(int cents) => cents / 100.0;

  // ═══════════════════ القراءة ═══════════════════

  /// بنود الذمة الفعلية لزبون — مشتقّة من الفواتير لا من عمود مخزَّن.
  Future<List<DebtItem>> openDebts(int customerId) async {
    try {
      final rows = await _db.readData(
        'SELECT invoices_id, invoice_date, final_amount, paid_amount, remaining_amount FROM invoices WHERE customer_id = ? AND subscription_id IS NULL AND remaining_amount > 0.004 ORDER BY invoice_date ASC',
        [customerId],
      );
      return rows
          .map(
            (r) => DebtItem(
              invoiceId: (r['invoices_id'] ?? 0) as int,
              date: r['invoice_date']?.toString() ?? '',
              finalAmount: ((r['final_amount'] ?? 0) as num).toDouble(),
              paidAmount: ((r['paid_amount'] ?? 0) as num).toDouble(),
              due: ((r['remaining_amount'] ?? 0) as num).toDouble(),
            ),
          )
          .toList();
    } catch (e) {
      debugPrint('openDebts error: $e');
      return [];
    }
  }

  /// مجموع الذمة الحقيقية بالقراءة من الفواتير (المصدر الوحيد للحقيقة)
  ///
  /// **إصلاح (2026-10-01):** كانت العتبة هنا `> 0` وحدها بينما `openDebts`
  /// و`debt_report_service` و`customer_account_controller` تستخدم `> 0.004`
  /// ⇒ التقارير والرصيد المخزَّن قد يختلفان بكسور سنت. العتبة الآن موحَّدة.
  Future<int> debtCents(int customerId) async {
    try {
      final rows = await _db.readData(
        'SELECT COALESCE(SUM(remaining_amount), 0) AS due FROM invoices WHERE customer_id = ? AND subscription_id IS NULL AND remaining_amount > 0.004',
        [customerId],
      );
      if (rows.isEmpty) return 0;
      return toCents(((rows.first['due'] ?? 0) as num).toDouble());
    } catch (e) {
      debugPrint('debtCents error: $e');
      return 0;
    }
  }

  /// الرصيد المخزَّن بالقراءة من جدول الزبائن
  Future<int> storedBalanceCents(int customerId) async {
    try {
      final rows = await _db.safeRead(
        'customers',
        where: 'customer_id = ?',
        whereArgs: [customerId],
        limit: 1,
      );
      if (rows.isEmpty) return 0;
      return toCents(((rows.first['balance'] ?? 0) as num).toDouble());
    } catch (e) {
      debugPrint('storedBalanceCents error: $e');
      return 0;
    }
  }

  /// كشف توازن الزبون: هل الرصيد المخزَّن يطابق مجموع الفواتير؟
  /// يُستخدم في شاشة التشخيص وفي الترحيل لتصحيح أرصدة قديمة مختلّة.
  Future<DebtReconciliation> reconcile(int customerId) async {
    final debt = await debtCents(customerId);
    final stored = await storedBalanceCents(customerId);
    // الرصيد المدين يجب أن يكون سالبًا بمقدار الذمة. وأي رصيد موجب
    // (دائن) يبقى كما هو لأنه سلفة لم تُخصم بعد.
    final int expected = stored > 0 ? stored : -debt;
    return DebtReconciliation(
      debtCents: debt,
      storedCents: stored,
      expectedCents: expected,
      isBalanced: stored == expected,
    );
  }

  // ═══════════════════ الكتابة ═══════════════════

  /// إعادة حساب رصيد الزبون من الفواتير وتسجيله.
  /// [keepCredit] أبقِ أي رصيد موجب قائم (سلفة) — القيمة الافتراضية true.
  Future<void> syncBalance(int customerId, {bool keepCredit = true}) async {
    try {
      final stored = await storedBalanceCents(customerId);
      final debt = await debtCents(customerId);
      final int target = (keepCredit && stored > 0) ? stored : -debt;
      if (target == stored) return;

      await _db.safeUpdate(
        'customers',
        {'balance': fromCents(target)},
        where: 'customer_id = ?',
        whereArgs: [customerId],
      );
    } catch (e) {
      debugPrint('syncBalance error: $e');
    }
  }

  /// إعادة حساب أرصدة **كل** الزبائن — للتصحيح بعد ترحيل أو استعادة نسخة.
  ///
  /// 🛡️ **محمية بصلاحية `debt.repair`**: العملية تُعيد كتابة حقل `balance`
  /// لكل زبون دفعةً واحدة. أي مستخدم يملك «تسجيل دفعة» لا يجوز أن يملك
  /// «إعادة اشتقاق كل الأرصدة» — فالثانية تُلغي أثر تدقيق الأول. عند
  /// الفقد ترجع `-1` (لا صفرًا) كي يُفرّق المنادي بين «لا شيء لتصحيحه»
  /// و«لم أُنفّذ».
  Future<int> rebuildAllBalances() async {
    if (!PermissionService.can(PermissionKeys.debtRepair)) {
      debugPrint('rebuildAllBalances مرفوض: لا صلاحية debt.repair');
      return -1;
    }
    int fixed = 0;
    try {
      final customers = await _db.readData(
        'SELECT customer_id, balance FROM customers WHERE COALESCE(is_active, 1) = 1',
      );
      for (final c in customers) {
        final id = c['customer_id'] as int?;
        if (id == null) continue;
        final before = toCents(((c['balance'] ?? 0) as num).toDouble());
        final debt = await debtCents(id);
        final int target = before > 0 ? before : -debt;
        if (target != before) {
          await _db.safeUpdate(
            'customers',
            {'balance': fromCents(target)},
            where: 'customer_id = ?',
            whereArgs: [id],
          );
          fixed++;
        }
      }
    } catch (e) {
      debugPrint('rebuildAllBalances error: $e');
    }
    return fixed;
  }

  /// احتساب ذمة فاتورة جديدة وتسجيلها على الزبون (يُستدعى بعد حفظ الفاتورة).
  /// يرجع الذمة الكلية الجديدة بعد الإضافة.
  Future<double> applyNewInvoiceDebt({
    required int customerId,
    required double remainingAmount,
  }) async {
    if (remainingAmount <= 0) {
      await syncBalance(customerId);
      return fromCents(await debtCents(customerId));
    }
    try {
      final stored = await storedBalanceCents(customerId);
      final debt = await debtCents(customerId);
      // أضف الذمة الجديدة فوق القديمة (أو أبقِ السلفة القائمة كما هي)
      final int target = stored > 0 ? stored : -(debt);
      await _db.safeUpdate(
        'customers',
        {'balance': fromCents(target)},
        where: 'customer_id = ?',
        whereArgs: [customerId],
      );
      return fromCents(debt);
    } catch (e) {
      debugPrint('applyNewInvoiceDebt error: $e');
      return 0;
    }
  }

  /// توزيع مبلغ على ذمم الزبون FIFO من الأقدم.
  ///
  /// تستدعيها أي واجهة تُسجّل سدادًا: شاشة حساب الزبون، الدفعة السريعة من
  /// تقرير الذمم، واسترداد إلغاء الاشتراك. **لا تكرّر منطق التوزيع في مكان
  /// آخر**؛ الاختلاف بين المسارات في الواجهة فقط، لا في القاعدة المحاسبية.
  ///
  /// **مسؤولية المنادي**: إنشاء صف `customer_payments` المناسب **قبل**
  /// الاستدعاء (فهو الذي يحمل `source` ليُستثنى غير النقدي من الصندوق).
  ///
  /// ترجع عدد الفواتير التي مُسّت (0 إن لم تكن هناك ذمة قائمة).
  Future<int> allocatePaymentFifo(int customerId, int amountCents) async {
    if (amountCents <= 0) return 0;
    var remaining = amountCents;
    var touched = 0;
    try {
      final debts = await openDebts(customerId);
      for (final item in debts) {
        if (remaining <= 0) break;
        final dueCents = toCents(item.due);
        final take = remaining >= dueCents ? dueCents : remaining;
        if (take <= 0) continue;

        await _db.safeUpdate(
          'invoices',
          {
            'remaining_amount': fromCents(dueCents - take),
            'paid_amount': fromCents(toCents(item.paidAmount) + take),
          },
          where: 'invoices_id = ?',
          whereArgs: [item.invoiceId],
        );
        remaining -= take;
        touched++;
      }

      // الفائض عن كل الذمم يصبح رصيدًا دائنًا (سلفة) — لا يُهمَل أبدًا
      if (remaining > 0) {
        final stored = await storedBalanceCents(customerId);
        final creditBase = stored > 0 ? stored : 0;
        await _db.safeUpdate(
          'customers',
          {'balance': fromCents(creditBase + remaining)},
          where: 'customer_id = ?',
          whereArgs: [customerId],
        );
      } else {
        // لا فائض: أعِد اشتقاق الرصيد من الفواتير
        await syncBalance(customerId);
      }
      return touched;
    } catch (e) {
      debugPrint('allocatePaymentFifo error: $e');
      return touched;
    }
  }

  /// إنفاق رصيد دائن (سلفة) على ذمم قائمة — FIFO من الأقدم.
  /// يرجع المبلغ المستخدَم فعليًا.
  Future<double> consumeCredit(int customerId, {int? maxCents}) async {
    try {
      final stored = await storedBalanceCents(customerId);
      if (stored <= 0) return 0;

      final debts = await openDebts(customerId);
      var available = stored;
      if (maxCents != null && available > maxCents) available = maxCents;
      var used = 0;

      for (final item in debts) {
        if (available <= 0) break;
        final dueCents = toCents(item.due);
        final take = available >= dueCents ? dueCents : available;
        if (take <= 0) continue;

        final newRemaining = fromCents(dueCents - take);
        final newPaid = fromCents(
          toCents(item.paidAmount) + take,
        );

        await _db.safeUpdate(
          'invoices',
          {'remaining_amount': newRemaining, 'paid_amount': newPaid},
          where: 'invoices_id = ?',
          whereArgs: [item.invoiceId],
        );

        await _db.logAudit(
          userId: SessionManager.currentUserId,
          action: 'customer_credit_used',
          tableName: 'invoices',
          recordId: item.invoiceId,
          newValues:
              '{"credit_used":${fromCents(take)},"remaining":$newRemaining}',
        );

        // صف في دفتر الدفعات بمصدر `credit_use` حتى يتعرّف تقرير الصندوق
        // على أنه **ليس نقدية** ولا يضخّم الإيداعات. المبلغ لا يساوي صفرًا
        // أبدًا (take > 0 مضمون أعلاه) فلا يفسد أي تجميع.
        await _db.safeInsert('customer_payments', {
          'customer_id': customerId,
          'amount': fromCents(take),
          'payment_method': 'رصيد',
          'payment_date': DateTime.now().toIso8601String(),
          'notes': trf('استهلاك رصيد سلفة على فاتورة #{0}', [item.invoiceId]),
          'recorded_by': SessionManager.currentUserId,
          'source': 'credit_use',
          'invoice_id': item.invoiceId,
        });

        available -= take;
        used += take;
      }

      await _db.safeUpdate(
        'customers',
        {'balance': fromCents(stored - used)},
        where: 'customer_id = ?',
        whereArgs: [customerId],
      );
      return fromCents(used);
    } catch (e) {
      debugPrint('consumeCredit error: $e');
      return 0;
    }
  }
}

/// نتيجة مطابقة الرصيد بالفاتير
class DebtReconciliation {
  final int debtCents;
  final int storedCents;
  final int expectedCents;
  final bool isBalanced;

  const DebtReconciliation({
    required this.debtCents,
    required this.storedCents,
    required this.expectedCents,
    required this.isBalanced,
  });

  double get debt => debtCents / 100.0;
  double get stored => storedCents / 100.0;
  double get expected => expectedCents / 100.0;
  double get difference => (storedCents - expectedCents) / 100.0;
}
