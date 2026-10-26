/// منطق **خالص** (بلا Flutter وبلا قاعدة بيانات) لخيارات النظام القابلة
/// للضبط من شاشة الإعدادات.
///
/// **لماذا ملف خالص:** القيم التي كانت ثوابت في `config/constants.dart` صارت
/// خيارات يضبطها المستخدم (تفعيل/تعطيل + تحديد قيمة). فوُضِعت أوصافُها
/// ونطاقاتُها ومفاتيحُها في سجل واحد يُقرأ منه: الزرع · القراءة في التشغيل ·
/// بناء واجهة الإعدادات. ولأن التطبيع (تفسير `'true'`، حصر القيمة بين حدّين،
/// رفض القيم الفاسدة) هنا خالصًا، فهو قابل للاختبار بلا قاعدة بيانات:
///
///     dart run tool/verify_setting_options.dart
library;

import 'package:laundry/config/constants.dart';
import 'package:laundry/services/catalog/clothing_sort.dart';
import 'package:laundry/services/i18n/l10n.dart';

/// نوع قيمة الخيار — يحدّد عنصر التحكم في الإعدادات وصيغة التخزين.
///
/// `choice` قيمة انتقائية من قائمة مغلقة (`choices`)، تُخزَّن كرمز ثابت
/// (مثل `'a4'` أو `'receipt_80mm'`) وتُعرض بلغة المستخدم عبر `choiceLabels`.
enum SettingKind { boolean, integer, decimal, text, choice }

/// مجموعات الخيارات — تُرتَّب بها بطاقات شاشة الإعدادات.
class SettingGroups {
  SettingGroups._();

  static const String invoicing = 'invoicing';
  static const String invoiceDisplay = 'invoice_display';
  static const String printing = 'printing';
  static const String invoiceOutput = 'invoice_output';
  static const String tax = 'tax';
  static const String expensesVat = 'expenses_vat';
  static const String receivables = 'receivables';
  static const String subscriptions = 'subscriptions';
  static const String processing = 'processing';
  static const String labor = 'labor';
  static const String pos = 'pos';
  static const String customers = 'customers';
  static const String loyalty = 'loyalty';
  static const String retention = 'retention';
  static const String license = 'license';

  /// ترتيب العرض في الشاشة (مصدر واحد للترتيب).
  static const List<String> ordered = <String>[
    invoicing,
    invoiceDisplay,
    printing,
    invoiceOutput,
    tax,
    expensesVat,
    receivables,
    subscriptions,
    processing,
    labor,
    pos,
    customers,
    loyalty,
    retention,
    license,
  ];
}

/// وصف خيار واحد: مفتاحه في جدول `settings`، نوعه، قيمته الافتراضية وحدوده.
class SettingOption {
  /// مفتاح التخزين في جدول `settings`.
  final String key;

  /// الاسم المعروض في الإعدادات.
  final String label;

  /// شرح مختصر يُعرض تحت الاسم.
  final String description;

  final SettingKind kind;

  /// القيمة الافتراضية **كنص** (صيغة التخزين نفسها)، تُستعمل عند غياب المفتاح.
  ///
  /// ️ مطابقتها لثوابت `AppConstants` مُتحقَّق منها آليًا في
  /// `tool/verify_setting_options.dart` — أي انحراف يفشل التحقق.
  final String defaultValue;

  /// حدّ أدنى للقيم الرقمية (يُحصر إليها).
  final num? min;

  /// حدّ أعلى للقيم الرقمية (يُحصر إليها).
  final num? max;

  /// المجموعة التي تُعرض فيها البطاقة.
  final String group;

  /// مفتاح التفعيل الذي يتبع له هذا الخيار.
  ///
  /// لا يُعرض في الإعدادات ولا يُقرأ فعليًا إلا عند تفعيل ذلك المفتاح —
  /// فلا يبقى خيار مُعطَّل يوهم المستخدم بأنه نافذ.
  final String? enabledBy;

  /// القيم المسموحة لخيار انتقائي (لا تُكتب يدويًا).
  final List<String>? choices;

  /// أسماء العرض للقيم الانتقائية (الرمز المخزَّن ⇒ نص المستخدم).
  final Map<String, String>? choiceLabels;

  const SettingOption({
    required this.key,
    required this.label,
    required this.description,
    required this.kind,
    required this.defaultValue,
    required this.group,
    this.min,
    this.max,
    this.enabledBy,
    this.choices,
    this.choiceLabels,
  });

  bool get isBoolean => kind == SettingKind.boolean;
  bool get isInteger => kind == SettingKind.integer;
  bool get isChoice => kind == SettingKind.choice;
  bool get isNumeric =>
      kind == SettingKind.integer || kind == SettingKind.decimal;
  bool get allowsDecimals => kind == SettingKind.decimal;
  bool get hasParent => enabledBy != null;

  /// اسم العرض لقيمة انتقائية (وإن غاب فالقيمة نفسها).
  ///
  /// 🚨 يُترجَم هنا لا في الكتالوج: القيمة المخزَّنة مفتاح (`cash` · `a4`)،
  /// والتسمية العربية مفتاح قاموس، والعرض يختار بحسب اللغة.
  String labelOfChoice(String value) => tr(choiceLabels?[value] ?? value);

  /// الاسم بلغة الواجهة — [label] يبقى **مفتاح القاموس** العربي.
  String get displayLabel => tr(label);

  /// الشرح بلغة الواجهة.
  String get displayDescription => tr(description);
}

/// السجل الواحد لكل خيارات النظام.
class SettingOptions {
  SettingOptions._();

  // ─── الفوترة والترقيم ──

  static const SettingOption invoiceStart = SettingOption(
    key: AppConstants.settingInvoiceStart,
    label: 'بداية ترقيم الفواتير',
    description:
        'أول رقم يُمنح لفاتورة جديدة. لا يقلّل الترقيم إن وُجدت فاتورة برقم أعلى.',
    kind: SettingKind.integer,
    defaultValue: '1001',
    min: 1,
    max: 99999999,
    group: SettingGroups.invoicing,
  );

  static const SettingOption invoiceNumberPrefix = SettingOption(
    key: AppConstants.settingInvoiceNumberPrefix,
    label: 'بادئة رقم الفاتورة',
    description:
        'نصّ يُسبق رقم الفاتورة المعروض (مثال: INV-). اتركه فارغًا لِلا بادئة.',
    kind: SettingKind.text,
    defaultValue: '',
    group: SettingGroups.invoicing,
  );

  static const SettingOption invoiceNumberPadding = SettingOption(
    key: AppConstants.settingInvoiceNumberPadding,
    label: 'حشو رقم الفاتورة',
    description: 'عدد الخانات بإضافة أصفار (6 ⇒ 000123). الصفر يعني بلا حشو.',
    kind: SettingKind.integer,
    defaultValue: '0',
    min: 0,
    max: 12,
    group: SettingGroups.invoicing,
  );

  static const SettingOption pageSize = SettingOption(
    key: AppConstants.settingPageSize,
    label: 'عدد الفواتير في الصفحة',
    description: 'حجم الدفعة في شاشة الفواتير السابقة (تحميل عند التمرير).',
    kind: SettingKind.integer,
    defaultValue: '12',
    min: 5,
    max: 200,
    group: SettingGroups.invoicing,
  );

  static const SettingOption currency = SettingOption(
    key: AppConstants.settingCurrency,
    label: 'العملة',
    description:
        'رمز العملة المعروض في الواجهات والفواتير (مثال: ر.س). يُترجم الافتراضي إلى SAR في الوضع الإنجليزي، وأي رمز آخر يبقى كما تكتبه.',
    kind: SettingKind.text,
    defaultValue: 'ر.س',
    group: SettingGroups.invoicing,
  );

