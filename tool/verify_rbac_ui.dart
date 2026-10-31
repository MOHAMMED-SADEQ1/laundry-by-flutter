// حرس المرحلة 5: شاشة الأدوار والصلاحيات + التجاوز الفردي.
//
// **ما يحرسه؟** ليس الشكل البصري بل **البنية الأمنية**: أن البوابات
// (صلاحية الجلسة، حماية الجذر، إلزام إعادة التحميل، تدقيق كل تغيير)
// موجودة في المصدر فعلًا. لأن العيب هنا لا يظهر كخطأ ترجمة ولا كقاعدة
// مكسورة — بل كـ**ثقب صامت** لا يُكتشف إلا بعد أن يستغلّه أحد.
//
// التشغيل: dart run tool/verify_rbac_ui.dart  (من جذر المشروع)

import 'dart:io';

int passed = 0;
int failed = 0;

void check(String name, bool ok, [String? detail]) {
  if (ok) {
    passed++;
    print('  ✓ $name');
  } else {
    failed++;
    print('  ✗ $name${detail == null ? '' : ' — $detail'}');
  }
}

String? readFile(String path) {
  final f = File(path);
  if (!f.existsSync()) return null;
  return f.readAsStringSync();
}

bool has(String? src, String needle) => src != null && src.contains(needle);

/// عدد مرات ظهور نمط في نص.
int countOf(String? src, String needle) {
  if (src == null || needle.isEmpty) return 0;
  var n = 0;
  var i = src.indexOf(needle);
  while (i != -1) {
    n++;
    i = src.indexOf(needle, i + needle.length);
  }
  return n;
}

