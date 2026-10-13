import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:laundry/controller/profile_controller.dart';
import 'package:laundry/core/theme/app_colors.dart';
import 'package:laundry/view/widget/common/developer_credit.dart';
import 'package:laundry/view/widget/customappbar.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late final ProfileController controller;

  @override
  void initState() {
    super.initState();
    controller = Get.put(ProfileController());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppbar(title: 'الملف الشخصي'),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [const Color(0xFFF8FAFC), AppColors.background],
          ),
        ),
        child: Obx(() {
          if (controller.isLoading.value) {
            return const Center(child: CircularProgressIndicator());
          }
          final user = controller.currentUser.value;
          if (user == null) {
            return const Center(
              child: Text('لا توجد بيانات',
                  style: TextStyle(fontFamily: 'cairo')),
            );
          }
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              // ─── صورة المستخدم ───
              Center(
                child: Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    color: ProfileController.roleColor(user['role'] ?? '')
                        .withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.person,
                    size: 48,
                    color: ProfileController.roleColor(user['role'] ?? ''),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // الاسم
              Center(
                child: Text(
                  user['full_name']?.toString().isNotEmpty == true
                      ? user['full_name']
                      : user['username'],
                  style: const TextStyle(
                    fontFamily: 'cairo',
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              // اسم المستخدم + الدور
              Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '@${user['username']}',
                      style: TextStyle(
                        fontFamily: 'cairo',
                        fontSize: 14,
                        color: AppColors.textMuted,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: ProfileController.roleColor(user['role'] ?? '')
                            .withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        ProfileController.roleLabel(user['role'] ?? ''),
                        style: TextStyle(
                          fontFamily: 'cairo',
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: ProfileController.roleColor(user['role'] ?? ''),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),
              // ─── تغيير كلمة المرور ───
              Card(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.lock_outline,
                              color: AppColors.primary, size: 22),
                          const SizedBox(width: 8),
                          const Text(
                            'تغيير كلمة المرور',
                            style: TextStyle(
                              fontFamily: 'cairo',
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _PasswordField(
                        label: 'كلمة المرور الحالية',
                        icon: Icons.lock,
                      ),
                      const SizedBox(height: 12),
                      _PasswordField(
                        label: 'كلمة المرور الجديدة',
                        icon: Icons.lock_reset,
                      ),
                      const SizedBox(height: 12),
                      _PasswordField(
                        label: 'تأكيد كلمة المرور الجديدة',
                        icon: Icons.lock_reset,
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () => _changePassword(context),
                          icon: const Icon(Icons.save, color: Colors.white),
                          label: const Text(
                            'حفظ كلمة المرور',
                            style: TextStyle(
                              fontFamily: 'cairo',
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // حقوق المطوّر — نهاية شاشة الملف الشخصي
              const DeveloperCredit(
                fontSize: 12,
                padding: EdgeInsets.only(top: 6, bottom: 12),
              ),
            ],
          );
        }),
      ),
    );
  }

  Future<void> _changePassword(BuildContext context) async {
    final currentCtrl = _currentPasswordCtrl;
    final newCtrl = _newPasswordCtrl;
    final confirmCtrl = _confirmPasswordCtrl;

    if (currentCtrl.text.isEmpty ||
        newCtrl.text.isEmpty ||
        confirmCtrl.text.isEmpty) {
      Get.snackbar('خطأ', 'أدخل جميع كلمات المرور',
          snackPosition: SnackPosition.BOTTOM);
      return;
    }

    if (newCtrl.text != confirmCtrl.text) {
      Get.snackbar('خطأ', 'كلمة المرور الجديدة غير متطابقة',
          snackPosition: SnackPosition.BOTTOM);
      return;
    }

    final success = await controller.changePassword(
      currentPassword: currentCtrl.text.trim(),
      newPassword: newCtrl.text.trim(),
    );

    if (success) {
      currentCtrl.clear();
      newCtrl.clear();
      confirmCtrl.clear();
    }
  }

  // Storage for text controllers
  final _currentPasswordCtrl = TextEditingController();
  final _newPasswordCtrl = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController();

  @override
  void dispose() {
    _currentPasswordCtrl.dispose();
    _newPasswordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    super.dispose();
  }
}

class _PasswordField extends StatefulWidget {
  final String label;
  final IconData icon;

  const _PasswordField({required this.label, required this.icon});

  @override
  State<_PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<_PasswordField> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _getController(context),
      obscureText: _obscure,
      decoration: InputDecoration(
        labelText: widget.label,
        labelStyle: const TextStyle(fontFamily: 'cairo'),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        prefixIcon: Icon(widget.icon),
        suffixIcon: IconButton(
          icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
          onPressed: () => setState(() => _obscure = !_obscure),
        ),
      ),
      style: const TextStyle(fontFamily: 'cairo'),
    );
  }

  TextEditingController _getController(BuildContext context) {
    // Access parent's controllers through inheritance
    final state = context.findAncestorStateOfType<_ProfileScreenState>();
    if (state == null) return TextEditingController();
    if (widget.label.contains('الحالية')) return state._currentPasswordCtrl;
    if (widget.label.contains('جديدة') && !widget.label.contains('تأكيد')) {
      return state._newPasswordCtrl;
    }
    return state._confirmPasswordCtrl;
  }
}
