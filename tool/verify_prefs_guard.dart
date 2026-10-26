// حرس ملفّ التفضيلات — يمنع عودة «تطبيق لا يفتح أبدًا».
//
// الحادثة: بعد إطفاء مفاجئ صار `shared_preferences.json` كلّه أصفارًا، والحزمة
// تقرأه بـ`json.decode` بلا `try/catch` ⇒ `FormatException` عند كل إقلاع،
// ولا وسيلة إصلاح من داخل التطبيق.
//
// الفحوص هنا **تُشغّل المنطق الحقيقي** على محتوى الأصفار نفسه، لا على وصفه.
//
// التشغيل: dart run tool/verify_prefs_guard.dart
import 'dart:convert';
import 'dart:io';

import 'package:laundry/services/storage/prefs_health.dart';

int _ok = 0;
int _fail = 0;

void check(String name, Object? got, Object? expected) {
  final pass = got == expected;
  if (pass) {
    _ok++;
    print('  ✓ $name');
  } else {
    _fail++;
    print('  ✗ $name  → got=$got expected=$expected');
  }
}

void main() {
  print('═' * 62);
  print('حرس ملفّ التفضيلات');
  print('═' * 62);

  // ─── [1] تمييز الصالح من التالف ─────────────────────────────────────
  print('\n[1] isUsable');
  check('[1] الفراغ صالح (لا مفاتيح)', PrefsHealthCheck.isUsable(''), true);
  check('[1] `{}` صالح', PrefsHealthCheck.isUsable('{}'), true);
  check('[1] خريطة بمفاتيح صالحة', PrefsHealthCheck.isUsable('{"a":1}'), true);
  check('[1] نصّ عربي صالح', PrefsHealthCheck.isUsable('{"k":"مغاسل"}'), true);

  // 🚨 الحادثة نفسها: 8836 بايت أصفار.
  check(
    '[1] ملفّ الأصفار (الحادثة) مرفوض',
    PrefsHealthCheck.isUsable('\u0000' * 8836),
    false,
  );
  check('[1] صفر واحد مرفوض', PrefsHealthCheck.isUsable('\u0000'), false);
  check('[1] JSON مقطوع مرفوض', PrefsHealthCheck.isUsable('{"a":'), false);
  check('[1] `null` مرفوض (ليست خريطة)', PrefsHealthCheck.isUsable('null'), false);
  check('[1] مصفوفة مرفوضة', PrefsHealthCheck.isUsable('[]'), false);
  check('[1] رقم مجرّد مرفوض', PrefsHealthCheck.isUsable('42'), false);
  check('[1] مسافات فقط مرفوضة', PrefsHealthCheck.isUsable('   '), false);
  check('[1] نصّ عادي مرفوض', PrefsHealthCheck.isUsable('hello'), false);

  // نفس المسار الذي تسلكه الحزمة: بايتات ← نصّ ← JSON.
  final tmp = Directory.systemTemp.createTempSync('prefs_guard_');
  final zeroed = File('${tmp.path}/zeroed.json')..writeAsBytesSync(List.filled(64, 0));
  final zeroedRaw = utf8.decode(zeroed.readAsBytesSync(), allowMalformed: true);
  check(
    '[1] ملفّ أصفار حقيقي على القرص مرفوض',
    PrefsHealthCheck.isUsable(zeroedRaw),
    false,
  );
  final good = File('${tmp.path}/good.json')..writeAsStringSync('{"a":1}');
  check(
    '[1] ملفّ صالح حقيقي على القرص مقبول',
    PrefsHealthCheck.isUsable(good.readAsStringSync()),
    true,
  );
  tmp.deleteSync(recursive: true);

  // ─── [2] الإصلاح لا يُتلف بيانات المستخدم ──────────────────────────
  print('\n[2] سلوك الإصلاح');
  final src = File('lib/services/storage/prefs_guard.dart').readAsStringSync();
  check('[2] ينسخ التالف قبل الكتابة', src.contains('copySync'), true);
  check('[2] يكتب `{}` صالحًا', src.contains("writeAsStringSync('{}')"), true);
  check(
    '[2] لا يحذف ملفّ المستخدم',
    RegExp(r'deleteSync|\.delete\(').hasMatch(src),
    false,
  );
  check('[2] لا يرمي (يلتقط كل استثناء)', src.contains('catch (e)'), true);
  check(
    '[2] لا يعمل على أندرويد (لا ملفّ JSON هناك)',
    src.contains('AppPlatform.isDesktop'),
    true,
  );
  check(
    '[2] اسم الملفّ مطابق لما تقرأه الحزمة',
    PrefsHealthCheck.fileName,
    'shared_preferences.json',
  );

  // ─── [3] الربط في الإقلاع ───────────────────────────────────────────
  print('\n[3] الإقلاع');
  final main = File('lib/main.dart').readAsStringSync();
  // الفحص السابق وحده ضعيف: `indexOf` يعيد -1 عند الغياب، و-1 أصغر من أي
  // موضع ⇒ فحوص الترتيب تنجح **زائفةً** بلا استدعاء. نشترط وجوده أولًا.
  final repairAt = main.indexOf('PrefsGuard.repairIfCorrupt()');
  final counterAt = main.indexOf('InvoiceCounterService.loadInitialCounter()');
  final sessionAt = main.indexOf('SessionManager.restoreSession()');
  check('[3] main يستدعي الفحص', repairAt >= 0, true);
  check(
    '[3] الفحص **قبل** أول قارئ للتفضيلات (عدّاد الفواتير)',
    repairAt >= 0 && counterAt >= 0 && repairAt < counterAt,
    true,
  );
  check(
    '[3] الفحص **قبل** استعادة الجلسة',
    repairAt >= 0 && sessionAt >= 0 && repairAt < sessionAt,
    true,
  );
  check(
    '[3] يُنبّه المستخدم مرة واحدة عند الإصلاح',
    main.contains('PrefsHealth.repaired'),
    true,
  );

  // ─── [4] عدّاد الفواتير لا يسقط بلا تفضيلات ────────────────────────
  print('\n[4] عدّاد الفواتير');
  final counter = File(
    'lib/core/services/invoicecounterservice.dart',
  ).readAsStringSync();
  check(
    '[4] لا فتح قسري للتفضيلات (`_prefsInstance!`)',
    counter.contains('_prefsInstance!'),
    false,
  );
  check(
    '[4] فتح التفضيلات داخل try',
    RegExp(r'try \{\s*_prefsInstance = await').hasMatch(counter),
    true,
  );
  check(
    '[4] القراءة والكتابة اختياريتان (`?.`)',
    counter.contains('_prefsInstance?.getInt') &&
        counter.contains('_prefsInstance?.setInt'),
    true,
  );

  // ─── النتيجة ────────────────────────────────────────────────────────
  print('\n' + '─' * 62);
  print('نجح: $_ok · فشل: $_fail');
  if (_fail > 0) exit(1);
}
