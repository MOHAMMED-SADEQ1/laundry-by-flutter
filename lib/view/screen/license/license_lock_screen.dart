import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:laundry/config/app_info.dart';
import 'package:laundry/core/theme/app_colors.dart';
import 'package:laundry/services/business_info_service.dart';
import 'package:laundry/services/i18n/l10n.dart';
import 'package:laundry/services/license/system_license_service.dart';
import 'package:laundry/view/widget/license/license_renew_dialog.dart';
import 'package:laundry/services/i18n/ui_direction.dart';

/// شاشة القفل الكاملة عند انتهاء اشتراك النظام.
///
/// **تُعرض فوق كل المسارات** من بوابة `MyApp.builder`، فلا يمكن الوصول
/// لفواتير أو تقارير أو إعدادات أو حتى تسجيل الدخول قبل التجديد. وهي تحوي
/// **مسار التجديد الوحيد**: زر يطلب بيانات مدير النظام ثم يحدّد التاريخ.
class LicenseLockScreen extends StatelessWidget {
  const LicenseLockScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final license = Get.find<SystemLicenseController>();
    final bizName = BusinessInfoService.instance.name;

    return Directionality(
      textDirection: appTextDirection,
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(gradient: AppColors.darkGradient),
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Obx(() {
                  final expiry = license.expiryDate;
                  final tampered = license.clockTampered;
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 92,
                        height: 92,
                        decoration: BoxDecoration(
                          color: AppColors.danger.withValues(alpha: 0.16),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.danger.withValues(alpha: 0.5),
                            width: 2,
                          ),
                        ),
                        child: Icon(
                          tampered ? Icons.hourglass_disabled : Icons.lock_clock,
                          size: 42,
                          color: AppColors.danger,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        bizName.isNotEmpty
                            ? bizName
                            : tr('نظام إدارة المغاسل'),
                        style: const TextStyle(
                          fontFamily: 'cairo',
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        tampered
                            ? tr('تعذّر التحقق من صحة تاريخ الجهاز')
                            : tr('انتهى اشتراك النظام'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontFamily: 'cairo',
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        tampered
                            ? tr(
                                'تاريخ الجهاز يسبق آخر تشغيل مسجّل للنظام. اضبط تاريخ الجهاز بشكل صحيح، أو جدّد الاشتراك كمدير النظام لإعادة ضبط التحقق.',
                              )
                            : tr(
                                'للاستمرار في استخدام النظام، يلزم تجديد الاشتراك.',
                              ),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'cairo',
                          fontSize: 13.5,
                          height: 1.6,
                          color: Colors.white.withValues(alpha: 0.75),
                        ),
                      ),
                      if (expiry != null) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.07),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.16),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.event_busy_outlined,
                                size: 18,
                                color: Colors.white70,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                trf('تاريخ الانتهاء: {0}', [
                                  SystemLicenseController.formatDate(expiry),
                                ]),
                                style: const TextStyle(
                                  fontFamily: 'cairo',
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 26),
                      SizedBox(
                        width: 260,
                        child: ElevatedButton.icon(
                          onPressed: () => showLicenseRenewDialog(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: const Icon(Icons.key_outlined),
                          label: Text(
                            tr('تجديد الاشتراك'),
                            style: const TextStyle(
                              fontFamily: 'cairo',
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        AppInfo.developerCredit,
                        style: TextStyle(
                          fontFamily: 'cairo',
                          fontSize: 11,
                          color: Colors.white.withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  );
                }),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
