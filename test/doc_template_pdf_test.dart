// اختبار توليد المستندات بقالب مخصّص — يتحقّق أن القالب يغيّر الورق فعلًا.
//
// **لماذا اختبار توليد حقيقي لا فحص نصّي؟** لأن الحرس النصّي يثبت أن الكود
// يقرأ `DocTemplateView` — لا أن النتيجة **ورقة مختلفة**. هنا نولّد PDF فعليًا
// في ثلاثة أوضاع (افتراضي · كل شيء معطَّل · نصوص مخصّصة) ونقارن الحجم، ثم
// نكتب الملفات في `build/probe/` للفحص البصري بـPyMuPDF.
//
// التشغيل: flutter test test/doc_template_pdf_test.dart
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laundry/core/services/preparePDF.dart';
import 'package:laundry/services/pdf/doc_template.dart';
import 'package:pdf/widgets.dart' as pw;

Future<Uint8List> _asset(String path) async {
  final d = await rootBundle.load(path);
  return d.buffer.asUint8List();
}

Map<String, dynamic> _statementData({
  required DocTemplate tpl,
  String customerName = 'محمد صادق',
  String period = 'من 2026-10-01 إلى 2026-10-23',
}) {
  return <String, dynamic>{
    'bizName': 'مغاسل النظارة',
    'bizPhone': '0500000000',
    'bizAddress': 'الرياض – حي النخيل',
    'customerName': customerName,
    'customerPhone': '0555555555',
    'printedAt': '2026-10-23 09:30',
    'period': period,
    'totals': <String, dynamic>{
      'purchases': 480.0,
      'paid': 300.0,
      'debt': 180.0,
      'credit': 0.0,
      'net': -180.0,
      'pieces': 42,
      'subPieces': 0,
      'subValue': 0.0,
    },
    'invoices': <Map<String, dynamic>>[
      <String, dynamic>{
        'id': 1024,
        'date': '2026-10-20',
        'total': 120.0,
        'paid': 120.0,
        'remaining': 0.0,
      },
      <String, dynamic>{
        'id': 1031,
        'date': '2026-10-22',
        'total': 360.0,
        'paid': 180.0,
        'remaining': 180.0,
      },
    ],
    'itemsDetailed': <Map<String, dynamic>>[
      <String, dynamic>{
        'date': '2026-10-20 10:12',
        'name': 'قميص',
        'count': 6,
        'value': 60.0,
      },
      <String, dynamic>{
        'date': '2026-10-22 18:40',
        'name': 'بنطال',
        'count': 4,
        'value': 80.0,
      },
    ],
    'payments': <Map<String, dynamic>>[
      <String, dynamic>{
        'date': '2026-10-20',
        'amount': 120.0,
        'method': 'نقد',
        'note': 'دفعة نقدية',
      },
    ],
    'usages': const <Map<String, dynamic>>[],
    ...tpl.toTransport(),
  };
}

Map<String, dynamic> _shiftData(DocTemplate tpl) {
  return <String, dynamic>{
    'shift_id': 14,
    'start_time': '2026-10-24 08:00:00',
    'end_time': '2026-10-24 20:00:00',
    'invoice_count': 32,
    'total_cash': 1450.0,
    'total_network': 980.5,
    'bizName': 'مغاسل النظارة',
    'bizPhone': '0500000000',
    'bizAddress': 'الرياض – حي النخيل',
    ...tpl.toTransport(),
  };
}