  static const SettingOption invoiceRequireCustomer = SettingOption(
    key: AppConstants.settingInvoiceRequireCustomer,
    label: 'إلزام اختيار زبون',
    description:
        'عند التفعيل لا تُصدر الفاتورة بلا زبون مُسجَّل — يفيد لمتابعة الذمم وإشعارات الجاهزية.',
    kind: SettingKind.boolean,
    defaultValue: '0',
    group: SettingGroups.invoicing,
  );

  static const SettingOption invoiceAllowCredit = SettingOption(
    key: AppConstants.settingInvoiceAllowCredit,
    label: 'السماح بالبيع الآجل',
    description:
        'عند التعطيل يُمنع تسجيل ذمة على أي زبون (كاش ودفع إلكتروني فقط).',
    kind: SettingKind.boolean,
    defaultValue: '1',
    group: SettingGroups.invoicing,
  );

  static const SettingOption invoiceAllowDiscount = SettingOption(
    key: AppConstants.settingInvoiceAllowDiscount,
    label: 'السماح بالخصومات',
    description: 'عند التعطيل لا يُقبل أي كود خصم في نقطة البيع.',
    kind: SettingKind.boolean,
    defaultValue: '1',
    group: SettingGroups.invoicing,
  );

  // ─── ما يظهر على الفاتورة ──

  static const SettingOption invoiceTitleText = SettingOption(
    key: AppConstants.settingInvoiceTitleText,
    label: 'عنوان الفاتورة',
    description: 'النصّ المطبوع أعلى الفاتورة (مثال: فاتورة ضريبية مبسطة).',
    kind: SettingKind.text,
    defaultValue: AppConstants.invoiceTitleTextDefault,
    group: SettingGroups.invoiceDisplay,
  );

  static const SettingOption invoiceShowLogo = SettingOption(
    key: AppConstants.settingInvoiceShowLogo,
    label: 'إظهار الشعار',
    description: 'طبع شعار النشاط أعلى الفاتورة.',
    kind: SettingKind.boolean,
    defaultValue: '1',
    group: SettingGroups.invoiceDisplay,
  );

  static const SettingOption invoiceLogoSize = SettingOption(
    key: AppConstants.settingInvoiceLogoSize,
    label: 'حجم شعار الفاتورة (مم)',
    description:
        'عرض الشعار المربّع أعلى الفاتورة بالمليمتر (53 = الحجم الافتراضي ≈ 5.3 سم).',
    kind: SettingKind.integer,
    defaultValue: '${AppConstants.invoiceLogoSizeDefaultMm}',
    min: AppConstants.invoiceLogoSizeMinMm,
    max: AppConstants.invoiceLogoSizeMaxMm,
    group: SettingGroups.invoiceDisplay,
    enabledBy: AppConstants.settingInvoiceShowLogo,
  );

  static const SettingOption invoiceShowTaxNumber = SettingOption(
    key: AppConstants.settingInvoiceShowTaxNumber,
    label: 'إظهار الرقم الضريبي',
    description: 'طبع الرقم الضريبي للنشاط على الفاتورة.',
    kind: SettingKind.boolean,
    defaultValue: '1',
    group: SettingGroups.invoiceDisplay,
  );

  static const SettingOption invoiceShowCrNumber = SettingOption(
    key: AppConstants.settingInvoiceShowCrNumber,
    label: 'إظهار السجل التجاري',
    description: 'طبع رقم السجل التجاري على الفاتورة.',
    kind: SettingKind.boolean,
    defaultValue: '1',
    group: SettingGroups.invoiceDisplay,
  );

  static const SettingOption invoiceShowShortAddress = SettingOption(
    key: AppConstants.settingInvoiceShowShortAddress,
    label: 'إظهار العنوان الوطني',
    description: 'طبع العنوان الوطني المختصر على الفاتورة.',
    kind: SettingKind.boolean,
    defaultValue: '0',
    group: SettingGroups.invoiceDisplay,
  );

  static const SettingOption invoiceShowCashier = SettingOption(
    key: AppConstants.settingInvoiceShowCashier,
    label: 'إظهار اسم المستخدم',
    description: 'طبع اسم الكاشير الذي أصدر الفاتورة.',
    kind: SettingKind.boolean,
    defaultValue: '1',
    group: SettingGroups.invoiceDisplay,
  );

  static const SettingOption invoiceShowDatetime = SettingOption(
    key: AppConstants.settingInvoiceShowDatetime,
    label: 'إظهار التاريخ والوقت',
    description: 'طبع تاريخ ووقت إصدار الفاتورة.',
    kind: SettingKind.boolean,
    defaultValue: '1',
    group: SettingGroups.invoiceDisplay,
  );

  static const SettingOption invoiceShowPickupCode = SettingOption(
    key: AppConstants.settingInvoiceShowPickupCode,
    label: 'إظهار رمز الاستلام',
    description: 'طبع رمز استلام الغسيل على الفاتورة.',
    kind: SettingKind.boolean,
    defaultValue: '1',
    group: SettingGroups.invoiceDisplay,
  );

  static const SettingOption invoiceShowCustomerPhone = SettingOption(
    key: AppConstants.settingInvoiceShowCustomerPhone,
    label: 'إظهار هاتف الزبون',
    description: 'طبع رقم هاتف الزبون على الفاتورة.',
    kind: SettingKind.boolean,
    defaultValue: '0',
    group: SettingGroups.invoiceDisplay,
  );

  static const SettingOption invoiceShowTaxLine = SettingOption(
    key: AppConstants.settingInvoiceShowTaxLine,
    label: 'إظهار سطر الضريبة',
    description: 'طبع سطر ضريبة القيمة المضافة في تفصيل الفاتورة.',
    kind: SettingKind.boolean,
    defaultValue: '1',
    group: SettingGroups.invoiceDisplay,
    enabledBy: AppConstants.settingTaxEnabled,
  );

  static const SettingOption invoiceShowTaxBase = SettingOption(
    key: AppConstants.settingInvoiceShowTaxBase,
    label: 'إظهار الأساس قبل الضريبة',
    description: 'طبع المبلغ قبل الضريبة بجانب الإجمالي.',
    kind: SettingKind.boolean,
    defaultValue: '0',
    group: SettingGroups.invoiceDisplay,
    enabledBy: AppConstants.settingTaxEnabled,
  );

  static const SettingOption invoiceShowDiscountLine = SettingOption(
    key: AppConstants.settingInvoiceShowDiscountLine,
    label: 'إظهار سطر الخصم',
    description: 'طبع قيمة الخصم إن وُجد.',
    kind: SettingKind.boolean,
    defaultValue: '1',
    group: SettingGroups.invoiceDisplay,
  );

  static const SettingOption invoiceShowPaid = SettingOption(
    key: AppConstants.settingInvoiceShowPaid,
    label: 'إظهار المدفوع',
    description: 'طبع المبلغ المدفوع على الفاتورة.',
    kind: SettingKind.boolean,
    defaultValue: '1',
    group: SettingGroups.invoiceDisplay,
  );

  static const SettingOption invoiceShowRemaining = SettingOption(
    key: AppConstants.settingInvoiceShowRemaining,
    label: 'إظهار المتبقي',
    description: 'طبع المبلغ المتبقي على الفاتورة.',
    kind: SettingKind.boolean,
    defaultValue: '1',
    group: SettingGroups.invoiceDisplay,
  );

  static const SettingOption invoiceShowQr = SettingOption(
    key: AppConstants.settingInvoiceShowQr,
    label: 'إظهار رمز QR',
    description:
        'طبع رمز الاستجابة السريعة. لا يُطبع فعلًا إلا عند تفعيل الضريبة ووجود رقم ضريبي للنشاط.',
    kind: SettingKind.boolean,
    defaultValue: '1',
    group: SettingGroups.invoiceDisplay,
    enabledBy: AppConstants.settingTaxEnabled,
  );

