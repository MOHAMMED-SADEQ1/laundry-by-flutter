// اختبار ورقة المغسلة (نسخة المحل) — بيانات + توليد PDF فعلي.
//
// **لماذا اختبار توليد حقيقي؟** لأن الخطر الحقيقي في هذه الورقة هو تسرّب
// مبالغ مالية إلى ورقة تُعطى للعامل، أو انهيار التوليد على ورق حراري ضيّق.
// فالاختبار يتحقّق من:
//   1. الحمولة خالية تمامًا من أي مفتاح مالي (سعر · خصم · ضريبة · QR).
//   2. تطبيع بنود السلة (`vestments`/`count`) ولقطة `invoice_items`
//      (`item_name`/`qty`) على السواء.
//   3. أن المقاس يتبع مقاس الفاتورة (لا مقاس مستقلّ) وأن الحراري يُقدَّر
//      من طول المحتوى.
//   4. أن التوليد ينجح على A4 و80 مم و58 مم وقائمة طويلة.
//   5. أن **قالب الورقة** يتحكّم فعلًا: النصوص والأحجام والتعطيل تُغيّر الورق،
//      وأن السجلّ خالٍ من أي حقل مالي.
//
// التشغيل: flutter test test/laundry_slip_test.dart
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laundry/services/pdf/doc_template.dart';
import 'package:laundry/services/pdf/laundry_slip.dart';
import 'package:laundry/services/pdf/laundry_slip_pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// المفاتيح الممنوعة — أي ظهور لها في الحمولة يعني تسرّبًا ماليًا.
const Set<String> _forbiddenKeys = <String>{
  'price',
  'unit_price',
  'total_price',
  'summation',
  'discount',
  'discountAmount',
  'tax',
  'taxAmount',
  'taxRate',
  'taxBase',
  'vat',
  'qr',
  'zatca',
  'payment',
  'paidAmount',
  'remainingAmount',
  'payable',
  'total',
  'currency',
};

/// يمشي على الحمولة كلها ويتأكّد أن لا مفتاح مالي في أي عمق.
void _expectNoMoney(dynamic node) {
  if (node is Map) {
    for (final entry in node.entries) {
      final key = '${entry.key}'.toLowerCase();
      expect(
        _forbiddenKeys.contains(key),
        isFalse,
        reason: 'تسرّب مفتاح مالي إلى ورقة المغسلة: ${entry.key}',
      );
      _expectNoMoney(entry.value);
    }
    return;
  }
  if (node is Iterable) {
    for (final item in node) {
      _expectNoMoney(item);
    }
  }
}

/// بنود شاشة البيع — تحمل أسعارًا يجب ألا تصل إلى الورقة.
List<Map<String, dynamic>> _saleItems() => <Map<String, dynamic>>[
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
  <String, dynamic>{
    'vestments': 'فستان',
    'content': 'تنظيف جاف',
    'price': 25.0,
    'count': 1,
    'total_price': 25.0,
    'note': 'كسر زر',
  },
];

/// لقطة `invoice_items` المخزَّنة — أسماء أعمدة مختلفة.
List<Map<String, dynamic>> _snapshotItems() => <Map<String, dynamic>>[
  <String, dynamic>{
    'item_name': 'قميص',
    'content': 'غسيل + كوي',
    'qty': 3,
    'unit_price': 10.0,
    'total_price': 30.0,
    'note': 'بقعة زيت',
  },
  <String, dynamic>{
    'item_name': 'بنطال',
    'content': 'غسيل',
    'qty': 2,
    'unit_price': 12.0,
    'total_price': 24.0,
    'note': '',
  },
];

LaundrySlipData _data({
  required List<Map<String, dynamic>> items,
  String paperSize = 'a4',
  bool isRtl = true,
}) => LaundrySlipData.fromItems(
  items: items,
  invoiceNumber: 'INV-001024',
  date: '2026-10-23 09:30 ص',
  customerName: 'محمد صادق',
  customerPhone: '0555555555',
  pickupCode: '1234',
  bizName: 'مغاسل النظارة',
  bizPhone: '0500000000',
  paperSize: paperSize,
  isRtl: isRtl,
);

