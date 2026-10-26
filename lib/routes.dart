import 'package:get/get.dart';
import 'package:laundry/core/constant/routes.dart';
import 'package:laundry/services/permission/permission_catalog.dart';
import 'package:laundry/services/permission/permission_guard.dart';
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
import 'package:laundry/view/screen/settings/settings_pages.dart';
import 'package:laundry/view/screen/settings/doc_template_screen.dart';
import 'package:laundry/view/screen/processing_screen.dart';
import 'package:laundry/view/screen/subscriptions_screen.dart';
import 'package:laundry/view/screen/subscription/subscription_dashboard_screen.dart';
import 'package:laundry/view/screen/onboarding_screen.dart';
import 'package:laundry/view/screen/users_screen.dart';
import 'package:laundry/view/screen/users/roles_screen.dart';
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

/// مسارات النظام — وكل مسار محمي يحمل `middlewares` بصلاحياته المرجوة.
///
/// **القاعدة:** `PermissionGuard` يُذكر لكل مسار **له معنى صلاحيوي**، لا
/// لكل مسار. المسارات العامة (`splash` · `login` · `onboarding` · `profile`
/// · `homepage`) بلا حرس عمدًا: الدخول والخروج والملف الشخصي حقّ كل مستخدم.
///
/// **النجاح بأحد المفاتيح (`any`)** لأن المسار قد يخدم غرضين — مثل
/// `/settings` التي تفتح لكل من يملك أي إعداد. والتحكم الدقيق بما *داخل*
/// الشاشة يبقى على الشاشة (`PermissionService.can`) وعلى طبقة الخدمة.
List<GetPage<dynamic>>? routes = [
  GetPage(name: AppRoute.splash, page: () => SplashScreen()),
  GetPage(name: AppRoute.homepage, page: () => const Home()),

  // الأصناف والأسعار — إدارة الصنف (وتكلفته) صلاحية، والكتالوج عرض
  GetPage(name: AppRoute.category, page: () => Category()),
  GetPage(
    name: AppRoute.addcategory,
    page: () => AddCategory(),
    middlewares: [
      PermissionGuard([PermissionKeys.categoryManage]),
    ],
  ),

  GetPage(name: AppRoute.login, page: () => LoginScreen()),

  // الزبائن
  GetPage(
    name: AppRoute.customernumber,
    page: () => CustomerNumber(),
    middlewares: [
      PermissionGuard([
        PermissionKeys.customerView,
        PermissionKeys.customerManage,
        PermissionKeys.customerPayment,
      ]),
    ],
  ),

  // الفواتير السابقة
  GetPage(
    name: AppRoute.invoices,
    page: () => PreviousInvoice(),
    middlewares: [
      PermissionGuard([PermissionKeys.invoiceReprint]),
    ],
  ),

  // الدفاتر
  GetPage(
    name: AppRoute.dashboard,
    page: () => DashboardScreen(),
    middlewares: [
      PermissionGuard([PermissionKeys.dashboardView]),
    ],
  ),
  GetPage(
    name: AppRoute.reports,
    page: () => ReportsScreen(),
    middlewares: [
      PermissionGuard([PermissionKeys.reportsView]),
    ],
  ),

  // الإعدادات — أي إعداد يفتح الفهرس، والتفصيل داخل الصفحات
  GetPage(
    name: AppRoute.settings,
    page: () => SettingsScreen(),
    middlewares: [
      PermissionGuard([
        PermissionKeys.settingsManage,
        PermissionKeys.settingsLicense,
        PermissionKeys.backupPerform,
        PermissionKeys.discountManage,
      ]),
    ],
  ),

  // المصنعية والاشتراكات
  GetPage(
    name: AppRoute.processing,
    page: () => const ProcessingScreen(),
    middlewares: [
      PermissionGuard([PermissionKeys.processingView]),
    ],
  ),
  GetPage(
    name: AppRoute.subscriptions,
    page: () => const SubscriptionsScreen(),
    middlewares: [
      PermissionGuard([
        PermissionKeys.subscriptionManage,
        PermissionKeys.subscriptionCancel,
      ]),
    ],
  ),
  GetPage(
    name: AppRoute.subscriptionDashboard,
    page: () => const SubscriptionDashboardScreen(),
    middlewares: [
      PermissionGuard([
        PermissionKeys.subscriptionManage,
        PermissionKeys.subscriptionCancel,
      ]),
    ],
  ),

  GetPage(name: AppRoute.onboarding, page: () => const OnboardingScreen()),

  // المستخدمون
  GetPage(
    name: AppRoute.users,
    page: () => const UsersScreen(),
    middlewares: [
      PermissionGuard([
        PermissionKeys.usersView,
        PermissionKeys.usersManage,
      ]),
    ],
  ),

  // الأدوار والصلاحيات — صلاحية مستقلة عن إدارة المستخدمين: من يرتّب
  // الصلاحيات ليس بالضرورة من يُنشئ الحسابات.
  GetPage(
    name: AppRoute.roles,
    page: () => const RolesScreen(),
    middlewares: [
      PermissionGuard([PermissionKeys.rolesManage]),
    ],
  ),

  // الصندوق والمصروفات
  GetPage(
    name: AppRoute.dailyCash,
    page: () => const DailyCashScreen(),
    middlewares: [
      PermissionGuard([PermissionKeys.cashView]),
    ],
  ),
  GetPage(
    name: AppRoute.expenses,
    page: () => const ExpensesScreen(),
    middlewares: [
      PermissionGuard([PermissionKeys.expenseManage]),
    ],
  ),

  // سجل التدقيق
  GetPage(
    name: AppRoute.auditLog,
    page: () => const AuditLogScreen(),
    middlewares: [
      PermissionGuard([PermissionKeys.auditView]),
    ],
  ),

  GetPage(name: AppRoute.profile, page: () => const ProfileScreen()),

  // حسابات الزبائن والذمم
  GetPage(
    name: AppRoute.customerAccount,
    page: () => const CustomerAccountScreen(),
    middlewares: [
      PermissionGuard([
        PermissionKeys.customerView,
        PermissionKeys.debtView,
        PermissionKeys.customerPayment,
      ]),
    ],
  ),
  GetPage(
    name: AppRoute.debtAging,
    page: () => const DebtAgingScreen(),
    middlewares: [
      PermissionGuard([PermissionKeys.debtView]),
    ],
  ),
  GetPage(
    name: AppRoute.debtReconciliation,
    page: () => const DebtReconciliationScreen(),
    middlewares: [
      PermissionGuard([PermissionKeys.debtRepair, PermissionKeys.debtView]),
    ],
  ),

  // الترخيص
  GetPage(
    name: AppRoute.licenseLog,
    page: () => const LicenseLogScreen(),
    middlewares: [
      PermissionGuard([PermissionKeys.settingsLicense]),
    ],
  ),

  // النسخ الاحتياطي
  GetPage(
    name: AppRoute.backup,
    page: () => const BackupScreen(),
    middlewares: [
      PermissionGuard([PermissionKeys.backupPerform]),
    ],
  ),

  // الخصومات
  GetPage(
    name: AppRoute.discounts,
    page: () => const DiscountsScreen(),
    middlewares: [
      PermissionGuard([PermissionKeys.discountManage]),
    ],
  ),

  // ─── صفحات الإعدادات الفرعية ───
  // الإعدادات صارت فهرسًا (`/settings`)، وكل مدخل ينقل إلى صفحته هنا.
  GetPage(
    name: AppRoute.settingsBusiness,
    page: () => const SettingsBusinessPage(),
    middlewares: [
      PermissionGuard([PermissionKeys.settingsManage]),
    ],
  ),
  GetPage(
    name: AppRoute.settingsAppearance,
    page: () => const SettingsAppearancePage(),
    middlewares: [
      PermissionGuard([PermissionKeys.settingsManage]),
    ],
  ),
  GetPage(
    name: AppRoute.settingsInvoice,
    page: () => const SettingsInvoicePage(),
    middlewares: [
      PermissionGuard([PermissionKeys.settingsManage]),
    ],
  ),
  GetPage(
    name: AppRoute.settingsPrinting,
    page: () => const SettingsPrintingPage(),
    middlewares: [
      PermissionGuard([PermissionKeys.settingsManage]),
    ],
  ),
  GetPage(
    name: AppRoute.settingsAccounts,
    page: () => const SettingsAccountsPage(),
    middlewares: [
      PermissionGuard([PermissionKeys.settingsManage]),
    ],
  ),
  GetPage(
    name: AppRoute.settingsOperations,
    page: () => const SettingsOperationsPage(),
    middlewares: [
      PermissionGuard([PermissionKeys.settingsManage]),
    ],
  ),
  GetPage(
    name: AppRoute.settingsTax,
    page: () => const SettingsTaxPage(),
    middlewares: [
      PermissionGuard([PermissionKeys.settingsManage]),
    ],
  ),
  GetPage(
    name: AppRoute.settingsRetention,
    page: () => const SettingsRetentionPage(),
    middlewares: [
      PermissionGuard([PermissionKeys.settingsManage]),
    ],
  ),
  GetPage(
    name: AppRoute.settingsLicense,
    page: () => const SettingsLicensePage(),
    middlewares: [
      PermissionGuard([
        PermissionKeys.settingsManage,
        PermissionKeys.settingsLicense,
      ]),
    ],
  ),
  GetPage(
    name: AppRoute.settingsBackup,
    page: () => const SettingsBackupPage(),
    middlewares: [
      PermissionGuard([PermissionKeys.backupPerform]),
    ],
  ),
  // محرّر قوالب الطباعة — تحكّم كامل في عناصر الفاتورة وكشف الحساب.
  // ⚠️ `middlewares: [` بلا `const`: `GetMiddleware` في get-4.7.3 مُنشئه
  // ليس `const`، فالقائمة الثابتة تُسقط البناء.
  GetPage(
    name: AppRoute.settingsDocTemplate,
    page: () => const DocTemplateScreen(),
    middlewares: [
      PermissionGuard([PermissionKeys.settingsManage]),
    ],
  ),
  GetPage(
    name: AppRoute.settingsAbout,
    page: () => const SettingsAboutPage(),
    middlewares: [
      PermissionGuard([PermissionKeys.settingsManage]),
    ],
  ),
];
