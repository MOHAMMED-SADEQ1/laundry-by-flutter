import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:laundry/controller/splashcontroller.dart';
import 'package:laundry/core/theme/app_colors.dart';
import 'package:laundry/services/business_info_service.dart';
import 'package:laundry/services/i18n/l10n.dart';
import 'package:laundry/view/widget/common/developer_credit.dart';

class SplashScreen extends StatelessWidget {
  SplashScreen({super.key});
  final SplashController controller = Get.put(SplashController());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.darkGradient),
        child: Stack(
          children: [
            // زخارف خلفية ناعمة
            Positioned(
              top: -80,
              left: -80,
              child: Container(
                width: 260,
                height: 260,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.05),
                ),
              ),
            ),
            Positioned(
              bottom: -100,
              right: -60,
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF0D9488).withValues(alpha: 0.15),
                ),
              ),
            ),
            Positioned(
              top: 120,
              right: -40,
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.04),
                ),
              ),
            ),

            Center(
              child: Obx(
                () => AnimatedOpacity(
                  duration: const Duration(milliseconds: 900),
                  opacity: controller.opacity.value,
                  child: AnimatedScale(
                    duration: const Duration(milliseconds: 900),
                    curve: Curves.easeOutBack,
                    scale: controller.scale.value,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 110,
                          height: 110,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.3),
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.2),
                                blurRadius: 30,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.local_laundry_service,
                            color: Colors.white,
                            size: 56,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          BusinessInfoService.instance.name.isNotEmpty
                              ? BusinessInfoService.instance.name
                              : tr('نظام إدارة المغاسل'),
                          style: TextStyle(
                            fontSize: 42,
                            color: Colors.white,
                            fontFamily: 'DTHULUTH',
                            fontWeight: FontWeight.bold,
                            shadows: [
                              Shadow(
                                color: Colors.black38,
                                blurRadius: 12,
                                offset: Offset(0, 3),
                              ),
                            ],
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          tr('نظام إدارة المغاسل الذكي'),
                          style: TextStyle(
                            fontSize: 15,
                            color: Colors.white.withValues(alpha: 0.8),
                            fontFamily: 'cairo',
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        // حقوق المطوّر — تظهر أسفل شعار النظام عند كل فتح للتطبيق
                        const SizedBox(height: 6),
                        const DeveloperCredit(onDark: true, fontSize: 12),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // مؤشر تحميل سفلي
            Positioned(
              bottom: 50,
              left: 0,
              right: 0,
              child: Obx(
                () => AnimatedOpacity(
                  duration: const Duration(milliseconds: 400),
                  opacity: controller.opacity.value,
                  child: Center(
                    child: SizedBox(
                      width: 26,
                      height: 26,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white.withValues(alpha: 0.9),
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
}
