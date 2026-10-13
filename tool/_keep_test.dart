// مسح: أي عدد أسطر يُنتج «عنوانًا يتيمًا»؟ ومعه: هل الغلاف غير القابل للانقسام يمنعه؟
// ignore_for_file: avoid_print

import 'dart:io';
import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

Future<void> main() async {
  final bytes = await File('assets/fonts/Noto/AL-Mohanad.ttf').readAsBytes();
  final font = pw.Font.ttf(ByteData.view(bytes.buffer));

  pw.TextStyle st(double s, {bool b = false}) => pw.TextStyle(
    font: font,
    fontSize: s,
    fontWeight: b ? pw.FontWeight.bold : pw.FontWeight.normal,
  );

  pw.Widget title() => pw.Padding(
    padding: const pw.EdgeInsets.only(top: 12, bottom: 6),
    child: pw.Text('SUMMARY_TITLE', style: st(14, b: true)),
  );

  pw.Widget kv(String a, String b) => pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 3),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [pw.Text(a, style: st(13)), pw.Text(b, style: st(13))],
    ),
  );

  List<pw.Widget> summary() => [
    title(),
    kv('L1', '1.00'),
    kv('L2', '2.00'),
    kv('L3', '3.00'),
    kv('L4', '4.00'),
    kv('L5', '5.00'),
    kv('L6', '6.00'),
  ];

  for (var wrap = 0; wrap <= 1; wrap++) {
    for (var h = 0; h <= 60; h += 2) {
      final doc = pw.Document();
      doc.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(24),
          build: (ctx) => [
            for (var i = 0; i < 32; i++)
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(vertical: 5),
                child: pw.Text('filler $i', style: st(13)),
              ),
            // فاصل دقيق يحرّك الكتلة بمقدار 2pt لمسح نافذة الانفصال
            pw.SizedBox(height: h.toDouble()),
            if (wrap == 1)
              pw.Container(child: pw.Column(children: summary()))
            else
              ...summary(),
          ],
        ),
      );
      final out = await doc.save();
      File('build/_keep_w${wrap}_h$h.pdf').writeAsBytesSync(out);
    }
  }
  print('done');
}
