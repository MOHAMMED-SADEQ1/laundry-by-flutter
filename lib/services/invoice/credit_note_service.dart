import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:laundry/core/services/invoicecounterservice.dart';
import 'package:laundry/services/customer/customer_ledger_service.dart';
import 'package:laundry/services/i18n/currency.dart';
import 'package:laundry/services/i18n/l10n.dart';
import 'package:laundry/services/invoice/processing_status.dart';
import 'package:laundry/services/payment/payment_method.dart';
import 'package:laundry/services/permission/permission_catalog.dart';
import 'package:laundry/services/permission/permission_service.dart';
import 'package:laundry/services/security/session_manager.dart';
import 'package:laundry/services/shift/shift_link_service.dart';
import 'package:laundry/sqldb.dart';

/// نتيجة محاولة إرجاع فاتورة.
class CreditNoteResult {
  final bool ok;

  /// رسالة جاهزة للعرض (نجاحًا أو سبب رفض).
  final String message;

  /// رقم **الفاتورة العكسية** التي أُنشئت (`credit_note_of` = الأصل).
  final int? creditInvoiceId;

  /// المبلغ الذي عاد للزبون (رصيدًا أو نقدًا).
  final double refunded;

  /// هل عاد المبلغ نقدًا من الدرج (بدل رصيد سلفة)؟
  final bool refundedCash;

  const CreditNoteResult({
    required this.ok,
    required this.message,
    this.creditInvoiceId,
    this.refunded = 0,
    this.refundedCash = false,
  });

  static CreditNoteResult fail(String message) =>
      CreditNoteResult(ok: false, message: message);
}

/// إشعارات الدائن — **إرجاع كامل** لفاتورة صادرة بلا حذفها.
///
/// ## لماذا فاتورة عكسية لا «تعديل الفاتورة»؟
/// لأن السجل المحاسبي لا يُعاد كتابته: الفاتورة الأصلية تبقى كما صدرت
/// (بالسعر والضريبة والبنود التي رآها الزبون)، ويُضاف **مستند عكسي** سالب
/// يُلغي أثرها. هذا هو الطريق الذي تعتمده الأنظمة الضريبية، وهو أيضًا الطريق
/// الذي يجعل **كل تقرير قائم يعمل بلا تعديل**: التقارير تجمع `final_amount`
/// و`tax_amount` و`total_cost` جمعًا جبريًّا، فالسالب يُلغي الموجب تلقائيًّا.
///
/// ## ما يُلمَس وما لا يُلمَس
/// | الكيان | الأثر |
/// |---|---|
/// | `credit_notes` | صفّ واحد: القيمة والضريبة والأساس والسبب |
/// | `invoices` | صفّ عكسي سالب بعلامة `credit_note_of` |
/// | `invoice_items` | بنود سالبة ⇒ التكلفة تُلغى أيضًا (وإلا انتفخ الربح) |
/// | الأصل | `remaining_amount = 0` فقط — الذمة تُبرأ، والتاريخ لا يُمسّ |
/// | `customers.balance` | يُعاد اشتقاقه؛ ومدفوع الزبون يصير رصيدًا أو نقدًا |
///
/// ## حدود مقصودة
/// - **فاتورة الاشتراك لا تُرجَع من هنا**: قيمتها سُدّدت عند الدفعة واستُهلكت
///   من التغطية؛ تصحيحها إلغاء اشتراك بتسوية (`cancelWithSettlement`).
/// - **إرجاع كامل فقط**: الإرجاع الجزئي يحتاج قواعد توزيع للخصم والضريبة على
///   البنود، وهي قرار تجاري لا يُخترع داخل الخدمة.
class CreditNoteService {
  CreditNoteService._();
  static final CreditNoteService instance = CreditNoteService._();

  final SqlDB _db = SqlDB();

  /// هل سبق إرجاع هذه الفاتورة؟
  Future<bool> isReturned(int invoiceId) async {
    try {
      final rows = await _db.readData(
        'SELECT COUNT(*) AS n FROM "credit_notes" WHERE "invoice_id" = ?',
        [invoiceId],
      );
      return ((rows.firstOrNull?['n'] as num?)?.toInt() ?? 0) > 0;
    } catch (e) {
      debugPrint('CreditNoteService.isReturned error: $e');
      return false;
    }
  }

