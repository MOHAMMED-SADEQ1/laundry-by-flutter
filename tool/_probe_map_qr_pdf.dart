// مسبار: هل يُرسم رمز QR لموقع النشاط فعلًا على الورق؟
//
// لا يستورد Flutter — يعيد بناء ما يفعله `_mapQrSvg` + `pw.SvgImage` في
// `preparePDF` بمكتبة `pdf` وحدها، ويُخرج PDF حقيقيًا يُقاس ويُنظر إليه.
//
// التشغيل: dart run tool/_probe_map_qr_pdf.dart
import 'dart:io';

import 'package:barcode/barcode.dart';
import 'package:laundry/services/pdf/map_qr.dart';
import 'package:laundry/services/pdf/print_visual_size.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

Future<void> main() async {
  const raw = 'https://maps.app.goo.gl/LaundryShop24';
  final url = MapQr.resolve(raw);
  print('الرابط المطبَّع: $url');

  final svg = Barcode.qrCode().toSvg(url, width: 120, height: 120);
  print('حجم SVG: ${svg.length} حرفًا');

  final points =
      PrintVisualSize.qr(sizeMm: 30, maxWidth: 538, maxHeight: 793).width;
  print('مقاس الرمز على A4: $points نقطة');

  final pdf = pw.Document();
  pdf.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      build:
          (ctx) => pw.Column(
            children: [
              pw.Text('PROBE_MAP_QR'),
              pw.SizedBox(height: 20),
              pw.Center(
                child: pw.SvgImage(svg: svg, width: points, height: points),
              ),
              pw.SizedBox(height: 4),
              pw.Center(child: pw.Text('PROBE_CAPTION')),
            ],
          ),
    ),
  );

  final bytes = await pdf.save();
  File('build/_probe_map_qr.pdf').writeAsBytesSync(bytes);
  print('كُتب build/_probe_map_qr.pdf — ${bytes.length} بايت');

  // نسخة حرارية 58 مم: نفس الرمز بمقاس الورق الضيّق، لقياس قابلية القراءة.
  final thermalPoints =
      PrintVisualSize.qr(sizeMm: 70, maxWidth: 137, maxHeight: 793).width;
  print('مقاس الرمز على الحراري 58 مم: $thermalPoints نقطة');
  final thermal = pw.Document();
  thermal.addPage(
    pw.Page(
      pageFormat: const PdfPageFormat(58 * PdfPageFormat.mm, 90 * PdfPageFormat.mm),
      build: (ctx) => pw.Center(
        child: pw.SvgImage(
          svg: svg,
          width: thermalPoints,
          height: thermalPoints,
        ),
      ),
    ),
  );
  final tbytes = await thermal.save();
  File('build/_probe_map_qr_thermal.pdf').writeAsBytesSync(tbytes);
  print('كُتب build/_probe_map_qr_thermal.pdf — ${tbytes.length} بايت');
}