  static const SettingOption invoiceFooterNote = SettingOption(
    key: AppConstants.settingInvoiceFooterNote,
    label: 'تذييل الفاتورة',
    description: 'نصّ حرّ يُطبع أسفل الفاتورة (شروط · شكر · ضمان).',
    kind: SettingKind.text,
    defaultValue: '',
    group: SettingGroups.invoiceDisplay,
  );

  static const SettingOption invoiceRounding = SettingOption(
    key: AppConstants.settingInvoiceRounding,
    label: 'تقريب الإجمالي',
    description: 'تقريب المبلغ المستحق لأقرب وحدة نقدية عند الطباعة.',
    kind: SettingKind.choice,
    defaultValue: AppConstants.invoiceRoundingDefault,
    group: SettingGroups.invoiceDisplay,
    choices: <String>['none', 'nearest_0.05', 'nearest_0.25', 'nearest_1'],
    choiceLabels: <String, String>{
      'none': 'بلا تقريب',
      'nearest_0.05': 'أقرب 0.05',
      'nearest_0.25': 'أقرب 0.25',
      'nearest_1': 'أقرب ريال',
    },
  );

  // ─── الطباعة بكل المقاسات ──

  /// **خطّ الطباعة** — يحكم كل مستند مطبوع (فاتورة · كشف · وردية).
  ///
  /// القيم هنا **مطابقة** لمفاتيح `PrintFonts.all` (حرس `verify_print_font`).
  /// تُعرض في الواجهة كبطاقات معاينة لا كقائمة منسدلة (انظر
  /// `print_font_picker.dart`) لأن المستخدم يحتاج أن **يرى** الخطّ.
  static const SettingOption printFont = SettingOption(
    key: AppConstants.settingPrintFont,
    label: 'خطّ الطباعة',
    description:
        'الخطّ المستخدم في طباعة كل المستندات. للحراري اختر خطًّا خفيفًا (IBM Plex خفيف · المراعي خفيف · المهنّد).',
    kind: SettingKind.choice,
    defaultValue: AppConstants.printFontDefault,
    group: SettingGroups.printing,
    choices: <String>[
      'al_mohanad',
      'ibm_plex_light',
      'almarai_light',
      'ibm_plex',
      'noto_sans',
      'noto_naskh',
      'tajawal',
      'almarai',
      'cairo',
      'noto_kufi',
      'amiri',
    ],
    choiceLabels: <String, String>{
      'al_mohanad': 'المهنّد (الافتراضي)',
      'ibm_plex_light': 'IBM Plex — خفيف',
      'almarai_light': 'المراعي — خفيف',
      'ibm_plex': 'IBM Plex',
      'noto_sans': 'نوتو سانس',
      'noto_naskh': 'نسخ نوتو',
      'tajawal': 'تجوال',
      'almarai': 'المراعي',
      'cairo': 'القاهرة',
      'noto_kufi': 'كوفي نوتو',
      'amiri': 'أميري',
    },
  );

  static const SettingOption invoicePaperSize = SettingOption(
    key: AppConstants.settingInvoicePaperSize,
    label: 'مقاس الفاتورة',
    description:
        'المقاس الافتراضي لطباعة الفاتورة. الحرارية 80/58 مم للطابعات الحرارية.',
    kind: SettingKind.choice,
    defaultValue: AppConstants.invoicePaperSizeDefault,
    group: SettingGroups.printing,
    choices: <String>['a4', 'a5', 'a6', 'receipt_80mm', 'receipt_58mm'],
    choiceLabels: <String, String>{
      'a4': 'A4',
      'a5': 'A5',
      'a6': 'A6',
      'receipt_80mm': 'حراري 80 مم',
      'receipt_58mm': 'حراري 58 مم',
    },
  );

  static const SettingOption shiftPaperSize = SettingOption(
    key: AppConstants.settingShiftPaperSize,
    label: 'مقاس ملخص الوردية',
    description: 'المقاس الافتراضي لطباعة ملخص إغلاق الوردية.',
    kind: SettingKind.choice,
    defaultValue: AppConstants.shiftPaperSizeDefault,
    group: SettingGroups.printing,
    choices: <String>['a6', 'a5', 'receipt_80mm'],
    choiceLabels: <String, String>{
      'a6': 'A6',
      'a5': 'A5',
      'receipt_80mm': 'حراري 80 مم',
    },
  );

  static const SettingOption statementPaperSize = SettingOption(
    key: AppConstants.settingStatementPaperSize,
    label: 'مقاس كشف الحساب',
    description: 'المقاس الافتراضي لطباعة كشف حساب الزبون.',
    kind: SettingKind.choice,
    defaultValue: AppConstants.statementPaperSizeDefault,
    group: SettingGroups.printing,
    choices: <String>['a4', 'a5'],
    choiceLabels: <String, String>{'a4': 'A4', 'a5': 'A5'},
  );

  static const SettingOption labelPaperSize = SettingOption(
    key: AppConstants.settingLabelPaperSize,
    label: 'مقاس ملصق القطع',
    description: 'مقاس ملصق تتبّع قطع الغسيل (يُطبع مع لوحة المصنعية).',
    kind: SettingKind.choice,
    defaultValue: AppConstants.labelPaperSizeDefault,
    group: SettingGroups.printing,
    choices: <String>['label_50x30', 'label_40x30', 'none'],
    choiceLabels: <String, String>{
      'label_50x30': 'ملصق 50×30 مم',
      'label_40x30': 'ملصق 40×30 مم',
      'none': 'بلا ملصقات',
    },
    enabledBy: AppConstants.settingProcessingPrintItemTags,
  );

  static const SettingOption printAskSizeEachTime = SettingOption(
    key: AppConstants.settingPrintAskSizeEachTime,
    label: 'اسأل عن المقاس عند الطباعة',
    description:
        'عند التفعيل يُفتح حوار لاختيار المقاس (وكل المقاسات المسموحة) قبل كل طباعة بدل الالتزام بالمقاس الافتراضي.',
    kind: SettingKind.boolean,
    defaultValue: '0',
    group: SettingGroups.printing,
  );

  static const SettingOption printAutoAfterSale = SettingOption(
    key: AppConstants.settingPrintAutoAfterSale,
    label: 'طباعة تلقائية بعد البيع',
    description: 'طباعة الفاتورة تلقائيًا بمجرد إتمام البيع.',
    kind: SettingKind.boolean,
    defaultValue: '0',
    group: SettingGroups.printing,
  );

  static const SettingOption printAutoPaperSize = SettingOption(
    key: AppConstants.settingPrintAutoPaperSize,
    label: 'مقاس الطباعة التلقائية',
    description: 'المقاس المستخدم عند الطباعة التلقائية.',
    kind: SettingKind.choice,
    defaultValue: AppConstants.invoicePaperSizeDefault,
    group: SettingGroups.printing,
    choices: <String>['a4', 'a5', 'a6', 'receipt_80mm', 'receipt_58mm'],
    choiceLabels: <String, String>{
      'a4': 'A4',
      'a5': 'A5',
      'a6': 'A6',
      'receipt_80mm': 'حراري 80 مم',
      'receipt_58mm': 'حراري 58 مم',
    },
    enabledBy: AppConstants.settingPrintAutoAfterSale,
  );

  static const SettingOption invoiceCopies = SettingOption(
    key: AppConstants.settingInvoiceCopies,
    label: 'عدد نسخ الفاتورة',
    description: 'عدد النسخ المطبوعة في كل عملية.',
    kind: SettingKind.integer,
    defaultValue: '1',
    min: 1,
    max: 5,
    group: SettingGroups.printing,
  );

