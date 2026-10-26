import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:laundry/services/i18n/l10n.dart';
import 'package:laundry/services/permission/permission_catalog.dart';
import 'package:laundry/services/permission/permission_service.dart';
import 'package:laundry/services/security/session_manager.dart';
import 'package:laundry/sqldb.dart';

/// نموذج دور واحد كما يُعرض في شاشة الأدوار.
class RoleRecord {
  final int roleId;
  final String name;
  final String label;
  final bool isSystem;

  /// الصلاحيات **المخزَّنة فعلًا** لهذا الدور (لا حزمة الكتالوج).
  final Set<String> granted;

  /// عدد المستخدمين النشطين المرتبطين بهذا الدور.
  final int usersCount;

  const RoleRecord({
    required this.roleId,
    required this.name,
    required this.label,
    required this.isSystem,
    required this.granted,
    this.usersCount = 0,
  });

  /// هل الدور جذر لا يقبل التعديل ولا الحذف؟
  bool get isRoot => PermissionCatalog.isRootRole(name);

  /// عدد الصلاحيات الممنوحة من أصل الكتالوج كله.
  int get count => granted.length;
}

/// متحكّم شاشة الأدوار والصلاحيات.
///
/// **مبدأ الحماية المزدوجة:** كل كتابة هنا (منح/سحب/إنشاء/حذف) تمرّ من
/// ثلاث بوابات متتالية:
/// 1. `PermissionService.can(roles.manage)` — فحص الجلسة الحالية.
/// 2. `PermissionCatalog.isRootRole` — منع مسّ دور الجذر `admin` بنيويًا
///    لا بالواجهة فقط (لو أُخفيت الودجة وحدها لبقي المسار مفتوحًا برمجيًا).
/// 3. `PermissionService.reload()` بعد كل تغيير — وإلا ظلّت الجلسة تعمل
///    بالصلاحيات القديمة حتى إعادة تشغيل التطبيق.
///
/// والتعديل يُسجَّل في `audit_log` بفرق الصلاحيات (`old_values`/`new_values`)
/// لأن منح صلاحية حذف فاتورة أو رؤية الأرباح **تغيير ائتماني** يجب أن يبقى
/// له أثر يُسأل عنه.
class RolesController extends GetxController {
  final SqlDB _db = SqlDB();

  final RxList<RoleRecord> roles = <RoleRecord>[].obs;
  final RxBool isLoading = false.obs;

  @override
  void onInit() {
    super.onInit();
    loadRoles();
  }

  // ══════════════════════════════════════════════════════════════════
  // القراءة
  // ══════════════════════════════════════════════════════════════════

  /// يحمّل الأدوار وحزمها من `roles` + `role_permissions` + عدّاد المستخدمين.
  ///
  /// استعلامان فقط مهما كان عدد الأدوار (لا استعلام لكل دور) — لأن القوائم
  /// تُبنى داخل `Obx` وتُعاد مع كل تغيير، فاستعلام داخل حلقة يُثقل الشاشة.
  Future<void> loadRoles() async {
    isLoading.value = true;
    try {
      final roleRows = await _db.safeRead('roles', orderBy: 'role_id ASC');

      // كل الإسنادات مرة واحدة ثم تُوزَّع على الأدوار في الذاكرة.
      final permRows = await _db.readData(
        'SELECT "role_id", "permission_key" FROM "role_permissions"',
      );
      final byRole = <int, Set<String>>{};
      for (final row in permRows) {
        final roleId = (row['role_id'] as num?)?.toInt();
        final key = row['permission_key']?.toString() ?? '';
        if (roleId == null) continue;
        if (!PermissionCatalog.isKnown(key)) continue; // مفتاح يتيم ⇒ يُهمَل
        (byRole[roleId] ??= <String>{}).add(key);
      }

      // عدد المستخدمين النشطين لكل دور — استعلام واحد مجمَّع.
      final userRows = await _db.readData(
        'SELECT "role", COUNT(*) AS total FROM "users" WHERE "is_active" = 1 GROUP BY "role"',
      );
      final usersByRole = <String, int>{};
      for (final row in userRows) {
        final role = row['role']?.toString() ?? '';
        usersByRole[role] = (row['total'] as num?)?.toInt() ?? 0;
      }

      roles.assignAll([
        for (final row in roleRows)
          RoleRecord(
            roleId: (row['role_id'] as num?)?.toInt() ?? 0,
            name: row['name']?.toString() ?? '',
            label: row['label']?.toString() ?? '',
            isSystem: (row['is_system'] as num?)?.toInt() == 1,
            granted: byRole[(row['role_id'] as num?)?.toInt() ?? 0] ??
                <String>{},
            usersCount: usersByRole[row['name']?.toString() ?? ''] ?? 0,
          ),
      ]);
    } catch (e) {
      debugPrint('loadRoles error: $e');
    } finally {
      isLoading.value = false;
    }
  }

