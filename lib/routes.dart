import 'package:get/get.dart';
import 'package:laundry/core/constant/routes.dart';
import 'package:laundry/view/screen/addcategory.dart';
import 'package:laundry/view/screen/category.dart';
import 'package:laundry/view/screen/customernumber.dart';
import 'package:laundry/view/screen/home.dart';
import 'package:laundry/view/screen/login.dart';
import 'package:laundry/view/screen/previousinvoice.dart';
import 'package:laundry/view/screen/spalesh.dart';
import 'package:laundry/view/screen/dashboard/dashboard_screen.dart';
import 'package:laundry/view/screen/reports/reports_screen.dart';
import 'package:laundry/view/screen/settings/settings_screen.dart';
import 'package:laundry/view/screen/processing_screen.dart';
import 'package:laundry/view/screen/subscriptions_screen.dart';

List<GetPage<dynamic>>? routes = [
  GetPage(name: AppRoute.splash, page: () => SplashScreen()),
  GetPage(name: AppRoute.homepage, page: () => const Home()),
  GetPage(name: AppRoute.category, page: () => Category()),
  GetPage(name: AppRoute.addcategory, page: () => AddCategory()),
  GetPage(name: AppRoute.login, page: () => LoginScreen()),
  GetPage(name: AppRoute.customernumber, page: () => CustomerNumber()),
  GetPage(name: AppRoute.invoices, page: () => PreviousInvoice()),
  GetPage(name: AppRoute.dashboard, page: () => DashboardScreen()),
  GetPage(name: AppRoute.reports, page: () => ReportsScreen()),
  GetPage(name: AppRoute.settings, page: () => SettingsScreen()),
  GetPage(name: AppRoute.processing, page: () => const ProcessingScreen()),
  GetPage(
    name: AppRoute.subscriptions,
    page: () => const SubscriptionsScreen(),
  ),
];
