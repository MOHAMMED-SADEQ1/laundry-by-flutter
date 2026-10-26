/// منطق **خالص** (بلا Flutter وبلا قاعدة بيانات) لكتالوج صلاحيات النظام.
///
/// **لماذا ملف خالص:**
/// كان نظام الصلاحيات ثوابت `static get` في `PermissionService` تُشتق من
/// `SessionManager.currentRole` — أي نظام **ثابت لا يُضبط**: لتغيير صلاحية
/// كاشير واحد يلزم إعادة ترجمة ونشر. هذا الملف يفصل **وصف الصلاحيات**
/// (ما هي، ما تسمّى، أي مجموعة تنتمي، ما خُطورتها) عن **إسنادها** (جداول
/// `roles`/`role_permissions`/`permission_overrides`) وعن **فحصها**
/// (`PermissionService`). فأصبح الكتالوج:
///
/// - **مصدرًا واحدًا** للأوصاف: الشاشة والزرع والفحص كلها تقرأ منه.
/// - **قابلًا للاختبار بلا قاعدة بيانات ولا Flutter**:
///
///       dart run tool/verify_permission_catalog.dart
///
/// **القاعدة الحاكمة:** الكتالوج **لا يُعدَّل من الواجهة**. المستخدم يضبط
/// *مَن يملك ماذا* (جداول الإسناد) لا *ما هي الصلاحيات الموجودة*. إضافة
/// صلاحية جديدة تكون هنا في الكود فقط — وهذا مقصود: صلاحية بلا نقطة إنفاذ
/// في الكود وهمٌ أمني، فلا معنى لإنشائها من شاشة.
///
/// **لماذا 37 وحدة لا 181 عملية؟** عدد العمليات القابلة للتغيير في النظام
/// (أزرار وحوارات) يقارب 181. لو جعلنا لكل عملية صلاحية لتضخّم الجدول حتى
/// صار غير قابل للمراجعة، ولَتكرّرت صلاحيات لا تفترق في المعنى (كل أزرار
/// «إضافة صنف» و«تعديل صنف» و«حذف صنف» قدرة واحدة). فوُحِّدت في **37 وحدة**
/// يقرأها المدير ويفهمها، مع **فصل متعمَّد** للعمليات المالية والتصحيحية
/// التي يجب أن تفترق (انظر التعليقات على كل وحدة).
library;

import 'package:laundry/services/i18n/l10n.dart';

/// درجة خطر الصلاحية — تُستخدم للترتيب والتنبيه في واجهة الأدوار.
///
/// **لماذا؟** ليست كل الصلاحيات سواء: منح «حذف فاتورة» أو «استعادة نسخة»
/// قرار مختلف جوهريًا عن منح «عرض التقارير». الوسم يجعل الخطر ظاهرًا في
/// الشاشة قبل التمكين، لا بعد الكارثة.
enum PermissionRisk {
  /// عرض أو عمل اعتيادي بلا أثر مالي مباشر.
  normal,

  /// يمسّ المال مباشرة (بيع آجل، خصم، مصروف، اشتراك).
  money,

  /// يمحو أو يعيد كتابة سجلات (حذف فاتورة/زبون، إصلاح أرصدة، استعادة نسخة).
  destructive,

  /// يمسّ الأمن والتحكّم نفسه (مستخدمون، أدوار، إعدادات، نسخ احتياطي).
  security,
}

/// مجموعات الصلاحيات — تُرتَّب بها واجهة شاشة الأدوار (مصدر واحد للترتيب).
class PermissionGroups {
  PermissionGroups._();

  static const String invoices = 'invoices';
  static const String cash = 'cash';
  static const String customers = 'customers';
  static const String books = 'books';
  static const String processing = 'processing';
  static const String system = 'system';
  static const String governance = 'governance';

  /// ترتيب العرض في الشاشة.
  static const List<String> ordered = <String>[
    invoices,
    cash,
    customers,
    books,
    processing,
    system,
    governance,
  ];

  /// اسم المجموعة المعروض بالعربية.
  static const Map<String, String> labels = <String, String>{
    invoices: 'الفواتير والبيع',
    cash: 'الصندوق والورديات',
    customers: 'الزبائن والذمم',
    books: 'الدفاتر والتقارير',
    processing: 'المصنعية والاشتراكات',
    system: 'الأصناف والنظام',
    governance: 'الحوكمة والتحكّم',
  };

  static String labelOf(String group) => labels[group] ?? group;
}

/// مفاتيح صلاحية واحدة: معرّفها، وسمها، خطرها، ومَن تتبع عرضًا.
class PermissionItem {
  /// معرّف ثابت يُخزَّن في جداول الإسناد — **لا يُغيَّر بعد النشر** وإلا
  /// فقدت القواعد القائمة إسنادها. صيغة `مجموعة.فعل`.
  final String key;

  /// الاسم المعروض في شاشة الأدوار.
  final String label;

  /// شرح مختصر يُعرض تحت الاسم.
  final String description;

  /// المجموعة التي تُعرض فيها (من [PermissionGroups]).
  final String group;

  final PermissionRisk risk;

