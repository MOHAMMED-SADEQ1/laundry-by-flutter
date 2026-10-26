import 'package:flutter/foundation.dart';
import 'package:laundry/sqldb.dart';

/// بنود الفاتورة **كلقطة محاسبية** + تكلفتها التاريخية.
///
/// **لماذا وُجد هذا الجدول؟** كانت التكلفة تُحسب بربط بنود الفاتورة بالاسم
/// مع `clothing.cost_price`:
///
///     FROM invoices i, json_each(i.list_data) j, clothing c
///     WHERE json_extract(j.value,'$.vestments') = c.clothing_name
///
/// عيبان صامتان في هذا الربط:
///   1. **إعادة تسمية صنف** تقطع الربط ⇒ تكلفة كل فواتيره التاريخية تصير
///      **صفرًا** ⇒ الربح ينتفخ بلا تحذير.
///   2. `cost_price` **الحالية** لا تكلفة يوم البيع ⇒ تعديل سعر التكلفة
///      يُعيد كتابة أرباح الماضي.
///
/// الفصل المعماري:
///   • `invoices.list_data` = مصدر **العرض** (ما رآه الزبون على الفاتورة).
///   • `invoice_items`      = مصدر **المحاسبة** (التكلفة والربح).
///
/// ولا يُقرأ الرقم من أحدهما للآخر — كل سؤال من مصدره.
class InvoiceItemsService {
  InvoiceItemsService._();
  static final InvoiceItemsService instance = InvoiceItemsService._();

  final SqlDB _db = SqlDB();

  /// يكتب لقطة بنود فاتورة واحدة.
  ///
  /// **متكرر الآمان**: يحذف بنود الفاتورة أولًا ثم يكتبها، فإعادة الاستدعاء
  /// لا تُضاعف الصفوف (وهو ما يهمّ عند إعادة إصدار فاتورة أو إصلاح لقطة).
  ///
  /// يرجع عدد الصفوف المكتوبة.
  Future<int> writeSnapshot(
    int invoiceId,
    List<Map<String, dynamic>> items,
  ) async {
    if (items.isEmpty) return 0;
    try {
      final costs = await _clothingMap();

      await _db.safeDelete(
        'invoice_items',
        where: 'invoice_id = ?',
        whereArgs: [invoiceId],
      );

      final now = DateTime.now().toIso8601String();
      var written = 0;
      for (final item in items) {
        final name = '${item['vestments'] ?? ''}'.trim();
        if (name.isEmpty) continue;

        final qty = _num(item['count']).round();
        final price = _num(item['price']);
        final lineTotal = _num(item['total_price']);
        final total = lineTotal > 0 ? lineTotal : price * qty;

        // التكلفة تُقرأ **الآن** وتُجمَّد: هذا هو جوهر اللقطة.
        final clothing = costs[name];
        final unitCost = clothing?.cost ?? 0.0;
        final nameEn =
            '${item['vestments_en'] ?? clothing?.nameEn ?? ''}'.trim();

        await _db.safeInsert('invoice_items', {
          'invoice_id': invoiceId,
          'clothing_id': clothing?.id,
          'item_name': name,
          'item_name_en': nameEn.isEmpty ? null : nameEn,
          'content': '${item['content'] ?? ''}',
          'content_en': _nullableText(item['content_en']),
          'qty': qty,
          'unit_price': price,
          'unit_cost': unitCost,
          'total_price': total,
          'total_cost': double.parse((unitCost * qty).toStringAsFixed(2)),
          'note': '${item['note'] ?? ''}',
          'note_en': _nullableText(item['note_en']),
          'created_at': now,
        });
        written++;
      }
      return written;
    } catch (e) {
      // فشل اللقطة **لا يُسقط الفاتورة**: البيع تمّ والمال محصَّل. يُسجَّل
      // ويُترك؛ والتقارير ترجع للربط بالاسم عبر الرجوع الاحتياطي.
      debugPrint('InvoiceItemsService.writeSnapshot error: $e');
      return 0;
    }
  }