  /// صلاحيات دور محدَّد كما تُخزَّن الآن (تُستعمل في شاشة المستخدم لعرض الميراث).
  Future<Set<String>> grantedOf(int roleId) async {
    try {
      final rows = await _db.readData(
        'SELECT "permission_key" FROM "role_permissions" WHERE "role_id" = ?',
        [roleId],
      );
      return {
        for (final r in rows)
          if (PermissionCatalog.isKnown(r['permission_key']?.toString() ?? ''))
            r['permission_key'].toString(),
      };
    } catch (e) {
      debugPrint('grantedOf error: $e');
      return <String>{};
    }
  }

  /// معرّف دور باسمه — `null` إن لم يوجد.
  Future<int?> roleIdOf(String name) async {
    try {
      final rows = await _db.safeRead(
        'roles',
        where: 'name = ?',
        whereArgs: [name],
        limit: 1,
      );
      if (rows.isEmpty) return null;
      return (rows.first['role_id'] as num?)?.toInt();
    } catch (e) {
      debugPrint('roleIdOf error: $e');
      return null;
    }
  }

  // ══════════════════════════════════════════════════════════════════
  // التعديل
  // ══════════════════════════════════════════════════════════════════

  /// يمنح/يسحب صلاحية واحدة لدور واحد.
  ///
  /// تُرجع `false` مع رسالة عند: انعدام صلاحية الإدارة، أو مسّ دور الجذر،
  /// أو مفتاح مجهول. ولا تكتب شيئًا في القاعدة قبل اجتياز البوابات الثلاث.
  Future<bool> setPermission({
    required RoleRecord role,
    required String key,
    required bool allow,
  }) async {
    if (!_guardManage()) return false;
    if (role.isRoot) {
      _refuse(tr('دور «مدير النظام» جذر لا يُعدَّل — يملك كل الصلاحيات دائمًا.'));
      return false;
    }
    if (!PermissionCatalog.isKnown(key)) {
      _refuse(trf('صلاحية غير معروفة في الكتالوج: {0}', [key]));
      return false;
    }

    final before = Set<String>.from(role.granted);
    if (allow == before.contains(key)) return true; // لا تغيير ⇒ لا كتابة

    try {
      if (allow) {
        await _insertPermission(role.roleId, key);
      } else {
        await _db.safeDelete(
          'role_permissions',
          where: 'role_id = ? AND permission_key = ?',
          whereArgs: [role.roleId, key],
        );
      }

      // نُسجِّل **عدد** صلاحيات الدور بعد التغيير لا مفتاحه وحده: انخفاض
      // العدد المفاجئ في سجل التدقيق هو الإشارة التي تُنبِّه المالك إلى أن
      // أحدًا يجرّد دورًا من قدراته تدريجيًا.
      final after = Set<String>.from(before);
      if (allow) {
        after.add(key);
      } else {
        after.remove(key);
      }

      await _logChange(
        action: allow ? 'role_permission_grant' : 'role_permission_revoke',
        roleName: role.name,
        oldValues: {
          'permission': key,
          'allow': !allow,
          'total': before.length,
        },
        newValues: {
          'permission': key,
          'allow': allow,
          'total': after.length,
        },
      );

      await loadRoles();
      await _reloadSession(role.name);
      return true;
    } catch (e) {
      debugPrint('setPermission error: $e');
      _refuse(trf('تعذّر تعديل الصلاحية: {0}', ['$e']));
      return false;
    }
  }

