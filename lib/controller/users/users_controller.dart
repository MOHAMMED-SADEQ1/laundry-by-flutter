import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:laundry/sqldb.dart';
import 'package:laundry/services/security/security_service.dart';
import 'package:laundry/services/security/session_manager.dart';

class UsersController extends GetxController {
  final SqlDB _db = SqlDB();

  final RxList<Map<String, dynamic>> users = <Map<String, dynamic>>[].obs;
  final RxBool isLoading = false.obs;

  @override
  void onInit() {
    super.onInit();
    loadUsers();
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
        Get.snackbar('خطأ', 'اسم المستخدم "$username" مستخدم بالفعل',
            snackPosition: SnackPosition.BOTTOM);
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
      Get.snackbar('نجاح', 'تم إضافة المستخدم "$fullName"',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: const Color(0xFF16A34A),
          colorText: Colors.white);
      return true;
    } catch (e) {
      debugPrint('addUser error: $e');
      Get.snackbar('خطأ', 'فشل في إضافة المستخدم: $e',
          snackPosition: SnackPosition.BOTTOM);
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
        Get.snackbar('خطأ', 'اسم المستخدم "$username" مستخدم بالفعل',
            snackPosition: SnackPosition.BOTTOM);
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
      Get.snackbar('نجاح', 'تم تعديل المستخدم "$fullName"',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: const Color(0xFF16A34A),
          colorText: Colors.white);
      return true;
    } catch (e) {
      debugPrint('updateUser error: $e');
      Get.snackbar('خطأ', 'فشل في تعديل المستخدم: $e',
          snackPosition: SnackPosition.BOTTOM);
      return false;
    }
  }

  /// حذف مستخدم (تعطيل)
  Future<bool> deleteUser(int userId, String fullName) async {
    try {
      // لا يسمح بحذف النفس
      if (userId == SessionManager.currentUserId) {
        Get.snackbar('خطأ', 'لا يمكنك حذف حسابك الخاص',
            snackPosition: SnackPosition.BOTTOM);
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
      Get.snackbar('نجاح', 'تم حذف المستخدم "$fullName"',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: const Color(0xFF16A34A),
          colorText: Colors.white);
      return true;
    } catch (e) {
      debugPrint('deleteUser error: $e');
      Get.snackbar('خطأ', 'فشل في حذف المستخدم: $e',
          snackPosition: SnackPosition.BOTTOM);
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
    switch (role) {
      case 'admin':
        return 'مدير النظام';
      case 'manager':
        return 'مدير';
      case 'cashier':
        return 'كاشير';
      case 'accountant':
        return 'محاسب';
      case 'worker':
        return 'عامل';
      default:
        return role;
    }
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