  /// تكلفة البنود لفواتير مطابقة لشرط.
  ///
  /// [where] يستخدم الاسم المستعار `i` لجدول `invoices` (مثل
  /// `DATE(i.invoice_date) = ? AND i.subscription_id IS NULL`).
  ///
  /// **الرجوع الاحتياطي مقصود وضروري:** الفواتير التي لم تُلتقط لها بنود بعد
  /// (قاعدة لم يُنفَّذ عليها الترحيل، أو لقطة فشلت) تُحسب بالطريقة القديمة —
  /// وإلا ظهرت تكلفتها صفرًا فانتفخ الربح، وهو نفس العيب الذي نُصلحه.
  /// الشرط `NOT EXISTS` يمنع الاحتساب المزدوج.
  Future<double> costFor({
    required String where,
    required List<Object?> args,
  }) async {
    try {
      final snapshot = await _db.readData(
        'SELECT COALESCE(SUM(ii.total_cost), 0) AS cost FROM invoice_items ii JOIN invoices i ON i.invoices_id = ii.invoice_id WHERE $where',
        args,
      );
      final legacy = await _db.readData(
        "SELECT COALESCE(SUM(CAST(json_extract(j.value, '\$.count') AS INTEGER) "
        '  * COALESCE(c.cost_price, 0)), 0) AS cost FROM invoices i, json_each(i.list_data) j, clothing c WHERE $where '
        "  AND json_extract(j.value, '\$.vestments') = c.clothing_name "
        '  AND NOT EXISTS (    SELECT 1 FROM invoice_items ii WHERE ii.invoice_id = i.invoices_id  )',
        args,
      );
      final a = (snapshot.firstOrNull?['cost'] as num?)?.toDouble() ?? 0.0;
      final b = (legacy.firstOrNull?['cost'] as num?)?.toDouble() ?? 0.0;
      return a + b;
    } catch (e) {
      debugPrint('InvoiceItemsService.costFor error: $e');
      return 0;
    }
  }

  /// هل لهذه الفاتورة لقطة بنود؟ (للفحص والعرض)
  Future<bool> hasSnapshot(int invoiceId) async {
    try {
      final rows = await _db.readData(
        'SELECT COUNT(*) AS n FROM invoice_items WHERE invoice_id = ?',
        [invoiceId],
      );
      return ((rows.firstOrNull?['n'] as num?)?.toInt() ?? 0) > 0;
    } catch (_) {
      return false;
    }
  }

  /// بنود فاتورة من اللقطة — للعرض في التقارير التفصيلية.
  Future<List<Map<String, dynamic>>> itemsOf(int invoiceId) async {
    try {
      return await _db.readData(
        'SELECT * FROM invoice_items WHERE invoice_id = ? ORDER BY item_id ASC',
        [invoiceId],
      );
    } catch (e) {
      debugPrint('InvoiceItemsService.itemsOf error: $e');
      return const [];
    }
  }

  /// خريطة الأصناف بالاسم: المعرّف والتكلفة الحالية.
  Future<Map<String, _ClothingRef>> _clothingMap() async {
    final rows = await _db.readData(
      'SELECT clothing_id, clothing_name, clothing_name_en, COALESCE(cost_price, 0) AS cost FROM clothing',
    );
    final map = <String, _ClothingRef>{};
    for (final r in rows) {
      final name = '${r['clothing_name'] ?? ''}'.trim();
      if (name.isEmpty) continue;
      map[name] = _ClothingRef(
        id: (r['clothing_id'] as num?)?.toInt(),
        cost: _num(r['cost']),
        nameEn: '${r['clothing_name_en'] ?? ''}'.trim(),
      );
    }
    return map;
  }

  static String? _nullableText(dynamic value) {
    final text = '${value ?? ''}'.trim();
    return text.isEmpty ? null : text;
  }

  static double _num(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse('${value ?? ''}') ?? 0.0;
  }
}

/// مرجع صنف في المخزون: معرّفه وتكلفته الحالية.
class _ClothingRef {
  final int? id;
  final double cost;
  final String nameEn;
  const _ClothingRef({required this.id, required this.cost, this.nameEn = ''});
}