  static const SettingOption receiptFooterNote = SettingOption(
    key: AppConstants.settingReceiptFooterNote,
    label: 'تذييل الإيصال الحراري',
    description: 'نصّ يُطبع أسفل الإيصال الحراري فقط.',
    kind: SettingKind.text,
    defaultValue: '',
    group: SettingGroups.printing,
  );

  static const SettingOption printUseDefaultPrinter = SettingOption(
    key: AppConstants.settingPrintUseDefaultPrinter,
    label: 'الطباعة على الطابعة المختارة تلقائيًا',
    description:
        'عند التفعيل تُطبَع الفاتورة مباشرةً على الطابعة المختارة في قسم «الطابعة الافتراضية» بلا أي حوار طباعة. عند التعطيل يظهر حوار طباعة النظام في كل مرة.',
    kind: SettingKind.boolean,
    defaultValue: '0',
    group: SettingGroups.printing,
  );

  // ── إخراج الفاتورة (طباعة / PDF) ──

  /// مفتاح الطباعة — **افتراضيّه «مُفعَّل»** حفاظًا على السلوك القائم (كل
  /// فاتورة تُطبَع عند البيع). تعطيله مقصود لنقطة بيع بلا ورق.
  static const SettingOption invoicePrintOnSale = SettingOption(
    key: AppConstants.settingInvoicePrintOnSale,
    label: 'طباعة الفاتورة على الطابعة عند البيع',
    description:
        'عند التعطيل لا تُطبَع الفاتورة عند إتمام البيع إطلاقًا (نقطة بيع بلا ورق). أما الطباعة اليدوية من شاشات الفواتير والورديات فتبقى تعمل.',
    kind: SettingKind.boolean,
    defaultValue: '1',
    group: SettingGroups.invoiceOutput,
  );

  /// ورقة المغسلة — **بلا مقاس مستقلّ** عن قصد.
  ///
  /// تتبع مقاس فاتورة العميل (`invoice_paper_size`) حرفيًّا: A4 · A5 · A6 ·
  /// حراري 80/58 مم. فلو غيّر المستخدم مقاس الفاتورة تغيّرت معها الورقة، ولا
  /// يمكن أن تخرج فاتورة 80 مم وورقة مغسلة A4 بسبب إعدادين متعارضين.
  static const SettingOption invoicePrintLaundrySlip = SettingOption(
    key: AppConstants.settingInvoicePrintLaundrySlip,
    label: 'طباعة ورقة المغسلة مع الفاتورة',
    description:
        'تُطبع بعد فاتورة العميل ورقة داخلية للمحل بنفس مقاس الورق المختار، بلا أسعار أو ضريبة، وتحتوي رقم الفاتورة والأصناف والكميات ورمز الاستلام. تُطبع كمهمة مستقلة ليقطعها القاطع التلقائي وحدها.',
    kind: SettingKind.boolean,
    defaultValue: '1',
    group: SettingGroups.invoiceOutput,
  );

  static const SettingOption invoicePdfExport = SettingOption(
    key: AppConstants.settingInvoicePdfExport,
    label: 'حفظ نسخة PDF عند إصدار الفاتورة',
    description:
        'تُحفَظ نسخة PDF من الفاتورة فور إتمام البيع في المجلد المحدَّد بالأسفل. مستقلّ عن الطباعة: يمكن الجمع بينهما أو تشغيل أحدهما.',
    kind: SettingKind.boolean,
    defaultValue: '0',
    group: SettingGroups.invoiceOutput,
  );

  /// مسار المجلد نصًّا. يُكتب هنا يدويًا (مفيد لمسار شبكة مثل
  /// `\\server\share`)، ويُملأ تلقائيًا من زرّ اختيار المجلد في البطاقة
  /// التالية. تركه فارغًا يعني استخدام المجلد الافتراضي `<المستندات>/فواتير`.
  static const SettingOption invoicePdfDirectory = SettingOption(
    key: AppConstants.settingInvoicePdfDirectory,
    label: 'مجلد حفظ الفواتير',
    description:
        'المسار الكامل لمجلد الحفظ. يمكن كتابته هنا أو اختياره بالزر أدناه. فارغ = المجلد الافتراضي داخل «المستندات».',
    kind: SettingKind.text,
    defaultValue: '',
    group: SettingGroups.invoiceOutput,
  );

  // ── الضريبة ──

  static const SettingOption taxEnabled = SettingOption(
    key: AppConstants.settingTaxEnabled,
    label: 'تفعيل الضريبة',
    description:
        'المفتاح الأكبر: عند التفعيل تُحتسب الضريبة على كل فاتورة وتُخزَّن وتُطبع وتُخصم من الربح لأنها التزام لا إيراد. وعند التعطيل تُصفَّر في كل الوحدات ولا يُطبع QR ولا يُبنى أي إرسال للهيئة.',
    kind: SettingKind.boolean,
    defaultValue: '0',
    group: SettingGroups.tax,
  );

  static const SettingOption taxRate = SettingOption(
    key: AppConstants.settingTaxRate,
    label: 'نسبة الضريبة',
    description:
        'كنسبة عشرية: 0.15 = 15%. القيمة محصورة بين 0 و1. تُجمَّد النسبة في كل فاتورة عند إصدارها، فلا يُعيد تغييرها لاحقًا كتابة ضريبة فاتورة قديمة.',
    kind: SettingKind.decimal,
    defaultValue: '0.15',
    min: 0,
    max: 1,
    group: SettingGroups.tax,
    enabledBy: AppConstants.settingTaxEnabled,
  );

  static const SettingOption taxPricesInclude = SettingOption(
    key: AppConstants.settingTaxPricesInclude,
    label: 'الأسعار شاملة الضريبة',
    description:
        'التفعيل يعني أن السعر المعروض للزبون يحتوي الضريبة (تُستخرج منه). والتعطيل يعني أن الضريبة تُضاف فوق السعر عند الدفع.',
    kind: SettingKind.boolean,
    defaultValue: '1',
    group: SettingGroups.tax,
    enabledBy: AppConstants.settingTaxEnabled,
  );

  static const SettingOption taxApplyToSubscriptions = SettingOption(
    key: AppConstants.settingTaxApplyToSubscriptions,
    label: 'إخضاع الاشتراكات للضريبة',
    description:
        'عند التعطيل تبقى فواتير الاشتراكات معفاة (لا ضريبة على مبلغ مُحصَّل سابقًا)، وعند التفعيل تُحتسب عليها ضريبة.',
    kind: SettingKind.boolean,
    defaultValue: '0',
    group: SettingGroups.tax,
    enabledBy: AppConstants.settingTaxEnabled,
  );

  static const SettingOption taxApplyToDelivery = SettingOption(
    key: AppConstants.settingTaxApplyToDelivery,
    label: 'إخضاع رسوم التوصيل للضريبة',
    description: 'عند التفعيل تُحتسب الضريبة على رسوم التوصيل أيضًا.',
    kind: SettingKind.boolean,
    defaultValue: '1',
    group: SettingGroups.tax,
    enabledBy: AppConstants.settingTaxEnabled,
  );

  static const SettingOption taxExemptCategories = SettingOption(
    key: AppConstants.settingTaxExemptCategories,
    label: 'تصنيفات معفاة من الضريبة',
    description:
        'أرقام تصنيفات مفصولة بفواصل (نسبة صفرية). اتركه فارغًا إن كان كل النشاط خاضعًا.',
    kind: SettingKind.text,
    defaultValue: '',
    group: SettingGroups.tax,
    enabledBy: AppConstants.settingTaxEnabled,
  );

  static const SettingOption taxShowInStatement = SettingOption(
    key: AppConstants.settingTaxShowInStatement,
    label: 'إظهار الضريبة في كشف الحساب',
    description: 'إظهار أعمدة الأساس والضريبة والإجمالي الضريبي في الكشف.',
    kind: SettingKind.boolean,
    defaultValue: '1',
    group: SettingGroups.tax,
    enabledBy: AppConstants.settingTaxEnabled,
  );

