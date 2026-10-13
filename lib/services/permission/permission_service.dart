import 'package:laundry/services/security/session_manager.dart';

/// خدمة مركزة لفحص صلاحيات المستخدمين.
/// تعتمد على [SessionManager] لجلب الدور الحالي.
class PermissionService {
  PermissionService._();

  static String? get _role => SessionManager.currentRole;
  static bool get _isAdmin => _role == 'admin';
  static bool get _isManager => _role == 'manager' || _role == 'admin';
  static bool get _isWorker => _role == 'worker';

  /// المحاسب: دور **مستقل** لا نسخة من المدير.
  ///
  /// **لماذا فصلناه؟** المحاسب يحتاج *الدفاتر* (تقارير، ذمم، مصروفات،
  /// اشتراكات) ولا يحتاج *السلطة التصحيحية* (حذف فاتورة، إصلاح أرصدة،
  /// إدارة مستخدمين، إعدادات، تجاوز حدّ ائتمان). منحه دور `manager` كان
  /// سيمنحه سلطة محو سجلات محاسبية — وهي عكس وظيفته تمامًا.
  static bool get _isAccountant => _role == 'accountant';

  /// صاحب شأن بالدفاتر: مدير أو محاسب.
  static bool get _canReadBooks => _isManager || _isAccountant;

  // ─── الصلاحيات ───

  /// إصدار فاتورة
  static bool get canCreateInvoice => true;

  /// حذف فاتورة
  static bool get canDeleteInvoice => _isManager;

  /// إدارة الأصناف (إضافة / تعديل / حذف)
  static bool get canManageCategories => _isManager;

  /// إدارة الزبائن — يشمل المحاسب (سجلات الذمم جزء من عمله)
  static bool get canManageCustomers => _canReadBooks;

  /// إدارة المستخدمين (إضافة / تعديل / حذف)
  static bool get canManageUsers => _isAdmin;

  /// عرض التقارير — مدير أو محاسب
  static bool get canViewReports => _canReadBooks;

  /// إدارة الإعدادات
  static bool get canManageSettings => _isAdmin;

  /// النسخ الاحتياطي
  static bool get canPerformBackup => _isAdmin;

  /// فتح / إغلاق وردية
  static bool get canManageShifts => _isManager;

  /// تسجيل المصروفات — مدير أو محاسب (قيد المصروف عمل محاسبي)
  static bool get canManageExpenses => _canReadBooks;

  /// إدارة الاشتراكات — مدير أو محاسب (اعتراف بالإيراد المؤجَّل)
  static bool get canManageSubscriptions => _canReadBooks;

  /// معالجة الغسيل (لوحة المصنعية)
  static bool get canProcessLaundry => _isManager || _isWorker;

  /// حذف بيانات
  static bool get canDeleteData => _isAdmin;

  /// إدارة أكواد الخصم (إنشاء/تعطيل)
  static bool get canManageDiscounts => _isAdmin || _isManager;

  /// تطبيق خصم على فاتورة.
  ///
  /// **لماذا صلاحية مستقلة؟** الخصم يُنقص الإيراد مباشرةً، وهو أسهل طريق
  /// لتسريب المال (خصم وهمي لزبون مقابل نقد). فصله عن «إصدار فاتورة» يمنع
  /// الكاشير من خصم أي مبلغ بلا ضابط، ويُبقي القرار عند الإدارة.
  static bool get canApplyDiscount => _isAdmin || _isManager;

  /// بيع آجل (تسجيل ذمة على زبون).
  ///
  /// **لماذا صلاحية مستقلة؟** البيع الآجل ليس بيعًا عاديًا — إنه منح ائتمان،
  /// وهو المخاطرة المالية الأكبر في المنشأة. فصله عن «إصدار فاتورة» يمنع
  /// أي كاشير أو عامل من تكوين ديون بلا ضابط، ويُبقي القرار عند من يتحمّله.
  static bool get canSellOnCredit => _isAdmin || _isManager;

  /// تجاوز حدّ الائتمان المضبوط لزبون.
  /// المدير وحده — لأنه قرار استثنائي فوق السياسة الائتمانية.
  static bool get canOverrideCreditLimit => _isManager;

  /// ضبط حدّ ائتمان زبون
  static bool get canSetCreditLimit => _isManager;

  /// حذف/إخفاء زبون
  static bool get canDeleteCustomer => _isManager;

  /// عرض تقارير الذمم وأعمار الديون — مدير أو محاسب
  static bool get canViewDebtReports => _canReadBooks;

  /// إصلاح أرصدة الزبائن (عملية تصحيحية حساسة)
  static bool get canRepairBalances => _isAdmin;

  /// عرض لوحة التحكم — مدير أو محاسب
  static bool get canViewDashboard => _canReadBooks;

  /// اسم الدور بالعربية
  static String get roleLabel {
    switch (_role) {
      case 'admin':
        return 'مدير النظام';
      case 'manager':
        return 'مدير';
      case 'cashier':
        return 'كاشير';
      case 'accountant':
        return 'محاسب';
      case 'worker':
        return 'عامل';
      default:
        return 'مستخدم';
    }
  }

  /// لون الدور
  static int get roleColor {
    switch (_role) {
      case 'admin':
        return 0xFFDC2626;
      case 'manager':
        return 0xFF2563EB;
      case 'cashier':
        return 0xFF16A34A;
      case 'accountant':
        return 0xFF7C3AED;
      case 'worker':
        return 0xFFD97706;
      default:
        return 0xFF6B7280;
    }
  }
}