  /// يُرجع فاتورة كاملة ويُصدر إشعار دائنًا.
  ///
  /// [refundAsCredit] `true` (الافتراضي) ⇒ المدفوع يصير **رصيد سلفة** للزبون
  /// ولا تخرج نقدية من الدرج. `false` ⇒ يُعاد نقدًا (يُنقص صندوق الوردية).
  /// الفاتورة بلا زبون **تُردّ نقدًا حتمًا** — لا حساب يُقيَّد فيه الرصيد.
  Future<CreditNoteResult> returnInvoice({
    required int invoiceId,
    required String reason,
    bool refundAsCredit = true,
  }) async {
    // 🛡️ الصلاحية أولًا وقبل أي قراءة: الإرجاع يُحرّك مالًا وذممًا.
    if (!PermissionService.can(PermissionKeys.invoiceReturn)) {
      return CreditNoteResult.fail(
        tr('لا تملك صلاحية إصدار إشعار دائن — راجع مدير النظام.'),
      );
    }

    final rows = await _db.safeRead(
      'invoices',
      where: 'invoices_id = ?',
      whereArgs: [invoiceId],
      limit: 1,
    );
    if (rows.isEmpty) {
      return CreditNoteResult.fail(tr('الفاتورة غير موجودة.'));
    }
    final inv = rows.first;

    if (inv['credit_note_of'] != null) {
      return CreditNoteResult.fail(
        tr('هذا السجل إشعار دائن بذاته — لا يمكن إرجاعه.'),
      );
    }
    if ((inv['subscription_id'] as num?)?.toInt() != null) {
      return CreditNoteResult.fail(
        tr('فاتورة اشتراك: صحّحها بإلغاء الاشتراك وتسويته، لا بإشعار دائن.'),
      );
    }
    if (await isReturned(invoiceId)) {
      return CreditNoteResult.fail(tr('أُرجعت هذه الفاتورة مسبقًا.'));
    }

    final finalAmount = _num(inv['final_amount']);
    final tax = _num(inv['tax_amount']);
    final gross = _num(inv['total_price']);
    final discount = _num(inv['discount_amount']);
    final paid = _num(inv['paid_amount']);
    final rate = _num(inv['tax_rate']);
    // `tax_base` قد يكون صفرًا في فواتير سبقت لقطة الضريبة ⇒ يُشتقّ.
    final base = _num(inv['tax_base']) != 0
        ? _num(inv['tax_base'])
        : (finalAmount - tax);
    final customerId = (inv['customer_id'] as num?)?.toInt();

    if (finalAmount <= 0) {
      return CreditNoteResult.fail(tr('مبلغ الفاتورة غير صالح للإرجاع.'));
    }

    // الفاتورة بلا زبون لا يمكن تقييد رصيدها ⇒ الإرجاع نقدي حتمًا.
    final cashRefund = !refundAsCredit || customerId == null;
    final refunded = paid > 0 ? paid : 0.0;

    final items = await _itemsFor(invoiceId, inv);
    final now = DateTime.now();
    final nowIso = now.toIso8601String();
    final userId = SessionManager.currentUserId;

    final db = await _db.dbGet;
    if (db == null) {
      return CreditNoteResult.fail(tr('تعذّر الوصول إلى قاعدة البيانات.'));
    }

    // 🔢 الرقم والوردية **قبل** المعاملة (استخدام اتصال القاعدة داخلها
    // يُخاطر بالتوقف — نفس درس `SubscriptionService.pay`).
    final creditId = await InvoiceCounterService.findInvoiceNo();
    final shiftId = await ShiftLinkService.activeShiftId();

    try {
      await db.transaction((txn) async {
        // حرس مزدوج داخل المعاملة: نقرتان متزامنتان لا تُنتجان إشعارين.
        final dup = await txn.query(
          'credit_notes',
          columns: <String>['credit_id'],
          where: 'invoice_id = ?',
          whereArgs: <Object?>[invoiceId],
          limit: 1,
        );
        if (dup.isNotEmpty) {
          throw _AlreadyReturned();
        }

        // 1. مستند الإشعار (السجل القانوني الموجز).
        await txn.insert('credit_notes', {
          'invoice_id': invoiceId,
          'customer_id': customerId,
          'reason': reason.trim().isEmpty ? tr('إرجاع كامل') : reason.trim(),
          'subtotal': _round(base),
          'tax_amount': _round(tax),
          'total': _round(finalAmount),
          'restock_value': 0,
          'created_by': userId,
          'created_at': nowIso,
          'zatca_uuid': null,
        });

        // 2. الفاتورة العكسية — سالبة بالكامل وموسومة بالأصل.
        await txn.insert('invoices', {
          'invoices_id': creditId,
          'invoice_number_text': 'CN-$creditId',
          'shift_id': shiftId,
          'customer_id': customerId,
          'customer_name': inv['customer_name'],
          'customer_phone': inv['customer_phone'],
          'total_price': _round(-gross),
          'discount_amount': _round(-discount),
          'tax_amount': _round(-tax),
          'tax_base': _round(-base),
          'tax_rate': rate,
          'final_amount': _round(-finalAmount),
          // نقدًا: سالبًا كي يُخصم من صندوق الوردية تلقائيًّا.
          // رصيدًا: صفرًا وطريقة «رصيد» فلا تخرج نقدية ولا تتضخّم الإيداعات.
          'paid_amount': cashRefund ? _round(-refunded) : 0.0,
          'payment_method':
              cashRefund ? PaymentMethod.cash.key : PaymentMethod.balance.key,
          'remaining_amount': 0.0,
          'discount_code': inv['discount_code'],
          'invoice_date': nowIso,
          'list_data': jsonEncode(_negativeListData(items)),
          'map_data': jsonEncode({
            'payment':
                cashRefund ? PaymentMethod.cash.key : PaymentMethod.balance.key,
            'summation': _round(-finalAmount),
            'customername': '${inv['customer_name'] ?? ''}',
            'date': _stamp(now),
            'credit_note_of': invoiceId,
          }),
          // مستند مُقفل: لا يدخل خط الغسيل. و`credit_note_of` هو ما يستبعده
          // من لوحة المصنعية صراحةً، فالقيمة هنا للقراءة البشرية فقط.
          'status': ProcessingStatuses.delivered.key,
          'credit_note_of': invoiceId,
          'created_by': userId,
        });

        // 3. بنود سالبة — بلا هذه الخطوة تُلغى الإيرادات وتبقى التكلفة،
        //    فيظهر الربح منخفضًا بمقدار التكلفة كاملة.
        for (final row in _negativeItems(creditId, items, nowIso)) {
          await txn.insert('invoice_items', row);
        }

        // 4. براءة ذمة الأصل — بلا مساس بتاريخه أو مدفوعه.
        await txn.update(
          'invoices',
          {'remaining_amount': 0.0},
          where: 'invoices_id = ?',
          whereArgs: <Object?>[invoiceId],
        );

      });
    } on _AlreadyReturned {
      return CreditNoteResult.fail(tr('أُرجعت هذه الفاتورة مسبقًا.'));
    } catch (e) {
      debugPrint('CreditNoteService.returnInvoice error: $e');
      return CreditNoteResult.fail(trf('تعذّر إصدار الإشعار: {0}', ['$e']));
    }

    // ٦. ردّ المدفوع **رصيدًا**: لا يُضاف إلى `customers.balance` مباشرةً.
    //
    // الرصيد الدائن هنا يعني «سلفة لم تُخصم بعد»، وحقل `balance` **مشتقّ**
    // من الفواتير عبر `syncBalance`. فلو أضفنا المبلغ إلى الحقل مباشرةً
    // لأعادت المزامنة اشتقاقه من الفواتير فمحته (أو لمحته متى كان الزبون
    // مدينًا)، فتصير الـ«سلفة» غير موجودة. المسار الصحيح هو مسار تسجيل
    // الدفعة نفسه: `allocatePaymentFifo` يخصم من أقدم الذمم، والفائض وحده
    // يصبح رصيدًا موجبًا — فيُحترم معنى العمود الواحد ولا يُخترع مصدر ثانٍ.
    if (!cashRefund && refunded > 0) {
      await CustomerLedgerService.instance.allocatePaymentFifo(
        customerId,
        CustomerLedgerService.toCents(refunded),
      );
      final afterCents =
          await CustomerLedgerService.instance.storedBalanceCents(customerId);
      await _db.safeInsert('customer_balance_log', {
        'customer_id': customerId,
        'change_amount': _round(refunded),
        'balance_after': CustomerLedgerService.fromCents(afterCents),
        'reason': 'invoice_return_credit',
        'reference_id': creditId,
        'created_at': nowIso,
        'created_by': userId,
      });
    }

    // بعد نجاح المعاملة: أعِد اشتقاق الرصيد من الفواتير (لا تخمين)، ثم وثّق.
    if (customerId != null) {
      await CustomerLedgerService.instance.syncBalance(customerId);
    }
    await _db.logAudit(
      userId: userId,
      action: 'invoice_return',
      tableName: 'invoices',
      recordId: invoiceId,
      oldValues: jsonEncode({
        'final_amount': finalAmount,
        'paid_amount': paid,
        'tax_amount': tax,
      }),
      newValues: jsonEncode({
        'credit_invoice': creditId,
        'refund': refunded,
        'cash': cashRefund,
        'reason': reason,
      }),
    );

    return CreditNoteResult(
      ok: true,
      message: cashRefund
          ? trf('أُصدر إشعار دائن #{0} — وأُعيد {1} نقدًا من الصندوق.', [
              creditId,
              _money(refunded),
            ])
          : trf('أُصدر إشعار دائن #{0} — وأُضيف {1} رصيدًا للزبون.', [
              creditId,
              _money(refunded),
            ]),
      creditInvoiceId: creditId,
      refunded: refunded,
      refundedCash: cashRefund,
    );
  }

