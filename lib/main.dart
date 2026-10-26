import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:get/get.dart';
import 'package:laundry/controller/settings/locale_controller.dart';
import 'package:laundry/services/i18n/l10n.dart';
import 'package:laundry/config/app_info.dart';
import 'package:laundry/config/run_target.dart';
import 'package:laundry/controller/auth/auth_controller.dart';
import 'package:laundry/controller/settings/theme_controller.dart';
import 'package:laundry/core/services/invoicecounterservice.dart';
import 'package:laundry/core/theme/app_theme.dart';
import 'package:laundry/controller/printInvoicecontroller.dart';
import 'package:laundry/routes.dart';
import 'package:laundry/services/business_info_service.dart';
import 'package:laundry/services/license/system_license_service.dart';
import 'package:laundry/services/permission/permission_service.dart';
import 'package:laundry/services/pdf/doc_template_service.dart';
import 'package:laundry/services/security/session_manager.dart';
import 'package:laundry/services/settings/app_settings_service.dart';
import 'package:laundry/services/storage/prefs_guard.dart';
import 'package:laundry/sqldb.dart';
import 'package:laundry/view/screen/license/license_lock_screen.dart';
import 'package:laundry/view/widget/license/license_warning_bar.dart';
import 'package:package_info_plus/package_info_plus.dart';

