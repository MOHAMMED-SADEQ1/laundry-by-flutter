import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import 'package:laundry/services/i18n/l10n.dart';
import 'package:laundry/services/permission/permission_catalog.dart';
import 'package:laundry/services/security/session_manager.dart';
import 'package:laundry/services/permission/permission_db_handle.dart';

/// خدمة فحص الصلاحيات — **العقد الوحيد** الذي يُسأل «هل يملك هذا المستخدم
/// هذه العملية؟».
///
/// **التحوّل من الثوابت إلى الإسناد:**
/// كانت كل الصلاحيات ثوابت `static get` تُشتق من الدور مباشرةً، فمن أراد
/// تغيير صلاحية كاشير واحد أعاد الترجمة والنشر. صار الفحص الآن يقرأ من:
///
///   ١. **التجاوز الفردي** (`permission_overrides`) — إن وُجد للمستخدم
///      والصلاحية صفّ، فهو **الغالب** (منحًا أو منعًا).
///   ٢. **دور المستخدم** (`users.role` ← `roles.name` ← `role_permissions`).
///   ٣. إن لم يوجد شيء ⇒ **ممنوع** (الفشل مُغلَق لا مفتوح).
///
/// **التخزين المؤقت (لماذا؟):** الفحص يُنادى في كل بناء واجهة، ومئات المرات
/// في الشاشة الواحدة. لو استعلم لكل نداء لصار كل رسم بطاقة رحلة إلى القاعدة.
/// فتُحمَّل مجموعة صلاحيات المستخدم **مرة واحدة** عند الدخول/الاستعادة،
/// وتُحدَّث (`reload`) عند أي تعديل على الأدوار أو المستخدمين.
///
/// **التهيئة الصريحة:** إن لم تُحمَّل بعد (`!isLoaded`) فإن [can] ترجع
/// `false` **بلا استعلام** — فلا نداء شبكة/قاعدة في مسار الرسم، ولا فتح
/// قاعدة لسهو. الواجهة تُحقن من `main.dart` ومن `AuthController` بعد الدخول.
///
/// **الظهر التوافقي:** كل الدوال السابقة (22 `static get`) باقية بنفس
/// أسمائها ونفس معانيها، لكنها تُفوِّض إلى [can] بمفتاح الكتالوج بدل اشتقاق
/// الدور. فالسطور التي تستدعيها اليوم في 7 ملفات تعمل كما هي بالضبط، لكنها
/// صارت **قابلة للضبط** بلا لمسها.
class PermissionService {
  PermissionService._();

  // ══════════════════════════════════════════════════════════════════
  // الحالة
  // ══════════════════════════════════════════════════════════════════

  /// مفاتيح الصلاحيات الفعّالة للمستخدم الحالي (بعد التجاوز والدور).
  static Set<String> _granted = <String>{};

  /// هل حُمِّلت المجموعة؟ قبل الحمل ⇒ لا شيء ممنوح (فشل مُغلَق).
  static bool _loaded = false;

  /// معرّف المستخدم الذي تخصّه المجموعة المحمَّلة — يكشف تبديل المستخدم.

  static bool get isLoaded => _loaded;

  /// عدد الصلاحيات المحمَّلة (للتشخيص والحراس).
  static int get grantedCount => _granted.length;

  /// نسخة للقراءة فقط من المفاتيح المحمَّلة (للشاشة والحراس).
  static Set<String> get grantedKeys => Set<String>.unmodifiable(_granted);

  // ══════════════════════════════════════════════════════════════════
  // التحميل
  // ══════════════════════════════════════════════════════════════════

  /// يحمّل صلاحيات **المستخدم الحالي** من قاعدة البيانات.
  ///
  /// يُستدعى: بعد نجاح الدخول (`AuthController`) · بعد استعادة الجلسة في
  /// الإقلاع (`main.dart`) · بعد أي تعديل على الأدوار أو المستخدمين.
  ///
  /// **يبتلع الفشل عمدًا:** لو تعذّر الاستعلام (قاعدة غير مفتوحة بعد، نسخة
  /// تُستعاد) نبقي المجموعة فارغة و`_loaded = true` بمفاتيح **دور نظيف**
  /// لاحقًا؟ لا — نتركها فارغة. الفارغ = لا صلاحيات = المنع. وهو الخيار
  /// الآمن. أما الخطأ الحقيقي فيُطبع ولا يُسقط التطبيق.
  static Future<void> load({DatabaseExecutor? db}) async {
    final userId = SessionManager.currentUserId;
    final role = SessionManager.currentRole;

    if (userId == null && role == null) {
      clear();
      return;
    }

    try {
      final executor = db ?? _dbOf();
      if (executor == null) {
        // لا قاعدة متاحة (إقلاع مبكّر جدًا) — نرجع بمجموعة الدور الافتراضية
        // من الكتالوج، وهي **مطابقة تمامًا** لمعنى ما كان النظام يعمل به.
        _granted = defaultKeysForRole(role);
        _loaded = true;
        return;
      }

      final keys = await _compose(executor, userId: userId, role: role);
      _granted = keys;
      _loaded = true;
    } catch (e) {
      debugPrint('PermissionService.load failed: $e');
      _granted = <String>{};
      _loaded = true;
    }
  }

