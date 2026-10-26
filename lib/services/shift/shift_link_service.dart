import 'package:flutter/foundation.dart';
import 'package:laundry/sqldb.dart';

/// ربط الحركات المالية بالوردية (الصندوق).
///
/// **القاعدة المعمارية:** «الوردية هي الصندوق». أي حركة نقدية (مصروف، سداد
/// ذمة، دفعة اشتراك، استرداد) يجب أن تُنسب إلى وردية، وإلا ظهر **عجز وهمي**
/// عند الإقفال: مبلغ خرج من الدرج لكنه غير منسوب للوردية التي كان الدرج
/// مفتوحًا فيها.
///
/// كانت هذه الحركات تُربط **بالوقت تخمينًا** (`datetime(x) >= shift_start`)
/// وبلا حدّ أعلى — فتُحتسب دفعة حدثت *بعد* إقفال الوردية ضمنها. الربط الآن
/// صريح بـ `shift_id`.
class ShiftLinkService {
  ShiftLinkService._();

  static final SqlDB _db = SqlDB();

  /// معرّف الوردية المفتوحة حاليًا (`end_time IS NULL`)، أو `null`.
  ///
  /// تُستدعى **قبل** بدء أي معاملة (`transaction`)، لأن استخدام اتصال
  /// القاعدة داخل معاملة قائمة قد يُوقف التنفيذ (deadlock).
  static Future<int?> activeShiftId() async {
    try {
      final rows = await _db.readData(
        'SELECT shift_id FROM shifts WHERE end_time IS NULL ORDER BY shift_id DESC LIMIT 1',
      );
      if (rows.isEmpty) return null;
      return (rows.first['shift_id'] as num?)?.toInt();
    } catch (e) {
      debugPrint('activeShiftId error: $e');
      return null;
    }
  }

  /// هل هناك وردية مفتوحة الآن؟
  static Future<bool> isShiftOpen() async => (await activeShiftId()) != null;

  /// وقت فتح الوردية (ISO) — يُستخدم لوسم الحركات غير المنسوبة زمنيًا.
  static Future<String?> activeShiftStart() async {
    try {
      final rows = await _db.readData(
        'SELECT start_time FROM shifts WHERE end_time IS NULL ORDER BY shift_id DESC LIMIT 1',
      );
      if (rows.isEmpty) return null;
      return rows.first['start_time']?.toString();
    } catch (e) {
      debugPrint('activeShiftStart error: $e');
      return null;
    }
  }
}
