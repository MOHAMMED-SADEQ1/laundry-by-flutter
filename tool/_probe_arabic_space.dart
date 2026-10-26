// **مسبار موثَّق** — أي بديل للمسافة ينجو من تشكيل حزمة `pdf`؟
//
// هذا الملف هو **دليل** عيب «رمز الاستلام ⇒ رمزالاستلام» الذي يعالجه
// `lib/services/pdf/arabic_text.dart`. أُبقي كي يُعاد تشغيله عند ترقية حزمة
// `pdf` أو تغيير الخط — فربما أُصلح العيب في الحزمة، أو ظهر بديل أفضل.
//
// التشغيل: dart run tool/_probe_arabic_space.dart
// ثم اعرض: build/probe/arabic_space.pdf
//
// النتيجة المسجَّلة (2026-10-23، حجم 27pt، خط AL-Mohanad):
//   مسافة عادية  ⇒ تُبلع        |  NBSP (U+00A0) ⇒ تُبلع
//   رقيقة (U+2009) ⇒ تُبلع      |  **مسافتان ⇒ سليمة**
// ignore_for_file: avoid_print
import 'dart:io';
import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

Future<void> main() async {
  final bytes = await File('assets/fonts/Noto/AL-Mohanad.ttf').readAsBytes();
  final font = pw.Font.ttf(ByteData.view(bytes.buffer));

  final samples = <String>[
    'رمز الاستلام: 1234', // مسافة عادية
    'رمز\u00A0الاستلام: 1234', // غير فاصلة
    'رمز  الاستلام: 1234', // مسافتان
    'رمز\u2009الاستلام: 1234', // رقيقة
    'رمز\u202Fالاستلام: 1234', // ضيقة غير فاصلة
    'رمز استلام: 1234', // بلا وصلة
  ];

  final pdf = pw.Document();
  pdf.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      build:
          (ctx) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              for (final s in samples)
                pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(vertical: 6),
                  child: pw.Text(
                    s,
                    textDirection: pw.TextDirection.rtl,
                    style: pw.TextStyle(font: font, fontSize: 27, fontWeight: pw.FontWeight.bold),
                  ),
                ),
            ],
          ),
    ),
  );
  File('build/probe/arabic_space.pdf').writeAsBytesSync(await pdf.save());
  print('ok');
}