  static const SettingOption taxShowInCashReport = SettingOption(
    key: AppConstants.settingTaxShowInCashReport,
    label: 'إظهار الضريبة في تقرير الصندوق',
    description:
        'سطر «ضريبة محصّلة (التزام غير نقدي)» في تقرير الصندوق. لا تُحسب ضمن النقدية الداخلة.',
    kind: SettingKind.boolean,
    defaultValue: '1',
    group: SettingGroups.tax,
    enabledBy: AppConstants.settingTaxEnabled,
  );

  static const SettingOption taxRegistered = SettingOption(
    key: AppConstants.settingTaxRegistered,
    label: 'النشاط مسجَّل لدى الهيئة',
    description:
        'المفتاح الذي يسمح بطباعة QR والتكامل الضريبي. لا يعني تفعيل الضريبة نفسه — بل جاهزية النشاط للربط بالهيئة.',
    kind: SettingKind.boolean,
    defaultValue: '0',
    group: SettingGroups.tax,
  );

  static const SettingOption zatcaQrPhase1 = SettingOption(
    key: AppConstants.settingZatcaQrPhase1,
    label: 'رمز QR (المرحلة الأولى)',
    description:
        'ترميز حقول الهيئة الخمسة في QR. لا يُطبع إلا عند وجود رقم ضريبي وتفعيل الضريبة.',
    kind: SettingKind.boolean,
    defaultValue: '1',
    group: SettingGroups.tax,
    enabledBy: AppConstants.settingTaxRegistered,
  );

  static const SettingOption zatcaPhase2Prepared = SettingOption(
    key: AppConstants.settingZatcaPhase2Prepared,
    label: 'تجهيز المرحلة الثانية',
    description:
        'بناء بنية UBL والتوقيع وحالة الفاتورة استعدادًا للربط الفعلي. التشغيل لا يفتح أي اتصال شبكة بحد ذاته.',
    kind: SettingKind.boolean,
    defaultValue: '0',
    group: SettingGroups.tax,
    enabledBy: AppConstants.settingTaxRegistered,
  );

  static const SettingOption vatReturnBasis = SettingOption(
    key: AppConstants.settingVatReturnBasis,
    label: 'أساس الإقرار الضريبي',
    description:
        'نقدي (حسب التحصيل) أو استحقاق (حسب الإصدار). يحدّد نطاق تجميع ضريبة المخرجات في تقرير الإقرار.',
    kind: SettingKind.choice,
    defaultValue: 'accrual',
    group: SettingGroups.tax,
    choices: <String>['accrual', 'cash'],
    choiceLabels: <String, String>{'accrual': 'استحقاق', 'cash': 'نقدي'},
    enabledBy: AppConstants.settingTaxEnabled,
  );

  // ─── ضريبة المدخلات على المصروفات ──

  static const SettingOption expensesVatEnabled = SettingOption(
    key: AppConstants.settingExpensesVatEnabled,
    label: 'تفعيل ضريبة المدخلات',
    description: 'عند التفعيل يُدخَل مبلغ ضريبة المدخلات في كل مصروف خاضع.',
    kind: SettingKind.boolean,
    defaultValue: '0',
    group: SettingGroups.expensesVat,
  );

  static const SettingOption expensesDefaultVatRate = SettingOption(
    key: AppConstants.settingExpensesDefaultVatRate,
    label: 'نسبة ضريبة المدخلات الافتراضية',
    description: 'النسبة المعروضة افتراضيًا عند إدخال مصروف خاضع.',
    kind: SettingKind.decimal,
    defaultValue: '0.15',
    min: 0,
    max: 1,
    group: SettingGroups.expensesVat,
    enabledBy: AppConstants.settingExpensesVatEnabled,
  );

  static const SettingOption expensesRequireTaxInvoice = SettingOption(
    key: AppConstants.settingExpensesRequireTaxInvoice,
    label: 'إلزام رقم فاتورة المورّد',
    description: 'تنبيه عند حفظ مصروف خاضع بلا رقم فاتورة ضريبية.',
    kind: SettingKind.boolean,
    defaultValue: '0',
    group: SettingGroups.expensesVat,
    enabledBy: AppConstants.settingExpensesVatEnabled,
  );

  // ─── الذمم ──

  static const SettingOption defaultCreditLimit = SettingOption(
    key: AppConstants.settingDefaultCreditLimit,
    label: 'حدّ الائتمان الافتراضي',
    description: 'الحدّ المطبَّق على الزبون بلا حدّ خاص. صفر = بلا حدّ.',
    kind: SettingKind.decimal,
    defaultValue: '0',
    min: 0,
    max: 10000000,
    group: SettingGroups.receivables,
  );

  static const SettingOption debtProvisionRate = SettingOption(
    key: AppConstants.settingDebtProvisionRate,
    label: 'نسبة مخصّص الديون المشكوكة',
    description:
        'نسبة تُحمَّل على الديون المتجاوزة 90 يومًا في تقارير الأعمار.',
    kind: SettingKind.decimal,
    defaultValue: '0.25',
    min: 0,
    max: 1,
    group: SettingGroups.receivables,
  );

  static const SettingOption creditBlockOnExceed = SettingOption(
    key: AppConstants.settingCreditBlockOnExceed,
    label: 'منع البيع عند تجاوز حدّ الائتمان',
    description:
        'عند التفعيل يُمنع البيع الآجل عند بلوغ الحدّ إلا بتجاوز مدير، وعند التعطيل يُكتفى بالتنبيه.',
    kind: SettingKind.boolean,
    defaultValue: '0',
    group: SettingGroups.receivables,
  );

  static const SettingOption statementShowTax = SettingOption(
    key: AppConstants.settingStatementShowTax,
    label: 'إظهار تفصيل ضريبي في الكشف',
    description: 'يتبع تفعيل الضريبة؛ يضيف ملخّصًا ضريبيًا لكشف الحساب.',
    kind: SettingKind.boolean,
    defaultValue: '1',
    group: SettingGroups.receivables,
    enabledBy: AppConstants.settingTaxEnabled,
  );

  static const SettingOption statementFooterNote = SettingOption(
    key: AppConstants.settingStatementFooterNote,
    label: 'تذييل كشف الحساب',
    description: 'نصّ يُطبع أسفل كشف الحساب.',
    kind: SettingKind.text,
    defaultValue: '',
    group: SettingGroups.receivables,
  );

  // ─── الاشتراكات ──

  static const SettingOption subUsageWarnPercent = SettingOption(
    key: AppConstants.settingSubUsageWarnPercent,
    label: 'نسبة التحذير من سقف الاستخدام',
    description: 'يُنبَّه الكاشير عند بلوغ هذه النسبة من سقف الاشتراك.',
    kind: SettingKind.integer,
    defaultValue: '80',
    min: 10,
    max: 100,
    group: SettingGroups.subscriptions,
  );

  static const SettingOption subRequirePaymentBeforeUse = SettingOption(
    key: AppConstants.settingSubRequirePaymentBeforeUse,
    label: 'إلزام سداد الاشتراك قبل الاستخدام',
    description: 'عند التفعيل لا تُغطّى فاتورة باشتراك غير مسدَّد.',
    kind: SettingKind.boolean,
    defaultValue: '0',
    group: SettingGroups.subscriptions,
  );

  static const SettingOption subGraceDays = SettingOption(
    key: AppConstants.settingSubGraceDays,
    label: 'مهلة السماح بعد انتهاء التغطية (أيام)',
    description:
        'أيام تبقى فيها التغطية نافذة بعد انتهائها قبل اعتبارها منتهية.',
    kind: SettingKind.integer,
    defaultValue: '0',
    min: 0,
    max: 60,
    group: SettingGroups.subscriptions,
  );

