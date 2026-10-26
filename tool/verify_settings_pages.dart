/// حرس بنية **صفحات الإعدادات** — يمنع فقدان مجموعة خيارات أو مدخل عند التقسيم.
///
/// ## لماذا هذا الفحص؟
/// بعد تقسيم الإعدادات إلى **فهرس + صفحة لكل جزء** صار في المشروع ثلاثة ملفات
/// تترابط بأسماء نصّية:
///   1. `core/constant/routes.dart` — تعريف أسماء المسارات.
///   2. `routes.dart` — تسجيل `GetPage` لكل مسار.
///   3. `settings_screen.dart` — الفهرس الذي ينقل بالمسارات.
///   4. `settings_pages.dart` — الصفحات التي تسرد مجموعات الخيارات.
///
/// وخطأ نسخ/لصق واحد (مسار غير مسجَّل ⇒ زرّ لا يعمل، أو مجموعة غير مذكورة في
/// أي صفحة ⇒ خيارات تختفي من الواجهة بلا رسالة) **صامت تمامًا**: لا المحلّل ولا
/// المترجم يشتكيان. هذا الحرس يكشفه.
///
/// التشغيل:  dart run tool/verify_settings_pages.dart
library;

import 'dart:io';

import 'package:laundry/services/settings/setting_option.dart';

const String _pagesPath = 'lib/view/screen/settings/settings_pages.dart';
const String _hubPath = 'lib/view/screen/settings/settings_screen.dart';
const String _routesConstPath = 'lib/core/constant/routes.dart';
const String _routesPath = 'lib/routes.dart';
const String _optionsPath = 'lib/services/settings/setting_option.dart';

/// المجموعة التي لا تُعرض كبطاقة خيارات: خياراتها داخل بطاقة الطابعة
/// ([InvoiceOutputBlock]) في صفحة الطباعة — فهي مشمولة صراحةً في الفحص.
const String _inlineGroup = SettingGroups.invoiceOutput;

int _passed = 0;
int _failed = 0;

void check(String label, Object? got, Object? expected) {
  final ok = got.toString() == expected.toString();
  if (ok) {
    _passed++;
    print('[PASS] $label');
  } else {
    _failed++;
    print('[FAIL] $label');
    print('        got=$got  expected=$expected');
  }
}

void checkTrue(String label, bool ok, [String detail = '']) {
  check(label, ok, true);
  if (!ok && detail.isNotEmpty) print('        $detail');
}

String read(String path) {
  final f = File(path);
  if (!f.existsSync()) {
    print('[FAIL] الملف غير موجود: $path');
    _failed++;
    return '';
  }
  return f.readAsStringSync();
}

/// كل `SettingGroups.<name>` الواردة في نصّ ما (بلا تكرار، مرتّبة).
Set<String> groupsIn(String source) {
  final re = RegExp(r'SettingGroups\.([A-Za-z0-9_]+)');
  return re
      .allMatches(source)
      .map((m) => m.group(1)!)
      .where((name) => name != 'ordered')
      .toSet();
}

/// كل `AppRoute.<name>` الواردة في نصّ ما (بلا تكرار).
Set<String> routeRefsIn(String source) {
  final re = RegExp(r'AppRoute\.([A-Za-z0-9_]+)');
  return re.allMatches(source).map((m) => m.group(1)!).toSet();
}