  /// صلاحية **قرينة**: من يملكها تُمكَّن ضمناً بصريًا من مدخل معيّن.
  ///
  /// مثال: `reports.view` قرينة لـ`dashboard.view` — لا معنى للوحة تحكم
  /// برقم بلا قدرة على فتح التقارير. تُستعمل في الواجهة لضمّ المداخل لا
  /// لإنفاذ الصلاحية؛ الإنفاذ يبقى على المفتاح الصريح.
  final List<String> readWith;

  const PermissionItem({
    required this.key,
    required this.label,
    required this.description,
    required this.group,
    required this.risk,
    this.readWith = const <String>[],
  });

  bool get isDestructive => risk == PermissionRisk.destructive;
  bool get isSecurity => risk == PermissionRisk.security;
  bool get touchesMoney => risk == PermissionRisk.money;

  /// الاسم بلغة الواجهة — [label] يبقى **مفتاح القاموس** العربي.
  ///
  /// 🚨 نقطة عرض واحدة تُترجم 37 صلاحية دفعةً واحدة، بدل تغليف كل نصّ في
  /// الكتالوج (ويبقى الكتالوج منطقًا خالصًا قابلًا للاختبار بلا Flutter).
  String get displayLabel => tr(label);

  /// الشرح بلغة الواجهة.
  String get displayDescription => tr(description);
}

/// مفاتيح الصلاحيات كـ**ثوابت مُسمّاة**.
///
/// **لماذا ثوابت لا نصوص حرّة؟** لأن خطأ حرف واحد في `'invoice.delet'` لا
/// يُكتشف عند الترجمة: الصلاحية تكون مجهولة في الكتالوج فيُمنع الجميع
/// بصمت، أو يُفتح الجميع إن انقلبت الدلالة. الثوابت تُدخِل الخطأ في
/// التحليل النوعي (`analyze`) فلا يمرّ. **استعمل هذه في كل نداء `can`.**
class PermissionKeys {
  PermissionKeys._();

  // الفواتير والبيع
  static const String invoiceCreate = 'invoice.create';
  static const String invoiceDiscountApply = 'invoice.discount_apply';
  static const String invoiceSellOnCredit = 'invoice.sell_on_credit';
  static const String invoiceDraft = 'invoice.draft';
  static const String invoicePrint = 'invoice.print';
  static const String invoiceReprint = 'invoice.reprint';
  static const String invoiceReturn = 'invoice.return';
  static const String invoiceEditIssued = 'invoice.edit_issued';
  static const String invoiceDelete = 'invoice.delete';

  // الصندوق والورديات
  static const String shiftOpen = 'shift.open';
  static const String shiftClose = 'shift.close';
  static const String cashView = 'cash.view';
  static const String expenseManage = 'expense.manage';

  // الزبائن والذمم
  static const String customerView = 'customer.view';
  static const String customerManage = 'customer.manage';
  static const String customerDelete = 'customer.delete';
  static const String customerPayment = 'customer.payment';
  static const String customerCreditLimit = 'customer.credit_limit';
  static const String customerCreditOverride = 'customer.credit_limit_override';
  static const String debtView = 'debt.view';
  static const String debtRepair = 'debt.repair';

  // الدفاتر والتقارير
  static const String dashboardView = 'dashboard.view';
  static const String reportsView = 'reports.view';
  static const String reportsProfit = 'reports.profit';
  static const String reportsTax = 'reports.tax';
  static const String auditView = 'audit.view';
  static const String exportData = 'export.data';

  // المصنعية والاشتراكات
  static const String processingView = 'processing.view';
  static const String processingUpdate = 'processing.update';
  static const String subscriptionManage = 'subscription.manage';
  static const String subscriptionCancel = 'subscription.cancel';

  // الأصناف والنظام
  static const String categoryManage = 'category.manage';
  static const String discountManage = 'discount.manage';
  static const String settingsManage = 'settings.manage';
  static const String settingsLicense = 'settings.license';

  // الحوكمة والتحكّم
  static const String usersView = 'users.view';
  static const String usersManage = 'users.manage';
  static const String rolesManage = 'roles.manage';
  static const String backupPerform = 'backup.perform';
  static const String dataDelete = 'data.delete';
}

/// السجل الواحد لكل صلاحيات النظام.
///
/// **الترتيب داخل كل مجموعة هو ترتيب العرض** — لا تُعِد ترتيبه في الواجهة.
class PermissionCatalog {
  PermissionCatalog._();

  // ══════════════════════════════════════════════════════════════════
  // ١) الفواتير والبيع
  // ══════════════════════════════════════════════════════════════════

  static const PermissionItem invoiceCreate = PermissionItem(
    key: 'invoice.create',
    label: 'إصدار فاتورة',
    description:
        'إنشاء فاتورة بيع جديدة وتحويلها إلى مدفوعة. هذا هو العمل الأساسي للصندوق، ولهذا يُمنح للكاشير ابتداءً.',
    group: PermissionGroups.invoices,
    risk: PermissionRisk.normal,
  );