  static const SettingOption subAutoRenew = SettingOption(
    key: AppConstants.settingSubAutoRenew,
    label: 'تجديد الاشتراك تلقائيًا',
    description:
        'عند التفعيل يُولَّد استحقاق الدورة الجديدة تلقائيًا عند الإغلاق.',
    kind: SettingKind.boolean,
    defaultValue: '0',
    group: SettingGroups.subscriptions,
  );

  static const SettingOption subBillingAnchorDay = SettingOption(
    key: AppConstants.settingSubBillingAnchorDay,
    label: 'يوم بداية دورة الاشتراك',
    description: 'اليوم من الشهر الذي تبدأ فيه دورة الفوترة (1 = بداية الشهر).',
    kind: SettingKind.integer,
    defaultValue: '1',
    min: 1,
    max: 28,
    group: SettingGroups.subscriptions,
  );

  // ─── المصنعية ──

  static const SettingOption processingEnabled = SettingOption(
    key: AppConstants.settingProcessingEnabled,
    label: 'تفعيل لوحة المصنعية',
    description: 'عند التعطيل يُخفى تتبّع الحالات من الفاتورة ولوحة المصنعية.',
    kind: SettingKind.boolean,
    defaultValue: '1',
    group: SettingGroups.processing,
  );

  static const SettingOption processingWorkflow = SettingOption(
    key: AppConstants.settingProcessingWorkflow,
    label: 'مخطط سير العمل',
    description: 'قياسي (4 حالات) أو موسّع (6 حالات: غسيل · كوي · تغليف...).',
    kind: SettingKind.choice,
    defaultValue: AppConstants.processingWorkflowDefault,
    group: SettingGroups.processing,
    choices: <String>['standard', 'extended'],
    choiceLabels: <String, String>{
      'standard': 'قياسي (4 حالات)',
      'extended': 'موسّع (6 حالات)',
    },
    enabledBy: AppConstants.settingProcessingEnabled,
  );

  static const SettingOption processingRequireWorker = SettingOption(
    key: AppConstants.settingProcessingRequireWorker,
    label: 'إلزام تعيين عامل',
    description: 'عند التفعيل لا تبدأ القطعة التنفيذ بلا عامل مسؤول.',
    kind: SettingKind.boolean,
    defaultValue: '0',
    group: SettingGroups.processing,
    enabledBy: AppConstants.settingProcessingEnabled,
  );

  static const SettingOption processingSlaHours = SettingOption(
    key: AppConstants.settingProcessingSlaHours,
    label: 'مهلة الإنجاز (ساعات)',
    description: 'بعد هذه المدة تُعلَّم الفاتورة كمتأخرة في لوحة المصنعية.',
    kind: SettingKind.integer,
    defaultValue: '24',
    min: 1,
    max: 720,
    group: SettingGroups.processing,
    enabledBy: AppConstants.settingProcessingEnabled,
  );

  static const SettingOption processingAutoReadyHours = SettingOption(
    key: AppConstants.settingProcessingAutoReadyHours,
    label: 'انتقال تلقائي إلى «جاهز» (ساعات)',
    description: 'صفر يعني بلا انتقال تلقائي (التحديث يدوي).',
    kind: SettingKind.integer,
    defaultValue: '0',
    min: 0,
    max: 720,
    group: SettingGroups.processing,
    enabledBy: AppConstants.settingProcessingEnabled,
  );

  static const SettingOption processingNotifyWhatsapp = SettingOption(
    key: AppConstants.settingProcessingNotifyWhatsapp,
    label: 'إشعار الزبون بالواتساب',
    description: 'إظهار زر إشعار العميل عند جاهزية الغسيل.',
    kind: SettingKind.boolean,
    defaultValue: '1',
    group: SettingGroups.processing,
    enabledBy: AppConstants.settingProcessingEnabled,
  );

  static const SettingOption processingPrintItemTags = SettingOption(
    key: AppConstants.settingProcessingPrintItemTags,
    label: 'طباعة ملصقات القطع',
    description: 'إتاحة طباعة ملصق لكل قطعة عند الاستلام.',
    kind: SettingKind.boolean,
    defaultValue: '0',
    group: SettingGroups.processing,
    enabledBy: AppConstants.settingProcessingEnabled,
  );

  static const SettingOption minOrderAmount = SettingOption(
    key: AppConstants.settingMinOrderAmount,
    label: 'الحد الأدنى للفاتورة',
    description: 'أقل مبلغ مسموح لفاتورة جديدة. صفر = بلا حدّ.',
    kind: SettingKind.decimal,
    defaultValue: '0',
    min: 0,
    max: 100000,
    group: SettingGroups.processing,
    enabledBy: AppConstants.settingProcessingEnabled,
  );

  // ─── مصنعية العمال ───

  static const SettingOption laborCostEnabled = SettingOption(
    key: AppConstants.settingLaborCostEnabled,
    label: 'تفعيل مصنعية العمال',
    description: 'احتساب تكلفة عمالة لكل قطعة على الفاتورة وتقرير الإنتاجية.',
    kind: SettingKind.boolean,
    defaultValue: '0',
    group: SettingGroups.labor,
  );

  static const SettingOption laborRatePerPiece = SettingOption(
    key: AppConstants.settingLaborRatePerPiece,
    label: 'أجر القطعة',
    description: 'قيمة مصنعية القطعة الواحدة للعامل.',
    kind: SettingKind.decimal,
    defaultValue: '0',
    min: 0,
    max: 10000,
    group: SettingGroups.labor,
    enabledBy: AppConstants.settingLaborCostEnabled,
  );

  static const SettingOption laborRequireWorker = SettingOption(
    key: AppConstants.settingLaborRequireWorker,
    label: 'إلزام تعيين عامل للاحتساب',
    description: 'عند التفعيل لا تُحمَّل مصنعية على فاتورة بلا عامل مسؤول.',
    kind: SettingKind.boolean,
    defaultValue: '1',
    group: SettingGroups.labor,
    enabledBy: AppConstants.settingLaborCostEnabled,
  );

  static const SettingOption laborIncentiveThreshold = SettingOption(
    key: AppConstants.settingLaborIncentiveThreshold,
    label: 'حدّ حافز الإنتاج (قطعة/شهر)',
    description: 'عدد القطع الشهري الذي يبدأ عنده صرف الحافز.',
    kind: SettingKind.integer,
    defaultValue: '0',
    min: 0,
    max: 1000000,
    group: SettingGroups.labor,
    enabledBy: AppConstants.settingLaborCostEnabled,
  );

  static const SettingOption laborIncentivePercent = SettingOption(
    key: AppConstants.settingLaborIncentivePercent,
    label: 'نسبة حافز الإنتاج',
    description: 'نسبة تُضاف على أجور المصنعية عند تجاوز الحدّ.',
    kind: SettingKind.decimal,
    defaultValue: '0',
    min: 0,
    max: 1,
    group: SettingGroups.labor,
    enabledBy: AppConstants.settingLaborCostEnabled,
  );

  // ─── سلوك نقطة البيع ──

  static const SettingOption posAutoPrint = SettingOption(
    key: AppConstants.settingPosAutoPrint,
    label: 'طباعة تلقائية في نقطة البيع',
    description: 'نسخة من طباعة الفاتورة بعد البيع مباشرة.',
    kind: SettingKind.boolean,
    defaultValue: '0',
    group: SettingGroups.pos,
  );

  static const SettingOption posConfirmBeforePay = SettingOption(
    key: AppConstants.settingPosConfirmBeforePay,
    label: 'تأكيد قبل الدفع',
    description: 'حوار تأكيد قبل حفظ الفاتورة.',
    kind: SettingKind.boolean,
    defaultValue: '0',
    group: SettingGroups.pos,
  );

