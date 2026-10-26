/// حرس بوابة المسارات — يتحقق من أن كل مسار محمي يحمل حرسًا بمفاتيح صحيحة.
///
///     dart run tool/verify_route_guards.dart
///
/// **العيب الذي يمنعه:** مسار جديد يُضاف بلا `middlewares` ⇒ `Get.toNamed`
/// يفتحه لأي مستخدم، ويبدو النظام محميًا في القائمة وهو مفتوح برمجيًا.
/// كانت **38 مسارًا بلا حرس واحد** قبل هذه الميزة، وهذا الحرس يمنع الرجوع.
///
/// يقرأ `lib/routes.dart` نصًّا (لا يستورده لأن الاستيراد يجرّ Flutter)،
/// ويُثبت:
/// 1. كل مسار مُدرَج في `AppRoute` يحمل `GetPage` — لا مسار منسي.
/// 2. كل مسار **حسّاس** يحمل `middlewares: const [PermissionGuard([...])]`.
/// 3. كل مفتاح داخل أي `PermissionGuard` **معروف في الكتالوج**.
/// 4. المسارات العامة المقصودة (splash/login/onboarding/profile/homepage)
///    بلا حرس — فلا يُبالَغ في التقييد.
library;

import 'dart:io';

import 'package:laundry/services/permission/permission_catalog.dart';

int _pass = 0;
int _fail = 0;
final List<String> _errors = <String>[];

void check(String name, bool ok, [String? detail]) {
  if (ok) {
    _pass++;
  } else {
    _fail++;
    _errors.add('✗ $name${detail == null ? '' : ' — $detail'}');
  }
}

String _read(String rel) {
  final f = File(rel);
  return f.existsSync() ? f.readAsStringSync() : '';
}

/// يستخرج قيم `AppRoute.xxx` ثوابت المسارات.
Set<String> _routeConstants(String src) {
  final out = <String>{};
  for (final m in RegExp(r'static\s+const\s+String\s+(\w+)\s*=')
      .allMatches(src)) {
    out.add(m.group(1)!);
  }
  return out;
}

