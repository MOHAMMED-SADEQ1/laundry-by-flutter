import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:laundry/services/i18n/l10n.dart';
import 'package:laundry/services/permission/permission_catalog.dart';
import 'package:laundry/services/permission/permission_service.dart';
import 'package:laundry/sqldb.dart';
import 'package:laundry/services/security/security_service.dart';
import 'package:laundry/services/security/session_manager.dart';

class UsersController extends GetxController {
  final SqlDB _db = SqlDB();

  final RxList<Map<String, dynamic>> users = <Map<String, dynamic>>[].obs;
  final RxBool isLoading = false.obs;

  /// الأدوار المتاحة للإسناد — تُقرأ من جدول `roles` لا من قائمة مكتوبة.
  ///
  /// **لماذا؟** لأن قائمة الأدوار المكتوبة في الواجهة تجعل أي دور جديد
  /// (صُنع في شاشة الأدوار) **غير قابل للإسناد** — يُنشأ ثم لا يظهر في
  /// المنتقي فيبدو كأنه لم يُنشأ. القائمة الآن تتبع القاعدة.
  final RxList<({String name, String label})> roleOptions =
      <({String name, String label})>[].obs;

  @override
  void onInit() {
    super.onInit();
    loadUsers();
    loadRoleOptions();
  }

  /// يحمّل الأدوار المتاحة للإسناد من جدول `roles` مرتّبةً بالمعرّف.
  Future<void> loadRoleOptions() async {
    try {
      final rows = await _db.safeRead('roles', orderBy: 'role_id ASC');
      if (rows.isEmpty) {
        // لا جدول أدوار (قاعدة قديمة قبل الترحيل) ⇒ ارجع لكتالوج الكتالوج
        // بدل أن يبقى المنتقي فارغًا فيتعذّر إنشاء أي مستخدم.
        roleOptions.assignAll([
          for (final r in PermissionCatalog.seedRoles)
            (name: r.name, label: r.label),
        ]);
        return;
      }
      roleOptions.assignAll([
        for (final row in rows)
          (
            name: row['name']?.toString() ?? '',
            label: row['label']?.toString().isNotEmpty == true
                ? row['label'].toString()
                : PermissionCatalog.roleLabelOf(row['name']?.toString()),
          ),
      ]);
    } catch (e) {
      debugPrint('loadRoleOptions error: $e');
    }
  }

  /// تسمية دور من القائمة المحمَّلة، مع رجوع آمن لاسمه الخام.
  String labelForRole(String role) {
    for (final r in roleOptions) {
      if (r.name == role) return r.label;
    }
    return PermissionCatalog.roleLabelOf(role);
  }

  Future<void> loadUsers() async {
    isLoading.value = true;
    try {
      final rows = await _db.safeRead(
        'users',
        orderBy: 'user_id ASC',
      );
      users.assignAll(rows);
    } catch (e) {
      debugPrint('loadUsers error: $e');
    } finally {
      isLoading.value = false;
    }
  }

  /// إضافة مستخدم جديد
  Future<bool> addUser({
    required String fullName,
    required String username,
    required String password,
    required String role,
  }) async {
    try {
      // التحقق من عدم تكرار اسم المستخدم
      final existing = await _db.safeRead(
        'users',
        where: 'username = ?',
        whereArgs: [username],
      );
      if (existing.isNotEmpty) {
        Get.snackbar(
          tr('خطأ'),
          trf('اسم المستخدم "{0}" مستخدم بالفعل', [username]),
          snackPosition: SnackPosition.BOTTOM,
        );
        return false;
      }

      final passwordHash = SecurityService.hashPassword(password);
      final userId = await _db.safeInsert('users', {
        'username': username,
        'full_name': fullName,
        'password_hash': passwordHash,
        'role': role,
        'is_active': 1,
        'created_at': DateTime.now().toIso8601String(),
      });

      await _db.logAudit(
        userId: SessionManager.currentUserId,
        action: 'user_create',
        tableName: 'users',
        recordId: userId,
        newValues: '{"username":"$username","role":"$role"}',
      );

      await loadUsers();
      Get.snackbar(
        tr('نجاح'),
        trf('تم إضافة المستخدم "{0}"', [fullName]),
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: const Color(0xFF16A34A),
        colorText: Colors.white,
      );
      return true;
    } catch (e) {
      debugPrint('addUser error: $e');
      Get.snackbar(
        tr('خطأ'),
        trf('فشل في إضافة المستخدم: {0}', [e]),
        snackPosition: SnackPosition.BOTTOM,
      );
      return false;
    }
  }

