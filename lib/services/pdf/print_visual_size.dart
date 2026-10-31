/// **مقاس العناصر المرئية في المستند** (الشعار · رمز QR) — منطق خالص.
///
/// ## لماذا وحدة مستقلة؟
/// كان مقاس الشعار مربّعًا إجباريًّا (`invoice_logo_size` = بُعد واحد)، ورمز
/// الموقع مقاسًا ثابتًا في الكود لا يملكه المستخدم. والمطلوب أن يضبط
/// **العرض والارتفاع والمساحة** لكلٍّ منهما. لكن أي مقاس يضبطه المستخدم
/// يمكن أن يخرج عن الورقة، فيُقتطع النصّ أو ينفرد الشعار في صفحة كاملة.
///
/// فالقرار هنا واحد: **تُقبل القيمة، ثم تُقيَّد بالورق**، ويُعاد مع الناتج
/// **هل قُيِّدت فعلًا** حتى تعلن الواجهة ذلك بدل أن تُظهر رقمًا لا يُطبع.
///
/// ## الوحدات
/// المستخدم يضبط **بالمليمتر** (وحدة يفهمها)، والرسم **بالنقاط** (وحدة
/// `pdf`). التحويل هنا وحده، فلا تتفرّع قاعدة تحويل ثانية في الواجهة.
///
/// ## لماذا سقف للارتفاع لا للعرض فقط؟
/// العرض يتجاوز الورقة فيُقتطع الشعار (خطأ مرئي واضح). أما الارتفاع فيدفع
/// **الرأس كلّه** إلى صفحة ثانية: فاتورة تبدأ بصفحة شعار وباسم النشاط ثم
/// أصناف في صفحة تالية — وهو أسوأ من شعار صغير، ويحدث بلا أي رسالة. لذلك
/// يُقيَّد الارتفاع بنسبة من المساحة المطبوعة.
library;

import 'package:laundry/config/constants.dart';
import 'package:laundry/core/services/paper_size.dart';

/// صندوق مطبوع: العرض والارتفاع بالنقاط + هل قُيِّدت القيمة المطلوبة.
class VisualBox {
  /// العرض النهائي بالنقاط (بعد التقييد).
  final double width;

  /// الارتفاع النهائي بالنقاط (بعد التقييد).
  final double height;

  /// طُلب عرض أكبر من المتاح فضُغط إلى حدّ الورق.
  final bool widthClamped;

  /// طُلب ارتفاع أكبر من المسموح فضُغط إلى سقف الارتفاع.
  final bool heightClamped;

  const VisualBox({
    required this.width,
    required this.height,
    this.widthClamped = false,
    this.heightClamped = false,
  });

  bool get clamped => widthClamped || heightClamped;

  /// العرض بالمليمتر — ما سيراه المستخدم على الورقة.
  double get widthMm => width * 25.4 / 72.0;

  /// الارتفاع بالمليمتر.
  double get heightMm => height * 25.4 / 72.0;

  /// **المساحة** بالمليمتر المربّع — الرقم الذي طلبه المستخدم صراحةً.
  double get areaMm2 => widthMm * heightMm;

  /// هل الصندوق مربّع؟ (رمز QR يجب أن يكون مربّعًا وإلا صار غير قابل للقراءة)
  bool get isSquare => (width - height).abs() < 0.01;
}

/// حدود الصفحة المطبوعة — تُشتق من الورق المختار وحده.
class PrintablePage {
  final double widthMm;
  final double heightMm;
  final bool thermal;

  const PrintablePage({
    required this.widthMm,
    required this.heightMm,
    this.thermal = false,
  });

  double get widthPoints => widthMm * 72.0 / 25.4;
  double get heightPoints => heightMm * 72.0 / 25.4;

  double get areaMm2 => widthMm * heightMm;
}

class PrintVisualSize {
  PrintVisualSize._();

  /// أصغر بُعد مسموح بالنقاط — لا يسمح باختفاء العنصر بسبب قيمة شاذّة.
  static const double minPoints = 8;

  /// سقف ارتفاع الشعار: نسبة من المساحة المطبوعة.
  ///
  /// ٣٥٪: على A4 (≈274 مم مطبوعة) = 96 مم — أي أن الشعار لا يأكل أكثر من
  /// ثلث الصفحة، ويبقى للاسم والعنوان والأصناف ثلثان.
  static const double logoMaxHeightShare = 0.35;

  /// سقف ارتفاع رمز QR — نفس المنطق: الرمز آخر الورقة، ولا يجوز أن يزاحم
  /// الإجمالي والتذييل.
  static const double qrMaxHeightShare = 0.35;

  // ─── الورق ────────────────────────────────────────────────────────────

  /// الهامش الجانبي التصميمي بالمليمتر — نفس هوامش `PreparePDF`:
  /// حراري ٢ مم + ٠٫٥ أمان، وغيره ١ سم + ١٫٥ أمان.
  static double marginMm(PaperSize paper) => paper.isThermal ? 2.5 : 11.5;

  /// المساحة المطبوعة فعلًا للورق المختار (بلا هوامش).
  static PrintablePage pageOf(PaperSize paper) {
    final m = marginMm(paper);
    final w = paper.widthMm - m * 2;
    // الحراري ورق متصل: ارتفاعه التصميمي ٢٩٧ مم وهو سقف تقديري لا حدّ فعلي.
    final h = paper.heightMm - m * 2;
    return PrintablePage(
      widthMm: w > 10 ? w : 10,
      heightMm: h > 10 ? h : 10,
      thermal: paper.isThermal,
    );
  }

  // ─── قراءة القيمة ─────────────────────────────────────────────────────

