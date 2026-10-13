/// مقاسات الورق المدعومة — منطق خالص (بلا Flutter) قابل للاختبار.
///
/// كل مستند له مقاس افتراضي يختاره المستخدم من الإعدادات (`printing`)، ويُمكن
/// إظهار «كل المقاسات» في حوار الطباعة. الوحدة هنا بالمليمتر ثم تُحوَّل إلى
/// نقاط PDF (72 نقطة/بوصة) في موضع البناء.
library;

/// مقاس ورق بالمليمتر.
class PaperSize {
  final String token;
  final String label;
  final double widthMm;

  /// الارتفاع بالمليمتر. الحرارية ارتفاعها مفتوح (تُضبط لأطول صفحة).
  final double heightMm;

  /// هل العرض حراري (إيصال)؟ يُستعمل لضبط الهوامش وحجم الخط.
  final bool isThermal;

  const PaperSize({
    required this.token,
    required this.label,
    required this.widthMm,
    required this.heightMm,
    this.isThermal = false,
  });
}

class PaperSizes {
  PaperSizes._();

  static const PaperSize a4 = PaperSize(
    token: 'a4',
    label: 'A4',
    widthMm: 210,
    heightMm: 297,
  );
  static const PaperSize a5 = PaperSize(
    token: 'a5',
    label: 'A5',
    widthMm: 148,
    heightMm: 210,
  );
  static const PaperSize a6 = PaperSize(
    token: 'a6',
    label: 'A6',
    widthMm: 105,
    heightMm: 148,
  );
  static const PaperSize receipt80 = PaperSize(
    token: 'receipt_80mm',
    label: 'حراري 80 مم',
    widthMm: 80,
    heightMm: 297,
    isThermal: true,
  );
  static const PaperSize receipt58 = PaperSize(
    token: 'receipt_58mm',
    label: 'حراري 58 مم',
    widthMm: 58,
    heightMm: 297,
    isThermal: true,
  );
  static const PaperSize label50x30 = PaperSize(
    token: 'label_50x30',
    label: 'ملصق 50×30 مم',
    widthMm: 50,
    heightMm: 30,
    isThermal: true,
  );
  static const PaperSize label40x30 = PaperSize(
    token: 'label_40x30',
    label: 'ملصق 40×30 مم',
    widthMm: 40,
    heightMm: 30,
    isThermal: true,
  );

  static const List<PaperSize> all = <PaperSize>[
    a4,
    a5,
    a6,
    receipt80,
    receipt58,
    label50x30,
    label40x30,
  ];

  /// المقاس المطابق لرمز، أو A4 كأمان عند رمز غير معروف.
  static PaperSize resolve(String? token) {
    for (final size in all) {
      if (size.token == token) return size;
    }
    return a4;
  }

  /// تحويل مليمتر إلى نقاط PDF.
  static double mmToPoints(double mm) => mm * 72.0 / 25.4;
}
