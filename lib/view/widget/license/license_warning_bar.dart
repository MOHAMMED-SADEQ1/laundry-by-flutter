import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:laundry/core/theme/app_colors.dart';
import 'package:laundry/services/i18n/l10n.dart';
import 'package:laundry/services/license/system_license_service.dart';
import 'package:laundry/view/widget/license/license_renew_dialog.dart';

/// لافتة تحذير قبل انتهاء اشتراك النظام (`licenseWarnDays` أيام).
///
/// تُعرض أعلى النظام كله من بوابة `MyApp.builder`، فلا تعتمد على شاشة بعينها
/// ولا يفوّتها المستخدم. وبها مسار التجديد حتى لا يُفاجأ أحد بالقفل.
class LicenseWarningBar extends StatelessWidget {
  const LicenseWarningBar({super.key});

  @override
  Widget build(BuildContext context) {
    final license = Get.find<SystemLicenseController>();
    final expiry = license.expiryDate;
    final text =
        expiry == null
            ? trf('اشتراك النظام: {0}', [license.statusLabel])
            : trf('اشتراك النظام: {0} (حتى {1})', [
              license.statusLabel,
              SystemLicenseController.formatDate(expiry),
            ]);
    return Material(
      color: AppColors.warning,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            children: [
              const Icon(
                Icons.warning_amber_rounded,
                size: 18,
                color: Colors.white,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  text,
                  style: const TextStyle(
                    fontFamily: 'cairo',
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => showLicenseRenewDialog(context),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  minimumSize: const Size(0, 30),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  tr('تجديد'),
                  style: const TextStyle(
                    fontFamily: 'cairo',
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    decoration: TextDecoration.underline,
                    decorationColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