  /// تعديل مستخدم
  Future<bool> updateUser({
    required int userId,
    required String fullName,
    required String username,
    String? newPassword,
    required String role,
    required bool isActive,
  }) async {
    try {
      // التحقق من عدم تكرار اسم المستخدم (مع استثناء نفس المستخدم)
      final existing = await _db.safeRead(
        'users',
        where: 'username = ? AND user_id != ?',
        whereArgs: [username, userId],
      );
      if (existing.isNotEmpty) {
        Get.snackbar(
          tr('خطأ'),
          trf('اسم المستخدم "{0}" مستخدم بالفعل', [username]),
          snackPosition: SnackPosition.BOTTOM,
        );
        return false;
      }

      final updateData = <String, dynamic>{
        'full_name': fullName,
        'username': username,
        'role': role,
        'is_active': isActive ? 1 : 0,
      };

      if (newPassword != null && newPassword.isNotEmpty) {
        updateData['password_hash'] = SecurityService.hashPassword(newPassword);
      }

      await _db.safeUpdate(
        'users',
        updateData,
        where: 'user_id = ?',
        whereArgs: [userId],
      );

      await _db.logAudit(
        userId: SessionManager.currentUserId,
        action: 'user_update',
        tableName: 'users',
        recordId: userId,
        newValues: '{"username":"$username","role":"$role","is_active":$isActive}',
      );

      await loadUsers();
      Get.snackbar(
        tr('نجاح'),
        trf('تم تعديل المستخدم "{0}"', [fullName]),
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: const Color(0xFF16A34A),
        colorText: Colors.white,
      );
      return true;
    } catch (e) {
      debugPrint('updateUser error: $e');
      Get.snackbar(
        tr('خطأ'),
        trf('فشل في تعديل المستخدم: {0}', [e]),
        snackPosition: SnackPosition.BOTTOM,
      );
      return false;
    }
  }

  /// حذف مستخدم (تعطيل)
  Future<bool> deleteUser(int userId, String fullName) async {
    try {
      // لا يسمح بحذف النفس
      if (userId == SessionManager.currentUserId) {
        Get.snackbar(
          tr('خطأ'),
          tr('لا يمكنك حذف حسابك الخاص'),
          snackPosition: SnackPosition.BOTTOM,
        );
        return false;
      }

      await _db.safeUpdate(
        'users',
        {'is_active': 0},
        where: 'user_id = ?',
        whereArgs: [userId],
      );

      await _db.logAudit(
        userId: SessionManager.currentUserId,
        action: 'user_delete',
        tableName: 'users',
        recordId: userId,
      );

      await loadUsers();
      Get.snackbar(
        tr('نجاح'),
        trf('تم حذف المستخدم "{0}"', [fullName]),
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: const Color(0xFF16A34A),
        colorText: Colors.white,
      );
      return true;
    } catch (e) {
      debugPrint('deleteUser error: $e');
      Get.snackbar(
        tr('خطأ'),
        trf('فشل في حذف المستخدم: {0}', [e]),
        snackPosition: SnackPosition.BOTTOM,
      );
      return false;
    }
  }

  /// تفعيل / تعطيل مستخدم
  Future<void> toggleActive(int userId, bool currentStatus) async {
    try {
      await _db.safeUpdate(
        'users',
        {'is_active': currentStatus ? 0 : 1},
        where: 'user_id = ?',
        whereArgs: [userId],
      );
      await loadUsers();
    } catch (e) {
      debugPrint('toggleActive error: $e');
    }
  }

  /// تسمية الدور بالعربية
  static String roleLabel(String role) {
    return PermissionCatalog.roleLabelOf(role);
  }

  // ══════════════════════════════════════════════════════════════════
  // 🛡️ التجاوزات الفردية (permission_overrides)
  // ══════════════════════════════════════════════════════════════════
  //
  // **لماذا تجاوز فردي أصلًا؟** لأن الأدوار تُعبّر عن «صنف وظيفي»، لكن
  // الواقع فيه استثناءات: كاشير واحد مأمون يُمنَح الخصم، ومحاسب واحد
  // يُمنَع من رؤية الأرباح. الحلّان الرديئان: (1) تغيير الدور فيتأثّر
  // كل من يحمله، (2) إنشاء دور لكل استثناء فتنفجر الأدوار. الجدول هنا
  // يحلّها بصفٍّ واحد: `allow=1` يمنح فوق الدور، و`allow=0` يسحب من الدور.

  /// معرّف دور باسمه — `null` إن لم يوجد.
  ///
  /// **لماذا هنا لا في شاشة الأدوار فقط؟** لأن ورقة الصلاحيات الفردية
  /// تحتاج أن تعرف **حزمة الدور** لتُظهر «الموروث»، وحزمة الدور تُقرأ
  /// بـ`role_id`. وجودها في متحكّم المستخدمين يمنع الشاشة من استدعاء
  /// متحكّمين اثنين لعملية واحدة.
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

  /// صلاحيات دور محدَّد كما تُخزَّن فعلًا في `role_permissions`.
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

