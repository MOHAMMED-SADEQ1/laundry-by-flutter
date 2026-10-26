/// **مسبار الوزن والعرض** — هل يمكن تعريض النصّ وتمدیده أفقيًا بلا كسر
/// الاتصال العربي؟
///
/// ## المشكلتان المقاستان هنا
/// 1. `AL-Mohanad` بوزن واحد وحزمة `pdf` لا تُنحّف ⇒ «الوزن» يحتاج
///    **تعريضًا صناعيًا**: رسم السطر مرّتين بإزاحة أفقية صغيرة. والخطر أن
///    `pw.Stack` يمنح الأبناء `constraints.loosen()` فيُفقد `textAlign`
///    داخل خلايا الجداول. الحلّ المُختبَر: `StackFit.passthrough`.
/// 2. `letterSpacing` **يكسر اتصال الحروف العربية** (أُثبت في مسبار
///    `_probe_font_weight.dart`: «ضريبية» تفرّقت). فـ«العرض» يجب أن يكون
///    **تمديدًا أفقيًا** (`Matrix4.diagonal3Values`) لا تباعدًا.
///
/// التشغيل: `dart run tool/_probe_weight_width.dart` ثم تصيير PNG.
library;

import 'dart:io';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:vector_math/vector_math_64.dart' show Matrix4;

Future<void> main() async {
  final font = pw.Font.ttf(
    File(
      'assets/fonts/Noto/AL-Mohanad.ttf',
    ).readAsBytesSync().buffer.asByteData(),
  );

  /// تعريض صناعي: نسخة ثانية مُزاحة أفقيًا.
  pw.Widget thick(String text, double size, double dx, {bool center = false}) {
    pw.Widget base = pw.Text(
      text,
      textDirection: pw.TextDirection.rtl,
      textAlign: center ? pw.TextAlign.center : pw.TextAlign.right,
      style: pw.TextStyle(font: font, fontSize: size),
    );
    if (dx <= 0) return base;
    return pw.Stack(
      fit: pw.StackFit.passthrough,
      overflow: pw.Overflow.visible,
      children: [
        base,
        pw.Transform.translate(
          offset: PdfPoint(dx, 0),
          child: pw.Text(
            text,
            textDirection: pw.TextDirection.rtl,
            textAlign: center ? pw.TextAlign.center : pw.TextAlign.right,
            style: pw.TextStyle(font: font, fontSize: size),
          ),
        ),
      ],
    );
  }

  /// تمديد أفقي (عرض) — يبقي الحروف متّصلة.
  pw.Widget wide(String text, double size, double scaleX, {bool center = false}) {
    return pw.Transform(
      transform: Matrix4.diagonal3Values(scaleX, 1, 1),
      alignment: pw.Alignment.center,
      child: pw.Text(
        text,
        textDirection: pw.TextDirection.rtl,
        textAlign: center ? pw.TextAlign.center : pw.TextAlign.right,
        style: pw.TextStyle(font: font, fontSize: size),
      ),
    );
  }

  final pdf = pw.Document();
  pdf.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a5,
      margin: const pw.EdgeInsets.all(18),
      build:
          (pw.Context context) => pw.Directionality(
            textDirection: pw.TextDirection.rtl,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                pw.Text(
                  'الوزن (تعريض صناعي) — 20pt',
                  style: pw.TextStyle(font: font, fontSize: 8),
                ),
                thick('فاتورة ضريبية مبسطة 0.00', 20, 0, center: true),
                thick('فاتورة ضريبية مبسطة 0.25', 20, 0.25, center: true),
                thick('فاتورة ضريبية مبسطة 0.45', 20, 0.45, center: true),
                thick('فاتورة ضريبية مبسطة 0.70', 20, 0.70, center: true),
                pw.Divider(),
                pw.Text(
                  'العرض (تمديد أفقي) — 18pt',
                  style: pw.TextStyle(font: font, fontSize: 8),
                ),
                wide('فاتورة ضريبية مبسطة 1.00', 18, 1.00, center: true),
                wide('فاتورة ضريبية مبسطة 1.12', 18, 1.12, center: true),
                wide('فاتورة ضريبية مبسطة 1.25', 18, 1.25, center: true),
                pw.Divider(),
                pw.Text(
                  'داخل خلايا جدول (اختبار الحفاظ على المحاذاة)',
                  style: pw.TextStyle(font: font, fontSize: 8),
                ),
                pw.Table(
                  border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.4),
                  columnWidths: {
                    0: const pw.FlexColumnWidth(1),
                    1: const pw.FlexColumnWidth(1),
                    2: const pw.FlexColumnWidth(1),
                  },
                  children: [
                    pw.TableRow(
                      children: [
                        pw.Container(
                          padding: const pw.EdgeInsets.all(3),
                          child: thick('عادي داخل خلية', 11, 0, center: true),
                        ),
                        pw.Container(
                          padding: const pw.EdgeInsets.all(3),
                          child: thick('عريض داخل خلية', 11, 0.22, center: true),
                        ),
                        pw.Container(
                          padding: const pw.EdgeInsets.all(3),
                          child: wide('ممتد داخل خلية', 11, 1.10, center: true),
                        ),
                      ],
                    ),
                    pw.TableRow(
                      children: [
                        pw.Container(
                          padding: const pw.EdgeInsets.all(3),
                          child: thick('نصّ طويل جدًا لاختبار الالتفاف داخل خلية ضيّقة', 11, 0.22),
                        ),
                        pw.Container(
                          padding: const pw.EdgeInsets.all(3),
                          child: thick('سطر ثانٍ للالتفاف', 11, 0),
                        ),
                        pw.Container(
                          padding: const pw.EdgeInsets.all(3),
                          child: pw.Text(
                            'مرجع',
                            textDirection: pw.TextDirection.rtl,
                            style: pw.TextStyle(font: font, fontSize: 11),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
    ),
  );

  final out = Directory('build/probe')..createSync(recursive: true);
  final file = File('${out.path}/weight_width.pdf');
  file.writeAsBytesSync(await pdf.save());
  stdout.writeln('كتب: ${file.path}');
}
