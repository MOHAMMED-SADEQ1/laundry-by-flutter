import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:laundry/services/catalog/clothing_sort.dart';
import 'package:laundry/services/i18n/doc_language.dart';
import 'package:laundry/services/security/session_manager.dart';
import 'package:laundry/services/settings/setting_option.dart';
import 'package:laundry/services/tax/tax_policy.dart';
import 'package:laundry/sqldb.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// مركز **قيم النظام القابلة للضبط** (خيارات شاشة الإعدادات).
///
/// **الطبقات الثلاث للقراءة:**
///   1. القيمة المخزَّنة في جدول `settings` — المصدر الأساسي.
///   2. القيمة الافتراضية للخيار في [SettingOptions] — عند غياب المفتاح.
///   3. كاش SharedPreferences — بديل عند تعذّر قراءة القاعدة.
///
/// **الكتابة** تمرّ دائمًا عبر [set]: تطبيع للقيمة (نوع + حدود) ثم كتابة
/// upsert، ثم كاش، ثم سجل تدقيق — فالقيم هنا تجارية (ضريبة · ولاء · ترقيم ·
/// احتفاظ بالبيانات) وتغييرها يجب أن يُعرف من نفّذه ومتى.
///
/// **بلا Flutter UI:** طبقة خدمة كنمط `BusinessInfoService`، فلا تتعلّق
/// بإدارة الحالة. شاشة الإعدادات تقرأ من متحكّمها وتحدّث عبره.
class AppSettingsService {
  AppSettingsService._();
  static final AppSettingsService instance = AppSettingsService._();

  /// بادئة كاش كل قيمة في SharedPreferences — مفتاح واحد لكل خيار.
  static const String _cachePrefix = 'cached_app_setting_';

  final SqlDB _db = SqlDB();

  /// القيم الخام كما هي مخزَّنة (تُطبَّع عند القراءة حسب نوع الخيار).
  final Map<String, String> _values = <String, String>{};
  bool _loaded = false;

  bool get isLoaded => _loaded;

  /// يقرأ كل مفاتيح [SettingOptions] من جدول `settings` ويهيّئ الكاش.
  ///
  /// يُستدعى عند الإقلاع (`main`) قبل `runApp` — أي قبل تشغيل مؤقّت الترخيص
  /// وأول قراءة لأي قيمة. وأي فشل يُلتقط ويُكمل من الكاش فلا يُسقط الإقلاع.
  Future<void> load() async {
    try {
      final rows = await _db.safeRead('settings');
      for (final row in rows) {
        final key = row['key']?.toString() ?? '';
        if (key.isEmpty || SettingOptions.byKey(key) == null) continue;
        _values[key] = row['value']?.toString() ?? '';
      }
      _loaded = true;
      await _cacheToPrefs();
    } catch (e) {
      debugPrint('AppSettingsService.load error: $e');
      await _loadFromCache();
    }
  }

  /// القيمة المطبَّعة للخيار (مخزَّنة، وإلا الافتراضية).
  String rawOf(SettingOption option) =>
      normalizeValue(option, _values[option.key] ?? option.defaultValue);

  /// هل الخيار مُفعَّل؟ (غياب القيمة أو أي نص غير صريح = معطَّل).
  bool isOn(SettingOption option) => isTruthy(rawOf(option));

  /// القيمة العددية المطبَّعة.
  int integerOf(SettingOption option) => intValueOf(option, rawOf(option));

  /// القيمة العشرية المطبَّعة.
  double decimalOf(SettingOption option) =>
      doubleValueOf(option, rawOf(option));

  // ─── قراءات جاهزة للمستهلكين ───

  /// رقم أول فاتورة جديدة.
  int get invoiceStart => integerOf(SettingOptions.invoiceStart);

  /// عدد الفواتير في الصفحة الواحدة.
  int get pageSize => integerOf(SettingOptions.pageSize);

  bool get invoiceAutoDeleteEnabled =>
      isOn(SettingOptions.invoiceAutoDeleteEnabled);

  int get invoiceRetentionDays =>
      integerOf(SettingOptions.invoiceRetentionDays);

  bool get loyaltyEnabled => isOn(SettingOptions.loyaltyEnabled);

  /// نقطة واحدة لكل هذا المبلغ (لا يقلّ عن 1 — تجنّبًا لقسمة على صفر).
  int get loyaltyRate {
    final rate = integerOf(SettingOptions.loyaltyRate);
    return rate < 1 ? 1 : rate;
  }

  bool get taxEnabled => isOn(SettingOptions.taxEnabled);

  /// النسبة العشرية للضريبة (0.15 = 15%).
  double get taxRate => decimalOf(SettingOptions.taxRate);

  String get currency => rawOf(SettingOptions.currency);

  int get licenseWarnDays => integerOf(SettingOptions.licenseWarnDays);

