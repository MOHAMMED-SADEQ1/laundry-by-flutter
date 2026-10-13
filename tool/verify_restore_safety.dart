// فحوص سلامة الاستعادة — **فحص بنيوي للنص المصدري** لا فحص نتائج.
//
// التشغيل:  dart run tool/verify_restore_safety.dart
//
// **لماذا بنيوي:** العيوب التي أُصلحت هنا ليست قيمًا تُحسب بل **ترتيبًا**:
//  1. إغلاق القاعدة ثم النسخ فوق الملف **بلا بوابة** ⇒ أي طلب يمرّ في اللحظة
//     الفاصلة يعيد فتح الملف وهو نصف مستبدَل ⇒ بيانات مختلطة وتعطّل النظام.
//  2. لو نادى `closeDB` الدالة `dbGet` لانتظر البوابة التي لن تُفتح إلا بعد
//     انتهاء الاستعادة، والاستعادة تنتظر الإغلاق ⇒ **جمود كامل** (deadlock).
//  3. إعادة التحميل اللينة بعد الاستعادة تُبقي حالة عشرات المتحكّمات حيّة فوق
//     قاعدة مُستبدلة ⇒ تتسلسل الأخطاء.
//  4. منتقي ملفات بفلترة `.db` يُخفي نسخة وصلت عبر واتساب باسم `.bin`.
//
// هذه الأربعة لا يمسكها محلّل ولا اختبار وحدات، وكلّها انحدارات تعود بصمت.
// فحص النص نفسه هو الحارس المناسب لها.
// ignore_for_file: avoid_print

import 'dart:io';

int _pass = 0;
int _fail = 0;

void check(String label, bool ok, [String? detail]) {
  if (ok) {
    _pass++;
    print('  ✅ $label');
  } else {
    _fail++;
    print('  ❌ $label${detail == null ? '' : '  →  $detail'}');
  }
}

String read(String path) => File(path).readAsStringSync();

/// يستخرج نص الدالة بدءًا من أول ظهور لـ[signature] حتى القوس الموازن.
///
/// ضروري لأن الفحص يجب أن يكون **داخل الدالة** لا في الملف كله: وجود
/// `beginMaintenance` في الملف لا يعني أنها قبل الإغلاق داخل `restoreBackup`.
String functionBody(String source, String signature) {
  final start = source.indexOf(signature);
  if (start < 0) return '';
  var depth = 0;
  var seen = false;
  for (var i = start; i < source.length; i++) {
    final ch = source[i];
    if (ch == '{') {
      depth++;
      seen = true;
    } else if (ch == '}') {
      depth--;
      if (seen && depth == 0) return source.substring(start, i + 1);
    }
  }
  return source.substring(start);
}

int indexOfStrict(String haystack, String needle) => haystack.indexOf(needle);

void main() {
  final db = read('lib/sqldb.dart');
  final backup = read('lib/services/database/backup_service.dart');
  final screen = read('lib/view/screen/backup/backup_screen.dart');

  // ──────────────────────────────────────────────
  print('══ 1) بوابة الصيانة موجودة في مسار الفتح ══');

  check('SqlDB فيه بوابة صيانة', db.contains('_maintenance'));
  check('بدء/إغلاق البوابة معرَّفان', db.contains('beginMaintenance'));
  final dbGet = functionBody(db, 'Future<Database?> get dbGet async');
  check('dbGet ينتظر البوابة قبل الفتح', dbGet.contains('await gate'));
  check(
    'الانتظار **قبل** إرجاع الاتصال المفتوح لا بعده',
    indexOfStrict(dbGet, 'await gate') <
        indexOfStrict(dbGet, 'if (_db != null) return _db;'),
  );

  // ──────────────────────────────────────────────
  print('\n══ 2) لا جمود: closeDB لا يمرّ بالبوابة ══');

  final closeDb = functionBody(db, 'Future<void> closeDB() async');
  check('closeDB لا ينادي dbGet (وإلا جمود كامل)', !closeDb.contains('dbGet'));
  check('closeDB يقرأ الحقل مباشرة', closeDb.contains('final mydb = _db;'));
  check('closeDB يُصفّر الحقل قبل الإغلاق', closeDb.contains('_db = null;'));

  // ──────────────────────────────────────────────
  print('\n══ 3) ترتيب الاستبدال داخل restoreBackup ══');

  final restore = functionBody(
    backup,
    'Future<RestoreResult> restoreBackup(String backupPath) async',
  );
  check('وُجد نص دالة الاستعادة', restore.isNotEmpty);

  final iGate = indexOfStrict(restore, 'beginMaintenance()');
  final iClose = indexOfStrict(restore, 'await softlyClose();');
  final iCopy = indexOfStrict(restore, 'copy(dbPath)');
  final iEnd = indexOfStrict(restore, 'endMaintenance()');

  check('البوابة تُغلق أولًا', iGate > 0);
  check(
    'البوابة **قبل** إغلاق القاعدة',
    iGate > 0 && iClose > iGate,
    'gate=$iGate · close=$iClose',
  );
  check(
    'البوابة **قبل** النسخ فوق القاعدة',
    iGate > 0 && iCopy > iGate,
    'gate=$iGate · copy=$iCopy',
  );
  check(
    'البوابة تُفتح **بعد** النسخ',
    iEnd > iCopy && iCopy > 0,
    'copy=$iCopy · end=$iEnd',
  );
  check(
    'فتح البوابة داخل finally (لا تُترك مغلقة أبدًا)',
    restore.contains('finally') &&
        indexOfStrict(restore, 'finally') < iEnd,
  );

  // ──────────────────────────────────────────────
  print('\n══ 4) حارس إصدار البنية (لا استعادة لملف أحدث) ══');

  check(
    'يُقرأ user_version من الملف',
    backup.contains("PRAGMA user_version"),
  );
  check(
    'يُرفض الملف الأحدث من التطبيق',
    backup.contains('schemaVersion > AppConstants.dbVersion'),
  );
  final iGuard = indexOfStrict(backup, 'PRAGMA user_version');
  final iCount = indexOfStrict(backup, "final userCount = await _count(probe, 'users');");
  check(
    'الحارس **قبل** اعتبار الملف صالحًا',
    iGuard > 0 && iCount > iGuard,
    'guard=$iGuard · valid=$iCount',
  );

  // ──────────────────────────────────────────────
  print('\n══ 5) لا إعادة تحميل لينة بعد الاستعادة ══');

  check(
    'لا Get.offAllNamed في شاشة النسخ (إعادة تحميل لينة)',
    !screen.contains('Get.offAllNamed'),
  );
  check('يُغلق التطبيق صراحةً', screen.contains('_closeApp'));
  check(
    'إغلاق المنصة عبر SystemNavigator',
    screen.contains('SystemNavigator.pop'),
  );
  check(
    'احتياط بعملية إغلاق صريحة',
    screen.contains('exit(0)'),
  );

  // ──────────────────────────────────────────────
  print('\n══ 6) منتقي الملفات لا يُخفي النسخ ══');

  final pick = functionBody(backup, 'static Future<String?> pickBackupFile()');
  check(
    'بلا فلترة امتداد (تخفي ملفات `.bin` القادمة من واتساب)',
    pick.contains('FileType.any'),
  );
  check(
    'لا فرض امتداد .db على الملف المختار',
    !pick.contains('allowedExtensions'),
  );

  print('\n════════════════════════════════════');
  print('النتيجة: $_pass نجحت · $_fail فشلت');
  if (_fail > 0) throw StateError('هناك فحوص فاشلة');
}
