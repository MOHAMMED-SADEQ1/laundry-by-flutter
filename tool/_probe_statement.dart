// محاكاة أمينة لبنية `generateCustomerStatementPdf` بعد الإصلاح — للتحقّق البصري.
// التشغيل: dart run tool/_probe_statement.dart
// 🚨 انسخ كود الإنتاج **حرفيًا** (الأحجام + rtl + عرض الأعمدة) وإلا أنتجت دليلًا مضلّلًا.
// ignore_for_file: avoid_print

import 'dart:io';
import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

String _money(dynamic v) {
  final a = v is num ? v.toDouble() : double.tryParse('${v ?? 0}') ?? 0.0;
  return a.toStringAsFixed(2);
}

Future<void> main() async {
  final bytes = await File('assets/fonts/Noto/AL-Mohanad.ttf').readAsBytes();
  final font = pw.Font.ttf(ByteData.view(bytes.buffer));

  // ═══ نفس أحجام الإنتاج ═══
  const double base = 13;
  const double small = 11;
  const double cellSize = 12;

  final pdf = pw.Document();

  pw.TextStyle st(double size, {bool bold = false}) => pw.TextStyle(
    font: font,
    fontSize: size,
    fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
  );

  pw.Text tx(String t, {double size = base, bool bold = false, pw.TextAlign? align}) =>
      pw.Text(
        t,
        style: st(size, bold: bold),
        textAlign: align,
        textDirection: pw.TextDirection.rtl,
      );

  pw.Widget kv(String label, String value, {bool bold = false}) => pw.Row(
    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
    children: [tx(label, bold: bold), tx(value, bold: bold)],
  );

  pw.Widget sectionTitle(String text) => pw.Padding(
    padding: const pw.EdgeInsets.only(top: 12, bottom: 6),
    child: tx(text, size: 14, bold: true),
  );

  pw.Widget table(
    List<String> headers,
    List<List<String>> rows, {
    Map<int, pw.TableColumnWidth>? widths,
  }) {
    pw.Widget cell(String t, {bool head = false}) => pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: tx(t, size: cellSize, bold: head, align: pw.TextAlign.center),
    );
    // نفس منطق الإنتاج: عكس الأعمدة ليصير العمود الأول في أقصى اليمين (RTL).
    final n = headers.length;
    final visualWidths = widths == null
        ? null
        : {for (final e in widths.entries) n - 1 - e.key: e.value};
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.4),
      columnWidths: visualWidths,
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey200),
          children: headers.reversed.map((h) => cell(h, head: true)).toList(),
        ),
        ...rows.map(
          (r) => pw.TableRow(children: r.reversed.map((c) => cell(c)).toList()),
        ),
      ],
    );
  }

  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      theme: pw.ThemeData.withFont(base: font, bold: font),
      margin: const pw.EdgeInsets.all(24),
      build: (ctx) => [
        pw.Center(child: tx('مغاسل النظارة', size: 20, bold: true)),
        pw.Center(child: tx('الرياض — هاتف: 0555555555', size: small)),
        pw.Divider(),
        pw.Center(child: tx('كشف حساب زبون', size: 19, bold: true)),
        pw.Center(
          child: tx('الفترة: من 2026-10-01 إلى 2026-10-03', size: small, bold: true),
        ),
        pw.SizedBox(height: 8),
        kv('الزبون:', 'أحمد بن محمد العتيبي', bold: true),
        kv('الهاتف:', '0509999999'),
        kv('تاريخ الطباعة:', '2026-10-03 03:55 ص'),
        pw.Divider(),
        // ═══ الجداول أولًا (الملخّص نُقل للأسفل) ═══
        sectionTitle('الأصناف التي أخذها'),
        table(
          ['التاريخ والوقت', 'الصنف', 'العدد', 'القيمة (ريال)'],
          [
            ['2026-09-21 10:14', 'قميص رجالي', '5', _money(150)],
            ['2026-09-21 10:14', 'بنطال', '3', _money(90)],
            ['2026-09-28 19:02', 'قميص رجالي', '7', _money(210)],
            ['2026-10-01 08:47', 'بطانية', '3', _money(150)],
          ],
          widths: {
            0: const pw.FlexColumnWidth(1.55),
            1: const pw.FlexColumnWidth(2.05),
            2: const pw.FlexColumnWidth(0.65),
            3: const pw.FlexColumnWidth(1.05),
          },
        ),
        sectionTitle('الفواتير'),
        table(
          ['رقم', 'التاريخ', 'الإجمالي', 'المدفوع', 'المتبقي'],
          [
            ['#1024', '2026-09-21', _money(1240), _money(900), _money(340)],
            ['#1031', '2026-09-28', _money(215.5), _money(215.5), _money(0)],
            ['#1042', '2026-10-01', _money(78.75), _money(0), _money(78.75)],
          ],
        ),
        sectionTitle('الدفعات المسجَّلة'),
        table(
          ['التاريخ', 'المبلغ', 'الطريقة', 'ملاحظة'],
          [
            ['2026-09-21', _money(500), 'كاش', 'دفعة نقدية – تسليم'],
            ['2026-10-01', _money(400), 'شبكة', 'تحصيل عند التسليم'],
          ],
        ),
        sectionTitle('سجل استهلاك الاشتراك (القطع المغسولة)'),
        table(
          ['التاريخ', 'الاشتراك', 'القطع', 'القيمة (ريال)', 'الفاتورة'],
          [
            ['2026-09-22', '#7', '10', _money(120), '#1025'],
            ['2026-09-29', '#7', '8', _money(96), '#1033'],
            ['2026-10-02', '#7', '5', _money(60), '-'],
          ],
        ),
        // ═══ الملخّص في الأسفل (خاتمة لا مقدّمة) — مطابق للإنتاج حرفيًا ═══
        // ⚠️ اللفّ في `pw.Row` (لا `pw.Container`) هو ما يجعل `canSpan=false`
        // فينقل `MultiPage` الكتلة كاملة لصفحة جديدة بدل اقتطاعها. التفصيل في
        // `preparePDF.generateCustomerStatementPdf`. المسبار ينسخ الإنتاج.
        pw.Row(
          children: [
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                children: [
                  pw.Divider(),
                  sectionTitle('الملخّص (تدفّقات الفترة + الرصيد الحالي)'),
                  kv('إجمالي المشتريات:', '1,240.00 ريال'),
                  kv('المسدَّد:', '900.00 ريال'),
                  kv('الذمة المتبقية (عليه):', '340.00 ريال', bold: true),
                  kv('الرصيد الدائن (له):', '0.00 ريال', bold: true),
                  pw.Divider(),
                  kv('صافي الموقف:', '340.00 ريال (عليه)', bold: true),
                  kv('عدد القطع:', '27'),
                  pw.SizedBox(height: 16),
                  pw.Center(
                    child: tx(
                      '--- هذا الكشف صادر آليًا من النظام ---',
                      size: small,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    ),
  );

  final out = await pdf.save();
  await File('tool/_probe_statement.pdf').writeAsBytes(out);
  print('wrote tool/_probe_statement.pdf (${out.length} bytes)');
}