  /// يمنح/يسحب **مجموعة كاملة** (مثل كل صلاحيات «الزبائن والذمم») بدفعة واحدة.
  ///
  /// **لماذا دفعة واحدة لا نداء متسلسل؟** لأن كل نداء يُعيد بناء الشاشة
  /// ويُسجِّل صفًا في التدقيق ويُعيد تحميل الجلسة — فمجموعة من 8 صلاحيات
  /// تُنتج 8 عمليات قراءة و8 صفوف تدقيق بلا داعٍ، ويُرى التغيير يتحرّك
  /// صفًا صفًا. هنا: كتابات مجمَّعة، ثم صف تدقيق واحد، ثم إعادة تحميل واحدة.
  Future<bool> setGroup({
    required RoleRecord role,
    required String group,
    required bool allow,
  }) async {
    if (!_guardManage()) return false;
    if (role.isRoot) {
      _refuse(tr('دور «مدير النظام» جذر لا يُعدَّل — يملك كل الصلاحيات دائمًا.'));
      return false;
    }

    final items = PermissionCatalog.ofGroup(group);
    if (items.isEmpty) return true;

    final changed = <String>[];
    try {
      for (final item in items) {
        if (allow) {
          if (role.granted.contains(item.key)) continue;
          await _insertPermission(role.roleId, item.key);
          changed.add(item.key);
        } else {
          if (!role.granted.contains(item.key)) continue;
          await _db.safeDelete(
            'role_permissions',
            where: 'role_id = ? AND permission_key = ?',
            whereArgs: [role.roleId, item.key],
          );
          changed.add(item.key);
        }
      }
      if (changed.isEmpty) return true;

      await _logChange(
        action: allow ? 'role_group_grant' : 'role_group_revoke',
        roleName: role.name,
        oldValues: {'group': group, 'allow': !allow, 'keys': changed},
        newValues: {'group': group, 'allow': allow, 'keys': changed},
      );

      await loadRoles();
      await _reloadSession(role.name);
      return true;
    } catch (e) {
      debugPrint('setGroup error: $e');
      _refuse(trf('تعذّر تعديل المجموعة: {0}', ['$e']));
      return false;
    }
  }

  /// يعيد حزمة الدور إلى حزمة الكتالوج الافتراضية (يُتجاهل للجذر).
  Future<bool> resetToDefault(RoleRecord role) async {
    if (!_guardManage()) return false;
    if (role.isRoot) {
      _refuse(tr('دور «مدير النظام» يملك كل الصلاحيات أصلًا.'));
      return false;
    }
    final bundle = PermissionCatalog.defaultBundleOf(role.name);
    if (bundle == null) {
      _refuse(
        trf('لا حزمة افتراضية معروفة للدور «{0}».', [role.label]),
      );
      return false;
    }

    try {
      await _db.safeDelete(
        'role_permissions',
        where: 'role_id = ?',
        whereArgs: [role.roleId],
      );
      for (final key in bundle) {
        await _insertPermission(role.roleId, key);
      }

      await _logChange(
        action: 'role_reset_default',
        roleName: role.name,
        oldValues: {'granted': role.granted.toList()},
        newValues: {'granted': bundle},
      );

      await loadRoles();
      await _reloadSession(role.name);
      Get.snackbar(
          tr('تم'),
          trf('أُعيدت حزمة «{0}» إلى الافتراضي.', [role.label]),
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: const Color(0xFF16A34A),
          colorText: Colors.white);
      return true;
    } catch (e) {
      debugPrint('resetToDefault error: $e');
      _refuse(trf('تعذّرت إعادة التعيين: {0}', ['$e']));
      return false;
    }
  }

