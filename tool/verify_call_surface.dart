// حرس بنيوي: كل نداء `controller.X` له تعريف، وكل نداء `PermissionService.X`
// موجود فعلًا.
//
// **لماذا هذا الحرس موجود؟** لأن `flutter analyze` **لا يعمل في بيئة
// التنفيذ** هذه: أداة فلاتر تحتاج تشغيل `git.exe`/`cmd.exe`/`where.exe`
// فيفشل بـ«All pipe instances are busy» (استنفاد خطوط الأنابيب على الجهاز
// نفسه، لا منع من الصندوق). بدون مُحلِّل، تمرّ أخطاء ترجمة حقيقية **بلا
// أي إشارة**:
//   - `controller.grantedOf(...)` بينما الدالة على متحكّم آخر.
//   - `PermissionService.canXyz` لم تُعرَّف قط.
//   - `PermissionKeys.foo` مفتاح وهمي.
//
// هذا الحرس ليس بديلًا عن `flutter analyze` — لكنه يمثل **أكثر أخطائه
// المتوقعة في هذا التغيير تحديدًا**، وهو يعمل بلا أي عملية فرعية.
//
// التشغيل: dart run tool/verify_call_surface.dart

import 'dart:io';

int _pass = 0;
int _fail = 0;
final List<String> _errs = <String>[];

void check(String name, bool ok, [String? detail]) {
  if (ok) {
    _pass++;
  } else {
    _fail++;
    _errs.add('✗ $name${detail == null ? '' : ' — $detail'}');
  }
}

/// يُزيل أسطر التعليق كي لا تُحسب أمثلة التوثيق أسماءً حقيقية.
String stripComments(String src) => src
    .split('\n')
    .where((l) {
      final t = l.trimLeft();
      return !t.startsWith('//') && !t.startsWith('*') && !t.startsWith('/*');
    })
    .join('\n');

/// كل ملفات Dart في lib/.
List<File> libFiles() => Directory('lib')
    .listSync(recursive: true)
    .whereType<File>()
    .where((f) => f.path.endsWith('.dart'))
    .toList();

/// أسماء الدوال/الخصائص المعرَّفة في ملف.
///
/// يعترف بأربع صور شائعة في هذا المشروع:
/// 1. تعريف دالة/مُشيّد: `Type name(` أو `name(`.
/// 2. وصول: `Type get name`.
/// 3. حقول: `Type name;` · `Type name =` · بما فيها الأنواع المُعمَّمة
///    (`TextEditingController neme = ...`) والـ`final`/`late`.
/// 4. مُعامَلات مُسمّاة في المُشيّد: `required this.name`.
Set<String> definedMembers(String src) {
  final out = <String>{};

  // [1] تعريف دالة أو مُشيّد.
  for (final m in RegExp(r'(?:^|\s)(\w+)\s*\(', multiLine: true)
      .allMatches(src)) {
    out.add(m.group(1)!);
  }

  // [2] وصول.
  for (final m in RegExp(r'\bget\s+(\w+)').allMatches(src)) {
    out.add(m.group(1)!);
  }

  // [3] حقول بأنواع قد تحمل مُعامَلات ومُعدِّلات.
  //
  // النمط يقبل **العبارة على أسطر متعدّدة**: `final RxList<Map<String,
  // dynamic>> cashIn =\n  <...>[].obs;` — ولذلك نبحث عن المُعرَّف ثم نتأكد
  // أن ما يليه (`=` أو `;` أو `,`) يظهر قريبًا، لا بالضرورة في نفس السطر.
  for (final m in RegExp(
    r'^\s*(?:static\s+|final\s+|const\s+|late\s+)*'
    r'[\w.]+(?:<[^;=]*?>)?\??\s+(\w+)\s*(?==|;|,|=)',
    multiLine: true,
    dotAll: true,
  ).allMatches(src)) {
    out.add(m.group(1)!);
  }

  // [4] مُعامَلات `this.x`.
  for (final m in RegExp(r'this\.(\w+)').allMatches(src)) {
    out.add(m.group(1)!);
  }

  return out;
}

