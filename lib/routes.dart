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
import 'package:laundry/view/screen/subscription/subscription_dashboard_screen.dart';
import 'package:laundry/view/screen/onboarding_screen.dart';
import 'package:laundry/view/screen/users_screen.dart';
import 'package:laundry/view/screen/daily_cash_screen.dart';
import 'package:laundry/view/screen/expenses_screen.dart';
import 'package:laundry/view/screen/audit_log_screen.dart';
import 'package:laundry/view/screen/profile_screen.dart';
import 'package:laundry/view/screen/customer_account_screen.dart';
import 'package:laundry/view/screen/customer/debt_aging_screen.dart';
import 'package:laundry/view/screen/customer/debt_reconciliation_screen.dart';
import 'package:laundry/view/screen/license/license_log_screen.dart';
import 'package:laundry/view/screen/backup/backup_screen.dart';
import 'package:laundry/view/screen/discount/discounts_screen.dart';

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
  GetPage(
    name: AppRoute.subscriptionDashboard,
    page: () => const SubscriptionDashboardScreen(),
  ),
  GetPage(name: AppRoute.onboarding, page: () => const OnboardingScreen()),
  GetPage(name: AppRoute.users, page: () => const UsersScreen()),
  GetPage(name: AppRoute.dailyCash, page: () => const DailyCashScreen()),
  GetPage(name: AppRoute.expenses, page: () => const ExpensesScreen()),
  GetPage(name: AppRoute.auditLog, page: () => const AuditLogScreen()),
  GetPage(name: AppRoute.profile, page: () => const ProfileScreen()),
  GetPage(
    name: AppRoute.customerAccount,
    page: () => const CustomerAccountScreen(),
  ),
  GetPage(
    name: AppRoute.debtAging,
    page: () => const DebtAgingScreen(),
  ),
  GetPage(
    name: AppRoute.debtReconciliation,
    page: () => const DebtReconciliationScreen(),
  ),
  GetPage(name: AppRoute.licenseLog, page: () => const LicenseLogScreen()),
  GetPage(name: AppRoute.backup, page: () => const BackupScreen()),
  GetPage(name: AppRoute.discounts, page: () => const DiscountsScreen()),
];
