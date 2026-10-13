import 'package:laundry/config/constants.dart';
import 'package:laundry/services/settings/setting_option.dart';
import 'package:laundry/services/tax/tax_service.dart';

/// أوضاع تقريب الإجمالي المستحق.
class TaxRounding {
  TaxRounding._();

  static const String none = 'none';
  static const String nearest005 = 'nearest_0.05';
  static const String nearest025 = 'nearest_0.25';
  static const String nearest1 = 'nearest_1';

  /// تقريب مبلغ حسب الوضع المختار (بلا تقريب ⇒ القيمة كما هي).
  static double apply(double value, String mode) {
    final step = switch (mode) {
      nearest005 => 0.05,
      nearest025 => 0.25,
      nearest1 => 1.0,
      _ => 0.0,
    };
    if (step <= 0) return _round2(value);
    return _round2((value / step).roundToDouble() * step);
  }

  static double _round2(double v) => double.parse(v.toStringAsFixed(2));
}

/// **السياسة الضريبية الكاملة** — منطق خالص يجمع كل خيارات الضريبة في كائن
/// واحد تستهلكه كل الوحدات.
///
/// **لماذا كائن واحد؟** لأن الضريبة كانت تُقرأ من موضعين متفرّقين (`taxEnabled`
/// و`taxRate`) وتُحسب يدويًا في كل متحكّم، فلم يكن ممكنًا تطبيق خيارات مثل
/// «الأسعار شاملة أم لا» أو «إخضاع الاشتراكات» أو «تصنيفات معفاة» في كل
/// المواضع باتساق. هنا القرار كله في موضع واحد مختبَر بلا قاعدة بيانات:
///
///     dart run tool/verify_tax_policy.dart
class TaxPolicy {
  /// المفتاح الأكبر: خضوع النظام للضريبة.
  final bool enabled;

  /// هل النشاط مسجَّل لدى الهيئة (يسمح بالـQR والتكامل)؟
  final bool registered;

  /// النسبة العشرية (0.15 = 15%).
  final double rate;

  /// الأسعار المعروضة شاملة الضريبة أم تُضاف فوقها.
  final bool pricesInclude;

  /// إخضاع فواتير الاشتراكات للضريبة.
  final bool applyToSubscriptions;

  /// إخضاع رسوم التوصيل.
  final bool applyToDelivery;

  /// أرقام التصنيفات المعفاة (نسبة صفرية).
  final Set<int> exemptCategoryIds;

  /// وضع تقريب الإجمالي.
  final String rounding;

  /// أساس الإقرار الضريبي: `accrual` أو `cash`.
  final String vatReturnBasis;

  const TaxPolicy({
    required this.enabled,
    required this.registered,
    required this.rate,
    required this.pricesInclude,
    required this.applyToSubscriptions,
    required this.applyToDelivery,
    required this.exemptCategoryIds,
    required this.rounding,
    required this.vatReturnBasis,
  });

  /// سياسة معطَّلة — تُستعمل عند تعذّر القراءة.
  static const TaxPolicy off = TaxPolicy(
    enabled: false,
    registered: false,
    rate: 0,
    pricesInclude: true,
    applyToSubscriptions: false,
    applyToDelivery: true,
    exemptCategoryIds: <int>{},
    rounding: TaxRounding.none,
    vatReturnBasis: 'accrual',
  );

  /// بناء السياسة من قارئ خام (يُراعى سلسلة التفعيل).
  factory TaxPolicy.fromReader(String? Function(String key) readRaw) {
    bool on(String key) {
      final option = SettingOptions.byKey(key);
      if (option == null) return false;
      return isEffectivelyOn(option, readRaw);
    }

    num numOf(String key, num fallback) {
      final option = SettingOptions.byKey(key);
      if (option == null) return fallback;
      return num.tryParse(readRaw(key) ?? '') ?? fallback;
    }

    return TaxPolicy(
      enabled: on(AppConstants.settingTaxEnabled),
      registered: isTruthy(readRaw(AppConstants.settingTaxRegistered)),
      rate: numOf(AppConstants.settingTaxRate, 0.15).toDouble(),
      pricesInclude:
          !(readRaw(AppConstants.settingTaxPricesInclude) == '0'),
      applyToSubscriptions: isTruthy(
        readRaw(AppConstants.settingTaxApplyToSubscriptions),
      ),
      applyToDelivery: readRaw(AppConstants.settingTaxApplyToDelivery) != '0',
      exemptCategoryIds: _parseIds(
        readRaw(AppConstants.settingTaxExemptCategories),
      ),
      rounding:
          readRaw(AppConstants.settingInvoiceRounding) ?? TaxRounding.none,
      vatReturnBasis:
          readRaw(AppConstants.settingVatReturnBasis) ?? 'accrual',
    );
  }

  /// هل الضريبة نافذة فعلًا (مفعّلة ونسبتها موجبة)؟
  bool get isActive => enabled && rate > 0 && rate <= 1;

  /// النسبة الفعلية المطبَّقة على عملية ما (صفر إن كانت معفاة أو معطَّلة).
  double effectiveRate({
    bool exempt = false,
    bool isSubscription = false,
    bool isDelivery = false,
  }) {
    if (!isActive) return 0;
    if (exempt) return 0;
    if (isSubscription && !applyToSubscriptions) return 0;
    if (isDelivery && !applyToDelivery) return 0;
    return rate;
  }

  /// تفصيل ضريبة مبلغ واحد وفق السياسة.
  ///
  /// - شامل التسعير: `base = amount/(1+r)` والضريبة تُستخرج منه.
  /// - غير شامل: `tax = amount×r` والإجمالي المستحق = amount + tax.
  TaxBreakdown apply(
    double amount, {
    bool exempt = false,
    bool isSubscription = false,
    bool isDelivery = false,
    int? categoryId,
  }) {
    final r = effectiveRate(
      exempt: exempt || (categoryId != null && exemptCategoryIds.contains(categoryId)),
      isSubscription: isSubscription,
      isDelivery: isDelivery,
    );
    if (r <= 0) {
      final v = amount > 0 ? amount : 0.0;
      return TaxBreakdown(base: _r2(v), tax: 0, gross: _r2(v), rate: 0);
    }
    if (pricesInclude) return TaxService.inclusive(amount, r);
    final base = amount > 0 ? amount : 0.0;
    final tax = base * r;
    return TaxBreakdown(
      base: _r2(base),
      tax: _r2(tax),
      gross: _r2(base + tax),
      rate: r,
    );
  }

  /// تقريب المبلغ المستحق حسب الوضع المختار.
  double roundPayable(double value) => TaxRounding.apply(value, rounding);

  static Set<int> _parseIds(String? raw) {
    final text = (raw ?? '').trim();
    if (text.isEmpty) return const <int>{};
    return text
        .split(RegExp(r'[,،\s]+'))
        .map((s) => int.tryParse(s.trim()))
        .whereType<int>()
        .toSet();
  }

  static double _r2(double v) => double.parse(v.toStringAsFixed(2));
}
