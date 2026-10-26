import 'package:flutter/foundation.dart';
import 'package:laundry/services/discount/discount_rules.dart';
import 'package:laundry/services/i18n/l10n.dart';
import 'package:laundry/sqldb.dart';

/// الوصول لجدول `discounts` — تحقق واستهلاك وإدارة.
///
/// الجدول كان موجودًا منذ أول إصدار و**صفر كود** يقرأ منه أو يكتب فيه، أي
/// ميزة معلنة في المخطط وغير موجودة في التطبيق. هذا هو تنفيذها.
///
/// القواعد نفسها (الصلاحية · التواريخ · السقف · الحساب) في
/// `discount_rules.dart` **بلا Flutter ولا قاعدة**، فتكون قابلة للاختبار
/// المباشر. هنا الوصول للقاعدة فقط.
class DiscountService {
  DiscountService._();
  static final DiscountService instance = DiscountService._();

  final SqlDB _db = SqlDB();

  /// التحقق من كود على مبلغ — يقرأ الصف ثم يفوّض للقواعد الخالصة.
  Future<DiscountCheck> check(String code, double gross) async {
    final trimmed = code.trim();
    if (trimmed.isEmpty) return DiscountCheck.none;
    try {
      final rows = await _db.readData(
        'SELECT * FROM "discounts" WHERE UPPER(TRIM(code)) = UPPER(?) ORDER BY discount_id DESC LIMIT 1',
        [trimmed],
      );
      return DiscountRules.evaluate(
        record: rows.isEmpty ? null : rows.first,
        gross: gross,
        today: DateTime.now(),
      );
    } catch (e) {
      debugPrint('DiscountService.check error: $e');
      return const DiscountCheck(
        valid: false,
        message: 'تعذّر التحقق من كود الخصم',
      );
    }
  }

  /// زيادة عدّاد الاستخدام بمقدار 1 — يُستدعى **بعد** نجاح إصدار الفاتورة
  /// فقط، لا قبله، وإلا استُهلك الكود على فاتورة لم تصدر.
  Future<void> consume(int discountId) async {
    try {
      await _db.updateData(
        'UPDATE "discounts" SET "current_uses" = COALESCE("current_uses", 0) + 1 WHERE "discount_id" = ?',
        [discountId],
      );
    } catch (e) {
      debugPrint('DiscountService.consume error: $e');
    }
  }

  /// كل الأكواد — للأحدث أولًا.
  Future<List<Map<String, dynamic>>> all({bool activeOnly = false}) async {
    try {
      return await _db.readData(
        'SELECT * FROM "discounts" ${activeOnly ? 'WHERE COALESCE(is_active,0) = 1' : ''} ORDER BY discount_id DESC',
      );
    } catch (e) {
      debugPrint('DiscountService.all error: $e');
      return const [];
    }
  }

  Future<Map<String, dynamic>?> byId(int id) async {
    try {
      final rows = await _db.readData(
        'SELECT * FROM "discounts" WHERE discount_id = ? LIMIT 1',
        [id],
      );
      return rows.isEmpty ? null : rows.first;
    } catch (_) {
      return null;
    }
  }

  /// إنشاء أو تحديث كود. يرجع معرّف الصف.
  ///
  /// يمنع تكرار الكود (مقارنة بلا حالة أحرف) لأن الكود مفتاح استدعاء يدوي
  /// من الكاشير — تكراره يجعل السلوك غير محدَّد.
  Future<int> save({
    int? id,
    required String name,
    String? nameEn,
    required String code,
    required String type,
    required double value,
    required String startDate,
    String? endDate,
    bool isActive = true,
    int? maxUses,
  }) async {
    final cleanCode = code.trim();
    final payload = <String, dynamic>{
      'name': name.trim(),
      'name_en': (nameEn ?? '').trim(),
      'code': cleanCode,
      'type': type,
      'value': value,
      'start_date': startDate,
      'end_date': (endDate == null || endDate.trim().isEmpty)
          ? null
          : endDate.trim(),
      'is_active': isActive ? 1 : 0,
      'max_uses': maxUses,
    };

    try {
      final clash = await _db.readData(
        'SELECT discount_id FROM "discounts" WHERE UPPER(TRIM(code)) = UPPER(?) AND discount_id != ?',
        [cleanCode, id ?? -1],
      );
      if (clash.isNotEmpty) {
        throw StateError(trf('كود «{0}» مستخدم بالفعل', [cleanCode]));
      }

      if (id == null) {
        return await _db.safeInsert('discounts', {
          ...payload,
          'current_uses': 0,
        });
      }
      await _db.safeUpdate(
        'discounts',
        payload,
        where: 'discount_id = ?',
        whereArgs: [id],
      );
      return id;
    } catch (e) {
      debugPrint('DiscountService.save error: $e');
      rethrow;
    }
  }

  /// حذف ناعم — لا حذف نهائي لسجل استُخدم في فواتير.
  Future<void> deactivate(int id) async {
    try {
      await _db.safeUpdate(
        'discounts',
        {'is_active': 0},
        where: 'discount_id = ?',
        whereArgs: [id],
      );
    } catch (e) {
      debugPrint('DiscountService.deactivate error: $e');
    }
  }
}