  static const PermissionItem invoiceDiscountApply = PermissionItem(
    key: 'invoice.discount_apply',
    label: 'تطبيق خصم على فاتورة',
    description:
        'إدخال كود خصم أو خصم يدوي قبل الدفع. **فُصل عن إصدار الفاتورة عمدًا**: الخصم يُنقص الإيراد مباشرةً، وهو أسهل طريق لتسريب المال (خصم وهمي مقابل نقد).',
    group: PermissionGroups.invoices,
    risk: PermissionRisk.money,
  );

  static const PermissionItem invoiceSellOnCredit = PermissionItem(
    key: 'invoice.sell_on_credit',
    label: 'البيع الآجل (تسجيل ذمة)',
    description:
        'تسجيل الفاتورة كدين على الزبون بدل تحصيلها نقدًا. **فُصلت عمدًا**: منح الائتمان هو المخاطرة المالية الأكبر في المنشأة، ولا يجوز أن يُفعّله كل كاشير ضمن قدرته على البيع.',
    group: PermissionGroups.invoices,
    risk: PermissionRisk.money,
  );

  static const PermissionItem invoiceDraft = PermissionItem(
    key: 'invoice.draft',
    label: 'حفظ واسترجاع مسودة',
    description: 'حفظ فاتورة غير مكتملة واسترجاعها لاحقًا.',
    group: PermissionGroups.invoices,
    risk: PermissionRisk.normal,
  );

  static const PermissionItem invoicePrint = PermissionItem(
    key: 'invoice.print',
    label: 'طباعة الفاتورة',
    description: 'إخراج الفاتورة PDF وطباعتها أو مشاركتها.',
    group: PermissionGroups.invoices,
    risk: PermissionRisk.normal,
  );

  static const PermissionItem invoiceReprint = PermissionItem(
    key: 'invoice.reprint',
    label: 'إعادة طباعة فاتورة سابقة',
    description:
        'فتح أرشيف الفواتير وطباعة نسخة جديدة. مستقلّة عن الطباعة عند البيع لأنها تفتح سجلات تاريخية لا فاتورة الحاضر.',
    group: PermissionGroups.invoices,
    risk: PermissionRisk.normal,
  );

  static const PermissionItem invoiceReturn = PermissionItem(
    key: 'invoice.return',
    label: 'إشعار دائن / مرتجع',
    description:
        'إصدار إشعار دائن لتصحيح فاتورة صادرة **بلا حذفها** — الطريق المحاسبي الصحيح للتصحيح.',
    group: PermissionGroups.invoices,
    risk: PermissionRisk.money,
  );

  static const PermissionItem invoiceDelete = PermissionItem(
    key: 'invoice.delete',
    label: 'حذف فاتورة',
    description:
        'محو فاتورة من السجل نهائيًا. عملية تصحيحية خطِرة تُفسد أثرًا محاسبيًا وتُخِلّ بالصندوق — تُمنح للإدارة وحدها.',
    group: PermissionGroups.invoices,
    risk: PermissionRisk.destructive,
  );

  static const PermissionItem invoiceEditIssued = PermissionItem(
    key: 'invoice.edit_issued',
    label: 'تعديل فاتورة صادرة',
    description: 'تغيير بنود فاتورة صدرت أو مبلغها بعد إصدارها.',
    group: PermissionGroups.invoices,
    risk: PermissionRisk.destructive,
  );

  // ══════════════════════════════════════════════════════════════════
  // ٢) الصندوق والورديات
  // ══════════════════════════════════════════════════════════════════

  static const PermissionItem shiftOpen = PermissionItem(
    key: 'shift.open',
    label: 'فتح وردية',
    description:
        'بدء وردية جديدة وضبط رصيدها الافتتاحي. لا بيع بلا وردية مفتوحة، فهذه الصلاحية **بوابة العمل اليومي**.',
    group: PermissionGroups.cash,
    risk: PermissionRisk.money,
  );

  static const PermissionItem shiftClose = PermissionItem(
    key: 'shift.close',
    label: 'إغلاق وردية وجردها',
    description:
        'إغلاق الوردية وتسجيل النقد المعدود والفرق وسببه. **فُصلت عن الفتح عمدًا**: من يفتح الصندوق ليس بالضرورة من يُحاسَب على جرده — الفصل يمنع إغلاقًا يمحو فرقًا حرجه.',
    group: PermissionGroups.cash,
    risk: PermissionRisk.money,
  );

  static const PermissionItem cashView = PermissionItem(
    key: 'cash.view',
    label: 'عرض حركة الصندوق',
    description: 'شاشة النقد اليومي وحركات الوردية ومطابقتها.',
    group: PermissionGroups.cash,
    risk: PermissionRisk.normal,
  );

  static const PermissionItem expenseManage = PermissionItem(
    key: 'expense.manage',
    label: 'تسجيل المصروفات',
    description:
        'إضافة مصروف وتعديله وحذفه — قيد يخرج من الصندوق مباشرةً، فهو عمل مالي لا إداري.',
    group: PermissionGroups.cash,
    risk: PermissionRisk.money,
  );

  // ══════════════════════════════════════════════════════════════════
  // ٣) الزبائن والذمم
  // ══════════════════════════════════════════════════════════════════