void main() {
  final routesSrc = _read('lib/routes.dart');
  final constSrc = _read('lib/core/constant/routes.dart');

  check('[0] routes.dart مقروء', routesSrc.isNotEmpty);
  check('[0] core/constant/routes.dart مقروء', constSrc.isNotEmpty);

  // ── [1] كل ثابت مسار له GetPage ──────────────────────────────────
  final routeConsts = _routeConstants(constSrc);
  check('[1] ثوابت المسارات موجودة', routeConsts.isNotEmpty,
      '${routeConsts.length} ثابتًا');

  final declared = <String>{};
  for (final m in RegExp(r'name:\s*AppRoute\.(\w+)').allMatches(routesSrc)) {
    declared.add(m.group(1)!);
  }

  // ثوابت مسار **ميّتة معروفة**: مُعرَّفة في `AppRoute` ولا `GetPage` لها
  // ولا مستهلك في المشروع. موجودة من قبل هذه الميزة، وأُبقيت هنا موثَّقة
  // (لا محذوفة) حتى لا يبدو الحرس صارمًا بمقدار ما هو صادق. إن أُحييت
  // لاحقًا فلازمها `GetPage` + حرس، وهذا الحرس سيكشف إغفاله.
  const knownDeadRoutes = <String>{'editcategory', 'viewpdf'};

  final missing = routeConsts
      .difference(declared)
      .difference(knownDeadRoutes)
      .toList()
    ..sort();
  check('[1] كل ثابت مسار له GetPage (غير الميّتة الموثَّقة)', missing.isEmpty,
      missing.join(', '));

  // التوثيق نفسه يُتحقق: الثوابت الميتة ليست مُعلَنة فعلًا (فلا تكذب).
  final wronglyAlive =
      knownDeadRoutes.where(declared.contains).toList();
  check('[1] الثوابت الميتة الموثَّقة لا تزال غير مُعلَنة', wronglyAlive.isEmpty,
      wronglyAlive.join(', '));

  // ── [2] المسارات الحسّاسة تحمل حرسًا ────────────────────────────
  //
  // **المسارات الحسّاسة** = كل ما يفتح شاشة لها صلاحية معرَّفة في الكتالوج.
  const mustBeGuarded = <String>[
    'addcategory',
    'invoices',
    'dashboard',
    'reports',
    'settings',
    'processing',
    'subscriptions',
    'subscriptionDashboard',
    'users',
    'roles',
    'dailyCash',
    'expenses',
    'auditLog',
    'customerAccount',
    'debtAging',
    'debtReconciliation',
    'licenseLog',
    'backup',
    'discounts',
    'settingsBusiness',
    'settingsAppearance',
    'settingsInvoice',
    'settingsPrinting',
    'settingsAccounts',
    'settingsOperations',
    'settingsTax',
    'settingsRetention',
    'settingsLicense',
    'settingsBackup',
    'settingsAbout',
  ];

  final unguarded = <String>[];
  for (final name in mustBeGuarded) {
    // ابحث عن كتلة `name: AppRoute.<name>` وحدّد إن كان فيها middlewares.
    final pattern = RegExp(
      'name:\\s*AppRoute\\.$name\\s*,.*?(?=name:\\s*AppRoute\\.|\\];)',
      dotAll: true,
    );
    final m = pattern.firstMatch(routesSrc);
    if (m == null) {
      unguarded.add('$name (لم يُوجد)');
      continue;
    }
    if (!m.group(0)!.contains('middlewares')) unguarded.add(name);
  }
  check('[2] كل المسارات الحسّاسة محروسة', unguarded.isEmpty,
      unguarded.join(', '));

  // ── [3] المسارات العامة بلا حرس (لا مبالغة) ─────────────────────
  const mustBeOpen = <String>[
    'splash',
    'login',
    'onboarding',
    'profile',
    'homepage',
  ];
  final overGuarded = <String>[];
  for (final name in mustBeOpen) {
    final pattern = RegExp(
      'name:\\s*AppRoute\\.$name\\s*,.*?(?=name:\\s*AppRoute\\.|\\];)',
      dotAll: true,
    );
    final m = pattern.firstMatch(routesSrc);
    if (m != null && m.group(0)!.contains('middlewares')) {
      overGuarded.add(name);
    }
  }
  check('[3] المسارات العامة بلا حرس', overGuarded.isEmpty,
      overGuarded.join(', '));

  // ── [4] كل مفتاح في كل حرس معروف في الكتالوج ────────────────────
  final guardBlocks =
      RegExp(r'PermissionGuard\(\[(.*?)\]\)', dotAll: true).allMatches(routesSrc);
  final badKeys = <String>[];
  var keyCount = 0;
  for (final g in guardBlocks) {
    for (final k in RegExp(r'PermissionKeys\.(\w+)').allMatches(g.group(1)!)) {
      keyCount++;
      final name = k.group(1)!;
      // تحقق أن الثابت موجود فعلًا في الكتالوج بمفتاحه.
      final known = PermissionCatalog.keys.any((catalogKey) =>
          _keyConstName(catalogKey) == name);
      if (!known) badKeys.add(name);
    }
  }
  check('[4] عدد المفاتيح في الحراس > 0', keyCount > 0, '$keyCount مفتاحًا');
  check('[4] كل مفتاح في حرس معروف في الكتالوج', badKeys.isEmpty,
      badKeys.join(', '));

  // ── [5] الحرس مُضمَّن في routes.dart ────────────────────────────
  check('[5] PermissionGuard مستورد',
      routesSrc.contains('permission_guard.dart'));
  check('[5] PermissionKeys مستورد',
      routesSrc.contains('permission_catalog.dart'));

  // ── [6] `middlewares` ليست `const` ───────────────────────────────
  //
  // **لماذا هذا الفحص موجود؟** لأن `GetMiddleware` في get-4.7.3 مُنشئه
  // `GetMiddleware({this.priority})` **بلا `const`** (سطر 102 في
  // `route_middleware.dart`). فكتابة `middlewares: const [PermissionGuard(...)]`
  // تجعل القائمة ثابتة، فيُشترط أن يكون كل عنصر تعبيرًا ثابتًا ⇒
  // **خطأ ترجمة**: «A constant constructor can't call a non-constant super
  // constructor». أسقط هذا البناء الفعلي على ويندوز (31 مسارًا معًا)،
  // ولم يمسكه أي حارس سابق. الآن يمسكه هذا الفحص.
  final constMiddlewareLists = RegExp(r'middlewares:\s*const\s*\[')
      .allMatches(routesSrc)
      .length;
  check('[6] كل `middlewares` بلا `const` (مُنشئ GetMiddleware غير ثابت)',
      constMiddlewareLists == 0,
      '$constMiddlewareLists قائمة const — احذف `const` وإلا فشل البناء');

  // ── التقرير ──────────────────────────────────────────────────────
  stdout.writeln('─' * 62);
  stdout.writeln('حرس بوابة المسارات');
  stdout.writeln('─' * 62);
  stdout.writeln('ثوابت المسار: ${routeConsts.length} · '
      'مُعلَنة في routes.dart: ${declared.length} · '
      'محروسة إلزاميًا: ${mustBeGuarded.length} · '
      'مفاتيح في الحراس: $keyCount');
  for (final e in _errors) {
    stdout.writeln(e);
  }
  stdout.writeln('نجح: $_pass · فشل: $_fail');
  if (_fail > 0) exit(1);
  stdout.writeln('✅ كل الفحوص نجحت');
}

/// يحوّل `'invoice.delete'` → `invoiceDelete` (اسم الثابت في `PermissionKeys`).
String _keyConstName(String key) {
  final parts = key.split('.');
  if (parts.length != 2) return key;
  final head = parts[0];
  final tail = parts[1];
  final camel = tail
      .split('_')
      .map((w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1))
      .join();
  return '$head$camel';
}