void main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();

  // ⚙️ محرّك قاعدة البيانات حسب نظام التشغيل (ويندوز ⇄ أندرويد).
  //
  // **يجب أن يكون أول شيء**: على ويندوز لا يوجد تنفيذ `sqflite` أصلي، فكل
  // نداء للقاعدة قبل هذا السطر يفشل. وهو قبل `runPendingMigrations` وقراءة
  // الجلسة والترخيص، وكلها تلمس القاعدة.
  // المفتاح والتفاصيل في `lib/config/run_target.dart`.
  AppPlatform.prepareDatabaseEngine();

  // رقم الإصدار من الحزمة نفسها — لا يُكتب يدويًا في الواجهة بعد الآن
  try {
    final info = await PackageInfo.fromPlatform();
    AppInfo.set(
      info.version,
      info.buildNumber.isEmpty ? null : int.tryParse(info.buildNumber),
    );
  } catch (e) {
    debugPrint('package info unavailable: $e');
  }

  // 🩺 إصلاح ملفّ التفضيلات **قبل أي قراءة له**.
  //
  // `shared_preferences` على سطح المكتب تقرأ ملفّ JSON ثم `json.decode` بلا
  // أي `try/catch`؛ فملفّ أصفار (أثر إطفاء مفاجئ) يُقفل التطبيق عند كل إقلاع
  // بـ`FormatException` — وأوّل من يقرأه هو عدّاد الفواتير أدناه. لا يرمي
  // ولا يحذف: ينسخ التالف جانبًا ويكتب `{}`.
  await PrefsGuard.repairIfCorrupt();

  await InvoiceCounterService.loadInitialCounter();
  await PrintInvoiceController.initializeAssets();
  await SessionManager.restoreSession();

  // ترحيلات قاعدة البيانات التدرجية (تُنفذ بأمان حتى لو أُعيد تشغيلها)
  try {
    await SqlDB().runPendingMigrations();
  } catch (e) {
    debugPrint('Migration error: $e');
  }

  // 🛡️ تحميل صلاحيات المستخدم المُستعاد جلسته — **بعد** الترحيلات لأنها
  // تُنشئ جداول الصلاحيات وزرع الأدوار. بدون هذا التحميل يبقى `can` مُغلَقًا
  // (الفشل مُغلَق) فلا تظهر أي شاشة محمية لحظةَ الإقلاع.
  await PermissionService.load();

  // تحميل معلومات النشاط التجاري
  await BusinessInfoService.instance.load();

  // تحميل **خيارات النظام** القابلة للضبط (ترقيم · احتفاظ · ولاء · ضريبة ·
  // ترخيص) — قبل تشغيل خدمة الترخيص التي تقرأ فاصل الفحص وعتبة التحذير منها.
  await AppSettingsService.instance.load();

  // قوالب المستندات (الفاتورة · كشف الحساب) — تُقرأ **بعد** خيارات النظام
  // لأن القالب غير المحفوظ يُزرع من خيارات `invoiceDisplay` الحالية، فلا
  // يتغيّر شكل أي مستند قائم بعد التحديث. التحميل لا يرمي أبدًا.
  await DocTemplateService.instance.loadAll();

  // ─── ترخيص النظام (تاريخ انتهاء الاشتراك) ───
  //
  // تُقرأ الحالة **قبل** بناء الواجهة كي لا تظهر شاشة مسموحة لحظةً ثم تُقفل.
  // و`start` تُشغّل كذلك مؤقّت الفحص كل ساعة ومراقبة العودة من الخلفية.
  final license = Get.put(SystemLicenseController(), permanent: true);
  await license.start();

  // Register global controllers
  Get.put(AuthController(), permanent: true);
  final themeController = Get.put(ThemeController(), permanent: true);
  await themeController.load();

  // 🌐 اللغة — **آخر ما يُحمَّل قبل `runApp`** لأنه يغيّر اتجاه الشجرة كلها.
  // يُسجَّل دائمًا (`permanent`) لأن شاشة المظهر تقرأ منه بلا `put` جديد.
  final localeController = Get.put(LocaleController(), permanent: true);
  await localeController.load();

  runApp(const MyApp());

  // تنبيه **واحد** عند الإقلاع إن أُصلح ملفّ التفضيلات: بدونه يرى المستخدم
  // شاشة الدخول بلا تفسير بعد أن كان داخلًا. (الإصلاح يمسح الجلسة المحفوظة.)
  if (PrefsGuard.lastResult == PrefsHealth.repaired) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Get.snackbar(
        tr('أُصلح ملفّ الإعدادات'),
        tr('كان ملفّ الإعدادات تالفًا — أثر إطفاء مفاجئ للجهاز — فأُعيد ضبطه وأُبقيت نسخة من التالف جانبًا. سجّل الدخول مرة أخرى.'),
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 9),
        backgroundColor: const Color(0xFFF59E0B),
        colorText: const Color(0xFFFFFFFF),
        icon: const Icon(Icons.build_circle_outlined, color: Color(0xFFFFFFFF)),
      );
    });
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  /// يُطبّق حجم الخط المختار من الإعدادات على الشجرة المارّة من البوابة.
  Widget _scaled(BuildContext context, Widget child) {
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: TextScaler.linear(ThemeController.instance.fontScale.value),
      ),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final bizName = BusinessInfoService.instance.name;
    return GetMaterialApp(
      title: bizName.isNotEmpty ? bizName : 'نظام إدارة المغاسل',
      debugShowCheckedModeBanner: false,
      getPages: routes,
      theme: AppTheme.light,
      // بوّابة الترخيص: `builder` يمرّ منها كل مسار (بما فيها السبلاش والدخول)،
      // فهي المكان الوحيد الذي يضمن أن شاشة القفل **تغطي النظام كله** وأن
      // لافتة التحذير تظهر في أي شاشة.
      //
      // **لا نستبدل `child` (وهو الـNavigator)**: استبداله يقتلع الـNavigator
      // من الشجرة فلا يبقى حوار ولا منتقي تاريخ يعمل — أي أن مسار التجديد
      // نفسه يتعطّل. لذا نضع القفل **طبقةً فوقه** داخل Stack، ونمنحه Navigator
      // خاصًّا به كي تعمل حواراته بلا Navigator أعلى منه.
      builder: (context, child) {
        return Obx(() {
          final content = child ?? const SizedBox.shrink();
          if (!Get.isRegistered<SystemLicenseController>()) {
            return _scaled(context, content);
          }
          final license = Get.find<SystemLicenseController>();
          return _scaled(
            context,
            Stack(
              children: [
                Column(
                  children: [
                    if (license.isExpiringSoon) const LicenseWarningBar(),
                    Expanded(child: content),
                  ],
                ),
                // القفل فوق كل شيء، ويتجاهل تفاعل المستخدم مع ما تحته.
                if (license.isLocked)
                  Positioned.fill(
                    child: Navigator(
                      onGenerateRoute:
                          (_) => MaterialPageRoute(
                            builder: (_) => const LicenseLockScreen(),
                          ),
                    ),
                  ),
              ],
            ),
          );
        });
      },
      defaultTransition: Transition.fadeIn,
      transitionDuration: const Duration(milliseconds: 320),
      // 🌐 اللغة والاتجاه من `L10n` (يضبطهما `LocaleController`). تمرير
      // `supportedLocales` **إلزامي**: بدونه يهبط Flutter إلى `en_US`
      // فتعمل عناصر Material بالإنجليزية أبدًا حتى لو كانت الواجهة عربية —
      // وهو الخلل الذي كان قائمًا قبل إضافة `flutter_localizations`.
      locale: Locale(L10n.language.code),
      supportedLocales: const <Locale>[Locale('ar'), Locale('en')],
      localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
    );
  }
}