  static const PermissionItem customerView = PermissionItem(
    key: 'customer.view',
    label: 'عرض الزبائن',
    description: 'تصفّح قائمة الزبائن وبياناتهم وأرصدتهم.',
    group: PermissionGroups.customers,
    risk: PermissionRisk.normal,
  );

  static const PermissionItem customerManage = PermissionItem(
    key: 'customer.manage',
    label: 'إضافة/تعديل زبون',
    description: 'تسجيل زبون جديد وتعديل بياناته.',
    group: PermissionGroups.customers,
    risk: PermissionRisk.normal,
  );

  static const PermissionItem customerDelete = PermissionItem(
    key: 'customer.delete',
    label: 'حذف/إخفاء زبون',
    description:
        'إخفاء الزبون من القوائم. حذف ناعم (`is_active=0`) لا محو — يبقى أثر ذممه في الدفاتر.',
    group: PermissionGroups.customers,
    risk: PermissionRisk.destructive,
  );

  static const PermissionItem customerPayment = PermissionItem(
    key: 'customer.payment',
    label: 'تسجيل دفعة من زبون',
    description:
        'قبض نقدي يُخصَم من ذمة الزبون أولًا (FIFO) ثم يُقيَّد سلفةً للفائض. حركة نقدية تُغيّر الصندوق والذمة معًا.',
    group: PermissionGroups.customers,
    risk: PermissionRisk.money,
  );

  static const PermissionItem customerCreditLimit = PermissionItem(
    key: 'customer.credit_limit',
    label: 'ضبط حدّ الائتمان',
    description: 'تحديد سقف الدين المسموح لزبون معيّن.',
    group: PermissionGroups.customers,
    risk: PermissionRisk.money,
  );

  static const PermissionItem customerCreditOverride = PermissionItem(
    key: 'customer.credit_limit_override',
    label: 'تجاوز حدّ الائتمان',
    description:
        'السماح ببيع يتخطّى سقف الزبون المضبوط. **فُصلت عن ضبط الحدّ عمدًا**: الضبط سياسة، والتجاوز استثناء عليها — ولا يجوز أن يمنح الاثنان لشخص واحد بلا مبرر.',
    group: PermissionGroups.customers,
    risk: PermissionRisk.money,
  );

  static const PermissionItem debtView = PermissionItem(
    key: 'debt.view',
    label: 'عرض تقارير الديون',
    description: 'أعمار الديون وكشف الحساب ومتابعة الذمم.',
    group: PermissionGroups.customers,
    risk: PermissionRisk.normal,
  );

  static const PermissionItem debtRepair = PermissionItem(
    key: 'debt.repair',
    label: 'إصلاح أرصدة الزبائن',
    description:
        'إعادة اشتقاق حقل `customers.balance` من الفواتير. عملية تصحيحية تُعيد كتابة أرقام كل الزبائن دفعةً واحدة — أخطر من أي دفعة فردية ولهذا لا تُدمج مع «تسجيل دفعة».',
    group: PermissionGroups.customers,
    risk: PermissionRisk.destructive,
  );

  // ══════════════════════════════════════════════════════════════════
  // ٤) الدفاتر والتقارير
  // ══════════════════════════════════════════════════════════════════

  static const PermissionItem dashboardView = PermissionItem(
    key: 'dashboard.view',
    label: 'عرض لوحة التحكم',
    description: 'مؤشرات اليوم: المبيعات والذمم والمصنعية.',
    group: PermissionGroups.books,
    risk: PermissionRisk.normal,
    // لوحة التحكم تعرض أرقام اليوم؛ من يفتحها يفتح التقارير عادةً — فالقرينة
    // تُبقي المدخلين معًا في الواجهة، والإنفاذ يبقى على كل مفتاح.
    readWith: <String>['reports.view'],
  );

  static const PermissionItem reportsView = PermissionItem(
    key: 'reports.view',
    label: 'عرض التقارير',
    description: 'التقارير اليومية والأسبوعية والشهرية والسنوية.',
    group: PermissionGroups.books,
    risk: PermissionRisk.normal,
    readWith: <String>['dashboard.view'],
  );

  static const PermissionItem reportsProfit = PermissionItem(
    key: 'reports.profit',
    label: 'عرض الأرباح والتكلفة',
    description:
        'إظهار الربح الصافي والتكلفة في التقارير. **فُصلت عمدًا**: رقم الربح من أدقّ أسرار المنشأة، ومن يُدخل بيانات لا يلزم أن يرى هامشها.',
    group: PermissionGroups.books,
    risk: PermissionRisk.normal,
  );

  static const PermissionItem reportsTax = PermissionItem(
    key: 'reports.tax',
    label: 'عرض إقرار الضريبة',
    description: 'استخراج ضريبة المخرجات والمدخلات الصافي المستحق.',
    group: PermissionGroups.books,
    risk: PermissionRisk.normal,
  );

  static const PermissionItem auditView = PermissionItem(
    key: 'audit.view',
    label: 'عرض سجل التغييرات',
    description:
        'سجل التدقيق: من غيّر ماذا ومتى (أسعار، ذمم، إعدادات، أدوار).',
    group: PermissionGroups.books,
    risk: PermissionRisk.security,
  );