/// أسماء قاعدة معروفة عالميًا (مكتبات Dart/GetX/Flutter) لا نتوقع إيجادها
/// في 정의ات المتحكّمات — وإلا عُدّت «غير محلولة» بلا سبب.
const Set<String> knownExternal = <String>{
  'value', 'obs', 'toString', 'runtimeType', 'hashCode', 'noSuchMethod',
  'refresh', 'update', 'of', 'maybeOf', 'to', 'withValues', 'clamp',
  'map', 'where', 'firstWhere', 'any', 'every', 'contains', 'add',
  'remove', 'removeWhere', 'join', 'toList', 'toSet', 'split', 'trim',
  'indexOf', 'substring', 'replaceAll', 'isNotEmpty', 'isEmpty',
  'length', 'keys', 'entries', 'assignAll', 'clear', 'put', 'get',
  'snackbar', 'back', 'toNamed', 'dialog', 'bottomSheet', 'defaultDialog',
  'isDialogOpen', 'context', 'text', 'index', 'name', 'path', 'now',
  'push', 'pop', 'show', 'hide', 'close', 'open', 'read', 'write',
  'existsSync', 'readAsStringSync', 'listSync', 'allMatches', 'group',
  'start', 'end', 'first', 'last', 'single', 'elementAt', 'sublist',
  'abs', 'ceil', 'floor', 'round', 'max', 'min', 'pow', 'sqrt',
  'fold', 'sort', 'reversed', 'take', 'skip', 'expand', 'cast', 'field',
  'dart', 'rx', 'obsValue', 'call', 'then', 'catchError', 'whenComplete',
};