  /// يُعيد التحميل — يُستدعى بعد أي تعديل على الصلاحيات أو المستخدمين أو
  /// الأدوار، فلا يبقى كاش قديم في واجهة مفتوحة.
  static Future<void> reload({DatabaseExecutor? db}) async {
    _loaded = false;
    await load(db: db);
  }

  /// يُفرغ الحالة — عند الخروج، أو قبل تبديل المستخدم.
  static void clear() {
    _granted = <String>{};
    _loaded = false;
  }

  /// يُحمّل لمستخدم بعينه بصلاحياته المستقلّة عن الجلسة الحالية.
  ///
  /// **لِمَن؟** لشاشة الأدوار والمستخدمين: تحتاج أن تعرض/تُحرّر صلاحيات
  /// **غير** المستخدم الجالس. لا تلمس كاش الجلسة إطلاقًا.
  static Future<Set<String>> keysForUser(
    DatabaseExecutor db, {
    required int? userId,
    required String? role,
  }) async {
    try {
      return await _compose(db, userId: userId, role: role);
    } catch (e) {
      debugPrint('PermissionService.keysForUser failed: $e');
      return <String>{};
    }
  }

  /// يُركّب المجموعة الفعّالة: التجاوز الفردي يعلو، ثم دور المستخدم.
  static Future<Set<String>> _compose(
    DatabaseExecutor db, {
    required int? userId,
    required String? role,
  }) async {
    final out = <String>{};

    // (أ) دور المستخدم
    final roleId = await _roleIdOf(db, role);
    if (roleId != null) {
      final rows = await db.query(
        'role_permissions',
        columns: <String>['permission_key'],
        where: 'role_id = ?',
        whereArgs: <Object?>[roleId],
      );
      for (final r in rows) {
        final k = r['permission_key'] as String?;
        // مفتاح مجهول في القاعدة (كُتب بإصدار أقدم أو يدويًا) **يُهمَل** —
        // فالإنفاذ يقرأ الكتالوج، ومفتاح بلا نقطة إنفاذ ليس صلاحية.
        if (k != null && PermissionCatalog.isKnown(k)) out.add(k);
      }
    }

    // (ب) التجاوز الفردي — الغالب على الدور
    if (userId != null) {
      final rows = await db.query(
        'permission_overrides',
        columns: <String>['permission_key', 'allow'],
        where: 'user_id = ?',
        whereArgs: <Object?>[userId],
      );
      for (final r in rows) {
        final k = r['permission_key'] as String?;
        if (k == null || !PermissionCatalog.isKnown(k)) continue;
        final allow = ((r['allow'] as num?)?.toInt() ?? 1) != 0;
        if (allow) {
          out.add(k);
        } else {
          out.remove(k);
        }
      }
    }

    return out;
  }

  /// مُنفِّذ القاعدة المفتوحة، أو `null` إن لم تُفتح بعد.
  ///
  /// يقرأ من الجسر `PermissionDbHandle` الذي يُحدّثه `SqlDB` — فلا دورة
  /// استيراد بين الخدمتين. و`null` تعني «القاعدة غير مفتوحة» فيُبنى من
  /// الكتالوج الافتراضي بلا أي فتح ضمني.
  static DatabaseExecutor? _dbOf() => PermissionDbHandle.connection;