  static const PermissionItem exportView = PermissionItem(
    key: 'export.data',
    label: 'تصدير البيانات',
    description: 'إخراج بيانات النظام إلى ملف للتحليل خارجيًا.',
    group: PermissionGroups.books,
    risk: PermissionRisk.security,
  );

  // ══════════════════════════════════════════════════════════════════
  // ٥) المصنعية والاشتراكات
  // ══════════════════════════════════════════════════════════════════

  static const PermissionItem processingView = PermissionItem(
    key: 'processing.view',
    label: 'عرض لوحة المصنعية',
    description: 'متابعة حالة الفواتير الواردة في خط الغسيل.',
    group: PermissionGroups.processing,
    risk: PermissionRisk.normal,
  );

  static const PermissionItem processingUpdate = PermissionItem(
    key: 'processing.update',
    label: 'تحديث حالة المصنعية',
    description: 'نقل الفاتورة بين مراحل الغسيل والكي والتسليم.',
    group: PermissionGroups.processing,
    risk: PermissionRisk.normal,
  );

  static const PermissionItem subscriptionManage = PermissionItem(
    key: 'subscription.manage',
    label: 'إدارة الاشتراكات',
    description:
        'إنشاء اشتراك شهري وتسجيل دفعاته — اعتراف بإيراد مؤجَّل، فهو قيد محاسبي لا عمل تشغيلي.',
    group: PermissionGroups.processing,
    risk: PermissionRisk.money,
  );

  static const PermissionItem subscriptionCancel = PermissionItem(
    key: 'subscription.cancel',
    label: 'إلغاء اشتراك وتسويته',
    description:
        'إلغاء الاشتراك واحتساب الاسترداد (يخفض ذمة الزبون أولًا). **فُصل عن الإدارة عمدًا**: الإلغاء يُرجع مالًا ويُكتب حركة `cancel_refund`، فهو تصحيح لا إدارة روتينية.',
    group: PermissionGroups.processing,
    risk: PermissionRisk.destructive,
  );

  // ══════════════════════════════════════════════════════════════════
  // ٦) الأصناف والنظام
  // ══════════════════════════════════════════════════════════════════

  static const PermissionItem categoryManage = PermissionItem(
    key: 'category.manage',
    label: 'إدارة الأصناف والأسعار',
    description:
        'إضافة صنف وتعديله وأسعاره الأربعة **وتكلفته**. تعديل `cost_price` يغيّر كل أرباح المستقبل، فهو صلاحية مالية مُقنَّعة بإدارة.',
    group: PermissionGroups.system,
    risk: PermissionRisk.money,
  );

  static const PermissionItem discountManage = PermissionItem(
    key: 'discount.manage',
    label: 'إدارة أكواد الخصم',
    description: 'إنشاء أكواد الخصم وتحديد نسبتها وسقف استخدامها وتعطيلها.',
    group: PermissionGroups.system,
    risk: PermissionRisk.money,
  );

  static const PermissionItem settingsManage = PermissionItem(
    key: 'settings.manage',
    label: 'إدارة إعدادات النظام',
    description:
        'معلومات النشاط والضريبة والترقيم والطباعة والأدوار — قلب تحكّم النظام، ولهذا لا يُمنح إلا لمن يُسائَل عن النظام كله.',
    group: PermissionGroups.system,
    risk: PermissionRisk.security,
  );

  static const PermissionItem settingsLicense = PermissionItem(
    key: 'settings.license',
    label: 'إدارة الترخيص',
    description: 'عرض تاريخ انتهاء الترخيص وتجديده.',
    group: PermissionGroups.system,
    risk: PermissionRisk.security,
  );

  // ══════════════════════════════════════════════════════════════════
  // ٧) الحوكمة والتحكّم
  // ══════════════════════════════════════════════════════════════════

  static const PermissionItem usersView = PermissionItem(
    key: 'users.view',
    label: 'عرض المستخدمين',
    description: 'تصفّح قائمة المستخدمين وأدوارهم وحالة حساباتهم.',
    group: PermissionGroups.governance,
    risk: PermissionRisk.security,
  );

  static const PermissionItem usersManage = PermissionItem(
    key: 'users.manage',
    label: 'إدارة المستخدمين',
    description:
        'إضافة مستخدم وتعديله وتغيير كلمة مروره وتعطيله. يمسّ الأمن مباشرةً، فهو من أخطر صلاحيات النظام.',
    group: PermissionGroups.governance,
    risk: PermissionRisk.security,
  );

  static const PermissionItem rolesManage = PermissionItem(
    key: 'roles.manage',
    label: 'إدارة الأدوار والصلاحيات',
    description:
        'تعديل ما يملكه كل دور من صلاحيات. **فُصل عن إدارة المستخدمين عمدًا**: من يضيف مستخدمًا ليس بالضرورة من يُعيد رسم حدود النظام — وإلا صار كل مدير قادرًا على ترقية نفسه.',
    group: PermissionGroups.governance,
    risk: PermissionRisk.security,
  );

