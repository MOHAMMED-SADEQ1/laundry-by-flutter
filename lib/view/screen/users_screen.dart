import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:laundry/controller/users/users_controller.dart';
import 'package:laundry/core/navigation/route_dismissal.dart';
import 'package:laundry/core/theme/app_colors.dart';
import 'package:laundry/services/i18n/l10n.dart';
import 'package:laundry/services/permission/permission_catalog.dart';
import 'package:laundry/services/permission/permission_service.dart';
import 'package:laundry/services/security/session_manager.dart';
import 'package:laundry/view/screen/users/user_permissions_sheet.dart';
import 'package:laundry/view/widget/common/app_dialog.dart';
import 'package:laundry/view/widget/customappbar.dart';

class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key});

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  late final UsersController controller;

  @override
  void initState() {
    super.initState();
    controller = Get.put(UsersController());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppbar(
        title: tr('إدارة المستخدمين'),
        subtitle: tr('إضافة وتعديل وحذف المستخدمين'),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [const Color(0xFFF8FAFC), AppColors.background],
          ),
        ),
        child: Column(
          children: [
            // زر الإضافة
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _showAddDialog(context),
                  icon: const Icon(Icons.person_add, color: Colors.white),
                  label: Text(
                    tr('إضافة مستخدم جديد'),
                    style: const TextStyle(
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
            ),
            // قائمة المستخدمين
            Expanded(
              child: Obx(() {
                if (controller.isLoading.value) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (controller.users.isEmpty) {
                  return Center(
                    child: Text(
                      tr('لا يوجد مستخدمين'),
                      style: const TextStyle(
                        fontFamily: 'cairo',
                        fontSize: 16,
                      ),
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: controller.users.length,
                  itemBuilder: (context, index) {
                    final user = controller.users[index];
                    return _UserCard(user: user, controller: controller);
                  },
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    final usernameCtrl = TextEditingController();
    final passwordCtrl = TextEditingController();
    String selectedRole = 'cashier';
    bool saving = false;
    StateSetter? dialogSetState;

    Get.defaultDialog(
      title: tr('إضافة مستخدم جديد'),
      titleStyle: const TextStyle(
        fontFamily: 'cairo',
        fontWeight: FontWeight.bold,
        fontSize: 18,
      ),
      content: StatefulBuilder(
        builder: (context, setState) {
          dialogSetState = setState;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildTextField(nameCtrl, tr('الاسم الكامل'), Icons.person),
                const SizedBox(height: 12),
                _buildTextField(
                  usernameCtrl,
                  tr('اسم المستخدم'),
                  Icons.account_circle,
                ),
                const SizedBox(height: 12),
                _buildTextField(
                  passwordCtrl,
                  tr('كلمة المرور'),
                  Icons.lock,
                  obscure: true,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: selectedRole,
                  decoration: InputDecoration(
                    labelText: tr('الدور'),
                    labelStyle: const TextStyle(fontFamily: 'cairo'),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    prefixIcon: const Icon(Icons.work),
                  ),
                  // الأدوار من القاعدة لا مكتوبة: أي دور جديد يظهر هنا فورًا.
                  items: [
                    for (final r in controller.roleOptions)
                      DropdownMenuItem(
                        value: r.name,
                        child: Text(r.label,
                            style: const TextStyle(fontFamily: 'cairo')),
                      ),
                  ],
                  onChanged: (value) {
                    setState(() => selectedRole = value!);
                  },
                ),
                if (saving) ...[
                  const SizedBox(height: 12),
                  const LinearProgressIndicator(minHeight: 3),
                ],
              ],
            ),
          );
        },
      ),
      textConfirm: tr('إضافة'),
      textCancel: tr('إلغاء'),
      confirmTextColor: Colors.white,
      buttonColor: AppColors.primary,
      onConfirm: () async {
        if (saving) return;
        if (nameCtrl.text.isEmpty || usernameCtrl.text.isEmpty || passwordCtrl.text.isEmpty) {
          Get.snackbar(tr('خطأ'), tr('أدخل جميع البيانات المطلوبة'),
              snackPosition: SnackPosition.BOTTOM);
          return;
        }
        saving = true;
        dialogSetState?.call(() {});
        final success = await controller.addUser(
          fullName: nameCtrl.text.trim(),
          username: usernameCtrl.text.trim(),
          password: passwordCtrl.text.trim(),
          role: selectedRole,
        );
        if (success) {
          // `Get.back()` يغلق رسالة النجاح بدل الحوار، فنغلق المسار مباشرة.
          dismissOpenDialog();
        } else {
          saving = false;
          dialogSetState?.call(() {});
        }
      },
    );
  }

  static Widget _buildTextField(
      TextEditingController ctrl, String label, IconData icon,
      {bool obscure = false}) {
    return TextField(
      controller: ctrl,
      obscureText: obscure,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontFamily: 'cairo'),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        prefixIcon: Icon(icon),
      ),
      style: const TextStyle(fontFamily: 'cairo'),
    );
  }
}

class _UserCard extends StatelessWidget {
  final Map<String, dynamic> user;
  final UsersController controller;

  const _UserCard({required this.user, required this.controller});

  @override
  Widget build(BuildContext context) {
    final isActive = (user['is_active'] ?? 1) == 1;
    final role = user['role'] ?? 'cashier';
    final fullName = user['full_name']?.toString().isNotEmpty == true
        ? user['full_name']
        : user['username'];

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: isActive ? 2 : 0.5,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: isActive ? Colors.white : Colors.grey.shade50,
        ),
        child: Row(
          children: [
            // الأيقونة
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: UsersController.roleColor(role).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.person,
                color: UsersController.roleColor(role),
                size: 26,
              ),
            ),
            const SizedBox(width: 12),
            // المعلومات
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$fullName',
                    style: TextStyle(
                      fontFamily: 'cairo',
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: isActive ? AppColors.textPrimary : Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(
                        '@${user['username']}',
                        style: TextStyle(
                          fontFamily: 'cairo',
                          fontSize: 12,
                          color: AppColors.textMuted,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: UsersController.roleColor(role)
                              .withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          controller.labelForRole(role),
                          style: TextStyle(
                            fontFamily: 'cairo',
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: UsersController.roleColor(role),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // الأزرار
            PopupMenuButton<String>(
              icon: Icon(
                Icons.more_vert,
                color: AppColors.textMuted,
              ),
              onSelected: (value) => _handleMenu(value, context),
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'edit',
                  child: ListTile(
                    leading: const Icon(Icons.edit, size: 20),
                    title: Text(
                      tr('تعديل'),
                      style: const TextStyle(fontFamily: 'cairo'),
                    ),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                // 🛡️ الصلاحيات: تظهر لمن يملك إدارة الأدوار — لأن تعديل
                // تجاوز فردي هو تعديل صلاحية، لا تعديل بيانات حساب.
                if (PermissionService.can(PermissionKeys.rolesManage))
                  PopupMenuItem(
                    value: 'permissions',
                    child: ListTile(
                      leading: const Icon(Icons.shield_outlined, size: 20),
                      title: Text(
                        tr('الصلاحيات'),
                        style: const TextStyle(fontFamily: 'cairo'),
                      ),
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                if (user['user_id'] != SessionManager.currentUserId)
                  PopupMenuItem(
                    value: 'delete',
                    child: ListTile(
                      leading:
                          const Icon(Icons.delete, size: 20, color: Colors.red),
                      title: Text(
                        tr('حذف'),
                        style: const TextStyle(
                          fontFamily: 'cairo',
                          color: Colors.red,
                        ),
                      ),
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _handleMenu(String value, BuildContext context) {
    if (value == 'edit') {
      _showEditDialog(context);
    } else if (value == 'permissions') {
      Get.bottomSheet(
        UserPermissionsSheet(
          userId: user['user_id'] as int,
          userName: user['full_name']?.toString().isNotEmpty == true
              ? user['full_name'].toString()
              : user['username'].toString(),
          role: user['role']?.toString() ?? 'cashier',
          controller: controller,
        ),
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
      );
    } else if (value == 'delete') {
      _showDeleteDialog(context);
    }
  }

  void _showEditDialog(BuildContext context) {
    final nameCtrl = TextEditingController(text: user['full_name']?.toString() ?? '');
    final usernameCtrl = TextEditingController(text: user['username']?.toString() ?? '');
    final passwordCtrl = TextEditingController();
    String selectedRole = user['role'] ?? 'cashier';
    bool isActive = (user['is_active'] ?? 1) == 1;
    bool saving = false;
    StateSetter? dialogSetState;

    Get.defaultDialog(
      title: tr('تعديل المستخدم'),
      titleStyle: const TextStyle(
        fontFamily: 'cairo',
        fontWeight: FontWeight.bold,
        fontSize: 18,
      ),
      content: StatefulBuilder(
        builder: (context, setState) {
          dialogSetState = setState;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildTextField(nameCtrl, tr('الاسم الكامل'), Icons.person),
                const SizedBox(height: 12),
                _buildTextField(
                  usernameCtrl,
                  tr('اسم المستخدم'),
                  Icons.account_circle,
                ),
                const SizedBox(height: 12),
                _buildTextField(
                  passwordCtrl,
                  tr('كلمة المرور الجديدة (اتركها فارغة)'),
                  Icons.lock,
                  obscure: true,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: selectedRole,
                  decoration: InputDecoration(
                    labelText: tr('الدور'),
                    labelStyle: const TextStyle(fontFamily: 'cairo'),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    prefixIcon: const Icon(Icons.work),
                  ),
                  // الأدوار من القاعدة لا مكتوبة — نفس مصدر منتقي الإضافة.
                  items: [
                    for (final r in controller.roleOptions)
                      DropdownMenuItem(
                        value: r.name,
                        child: Text(r.label,
                            style: const TextStyle(fontFamily: 'cairo')),
                      ),
                  ],
                  onChanged: (value) {
                    setState(() => selectedRole = value!);
                  },
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Text(
                      tr('نشط:'),
                      style: const TextStyle(fontFamily: 'cairo'),
                    ),
                    const Spacer(),
                    Switch(
                      value: isActive,
                      onChanged: (val) => setState(() => isActive = val),
                      activeThumbColor: AppColors.primary,
                    ),
                  ],
                ),
                if (saving) ...[
                  const SizedBox(height: 12),
                  const LinearProgressIndicator(minHeight: 3),
                ],
              ],
            ),
          );
        },
      ),
      textConfirm: tr('حفظ'),
      textCancel: tr('إلغاء'),
      confirmTextColor: Colors.white,
      buttonColor: AppColors.primary,
      onConfirm: () async {
        if (saving) return;
        if (nameCtrl.text.isEmpty || usernameCtrl.text.isEmpty) {
          Get.snackbar(tr('خطأ'), tr('أدخل البيانات المطلوبة'),
              snackPosition: SnackPosition.BOTTOM);
          return;
        }
        saving = true;
        dialogSetState?.call(() {});
        final success = await controller.updateUser(
          userId: user['user_id'],
          fullName: nameCtrl.text.trim(),
          username: usernameCtrl.text.trim(),
          newPassword: passwordCtrl.text.isNotEmpty ? passwordCtrl.text.trim() : null,
          role: selectedRole,
          isActive: isActive,
        );
        if (success) {
          dismissOpenDialog();
        } else {
          saving = false;
          dialogSetState?.call(() {});
        }
      },
    );
  }

  Future<void> _showDeleteDialog(BuildContext context) async {
    final name = user['full_name']?.toString() ??
        user['username']?.toString() ??
        '';
    // حوار تأكيد موحّد يغلق نفسه بنفسه، ثم ينفّذ الحذف — فلا يبقى معلّقًا
    // إذا كانت رسالة snackbar سابقة معروضة.
    final confirmed = await showConfirmDialog(
      title: tr('حذف المستخدم'),
      message: trf('هل أنت متأكد من حذف "{0}"؟', [name]),
      confirmText: tr('حذف'),
    );
    if (confirmed != true) return;
    await controller.deleteUser(user['user_id'], name);
  }

  static Widget _buildTextField(
      TextEditingController ctrl, String label, IconData icon,
      {bool obscure = false}) {
    return TextField(
      controller: ctrl,
      obscureText: obscure,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontFamily: 'cairo'),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        prefixIcon: Icon(icon),
      ),
      style: const TextStyle(fontFamily: 'cairo'),
    );
  }
}
