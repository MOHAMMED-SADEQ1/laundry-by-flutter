// مسبار الخطوط: ورقة مقارنة واحدة — كل خطّ بسطرين (9pt للحراري · 16pt للورق).
//
// الغرض: إثبات ثلاثة أشياء **قبل** كتابة أي كود إنتاجي:
//   1. أن محلّل TTF في حزمة `pdf` يقبل الملف (يرمي على خطّ تالف).
//   2. أن الخطّ يرسم العربية فعلًا (لا مربّعات .notdef) — بالفحص البصري.
//   3. مقارنة الوزن والاتساع: الأضيق أوضح على 80 مم الحراري.
//
// التشغيل: dart run tool/_probe_print_fonts.dart
// المخرجات: build/probe/font_compare.pdf
import 'dart:io';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

const String line = 'قيميص (غسيل) 3 × 10.00 = 30.00 ر.س';
const String line2 = 'مغاسل النظارة — فاتورة ضريبية مبسطة 1234567890';

const Map<String, String> fonts = <String, String>{
  'al_mohanad': 'assets/fonts/Noto/AL-Mohanad.ttf',
  'noto_naskh': 'assets/fonts/Noto/NotoNaskhArabic-Regular.ttf',
  'noto_sans': 'assets/fonts/Noto/NotoSansArabic-Regular.ttf',
  'noto_kufi': 'assets/fonts/Noto/NotoKufiArabic-Regular.ttf',
  'ibm_plex': 'assets/fonts/IBMPlex/IBMPlexSansArabic-Regular.ttf',
  'ibm_plex_light': 'assets/fonts/IBMPlex/IBMPlexSansArabic-Light.ttf',
  'almarai': 'assets/fonts/Almarai/Almarai-Regular.ttf',
  'almarai_light': 'assets/fonts/Almarai/Almarai-Light.ttf',
  'tajawal': 'assets/fonts/Tajawal/Tajawal-Regular.ttf',
  'cairo': 'assets/fonts/Cairo/Cairo-Medium.ttf',
  'amiri': 'assets/fonts/Amiri/Amiri-Regular.ttf',
  'trad': 'assets/fonts/Noto/TRAD.ttf',
  'dthuluth': 'assets/fonts/DTHULUTH/DTHULUTH-II-1.ttf',
};

Future<void> main() async {
  Directory('build/probe').createSync(recursive: true);
  final doc = pw.Document();
  final label = pw.Font.helvetica();

  final children = <pw.Widget>[];
  for (final e in fonts.entries) {
    final f = File(e.value);
    if (!f.existsSync()) {
      print('MISSING ${e.key} -> ${e.value}');
      continue;
    }
    final bytes = f.readAsBytesSync();
    final pw.Font font;
    try {
      font = pw.Font.ttf(
        bytes.buffer.asByteData(bytes.offsetInBytes, bytes.lengthInBytes),
      );
      // يُجبر المحلّل على قراءة الجدول كاملًا هنا لا وقت الرسم.
      final probe = pw.Document();
      probe.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build:
              (_) => pw.Text(
                line2,
                textDirection: pw.TextDirection.rtl,
                style: pw.TextStyle(font: font, fontSize: 12),
              ),
        ),
      );
      await probe.save();
      print('OK ${e.key.padRight(16)} ${bytes.length} bytes');
    } catch (err) {
      print('FAIL ${e.key.padRight(16)} $err');
      continue;
    }

    children.add(
      pw.Container(
        margin: const pw.EdgeInsets.only(bottom: 7),
        padding: const pw.EdgeInsets.all(4),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.grey400, width: 0.5),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            pw.Text(
              '${e.key}   (${bytes.length ~/ 1024} KB)',
              style: pw.TextStyle(font: label, fontSize: 7),
            ),
            pw.SizedBox(height: 2),
            // مقاس 9pt = مقاس الإيصال الحراري الفعلي.
            pw.Text(
              line,
              textDirection: pw.TextDirection.rtl,
              style: pw.TextStyle(font: font, fontSize: 9),
            ),
            pw.Text(
              line2,
              textDirection: pw.TextDirection.rtl,
              style: pw.TextStyle(font: font, fontSize: 9),
            ),
            pw.SizedBox(height: 2),
            pw.Text(
              line2,
              textDirection: pw.TextDirection.rtl,
              style: pw.TextStyle(font: font, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(18),
      build: (_) => children,
    ),
  );
  final out = await doc.save();
  File('build/probe/font_compare.pdf').writeAsBytesSync(out);
  print('WROTE build/probe/font_compare.pdf (${out.length} bytes)');
}
