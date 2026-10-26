class AppConstants {
  static const String appName = 'نظام المغاسل';
  static const String dbName = 'laundry_pos.db';
  static const int dbVersion = 7;

  // ─── الحسابات الافتراضية ───
  //
  // تُزرع مرة واحدة عند أول إنشاء للقاعدة، وبشكل **غير مُتلِف** عند كل فتح
  // للتطبيق (INSERT OR IGNORE على `username` الفريد). أي حساب موجود مسبقًا
  // — ولو غيّر صاحبه كلمة مروره — **لا يُلمَس ولا تُستعاد كلمة مروره**.
  static const String defaultAdminUsername = 'admin';
  static const String defaultAdminPassword = 'laundry123456';

  static const String defaultManagerUsername = 'manager';
  static const String defaultManagerPassword = 'm123';

  static const String defaultAccountantUsername = 'accountant';
  static const String defaultAccountantPassword = 'accountant123456';

  static const String defaultUserUsername = 'user';
  static const String defaultUserPassword = '123';

  // ─── خيارات النظام: مفاتيحها وقيمها الافتراضية ───
  //
  // كل قيمة هنا **افتراضية فقط**: القيمة الفعلية تُقرأ من جدول `settings`
  // بهذا المفتاح، ويُضبطها المستخدم من «الإعدادات ← خيارات النظام».
  // تبقى في الكود:
  //   1. قيمةً احتياطية حين يغيب المفتاح من قاعدة بيانات قديمة.
  //   2. قيمةً مزروعة عند إنشاء قاعدة جديدة (`_insertDefaultSettings`).
  //
  // الأوصاف ونطاقات القيم ونوع كل خيار في موضع واحد:
  // `lib/services/settings/setting_option.dart` (منطق خالص قابل للاختبار).
  static const String settingInvoiceStart = 'invoice_start';
  static const String settingPageSize = 'page_size';
  static const String settingCurrency = 'currency';
  static const String settingInvoiceAutoDeleteEnabled =
      'invoice_auto_delete_enabled';
  static const String settingInvoiceRetentionDays = 'invoice_retention_days';
  static const String settingLoyaltyEnabled = 'loyalty_enabled';
  static const String settingLoyaltyRate = 'loyalty_rate';
  static const String settingTaxEnabled = 'tax_enabled';
  static const String settingTaxRate = 'tax_rate';
  static const String settingLicenseWarnDays = 'license_warn_days';
  static const String settingLicenseCheckHours = 'license_check_hours';

  // ─── خيارات الفاتورة والترقيم (المرحلة ٠) ───
  static const String settingInvoiceNumberPrefix = 'invoice_number_prefix';
  static const String settingInvoiceNumberPadding = 'invoice_number_padding';
  static const String settingInvoiceRequireCustomer =
      'invoice_require_customer';
  static const String settingInvoiceAllowCredit = 'invoice_allow_credit';
  static const String settingInvoiceAllowDiscount = 'invoice_allow_discount';

  // ─── ما يظهر على الفاتورة ───
  static const String settingInvoiceTitleText = 'invoice_title_text';
  static const String settingInvoiceShowLogo = 'invoice_show_logo';
  static const String settingInvoiceLogoSize = 'invoice_logo_size';

  /// مقاس شعار الفاتورة المربّع بالمليمتر.
  ///
  /// 53 مم ≈ 150 نقطة — وهو المقاس الثابت القديم، فالقيمة الافتراضية
  /// **لا تغيّر شكل أي فاتورة قائمة**. والحفظ بالمليمتر لأن المستخدم يفهمه،
  /// والتحويل إلى نقاط يقع في مولّد PDF وحده.
  static const int invoiceLogoSizeDefaultMm = 53;
  static const int invoiceLogoSizeMinMm = 10;
  static const int invoiceLogoSizeMaxMm = 120;
  static const String settingInvoiceShowTaxNumber = 'invoice_show_tax_number';
  static const String settingInvoiceShowCrNumber = 'invoice_show_cr_number';
  static const String settingInvoiceShowShortAddress =
      'invoice_show_short_address';
  static const String settingInvoiceShowCashier = 'invoice_show_cashier';
  static const String settingInvoiceShowDatetime = 'invoice_show_datetime';
  static const String settingInvoiceShowPickupCode = 'invoice_show_pickup_code';
  static const String settingInvoiceShowTaxLine = 'invoice_show_tax_line';
  static const String settingInvoiceShowTaxBase = 'invoice_show_tax_base';
  static const String settingInvoiceShowDiscountLine =
      'invoice_show_discount_line';
  static const String settingInvoiceShowPaid = 'invoice_show_paid';
  static const String settingInvoiceShowRemaining = 'invoice_show_remaining';
  static const String settingInvoiceShowCustomerPhone =
      'invoice_show_customer_phone';
  static const String settingInvoiceShowQr = 'invoice_show_qr';
  static const String settingInvoiceFooterNote = 'invoice_footer_note';
  static const String settingInvoiceRounding = 'invoice_rounding';

  // ─── الطباعة بكل المقاسات ───
  static const String settingInvoicePaperSize = 'invoice_paper_size';
  static const String settingShiftPaperSize = 'shift_paper_size';
  static const String settingStatementPaperSize = 'statement_paper_size';
  static const String settingLabelPaperSize = 'label_paper_size';
  static const String settingPrintAskSizeEachTime = 'print_ask_size_each_time';
  static const String settingPrintAutoAfterSale = 'print_auto_after_sale';
  static const String settingPrintAutoPaperSize = 'print_auto_paper_size';
  static const String settingInvoiceCopies = 'invoice_copies';
  static const String settingReceiptFooterNote = 'receipt_footer_note';

  // ─── خطّ الطباعة ───
  //
  // مفتاح واحد يحكم خطّ **كل** المستندات المطبوعة (فاتورة · كشف · وردية).
  // القيم المسموحة في `PrintFonts.all` — لا تُكتب هنا ولا في الواجهة.
  static const String settingPrintFont = 'print_font';
  static const String printFontDefault = 'al_mohanad';

  // ─── الطابعة (ويندوز/سطح المكتب) ───
  //
  // اختيار الطابعة **مرة واحدة** للنظام: يُحفظ معرّف الطابعة (`url` من
  // حزمة الطباعة) واسمها المعروض في جدول `settings`. وعند تفعيل
  // `print_use_default_printer` تُطبَع الفاتورة **مباشرةً** على هذه الطابعة
  // بلا حوار طباعة. وعند تعطيله يبقى حوار طباعة النظام (السلوك السابق).
  //
  // ملاحظة: هذه المفاتيح تُخزَّن مباشرةً كأي إعداد (لا حاجة لعمود جديد)،
  // وقراءتها من `PrinterService`.
  static const String settingPrinterSelectedUrl = 'printer_selected_url';
  static const String settingPrinterSelectedName = 'printer_selected_name';
  static const String settingPrintUseDefaultPrinter =
      'print_use_default_printer';

  // ─── إخراج الفاتورة (طباعة / PDF) ───
  //
  // **مفتاحان مستقلّان** لا إعداد واحد: فيمكن تشغيل الطباعة وحدها (الوضع
  // السابق)، أو حفظ PDF وحده (نقطة بيع بلا ورق)، أو الاثنين معًا (طباعة +
  // أرشيف). ومسار الحفظ يُختار مرة واحدة ويُخزَّن كما يُخزَّن معرّف الطابعة.
  static const String settingInvoicePrintOnSale = 'invoice_print_on_sale';
  static const String settingInvoicePdfExport = 'invoice_pdf_export';
  static const String settingInvoicePdfDirectory = 'invoice_pdf_directory';

  /// طباعة «ورقة المغسلة» (نسخة المحل) بعد فاتورة العميل — بنفس مقاس الورق.
  ///
  /// مفتاح واحد فقط بلا مقاس مستقلّ: الورقة تتبع `invoice_paper_size` دائمًا،
  /// فلا يمكن أن تخرج فاتورة 80 مم وورقة مغسلة A4 بسبب إعدادين متعارضين.
  static const String settingInvoicePrintLaundrySlip =
      'invoice_print_laundry_slip';

  // ─── الضريبة الموسّعة ───
  static const String settingTaxPricesInclude = 'tax_prices_include';
  static const String settingTaxApplyToSubscriptions =
      'tax_apply_to_subscriptions';
  static const String settingTaxApplyToDelivery = 'tax_apply_to_delivery';
  static const String settingTaxExemptCategories = 'tax_exempt_categories';
  static const String settingTaxShowInStatement = 'tax_show_in_statement';
  static const String settingTaxShowInCashReport = 'tax_show_in_cash_report';
  static const String settingTaxRegistered = 'tax_registered';
  static const String settingZatcaQrPhase1 = 'zatca_qr_phase1';
  static const String settingZatcaPhase2Prepared = 'zatca_phase2_prepared';
  static const String settingVatReturnBasis = 'vat_return_basis';

  // ─── ضريبة المدخلات على المصروفات ───
  static const String settingExpensesVatEnabled = 'expenses_vat_enabled';
  static const String settingExpensesDefaultVatRate =
      'expenses_default_vat_rate';
  static const String settingExpensesRequireTaxInvoice =
      'expenses_require_tax_invoice';

  // ─── الذمم ───
  static const String settingDefaultCreditLimit = 'default_credit_limit';
  static const String settingDebtProvisionRate = 'debt_provision_rate';
  static const String settingCreditBlockOnExceed = 'credit_block_on_exceed';
  static const String settingStatementFooterNote = 'statement_footer_note';
  static const String settingStatementShowTax = 'statement_show_tax';

  // ─── الاشتراكات ───
  static const String settingSubUsageWarnPercent = 'sub_usage_warn_percent';
  static const String settingSubRequirePaymentBeforeUse =
      'sub_require_payment_before_use';
  static const String settingSubGraceDays = 'sub_grace_days';
  static const String settingSubAutoRenew = 'sub_auto_renew';
  static const String settingSubBillingAnchorDay = 'sub_billing_anchor_day';

  // ─── المصنعية ───
  static const String settingProcessingEnabled = 'processing_enabled';
  static const String settingProcessingWorkflow = 'processing_workflow';
  static const String settingProcessingRequireWorker =
      'processing_require_worker';
  static const String settingProcessingSlaHours = 'processing_sla_hours';
  static const String settingProcessingAutoReadyHours =
      'processing_auto_ready_hours';
  static const String settingProcessingNotifyWhatsapp =
      'processing_notify_whatsapp';
  static const String settingProcessingPrintItemTags =
      'processing_print_item_tags';
  static const String settingMinOrderAmount = 'min_order_amount';

  // ─── مصنعية العمال ───
  static const String settingLaborCostEnabled = 'labor_cost_enabled';
  static const String settingLaborRatePerPiece = 'labor_rate_per_piece';
  static const String settingLaborRequireWorker = 'labor_require_worker';
  static const String settingLaborIncentiveThreshold =
      'labor_incentive_threshold';
  static const String settingLaborIncentivePercent = 'labor_incentive_percent';

  // ─── سلوك نقطة البيع ───
  static const String settingPosAutoPrint = 'pos_auto_print';
  static const String settingPosConfirmBeforePay = 'pos_confirm_before_pay';
  static const String settingPosDefaultPaymentMethod =
      'pos_default_payment_method';
  static const String settingPosSoundOnSale = 'pos_sound_on_sale';

  /// ترتيب أصناف اللبس في شاشة البيع — قيمته مفتاح من `ClothingSort`.
  static const String settingClothingSort = 'clothing_sort';

  // ─── الزبائن ───
  static const String settingCustomerRequirePhone = 'customer_require_phone';
  static const String settingCustomerDefaultTier = 'customer_default_tier';
  static const String settingLoyaltyRoundUp = 'loyalty_round_up';

  // ─── بيانات النشاط الإضافية ───
  static const String settingBusinessCrNumber = 'business_cr_number';
  static const String settingBusinessShortAddress = 'business_short_address';

  // ─── قيم افتراضية للخيارات الجديدة ───
  static const bool taxPricesIncludeByDefault = true;
  static const bool taxRegisteredByDefault = false;
  static const bool invoiceAllowCreditByDefault = true;
  static const bool invoiceAllowDiscountByDefault = true;
  static const bool invoiceRequireCustomerByDefault = false;
  static const String invoiceTitleTextDefault = 'فاتورة ضريبية مبسطة';
  static const String invoiceRoundingDefault = 'none';
  static const String invoicePaperSizeDefault = 'a4';
  static const String shiftPaperSizeDefault = 'a6';
  static const String statementPaperSizeDefault = 'a4';
  static const String labelPaperSizeDefault = 'label_50x30';
  /// الطريقة المحدَّدة عند **كل** فتح لنافذة الدفع في نقطة البيع.
  ///
  /// «شبكة» هي الافتراضي المطلوب تشغيليًّا؛ يمكن للموظف اختيار أي طريقة
  /// أخرى يدويًّا داخل النافذة، ويعود الافتراضي عند الفتح التالي.
  static const String posDefaultPaymentMethodDefault = 'card';
  static const String customerDefaultTierDefault = 'bronze';
  static const double defaultCreditLimitDefault = 0;
  static const double debtProvisionRateDefault = 0.25;
  static const int subUsageWarnPercentDefault = 80;
  static const int processingSlaHoursDefault = 24;
  static const double laborRatePerPieceDefault = 0;
  static const String processingWorkflowDefault = 'standard';

  // Invoice counter start — رقم أول فاتورة جديدة.
  static const int invoiceCounterStart = 1001;

  // حدّ أدنى لمدة الاحتفاظ بالفواتير: أي فاتورة من **السنة الجارية** لا
  // تُحذف مهما كان عمرها حمايةً للتقارير السنوية والشهرية، فالحد الفعلي سنة
  // ميلادية كاملة (400 يومًا). أي قيمة أقل تُرفع إليه ولا تُنقصه.
  static const int invoiceRetentionMinDays = 400;

  // Invoice auto-delete after days — قيمة احتياطية عند غياب المفتاح
  // (والقيمة الفعلية من `settingInvoiceRetentionDays`).
  static const int invoiceAutoDeleteDays = invoiceRetentionMinDays;

  // الحذف التلقائي للفواتير القديمة: **معطَّل افتراضيًا**.
  // حذف فواتير بلا إشعار يُفسد التقارير ويُفقد سجلًّا محاسبيًا، لذا لا يُفعَّل
  // إلا بقيمة صريحة ('1') في `settingInvoiceAutoDeleteEnabled` — وغياب
  // المفتاح يعني «معطَّل» كذلك.
  static const bool invoiceAutoDeleteEnabledByDefault = false;

  // نقاط الولاء: **مفعَّلة افتراضيًا** — النظام كان يحتسبها فعليًا قبل وجود
  // المفتاح، فالتعطيل الافتراضي يغيّر ترقيات الزبائن القائمة.
  static const bool loyaltyEnabledByDefault = true;

  // الضريبة: تُخزَّن نسبتها وتُضبط من الإعدادات، ولا تُضاف تلقائيًا إلى
  // حساب الفاتورة في هذه النسخة (بند مفتوح في الذاكرة المعمارية).
  static const bool taxEnabledByDefault = false;

  // ─── ترخيص النظام (تاريخ انتهاء اشتراك النظام) ───
  //
  // **المفتاح غيابه = غير محدود**: لا يُقفل النظام إلا بعد أن يُعطى تاريخًا
  // صراحةً، فلا تُقفل تثبيتات قائمة ولا نسخ تطوير بلا سبب.
  static const String settingSystemExpiryDate = 'system_expiry_date';

  /// كاش تاريخ الانتهاء في SharedPreferences — قراءة أسرع وبديل عند تعذّر
  /// قراءة القاعدة.
  static const String spSystemExpiryDate = 'cached_system_expiry_date';

  /// 🔧 **التاريخ الافتراضي المضمَّن في الكود** (`YYYY-MM-DD`) — عدّله هنا
  /// عند كل إصدار تريد أن يحمل صلاحية جديدة.
  ///
  /// قواعد تطبيقه (انظر `LicenseStatus.shouldSeed`):
  ///  - يُطبّق عند تثبيت جديد، أو حين يحمل الإصدار تاريخًا **لاحقًا** للمخزَّن.
  ///  - **لا يُقصّر أبدًا** صلاحية أبعد (تجديد يدوي يبقى نافذًا).
  ///  - يُطبَّق **مرة واحدة لكل قيمة** (يُسجَّل في [settingLicenseSeedApplied])،
  ///    فلا يمحو «بلا تاريخ» ولا تجديدًا يدويًا في كل تشغيل.
  ///  - اجعله `''` لإيقاف البذر تمامًا (نظام غير محدود).
  static const String defaultLicenseExpiryDate = '2027-09-11';

  /// يسجّل قيمة الكود التي طُبِّقت فعلًا — حارس «مرة واحدة لكل قيمة».
  static const String settingLicenseSeedApplied = 'license_seed_applied';

  /// آخر يوم شوهد فيه النظام (yyyy-MM-dd) — لكشف إرجاع ساعة الجهاز.
  static const String spLicenseLastSeen = 'cached_license_last_seen';

  /// آخر يوم عُرض فيه إشعار «قرب انتهاء الاشتراك» عند الدخول (yyyy-MM-dd).
  ///
  /// يمنع تكرار الإشعار مع كل دخول/خروج في اليوم نفسه — وهو إشعار تذكيري
  /// لا حاجز، فلا يصح أن يُقاطع الكاشير عشر مرات في وردية واحدة.
  static const String spLicenseNoticeDate = 'cached_license_notice_date';

  /// يعرض تحذير «يتبقى N يومًا» في آخر هذه المدة قبل الانتهاء.
  static const int licenseWarnDays = 7;

  /// الفاصل بين فحوص الترخيص أثناء عمل النظام.
  static const Duration licenseCheckInterval = Duration(hours: 1);

  // Pagination
  static const int defaultPageSize = 12;

  // Loyalty points rate (1 point per X riyals)
  static const int loyaltyPointsRate = 10; // 1 point per 10 riyals

  // Tax rate (VAT)
  static const double taxRate = 0.15; // 15%

  // Shift default start time
  static const String shiftStartTime = 'shift_start_time';

  // SharedPreferences Keys
  static const String spLogin = 'login';
  static const String spUsername = 'username';
  static const String spUserRole = 'user_role';
  static const String spCounterInvoice = 'counterinvoice';
  static const String spShiftActive = 'is_shift_active';
  static const String spActiveShiftId = 'active_shift_id';
  static const String spShiftStartTimeQuery = 'shift_start_time_query';
  static const String spShiftStartTimeDisplay = 'shift_start_time_display';
  static const String spBackupPath = 'backup_path';
  static const String spLastBackup = 'last_backup';
  static const String spDarkMode = 'dark_mode';
  static const String spFontSize = 'font_size';

  /// 🌐 لغة الواجهة — مفتاح خام في `settings` (مثل `font_size`) لا خيار في
  /// `SettingOptions`: تظهر في بطاقة «المظهر» لا في قائمة منسدلة عامة.
  /// قيمته كود من `AppLanguage` (`ar` · `en` · `system`).
  static const String settingLanguage = 'language';
}
