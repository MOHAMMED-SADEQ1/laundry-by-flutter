import 'dart:math' as math;

import 'package:pdf/pdf.dart' show PdfPageFormat;

/// **تخطيط الطباعة الفعلي** كما يبلّغ عنه تعريف الطابعة على ويندوز.
///
/// ## المشكلة التي يحلّها
/// مولّد الفاتورة يبني صفحة بمقاس الورق المختار وهامش تصميم (١ سم)، لكن
/// الطبقة الأصلية في ويندوز (`print_job.cpp` في حزمة `printing`) ترسم صفحة
/// الـPDF **بكامل عرض الورقة المادية** انطلاقًا من حدّها المادي، بلا أي
/// تصغير إلى المساحة القابلة للطباعة. فينتج خطآن:
///   • إن كان للطابعة هامش أيمن غير قابل للطباعة **أوسع** من هامش التصميم،
///     قُصَّ الجانب الأيمن — وهو في العربية **بداية أسماء الأصناف** (RTL).
///   • إن كان مقاس الورق في تعريف الطابعة مختلفًا عن المقاس المختار في
///     الإعدادات، رُسمت الصفحة بعرضها المختار على ورق أضيق فقُصّت.
///
/// الحلّ: تُمرَّر هوامش العتاد الحقيقية من `onLayout` إلى المولّد، فيُعاد
/// توليد **نسخة الطباعة** بمقاس الورقة الفعلي وهوامش لا تقلّ عن هوامش
/// العتاد. فالـPDF المصدَّر يبقى كما هو (١ سم)، ونسخة الطابعة وحدها تتكيّف.
///
/// ## لماذا خريطة لا كائن؟
/// الحمولة تمرّ إلى `compute` (عزل مستقلّ)، فتبقى أنواعًا أوّلية فقط.
class PrintLayout {
  const PrintLayout({
    required this.width,
    required this.height,
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
  });

  /// مفتاح الحمولة في خرائط توليد PDF.
  static const String dataKey = 'printLayout';

  /// عرض الورقة المادية (نقاط PDF).
  final double width;

  /// ارتفاع الورقة المادية (نقاط PDF).
  final double height;

  /// الهوامش غير القابلة للطباعة (نقاط PDF) من كل جهة.
  final double left;
  final double top;
  final double right;
  final double bottom;

  /// هل الأبعاد معقولة؟ (تعريف شاذ قد يبلّغ صفرًا.)
  bool get isUsable => width >= 72 && height >= 72;

  /// يقرأ تخطيطًا أبلغت به الطابعة.
  factory PrintLayout.fromPdfPageFormat(PdfPageFormat format) => PrintLayout(
    width: _finite(format.width),
    height: _finite(format.height),
    left: _margin(format.marginLeft),
    top: _margin(format.marginTop),
    right: _margin(format.marginRight),
    bottom: _margin(format.marginBottom),
  );

  /// يقرأ التخطيط من حمولة PDF (يعمل داخل `compute`).
  static PrintLayout? fromData(Object? raw) {
    if (raw is! Map) return null;
    final layout = PrintLayout(
      width: _finite(raw['width']),
      height: _finite(raw['height']),
      left: _margin(raw['left']),
      top: _margin(raw['top']),
      right: _margin(raw['right']),
      bottom: _margin(raw['bottom']),
    );
    return layout.isUsable ? layout : null;
  }

  /// نسخة من الحمولة تحمل هذا التخطيط — تُمرَّر إلى مولّد PDF.
  Map<String, dynamic> applyTo(Map<String, dynamic> data) => <String, dynamic>{
    ...data,
    dataKey: <String, dynamic>{
      'width': width,
      'height': height,
      'left': left,
      'top': top,
      'right': right,
      'bottom': bottom,
    },
  };

  /// يبني مقاس صفحة PDF من الورق المختار وتخطيط الطابعة (إن وُجد).
  ///
  /// [width]/[height] هما المقاس المصمَّم (نقاط). عند وجود [layout] يُؤخذ
  /// مقاس الورقة الفعلي الذي أبلغت به الطابعة — إلا الارتفاع حين
  /// [keepHeight] (الورق الحراري متصل فيبقى ارتفاع التصميم).
  static PdfPageFormat pageFormat({
    required double width,
    required double height,
    required PrintLayout? layout,
    required double baseMargin,
    required double safety,
    bool keepHeight = false,
  }) {
    final pageWidth = layout?.width ?? width;
    final pageHeight = keepHeight ? height : (layout?.height ?? height);
    return PdfPageFormat(
      pageWidth,
      pageHeight,
      marginLeft: safeMargin(
        hardware: layout?.left ?? 0,
        base: baseMargin,
        safety: safety,
        extent: pageWidth,
      ),
      marginTop: safeMargin(
        hardware: layout?.top ?? 0,
        base: baseMargin,
        safety: safety,
        extent: pageHeight,
      ),
      marginRight: safeMargin(
        hardware: layout?.right ?? 0,
        base: baseMargin,
        safety: safety,
        extent: pageWidth,
      ),
      marginBottom: safeMargin(
        hardware: layout?.bottom ?? 0,
        base: baseMargin,
        safety: safety,
        extent: pageHeight,
      ),
    );
  }

  /// هامش جانب واحد: هامش التصميم، أو هامش العتاد + أمان إن كان أوسع.
  ///
  /// [extent] بُعد الصفحة في اتجاه الهامش (العرض للأيمن/الأيسر، والارتفاع
  /// للأعلى/الأسفل). السقف ٣٠٪ لكل جانب يمنع تعريفًا شاذًا من ابتلاع المحتوى
  /// كلّه (ويمنع `PdfPageFormat` من رفض الهوامش).
  static double safeMargin({
    required double hardware,
    required double base,
    required double safety,
    required double extent,
  }) {
    final value = hardware > 0 ? math.max(base, hardware + safety) : base;
    final cap = extent * 0.30;
    return value.clamp(0.0, cap > 0 ? cap : 0.0).toDouble();
  }

  static double _finite(Object? value) {
    if (value is num && value.isFinite) return value.toDouble();
    return 0;
  }

  static double _margin(Object? value) {
    final v = _finite(value);
    return v > 0 ? v : 0;
  }
}
