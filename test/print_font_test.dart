// اختبار خطوط الطباعة — يثبت أن **كل** خطّ في السجلّ يطبع فاتورة فعلية.
//
// **لماذا اختبار توليد حقيقي لا فحص نصّي؟** لأن الخطر هنا صامت: مفتاح خطّ
// في `settings` لا يقابله ملفّ محزوم ⇒ تُطبع الفاتورة بخطّ آخر بلا خطأ، أو
// يُرمى استثناء وقت الطباعة عند العميل. الحرس النصّي لا يرى ذلك؛ هذا الاختبار
// يُولّد PDF فعليًا بكل خطّ ويكتبه في `build/probe/` للفحص البصري.
//
// التشغيل: flutter test test/print_font_test.dart
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laundry/core/services/preparePDF.dart';
import 'package:laundry/services/pdf/doc_template.dart';
import 'package:laundry/services/pdf/print_font.dart';
import 'package:pdf/widgets.dart' as pw;

Future<Uint8List> _asset(String path) async {
  final d = await rootBundle.load(path);
  return d.buffer.asUint8List();
}

Future<pw.Font> _fontOf(PrintFont f) async =>
    pw.Font.ttf(await rootBundle.load(f.asset));

Future<Map<String, dynamic>> _invoiceData(pw.Font font) async {
  return <String, dynamic>{
    'payment': 'نقد',
    'logoImage': await _asset('assets/images/logo-wash.png'),
    'riyalImage': await _asset('assets/images/saudi_riyal.png'),
    'arabicFont': font,
    'invoiceItems': <Map<String, dynamic>>[
      <String, dynamic>{
        'vestments': 'قميص',
        'content': 'غسيل + كوي',
        'price': 10.0,
        'count': 3,
        'total_price': 30.0,
        'note': 'بقعة زيت على الكم',
      },
    ],
    'summation': 30.0,
    'invoiceNumber': 1024,
    'invoiceNumberText': 'INV-001024',
    'customername': 'محمد صادق',
    'customerPhone': '0555555555',
    'pickupCode': '1234',
    'date': '2026-10-24  09:30:00 ص',
    'bizName': 'مغاسل النظارة',
    'bizPhone': '0500000000',
    'bizAddress': 'الرياض – حي النخيل',
    'bizTaxNumber': '300000000000003',
    'bizCrNumber': '1010000000',
    'bizShortAddress': 'RRAA1234',
    'createdByName': 'admin',
    'discountAmount': 0.0,
    'taxAmount': 0.0,
    'taxRate': 0.0,
    'taxBase': 30.0,
    'payable': 30.0,
    'paperSize': 'a4',
    ...DocTemplate.defaults(DocKind.invoice).toTransport(),
  };
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('سجلّ خطوط الطباعة', () {
    test('الافتراضي هو خطّ النظام السابق', () {
      expect(PrintFonts.defaultKey, 'al_mohanad');
      expect(
        PrintFonts.byKey(PrintFonts.defaultKey).asset,
        'assets/fonts/Noto/AL-Mohanad.ttf',
      );
    });

    test('مفتاح مجهول لا يرمي ويعود للافتراضي', () {
      expect(PrintFonts.byKey('خطّ_غير_موجود').key, PrintFonts.defaultKey);
      expect(PrintFonts.byKey(null).key, PrintFonts.defaultKey);
      expect(PrintFonts.byKey('').key, PrintFonts.defaultKey);
      expect(PrintFonts.isKnown('trad'), false);
    });

    test('كل خطّ له استخدام محدَّد وتسمية', () {
      for (final f in PrintFonts.all) {
        expect(f.thermal || f.paper, true, reason: f.key);
        expect(f.usageLabel.trim().isEmpty, false, reason: f.key);
        expect(f.note.trim().isEmpty, false, reason: f.key);
      }
      expect(PrintFonts.forThermal, isNotEmpty);
      expect(PrintFonts.forPaper, isNotEmpty);
    });
  });

  group('كل خطّ يطبع فاتورة فعلية', () {
    for (final f in PrintFonts.all) {
      test('${f.key} (${f.label})', () async {
        final font = await _fontOf(f);
        final bytes = await PreparePDF.generatePdfData(await _invoiceData(font));
        // ورقة A4 بنصّ عربي وكائنات خطّ مضمَّنة لا تقلّ عن هذا الحجم.
        expect(bytes.length, greaterThan(8000), reason: f.key);
        // رأس PDF صالح — أي فشل في الخطّ يظهر هنا لا عند العميل.
        expect(String.fromCharCodes(bytes.sublist(0, 5)), '%PDF-');

        Directory('build/probe').createSync(recursive: true);
        File(
          'build/probe/printfont_${f.key}.pdf',
        ).writeAsBytesSync(bytes);
      });
    }
  });

  test('الخطوط تنتج أوراقًا مختلفة (الخطّ يصل إلى الورق فعلًا)', () async {
    final a = await PreparePDF.generatePdfData(
      await _invoiceData(await _fontOf(PrintFonts.byKey('al_mohanad'))),
    );
    final b = await PreparePDF.generatePdfData(
      await _invoiceData(await _fontOf(PrintFonts.byKey('amiri'))),
    );
    // خطّان مختلفان ⇒ ملفّان مختلفان. لو كان الخطّ يُتجاهَل لتساوى الحجمان.
    expect(a.length, isNot(b.length));
  });

  test('كل ملفّ خطّ مقروء بـrootBundle (محزوم لا ناقص)', () async {
    for (final f in PrintFonts.all) {
      final data = await rootBundle.load(f.asset);
      expect(data.lengthInBytes, greaterThan(20000), reason: f.key);
    }
  });

  // الإيصال الحراري 80 مم هو المكان الذي تظهر فيه جودة الخطّ حقًّا:
  // 8–10 نقاط وحبر بلا تدرّج. نولّد إيصالًا فعليًا لكل خطّ موصى به للحراري.
  group('الإيصال الحراري 80 مم', () {
    for (final f in PrintFonts.forThermal) {
      test('${f.key} يطبع إيصالًا حراريًا', () async {
        final data = await _invoiceData(await _fontOf(f));
        data['paperSize'] = 'receipt_80mm';
        final bytes = await PreparePDF.generatePdfData(data);
        expect(bytes.length, greaterThan(3000), reason: f.key);
        File(
          'build/probe/thermal_${f.key}.pdf',
        ).writeAsBytesSync(bytes);
      });
    }
  });
}
