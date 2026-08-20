import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:laundry/controller/auth/auth_controller.dart';
import 'package:laundry/controller/settings/theme_controller.dart';
import 'package:laundry/core/services/invoicecounterservice.dart';
import 'package:laundry/core/theme/app_theme.dart';
import 'package:laundry/controller/printInvoicecontroller.dart';
import 'package:laundry/routes.dart';
import 'package:laundry/services/security/session_manager.dart';
import 'package:laundry/sqldb.dart';

void main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  await InvoiceCounterService.loadInitialCounter();
  await PrintInvoiceController.initializeAssets();
  await SessionManager.restoreSession();

  // ترحيلات قاعدة البيانات التدرجية (تُنفذ بأمان حتى لو أُعيد تشغيلها)
  try {
    await SqlDB().runPendingMigrations();
  } catch (e) {
    debugPrint('Migration error: $e');
  }

  // Register global controllers
  Get.put(AuthController(), permanent: true);
  final themeController = Get.put(ThemeController(), permanent: true);
  await themeController.load();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'مغاسل النظارة',
      debugShowCheckedModeBanner: false,
      getPages: routes,
      theme: AppTheme.light,
      builder: (context, child) {
        return Obx(() {
          return MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(
                ThemeController.instance.fontScale.value,
              ),
            ),
            child: child!,
          );
        });
      },
      defaultTransition: Transition.fadeIn,
      transitionDuration: const Duration(milliseconds: 320),
      locale: const Locale('ar'),
    );
  }
}