  /// فاصل فحص الترخيص أثناء العمل.
  Duration get licenseCheckInterval =>
      Duration(hours: integerOf(SettingOptions.licenseCheckHours));

  // ─── قراءات القيمة الفعلية (مراعية سلسلة التفعيل) ───

  /// القيمة الخام المخزَّنة لمفتاح (بلا تطبيع).
  String? stored(String key) => _values[key];

  /// هل الخيار مُفعَّل فعلًا (نفسه وكل أسلافه)؟
  bool effectiveOn(SettingOption option) => isEffectivelyOn(option, stored);

  /// القيمة الفعلية لخيار بعد مراعاة سلسلة التفعيل.
  String effectiveOf(SettingOption option) => effectiveValue(option, stored);

  /// قيمة منطقية فعلية لمفتاح مسجَّل.
  bool effectiveBool(String key) {
    final option = SettingOptions.byKey(key);
    if (option == null) return false;
    return effectiveOn(option);
  }

  /// قيمة نصية فعلية لمفتاح مسجَّل (أو الخام إن لم يكن مسجَّلًا).
  String effectiveText(String key) {
    final option = SettingOptions.byKey(key);
    if (option == null) return _values[key] ?? '';
    return effectiveOf(option);
  }

  /// قيمة عددية فعلية لمفتاح مسجَّل.
  int effectiveInt(String key) {
    final option = SettingOptions.byKey(key);
    if (option == null) return 0;
    return intValueOf(option, effectiveOf(option));
  }

  /// قيمة عشرية فعلية لمفتاح مسجَّل.
  double effectiveDecimal(String key) {
    final option = SettingOptions.byKey(key);
    if (option == null) return 0;
    return doubleValueOf(option, effectiveOf(option));
  }

  // ─── الفاتورة والترقيم ───

  String get invoiceNumberPrefix => rawOf(SettingOptions.invoiceNumberPrefix);
  int get invoiceNumberPadding =>
      integerOf(SettingOptions.invoiceNumberPadding);
  bool get invoiceRequireCustomer =>
      isOn(SettingOptions.invoiceRequireCustomer);
  bool get invoiceAllowCredit => isOn(SettingOptions.invoiceAllowCredit);
  bool get invoiceAllowDiscount => isOn(SettingOptions.invoiceAllowDiscount);

  /// هل يُسمح بالبيع الآجل فعليًا (الخيار + صلاحية المستخدم)؟
  bool get creditAllowed => invoiceAllowCredit;

  // ─── ما يظهر على الفاتورة ───

  /// **لغة المستندات المطبوعة** — مستقلة تمامًا عن لغة الواجهة.
  ///
  /// لا تقرأ `settings.language` ولا `L10n`: تبديل لغة الشاشة لا يجوز أن
  /// يغيّر لغة الفاتورة الضريبية. القيمة الافتراضية عربية (المطلوبة نظامًا)،
  /// وأي قيمة مخزَّنة مجهولة تسقط للافتراضي بدل تعطيل الطباعة.
  DocLanguage get docLanguage =>
      DocLanguage.byCode(rawOf(SettingOptions.docLanguage));

  String get invoiceTitleText => rawOf(SettingOptions.invoiceTitleText);
  bool get invoiceShowLogo => isOn(SettingOptions.invoiceShowLogo);

  /// عرض الشعار بالمليمتر — يُقصّ على الورق عند الرسم لا هنا.
  int get invoiceLogoWidthMm => integerOf(SettingOptions.invoiceLogoWidth);

  /// ارتفاع الشعار بالمليمتر.
  int get invoiceLogoHeightMm => integerOf(SettingOptions.invoiceLogoHeight);

  /// ضلع رمز QR لموقع النشاط بالمليمتر.
  int get mapQrSizeMm => integerOf(SettingOptions.mapQrSize);
  bool get invoiceShowTaxNumber => isOn(SettingOptions.invoiceShowTaxNumber);
  bool get invoiceShowCrNumber => isOn(SettingOptions.invoiceShowCrNumber);
  bool get invoiceShowShortAddress =>
      isOn(SettingOptions.invoiceShowShortAddress);
  bool get invoiceShowCashier => isOn(SettingOptions.invoiceShowCashier);
  bool get invoiceShowDatetime => isOn(SettingOptions.invoiceShowDatetime);
  bool get invoiceShowPickupCode => isOn(SettingOptions.invoiceShowPickupCode);
  bool get invoiceShowCustomerPhone =>
      isOn(SettingOptions.invoiceShowCustomerPhone);
  bool get invoiceShowDiscountLine =>
      isOn(SettingOptions.invoiceShowDiscountLine);
  bool get invoiceShowPaid => isOn(SettingOptions.invoiceShowPaid);
  bool get invoiceShowRemaining => isOn(SettingOptions.invoiceShowRemaining);
  String get invoiceFooterNote => rawOf(SettingOptions.invoiceFooterNote);
  String get invoiceRoundingValue => rawOf(SettingOptions.invoiceRounding);