  /// يقرأ قيمة مليمترية من أي شكل (`num` · `String` · `null`) ويحصرها.
  ///
  /// **لا يرمي أبدًا**: القيمة تأتي من JSON قديم أو من عزل `compute`، وفشل
  /// قراءة مقاس لا يجوز أن يمنع طباعة فاتورة.
  static double mmOf(
    Object? raw, {
    required double fallback,
    required double min,
    required double max,
  }) {
    final parsed = switch (raw) {
      num v => v.toDouble(),
      String v => double.tryParse(v.trim()),
      _ => null,
    };
    final value = parsed != null && parsed.isFinite ? parsed : fallback;
    if (value < min) return min;
    if (value > max) return max;
    return value;
  }

  // ─── الشعار ───────────────────────────────────────────────────────────

  /// صندوق الشعار: عرض وارتفاع مستقلّان، مقصوصان على الورق.
  ///
  /// [legacyMm] هو المفتاح القديم `invoice_logo_size` (بُعد واحد مربّع):
  /// يُستعمل للعرض والارتفاع معًا حين تغيب القيمتان الجديدتان، فتبقى أي
  /// حمولة قديمة (إعادة طباعة فاتورة سابقة) تُطبع بنفس الشكل.
  ///
  /// [maxWidth]/[maxHeight] بالنقاط من الورق الفعلي كما أبلغت به الطابعة —
  /// لا من الورق التصميمي، فلا يخرج الشعار عن ورق أضيق من المتوقّع.
  static VisualBox logo({
    Object? widthMm,
    Object? heightMm,
    Object? legacyMm,
    required double maxWidth,
    required double maxHeight,
  }) {
    final fallback = mmOf(
      legacyMm,
      fallback: AppConstants.invoiceLogoSizeDefaultMm.toDouble(),
      min: AppConstants.invoiceLogoWidthMinMm.toDouble(),
      max: AppConstants.invoiceLogoWidthMaxMm.toDouble(),
    );
    final wMm = mmOf(
      widthMm,
      fallback: fallback,
      min: AppConstants.invoiceLogoWidthMinMm.toDouble(),
      max: AppConstants.invoiceLogoWidthMaxMm.toDouble(),
    );
    final hMm = mmOf(
      heightMm,
      fallback: fallback,
      min: AppConstants.invoiceLogoHeightMinMm.toDouble(),
      max: AppConstants.invoiceLogoHeightMaxMm.toDouble(),
    );

    final safeWidth = maxWidth > minPoints ? maxWidth : minPoints;
    final heightCap =
        maxHeight > minPoints ? maxHeight * logoMaxHeightShare : minPoints;

    var w = PaperSizes.mmToPoints(wMm);
    var h = PaperSizes.mmToPoints(hMm);
    final wClamped = w > safeWidth;
    final hClamped = h > heightCap;
    if (wClamped) w = safeWidth;
    if (hClamped) h = heightCap;
    if (w < minPoints) w = minPoints;
    if (h < minPoints) h = minPoints;

    return VisualBox(
      width: w,
      height: h,
      widthClamped: wClamped,
      heightClamped: hClamped,
    );
  }

  // ─── رمز QR ───────────────────────────────────────────────────────────

  /// مربّع رمز QR: ضلع واحد، لأن الرمز غير المربّع **لا يُقرأ**.
  ///
  /// [sizeMm] من الإعداد (`map_qr_size`). يُقصّ على عرض الورق وسقف الارتفاع،
  /// ويبقى مربّعًا بعد القصّ (أصغر البعدين) — فلا يخرج مستطيلًا مشوّهًا.
  static VisualBox qr({
    Object? sizeMm,
    required double maxWidth,
    required double maxHeight,
  }) {
    final sideMm = mmOf(
      sizeMm,
      fallback: AppConstants.mapQrSizeDefaultMm.toDouble(),
      min: AppConstants.mapQrSizeMinMm.toDouble(),
      max: AppConstants.mapQrSizeMaxMm.toDouble(),
    );

    final safeWidth = maxWidth > minPoints ? maxWidth : minPoints;
    final heightCap =
        maxHeight > minPoints ? maxHeight * qrMaxHeightShare : minPoints;
    final cap = safeWidth < heightCap ? safeWidth : heightCap;

    var side = PaperSizes.mmToPoints(sideMm);
    final clamped = side > cap;
    if (clamped) side = cap;
    if (side < minPoints) side = minPoints;

    return VisualBox(
      width: side,
      height: side,
      widthClamped: clamped,
      heightClamped: clamped,
    );
  }

  // ─── الحساب المعلن ────────────────────────────────────────────────────

  /// نسبة مساحة العنصر من مساحة الورق المطبوعة (٠..١).
  ///
  /// تُعرض في الإعدادات كي يرى المستخدم **أثر رقمه** لا رقمه وحده.
  static double shareOfPage(VisualBox box, PrintablePage page) {
    final total = page.areaMm2;
    if (total <= 0) return 0;
    final share = box.areaMm2 / total;
    return share < 0 ? 0 : (share > 1 ? 1 : share);
  }

  /// مجموع ارتفاع الشعار والرمز كنسبة من ارتفاع الورق.
  ///
  /// هو الرقم الذي يُنبّه عليه: تجاوز **٦٠٪** يعني أن الرأس والتذييل يأكلان
  /// أغلب الورقة، فيتزاحم النصّ أو يُدفع إلى صفحة ثانية.
  static double verticalBudget(
    VisualBox logo,
    VisualBox qr,
    PrintablePage page,
  ) {
    if (page.heightPoints <= 0) return 0;
    return (logo.height + qr.height) / page.heightPoints;
  }

  /// حدّ التنبيه: نصف الورقة تقريبًا. فوقه تظهر ملاحظة في الإعدادات.
  static const double verticalBudgetWarn = 0.60;
}
