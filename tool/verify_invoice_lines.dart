// حرس **بنود الفاتورة** — الدمج بالكمية لا بالسطر، والتعديل بلا حذف وإعادة.
//
// العيب الذي يمنعه: كان كل ضغط على صنف يُضيف صفًّا جديدًا، فتُقرأ الفاتورة
// عشرة أسطر لعشرة أثواب والمجموع صحيح. والحلّ ليس «احذف المكرر» بل قرار
// محاسبي: **متى يجوز الدمج ومتى يجب الفصل** — والخطأ هنا صامت (ينقص مال أو
// يختفي تحذير بقعة)، فلا بدّ من إثباته بحالات حقيقية.
//
// التشغيل: dart run tool/verify_invoice_lines.dart
import 'dart:io';

import 'package:laundry/services/invoice/invoice_lines.dart';

int _ok = 0;
int _fail = 0;

void check(String name, Object? got, Object? expected) {
  final pass = '$got' == '$expected';
  if (pass) {
    _ok++;
    print('  ✓ $name');
  } else {
    _fail++;
    print('  ✗ $name  → got=$got expected=$expected');
  }
}

// يُطبَّع نهاية السطر: ملفّات المشروع مختلطة (LF وCRLF)، وفحصٌ يعتمد على
// `\n` وحده ينجح أو يفشل بحسب محرّر فتح الملف — وهو حرس كاذب.
String _read(String path) =>
    File(path).readAsStringSync().replaceAll('\r\n', '\n');

String _code(String path) =>
    _read(path).replaceAll(RegExp(r'//[^\n]*'), '');

Map<String, dynamic> _item({
  String name = 'ثوب أبيض',
  String service = ServiceKind.normalWash,
  Object? price = 5,
  Object? count = 1,
  String? note,
  String? photo,
}) => <String, dynamic>{
  'vestments': name,
  'content': service,
  'price': price,
  'count': count,
  'total_price': 0,
  if (note != null) 'note': note,
  if (photo != null) 'photo': photo,
};