  // ══════════════════════════════════════════════════════════════════
  // إدارة الأدوار نفسها (إنشاء/تسمية/حذف)
  // ══════════════════════════════════════════════════════════════════

  /// ينشئ دورًا جديدًا بحزمة فارغة.
  ///
  /// **لماذا فارغة لا مقلَّدة عن دور آخر؟** لأن التقليد الصامت يمنح صلاحيات
  /// لم يقصدها المُنشئ. الفارغ يجبره على المنح الصريح واحدًا واحدًا.
  Future<bool> createRole({
    required String name,
    required String label,
    List<String> initialKeys = const <String>[],
  }) async {
    if (!_guardManage()) return false;

    final cleanName = name.trim().toLowerCase();
    if (!RegExp(r'^[a-z][a-z0-9_]{1,29}$').hasMatch(cleanName)) {
      _refuse(tr('اسم الدور يجب أن يبدأ بحرف لاتيني ويحتوي حروفًا وأرقامًا وشرطة سفلية فقط (2–30 محرفًا).'));
      return false;
    }
    if (label.trim().isEmpty) {
      _refuse(tr('أدخل اسمًا معروضًا للدور.'));
      return false;
    }
    if (PermissionCatalog.isRootRole(cleanName)) {
      _refuse(tr('الاسم «admin» محجوز لدور الجذر.'));
      return false;
    }

    try {
      final exists = await _db.safeRead(
        'roles',
        where: 'name = ?',
        whereArgs: [cleanName],
        limit: 1,
      );
      if (exists.isNotEmpty) {
        _refuse(trf('يوجد دور بالاسم «{0}» بالفعل.', [cleanName]));
        return false;
      }

      final roleId = await _db.safeInsert('roles', {
        'name': cleanName,
        'label': label.trim(),
        'is_system': 0,
        'created_at': DateTime.now().toIso8601String(),
      });

      for (final key in initialKeys) {
        if (!PermissionCatalog.isKnown(key)) continue;
        await _insertPermission(roleId, key);
      }

      await _logChange(
        action: 'role_create',
        roleName: cleanName,
        newValues: {'label': label.trim(), 'granted': initialKeys},
      );

      await loadRoles();
      Get.snackbar(
          tr('تم'),
          trf('أُنشئ الدور «{0}».', [label.trim()]),
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: const Color(0xFF16A34A),
          colorText: Colors.white);
      return true;
    } catch (e) {
      debugPrint('createRole error: $e');
      _refuse(trf('تعذّر إنشاء الدور: {0}', ['$e']));
      return false;
    }
  }

  /// يسمّي دورًا (يغيّر الوسم المعروض فقط — الاسم التقني لا يُغيَّر).
  Future<bool> renameRole({required RoleRecord role, required String label}) async {
    if (!_guardManage()) return false;
    if (role.isRoot) {
      _refuse(tr('لا يُعاد تسمية دور الجذر.'));
      return false;
    }
    if (label.trim().isEmpty) {
      _refuse(tr('أدخل اسمًا معروضًا.'));
      return false;
    }

    try {
      await _db.safeUpdate(
        'roles',
        {'label': label.trim()},
        where: 'role_id = ?',
        whereArgs: [role.roleId],
      );

      await _logChange(
        action: 'role_rename',
        roleName: role.name,
        oldValues: {'label': role.label},
        newValues: {'label': label.trim()},
      );

      await loadRoles();
      return true;
    } catch (e) {
      debugPrint('renameRole error: $e');
      _refuse(trf('تعذّرت إعادة التسمية: {0}', ['$e']));
      return false;
    }
  }

