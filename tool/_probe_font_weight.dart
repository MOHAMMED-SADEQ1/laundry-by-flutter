/// **مسبار أوزان الخطوط** — يُثبت أيّ وجه عربي أثقل فعلًا.
///
/// ## لماذا؟
/// `AL-Mohanad.ttf` يأتي بوزن **واحد** فقط، وحزمة `pdf` لا تُنحّف الحروف
/// (لا faux bold). فطلب المستخدم «التحكم في وزن الخط» لا يُنفَّذ إلا بوجه
/// ثانٍ حقيقي. لكن اختيار الوجه بالتخمين خطر: لو كان الوجه الثاني **أنحف**
/// لصار زرّ «عريض» يُخرج نصًّا أرقّ — عيب صامت لا يكشفه أي حارس.
///
/// فهذا المسبار يرسم السطور نفسها بالأوجه الثلاثة بالحجم نفسه، ويُخرج PDF
/// يُقرأ بالعين. نتيجته المسجَّلة (2026-10-24):
///   • `AL-Mohanad`  — نحيف/عادي، هو وجه المستند الحالي.
///   • `Cairo-Medium` — أثقل بوضوح، ونفس الطابع الحديث ⇒ **العريض**.
///   • `Amiri-Bold`  — أثقل لكنه نسخي (Serif) مختلف الطابع ⇒ لم يُستخدم.
///
/// التشغيل: `dart run tool/_probe_font_weight.dart`
library;

import 'dart:io';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

Future<void> main() async {
  final regular = pw.Font.ttf(
    File('assets/fonts/Noto/AL-Mohanad.ttf').readAsBytesSync().buffer.asByteData(),
  );
  final cairo = pw.Font.ttf(
    File('assets/fonts/Cairo/Cairo-Medium.ttf').readAsBytesSync().buffer.asByteData(),
  );
  final amiri = pw.Font.ttf(
    File('assets/fonts/Amiri/Amiri-Bold.ttf').readAsBytesSync().buffer.asByteData(),
  );

  final pdf = pw.Document();
  final samples = <(String, pw.Font)>[
    ('AL-Mohanad (الافتراضي)', regular),
    ('Cairo-Medium', cairo),
    ('Amiri-Bold', amiri),
  ];

  pdf.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a5,
      margin: const pw.EdgeInsets.all(20),
      build:
          (pw.Context context) => pw.Directionality(
            textDirection: pw.TextDirection.rtl,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                for (final (name, f) in samples) ...[
                  pw.Text(
                    '$name — 20pt',
                    style: pw.TextStyle(font: regular, fontSize: 9),
                  ),
                  pw.Text(
                    'فاتورة ضريبية مبسطة — رمز الاستلام 1024',
                    textDirection: pw.TextDirection.rtl,
                    style: pw.TextStyle(font: f, fontSize: 20),
                  ),
                  pw.Text(
                    '$name — 13pt',
                    style: pw.TextStyle(font: regular, fontSize: 9),
                  ),
                  pw.Text(
                    'محمد صادق · مغسلة النخيل · الرياض',
                    textDirection: pw.TextDirection.rtl,
                    style: pw.TextStyle(font: f, fontSize: 13),
                  ),
                  pw.Divider(),
                ],
                // تباعد الحروف (العرض) — هل ينجو مع التشكيل العربي؟
                pw.Text(
                  'العرض 100% (طبيعي)',
                  style: pw.TextStyle(font: regular, fontSize: 9),
                ),
                pw.Text(
                  'فاتورة ضريبية مبسطة',
                  textDirection: pw.TextDirection.rtl,
                  style: pw.TextStyle(font: regular, fontSize: 18, letterSpacing: 0),
                ),
                pw.Text(
                  'العرض 130% (تباعد +)',
                  style: pw.TextStyle(font: regular, fontSize: 9),
                ),
                pw.Text(
                  'فاتورة ضريبية مبسطة',
                  textDirection: pw.TextDirection.rtl,
                  style: pw.TextStyle(
                    font: regular,
                    fontSize: 18,
                    letterSpacing: 18 * 0.30 * 0.5,
                  ),
                ),
                pw.Text(
                  'العرض 85% (تباعد -)',
                  style: pw.TextStyle(font: regular, fontSize: 9),
                ),
                pw.Text(
                  'فاتورة ضريبية مبسطة',
                  textDirection: pw.TextDirection.rtl,
                  style: pw.TextStyle(
                    font: regular,
                    fontSize: 18,
                    letterSpacing: 18 * -0.15 * 0.5,
                  ),
                ),
              ],
            ),
          ),
    ),
  );

  final out = Directory('build/probe')..createSync(recursive: true);
  final file = File('${out.path}/fonts.pdf');
  file.writeAsBytesSync(await pdf.save());
  stdout.writeln('كتب: ${file.path}');
}