  /// سطر الضريبة يظهر فعلًا عند تفعيل الخيار والضريبة معًا.
  bool get invoiceShowTaxLine => effectiveOn(SettingOptions.invoiceShowTaxLine);
  bool get invoiceShowTaxBase => effectiveOn(SettingOptions.invoiceShowTaxBase);
  bool get invoiceShowQr => effectiveOn(SettingOptions.invoiceShowQr);

  // ─── الطباعة ───

  /// مفتاح خطّ الطباعة المحفوظ (قد يكون مجهولًا إن جاء من نسخة قديمة).
  ///
  /// لا يُستعمل مباشرة: `PrintFonts.byKey` تُسقط المجهول إلى الافتراضي،
  /// و`PrintFontService` هي التي تُحمّل الملفّ.
  String get printFontKey => rawOf(SettingOptions.printFont);

  String get invoicePaperSize => rawOf(SettingOptions.invoicePaperSize);
  String get shiftPaperSize => rawOf(SettingOptions.shiftPaperSize);
  String get statementPaperSize => rawOf(SettingOptions.statementPaperSize);
  String get labelPaperSize => rawOf(SettingOptions.labelPaperSize);
  bool get printAskSizeEachTime => isOn(SettingOptions.printAskSizeEachTime);
  bool get printAutoAfterSale => isOn(SettingOptions.printAutoAfterSale);
  String get printAutoPaperSize => rawOf(SettingOptions.printAutoPaperSize);
  int get invoiceCopies => integerOf(SettingOptions.invoiceCopies);
  String get receiptFooterNote => rawOf(SettingOptions.receiptFooterNote);

  /// هل تُطبع ورقة المغسلة (نسخة المحل) مع فاتورة العميل؟
  ///
  /// **لا مقاس خاص بها**: تُطبع دائمًا بنفس [invoicePaperSize].
  bool get invoicePrintLaundrySlip =>
      isOn(SettingOptions.invoicePrintLaundrySlip);

  // ─── الضريبة ───

  bool get taxPricesInclude => isOn(SettingOptions.taxPricesInclude);
  bool get taxApplyToSubscriptions =>
      effectiveOn(SettingOptions.taxApplyToSubscriptions);
  bool get taxApplyToDelivery => effectiveOn(SettingOptions.taxApplyToDelivery);
  String get taxExemptCategories =>
      effectiveText(SettingOptions.taxExemptCategories.key);
  bool get taxShowInStatement => effectiveOn(SettingOptions.taxShowInStatement);
  bool get taxShowInCashReport =>
      effectiveOn(SettingOptions.taxShowInCashReport);
  bool get taxRegistered => isOn(SettingOptions.taxRegistered);
  bool get zatcaQrPhase1 => effectiveOn(SettingOptions.zatcaQrPhase1);
  bool get zatcaPhase2Prepared =>
      effectiveOn(SettingOptions.zatcaPhase2Prepared);
  String get vatReturnBasis =>
      effectiveText(SettingOptions.vatReturnBasis.key).isEmpty
          ? 'accrual'
          : effectiveText(SettingOptions.vatReturnBasis.key);

  /// هل يتصل النظام بالهيئة فعلًا؟ لا — الربط الفعلي مُجهّز فقط.
  bool get zatcaOnlineEnabled => false;

  /// **السياسة الضريبية الكاملة** — مصدر واحد يستهلكه كل النظام.
  TaxPolicy get taxPolicy => TaxPolicy.fromReader(stored);

  // ─── ضريبة المدخلات ───

  bool get expensesVatEnabled => isOn(SettingOptions.expensesVatEnabled);
  double get expensesDefaultVatRate =>
      effectiveDecimal(SettingOptions.expensesDefaultVatRate.key);
  bool get expensesRequireTaxInvoice =>
      effectiveOn(SettingOptions.expensesRequireTaxInvoice);

  // ─── الذمم ───

  double get defaultCreditLimit => decimalOf(SettingOptions.defaultCreditLimit);
  double get debtProvisionRate => decimalOf(SettingOptions.debtProvisionRate);
  bool get creditBlockOnExceed => isOn(SettingOptions.creditBlockOnExceed);
  bool get statementShowTax => effectiveOn(SettingOptions.statementShowTax);
  String get statementFooterNote => rawOf(SettingOptions.statementFooterNote);

  // ─── الاشتراكات ───

