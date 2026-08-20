import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:laundry/controller/settings/settings_controller.dart';
import 'package:laundry/controller/settings/theme_controller.dart';
import 'package:laundry/core/theme/app_colors.dart';
import 'package:laundry/view/widget/common/animation_wrappers.dart';
import 'package:laundry/view/widget/common/common_widgets.dart';
import 'package:laundry/view/widget/customappbar.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(SettingsController());
    controller.loadSettings();

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: CustomAppbar(
          title: 'الإعدادات',
          subtitle: 'إعدادات النظام والنشاط التجاري',
        ),
        body: Obx(() {
          if (controller.isLoading.value && controller.settings.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          return ListView(
            padding: const EdgeInsets.all(14),
            children: [
              FadeInUp(child: _businessInfoCard(controller)),
              const SizedBox(height: 14),
              FadeInUp(delayMs: 80, child: _backupSection(controller)),
              const SizedBox(height: 14),
              FadeInUp(delayMs: 160, child: _appearanceSection(controller)),
              const SizedBox(height: 14),
              FadeInUp(delayMs: 240, child: _aboutSection()),
              const SizedBox(height: 20),
            ],
          );
        }),
      ),
    );
  }

  Widget _businessInfoCard(SettingsController controller) {
    final nameCtrl = TextEditingController(
      text: controller.settings['business_name'] ?? '',
    );
    final phoneCtrl = TextEditingController(
      text: controller.settings['business_phone'] ?? '',
    );
    final addressCtrl = TextEditingController(
      text: controller.settings['business_address'] ?? '',
    );

    return SoftCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(
            title: 'معلومات النشاط التجاري',
            icon: Icons.business_outlined,
          ),
          const SizedBox(height: 14),
          TextField(
            controller: nameCtrl,
            decoration: const InputDecoration(
              labelText: 'اسم النشاط',
              prefixIcon: Icon(Icons.storefront_outlined),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: phoneCtrl,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'رقم الهاتف',
              prefixIcon: Icon(Icons.phone_outlined),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: addressCtrl,
            decoration: const InputDecoration(
              labelText: 'العنوان',
              prefixIcon: Icon(Icons.location_on_outlined),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                controller.updateSetting('business_name', nameCtrl.text);
                controller.updateSetting('business_phone', phoneCtrl.text);
                controller.updateSetting('business_address', addressCtrl.text);
              },
              icon: const Icon(Icons.save_outlined),
              label: const Text(
                'حفظ المعلومات',
                style: TextStyle(fontFamily: 'cairo'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _backupSection(SettingsController controller) {
    return SoftCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(
            title: 'النسخ الاحتياطي',
            icon: Icons.backup_outlined,
          ),
          const SizedBox(height: 10),
          _SettingTile(
            icon: Icons.backup,
            iconColor: AppColors.success,
            title: 'إنشاء نسخة احتياطية',
            subtitle: 'حفظ نسخة كاملة من قاعدة البيانات',
            onTap: () async {
              final success = await controller.exportData();
              Get.snackbar(
                success ? 'نجاح' : 'خطأ',
                success
                    ? 'تم إنشاء النسخة الاحتياطية بنجاح'
                    : 'فشل في إنشاء النسخة الاحتياطية',
                snackPosition: SnackPosition.BOTTOM,
                backgroundColor: success ? AppColors.success : AppColors.danger,
                colorText: Colors.white,
              );
            },
          ),
          const Divider(height: 20),
          _SettingTile(
            icon: Icons.restore,
            iconColor: AppColors.warning,
            title: 'استعادة من نسخة احتياطية',
            subtitle: 'استعادة البيانات من نسخة محفوظة',
            onTap: () {
              Get.snackbar(
                'ملاحظة',
                'ميزة الاستعادة قيد التطوير',
                snackPosition: SnackPosition.BOTTOM,
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _appearanceSection(SettingsController controller) {
    final theme = ThemeController.instance;

    return SoftCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: 'المظهر', icon: Icons.brush_outlined),
          const SizedBox(height: 10),
          Obx(() {
            final fontSize =
                theme.fontScale.value * ThemeController.baseFontSize;
            return Column(
              children: [
                Row(
                  children: [
                    const Icon(Icons.text_fields, color: AppColors.secondary),
                    const SizedBox(width: 10),
                    const Text(
                      'حجم الخط',
                      style: TextStyle(
                        fontFamily: 'cairo',
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        fontSize.toStringAsFixed(0),
                        style: const TextStyle(
                          fontFamily: 'cairo',
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
                Slider(
                  value: fontSize,
                  min: 10,
                  max: 24,
                  divisions: 14,
                  label: fontSize.toStringAsFixed(0),
                  activeColor: AppColors.secondary,
                  onChanged: (val) {
                    theme.setFontSize(val);
                  },
                ),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _aboutSection() {
    return SoftCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              shape: BoxShape.circle,
              boxShadow: AppColors.softShadow(blur: 14, y: 5),
            ),
            child: const Icon(
              Icons.local_laundry_service,
              size: 34,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'مغاسل النظارة',
            style: TextStyle(
              fontFamily: 'cairo',
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'الإصدار 1.2.0',
            style: TextStyle(
              fontFamily: 'cairo',
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'نظام إدارة المغاسل الشامل — تصميم عصري وتجربة سلسة',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'cairo',
              fontSize: 12,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _SettingTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        padding: const EdgeInsets.all(9),
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: iconColor, size: 22),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontFamily: 'cairo',
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontFamily: 'cairo',
          fontSize: 11.5,
          color: AppColors.textSecondary,
        ),
      ),
      trailing: Icon(Icons.chevron_left, color: AppColors.textMuted),
      onTap: onTap,
    );
  }
}