  static const SettingOption posDefaultPaymentMethod = SettingOption(
    key: AppConstants.settingPosDefaultPaymentMethod,
    label: 'طريقة الدفع الافتراضية',
    description: 'الطريقة المحدَّدة مسبقًا عند فتح الدفع.',
    kind: SettingKind.choice,
    defaultValue: AppConstants.posDefaultPaymentMethodDefault,
    group: SettingGroups.pos,
    // 🚨 `choices` **مفاتيح تخزين** لا نصوص عرض: القيمة تُكتب في `settings`
    // وتبقى ثابتة مهما تغيّرت اللغة أو الصياغة. التسمية العربية في
    // `choiceLabels` وهي وحدها ما يُترجَم عند العرض.
    choices: <String>['cash', 'card', 'credit'],
    choiceLabels: <String, String>{
      'cash': 'كاش',
      'card': 'شبكة',
      'credit': 'آجل',
    },
  );

  static const SettingOption posSoundOnSale = SettingOption(
    key: AppConstants.settingPosSoundOnSale,
    label: 'نبرة نجاح البيع',
    description: 'تشغيل صوت عند إتمام البيع.',
    kind: SettingKind.boolean,
    defaultValue: '0',
    group: SettingGroups.pos,
  );

  /// ترتيب بطاقات الأصناف في شاشة البيع — الفرز **في القاعدة** لا في الواجهة.
  static const SettingOption clothingSort = SettingOption(
    key: AppConstants.settingClothingSort,
    label: 'ترتيب الأصناف في شاشة البيع',
    description: 'الطريقة التي تُعرض بها بطاقات الأصناف عند البيع.',
    kind: SettingKind.choice,
    defaultValue: ClothingSort.defaultKey,
    group: SettingGroups.pos,
    choices: <String>[
      'name_asc',
      'name_desc',
      'unsorted',
      'price_asc',
      'price_desc',
      'best_selling',
      'newest',
      'oldest',
    ],
    choiceLabels: <String, String>{
      'name_asc': 'الاسم: أ ← ي',
      'name_desc': 'الاسم: ي ← أ',
      'unsorted': 'بدون فرز',
      'price_asc': 'السعر: الأقل أولًا',
      'price_desc': 'السعر: الأعلى أولًا',
      'best_selling': 'الأكثر مبيعًا',
      'newest': 'الأحدث إضافة',
      'oldest': 'الأقدم',
    },
  );

  // ─── الزبائن ───

  static const SettingOption customerRequirePhone = SettingOption(
    key: AppConstants.settingCustomerRequirePhone,
    label: 'إلزام هاتف الزبون',
    description: 'عند التفعيل لا يُحفظ زبون بلا رقم هاتف.',
    kind: SettingKind.boolean,
    defaultValue: '0',
    group: SettingGroups.customers,
  );

  static const SettingOption customerDefaultTier = SettingOption(
    key: AppConstants.settingCustomerDefaultTier,
    label: 'شريحة الزبون الافتراضية',
    description: 'الشريحة الممنوحة للزبون الجديد.',
    kind: SettingKind.choice,
    defaultValue: AppConstants.customerDefaultTierDefault,
    group: SettingGroups.customers,
    choices: <String>['bronze', 'silver', 'gold', 'vip'],
    choiceLabels: <String, String>{
      'bronze': 'برونزي',
      'silver': 'فضي',
      'gold': 'ذهبي',
      'vip': 'كبار العملاء',
    },
  );

  // ─── نقاط الولاء ───

  static const SettingOption loyaltyEnabled = SettingOption(
    key: AppConstants.settingLoyaltyEnabled,
    label: 'احتساب نقاط الولاء',
    description:
        'عند التعطيل لا تُضاف نقاط ولا تُرقّى شرائح الزبائن عند إصدار فاتورة.',
    kind: SettingKind.boolean,
    defaultValue: '1',
    group: SettingGroups.loyalty,
  );

  static const SettingOption loyaltyRate = SettingOption(
    key: AppConstants.settingLoyaltyRate,
    label: 'نقاط الولاء لكل مبلغ',
    description:
        'نقطة واحدة لكل هذا المبلغ من قيمة الفاتورة (10 = نقطة لكل 10 ر.س).',
    kind: SettingKind.integer,
    defaultValue: '10',
    min: 1,
    max: 100000,
    group: SettingGroups.loyalty,
    enabledBy: AppConstants.settingLoyaltyEnabled,
  );

  static const SettingOption loyaltyRoundUp = SettingOption(
    key: AppConstants.settingLoyaltyRoundUp,
    label: 'جبر كسور النقاط لأعلى',
    description: 'عند التفعيل تُقرَّب النقاط لأعلى بدل إسقاط الكسور.',
    kind: SettingKind.boolean,
    defaultValue: '0',
    group: SettingGroups.loyalty,
    enabledBy: AppConstants.settingLoyaltyEnabled,
  );

  // ─── الاحتفاظ بالبيانات ──

  static const SettingOption invoiceAutoDeleteEnabled = SettingOption(
    key: AppConstants.settingInvoiceAutoDeleteEnabled,
    label: 'حذف الفواتير القديمة تلقائيًا',
    description:
        'عند التعطيل لا يُحذف أي سجل محاسبي تلقائيًا. وعند التفعيل تُحذف الفواتير الأقدم من مدة الاحتفاظ، ولا تُمسّ فواتير الديون والاشتراكات ولا فواتير السنة الجارية.',
    kind: SettingKind.boolean,
    defaultValue: '0',
    group: SettingGroups.retention,
  );

  static const SettingOption invoiceRetentionDays = SettingOption(
    key: AppConstants.settingInvoiceRetentionDays,
    label: 'مدة الاحتفاظ (أيام)',
    description:
        'أقل مدة مسموحة 400 يومًا: أي فاتورة من السنة الجارية لا تُحذف مهما كان عمرها، حمايةً للتقارير السنوية والشهرية.',
    kind: SettingKind.integer,
    defaultValue: '400',
    min: AppConstants.invoiceRetentionMinDays,
    max: 36500,
    group: SettingGroups.retention,
    enabledBy: AppConstants.settingInvoiceAutoDeleteEnabled,
  );

  // ─── خيارات الترخيص ──

  static const SettingOption licenseWarnDays = SettingOption(
    key: AppConstants.settingLicenseWarnDays,
    label: 'تنبيه قبل انتهاء الترخيص (أيام)',
    description: 'يُعرض تحذير «يتبقى N يومًا» في آخر هذه المدة قبل الانتهاء.',
    kind: SettingKind.integer,
    defaultValue: '7',
    min: 0,
    max: 365,
    group: SettingGroups.license,
  );

  static const SettingOption licenseCheckHours = SettingOption(
    key: AppConstants.settingLicenseCheckHours,
    label: 'فاصل فحص الترخيص (ساعات)',
    description:
        'كل هذه المدة يُعاد فحص صلاحية النظام أثناء العمل (مع الفحص عند الإقلاع وعند العودة من الخلفية).',
    kind: SettingKind.integer,
    defaultValue: '1',
    min: 1,
    max: 24,
    group: SettingGroups.license,
  );