  /// يجلب التجاوزات الفردية لمستخدم: `{key: allow}`.
  Future<Map<String, bool>> overridesOf(int userId) async {
    try {
      final rows = await _db.safeRead(
        'permission_overrides',
        where: 'user_id = ?',
        whereArgs: [userId],
      );
      return {
        for (final r in rows)
          if (PermissionCatalog.isKnown(r['permission_key']?.toString() ?? ''))
            r['permission_key'].toString():
                (r['allow'] as num?)?.toInt() == 1,
      };
    } catch (e) {
      debugPrint('overridesOf error: $e');
      return <String, bool>{};
    }
  }

  /// مجموع صلاحيات مستخدم فعليًا = حزمة دوره ثم التجاوزات فوقها.
  ///
  /// هذا هو **نفس** ترتيب `PermissionService._compose` — وإلا عُرض للمدير
  /// شيء وعمل المستخدم بشيء آخر.
  Future<Set<String>> effectiveFor({
    required int? userId,
    required String role,
  }) async {
    final db = await _db.dbGet;
    if (db == null) return <String>{};
    return PermissionService.keysForUser(db, userId: userId, role: role);
  }

  /// يمنح أو يسحب صلاحية لمستخدم بعينه فوق دوره.
  ///
  /// `allow = true` ⇒ منح صريح · `allow = false` ⇒ سحب صريح · `null` ⇒ مسح
  /// التجاوز ليعود المستخدم لحزمة دوره وحدها.
  Future<bool> setOverride({
    required int userId,
    required String key,
    required bool? allow,
  }) async {
    if (!PermissionService.can(PermissionKeys.usersManage)) {
      _refuse(
        tr('تعديل صلاحيات المستخدم يحتاج صلاحية إدارة المستخدمين.'),
      );
      return false;
    }
    if (!PermissionCatalog.isKnown(key)) {
      _refuse(trf('صلاحية غير معروفة: {0}', [key]));
      return false;
    }

    try {
      if (allow == null) {
        await _db.safeDelete(
          'permission_overrides',
          where: 'user_id = ? AND permission_key = ?',
          whereArgs: [userId, key],
        );
      } else {
        // UPSERT يدوي: `INSERT OR REPLACE` يحترم المفتاح المركّب فيكتب آخر
        // قيمة بدل رفض التكرار — والاعتماد على `ConflictAlgorithm.replace`
        // في `insertData` غير متاح لأنها `rawInsert`.
        await _db.insertData(
          'INSERT OR REPLACE INTO "permission_overrides" ("user_id", "permission_key", "allow") VALUES (?, ?, ?)',
          [userId, key, allow ? 1 : 0],
        );
      }

      await _db.logAudit(
        userId: SessionManager.currentUserId,
        action: 'user_permission_override',
        tableName: 'permission_overrides',
        recordId: userId,
        newValues: jsonEncode({'user_id': userId, 'key': key, 'allow': allow}),
      );

      // لو عدّل المدير **نفسه**، يجب أن تسري الصلاحية الجديدة فورًا عليه.
      if (userId == SessionManager.currentUserId) {
        await PermissionService.reload();
      }
      return true;
    } catch (e) {
      debugPrint('setOverride error: $e');
      _refuse(trf('تعذّر تعديل الصلاحية: {0}', [e]));
      return false;
    }
  }

  /// يمسح كل تجاوزات مستخدم — فيعود لحزمة دوره وحدها.
  Future<bool> clearOverrides(int userId) async {
    if (!PermissionService.can(PermissionKeys.usersManage)) {
      _refuse(
        tr('تعديل صلاحيات المستخدم يحتاج صلاحية إدارة المستخدمين.'),
      );
      return false;
    }
    try {
      final count = (await overridesOf(userId)).length;
      await _db.safeDelete(
        'permission_overrides',
        where: 'user_id = ?',
        whereArgs: [userId],
      );
      await _db.logAudit(
        userId: SessionManager.currentUserId,
        action: 'user_permission_override_clear',
        tableName: 'permission_overrides',
        recordId: userId,
        oldValues: jsonEncode({'cleared': count}),
      );
      if (userId == SessionManager.currentUserId) {
        await PermissionService.reload();
      }
      Get.snackbar(
        tr('تم'),
        trf('أُزيلت {0} تجاوزات فردية.', [count]),
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: const Color(0xFF16A34A),
        colorText: Colors.white,
      );
      return true;
    } catch (e) {
      debugPrint('clearOverrides error: $e');
      _refuse(trf('تعذّر المسح: {0}', [e]));
      return false;
    }
  }

  void _refuse(String message) {
    Get.snackbar(tr('مرفوض'), message,
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: const Color(0xFFDC2626),
        colorText: Colors.white);
  }

  /// لون الدور
  static Color roleColor(String role) {
    switch (role) {
      case 'admin':
        return const Color(0xFFDC2626);
      case 'manager':
        return const Color(0xFF2563EB);
      case 'cashier':
        return const Color(0xFF16A34A);
      case 'accountant':
        return const Color(0xFF7C3AED);
      case 'worker':
        return const Color(0xFFD97706);
      default:
        return const Color(0xFF6B7280);
    }
  }
}
