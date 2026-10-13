/// **الإقرار الضريبي المبسّط** — منطق خالص يجمع ضريبة المخرجات وضريبة
/// المدخلات إلى صافي المستحق للهيئة.
///
///     الصافي المستحق = ضريبة المخرجات − ضريبة المدخلات
///
/// موجب ⇒ مستحق على المنشأة، وسالب ⇒ رصيد دائن يُرحَّل. والمنطق هنا خالص
/// ليُختبر بلا قاعدة بيانات:
///
///     dart run tool/verify_vat_return.dart
library;

class VatReturn {
  /// الأساس الخاضع للمبيعات (صافي الضريبة).
  final double salesBase;

  /// ضريبة المخرجات (المحصّلة على المبيعات).
  final double outputTax;

  /// الأساس الخاضع للمشتريات/المصروفات.
  final double purchasesBase;

  /// ضريبة المدخلات (القابلة للخصم).
  final double inputTax;

  /// عدد الفواتير الداخلة في التجميع.
  final int invoiceCount;

  /// المبيعات المعفاة/الصفرية (نسبة صفر).
  final double exemptSales;

  const VatReturn({
    this.salesBase = 0,
    this.outputTax = 0,
    this.purchasesBase = 0,
    this.inputTax = 0,
    this.invoiceCount = 0,
    this.exemptSales = 0,
  });

  static const VatReturn empty = VatReturn();

  /// الصافي المستحق (موجب مستحق · سالب دائن).
  double get netPayable =>
      double.parse((outputTax - inputTax).toStringAsFixed(2));

  /// هل الصافي لصالح المنشأة (رصيد دائن)؟
  bool get isCredit => netPayable < 0;

  /// بناء إقرار من مجاميع جاهزة (تأتي من القاعدة).
  factory VatReturn.compute({
    required double salesBase,
    required double outputTax,
    required double purchasesBase,
    required double inputTax,
    int invoiceCount = 0,
    double exemptSales = 0,
  }) => VatReturn(
    salesBase: _r2(salesBase),
    outputTax: _r2(outputTax),
    purchasesBase: _r2(purchasesBase),
    inputTax: _r2(inputTax),
    invoiceCount: invoiceCount,
    exemptSales: _r2(exemptSales),
  );

  /// إقرار مدمج: يجمع إقرارين (مثلاً شهريان في ربع واحد).
  VatReturn plus(VatReturn other) => VatReturn(
    salesBase: _r2(salesBase + other.salesBase),
    outputTax: _r2(outputTax + other.outputTax),
    purchasesBase: _r2(purchasesBase + other.purchasesBase),
    inputTax: _r2(inputTax + other.inputTax),
    invoiceCount: invoiceCount + other.invoiceCount,
    exemptSales: _r2(exemptSales + other.exemptSales),
  );

  static double _r2(double v) => double.parse(v.toStringAsFixed(2));
}
