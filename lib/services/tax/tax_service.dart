import 'dart:convert';
import 'dart:typed_data';

/// تفصيل ضريبة فاتورة واحدة.
///
/// [base] = الأساس الخاضع (قبل الضريبة) · [tax] = مبلغ الضريبة ·
/// [gross] = ما يدفعه الزبون فعلًا (شامل الضريبة).
class TaxBreakdown {
  final double base;
  final double tax;
  final double gross;
  final double rate;

  const TaxBreakdown({
    required this.base,
    required this.tax,
    required this.gross,
    required this.rate,
  });

  bool get isEmpty => tax <= 0.004;

  static const TaxBreakdown none = TaxBreakdown(
    base: 0,
    tax: 0,
    gross: 0,
    rate: 0,
  );
}

/// ضريبة القيمة المضافة — **منطق خالص** بلا Flutter ولا قاعدة بيانات،
/// فيُختبر مباشرة.
///
/// ## القرار المحاسبي: الأسعار **شاملة** الضريبة
/// في تجزئة المغاسل السعودية السعر المعروض للزبون هو ما يدفعه، والضريبة
/// **داخله**. لذلك:
///
///     الأساس = الإجمالي ÷ (1 + النسبة)
///     الضريبة = الإجمالي − الأساس
///
/// ولا تُضاف الضريبة فوق السعر — إضافتها تعني أن الزبون يدفع أكثر من السعر
/// المعلن، وهو ما يخالف السعر المعروض ويُربك الكاشير والزبون معًا.
class TaxService {
  TaxService._();

  /// حساب الضريبة الشاملة لمبلغ.
  ///
  /// [gross] الإجمالي الذي يدفعه الزبون، و[rate] نسبة عشرية (0.15 = 15%).
  /// نسبة صفر أو سالبة ⇒ لا ضريبة، والأساس = الإجمالي.
  static TaxBreakdown inclusive(double gross, double rate) {
    final safeGross = gross > 0 ? gross : 0.0;
    if (rate <= 0 || safeGross <= 0) {
      return TaxBreakdown(
        base: _round(safeGross),
        tax: 0,
        gross: _round(safeGross),
        rate: 0,
      );
    }
    final base = safeGross / (1 + rate);
    final tax = safeGross - base;
    return TaxBreakdown(
      base: _round(base),
      tax: _round(tax),
      gross: _round(safeGross),
      rate: rate,
    );
  }

  /// نسبة الضريبة الفعلية المطبَّقة — صفر إن كان الخيار معطَّلًا.
  static double effectiveRate({
    required bool enabled,
    required double rate,
  }) {
    if (!enabled) return 0;
    if (rate <= 0 || rate > 1) return 0;
    return rate;
  }

  /// ترميز **QR هيئة الزكاة والضريبة والجمارك** (المرحلة الأولى).
  ///
  /// الصيغة المعتمدة: حقول TLV (وسم بايت + طول بايت + القيمة UTF-8) ثم
  /// Base64. الترتيب إلزامي:
  ///   1 اسم البائع · 2 الرقم الضريبي · 3 الطابع الزمني ·
  ///   4 الإجمالي شامل الضريبة · 5 مبلغ الضريبة.
  ///
  /// **لماذا هنا وليس في الواجهة؟** لأنه منطق خالص يُختبر، ووضعه في الـPDF
  /// كان يجعله غير قابل للاختبار.
  static String zatcaQrPayload({
    required String sellerName,
    required String vatNumber,
    required DateTime timestamp,
    required double totalWithVat,
    required double vatTotal,
  }) {
    final fields = <String>[
      sellerName,
      vatNumber,
      _isoLocal(timestamp),
      totalWithVat.toStringAsFixed(2),
      vatTotal.toStringAsFixed(2),
    ];

    final bytes = <int>[];
    for (var i = 0; i < fields.length; i++) {
      final value = utf8.encode(fields[i]);
      bytes.add(i + 1); // الوسم: 1..5
      bytes.add(value.length); // الطول: بايت واحد (القيم قصيرة دائمًا)
      bytes.addAll(value);
    }
    return base64.encode(Uint8List.fromList(bytes));
  }

  /// طابع زمني محلي بصيغة ISO 8601 بلا كسور — كما تتوقّعه الهيئة.
  static String _isoLocal(DateTime t) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${t.year}-${two(t.month)}-${two(t.day)}T${two(t.hour)}:${two(t.minute)}:${two(t.second)}';
  }

  /// تقريب مالي إلى منزلتين — يمنع ضوضاء الفاصلة العائمة في التقارير.
  static double _round(double v) => double.parse(v.toStringAsFixed(2));
}