/// حمولة المولّد كما تُبنى في مسار الطباعة — بلا خطّ (للمقاس فقط).
Map<String, dynamic> _payload(LaundrySlipData data, [DocTemplate? template]) =>
    <String, dynamic>{
      ...data.toMap(),
      if (template != null) ...template.toTransport(),
    };

Future<Uint8List> _generate(
  LaundrySlipData data, {
  bool showLogo = false,
  DocTemplate? template,
  Uint8List? logo,
}) async {
  final font = pw.Font.ttf(
    await rootBundle.load('assets/fonts/Noto/AL-Mohanad.ttf'),
  );
  return LaundrySlipPdf.generateLaundrySlipPdf(<String, dynamic>{
    ...data.toMap(),
    if (template != null) ...template.toTransport(),
    'arabicFont': font,
    'showLogo': showLogo,
    if (logo != null) 'logoImage': logo,
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    Directory('build/probe').createSync(recursive: true);
  });

  group('بيانات ورقة المغسلة', () {
    test('بنود السلة: الأسعار لا تصل إلى الحمولة', () {
      final data = _data(items: _saleItems());
      final map = data.toMap();

      _expectNoMoney(map);
      expect(map['invoiceNumber'], 'INV-001024');
      expect(map['customerName'], 'محمد صادق');
      expect(map['pickupCode'], '1234');
      expect((map['items'] as List).length, 3);
      expect(map['totalPieces'], 6);
      expect(map['itemsCount'], 3);
      expect(map['paperSize'], 'a4');
      expect(map['docLang'], 'ar');
    });

    test('لقطة invoice_items تُطبَّع بنفس الشكل وتُجمع قطعها', () {
      final data = _data(items: _snapshotItems());
      final map = data.toMap();

      _expectNoMoney(map);
      expect(data.items.length, 2);
      expect(data.items.first.name, 'قميص');
      expect(data.items.first.qty, 3);
      expect(data.items.first.service, 'غسيل + كوي');
      expect(data.items.first.note, 'بقعة زيت');
      expect(data.totalPieces, 5);
      expect(map['itemsCount'], 2);
    });

    test('البنود الفارغة تُسقَط ولا تُحسب', () {
      final data = _data(
        items: <Map<String, dynamic>>[
          <String, dynamic>{'vestments': '  ', 'count': 9},
          <String, dynamic>{'vestments': 'جاكيت', 'count': 2},
        ],
      );
      expect(data.items.length, 1);
      expect(data.totalPieces, 2);
    });

    test('الوضع الإنجليزي يُختم في الحمولة', () {
      final data = _data(
        items: <Map<String, dynamic>>[
          <String, dynamic>{
            'vestments': 'قميص',
            'vestments_en': 'Shirt',
            'content': 'غسيل',
            'content_en': 'Wash',
            'count': 2,
          },
        ],
        isRtl: false,
      );
      final map = data.toMap();
      expect(map['docLang'], 'en');
      expect(map['docEnglish'], isA<Map>());
      expect(data.items.first.name, 'Shirt');
      expect(data.items.first.service, 'Wash');
    });

    test('الورقة بلا بنود لا تنهار', () {
      final data = _data(items: const <Map<String, dynamic>>[]);
      expect(data.isEmpty, isTrue);
      expect(data.totalPieces, 0);
      expect(data.toMap()['items'], isEmpty);
    });
  });

  group('المقاس يتبع الفاتورة', () {
    test('A4 وA5 وA6 تُعيد المقاس نفسه بلا تعديل', () {
      for (final token in <String>['a4', 'a5', 'a6']) {
        final paper = LaundrySlipPdf.paperFor(
          _data(items: _saleItems(), paperSize: token),
        );
        expect(paper.token, token);
        expect(paper.isThermal, isFalse);
      }
    });

    test('الحراري يحفظ العرض ويُقدّر الارتفاع من المحتوى', () {
      final short = LaundrySlipPdf.paperFor(
        _data(items: _saleItems().take(1).toList(), paperSize: 'receipt_80mm'),
      );
      final long = LaundrySlipPdf.paperFor(
        _data(items: _saleItems(), paperSize: 'receipt_80mm'),
      );

      expect(short.isThermal, isTrue);
      expect(short.widthMm, 80);
      expect(long.widthMm, 80);
      expect(long.heightMm, greaterThanOrEqualTo(short.heightMm));
      expect(long.heightMm, lessThanOrEqualTo(500));
      expect(short.heightMm, greaterThanOrEqualTo(80));
    });

    test('58 مم يبقى 58 مم مهما طال المحتوى', () {
      final paper = LaundrySlipPdf.paperFor(
        _data(items: _saleItems(), paperSize: 'receipt_58mm'),
      );
      expect(paper.widthMm, 58);
      expect(paper.isThermal, isTrue);
    });

    test('الشعار يزيد ارتفاع الحراري المقدَّر', () {
      final plain = LaundrySlipPdf.paperFor(
        _data(items: _saleItems(), paperSize: 'receipt_80mm'),
      );
      final withLogo = LaundrySlipPdf.paperFor(
        _data(items: _saleItems(), paperSize: 'receipt_80mm'),
        hasLogo: true,
      );
      expect(withLogo.heightMm, greaterThan(plain.heightMm));
    });
  });

  group('توليد PDF', () {
    test('A4: يولّد ورقة سليمة', () async {
      final bytes = await _generate(_data(items: _saleItems()));
      expect(bytes.length, greaterThan(1000));
      File('build/probe/laundry_slip_a4.pdf').writeAsBytesSync(bytes);
    });

    test('حراري 80 مم: يولّد ورقة سليمة', () async {
      final bytes = await _generate(
        _data(items: _saleItems(), paperSize: 'receipt_80mm'),
      );
      expect(bytes.length, greaterThan(1000));
      File('build/probe/laundry_slip_80mm.pdf').writeAsBytesSync(bytes);
    });

    test('حراري 58 مم: يولّد ورقة سليمة', () async {
      final bytes = await _generate(
        _data(items: _saleItems(), paperSize: 'receipt_58mm'),
      );
      expect(bytes.length, greaterThan(1000));
      File('build/probe/laundry_slip_58mm.pdf').writeAsBytesSync(bytes);
    });

    test('A6: يولّد ورقة سليمة', () async {
      final bytes = await _generate(
        _data(items: _saleItems(), paperSize: 'a6'),
      );
      expect(bytes.length, greaterThan(1000));
      File('build/probe/laundry_slip_a6.pdf').writeAsBytesSync(bytes);
    });

    test('قائمة طويلة على الحراري تتجاوز صفحة واحدة بلا انهيار', () async {
      final items = <Map<String, dynamic>>[
        for (var i = 1; i <= 80; i++)
          <String, dynamic>{
            'vestments': 'صنف رقم $i',
            'content': 'غسيل',
            'count': i % 4 + 1,
            'price': 5.0,
            'total_price': 5.0,
            if (i % 5 == 0) 'note': 'ملاحظة على البند $i',
          },
      ];
      final bytes = await _generate(
        _data(items: items, paperSize: 'receipt_80mm'),
      );
      expect(bytes.length, greaterThan(1000));
      File('build/probe/laundry_slip_80mm_long.pdf').writeAsBytesSync(bytes);
    });

    test('الوضع الإنجليزي يولّد بلا انهيار', () async {
      final bytes = await _generate(
        _data(
          items: _saleItems(),
          paperSize: 'receipt_80mm',
          isRtl: false,
        ),
      );
      expect(bytes.length, greaterThan(1000));
      File('build/probe/laundry_slip_en.pdf').writeAsBytesSync(bytes);
    });

    test('الشعار لا يكسر التوليد', () async {
      final font = pw.Font.ttf(
        await rootBundle.load('assets/fonts/Noto/AL-Mohanad.ttf'),
      );
      final logo = await rootBundle.load('assets/images/logo-wash.png');
      final data = _data(items: _saleItems(), paperSize: 'receipt_80mm');
      final bytes = await LaundrySlipPdf.generateLaundrySlipPdf(
        <String, dynamic>{
          ...data.toMap(),
          'arabicFont': font,
          'logoImage': logo.buffer.asUint8List(),
          'showLogo': true,
        },
      );
      expect(bytes.length, greaterThan(1000));
    });
  });

  // ─────────────────────────────────────────────────────────────────────
  // قالب الورقة — نفس نظام «قوالب الطباعة» الذي تتحكّم به الفاتورة.
  // ─────────────────────────────────────────────────────────────────────
  group('قالب ورقة المغسلة', () {
    test('السجلّ خالٍ من أي حقل مالي', () {
      // أي كلمة مالية في اسم الحقل أو شرحه أو نصّه تعني ورقة تُعطى للعامل
      // وفيها مبلغ — وهو ما تمنعه هذه الورقة تصميمًا.
      const moneyWords = <String>[
        'سعر',
        'ريال',
        'ضريبة',
        'خصم',
        'مبلغ',
        'الدفع',
        'المستحق',
      ];
      for (final f in DocCatalog.laundrySlipFields) {
        final text = '${f.label} ${f.hint} ${f.defaultText}';
        for (final word in moneyWords) {
          expect(
            text.contains(word),
            isFalse,
            reason: 'حقل «${f.key}» يحمل كلمة مالية: $word',
          );
        }
      }

      final keys = DocCatalog.laundrySlipFields.map((f) => f.key).toSet();
      for (final forbidden in <String>[
        DocCatalog.kItemPrice,
        DocCatalog.kDiscount,
        DocCatalog.kTaxLine,
        DocCatalog.kTotalAmount,
        DocCatalog.kQr,
        DocCatalog.kCurrency,
      ]) {
        expect(keys, isNot(contains(forbidden)), reason: forbidden);
      }
    });

    test('الافتراضي يُبقي الشكل الحالي: كل الحقول مُفعَّلة', () {
      final tpl = DocTemplate.defaults(DocKind.laundrySlip);
      expect(tpl.kind, DocKind.laundrySlip);
      expect(
        DocCatalog.storageKey(DocKind.laundrySlip),
        'doc_template_laundry_slip',
      );
      for (final f in DocCatalog.laundrySlipFields) {
        expect(tpl.isOn(f.key), isTrue, reason: 'حقل «${f.key}» افتراضيًّا معطَّل');
      }
      // عنوان الورقة وعنوانها الفرعي لهما نصّ افتراضي مفهوم خارج الشاشة.
      expect(
        tpl.textOf(DocCatalog.kTitle),
        DocCatalog.slipTitleDefault,
      );
      expect(
        tpl.textOf(DocCatalog.kSlipSubtitle),
        DocCatalog.slipSubtitleDefault,
      );
    });

    test('النقل يقرأ النصوص والأنماط المخصّصة من الحمولة', () {
      final tpl =
          DocTemplate.defaults(DocKind.laundrySlip)
              .withField(DocCatalog.kTitle, text: 'نسخة العامل')
              .withField(DocCatalog.kBusinessName, text: 'مغاسل النخبة')
              // الفراغ = الافتراضي، لا نصّ فارغ على الورق.
              .withField(DocCatalog.kSlipSubtitle, text: '   ')
              .withField(
                DocCatalog.kTitle,
                style: const DocStyle(size: 22, weight: 900, width: 90),
              );
      final view = DocTemplateView.of(
        _payload(_data(items: _saleItems()), tpl),
        DocKind.laundrySlip,
      );

      expect(view.text(DocCatalog.kTitle), 'نسخة العامل');
      expect(view.text(DocCatalog.kBusinessName), 'مغاسل النخبة');
      expect(
        view.text(DocCatalog.kSlipSubtitle),
        DocCatalog.slipSubtitleDefault,
      );
      expect(view.style(DocCatalog.kTitle).size, 22);
      expect(view.style(DocCatalog.kTitle).weight, 900);
      expect(view.style(DocCatalog.kTitle).width, 90);
    });

    test('نصوص مخصّصة تُغيّر الورق فعلًا', () async {
      final plain = DocTemplate.defaults(DocKind.laundrySlip);
      final custom =
          plain
              .withField(DocCatalog.kTitle, text: 'نسخة العامل')
              .withField(DocCatalog.kBusinessName, text: 'مغاسل النخبة')
              .withField(DocCatalog.kTotalPieces, text: 'مجموع القطع');
      final a = await _generate(_data(items: _saleItems()), template: plain);
      final b = await _generate(_data(items: _saleItems()), template: custom);
      File('build/probe/laundry_slip_custom.pdf').writeAsBytesSync(b);
      expect(b.length, greaterThan(1000));
      // مساواة الحجمين تعني أن النصّ المخزَّن لم يُقرأ إطلاقًا.
      expect(b, isNot(equals(a)));
    });

    test('تعطيل كل العناصر يُولّد ورقة أصغر بلا انهيار', () async {
      final full = DocTemplate.defaults(DocKind.laundrySlip);
      final empty = full.withAllEnabled(false);
      final a = await _generate(_data(items: _saleItems()), template: full);
      final b = await _generate(_data(items: _saleItems()), template: empty);
      File('build/probe/laundry_slip_empty.pdf').writeAsBytesSync(b);
      expect(b.length, greaterThan(500));
      expect(b.length, lessThan(a.length));
    });

    test('الحجم والوزن من القالب يُغيّران الورق', () async {
      final plain = DocTemplate.defaults(DocKind.laundrySlip);
      final styled =
          plain
              .withField(
                DocCatalog.kTitle,
                style: const DocStyle(size: 24, weight: 900),
              )
              .withField(
                DocCatalog.kBusinessName,
                style: const DocStyle(size: 24, weight: 900),
              );
      final a = await _generate(_data(items: _saleItems()), template: plain);
      final b = await _generate(_data(items: _saleItems()), template: styled);
      File('build/probe/laundry_slip_styled.pdf').writeAsBytesSync(b);
      // النمط لا يُقرأ ⇒ المحتوى يتطابق حرفيًّا.
      expect(b, isNot(equals(a)));
    });

    test('الحراري: تعطيل الحقول يقلّل الارتفاع المقدَّر', () {
      final data = _data(items: _saleItems(), paperSize: 'receipt_80mm');
      final full = DocTemplate.defaults(DocKind.laundrySlip);
      final empty = full.withAllEnabled(false);

      final a = LaundrySlipPdf.paperForData(_payload(data, full));
      final b = LaundrySlipPdf.paperForData(_payload(data, empty));

      expect(b.heightMm, lessThan(a.heightMm));
      // الحدّ الأدنى المقروء محفوظ: لا ورقة بحجم صفر.
      expect(b.heightMm, greaterThanOrEqualTo(80));
      expect(b.widthMm, 80);
    });

    test('تعطيل ملاحظة البند يلغي احتساب أسطر الملاحظات', () {
      final data = _data(items: _saleItems(), paperSize: 'receipt_80mm');
      final full = DocTemplate.defaults(DocKind.laundrySlip);
      final noNotes = full.withField(DocCatalog.kItemNote, enabled: false);

      final a = LaundrySlipPdf.paperForData(_payload(data, full));
      final b = LaundrySlipPdf.paperForData(_payload(data, noNotes));

      // البنود الثلاثة فيها ملاحظتان — تعطيل الحقل يوفّر سطريهما (6 مم
      // للسطر على 80 مم).
      expect(b.heightMm, lessThan(a.heightMm));
      expect(a.heightMm - b.heightMm, closeTo(12, 0.01));
    });

    test('تعطيل الشعار في القالب يمنع احتساب ارتفاعه', () {
      final data = _data(items: _saleItems(), paperSize: 'receipt_80mm');
      final full = DocTemplate.defaults(DocKind.laundrySlip);
      // بايتات شكلية: التقدير يفحص النوع فقط ولا يفكّ الصورة.
      final withLogo = _payload(data, full)
        ..['logoImage'] = Uint8List.fromList(<int>[1, 2, 3])
        ..['showLogo'] = true;
      final logoOff = _payload(
        data,
        full.withField(DocCatalog.kLogo, enabled: false),
      )
        ..['logoImage'] = Uint8List.fromList(<int>[1, 2, 3])
        ..['showLogo'] = true;

      final a = LaundrySlipPdf.paperForData(withLogo);
      final b = LaundrySlipPdf.paperForData(logoOff);
      expect(b.heightMm, lessThan(a.heightMm));
    });
  });
}