  static Future<int?> _roleIdOf(DatabaseExecutor db, String? role) async {
    if (role == null || role.isEmpty) return null;
    final rows = await db.query(
      'roles',
      columns: <String>['role_id'],
      where: 'name = ?',
      whereArgs: <Object?>[role],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return (rows.first['role_id'] as num?)?.toInt();
  }

  /// الحزمة الافتراضية من **الكتالوج** لدور — تُستعمل حين لا قاعدة متاحة.
  static Set<String> defaultKeysForRole(String? role) {
    final bundle = PermissionCatalog.defaultBundleOf(role ?? '');
    return bundle == null ? <String>{} : bundle.toSet();
  }

  // ══════════════════════════════════════════════════════════════════
  // الفحص — الدوال الأساسية
  // ══════════════════════════════════════════════════════════════════

  /// هل يملك المستخدم الحالي الصلاحية [key]؟
  ///
  /// **لا تستعلم.** إن لم تُحمَّل المجموعة تُرجع `false` (فشل مُغلَق).
  /// لضمان التحميل المبكّر انظر `main.dart` و`AuthController.login`.
  static bool can(String key) {
    if (!_loaded) return false;
    return _granted.contains(key);
  }

  /// هل يملك **أيًّا** من هذه الصلاحيات؟ (تسجيل «مِلكية واحدة تكفي»).
  static bool any(List<String> keys) {
    if (!_loaded || keys.isEmpty) return false;
    for (final k in keys) {
      if (_granted.contains(k)) return true;
    }
    return false;
  }

  /// هل يملك **كل** هذه الصلاحيات؟ (تسجيل «الكل شرط»).
  static bool all(List<String> keys) {
    if (!_loaded || keys.isEmpty) return false;
    for (final k in keys) {
      if (!_granted.contains(k)) return false;
    }
    return true;
  }

  /// يرمي استثناءً بالعربية إن فقد المستخدم الصلاحية.
  ///
  /// **لماذا يرمي؟** طبقة الخدمة تُنفّذ الفحص قبل أي كتابة (`assert.can`).
  /// لو رجعت `false` صامتة لأكمل المتحكّم عمله كما لو نجح؛ فالجملة الصريحة
  /// تجعل التسرّب **مستحيلًا** لا **مُغفَلًا**. الواجهة تعرض نصّ الاستثناء.
  ///
  /// يرجع `true` إن كان مسموحًا — فيُستعمل في تعبير واحد:
  /// `PermissionService.assertCan(PermissionKeys.invoiceDelete);`
  static bool assertCan(String key, {String? action}) {
    if (can(key)) return true;
    final what = action ?? PermissionCatalog.find(key)?.label ?? key;
    throw PermissionDeniedException(key: key, action: what);
  }

  /// النسخة غير الرامية — للفحص في الواجهة بلا استثناء.
  static bool get isBlocked => !_loaded;

  // ══════════════════════════════════════════════════════════════════
  // الظهر التوافقي — كل الدوال السابقة (نفس الأسماء ونفس المعاني)
  // ══════════════════════════════════════════════════════════════════
  //
  // **لماذا أُبقيت؟** لأنها مستعملة في 7 ملفات قائمة (`home.dart` ·
  // `customdrawer.dart` · `settings_screen.dart` · `settings_sections.dart` ·
  // `custompayinvoice.dart` · `discounts_screen.dart` · `backup_screen.dart`)
  // ولم يكن الهدف كسرها بل **تحويلها إلى القابل للضبط**. فهذه الأسماء الآن
  // تُفوِّض إلى `can` بمفتاح واحد — والملفات لم تُلمس بعد. في المرحلة 7
  // تُحوَّل تدريجيًا إلى `can(PermissionKeys.x)` الصريح.

  static bool get canCreateInvoice => can('invoice.create');
  static bool get canManageCategories => can('category.manage');
  static bool get canManageCustomers => can('customer.manage');
  static bool get canManageUsers => can('users.manage');
  static bool get canViewReports => can('reports.view');
  static bool get canManageSettings => can('settings.manage');
  static bool get canPerformBackup => can('backup.perform');
  static bool get canManageShifts => can('shift.open');
  static bool get canManageExpenses => can('expense.manage');
  static bool get canManageSubscriptions => can('subscription.manage');
  static bool get canProcessLaundry => can('processing.update');
  static bool get canDeleteData => can('data.delete');
  static bool get canManageDiscounts => can('discount.manage');
  static bool get canApplyDiscount => can('invoice.discount_apply');
  static bool get canSellOnCredit => can('invoice.sell_on_credit');
  static bool get canOverrideCreditLimit => can('customer.credit_limit_override');
  static bool get canOverrideSubscriptionUsage =>
      can('subscription.usage_override');
  static bool get canSetCreditLimit => can('customer.credit_limit');
  static bool get canDeleteCustomer => can('customer.delete');
  static bool get canViewDebtReports => can('debt.view');
  static bool get canRepairBalances => can('debt.repair');
  static bool get canViewDashboard => can('dashboard.view');

  // إضافات الواجهة الجديدة (بلا تسمية سابقة — تُستعمل في المرحلة 7 وما بعدها)
  static bool get canCloseShift => can('shift.close');
  static bool get canViewCash => can('cash.view');
  static bool get canViewAudit => can('audit.view');
  static bool get canManageRoles => can('roles.manage');
  static bool get canViewUsers => can('users.view');
  static bool get canViewLicense => can('settings.license');

  // ══════════════════════════════════════════════════════════════════
  // واجهة العرض (الاسم واللون)
  // ══════════════════════════════════════════════════════════════════

  /// اسم الدور بالعربية — من الكتالوج (مصدر واحد).
  static String get roleLabel => PermissionCatalog.roleLabelOf(_role);

  /// لون الدور.
  static int get roleColor {
    switch (_role) {
      case 'admin':
        return 0xFFDC2626;
      case 'manager':
        return 0xFF2563EB;
      case 'cashier':
        return 0xFF16A34A;
      case 'accountant':
        return 0xFF7C3AED;
      case 'worker':
        return 0xFFD97706;
      default:
        return 0xFF6B7280;
    }
  }

  static String? get _role => SessionManager.currentRole;

  /// هل المستخدم الحالي مدير نظام (الجذر غير القابل للتعديل)؟
  static bool get isRoot => _role == 'admin';
}

/// يُرمى عند محاولة عملية بلا صلاحية — نصّه عربي جاهز للعرض.
class PermissionDeniedException implements Exception {
  final String key;

  /// اسم العملية الممنوعة كما يراه المستخدم.
  final String action;

  const PermissionDeniedException({required this.key, required this.action});

  @override
  String toString() => trf('لا تملك صلاحية «{0}»، راجع مدير النظام.', [action]);
}