  // ═══════════════════ البنود ═══════════════════

  /// بنود الفاتورة من اللقطة المحاسبية، أو من `list_data` إن لم توجد لقطة.
  Future<List<Map<String, dynamic>>> _itemsFor(
    int invoiceId,
    Map<String, dynamic> inv,
  ) async {
    try {
      final rows = await _db.readData(
        'SELECT * FROM "invoice_items" WHERE "invoice_id" = ? ORDER BY "item_id" ASC',
        [invoiceId],
      );
      if (rows.isNotEmpty) {
        return rows
            .map(
              (r) => <String, dynamic>{
                'name': '${r['item_name'] ?? ''}',
                'name_en': r['item_name_en'],
                'content': '${r['content'] ?? ''}',
                'content_en': r['content_en'],
                'qty': (r['qty'] as num?)?.toInt() ?? 0,
                'price': _num(r['unit_price']),
                'total': _num(r['total_price']),
                'cost': _num(r['unit_cost']),
                'total_cost': _num(r['total_cost']),
                'clothing_id': (r['clothing_id'] as num?)?.toInt(),
                'note': r['note'],
                'note_en': r['note_en'],
              },
            )
            .toList();
      }
    } catch (e) {
      debugPrint('CreditNoteService._itemsFor snapshot error: $e');
    }

    // رجوع احتياطي: فاتورة قديمة بلا لقطة.
    try {
      final decoded = jsonDecode('${inv['list_data'] ?? '[]'}');
      if (decoded is! List) return const [];
      return decoded.whereType<Map>().map((item) {
        final qty = _num(item['count']).round();
        final price = _num(item['price']);
        final line = _num(item['total_price']);
        return <String, dynamic>{
          'name': '${item['vestments'] ?? ''}',
          'name_en': item['vestments_en'],
          'content': '${item['content'] ?? ''}',
          'content_en': item['content_en'],
          'qty': qty,
          'price': price,
          'total': line != 0 ? line : price * qty,
          'cost': 0.0,
          'total_cost': 0.0,
          'clothing_id': null,
          'note': item['note'],
          'note_en': item['note_en'],
        };
      }).toList();
    } catch (e) {
      debugPrint('CreditNoteService._itemsFor legacy error: $e');
      return const [];
    }
  }

