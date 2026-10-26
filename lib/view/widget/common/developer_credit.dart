import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:laundry/config/app_info.dart';
import 'package:laundry/core/theme/app_colors.dart';
import 'package:laundry/services/business_info_service.dart';
import 'package:laundry/services/i18n/l10n.dart';
import 'package:url_launcher/url_launcher.dart';

/// حقوق المطوّر — عرض موحّد لجملة [AppInfo.developerCredit].
///
/// **مصدر واحد للنص**: أي تعديل على الجملة يتم في `AppInfo` فقط، فلا تتباعد
/// النسخ بين الشاشات (الإقلاع، الدخول، الترحيب، الإعدادات، القائمة الجانبية)
/// ولا بين الفواتير المطبوعة.
///
/// الاستعمال:
/// * على خلفية داكنة (الإقلاع/الدخول/الترحيب): `DeveloperCredit(onDark: true)`
/// * على خلفية فاتحة (الإعدادات/القائمة الجانبية): `DeveloperCredit()`
/// * بدون تفاعل: `DeveloperCredit(tappable: false)`
class DeveloperCredit extends StatelessWidget {
  /// خلفية داكنة ⇒ نص وأيقونة بلون فاتح
  final bool onDark;

  final double fontSize;

  /// إظهار أيقونة `</>` قبل الجملة
  final bool showIcon;

  /// الضغط يفتح نافذة «مطوّر النظام» (معلومات التواصل)
  final bool tappable;

  final EdgeInsetsGeometry padding;

  const DeveloperCredit({
    super.key,
    this.onDark = false,
    this.fontSize = 11,
    this.showIcon = true,
    this.tappable = true,
    this.padding = EdgeInsets.zero,
  });

  @override
  Widget build(BuildContext context) {
    final textColor =
        onDark ? Colors.white.withValues(alpha: 0.85) : AppColors.textMuted;
    final iconColor =
        onDark ? Colors.white.withValues(alpha: 0.75) : AppColors.primaryLight;

    final content = Padding(
      padding: padding,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (showIcon) ...[
            Icon(Icons.code, size: fontSize + 3, color: iconColor),
            const SizedBox(width: 5),
          ],
          Flexible(
            child: Text(
              AppInfo.developerCredit,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'cairo',
                fontSize: fontSize,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
          ),
        ],
      ),
    );

    if (!tappable) return content;
    return InkWell(
      onTap: showDeveloperDialog,
      borderRadius: BorderRadius.circular(10),
      child: content,
    );
  }
}

/// نافذة «مطوّر النظام» — معلومات التواصل + جملة الحقوق.
///
/// كانت مكرّرة داخل القائمة الجانبية (`CustomDrawer._showDeveloperDialog`)
/// وبمعلومات اتصال مكتوبة يدويًا؛ الآن موحّدة هنا وتقرأ من [AppInfo].
void showDeveloperDialog() {
  Get.defaultDialog(
    title: AppInfo.developerName,
    titleStyle: const TextStyle(
      fontFamily: 'cairo',
      fontSize: 15,
      fontWeight: FontWeight.bold,
      color: AppColors.textPrimary,
    ),
    contentPadding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.code, size: 40, color: AppColors.primary),
        const SizedBox(height: 10),
        Text(
          AppInfo.developerCredit,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontFamily: 'cairo',
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          tr('للشكاوى والاستفسار تواصل معنا عبر:'),
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontFamily: 'cairo',
            fontSize: 13,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    ),
    actions: [
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          IconButton(
            tooltip: tr('البريد الإلكتروني'),
            onPressed: _openDeveloperMail,
            icon: const Icon(
              Icons.mail_outline,
              color: AppColors.info,
              size: 34,
            ),
          ),
          IconButton(
            tooltip: tr('واتساب'),
            onPressed: _openDeveloperWhatsapp,
            icon: const Icon(
              Icons.chat_outlined,
              color: AppColors.success,
              size: 34,
            ),
          ),
        ],
      ),
    ],
  );
}

/// نافذة «عن النظام» — تُفتح من شعار شاشة الدخول.
///
/// تجمع: اسم النشاط/النظام، الإصدار، جملة الحقوق، وزرّ التواصل مع المطوّر.
void showAboutAppDialog() {
  final String bizName =
      BusinessInfoService.instance.name.isNotEmpty
          ? BusinessInfoService.instance.name
          : tr('نظام إدارة المغاسل');

  Get.defaultDialog(
    title: tr('عن النظام'),
    titleStyle: const TextStyle(
      fontFamily: 'cairo',
      fontSize: 16,
      fontWeight: FontWeight.bold,
      color: AppColors.textPrimary,
    ),
    contentPadding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 62,
          height: 62,
          decoration: BoxDecoration(
            gradient: AppColors.primaryGradient,
            shape: BoxShape.circle,
            boxShadow: AppColors.softShadow(blur: 12, y: 4),
          ),
          child: const Icon(
            Icons.local_laundry_service,
            color: Colors.white,
            size: 30,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          bizName,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontFamily: 'cairo',
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          trf('نظام إدارة المغاسل الذكي — الإصدار {0}', [AppInfo.version]),
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontFamily: 'cairo',
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 10),
        const Divider(height: 1),
        const SizedBox(height: 8),
        const DeveloperCredit(fontSize: 12, tappable: false, showIcon: false),
      ],
    ),
    textConfirm: tr('معلومات التواصل'),
    textCancel: tr('إغلاق'),
    confirmTextColor: Colors.white,
    buttonColor: AppColors.primary,
    cancelTextColor: AppColors.textSecondary,
    onConfirm: () {
      Get.back();
      showDeveloperDialog();
    },
    onCancel: () => Get.back(),
  );
}

/// بريد المطوّر — يُفتح في تطبيق البريد، وإن تعذّر نُعرض القيمة للنسخ.
Future<void> _openDeveloperMail() async {
  final uri = Uri(scheme: 'mailto', path: AppInfo.developerEmail);
  try {
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
      return;
    }
  } catch (_) {}
  Get.snackbar(
    tr('البريد الإلكتروني'),
    AppInfo.developerEmail,
    snackPosition: SnackPosition.BOTTOM,
    duration: const Duration(seconds: 5),
  );
}

/// واتساب المطوّر — يُفتح على المحادثة مباشرة، وإن تعذّر نُعرض الرقم للنسخ.
Future<void> _openDeveloperWhatsapp() async {
  final uri = Uri(
    scheme: 'https',
    host: 'wa.me',
    path: '+966${AppInfo.developerPhone.replaceFirst('0', '')}',
    queryParameters: <String, String>{'text': Uri.encodeComponent('.')},
  );
  try {
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      return;
    }
  } catch (_) {}
  Get.snackbar(
    tr('واتساب'),
    AppInfo.developerPhone,
    snackPosition: SnackPosition.BOTTOM,
    duration: const Duration(seconds: 5),
  );
}