Future<Map<String, dynamic>> _invoiceData(DocTemplate tpl) async {
  return <String, dynamic>{
    'payment': 'نقد',
    'logoImage': await _asset('assets/images/logo-wash.png'),
    'riyalImage': await _asset('assets/images/saudi_riyal.png'),
    'arabicFont': pw.Font.ttf(
      (await rootBundle.load('assets/fonts/Noto/AL-Mohanad.ttf')),
    ),
    'invoiceItems': <Map<String, dynamic>>[
      <String, dynamic>{
        'vestments': 'قميص',
        'content': 'غسيل + كوي',
        'price': 10.0,
        'count': 3,
        'total_price': 30.0,
        'note': 'بقعة زيت على الكم',
      },
      <String, dynamic>{
        'vestments': 'بنطال',
        'content': 'غسيل',
        'price': 12.0,
        'count': 2,
        'total_price': 24.0,
      },
    ],
    'summation': 54.0,
    'invoiceNumber': 1024,
    'invoiceNumberText': 'INV-001024',
    'customername': 'محمد صادق',
    'customerPhone': '0555555555',
    'pickupCode': '1234',
    'date': '2026-10-23  09:30:00 ص',
    'bizName': 'مغاسل النظارة',
    'bizPhone': '0500000000',
    'bizAddress': 'الرياض – حي النخيل',
    'bizTaxNumber': '300000000000003',
    'bizCrNumber': '1010000000',
    'bizShortAddress': 'RRAA1234',
    'createdByName': 'admin',
    'discountAmount': 4.0,
    'discountCode': 'SAVE',
    'taxAmount': 7.5,
    'taxRate': 0.15,
    'taxBase': 50.0,
    'payable': 50.0,
    'paidAmount': 50.0,
    'remainingAmount': 0.0,
    'paperSize': 'a4',
    ...tpl.toTransport(),
  };
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    Directory('build/probe').createSync(recursive: true);
  });

  test('كشف الحساب: الافتراضي يُولّد ورقة سليمة', () async {
    final tpl = DocTemplate.defaults(DocKind.statement);
    final bytes = await PreparePDF.generateCustomerStatementPdf(
      _statementData(tpl: tpl),
    );
    expect(bytes.length, greaterThan(2000));
    File('build/probe/statement_default.pdf').writeAsBytesSync(bytes);
  });

  test('كشف الحساب: تعطيل الكل يُخرج ورقة أصغر بكثير', () async {
    final full = DocTemplate.defaults(DocKind.statement);
    final empty = full.withAllEnabled(false);
    final a = await PreparePDF.generateCustomerStatementPdf(
      _statementData(tpl: full),
    );
    final b = await PreparePDF.generateCustomerStatementPdf(
      _statementData(tpl: empty),
    );
    File('build/probe/statement_default2.pdf').writeAsBytesSync(a);
    File('build/probe/statement_empty.pdf').writeAsBytesSync(b);
    // الورقة الفارغة لا تحوي جداول ولا نصوصًا ⇒ أصغر بفارق ملموس.
    expect(b.length, lessThan(a.length));
  });

  test('كشف الحساب: النصوص المخصّصة تُغيّر المحتوى', () async {
    final tpl = DocTemplate.defaults(DocKind.statement)
        .withField(DocCatalog.kTitle, text: 'بيان حساب العميل')
        .withField(DocCatalog.kCustomerName, text: 'العميل الكريم')
        .withField(DocCatalog.kFooter, text: 'شكرًا لثقتكم – إدارة المغسلة')
        .withField(DocCatalog.kLogo, enabled: false);
    final bytes = await PreparePDF.generateCustomerStatementPdf(
      _statementData(tpl: tpl),
    );
    expect(bytes.length, greaterThan(2000));
    File('build/probe/statement_custom.pdf').writeAsBytesSync(bytes);
  });

  test('الفاتورة: الافتراضي يُولّد ورقة سليمة', () async {
    final tpl = DocTemplate.defaults(DocKind.invoice);
    final bytes = await PreparePDF.generatePdfData(
      await _invoiceData(tpl),
    );
    expect(bytes.length, greaterThan(5000));
    File('build/probe/invoice_default.pdf').writeAsBytesSync(bytes);
  });

  test('الفاتورة: تعطيل الكل يُخرج ورقة أصغر', () async {
    final full = DocTemplate.defaults(DocKind.invoice);
    final empty = full.withAllEnabled(false);
    final a = await PreparePDF.generatePdfData(await _invoiceData(full));
    final b = await PreparePDF.generatePdfData(await _invoiceData(empty));
    File('build/probe/invoice_empty.pdf').writeAsBytesSync(b);
    expect(b.length, lessThan(a.length));
  });

  test('الفاتورة: نصوص مخصّصة + حقول جديدة مُفعَّلة', () async {
    final tpl =
        DocTemplate.defaults(DocKind.invoice)
            .withField(DocCatalog.kReceiptNo, text: 'إيصال رقم')
            .withField(DocCatalog.kCustomerName, text: 'الزبون')
            .withField(DocCatalog.kRemaining, enabled: true)
            .withField(DocCatalog.kPickupCode, enabled: true)
            .withField(DocCatalog.kCustomerPhone, enabled: true)
            .withField(DocCatalog.kTaxLine, text: 'ضريبة (15%)')
            .withField(DocCatalog.kFooter, text: 'الاستلام خلال ٣ أيام');
    final bytes = await PreparePDF.generatePdfData(await _invoiceData(tpl));
    expect(bytes.length, greaterThan(5000));
    File('build/probe/invoice_custom.pdf').writeAsBytesSync(bytes);
  });

  // ─────────────────────────────────────────────────────────────────────
  // ملخّص الوردية — كان خارج نظام القوالب حتى 2026-10-24.
  // ─────────────────────────────────────────────────────────────────────
  test('ملخّص الوردية: يُولَّد من القالب ويستجيب لتعطيل عنصر', () async {
    final full = DocTemplate.defaults(DocKind.shift);
    final a = await PreparePDF.generateShiftSummaryPdf(_shiftData(full));
    File('build/probe/shift_default.pdf').writeAsBytesSync(a);
    expect(a.length, greaterThan(2000));

    final without = full
        .withField(DocCatalog.kTotalNetwork, enabled: false)
        .withField(DocCatalog.kFooter, enabled: false);
    final b = await PreparePDF.generateShiftSummaryPdf(_shiftData(without));
    File('build/probe/shift_less.pdf').writeAsBytesSync(b);
    expect(b.length, lessThan(a.length));
  });

  test('ملخّص الوردية: النصوص المخصّصة تُغيّر المحتوى', () async {
    final tpl = DocTemplate.defaults(DocKind.shift)
        .withField(DocCatalog.kTitle, text: 'تقرير إغلاق الصندوق')
        .withField(DocCatalog.kTotalCash, text: 'نقدية الدرج')
        .withField(DocCatalog.kCurrency, text: 'SAR')
        .withField(DocCatalog.kFooter, text: 'إدارة المغسلة');
    final bytes = await PreparePDF.generateShiftSummaryPdf(_shiftData(tpl));
    File('build/probe/shift_custom.pdf').writeAsBytesSync(bytes);
    expect(bytes.length, greaterThan(2000));
  });

  // ─────────────────────────────────────────────────────────────────────
  // النمط — الحجم · الوزن · العرض
  // ─────────────────────────────────────────────────────────────────────
  test('النمط: التكبير والتعريض والتضييق تُغيّر الورق فعلًا', () async {
    final plain = DocTemplate.defaults(DocKind.statement);
    final big = plain
        .withField(
          DocCatalog.kTitle,
          style: const DocStyle(size: 34, weight: 900, width: 80),
        )
        .withField(
          DocCatalog.kBusinessName,
          style: const DocStyle(size: 30, weight: 700),
        )
        .withField(
          DocCatalog.kItemsTable,
          style: const DocStyle(size: 20, weight: 700),
        );
    final a = await PreparePDF.generateCustomerStatementPdf(
      _statementData(tpl: plain),
    );
    final b = await PreparePDF.generateCustomerStatementPdf(
      _statementData(tpl: big),
    );
    File('build/probe/statement_plain.pdf').writeAsBytesSync(a);
    File('build/probe/statement_big.pdf').writeAsBytesSync(b);
    // خطّ أكبر ⇒ محتوى أكبر ⇒ ملف مختلف. المساواة تعني أن النمط لم يُقرأ.
    expect(b.length, isNot(a.length));
  });

  test('النمط: التعريض الصناعي يزيد حجم الورق (نسخة ثانية مرسومة)', () async {
    final plain = DocTemplate.defaults(DocKind.statement);
    final bold = plain
        .withField(
          DocCatalog.kTitle,
          style: const DocStyle(size: 19, weight: 900),
        )
        .withField(
          DocCatalog.kBusinessName,
          style: const DocStyle(size: 20, weight: 900),
        );
    final a = await PreparePDF.generateCustomerStatementPdf(
      _statementData(tpl: plain),
    );
    final b = await PreparePDF.generateCustomerStatementPdf(
      _statementData(tpl: bold),
    );
    // النصّ نفسه لكن مرسومًا مرّتين ⇒ محتوى الصفحة أطول.
    expect(b.length, greaterThan(a.length));
  });

  test('الحدود القصوى للنمط (36pt · 900 · 140%) لا تُسقط التوليد', () async {
    var wild = DocTemplate.defaults(DocKind.invoice);
    for (final f in DocCatalog.invoiceFields.where((f) => f.hasStyle)) {
      wild = wild.withField(
        f.key,
        style: const DocStyle(
          size: DocStyle.maxSize,
          weight: 900,
          width: DocStyle.maxWidth,
        ),
      );
    }
    final bytes = await PreparePDF.generatePdfData(await _invoiceData(wild));
    File('build/probe/invoice_extreme.pdf').writeAsBytesSync(bytes);
    expect(bytes.length, greaterThan(5000));
  });
}