  static const PermissionItem backupPerform = PermissionItem(
    key: 'backup.perform',
    label: 'النسخ الاحتياطي والاستعادة',
    description:
        'أخذ نسخة كاملة واستعادة نسخة. **الاستعادة تمحو القاعدة الحالية كاملةً** — أخطر عملية في النظام بلا منافس.',
    group: PermissionGroups.governance,
    risk: PermissionRisk.destructive,
  );

  static const PermissionItem dataDelete = PermissionItem(
    key: 'data.delete',
    label: 'تنظيف البيانات القديمة',
    description: 'حذف الفواتير الأقدم من مدّة الاحتفاظ المضبوطة.',
    group: PermissionGroups.governance,
    risk: PermissionRisk.destructive,
  );

  // ══════════════════════════════════════════════════════════════════
  // القوائم والمشتقات
  // ══════════════════════════════════════════════════════════════════

  /// كل الصلاحيات بترتيب المجموعات والعرض.
  static const List<PermissionItem> all = <PermissionItem>[
    // الفواتير
    invoiceCreate,
    invoiceDiscountApply,
    invoiceSellOnCredit,
    invoiceDraft,
    invoicePrint,
    invoiceReprint,
    invoiceReturn,
    invoiceEditIssued,
    invoiceDelete,
    // الصندوق
    shiftOpen,
    shiftClose,
    cashView,
    expenseManage,
    // الزبائن
    customerView,
    customerManage,
    customerPayment,
    customerCreditLimit,
    customerCreditOverride,
    debtView,
    debtRepair,
    customerDelete,
    // الدفاتر
    dashboardView,
    reportsView,
    reportsProfit,
    reportsTax,
    auditView,
    exportView,
    // المصنعية
    processingView,
    processingUpdate,
    subscriptionManage,
    subscriptionCancel,
    // النظام
    categoryManage,
    discountManage,
    settingsManage,
    settingsLicense,
    // الحوكمة
    usersView,
    usersManage,
    rolesManage,
    backupPerform,
    dataDelete,
  ];

  static final Map<String, PermissionItem> _byKey = <String, PermissionItem>{
    for (final item in all) item.key: item,
  };

  /// الأسماء الإنجليزية للصلاحيات — مفتاحها مفتاح الصلاحية الثابت.
  static const Map<String, String> labelsEn = <String, String>{
    'invoice.create': 'Issue invoice',
    'invoice.discount_apply': 'Apply invoice discount',
    'invoice.sell_on_credit': 'Sell on credit (record debt)',
    'invoice.draft': 'Save/restore draft',
    'invoice.print': 'Print invoice',
    'invoice.reprint': 'Reprint previous invoice',
    'invoice.return': 'Credit note / return',
    'invoice.delete': 'Delete invoice',
    'invoice.edit_issued': 'Edit issued invoice',
    'shift.open': 'Open shift',
    'shift.close': 'Close and reconcile shift',
    'cash.view': 'View cash movement',
    'expense.manage': 'Record expenses',
    'customer.view': 'View customers',
    'customer.manage': 'Add/edit customer',
    'customer.delete': 'Delete/hide customer',
    'customer.payment': 'Record customer payment',
    'customer.credit_limit': 'Set credit limit',
    'customer.credit_limit_override': 'Override credit limit',
    'debt.view': 'View debt reports',
    'debt.repair': 'Repair customer balances',
    'dashboard.view': 'View dashboard',
    'reports.view': 'View reports',
    'reports.profit': 'View profit and cost',
    'reports.tax': 'View tax return',
    'audit.view': 'View change log',
    'export.data': 'Export data',
    'processing.view': 'View processing board',
    'processing.update': 'Update processing status',
    'subscription.manage': 'Manage subscriptions',
    'subscription.cancel': 'Cancel and settle subscription',
    'category.manage': 'Manage items and prices',
    'discount.manage': 'Manage discount codes',
    'settings.manage': 'Manage system settings',
    'settings.license': 'Manage license',
    'users.view': 'View users',
    'users.manage': 'Manage users',
    'roles.manage': 'Manage roles and permissions',
    'backup.perform': 'Backup and restore',
    'data.delete': 'Clean old data',
  };