  /// بنود `list_data` للفاتورة العكسية — الكمية والإجمالي سالبان.
  List<Map<String, dynamic>> _negativeListData(
    List<Map<String, dynamic>> items,
  ) {
    return items
        .map(
          (it) => <String, dynamic>{
            'vestments': it['name'],
            'vestments_en': it['name_en'],
            'content': it['content'],
            'content_en': it['content_en'],
            'count': -(it['qty'] as int? ?? 0),
            'price': _round(_num(it['price'])),
            'total_price': _round(-_num(it['total'])),
            'note': it['note'],
            'note_en': it['note_en'],
          },
        )
        .toList();
  }

  /// صفوف `invoice_items` للفاتورة العكسية.
  List<Map<String, dynamic>> _negativeItems(
    int creditInvoiceId,
    List<Map<String, dynamic>> items,
    String nowIso,
  ) {
    return items
        .map(
          (it) => <String, dynamic>{
            'invoice_id': creditInvoiceId,
            'clothing_id': it['clothing_id'],
            'item_name': it['name'],
            'item_name_en': it['name_en'],
            'content': it['content'],
            'content_en': it['content_en'],
            'qty': -(it['qty'] as int? ?? 0),
            'unit_price': _round(_num(it['price'])),
            'unit_cost': _round(_num(it['cost'])),
            'total_price': _round(-_num(it['total'])),
            'total_cost': _round(-_num(it['total_cost'])),
            'note': it['note'],
            'note_en': it['note_en'],
            'created_at': nowIso,
          },
        )
        .toList();
  }

  // ═══════════════════ أدوات ═══════════════════

  static double _num(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse('${value ?? ''}') ?? 0.0;
  }

  static double _round(double value) =>
      double.parse(value.toStringAsFixed(2));

  static String _money(double value) =>
      '${value.toStringAsFixed(2)} ${Currency.symbol}';

  /// طابع محايد اللغة (`yyyy-MM-dd HH:mm:ss`) — نفس قاعدة `map_data`.
  static String _stamp(DateTime t) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${t.year}-${two(t.month)}-${two(t.day)} '
        '${two(t.hour)}:${two(t.minute)}:${two(t.second)}';
  }
}

/// إشارة داخلية لتصادم «أُرجعت مسبقًا» داخل المعاملة.
class _AlreadyReturned implements Exception {}
