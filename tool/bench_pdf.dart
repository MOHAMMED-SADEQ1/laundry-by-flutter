// ignore_for_file: avoid_print
//
// مقياس أداء توليد فاتورة PDF — يحاكي preparePDF.generatePdfData بدقة.
// يُشغَّل بـ: dart run tool/bench_pdf.dart
//
// ليس اختبارًا ولا تقريرًا — أداة قياس فقط.

import 'dart:io';
import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

Future<Uint8List> buildInvoice({
  required pw.Font font,
  required Uint8List logo,
  required Uint8List riyal,
  required int itemCount,
  Uint8List? photo,
  int photoCount = 0,
}) async {
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
  final riyalIcon = pw.Image(pw.MemoryImage(riyal), width: 18, height: 18);

  final header = <pw.Widget>[
    pw.Center(child: pw.Image(pw.MemoryImage(logo), width: 150, height: 150)),
    pw.SizedBox(height: 6),
    pw.Center(child: pw.Text('مغاسل النظارة', style: itemStyle)),
    pw.SizedBox(height: 10),
    pw.Divider(),
    pw.Center(child: pw.Text('فاتورة ضريبية مبسطة', style: itemStyle)),
    pw.Center(child: pw.Text('رقم الإيصال: 1234-1', style: itemStyle)),
    pw.Center(
      child: pw.Text(
        'التأريخ: 2026-09-17 07:00 | نقطة بيع POS',
        style: itemStyle,
      ),
    ),
    pw.Divider(),
  ];

  final items = <pw.Widget>[];
  for (var i = 0; i < itemCount; i++) {
    items.add(
      pw.Container(
        padding: const pw.EdgeInsets.symmetric(vertical: 7),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Padding(
              padding: const pw.EdgeInsets.only(left: 10),
              child: pw.Text('15.00', style: priceStyle),
            ),
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(
                    'قميص أبيض (غسيل وكوي)',
                    textDirection: pw.TextDirection.rtl,
                    style: itemStyle,
                  ),
                  pw.Text(
                    '15.0 x 1',
                    textDirection: pw.TextDirection.rtl,
                    style: priceStyle,
                  ),
                  if (photo != null && i < photoCount)
                    pw.Container(
                      margin: const pw.EdgeInsets.only(top: 4),
                      child: pw.Image(
                        pw.MemoryImage(photo),
                        width: 80,
                        height: 80,
                        fit: pw.BoxFit.cover,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  final footer = <pw.Widget>[
    pw.Divider(),
    pw.Row(
      children: [
        pw.Text('150.00', style: priceStyle),
        pw.SizedBox(width: 5),
        riyalIcon,
        pw.Spacer(),
        pw.Text(
          'المجموع شامل الضريبة',
          textDirection: pw.TextDirection.rtl,
          style: itemStyle,
        ),
      ],
    ),
  ];

  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      theme: pw.ThemeData.withFont(base: font),
      build: (pw.Context ctx) => [...header, ...items, ...footer],
    ),
  );
  return pdf.save();
}

Future<void> bench(
  String label,
  pw.Font Function() fontFactory,
  Uint8List logo,
  Uint8List riyal, {
  int itemCount = 3,
  Uint8List? photo,
  int photoCount = 0,
  int runs = 5,
}) async {
  // تسخين
  await buildInvoice(
    font: fontFactory(),
    logo: logo,
    riyal: riyal,
    itemCount: itemCount,
    photo: photo,
    photoCount: photoCount,
  );

  final times = <int>[];
  Uint8List? last;
  for (var i = 0; i < runs; i++) {
    final sw = Stopwatch()..start();
    last = await buildInvoice(
      font: fontFactory(),
      logo: logo,
      riyal: riyal,
      itemCount: itemCount,
      photo: photo,
      photoCount: photoCount,
    );
    sw.stop();
    times.add(sw.elapsedMilliseconds);
  }
  times.sort();
  final median = times[times.length ~/ 2];
  final sizeKb = (last!.length / 1024).toStringAsFixed(0);
  print(
    '${label.padRight(34)} '
    'وسيط ${median.toString().padLeft(5)} ms   '
    'أدنى ${times.first.toString().padLeft(4)} ms   '
    'الحجم ${sizeKb.padLeft(6)} KB',
  );
}

Future<void> main() async {
  final fontBytes = File('assets/fonts/Noto/AL-Mohanad.ttf').readAsBytesSync();
  final logo = File('assets/images/logo-wash.png').readAsBytesSync();
  final riyal = File('assets/images/saudi_riyal.png').readAsBytesSync();
  final photoFile = File('build/bench/big_photo.png');
  final photo = photoFile.existsSync() ? photoFile.readAsBytesSync() : null;

  print('حجم الخط: ${(fontBytes.length / 1024).toStringAsFixed(1)} KB');
  print('حجم الشعار: ${(logo.length / 1024).toStringAsFixed(1)} KB');
  if (photo != null) {
    print('حجم صورة الصنف: ${(photo.length / 1024 / 1024).toStringAsFixed(2)} MB');
  }
  print('');

  // 1) كلفة تحليل الخط (تُدفع مرة واحدة لكل عملية)
  final swFont = Stopwatch()..start();
  pw.Font.ttf(ByteData.view(fontBytes.buffer));
  swFont.stop();
  print('تحليل الخط (مرة واحدة)              ${swFont.elapsedMilliseconds} ms');
  print('');

  // خط واحد مُحلَّل مسبقًا (كما في التطبيق: arabicFont مخزَّن)
  final cachedFont = pw.Font.ttf(ByteData.view(fontBytes.buffer));

  print('--- الخط مُحلَّل مسبقًا (الوضع الحالي في التطبيق) ---');
  await bench('فاتورة 3 أصناف', () => cachedFont, logo, riyal, itemCount: 3);
  await bench('فاتورة 10 أصناف', () => cachedFont, logo, riyal, itemCount: 10);
  await bench('فاتورة 30 صنفًا', () => cachedFont, logo, riyal, itemCount: 30);
  if (photo != null) {
    await bench(
      'فاتورة 3 أصناف + صورة كاملة',
      () => cachedFont,
      logo,
      riyal,
      itemCount: 3,
      photo: photo,
      photoCount: 1,
    );
    await bench(
      'فاتورة 10 أصناف + 10 صور كاملة',
      () => cachedFont,
      logo,
      riyal,
      itemCount: 10,
      photo: photo,
      photoCount: 10,
    );
  }

  // 2) الأثر بعد تصغير الصورة قبل التضمين
  final small160 = File('build/bench/photo_160.png');
  final small320 = File('build/bench/photo_320.png');
  if (small160.existsSync()) {
    print('');
    print('--- بعد تصغير الصورة قبل التضمين ---');
    final p160 = small160.readAsBytesSync();
    final p320 = small320.readAsBytesSync();
    await bench(
      '3 أصناف + صورة 160x160',
      () => cachedFont,
      logo,
      riyal,
      itemCount: 3,
      photo: p160,
      photoCount: 1,
    );
    await bench(
      '3 أصناف + صورة 320x320',
      () => cachedFont,
      logo,
      riyal,
      itemCount: 3,
      photo: p320,
      photoCount: 1,
    );
    await bench(
      '10 أصناف + 10 صور 160x160',
      () => cachedFont,
      logo,
      riyal,
      itemCount: 10,
      photo: p160,
      photoCount: 10,
    );
  }

  print('');
  print('--- الخط يُحلَّل من جديد في كل مرة (سيناريو الـ isolate) ---');
  await bench(
    'فاتورة 3 أصناف + تحليل خط',
    () => pw.Font.ttf(ByteData.view(fontBytes.buffer)),
    logo,
    riyal,
    itemCount: 3,
  );
}