  /// الأوصاف الإنجليزية للصلاحيات.
  static const Map<String, String> descriptionsEn = <String, String>{
    'invoice.create': 'Create a new sales invoice and turn it into a paid one. This is the cashier\'s core work.',
    'invoice.discount_apply': 'Enter a discount code or a manual discount before payment. It reduces revenue directly.',
    'invoice.sell_on_credit': 'Record the invoice as customer debt instead of collecting cash — the biggest financial risk.',
    'invoice.draft': 'Save an incomplete invoice and restore it later.',
    'invoice.print': 'Output the invoice as PDF and print or share it.',
    'invoice.reprint': 'Open the invoice archive and print a copy of a past invoice.',
    'invoice.return': 'Issue a credit note to correct an issued invoice without deleting it.',
    'invoice.delete': 'Permanently erase an invoice from the ledger. A dangerous correction that affects the cash box.',
    'invoice.edit_issued': 'Change the items or amount of an already issued invoice.',
    'shift.open': 'Start a new shift and set its opening balance. No sales without an open shift.',
    'shift.close': 'Close the shift and record counted cash, the difference, and its reason.',
    'cash.view': 'View daily cash, shift movements, and reconciliation.',
    'expense.manage': 'Add, edit, and delete expenses — money leaving the cash box.',
    'customer.view': 'Browse customers, their details, and balances.',
    'customer.manage': 'Register a new customer and edit their details.',
    'customer.delete': 'Hide the customer from lists (soft delete). Their debt history remains in the books.',
    'customer.payment': 'Collect cash, deduct it from the customer debt (FIFO), and post any excess as credit.',
    'customer.credit_limit': 'Set the maximum allowed debt for a customer.',
    'customer.credit_limit_override': 'Allow a sale above the customer\'s configured limit.',
    'debt.view': 'Debt aging, account statements, and debt follow-up.',
    'debt.repair': 'Re-derive customers.balance from invoices — a bulk corrective rewrite of all balances.',
    'dashboard.view': 'Today\'s sales, debts, and processing indicators.',
    'reports.view': 'Daily, weekly, monthly, and yearly reports.',
    'reports.profit': 'Show net profit and cost in reports — some of the business\'s most sensitive numbers.',
    'reports.tax': 'Extract output and input tax and the net amount due.',
    'audit.view': 'Audit log: who changed what and when (prices, debts, settings, roles).',
    'export.data': 'Export system data to a file for external analysis.',
    'processing.view': 'Follow the status of invoices in the laundry line.',
    'processing.update': 'Move an invoice between washing, ironing, and delivery stages.',
    'subscription.manage': 'Create a monthly subscription and record its payments (deferred revenue).',
    'subscription.cancel': 'Cancel a subscription and calculate the refund (reduces the customer debt first).',
    'category.manage': 'Add items, edit them, their four prices, and their cost. Changing cost_price affects future profit.',
    'discount.manage': 'Create discount codes, set their rate, usage cap, and disable them.',
    'settings.manage': 'Business info, tax, numbering, printing, and roles — the system control core.',
    'settings.license': 'View the license expiry history and renew it.',
    'users.view': 'Browse users, their roles, and account status.',
    'users.manage': 'Add users, edit them, change passwords, and disable them.',
    'roles.manage': 'Edit what each role can do. Separate from user management on purpose.',
    'backup.perform': 'Take a full backup and restore one. Restore erases the current database.',
    'data.delete': 'Delete invoices older than the configured retention period.',
  };

  static String labelEn(String key) => labelsEn[key] ?? '';
  static String descriptionEn(String key) => descriptionsEn[key] ?? '';

  /// خريطة المفتاح ⇒ الوصف (للقراءة السريعة).
  static Map<String, PermissionItem> get byKey => _byKey;

  /// صلاحية بمفتاحها، أو `null` إن لم تُعرَّف (مفتاح مجهول ⇒ لا تُمنح).
  static PermissionItem? find(String key) => _byKey[key];

  /// هل المفتاح صلاحية معروفة في الكتالوج؟
  static bool isKnown(String key) => _byKey.containsKey(key);

  /// صلاحيات مجموعة معيّنة بترتيب الكتالوج.
  static List<PermissionItem> ofGroup(String group) =>
      all.where((i) => i.group == group).toList(growable: false);

  /// كل الصلاحيات مجمَّعة بترتيب [PermissionGroups.ordered] — **وكل صلاحية
  /// تظهر في مجموعة واحدة فقط**، والمجموعات الفارغة تُحذف (حماية من مجموعة
  /// أُضيفت للترتيب ولم تُشغَل بعد).
  static Map<String, List<PermissionItem>> get grouped {
    final out = <String, List<PermissionItem>>{};
    for (final group in PermissionGroups.ordered) {
      final items = ofGroup(group);
      if (items.isNotEmpty) out[group] = items;
    }
    return out;
  }

  /// عدد الصلاحيات — يُستعمل في الحراس اللاحقة.
  static int get count => all.length;

  /// كل المفاتيح (لتطبيع المخزَّن ومقارنته).
  static List<String> get keys => all.map((i) => i.key).toList(growable: false);

  // ══════════════════════════════════════════════════════════════════
  // حِزم الزرع الافتراضية للأدوار الخمسة
  // ══════════════════════════════════════════════════════════════════

  /// حزمة «مدير النظام»: **كل الصلاحيات** بلا استثناء.
  ///
  /// وهو **الجذر غير القابل للتعديل** في شاشة الأدوار — لا يجوز إسقاط
  /// صلاحية عنه، وإلا بقي النظام بلا مدير قادر على استعادته.
  static List<String> get adminBundle => List<String>.from(keys);