  /// كل الخيارات بترتيب العرض.
  static const List<SettingOption> all = <SettingOption>[
    // الفوترة والترقيم
    invoiceStart,
    invoiceNumberPrefix,
    invoiceNumberPadding,
    pageSize,
    currency,
    invoiceRequireCustomer,
    invoiceAllowCredit,
    invoiceAllowDiscount,
    // ما يظهر على الفاتورة
    invoiceTitleText,
    invoiceShowLogo,
    invoiceLogoSize,
    invoiceShowTaxNumber,
    invoiceShowCrNumber,
    invoiceShowShortAddress,
    invoiceShowCashier,
    invoiceShowDatetime,
    invoiceShowPickupCode,
    invoiceShowCustomerPhone,
    invoiceShowTaxLine,
    invoiceShowTaxBase,
    invoiceShowDiscountLine,
    invoiceShowPaid,
    invoiceShowRemaining,
    invoiceShowQr,
    invoiceFooterNote,
    invoiceRounding,
    // الطباعة
    printFont,
    invoicePaperSize,
    shiftPaperSize,
    statementPaperSize,
    labelPaperSize,
    printAskSizeEachTime,
    printAutoAfterSale,
    printAutoPaperSize,
    invoiceCopies,
    receiptFooterNote,
    printUseDefaultPrinter,
    // إخراج الفاتورة (طباعة / PDF)
    invoicePrintOnSale,
    invoicePrintLaundrySlip,
    invoicePdfExport,
    invoicePdfDirectory,
    // الضريبة
    taxEnabled,
    taxRate,
    taxPricesInclude,
    taxApplyToSubscriptions,
    taxApplyToDelivery,
    taxExemptCategories,
    taxShowInStatement,
    taxShowInCashReport,
    taxRegistered,
    zatcaQrPhase1,
    zatcaPhase2Prepared,
    vatReturnBasis,
    // ضريبة المدخلات
    expensesVatEnabled,
    expensesDefaultVatRate,
    expensesRequireTaxInvoice,
    // الذمم
    defaultCreditLimit,
    debtProvisionRate,
    creditBlockOnExceed,
    statementShowTax,
    statementFooterNote,
    // الاشتراكات
    subUsageWarnPercent,
    subRequirePaymentBeforeUse,
    subGraceDays,
    subAutoRenew,
    subBillingAnchorDay,
    // المصنعية
    processingEnabled,
    processingWorkflow,
    processingRequireWorker,
    processingSlaHours,
    processingAutoReadyHours,
    processingNotifyWhatsapp,
    processingPrintItemTags,
    minOrderAmount,
    // مصنعية العمال
    laborCostEnabled,
    laborRatePerPiece,
    laborRequireWorker,
    laborIncentiveThreshold,
    laborIncentivePercent,
    // نقطة البيع
    posAutoPrint,
    posConfirmBeforePay,
    posDefaultPaymentMethod,
    posSoundOnSale,
    clothingSort,
    // الزبائن
    customerRequirePhone,
    customerDefaultTier,
    // الولاء
    loyaltyEnabled,
    loyaltyRate,
    loyaltyRoundUp,
    // الاحتفاظ
    invoiceAutoDeleteEnabled,
    invoiceRetentionDays,
    // الترخيص
    licenseWarnDays,
    licenseCheckHours,
  ];

  /// الخيار المطابق لمفتاح تخزين، أو `null` إن لم يكن خيارًا مسجّلًا.
  static SettingOption? byKey(String key) {
    for (final option in all) {
      if (option.key == key) return option;
    }
    return null;
  }

  /// خيارات مجموعة معيّنة بترتيب السجل.
  static List<SettingOption> ofGroup(String group) =>
      all.where((o) => o.group == group).toList(growable: false);

  /// مفتاح التفعيل الذي يتبع له الخيار (أو `null`).
  static SettingOption? parentOf(SettingOption option) =>
      option.enabledBy == null ? null : byKey(option.enabledBy!);

  /// سلسلة مفاتيح التفعيل من الجذر إلى الخيار (بلا الخيار نفسه).
  static List<SettingOption> ancestorsOf(SettingOption option) {
    final chain = <SettingOption>[];
    var key = option.enabledBy;
    var guard = 0;
    while (key != null && guard++ < 32) {
      final parent = byKey(key);
      if (parent == null) break;
      chain.add(parent);
      key = parent.enabledBy;
    }
    return chain;
  }
}

/// هل القيمة النصية تعني «مُفعَّل»؟
///
/// المنطق الخالص لحارس الحذف التلقائي: **الغياب أو أي قيمة غير صريحة تعني
/// معطَّل** — فلا يُحذف سجل مالي إلا بتفعيل صريح ('1' أو 'true').
bool isTruthy(String? raw) {
  final value = (raw ?? '').trim().toLowerCase();
  return value == '1' || value == 'true';
}

/// القيمة الفعلية لخيار مع مراعاة سلسلة التفعيل.
///
/// يعيد `'0'` للمنطقي المعطَّل (أو أبيه)، والقيمة المطبَّعة لغيره، والافتراضي
/// حين يكون الخيار أو أحد أسلافه معطَّلًا. هذا ما يجعل «خيارًا معطَّلًا» يعني
/// فعلًا معطَّلًا لا مجرّد مخفي.
String effectiveValue(
  SettingOption option,
  String? Function(String key) readRaw,
) {
  final on = isEffectivelyOn(option, readRaw);
  if (option.isBoolean) return on ? '1' : '0';
  if (!on) return option.defaultValue;
  return normalizeValue(option, readRaw(option.key) ?? option.defaultValue);
}

/// هل الخيار مُفعَّل فعلًا (نفسه وكل أسلافه)؟
bool isEffectivelyOn(
  SettingOption option,
  String? Function(String key) readRaw,
) {
  final own = readRaw(option.key) ?? option.defaultValue;
  if (!isTruthy(own)) return false;
  for (final ancestor in SettingOptions.ancestorsOf(option)) {
    final raw = readRaw(ancestor.key) ?? ancestor.defaultValue;
    if (!isTruthy(raw)) return false;
  }
  return true;
}

/// يطبّع قيمة خام إلى صيغة التخزين المعتمدة للخيار.
///
/// - منطقي ⇒ `'1'` أو `'0'`.
/// - عدد صحيح ⇒ يُحصر بين `min` و`max`، وإن تعذّر تحليله فالقيمة الافتراضية.
/// - عشري ⇒ كالعدد الصحيح مع كسور (بلا أصفار زائدة).
/// - نصّي ⇒ يُشطب الفراغ، وإن فرغ يُستعمل الافتراضي.
/// - انتقائي ⇒ قيمة من `choices` فقط، وإلا الافتراضي.
String normalizeValue(SettingOption option, String? raw) {
  final value = (raw ?? '').trim();

  switch (option.kind) {
    case SettingKind.boolean:
      return isTruthy(value) ? '1' : '0';

    case SettingKind.choice:
      final allowed = option.choices;
      if (allowed != null && allowed.contains(value)) return value;
      return option.defaultValue;

    case SettingKind.integer:
    case SettingKind.decimal:
      final fallback = num.tryParse(option.defaultValue);
      num? parsed = num.tryParse(value) ?? fallback;
      if (parsed == null) return option.defaultValue;
      final lower = option.min;
      final upper = option.max;
      if (lower != null && parsed < lower) parsed = lower;
      if (upper != null && parsed > upper) parsed = upper;
      if (option.kind == SettingKind.integer) return parsed.round().toString();
      return _plainDecimal(parsed);

    case SettingKind.text:
      if (value.isEmpty) return option.defaultValue;
      return value;
  }
}

/// قيمة عددية مطبَّعة للخيار.
int intValueOf(SettingOption option, String? raw) =>
    int.tryParse(normalizeValue(option, raw)) ?? 0;

/// قيمة عشرية مطبَّعة للخيار.
double doubleValueOf(SettingOption option, String? raw) =>
    double.tryParse(normalizeValue(option, raw)) ?? 0.0;

/// عدد عشري بأبسط صيغة نصية (`0.1500` ⇒ `0.15`).
String _plainDecimal(num value) {
  final text = value.toStringAsFixed(4);
  if (!text.contains('.')) return text;
  return text.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
}
