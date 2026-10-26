import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:laundry/controller/auth/auth_controller.dart';
import 'package:laundry/config/app_info.dart';
import 'package:laundry/core/theme/app_colors.dart';
import 'package:laundry/services/business_info_service.dart';
import 'package:laundry/services/i18n/l10n.dart';
import 'package:laundry/view/widget/common/animation_wrappers.dart';
import 'package:laundry/view/widget/common/developer_credit.dart';
import 'package:laundry/services/i18n/ui_direction.dart';

class LoginScreen extends StatelessWidget {
  LoginScreen({super.key});
  final AuthController controller = Get.find<AuthController>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.primaryDark,
              AppColors.primary,
              Color(0xFF0D9488),
            ],
          ),
        ),
        child: Stack(
          children: [
            // زخارف خلفية
            Positioned(
              top: -60,
              right: -60,
              child: _decorationCircle(
                260,
                Colors.white.withValues(alpha: 0.06),
              ),
            ),
            Positioned(
              bottom: -80,
              left: -40,
              child: _decorationCircle(
                300,
                Colors.white.withValues(alpha: 0.05),
              ),
            ),
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: FadeInUp(
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(28, 32, 28, 28),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.25),
                            blurRadius: 40,
                            offset: const Offset(0, 16),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // الشعار — الضغط عليه يفتح نافذة «عن النظام»
                          GestureDetector(
                            onTap: showAboutAppDialog,
                            child: Container(
                              width: 84,
                              height: 84,
                              decoration: BoxDecoration(
                                gradient: AppColors.primaryGradient,
                                shape: BoxShape.circle,
                                boxShadow: AppColors.softShadow(blur: 18, y: 6),
                              ),
                              child: const Icon(
                                Icons.local_laundry_service,
                                size: 42,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            BusinessInfoService.instance.name.isNotEmpty
                                ? BusinessInfoService.instance.name
                                : tr('نظام إدارة المغاسل'),
                            style: TextStyle(
                              fontSize: 26,
                              fontFamily: 'DTHULUTH',
                              color: AppColors.primaryDark,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            tr('تسجيل الدخول إلى النظام'),
                            style: TextStyle(
                              fontSize: 13,
                              fontFamily: 'cairo',
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 28),

                          // اسم المستخدم
                          TextFormField(
                            decoration: InputDecoration(
                              labelText: tr('اسم المستخدم'),
                              hintText: tr('أدخل اسم المستخدم'),
                              prefixIcon: const Icon(Icons.person_outline),
                            ),
                            textDirection: appTextDirection,
                            onChanged:
                                (value) => controller.username.value = value,
                          ),
                          const SizedBox(height: 16),

                          // كلمة المرور
                          Obx(
                            () => TextFormField(
                              obscureText: !controller.showPassword.value,
                              decoration: InputDecoration(
                                labelText: tr('كلمة المرور'),
                                hintText: tr('أدخل كلمة المرور'),
                                prefixIcon: const Icon(Icons.lock_outline),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    controller.showPassword.value
                                        ? Icons.visibility_outlined
                                        : Icons.visibility_off_outlined,
                                  ),
                                  onPressed:
                                      controller.togglePasswordVisibility,
                                ),
                              ),
                              textDirection: appTextDirection,
                              onChanged:
                                  (value) => controller.password.value = value,
                            ),
                          ),
                          const SizedBox(height: 28),

                          // زر الدخول
                          Obx(
                            () => SizedBox(
                              width: double.infinity,
                              height: 52,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  textStyle: const TextStyle(
                                    fontFamily: 'cairo',
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                onPressed:
                                    controller.isLoading.value
                                        ? null
                                        : controller.login,
                                child:
                                    controller.isLoading.value
                                        ? const SizedBox(
                                          width: 24,
                                          height: 24,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2.5,
                                            color: Colors.white,
                                          ),
                                        )
                                        : Text(tr('تسجيل الدخول')),
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            trf('نظام إدارة المغاسل — الإصدار {0}', [
                              AppInfo.version,
                            ]),
                            style: TextStyle(
                              fontSize: 11,
                              fontFamily: 'cairo',
                              color: AppColors.textMuted,
                            ),
                          ),
                          // حقوق المطوّر — أسفل بطاقة تسجيل الدخول
                          const SizedBox(height: 10),
                          const DeveloperCredit(fontSize: 11.5),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _decorationCircle(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }
}
