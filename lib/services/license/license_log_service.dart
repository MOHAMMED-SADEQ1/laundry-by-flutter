import 'package:flutter/foundation.dart';
import 'package:laundry/services/license/license_event.dart';
import 'package:laundry/sqldb.dart';

/// قراءة سجل أحداث الترخيص من `audit_log`.
///
/// **لماذا ملف مستقل ولا يُستخدم `AuditService`؟** لأن `AuditService.list`
/// يفلتر بـ`DATE(timestamp, 'localtime')` — وهو النمط **الممنوع** في هذا
/// المشروع (كل الطوابع محلية أصلًا، فإضافة `localtime` تحويل مزدوج يُزيح
/// اليوم بإزاحة الجهاز). وسجل الترخيص صغير (أحداث معدودة في السنة) فلا يحتاج
/// فلترة زمنية أصلًا، فنبني استعلامًا مخصّصًا نظيفًا لا يورث ذلك الخلل.
///
/// كذلك نُرتّب بـ`log_id DESC` (ترتيب مسجّل أحادي) لا بالطابع الزمني، فلا
/// تتأثر الصحة بأي ساعة جهاز.
class LicenseLogService {
  LicenseLogService._();
  static final LicenseLogService instance = LicenseLogService._();

  final SqlDB _db = SqlDB();

  /// أحداث الترخيص التي يكتبها التطبيق في `audit_log`.
  static const List<String> actions = <String>['license_seed', 'license_update'];

  Future<List<LicenseEvent>> list({int limit = 200}) async {
    final placeholders = List.filled(actions.length, '?').join(', ');
    try {
      final rows = await _db.readData(
        'SELECT a.*, u.username AS user_name '
        'FROM audit_log a '
        'LEFT JOIN users u ON u.user_id = a.user_id '
        'WHERE a.action IN ($placeholders) '
        'ORDER BY a.log_id DESC LIMIT ?',
        [...actions, limit],
      );
      return rows.map(LicenseEvent.fromMap).toList();
    } catch (e) {
      // قاعدة قديمة بلا جدول users ⇒ نرجع بلا أسماء بدل فقدان السجل كله.
      debugPrint('LicenseLogService.list error: $e');
      return _listWithoutJoin(limit: limit);
    }
  }

  Future<List<LicenseEvent>> _listWithoutJoin({int limit = 200}) async {
    final placeholders = List.filled(actions.length, '?').join(', ');
    try {
      final rows = await _db.readData(
        'SELECT * FROM audit_log '
        'WHERE action IN ($placeholders) '
        'ORDER BY log_id DESC LIMIT ?',
        [...actions, limit],
      );
      return rows.map(LicenseEvent.fromMap).toList();
    } catch (e) {
      debugPrint('LicenseLogService fallback error: $e');
      return <LicenseEvent>[];
    }
  }
}