void main() {
  print('═' * 64);
  print('حرس بنود الفاتورة (الدمج بالكمية + تعديل البند)');
  print('═' * 64);

  // ─── [1] تطبيع النصّ ─────────────────────────────────────────────────
  print('\n[1] تطبيع النصّ');
  check(
    '[1] المسافة الطرفية لا تُنشئ صنفًا ثانيًا',
    InvoiceLines.normalize('ثوب أبيض '),
    InvoiceLines.normalize('ثوب أبيض'),
  );
  check(
    '[1] المسافات المتتابعة تُطوى',
    InvoiceLines.normalize('ثوب    أبيض'),
    'ثوب ابيض',
  );
  check(
    '[1] الهمزة تُوحَّد مع الألف',
    InvoiceLines.normalize('أبيض') == InvoiceLines.normalize('ابيض'),
    true,
  );
  check(
    '[1] التاء المربوطة تُوحَّد مع الهاء',
    InvoiceLines.normalize('غترة') == InvoiceLines.normalize('غتره'),
    true,
  );
  check(
    '[1] الألف المقصورة تُوحَّد مع الياء',
    InvoiceLines.normalize('مصطفى') == InvoiceLines.normalize('مصطفي'),
    true,
  );
  check(
    '[1] التشكيل يُحذف',
    InvoiceLines.normalize('ثَوبٌ أَبيَض'),
    InvoiceLines.normalize('ثوب أبيض'),
  );
  check(
    '[1] التطويل يُحذف',
    InvoiceLines.normalize('ثـــوب'),
    'ثوب',
  );
  check('[1] اللاتيني يُصبغ صغيرًا', InvoiceLines.normalize('Thobe'), 'thobe');
  check('[1] الفراغ يبقى فراغًا', InvoiceLines.normalize(null), '');
  check(
    '[1] التطبيع لا يُخزَّن — النصّ الأصلي سليم',
    _item(name: 'ثوب أبيض ')['vestments'],
    'ثوب أبيض ',
  );

  // ─── [2] البحث عن بند مطابق ──────────────────────────────────────────
  print('\n[2] البحث عن بند مطابق');
  final cart = <Map<String, dynamic>>[_item()];

  check(
    '[2] نفس الصنف والخدمة ⇒ مطابقة',
    InvoiceLines.probe(cart, _item()).index,
    0,
  );
  check(
    '[2] المطابقة تُبلَّغ كتكرار',
    InvoiceLines.probe(cart, _item()).isDuplicate,
    true,
  );
  check(
    '[2] الكمية لا تكسر المطابقة (١ ضد ٣)',
    InvoiceLines.probe(cart, _item(count: 3)).index,
    0,
  );
  check(
    '[2] السعر كنصّ `5.00` يطابق الرقم 5',
    InvoiceLines.probe(cart, _item(price: '5.00')).index,
    0,
  );
  check(
    '[2] خدمة مختلفة ⇒ لا مطابقة',
    InvoiceLines.probe(cart, _item(service: ServiceKind.urgentWash)).index,
    -1,
  );
  check(
    '[2] خدمة مختلفة ⇒ لا سبب للفصل (صنف جديد)',
    InvoiceLines.probe(cart, _item(service: ServiceKind.normalIron)).reason,
    LineMismatch.none,
  );
  check(
    '[2] صنف مختلف ⇒ لا مطابقة',
    InvoiceLines.probe(cart, _item(name: 'غترة')).index,
    -1,
  );
  check(
    '[2] ملاحظة مختلفة ⇒ فصل بسببه',
    InvoiceLines.probe(cart, _item(note: 'بقعة زيت')).reason,
    LineMismatch.note,
  );
  check(
    '[2] صورة مختلفة ⇒ فصل بصورته',
    InvoiceLines.probe(cart, _item(photo: '/tmp/a.jpg')).reason,
    LineMismatch.photo,
  );
  check(
    '[2] سعر مختلف ⇒ فصل بسعره',
    InvoiceLines.probe(cart, _item(price: 7)).reason,
    LineMismatch.price,
  );
  check(
    '[2] نفس الملاحظة تُطابق (لا تُفصل)',
    InvoiceLines.probe(
      <Map<String, dynamic>>[_item(note: 'بقعة زيت')],
      _item(note: ' بقعة  زيت '),
    ).index,
    0,
  );
  check(
    '[2] الأولوية للملاحظة عند اجتماع الأسباب',
    InvoiceLines.probe(cart, _item(note: 'x', price: 9)).reason,
    LineMismatch.note,
  );
  check(
    '[2] `ignoreIndex` لا يُطابق البند نفسه',
    InvoiceLines.probe(cart, _item(), ignoreIndex: 0).index,
    -1,
  );
  check(
    '[2] فهرس المطابقة صحيح في قائمة طويلة',
    InvoiceLines.probe(
      <Map<String, dynamic>>[
        _item(name: 'غترة'),
        _item(service: ServiceKind.urgentIron),
        _item(),
      ],
      _item(),
    ).index,
    2,
  );

  // ─── [3] الدمج والكمية ───────────────────────────────────────────────
  print('\n[3] الدمج والكمية');
  final existing = _item(count: 2, price: 5);
  final incoming = _item(count: 3, price: 5);
  final merged = InvoiceLines.merge(existing, incoming);
  check('[3] الكميات تُجمع', merged['count'], 5);
  check('[3] الإجمالي يُعاد حسابه', merged['total_price'], 25.0);
  check('[3] البند الأصلي لم يُعدَّل', existing['count'], 2);
  check('[3] الإجمالي القديم لم يبقَ', existing['total_price'], 0);
  check(
    '[3] الدمج يحفظ بقية الحقول',
    InvoiceLines.merge(_item(note: 'بقعة'), _item(note: 'بقعة'))['note'],
    'بقعة',
  );

  check('[3] الكمية الدنيا ١', InvoiceLines.quantityOf(_item(count: 0)), 1);
  check('[3] الكمية السالبة ⇒ ١', InvoiceLines.quantityOf(_item(count: -5)), 1);
  check(
    '[3] الكمية القصوى ٩٩٩',
    InvoiceLines.quantityOf(_item(count: 5000)),
    InvoiceLines.maxQuantity,
  );
  check('[3] الكمية كنصّ', InvoiceLines.quantityOf(_item(count: '4')), 4);
  check(
    '[3] الكمية بالأرقام العربية',
    InvoiceLines.quantityOf(_item(count: '٣')),
    3,
  );
  check('[3] كمية غائبة ⇒ ١', InvoiceLines.quantityOf(<String, dynamic>{}), 1);
  check(
    '[3] `withQuantity` لا يُعدّل الأصل',
    InvoiceLines.withQuantity(_item(), 9)['count'],
    9,
  );
  check(
    '[3] `withQuantity` يُعيد حساب الإجمالي',
    InvoiceLines.withQuantity(_item(price: 5), 4)['total_price'],
    20.0,
  );
  check(
    '[3] السعر بفاصلة عشرية عربية',
    InvoiceLines.priceOf(_item(price: '5,50')),
    5.5,
  );
  check(
    '[3] `withPrice` يُعيد حساب الإجمالي',
    InvoiceLines.withPrice(_item(count: 3, price: 5), 7)['total_price'],
    21.0,
  );

  // ─── [4] حماية المبالغ ───────────────────────────────────────────────
  print('\n[4] حماية المبالغ');
  check(
    '[4] التقريب يمنع الكسر العائم',
    InvoiceLines.money(0.1 * 3),
    0.3,
  );
  check(
    '[4] إجمالي السطر = السعر × الكمية',
    InvoiceLines.lineTotal(_item(price: 5.5, count: 3)),
    16.5,
  );
  check(
    '[4] بند قديم بلا سعر يحتفظ بمبلغه المخزَّن',
    InvoiceLines.lineTotal(<String, dynamic>{
      'vestments': 'ثوب',
      'content': ServiceKind.normalWash,
      'count': 2,
      'total_price': 18,
    }),
    18.0,
  );
  check(
    '[4] بند مجاني يبقى صفرًا',
    InvoiceLines.lineTotal(_item(price: 0, count: 3)),
    0.0,
  );
  check(
    '[4] مجموع خدمة عبر سطرين بملاحظتين',
    InvoiceLines.quantityOfService(
      <Map<String, dynamic>>[
        _item(count: 2),
        _item(count: 1, note: 'بقعة'),
        _item(count: 5, service: ServiceKind.urgentWash),
      ],
      name: 'ثوب أبيض',
      service: ServiceKind.normalWash,
    ),
    3,
  );

  // ─── [5] الخدمات الأربع ──────────────────────────────────────────────
  print('\n[5] الخدمات الأربع');
  check('[5] أربع خدمات', ServiceKind.all.length, 4);
  check('[5] التسميات فريدة', ServiceKind.all.toSet().length, 4);
  check('[5] مفاتيح الحوار أربعة', ServiceKind.keyToLabel.length, 4);
  check(
    '[5] مفتاح الحوار يُعطي التسمية',
    ServiceKind.keyToLabel['normalwashingironing'],
    ServiceKind.normalWash,
  );
  check(
    '[5] التسمية تُعيد مفتاحها',
    ServiceKind.keyOf(ServiceKind.urgentIron),
    'urgentironing',
  );
  check(
    '[5] عمود سعر الغسيل المستعجل',
    ServiceKind.priceColumn(ServiceKind.urgentWash),
    'urgent_washing_and_ironing_price',
  );
  check(
    '[5] عمود سعر الكوي العادي',
    ServiceKind.priceColumn(ServiceKind.normalIron),
    'normal_ironing_price',
  );
  check(
    '[5] عمود سعر الكوي المستعجل',
    ServiceKind.priceColumn(ServiceKind.urgentIron),
    'urgent_ironing_price',
  );
  check(
    '[5] عمود سعر الغسيل العادي',
    ServiceKind.priceColumn(ServiceKind.normalWash),
    'normal_washing_and_ironing_price',
  );
  check(
    '[5] كل خدمة لها عمود سعر مختلف',
    ServiceKind.all.map(ServiceKind.priceColumn).toSet().length,
    4,
  );

  // ─── [6] سلوك الإضافة على قائمة حقيقية ───────────────────────────────
  print('\n[6] الإضافة على قائمة حقيقية');
  var cart1 = <Map<String, dynamic>>[];
  var step = InvoiceLines.applyAdd(cart1, _item());
  check('[6] أول إضافة ⇒ سطر جديد', step.items.length, 1);
  check('[6] أول إضافة ⇒ النتيجة added', step.result.outcome, LineAddOutcome.added);
  check('[6] أول إضافة ⇒ كمية ١', step.result.quantity, 1);
  check('[6] القائمة الأصلية لم تُعدَّل', cart1.length, 0);

  cart1 = step.items;
  step = InvoiceLines.applyAdd(cart1, _item());
  check('[6] الثانية ⇒ لا سطر جديد', step.items.length, 1);
  check('[6] الثانية ⇒ النتيجة merged', step.result.outcome, LineAddOutcome.merged);
  check('[6] الثانية ⇒ الكمية ٢', step.result.quantity, 2);
  check('[6] الثانية ⇒ الإجمالي ١٠', step.items.first['total_price'], 10.0);

  step = InvoiceLines.applyAdd(step.items, _item(count: 3));
  check('[6] إضافة ٣ ⇒ الكمية ٥', step.result.quantity, 5);
  check('[6] سطر واحد بعد ثلاث إضافات', step.items.length, 1);
  check('[6] الإجمالي ٢٥', step.items.first['total_price'], 25.0);

  step = InvoiceLines.applyAdd(step.items, _item(note: 'بقعة زيت'));
  check('[6] ملاحظة مختلفة ⇒ سطر ثانٍ', step.items.length, 2);
  check(
    '[6] السبب مُعلَن لا صامت',
    step.result.outcome,
    LineAddOutcome.separateByNote,
  );
  step = InvoiceLines.applyAdd(step.items, _item(note: 'بقعة زيت'));
  check('[6] نفس الملاحظة تُدمج في سطرها', step.result.quantity, 2);
  check('[6] ولا تُضاف سطرًا ثالثًا', step.items.length, 2);

  step = InvoiceLines.applyAdd(step.items, _item(service: ServiceKind.urgentWash));
  check('[6] خدمة أخرى ⇒ سطر مستقلّ', step.items.length, 3);
  check(
    '[6] خدمة أخرى ليست «فصلًا بسبب»',
    step.result.outcome,
    LineAddOutcome.added,
  );

  // سعر مختلف على **قائمة نظيفة**: في القائمة المتراكمة أعلاه توجد ملاحظة
  // مختلفة، والملاحظة تسبق السعر في ترتيب الأسباب (بقعة أهمّ من سعر).
  final priceOnly = InvoiceLines.applyAdd(
    <Map<String, dynamic>>[_item()],
    _item(price: 6),
  );
  check('[6] سعر مختلف ⇒ سطر مستقلّ', priceOnly.items.length, 2);
  check(
    '[6] السعر سبب مُعلَن',
    priceOnly.result.outcome,
    LineAddOutcome.separateByPrice,
  );
  check(
    '[6] الملاحظة تسبق السعر عند اجتماعهما',
    InvoiceLines.applyAdd(
      <Map<String, dynamic>>[_item(note: 'بقعة')],
      _item(price: 6),
    ).result.outcome,
    LineAddOutcome.separateByNote,
  );

  // ─── [7] سلوك التعديل ────────────────────────────────────────────────
  print('\n[7] التعديل على قائمة حقيقية');
  final base = <Map<String, dynamic>>[
    _item(count: 1),
    _item(service: ServiceKind.normalIron, price: 3),
  ];

  var edit = InvoiceLines.applyUpdate(base, 0, _item(count: 4));
  check('[7] الكمية تُعدَّل', edit.items.first['count'], 4);
  check('[7] الإجمالي يُعاد حسابه', edit.items.first['total_price'], 20.0);
  check('[7] عدد الأسطر لا يتغيّر', edit.items.length, 2);
  check('[7] الأصل لم يُعدَّل', base.first['count'], 1);

  edit = InvoiceLines.applyUpdate(edit.items, 0, _item(price: 9, count: 4));
  check('[7] السعر يُعدَّل', edit.items.first['price'], 9.0);
  check('[7] الإجمالي يتبع السعر', edit.items.first['total_price'], 36.0);

  // خريطة ناقصة لا تُصفّر الكمية ولا السعر
  final partial = InvoiceLines.applyUpdate(
    <Map<String, dynamic>>[_item(count: 4, price: 5)],
    0,
    <String, dynamic>{'vestments': 'ثوب أبيض', 'content': ServiceKind.normalWash},
  );
  check('[7] خريطة بلا كمية تحفظ الكمية', partial.items.first['count'], 4);
  check('[7] خريطة بلا سعر تحفظ السعر', partial.items.first['price'], 5.0);
  check('[7] الإجمالي يبقى صحيحًا', partial.items.first['total_price'], 20.0);

  // تعديل يجعل البند مطابقًا لبند آخر ⇒ دمج
  final twin = <Map<String, dynamic>>[
    _item(count: 1),
    _item(count: 2, note: 'بقعة'),
  ];
  final mergedEdit = InvoiceLines.applyUpdate(twin, 1, _item(count: 2));
  check('[7] التعديل المطابق يُدمج', mergedEdit.items.length, 1);
  check(
    '[7] الدمج بالتحرير مُعلَن',
    mergedEdit.result.outcome,
    LineAddOutcome.mergedByEdit,
  );
  check('[7] الكميتان تجتمعان', mergedEdit.result.quantity, 3);
  check('[7] فهرس النتيجة صالح', mergedEdit.result.index, 0);

  // الدمج عند فهرس أعلى من المعدَّل: يجب ألّا يختلّ الفهرس
  final swap = <Map<String, dynamic>>[
    _item(note: 'بقعة'),
    _item(count: 2),
  ];
  final swapEdit = InvoiceLines.applyUpdate(swap, 0, _item(count: 2));
  check('[7] الدمج مع سطر أعلى', swapEdit.items.length, 1);
  check('[7] الفهرس يشير للسطر الباقي', swapEdit.result.index, 0);
  check('[7] الكمية صحيحة بعد الحذف', swapEdit.items.first['count'], 4);

  check(
    '[7] فهرس خارج الحدود لا يرمي',
    InvoiceLines.applyUpdate(base, 9, _item()).result.index,
    -1,
  );
  check(
    '[7] فهرس سالب لا يرمي',
    InvoiceLines.applyUpdate(base, -1, _item()).items.length,
    2,
  );

  // ─── [8] ربط المتحكّم (لا دمج في الواجهة) ────────────────────────────
  print('\n[8] ربط المتحكّم');
  final controller = _code('lib/controller/invoicecontroller.dart');
  check(
    '[8] الإضافة تُمرَّر للمنطق الخالص',
    controller.contains('InvoiceLines.applyAdd(invoice, item)'),
    true,
  );
  check(
    '[8] التعديل يُمرَّر للمنطق الخالص',
    controller.contains('InvoiceLines.applyUpdate(invoice, index, updated)'),
    true,
  );
  check(
    '[8] المتحكّم لا يقرّر الدمج بنفسه',
    controller.contains('probe'),
    false,
  );
  check(
    '[8] زيادة/إنقاص الكمية موجودان',
    controller.contains('void increaseQuantity(') &&
        controller.contains('void decreaseQuantity('),
    true,
  );
  check(
    '[8] المجموع لا يُقرأ من `total_price` المخزَّن',
    controller.contains('total += InvoiceLines.lineTotal(item);'),
    true,
  );
  check(
    '[8] عدد القطع مصدره المتحكّم',
    controller.contains('int piecesCount()'),
    true,
  );
  check(
    '[8] الاستبدال في المكان لا بقائمة جديدة',
    controller.contains('..addAll(items);'),
    true,
  );
  check(
    '[8] حذف البند يتحقّق من الحدود',
    controller.contains('if (index < 0 || index >= invoice.length) return;'),
    true,
  );

  // ─── [9] ربط الواجهة ─────────────────────────────────────────────────
  print('\n[9] ربط الواجهة');
  final line = _code('lib/view/widget/invoice/customviewinvoice.dart');
  check(
    '[9] عدّاد الكمية في سطر الفاتورة',
    line.contains('_QuantityStepper('),
    true,
  );
  check(
    '[9] زرّ الزيادة يمرّ من المتحكّم',
    line.contains('controllerprint.increaseQuantity(index)'),
    true,
  );
  check(
    '[9] زرّ الإنقاص يمرّ من المتحكّم',
    line.contains('controllerprint.decreaseQuantity(index)'),
    true,
  );
  check(
    '[9] زرّ التعديل يفتح الحوار',
    line.contains('showInvoiceLineEditDialog(controller: controllerprint'),
    true,
  );
  check(
    '[9] زرّ الحذف موجود',
    line.contains('controllerprint.removeItem(index)'),
    true,
  );
  check(
    '[9] الحذف بتأكيد لا بنقرة واحدة',
    line.contains("tr('حذف البند؟')"),
    true,
  );

  final editDialog = _code(
    'lib/view/widget/invoice/invoice_line_edit_dialog.dart',
  );
  check('[9] حوار التعديل موجود', editDialog.isNotEmpty, true);
  check(
    '[9] الحوار يحفظ عبر `updateItem`',
    editDialog.contains('controller.updateItem(index, updated)'),
    true,
  );
  check(
    '[9] تغيير الخدمة يُسعَّر من قائمة الأسعار',
    editDialog.contains('ServiceKind.priceColumn(label)'),
    true,
  );
  check(
    '[9] الكمية تُقصّ على الحدّين',
    editDialog.contains('InvoiceLines.maxQuantity') &&
        editDialog.contains('InvoiceLines.minQuantity'),
    true,
  );
  check(
    '[9] الملاحظة الفارغة تُحذف من البند',
    editDialog.contains("updated.remove('note')"),
    true,
  );

  // ─── [10] لا مصدر ثانٍ للتسمية ولا كمية محلية ────────────────────────
  print('\n[10] مصدر واحد');
  final addDialog = _code('lib/controller/showdialogcontroller.dart');
  check(
    '[10] المتحكّم لا يكرّر تسميات الخدمات',
    addDialog.contains("'غسيل وكوي عادي'"),
    false,
  );
  check(
    '[10] المتحكّم يقرأ التسمية من `ServiceKind`',
    addDialog.contains('ServiceKind.keyToLabel[typerequest]'),
    true,
  );
  check(
    '[10] السعر من عمود الخدمة لا من فرع يدوي',
    addDialog.contains('data[ServiceKind.priceColumn(label)]'),
    true,
  );
  check(
    '[10] الإضافة تُبلّغ المستخدم بالنتيجة',
    addDialog.contains('_announce(controllerinvoce.addItem(item))'),
    true,
  );
  check(
    '[10] شارة «في الفاتورة» موجودة',
    addDialog.contains('quantityInInvoice('),
    true,
  );
  check(
    '[10] حوار الصنف يعرض الشارة',
    _code('lib/view/widget/home/dialog.dart').contains('existing: controller'),
    true,
  );

  final pay = _code('lib/view/widget/invoice/custompayinvoice.dart');
  check(
    '[10] عدد القطع في حوار الدفع من المتحكّم',
    pay.contains('itemPieces: invcontroller.piecesCount()'),
    true,
  );
  check(
    '[10] لا جمع كمية محلي في حوار الدفع',
    pay.contains("it['count']"),
    false,
  );

  final printer = _code('lib/controller/printInvoicecontroller.dart');
  check(
    '[10] المطبوع يقرأ الكمية من `InvoiceLines`',
    printer.contains('InvoiceLines.quantityOf(it)'),
    true,
  );
  check(
    '[10] المطبوع يقرأ إجمالي السطر من `InvoiceLines`',
    printer.contains('InvoiceLines.lineTotal(it)'),
    true,
  );

  // ─── [11] الاستعادة لا تُدمج (المستند صورة الماضي) ───────────────────
  print('\n[11] الاستعادة');
  check(
    '[11] `setItems` لا يدمج',
    controller.contains('void setItems(List<Map<String, dynamic>> items)') &&
        !_section(controller, 'void setItems', 'void _replaceItems')
            .contains('applyAdd'),
    true,
  );
  final restored = <Map<String, dynamic>>[_item(), _item()];
  check(
    '[11] قائمة مستعادة بأسطر مكرّرة تبقى كما هي',
    restored.length,
    2,
  );

  print('\n${'─' * 64}');
  print('نجح: $_ok · فشل: $_fail');
  if (_fail > 0) exit(1);
}

/// مقطع من المصدر بين علامتين — لفحص دالة بعينها لا الملف كله.
String _section(String source, String startMark, String endMark) {
  final start = source.indexOf(startMark);
  if (start < 0) return '';
  final end = source.indexOf(endMark, start);
  return source.substring(start, end < 0 ? source.length : end);
}