  /// حزمة «مدير»: كل شيء **إلا** الحوكمة العليا.
  ///
  /// المدير يدير العمل كله، لكنه لا يمسّ: إدارة الأدوار نفسها
  /// (`roles.manage`)، ولا استعادة النسخة (`backup.perform`)، ومستخدمو
  /// النظام (`users.manage`) وتنظيف البيانات (`data.delete`) — هذه كلها
  /// سلطة المالك التي لا تُفوَّض.
  static const List<String> managerBundle = <String>[
    'invoice.create',
    'invoice.discount_apply',
    'invoice.sell_on_credit',
    'invoice.draft',
    'invoice.print',
    'invoice.reprint',
    'invoice.return',
    'invoice.edit_issued',
    'invoice.delete',
    'shift.open',
    'shift.close',
    'cash.view',
    'expense.manage',
    'customer.view',
    'customer.manage',
    'customer.payment',
    'customer.credit_limit',
    'customer.credit_limit_override',
    'debt.view',
    'debt.repair',
    'customer.delete',
    'dashboard.view',
    'reports.view',
    'reports.profit',
    'reports.tax',
    'audit.view',
    'export.data',
    'processing.view',
    'processing.update',
    'subscription.manage',
    'subscription.cancel',
    'category.manage',
    'discount.manage',
  ];

  /// حزمة «كاشير» (يُعرض «مستخدم»): يُصدر ويطبع ويقبض — لا يمحو ولا يخصم
  /// ولا يبيع آجلًا ولا يرى الأرباح.
  ///
  /// **لماذا لا نمنحه `reports.profit`؟** لأنه رقم الهامش؛ ومن يقف على
  /// الصندوق لا يلزم أن يعرف كم يربح الصنف. أمّا `dashboard.view` فتُمنح
  /// له (مبيعات وذمم اليوم) لأنها **تشغيلية** لا سرّية.
  static const List<String> cashierBundle = <String>[
    'invoice.create',
    'invoice.draft',
    'invoice.print',
    'shift.open',
    'shift.close',
    'cash.view',
    'customer.view',
    'customer.manage',
    'customer.payment',
    'dashboard.view',
    'processing.view',
    'processing.update',
  ];

  /// حزمة «محاسب»: يقرأ الدفاتر كلها **ويمنع من السلطة التصحيحية**.
  ///
  /// يُمنَح التقارير والربح والضريبة وسجل التدقيق (كلها قراءة)، والمصروفات
  /// والاشتراكات (قيد محاسبي من عمله)، والبحث في الزبائن. ولا يُمنَح: حذف
  /// فاتورة، إصلاح أرصدة، حدّ الائتمان وتجاوزه، البيع الآجل، الخصم،
  /// المستخدمين، الأدوار، الإعدادات، النسخ الاحتياطي. منحه `manager` كان
  /// سيمنحه سلطة محو سجلات محاسبية — وهي عكس وظيفته تمامًا.
  static const List<String> accountantBundle = <String>[
    'invoice.print',
    'invoice.reprint',
    'invoice.return',
    'cash.view',
    'expense.manage',
    'customer.view',
    'customer.payment',
    'debt.view',
    'dashboard.view',
    'reports.view',
    'reports.profit',
    'reports.tax',
    'audit.view',
    'export.data',
    'processing.view',
    'subscription.manage',
  ];

  /// حزمة «عامل»: مصنعية فقط — لا يلمس صندوقًا ولا زبونًا ولا سعرًا.
  static const List<String> workerBundle = <String>[
    'processing.view',
    'processing.update',
  ];

  /// حزمة دور بمفتاحه — `null` إن كان الدور غير معروف.
  static List<String>? defaultBundleOf(String roleName) {
    switch (roleName) {
      case 'admin':
        return adminBundle;
      case 'manager':
        return List<String>.from(managerBundle);
      case 'cashier':
        return List<String>.from(cashierBundle);
      case 'accountant':
        return List<String>.from(accountantBundle);
      case 'worker':
        return List<String>.from(workerBundle);
      default:
        return null;
    }
  }

  /// الأدوار المزروعة مع أسمائها المعروضة.
  ///
  /// `isSystem = true` ⇒ لا تُحذف من شاشة الأدوار.
  static const List<({String name, String label, bool isSystem})> seedRoles =
      <({String name, String label, bool isSystem})>[
    (name: 'admin', label: 'مدير النظام', isSystem: true),
    (name: 'manager', label: 'مدير', isSystem: true),
    (name: 'accountant', label: 'محاسب', isSystem: true),
    (name: 'cashier', label: 'مستخدم', isSystem: true),
    (name: 'worker', label: 'عامل', isSystem: true),
  ];

  /// اسم الدور المعروض بالعربية (للعرض في الواجهة، وللأدوار غير المعروفة).
  static String roleLabelOf(String? roleName) {
    for (final r in seedRoles) {
      if (r.name == roleName) return r.label;
    }
    return 'مستخدم';
  }

  /// هل الدور **جذر** لا يُعدَّل إسناده؟
  ///
  /// `admin` وحده. **لماذا؟** لو أُبيح تعديله لاستطاع مدير إسقاط
  /// `roles.manage` عن نفسه أو عن غيره حتى يبقى النظام بلا من يضبط
  /// الصلاحيات — وهو تصعيد صلاحية ذاتي مقنَّع. إبقاؤه غير قابل للتعديل
  /// يضمن وجود **سلطة عليا دائمة** تُعيد ضبط كل شيء.
  static bool isRootRole(String roleName) => roleName == 'admin';
}