void main() {
  print('═══ حرس المرحلة 5: الأدوار والصلاحيات + التجاوز الفردي ═══\n');

  final controller = readFile('lib/controller/users/roles_controller.dart');
  final screen = readFile('lib/view/screen/users/roles_screen.dart');
  final sheet =
      readFile('lib/view/screen/users/user_permissions_sheet.dart');
  final usersCtrl = readFile('lib/controller/users/users_controller.dart');
  final usersScreen = readFile('lib/view/screen/users_screen.dart');
  final routes = readFile('lib/routes.dart');
  final routeConst = readFile('lib/core/constant/routes.dart');

  // ── [1] الملفات موجودة ────────────────────────────────────────────
  print('[1] الملفات');
  check('roles_controller.dart موجود', controller != null);
  check('roles_screen.dart موجود', screen != null);
  check('user_permissions_sheet.dart موجود', sheet != null);

  // ── [2] المسار مسجَّل ومحمي ───────────────────────────────────────
  print('\n[2] المسار');
  check('AppRoute.roles معرَّف',
      has(routeConst, "static const String roles = \"/roles\";"));
  check('GetPage للـroles مسجَّل', has(routes, 'name: AppRoute.roles'));
  check('roles_screen مستورد', has(routes, 'users/roles_screen.dart'));
  final rolesPageIdx = routes?.indexOf('name: AppRoute.roles') ?? -1;
  check('المسار محمي بـPermissionGuard',
      rolesPageIdx != -1 &&
          routes!.substring(rolesPageIdx).contains('PermissionGuard'));
  check('المفتاح هو rolesManage',
      rolesPageIdx != -1 &&
          routes!
              .substring(rolesPageIdx, rolesPageIdx + 400)
              .contains('PermissionKeys.rolesManage'));

  // ── [3] البوابات الثلاث في المتحكّم ──────────────────────────────
  print('\n[3] بوابات الحماية في المتحكّم');
  check('بوابة صلاحية الإدارة موجودة',
      has(controller, 'PermissionService.can(PermissionKeys.rolesManage)'));
  check('بوابة الجذر موجودة', has(controller, 'role.isRoot'));
  check('الفحص البنيوي isRootRole',
      has(controller, 'PermissionCatalog.isRootRole'));
  check('إعادة تحميل الجلسة موجودة', has(controller, 'PermissionService.reload()'));
  check('إعادة التحميل مشروطة بدور المستخدم',
      has(controller, 'roleName != SessionManager.currentRole'));
  check('التدقيق عبر logAudit', has(controller, '_db.logAudit'));
  check('الكاتب يستعمل readData بمعاملات ?',
      has(controller, 'role_id" = ?') || has(controller, '"role_id" = ?'));

  // ── [4] كل عمليات الكتابة محروسة ──────────────────────────────────
  print('\n[4] كل عمليات الكتابة محروسة');
  for (final fn in <String>[
    'setPermission',
    'setGroup',
    'resetToDefault',
    'createRole',
    'renameRole',
    'deleteRole',
  ]) {
    final idx = controller?.indexOf('Future<bool> $fn(') ?? -1;
    final body = idx == -1
        ? null
        : controller!.substring(idx, (idx + 2600).clamp(0, controller.length));
    check('$fn يبدأ ببوابة _guardManage',
        body != null && body.contains('_guardManage()'),
        body == null ? 'الدالة غير موجودة' : null);
  }

  // ── [5] منع تصعيد الصلاحية الذاتي ────────────────────────────────
  print('\n[5] منع تصعيد الصلاحية الذاتي');
  check('رفض تعديل دور الجذر في setPermission',
      has(controller, 'دور «مدير النظام» جذر لا يُعدَّل'));
  check('رفض حذف دور الجذر', has(controller, 'لا يُحذف دور الجذر'));
  check('رفض حذف دور يعمل به المستخدم',
      has(controller, 'لا يمكنك حذف الدور الذي تعمل به الآن'));
  check('رفض حذف دور عليه مستخدمون',
      has(controller, 'role.usersCount > 0'));
  check('رفض حذف الأدوار النظامية', has(controller, 'دور نظامي لا يُحذف'));
  check('رفض اسم admin المحجوز', has(controller, 'محجوز لدور الجذر'));

  // ── [6] الواجهة تُظهر الجذر للقراءة فقط ──────────────────────────
  print('\n[6] الواجهة');
  check('التبديلات معطَّلة للجذر', has(screen, 'if (role.isRoot)'));
  check('قائمة الإجراءات تُخفى للجذر', has(screen, 'canManage && !role.isRoot'));
  check('ملاحظة الجذر معروضة', has(screen, 'دور الجذر يملك كل صلاحيات الكتالوج'));
  check('الكتالوج يُبنى من grouped', has(screen, 'PermissionCatalog.grouped'));
  check('ترتيب المجموعات من PermissionGroups', has(screen, 'PermissionGroups.labelOf'));
  check('عدد الصلاحيات من الكتالوج لا رقم مكتوب',
      has(screen, 'PermissionCatalog.count'));
  check('زر الإنشاء مشروط بالصلاحية',
      has(screen, 'if (PermissionService.can(PermissionKeys.rolesManage))'));
  check('زر المجموعة يمنح/يسحب الكل', has(screen, 'controller.setGroup('));
  check('التبديل الفردي يمرّ بـsetPermission', has(screen, 'controller.setPermission('));

  // ── [7] التجاوز الفردي: ثلاث حالات لا حالتان ─────────────────────
  print('\n[7] التجاوز الفردي');
  check('الحالات الثلاث معرَّفة', has(sheet, 'enum _OverrideState'));
  check('موروث معرَّف', has(sheet, '_OverrideState.inherit'));
  check('ممنوح معرَّف', has(sheet, '_OverrideState.allow'));
  check('مسحوب معرَّف', has(sheet, '_OverrideState.deny'));
  check('المسح يمرّر null لا false',
      has(sheet, 'state == _OverrideState.inherit') && has(sheet, '? null'));
  check('الشاشة تعرض الحالة الفعلية', has(sheet, 'bool _effective(String key)'));
  check('الحالة الفعلية = تجاوز ثم ميراث',
      has(sheet, 'return _roleKeys.contains(key);'));
  check('الكشف عن المُتجاوزات في الترويسة', has(sheet, 'تجاوز'));
  check('تراجع تفاؤلي عند الفشل', has(sheet, '_overrides[key] = previous;'));

  // ── [8] متحكّم المستخدمين: التجاوزات ─────────────────────────────
  print('\n[8] متحكّم المستخدمين');
  check('overridesOf موجود', has(usersCtrl, 'Future<Map<String, bool>> overridesOf('));
  check('setOverride موجود', has(usersCtrl, 'Future<bool> setOverride('));
  check('clearOverrides موجود', has(usersCtrl, 'Future<bool> clearOverrides('));
  check('effectiveFor موجود', has(usersCtrl, 'Future<Set<String>> effectiveFor('));
  check('effectiveFor تفوّض لـkeysForUser',
      has(usersCtrl, 'PermissionService.keysForUser('));
  check('setOverride يفحص users.manage',
      has(usersCtrl, 'PermissionService.can(PermissionKeys.usersManage)'));
  check('setOverride يسجِّل تدقيقًا',
      countOf(usersCtrl, 'user_permission_override') >= 2);
  check('المسح يستعمل DELETE بمعاملات ?',
      has(usersCtrl, "where: 'user_id = ? AND permission_key = ?'"));
  check('الكتابة UPSERT بمفتاح مركّب', has(usersCtrl, 'INSERT OR REPLACE INTO'));
  check('إعادة التحميل للذات فقط',
      has(usersCtrl, 'userId == SessionManager.currentUserId'));
  check('roleLabel تفوّض للكتالوج',
      has(usersCtrl, 'PermissionCatalog.roleLabelOf(role)'));

  // ── [9] الدمج في شاشة المستخدمين ─────────────────────────────────
  print('\n[9] الدمج في شاشة المستخدمين');
  check('مدخل الصلاحيات في القائمة', has(usersScreen, "value: 'permissions'"));
  check('مدخل الصلاحيات مشروط', has(usersScreen, 'PermissionKeys.rolesManage'));
  check('الورقة تُفتح بـbottomSheet', has(usersScreen, 'UserPermissionsSheet('));
  check('الورقة تستورد', has(usersScreen, 'user_permissions_sheet.dart'));
  check('الحالات الثلاث مشروحة في الورقة',
      has(sheet, 'لا حالتان') || has(sheet, 'ثلاث حالات'));

  // ── [10] لا نسخ مكرَّرة للأدوار ──────────────────────────────────
  print('\n[10] لا تكرار للأدوار');
  check('users_controller لم يعد يكتب الأدوار يدويًا',
      !has(usersCtrl, "case 'admin':") || has(usersCtrl, 'roleColor'));
  check('roles_screen لا يعرّف أدوارًا بنفسه',
      !has(screen, "'cashier', 'مدير'"));

  // ── [11] لا `null` كقيمة في منتقي ────────────────────────────────
  //
  // بندٌ بـ`value: null` مع `DropdownButtonFormField<String>` يسقط في
  // الوضع التنقيحي (بندان يطابقان «لا اختيار»). القيمة الفارغة `''` صريحة.
  print('\n[11] منتقي النسخ');
  check('لا DropdownMenuItem بقيمة null',
      !has(screen, 'value: null,'));
  check('الحرس يسـتعمل سلسلة فارغة', has(screen, "String base = '';"));
  check('الفحص على isEmpty لا == null', has(screen, 'base.isEmpty'));

  // ── [12] الحوار لا يعتمد على قيمة مُعادة ────────────────────────
  //
  // `null` (سحب) و`false` (إلغاء) يتساويان لو قُرئا معًا ⇒ إمّا تحميل
  // بلا سبب أو إهمال نجاح حقيقي. المصدر الصادق هو نجاح الكتابة نفسه.
  print('\n[12] حوار تأكيد المسح');
  check('لا يقرأ القيمة المُعادة',
      !has(sheet, 'final ok = await Get.defaultDialog'));
  check('يمرّر Get.defaultDialog<void>', has(sheet, 'Get.defaultDialog<void>('));
  // الإغلاق إمّا بالفحص المباشر أو عبر `dismissOpenDialog()` المشترك في
  // `core/navigation/route_dismissal.dart` — وهو يفعل الفحص نفسه ثم
  // `Get.close(1)` (يتجاوز فحص الـsnackbar في GetX 4.x).
  check(
      'يُغلق بفحص isDialogOpen',
      has(sheet, 'if (Get.isDialogOpen == true) Get.back();') ||
          has(sheet, 'dismissOpenDialog()'));

  // ── [13] الأدوار تُقرأ من القاعدة لا من قائمة مكتوبة ─────────────
  //
  // **العيب الذي يمنعه:** دور جديد يُصنع في شاشة الأدوار ثم لا يظهر في
  // منتقي الأدوار بشاشة المستخدمين ⇒ يُنشأ ولا يُسنَد ⇒ يبدو كأن الإنشاء
  // فشل بلا سبب. القائمة المكتوبة في الواجهة هي سبب ذلك.
  print('\n[13] مصدر الأدوار في منتقي المستخدمين');
  check('roleOptions معرَّفة', has(usersCtrl, 'roleOptions'));
  check('تُحمَّل من جدول roles', has(usersCtrl, "safeRead('roles'"));
  check('loadRoleOptions مستدعاة في onInit', has(usersCtrl, 'loadRoleOptions();'));
  check('رجوع للكتالوج عند غياب الجدول',
      has(usersCtrl, 'PermissionCatalog.seedRoles'));
  check('labelForRole موجودة', has(usersCtrl, 'String labelForRole('));
  check('المنتقيان يقرآن roleOptions',
      countOf(usersScreen, 'controller.roleOptions') == 2,
      'عدد المواضع: ${countOf(usersScreen, 'controller.roleOptions')}');
  check('لا قائمة أدوار مكتوبة في الواجهة',
      !has(usersScreen, "DropdownMenuItem(value: 'admin'"));
  check('العرض يستعمل labelForRole',
      has(usersScreen, 'controller.labelForRole(role)'));

  // ── [14] المدخل في القائمة الجانبية ─────────────────────────────
  //
  // **العيب الذي يمنعه:** شاشة تعمل ولا يمكن الوصول إليها — وهي أسوأ من
  // عدم وجودها، لأنها تُوهِم بأن الميزة أُنجزت. (وجدنا `/users` نفسه
  // بلا مدخل قبل هذا الفحص.)
  print('\n[14] المدخل في القائمة الجانبية');
  final drawer = readFile('lib/view/widget/home/customdrawer.dart');
  check('مدخل الأدوار موجود', has(drawer, "route: '/roles'"));
  check('مشروط بـrolesManage',
      has(drawer, 'PermissionService.can(PermissionKeys.rolesManage)'));
  check('permission_catalog مستورد في القائمة',
      has(drawer, 'permission_catalog.dart'));
  check('مدخل المستخدمين يستعمل المفتاح الصريح',
      has(drawer, 'PermissionService.can(PermissionKeys.usersManage)'));

  // ── [15] مصدر واحد لتسمية الدور ─────────────────────────────────
  //
  // **العيب الذي يمنعه:** ثلاث نسخ `switch` للأسماء: `UsersController`
  // و`ProfileController` و`PermissionCatalog`. أول دور جديد يُترجَم في
  // مكان ويُنسى في آخر ⇒ اسم بلغتين في نفس الشاشة.
  print('\n[15] مصدر واحد لتسمية الدور');
  final profileCtrl = readFile('lib/controller/profile_controller.dart');

  /// يستخرج جسم دالة `roleLabel` **بلا تعليقها** — التعليق يشرح أن النسخة
  /// القديمة كانت `switch`، فلو فُحص النص كاملًا لرسب التوثيق نفسه.
  String? roleLabelBody(String? src) {
    if (src == null) return null;
    final i = src.indexOf('static String roleLabel(');
    if (i == -1) return null;
    return src.substring(i, (i + 120).clamp(0, src.length));
  }

  check('ProfileController.roleLabel لم تعد switch',
      !(roleLabelBody(profileCtrl) ?? '').contains('case '));
  check('ProfileController فوّض للكتالوج',
      has(roleLabelBody(profileCtrl), 'PermissionCatalog.roleLabelOf(role)'));
  check('UsersController.roleLabel فوّض للكتالوج',
      has(roleLabelBody(usersCtrl), 'PermissionCatalog.roleLabelOf(role)'));
  // ⚠️ `roleColor` **تبقى** switch عن قصد: الألوان لم تُدرَج في الكتالوج
  // لأنها عرض لا سلطة، والدور المجهول يأخذ لونًا رماديًا محايدًا.
  check('roleColor يبقى Switch محليًا (مقصود)',
      has(usersCtrl, 'static Color roleColor(String role)'));

  print('\n═══ النتيجة: نجح $passed · فشل $failed ═══');
  if (failed > 0) exitCode = 1;
}
