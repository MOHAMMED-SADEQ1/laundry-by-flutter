// ignore_for_file: avoid_print
// إعادة إنتاج دقيقة لكود الفوتر في preparePDF.dart للتحقق من ظهور المجموع.
import 'dart:io';
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

Future<void> main() async {
  final fontBytes = File('assets/fonts/Noto/AL-Mohanad.ttf').readAsBytesSync();
  final font = pw.Font.ttf(ByteData.view(fontBytes.buffer));
  final logo = File('assets/images/logo-wash.png').readAsBytesSync();

  final pdf = pw.Document();
  final itemStyle = pw.TextStyle(
    font: font,
    fontSize: 27,
    fontWeight: pw.FontWeight.bold,
  );
  final priceStyle = pw.TextStyle(
    font: font,
    fontSize: 24,
    fontWeight: pw.FontWeight.bold,
  );
  final header = <pw.Widget>[
    pw.Center(child: pw.Image(pw.MemoryImage(logo), width: 150, height: 150)),
    pw.Center(
      child: pw.Text(
        'مغاسل النظارة',
        textDirection: pw.TextDirection.rtl,
        textAlign: pw.TextAlign.center,
        style: itemStyle,
      ),
    ),
    pw.Center(
      child: pw.Text(
        'فاتورة ضريبية مبسطة',
        textDirection: pw.TextDirection.rtl,
        textAlign: pw.TextAlign.center,
        style: itemStyle,
      ),
    ),
    pw.Divider(),
  ];

  final items = <pw.Widget>[];
  for (var i = 0; i < 2; i++) {
    items.add(
      pw.Container(
        padding: const pw.EdgeInsets.symmetric(vertical: 7),
        child: pw.Row(
          children: [
            pw.Text('15.00', style: priceStyle),
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(
                    'قميص أبيض (غسيل وكوي)',
                    textDirection: pw.TextDirection.rtl,
                    textAlign: pw.TextAlign.right,
                    style: itemStyle,
                  ),
                  pw.Text(
                    '15.0 x 1',
                    textDirection: pw.TextDirection.rtl,
                    textAlign: pw.TextAlign.right,
                    style: priceStyle,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══ نفس كود الفوتر في preparePDF.dart حرفيًا (بعد إصلاح ازدواج المبلغ) ═══
  final footerWidgets = <pw.Widget>[
    pw.Divider(),
    pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Row(
              mainAxisSize: pw.MainAxisSize.min,
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Text(
                  '30.00 ر.س',
                  style: priceStyle,
                  textDirection: pw.TextDirection.rtl,
                ),
              ],
            ),
            pw.Text(
              'PROBE_AMOUNT_COL',
              style: pw.TextStyle(font: pw.Font.helvetica(), fontSize: 10),
            ),
          ],
        ),
        pw.Spacer(),
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Text(
              'المجموع شامل الضريبة',
              textDirection: pw.TextDirection.rtl,
              textAlign: pw.TextAlign.right,
              style: itemStyle,
            ),
            pw.Text(
              'PROBE_DESC_COL',
              style: pw.TextStyle(font: pw.Font.helvetica(), fontSize: 10),
            ),
            pw.SizedBox(height: 10),
            pw.Text(
              'الدفع: كاش',
              textDirection: pw.TextDirection.rtl,
              textAlign: pw.TextAlign.right,
              style: pw.TextStyle(font: font, fontSize: 16),
            ),
          ],
        ),
      ],
    ),
  ];

  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      theme: pw.ThemeData.withFont(base: font),
      build: (pw.Context ctx) => [...header, ...items, ...footerWidgets],
    ),
  );

  final bytes = await pdf.save();
  File('build/_repro.pdf').writeAsBytesSync(bytes);
  print('حجم الملف: ${(bytes.length / 1024).toStringAsFixed(1)} KB');
}
