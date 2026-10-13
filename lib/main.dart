import 'package:flutter/material.dart';
import 'package:get/get.dart';
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
import 'package:laundry/services/security/session_manager.dart';
import 'package:laundry/services/settings/app_settings_service.dart';
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

  await InvoiceCounterService.loadInitialCounter();
  await PrintInvoiceController.initializeAssets();
  await SessionManager.restoreSession();

  // ترحيلات قاعدة البيانات التدرجية (تُنفذ بأمان حتى لو أُعيد تشغيلها)
  try {
    await SqlDB().runPendingMigrations();
  } catch (e) {
    debugPrint('Migration error: $e');
  }

  // تحميل معلومات النشاط التجاري
  await BusinessInfoService.instance.load();

  // تحميل **خيارات النظام** القابلة للضبط (ترقيم · احتفاظ · ولاء · ضريبة ·
  // ترخيص) — قبل تشغيل خدمة الترخيص التي تقرأ فاصل الفحص وعتبة التحذير منها.
  await AppSettingsService.instance.load();

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

  runApp(const MyApp());
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
      locale: const Locale('ar'),
    );
  }
}
