import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:laundry/config/constants.dart';
import 'package:laundry/core/theme/app_colors.dart';
import 'package:laundry/services/i18n/l10n.dart';
import 'package:laundry/services/license/system_license_service.dart';
import 'package:laundry/view/widget/license/license_renew_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:laundry/services/i18n/ui_direction.dart';

/// إشعار «قرب انتهاء الاشتراك» عند الدخول، مع **زر تجديد مباشر**.
///
/// **لماذا إشعار منفصل عن اللافتة العلوية؟** اللافتة (`LicenseWarningBar`)
/// تُعرض أثناء العمل وهي سلبية يسهل تجاهلها؛ هذا الإشعار يوقف المستخدم مرة
/// واحدة عند بدء استخدامه للنظام، ويضع أمامه زر التجديد فورًا — قبل أن
/// يُفاجأ بالقفل.
///
/// **مرة واحدة في اليوم**: يُسجَّل يوم العرض في
/// [AppConstants.spLicenseNoticeDate]. فلا يُقاطع الكاشير مع كل دخول/خروج
/// في الوردية نفسها. أما اللافتة العلوية فتبقى ظاهرة دائمًا خلال المدة.
///
/// **لا يُعرض أبدًا**: إن لم يكن هناك تاريخ انتهاء (غير محدود)، أو إن كان النظام
/// سارٍ بعيدًا عن الانتهاء، أو إن كان **مقفلًا** (فشاشة القفل تتولّى الأمر
/// ومسارها الخاص أظهر للعميل).
Future<void> showLicenseExpiryNoticeIfDue() async {
  // بعد الإطار الحالي: يُستدعى مباشرةً إثر `Get.offNamed`، فلا نبني حوارًا
  // فوق شجرة قيد التبديل.
  WidgetsBinding.instance.addPostFrameCallback((_) async {
    try {
      if (!Get.isRegistered<SystemLicenseController>()) return;
      final license = Get.find<SystemLicenseController>();

      // لا قفل هنا: النظام المقفل له شاشته، ولا معنى لإشعار فوقه.
      if (license.isLocked || !license.isExpiringSoon) return;

      final today = SystemLicenseController.formatDate(DateTime.now());
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getString(AppConstants.spLicenseNoticeDate) == today) return;
      await prefs.setString(AppConstants.spLicenseNoticeDate, today);

      await Get.dialog<void>(
        const _LicenseExpiryNoticeDialog(),
        barrierDismissible: true,
      );
    } catch (e) {
      debugPrint('license expiry notice skipped: $e');
    }
  });
}

class _LicenseExpiryNoticeDialog extends StatelessWidget {
  const _LicenseExpiryNoticeDialog();

  @override
  Widget build(BuildContext context) {
    final license = Get.find<SystemLicenseController>();
    final expiry = license.expiryDate;
    final urgent = (license.daysRemaining ?? 99) <= 1;

    return Directionality(
      textDirection: appTextDirection,
      child: AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: [
            Icon(
              urgent ? Icons.error_outline : Icons.notifications_active_outlined,
              color: urgent ? AppColors.danger : AppColors.warning,
            ),
            const SizedBox(width: 8),
            Text(
              tr('تنبيه: اشتراك النظام'),
              style: const TextStyle(
                fontFamily: 'cairo',
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              license.statusLabel,
              style: TextStyle(
                fontFamily: 'cairo',
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: urgent ? AppColors.danger : AppColors.warning,
              ),
            ),
            if (expiry != null) ...[
              const SizedBox(height: 6),
              Text(
                trf('تاريخ الانتهاء: {0}', [
                  SystemLicenseController.formatDate(expiry),
                ]),
                style: TextStyle(
                  fontFamily: 'cairo',
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
            const SizedBox(height: 10),
            Text(
              tr(
                'جدّد الاشتراك الآن لتفادي توقّف النظام. يتطلب التجديد بيانات مدير النظام (admin).',
              ),
              style: TextStyle(
                fontFamily: 'cairo',
                fontSize: 12.5,
                height: 1.5,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back<void>(),
            child: Text(
              tr('لاحقًا'),
              style: const TextStyle(fontFamily: 'cairo'),
            ),
          ),
          ElevatedButton.icon(
            onPressed: () {
              // نلتقط سياق الـNavigator **قبل** إغلاق الإشعار: سياق الحوار
              // نفسه يصبح غير صالح بعده، وتمريره لـ`showDialog` يرمي
              // «Looking up a deactivated widget's ancestor».
              final navContext = Navigator.of(
                context,
                rootNavigator: true,
              ).context;
              Get.back<void>();
              showLicenseRenewDialog(navContext);
            },
            icon: const Icon(Icons.key_outlined, size: 18),
            label: Text(
              tr('تجديد الآن'),
              style: const TextStyle(fontFamily: 'cairo'),
            ),
          ),
        ],
      ),
    );
  }
}