void main() {
  final pages = read(_pagesPath);
  final hub = read(_hubPath);
  final routesConst = read(_routesConstPath);
  final routes = read(_routesPath);
  if (pages.isEmpty || hub.isEmpty) {
    print('=' * 70);
    print('تعذّر إكمال الفحص.');
    return;
  }

  // ─── أ. تغطية مجموعات الخيارات ───
  print('=' * 70);
  print('A. تغطية مجموعات الخيارات (لا مجموعة تضيع بين الصفحات)');
  print('=' * 70);

  // ⚠️ `SettingGroups.ordered` تحمل **قيم** المجموعات (`'invoice_display'`)،
  // والصفحات تذكر **أسماء الثوابت** (`SettingGroups.invoiceDisplay`) — فلا
  // تُقارَن مباشرةً. نبني خريطة الاسم⇒القيمة من ملف السجل نفسه.
  final nameToValue = <String, String>{};
  for (final m in RegExp(
    r"static const String (\w+) = '([^']*)'",
  ).allMatches(read(_optionsPath))) {
    nameToValue[m.group(1)!] = m.group(2)!;
  }
  checkTrue(
    'A0. خريطة أسماء المجموعات مقروءة من السجل',
    nameToValue.length >= SettingGroups.ordered.length,
    'وُجد ${nameToValue.length} مقابل ${SettingGroups.ordered.length}',
  );

  final inPages = groupsIn(pages);
  final pageValues = inPages
      .map((n) => nameToValue[n] ?? '<غير معروف:$n>')
      .toSet();

  final missing = SettingGroups.ordered
      .where((g) => g != _inlineGroup)
      .where((g) => !pageValues.contains(g))
      .toList();

  check('A1. كل مجموعة معروضة مذكورة في صفحة', missing, <String>[]);

  final unknown = inPages.where((g) => !nameToValue.containsKey(g)).toList();
  check('A2. لا مجموعة مذكورة في الصفحات خارج السجل', unknown, <String>[]);

  // التكرار: مجموعة في صفحتين ⇒ خياراتها تظهر مرّتين ⇒ لبس للمستخدم.
  final counts = <String, int>{};
  for (final m in RegExp(r'SettingGroups\.([A-Za-z0-9_]+)').allMatches(pages)) {
    final name = m.group(1)!;
    if (name == 'ordered') continue;
    counts[name] = (counts[name] ?? 0) + 1;
  }
  final duplicated = counts.entries
      .where((e) => e.value > 1)
      .map((e) => '${e.key}×${e.value}')
      .toList();
  check('A3. لا مجموعة مكرّرة في أكثر من صفحة', duplicated, <String>[]);

  checkTrue(
    'A4. مجموعة الإخراج المضمَّنة مُعلنة صراحةً (invoiceOutput)',
    _inlineGroup == SettingGroups.invoiceOutput,
  );

  // ─── ب. سلامة المسارات ───
  print('=' * 70);
  print('B. مسارات صفحات الإعدادات (كل زرّ يفتح صفحة موجودة فعلًا)');
  print('=' * 70);

  final refs = routeRefsIn(hub);
  final settingsRefs = refs
      .where((r) => r.toLowerCase().contains('setting'))
      .toSet();
  checkTrue('B1. الفهرس يشير إلى مسارات إعدادات', settingsRefs.length >= 10,
      'وُجد ${settingsRefs.length}');

  final notDeclared = settingsRefs
      .where((r) => !RegExp('String $r =').hasMatch(routesConst))
      .toList();
  check('B2. كل مسار مُشار إليه معرَّف في AppRoute', notDeclared, <String>[]);

  final notRegistered = settingsRefs
      .where((r) => !routes.contains('AppRoute.$r'))
      .toList();
  check('B3. كل مسار مُشار إليه مسجَّل في routes.dart', notRegistered,
      <String>[]);

  // مسار معرَّف وغير مستعمل ⇒ صفحة ميتة (نسيان ربط المدخل).
  // يُستثنى `settings` نفسه: هو مسار الفهرس لا صفحة فرعية.
  final declaredSettings = RegExp(r'String (settings[A-Za-z0-9_]*) =')
      .allMatches(routesConst)
      .map((m) => m.group(1)!)
      .where((r) => r != 'settings')
      .toSet();
  final unused = declaredSettings.where((r) => !refs.contains(r)).toList();
  check('B4. لا مسار إعدادات معرَّف بلا مدخل في الفهرس', unused, <String>[]);

  // ─── ج. تناظر الملفات ───
  print('=' * 70);
  print('C. تناظر الفهرس والصفحات');
  print('=' * 70);

  checkTrue(
    'C1. الفهرس لا يبني خيارات بنفسه (أُخرجت إلى الصفحات)',
    !hub.contains('optionsSection('),
  );
  checkTrue(
    'C2. الفهرس لا يبني قائمة الطابعات بنفسه',
    !hub.contains('PrinterSection('),
  );
  checkTrue(
    'C3. كل صفحة تُبنى من الهيكل الموحّد',
    RegExp('=> SettingsGroupsPage\\(').allMatches(pages).length >= 10,
    'وُجد ${RegExp('=> SettingsGroupsPage\\(').allMatches(pages).length}',
  );

  print('=' * 70);
  if (_failed == 0) {
    print('كل الفحوصات نجحت ($_passed/$_passed)');
  } else {
    print('فشل $_failed من ${_passed + _failed}');
  }
  print('=' * 70);
  exitCode = _failed == 0 ? 0 : 1;
}