  int get subUsageWarnPercent => integerOf(SettingOptions.subUsageWarnPercent);
  bool get subRequirePaymentBeforeUse =>
      isOn(SettingOptions.subRequirePaymentBeforeUse);
  int get subGraceDays => integerOf(SettingOptions.subGraceDays);
  bool get subAutoRenew => isOn(SettingOptions.subAutoRenew);
  int get subBillingAnchorDay => integerOf(SettingOptions.subBillingAnchorDay);

  // ─── المصنعية ───

  bool get processingEnabled => isOn(SettingOptions.processingEnabled);
  String get processingWorkflow => rawOf(SettingOptions.processingWorkflow);
  bool get processingRequireWorker =>
      effectiveOn(SettingOptions.processingRequireWorker);
  int get processingSlaHours =>
      effectiveInt(SettingOptions.processingSlaHours.key);
  int get processingAutoReadyHours =>
      effectiveInt(SettingOptions.processingAutoReadyHours.key);
  bool get processingNotifyWhatsapp =>
      effectiveOn(SettingOptions.processingNotifyWhatsapp);
  bool get processingPrintItemTags =>
      effectiveOn(SettingOptions.processingPrintItemTags);
  double get minOrderAmount =>
      effectiveDecimal(SettingOptions.minOrderAmount.key);

  // ─── مصنعية العمال ───

  bool get laborCostEnabled => isOn(SettingOptions.laborCostEnabled);
  double get laborRatePerPiece =>
      effectiveDecimal(SettingOptions.laborRatePerPiece.key);
  bool get laborRequireWorker => effectiveOn(SettingOptions.laborRequireWorker);
  int get laborIncentiveThreshold =>
      effectiveInt(SettingOptions.laborIncentiveThreshold.key);
  double get laborIncentivePercent =>
      effectiveDecimal(SettingOptions.laborIncentivePercent.key);

  // ─── نقطة البيع ───

  bool get posAutoPrint => isOn(SettingOptions.posAutoPrint);
  bool get posConfirmBeforePay => isOn(SettingOptions.posConfirmBeforePay);
  String get posDefaultPaymentMethod =>
      rawOf(SettingOptions.posDefaultPaymentMethod);
  bool get posSoundOnSale => isOn(SettingOptions.posSoundOnSale);

  /// ترتيب بطاقات الأصناف في شاشة البيع (مفتاح من [ClothingSort]).
  ClothingSort get clothingSort =>
      ClothingSort.byKey(rawOf(SettingOptions.clothingSort));

  /// عدد أعمدة شبكة «الأصناف والخدمات» — صفر يعني تلقائيًا حسب عرض الشاشة.
  int get homeGridColumns =>
      int.tryParse(rawOf(SettingOptions.homeGridColumns)) ?? 0;

  // ─── الزبائن والولاء ───

  bool get customerRequirePhone => isOn(SettingOptions.customerRequirePhone);
  String get customerDefaultTier => rawOf(SettingOptions.customerDefaultTier);
  bool get loyaltyRoundUp => effectiveOn(SettingOptions.loyaltyRoundUp);

  /// يكتب قيمة خيار ويعيد القيمة **المطبَّعة** فعلًا (بعد الحدود والنوع).
  ///
  /// المفتاح غير المسجَّل يُكتب كما هو (نمط متسامح لإعدادات أخرى).
  Future<String> set(String key, String raw) async {
    final option = SettingOptions.byKey(key);
    if (option == null) {
      await _db.updateSetting(key, raw);
      return raw;
    }
    final applied = normalizeValue(option, raw);
    await _db.updateSetting(option.key, applied);
    _values[option.key] = applied;
    await _cacheOne(option.key, applied);
    await _logChange(option.key, applied);
    return applied;
  }

  /// سجل تدقيق لكل تغيير — من غيّر أي قيمة وإلى ما صارت.
  Future<void> _logChange(String key, String value) async {
    try {
      await _db.logAudit(
        userId: SessionManager.currentUserId,
        action: 'setting_update',
        tableName: 'settings',
        newValues: jsonEncode({'key': key, 'value': value}),
      );
    } catch (e) {
      debugPrint('setting audit skipped: $e');
    }
  }

  Future<void> _cacheToPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      for (final entry in _values.entries) {
        await prefs.setString('$_cachePrefix${entry.key}', entry.value);
      }
    } catch (e) {
      debugPrint('app settings cache error: $e');
    }
  }

  Future<void> _cacheOne(String key, String value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('$_cachePrefix$key', value);
    } catch (e) {
      debugPrint('app setting cache error: $e');
    }
  }

  /// القيم من الكاش عند تعذّر القاعدة — والغياب يُكمل بالافتراضي عند القراءة.
  Future<void> _loadFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      for (final option in SettingOptions.all) {
        final cached = prefs.getString('$_cachePrefix${option.key}');
        if (cached != null) _values[option.key] = cached;
      }
      _loaded = true;
    } catch (e) {
      debugPrint('AppSettingsService._loadFromCache error: $e');
    }
  }
}