void main() {
  print('═══ حرس بنيوي: سطح النداءات ═══\n');

  // ── [1] كل نداء `controller.X` له تعريف في **متحكّم مرتبط بالملف** ──
  //
  // الفحص الأول كان يكتفي بوجود الاسم **في أي ملف** — وهو ضعيف: لو نُقلت
  // دالة من متحكّم إلى آخر لبقي الاسم موجودًا فمرّ الخطأ. (أثبتناه بالتجربة:
  // إعادة تسمية `grantedOf` في `UsersController` لم تُسقط الفحص لأن
  // `RolesController` يعرّفها أيضًا.)
  //
  // الآن نربط: نستخرج من كل **شاشة/ودجة** المتحكّمات التي تستوردها، ثم
  // نتحقق أن العضو معرَّف في **أحد متحكّماتها** لا في أي مكان.
  print('[1] نداءات controller.X');
  final allDefined = <String>{};
  for (final f in libFiles()) {
    allDefined.addAll(definedMembers(stripComments(f.readAsStringSync())));
  }

  /// مسار ملف المتحكّم من سطر استيراده (يُرجَع `null` إن كان نوعًا آخر).
  /// يلتقط `import '.../controller/..._controller.dart'` وأيضًا أي ملف
  /// يُسمّى `*_controller.dart` (نعتمد الاسم لا المجلد — بعض المتحكّمات في
  /// `services/`).
  List<String> importedControllers(String src) {
    final out = <String>[];
    for (final m in RegExp(r"import 'package:laundry/([^']+)'")
        .allMatches(src)) {
      final rel = m.group(1)!;
      if (rel.endsWith('_controller.dart')) {
        out.add('lib/$rel');
      }
    }
    return out;
  }

  final unresolved = <String>{};
  final resolvedCount = <String, int>{};
  for (final f in libFiles()) {
    final p = f.path.replaceAll(r'\', '/');
    final raw = f.readAsStringSync();
    final src = stripComments(raw);

    final calls = RegExp(r'\bcontroller\.(\w+)')
        .allMatches(src)
        .map((m) => m.group(1)!)
        .where((n) => n != 'dart')
        .toSet();
    if (calls.isEmpty) continue;

    // أعضاء المتحكّمات التي يستوردها هذا الملف.
    final ctrlPaths = importedControllers(raw);
    final ctrlMembers = <String>{};
    for (final cp in ctrlPaths) {
      final cf = File(cp);
      if (cf.existsSync()) {
        ctrlMembers.addAll(definedMembers(stripComments(cf.readAsStringSync())));
      }
    }

    // لو لم يستورد أي متحكّم، لا نحكم (قد يكون المتحكّم من حزمة خارجية).
    if (ctrlPaths.isEmpty) continue;

    for (final name in calls) {
      if (ctrlMembers.contains(name) || knownExternal.contains(name)) {
        resolvedCount[p] = (resolvedCount[p] ?? 0) + 1;
        continue;
      }
      unresolved.add('$p → $name');
    }
  }
  check('كل نداء controller.X معرَّف في متحكّم مُستورَد', unresolved.isEmpty,
      unresolved.take(8).join(' · '));
  check('الفحص ربط نداءات فعلية', resolvedCount.isNotEmpty,
      '${resolvedCount.length} ملفًا');

  // ── [2] كل نداء `PermissionService.X` موجود ─────────────────────
  print('\n[2] نداءات PermissionService.X');
  final svc = stripComments(
      File('lib/services/permission/permission_service.dart')
          .readAsStringSync());
  final svcMembers = definedMembers(svc);
  final badSvc = <String>{};
  for (final f in libFiles()) {
    final p = f.path.replaceAll(r'\', '/');
    if (p.endsWith('permission_service.dart')) continue;
    final src = stripComments(f.readAsStringSync());
    for (final m in RegExp(r'\bPermissionService\.(\w+)').allMatches(src)) {
      final name = m.group(1)!;
      if (!svcMembers.contains(name)) badSvc.add('$p → $name');
    }
  }
  check('كل نداء PermissionService.X معرَّف', badSvc.isEmpty,
      badSvc.take(6).join(' · '));

  // ── [3] كل `PermissionKeys.X` معرَّف ────────────────────────────
  print('\n[3] ثوابت PermissionKeys');
  final cat = stripComments(
      File('lib/services/permission/permission_catalog.dart')
          .readAsStringSync());
  final keys = RegExp(r'static const String (\w+) = ')
      .allMatches(cat)
      .map((m) => m.group(1)!)
      .toSet();
  final badKeys = <String>{};
  for (final f in libFiles()) {
    final src = stripComments(f.readAsStringSync());
    for (final m in RegExp(r'PermissionKeys\.(\w+)').allMatches(src)) {
      final n = m.group(1)!;
      if (n == '_') continue; // المُنشئ الخاص
      if (!keys.contains(n)) badKeys.add('${f.path} → $n');
    }
  }
  check('كل مفتاح مستعمل معرَّف', badKeys.isEmpty, badKeys.take(6).join(' · '));

  // ── [4] التوازن البنيوي: أقواس متوازنة في الملفات الجديدة ────────
  //
  // مؤشر خشن لكنه يكشف قطعًا في التعديل (نسخ جزئي ترك قوسًا معلَّقًا).
  print('\n[4] توازن الأقواس في ملفات الصلاحيات');
  final newish = <String>[
    'lib/services/permission/permission_catalog.dart',
    'lib/services/permission/permission_service.dart',
    'lib/services/permission/permission_guard.dart',
    'lib/services/permission/permission_db_handle.dart',
    'lib/controller/users/roles_controller.dart',
    'lib/view/screen/users/roles_screen.dart',
    'lib/view/screen/users/user_permissions_sheet.dart',
  ];
  for (final p in newish) {
    final src = stripComments(File(p).readAsStringSync());
    // نحسب الأقواس مع تجاهل ما داخل النصوص لتفادي الأقواس في الرسائل.
    final noStrings = src.replaceAll(RegExp(r"'[^'\n]*'"), "''")
        .replaceAll(RegExp(r'"[^"\n]*"'), '""');
    final open = '{'.allMatches(noStrings).length;
    final close = '}'.allMatches(noStrings).length;
    check('${p.split('/').last}: أقواس متوازنة ($open/$close)', open == close);
  }

  print('\n═══ النتيجة: نجح $_pass · فشل $_fail ═══');
  for (final e in _errs) {
    print(e);
  }
  if (_fail > 0) exit(1);
  print('✅ كل الفحوص نجحت');
}