  /// يحذف دورًا غير نظامي — بشرط ألّا يكون عليه مستخدمون.
  ///
  /// **لماذا الحذف لا التعطيل هنا؟** لأن جدول `roles` لا يحمل `is_active`،
  /// والدور بلا مستخدمين ولا صلاحيات لا أثر له. لكن لو حُذف دور عليه
  /// مستخدمون لصاروا بلا دور ⇒ بلا صلاحيات ⇒ **منع صامت** من كل شيء.
  /// لذلك يُرفض الحذف حتى يُنقل المستخدمون أولًا.
  Future<bool> deleteRole(RoleRecord role) async {
    if (!_guardManage()) return false;
    if (role.isRoot) {
      _refuse(tr('لا يُحذف دور الجذر.'));
      return false;
    }
    if (role.isSystem) {
      _refuse(
        trf(
          '«{0}» دور نظامي لا يُحذف — يمكنك تعديل صلاحياته.',
          [role.label],
        ),
      );
      return false;
    }
    if (role.usersCount > 0) {
      _refuse(
        trf(
          'على «{0}» {1} مستخدم — انقلهم إلى دور آخر قبل الحذف.',
          [role.label, '${role.usersCount}'],
        ),
      );
      return false;
    }
    if (role.name == SessionManager.currentRole) {
      _refuse(tr('لا يمكنك حذف الدور الذي تعمل به الآن.'));
      return false;
    }

    try {
      await _db.safeDelete(
        'role_permissions',
        where: 'role_id = ?',
        whereArgs: [role.roleId],
      );
      await _db.safeDelete(
        'roles',
        where: 'role_id = ?',
        whereArgs: [role.roleId],
      );

      await _logChange(
        action: 'role_delete',
        roleName: role.name,
        oldValues: {'label': role.label, 'granted': role.granted.toList()},
      );

      await loadRoles();
      Get.snackbar(
          tr('تم'),
          trf('حُذف الدور «{0}».', [role.label]),
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: const Color(0xFF16A34A),
          colorText: Colors.white);
      return true;
    } catch (e) {
      debugPrint('deleteRole error: $e');
      _refuse(trf('تعذّر حذف الدور: {0}', ['$e']));
      return false;
    }
  }

  // ══════════════════════════════════════════════════════════════════
  // مساعدات داخلية
  // ══════════════════════════════════════════════════════════════════

  /// البوابة الأولى: صلاحية إدارة الأدوار في الجلسة الحالية.
  bool _guardManage() {
    if (PermissionService.can(PermissionKeys.rolesManage)) return true;
    _refuse(tr('إدارة الأدوار صلاحية مقصورة على مدير النظام (roles.manage).'));
    return false;
  }

  Future<void> _insertPermission(int roleId, String key) async {
    await _db.insertData(
      'INSERT OR IGNORE INTO "role_permissions" ("role_id", "permission_key") VALUES (?, ?)',
      [roleId, key],
    );
  }

  /// إعادة تحميل الجلسة **فقط** إن كان الدور المعدَّل هو دور المستخدم الحالي.
  ///
  /// وإلا فعّل المستخدم مديرًا وسحب صلاحياته ثم ظلّ يعمل بالقدرة القديمة
  /// حتى إعادة التشغيل — وهو بالضبط الثقب الذي نُغلق.
  Future<void> _reloadSession(String roleName) async {
    if (roleName != SessionManager.currentRole) return;
    await PermissionService.reload();
  }

  Future<void> _logChange({
    required String action,
    required String roleName,
    Map<String, dynamic>? oldValues,
    Map<String, dynamic>? newValues,
  }) async {
    final roleId = await roleIdOf(roleName);
    await _db.logAudit(
      userId: SessionManager.currentUserId,
      action: action,
      tableName: 'roles',
      recordId: roleId,
      oldValues: oldValues == null ? null : jsonEncode(oldValues),
      newValues: newValues == null ? null : jsonEncode(newValues),
    );
  }

  void _refuse(String message) {
    Get.snackbar(tr('مرفوض'), message,
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: const Color(0xFFDC2626),
        colorText: Colors.white);
  }
}
