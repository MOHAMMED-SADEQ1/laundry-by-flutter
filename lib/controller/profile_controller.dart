import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:laundry/services/security/security_service.dart';
import 'package:laundry/services/security/session_manager.dart';
import 'package:laundry/sqldb.dart';

class ProfileController extends GetxController {
  final SqlDB _db = SqlDB();
  final Rxn<Map<String, dynamic>> currentUser = Rxn<Map<String, dynamic>>();
  final RxBool isLoading = false.obs;

  @override
  void onInit() {
    super.onInit();
    loadProfile();
  }

  Future<void> loadProfile() async {
    isLoading.value = true;
    try {
      final userId = SessionManager.currentUserId;
      if (userId == null) return;
      final rows = await _db.safeRead(
        'users',
        where: 'user_id = ?',
        whereArgs: [userId],
      );
      if (rows.isNotEmpty) {
        currentUser.value = rows.first;
      }
    } catch (e) {
      debugPrint('loadProfile error: $e');
    } finally {
      isLoading.value = false;
    }
  }

  Future<bool> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      final userId = SessionManager.currentUserId;
      if (userId == null) return false;

      // جلب المستخدم والتحقق من كلمة المرور الحالية
      final rows = await _db.safeRead(
        'users',
        where: 'user_id = ?',
        whereArgs: [userId],
      );

      if (rows.isEmpty) {
        Get.snackbar('خطأ', 'المستخدم غير موجود',
            snackPosition: SnackPosition.BOTTOM);
        return false;
      }

      final storedHash = rows.first['password_hash']?.toString() ?? '';
      final isCorrect = SecurityService.verifyPassword(currentPassword, storedHash);

      if (!isCorrect) {
        Get.snackbar('خطأ', 'كلمة المرور الحالية غير صحيحة',
            snackPosition: SnackPosition.BOTTOM);
        return false;
      }

      final newHash = SecurityService.hashPassword(newPassword);
      await _db.safeUpdate(
        'users',
        {'password_hash': newHash},
        where: 'user_id = ?',
        whereArgs: [userId],
      );

      await _db.logAudit(
        userId: userId,
        action: 'password_change',
        tableName: 'users',
        recordId: userId,
      );

      Get.snackbar('نجاح', 'تم تغيير كلمة المرور بنجاح',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: const Color(0xFF16A34A),
          colorText: Colors.white);
      return true;
    } catch (e) {
      debugPrint('changePassword error: $e');
      Get.snackbar('خطأ', 'فشل في تغيير كلمة المرور: $e',
          snackPosition: SnackPosition.BOTTOM);
      return false;
    }
  }

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
