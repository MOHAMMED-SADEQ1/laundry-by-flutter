// حرس **رمز QR لموقع النشاط** — يثبت أن `business_location` صار له مستهلك.
//
// العيب الذي يمنعه: حقل «رابط الموقع» كان يُحفظ من الإعدادات ومن الإعداد
// الأولي ثم **لا يُقرأ في أي مستند** — إعداد فعّال بلا أثر. والحلّ ليس
// «رسم رمز» فقط بل سلسلة كاملة: رابط مُطبَّع ⇒ حقل في القالب ⇒ رمز في
// الحمولة ⇒ رسم أسفل الورقة. كسر أي حلقة يعني رمزًا لا يظهر أو رابطًا لا يفتح.
//
// التشغيل: dart run tool/verify_map_qr.dart
import 'dart:io';

import 'package:laundry/services/pdf/doc_template.dart';
import 'package:laundry/services/pdf/map_qr.dart';
import 'package:laundry/services/pdf/print_visual_size.dart';

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

// يُطبَّع نهاية السطر: ملفّات المشروع مختلطة (LF وCRLF)، وفحصٌ يعتمد
// على `\n` وحده يفشل أو ينجح بحسب محرّر فتح الملف — وهو حرس كاذب.
String _read(String path) =>
    File(path).readAsStringSync().replaceAll('\r\n', '\n');

String _code(String path) =>
    _read(path).replaceAll(RegExp(r'//[^\n]*'), '');

void main() {
  print('═' * 64);
  print('حرس رمز QR لموقع النشاط');
  print('═' * 64);

  // ─── [1] تطبيع الرابط ───────────────────────────────────────────────
  print('\n[1] تطبيع الرابط');
  check(
    '[1] رابط كامل يبقى كما هو',
    MapQr.resolve('https://maps.app.goo.gl/AbCdEf'),
    'https://maps.app.goo.gl/AbCdEf',
  );
  check(
    '[1] بلا بروتوكول ⇒ https',
    MapQr.resolve('google.com/maps/place/Shop'),
    'https://google.com/maps/place/Shop',
  );
  check(
    '[1] بروتوكول نسبي // ⇒ https:',
    MapQr.resolve('//maps.google.com/?q=24.7,46.6'),
    'https://maps.google.com/?q=24.7,46.6',
  );
  check(
    '[1] إحداثيات خام ⇒ صفحة خرائط',
    MapQr.resolve('24.7136,46.6753'),
    '${MapQr.coordsBase}24.7136,46.6753',
  );
  check(
    '[1] إحداثيات بمسافة بعد الفاصلة',
    MapQr.resolve(' 24.7136 , 46.6753 '),
    '${MapQr.coordsBase}24.7136,46.6753',
  );
  check(
    '[1] المسافات داخل الرابط تُحذف',
    MapQr.resolve('https://www.google.com/maps?q=24.7, 46.6'),
    'https://www.google.com/maps?q=24.7,46.6',
  );
  check('[1] الفراغ ⇒ لا رمز', MapQr.resolve(''), '');
  check('[1] الفراغات فقط ⇒ لا رمز', MapQr.resolve('   '), '');
  check('[1] null لا يرمي', MapQr.resolve(null), '');
  check(
    '[1] بروتوكول غير http يُرفض',
    MapQr.resolve('javascript:alert(1)'),
    '',
  );
  check('[1] tel: يُرفض', MapQr.resolve('tel:+966500000000'), '');
  check('[1] مضيف بلا نقطة يُرفض', MapQr.resolve('https://نشاطي'), '');
  check(
    '[1] الطويل جدًا يُرفض (رمز لا يُقرأ)',
    MapQr.resolve('https://maps.app.goo.gl/${'a' * 600}'),
    '',
  );
  check('[1] الطول المقبول تمامًا يمرّ', MapQr.isValid('https://maps.app.goo.gl/abc'), true);

  // ─── [2] تمييز روابط الخرائط ───────────────────────────────────────
  print('\n[2] هل يشبه رابط خرائط؟');
  check('[2] maps.app.goo.gl', MapQr.looksLikeMaps('https://maps.app.goo.gl/x'), true);
  check('[2] google.com/maps', MapQr.looksLikeMaps('google.com/maps/place/x'), true);
  check('[2] goo.gl', MapQr.looksLikeMaps('https://goo.gl/maps/x'), true);
  // الإحداثيات الخام تُبنى لها صفحة خرائط جوجل، فهي «رابط خرائط» بعد التطبيع.
  check('[2] إحداثيات', MapQr.looksLikeMaps('24.7,46.6'), true);
  check('[2] موقع آخر', MapQr.looksLikeMaps('https://example.com/shop'), false);
  check('[2] فراغ', MapQr.looksLikeMaps(''), false);

  // ─── [3] مقاس الرمز ────────────────────────────────────────────────
  //
  // المقاس صار إعدادًا (`map_qr_size`) لا ثابتًا في الكود، ويُقصّ على الورق.
  print('\n[3] المقاس على الورق');
  final a4 = PrintVisualSize.qr(sizeMm: 30, maxWidth: 538, maxHeight: 793);
  check('[3] A4 ⇒ 30 مم ≈ 85 نقطة', (a4.width - 85.04).abs() < 0.01, true);
  check('[3] يبقى مربّعًا', a4.isSquare, true);
  final thermal = PrintVisualSize.qr(
    sizeMm: 70,
    maxWidth: 137,
    maxHeight: 793,
  );
  check('[3] حراري 58 مم ⇒ يُقصّ على العرض', thermal.width, 137.0);
  check('[3] ويُعلَن التقييد', thermal.clamped, true);
  check('[3] لا يخرج عن الورق', thermal.width <= 137, true);
  check(
    '[3] عرض شاذّ لا يرمي',
    PrintVisualSize.qr(sizeMm: 30, maxWidth: 0, maxHeight: 0).width,
    PrintVisualSize.minPoints,
  );

  // ─── [4] الحقل في السجل ────────────────────────────────────────────
  print('\n[4] الحقل في القالب');
  check('[4] المفتاح', DocCatalog.kMapQr, 'map_qr');
  final invoiceField = DocCatalog.fieldOf(DocKind.invoice, DocCatalog.kMapQr);
  check('[4] معرَّف في الفاتورة', invoiceField != null, true);
  check('[4] قسمه التذييل', invoiceField?.section, DocSections.footer);
  check('[4] له نصّ (تسمية تحت الرمز)', invoiceField?.hasText, true);
  check('[4] مُفعَّل افتراضيًا', invoiceField?.defaultEnabled, true);
  final statementField = DocCatalog.fieldOf(DocKind.statement, DocCatalog.kMapQr);
  check('[4] معرَّف في كشف الحساب', statementField != null, true);
  check('[4] قسمه التذييل في الكشف', statementField?.section, DocSections.footer);
  // مستند داخلي لا يخرج من المحل ⇒ لا رمز خريطة فيه.
  check(
    '[4] ليس في ملخّص الوردية',
    DocCatalog.fieldOf(DocKind.shift, DocCatalog.kMapQr),
    null,
  );
  check(
    '[4] ليس في ورقة المغسلة',
    DocCatalog.fieldOf(DocKind.laundrySlip, DocCatalog.kMapQr),
    null,
  );
  check(
    '[4] لا تصادم مفاتيح داخل المستند',
    DocCatalog.fieldsOf(DocKind.invoice).map((f) => f.key).toSet().length,
    DocCatalog.fieldsOf(DocKind.invoice).length,
  );

  // ─── [5] الرابط يصل إلى الحمولة ────────────────────────────────────
  //
  // كسر هذه الحلقة هو أخطر عيب ممكن: الرمز يعمل، والقالب يعمل، والرابط
  // محفوظ — ولا يظهر شيء لأن المفتاح لا يُمرَّر. لذلك يُفحص كل مولّد.
  print('\n[5] الرابط في الحمولات');
  final payloads = <String, String>{
    'البيع': 'lib/controller/printInvoicecontroller.dart',
    'إعادة الطباعة': 'lib/controller/previousinvoicecontroller.dart',
    'المشاركة': 'lib/core/services/invoice_share_service.dart',
    'كشف الحساب': 'lib/controller/customer/customer_statement_controller.dart',
  };
  for (final e in payloads.entries) {
    check(
      '[5] ${e.key} يمرّر bizMapUrl',
      _code(e.value).contains("'bizMapUrl'"),
      true,
    );
  }
  check(
    '[5] المصدر هو خدمة معلومات النشاط لا نصّ ثابت',
    _code(
      'lib/controller/printInvoicecontroller.dart',
    ).contains('BusinessInfoService.instance.location'),
    true,
  );

  // ─── [6] الرسم أسفل الورقة ─────────────────────────────────────────
  print('\n[6] الرسم في المولّد');
  final pdf = _code('lib/core/services/preparePDF.dart');
  check('[6] يقرأ المفتاح', pdf.contains("data['bizMapUrl']"), true);
  check('[6] يطبّع الرابط', pdf.contains('MapQr.resolve('), true);
  check('[6] يُرسم كـSVG', pdf.contains('pw.SvgImage('), true);
  check(
    '[6] مقاسه من الإعداد ثم مقصوص على الورق',
    pdf.contains('PrintVisualSize.qr(') &&
        pdf.contains("data['mapQrSizeMm']"),
    true,
  );
  check(
    '[6] محروس بتفعيل الحقل',
    pdf.contains('doc.isOn(DocCatalog.kMapQr)'),
    true,
  );
  check(
    '[6] الترميز لا يرمي إن فشل',
    pdf.contains('map QR error'),
    true,
  );
  check(
    '[6] التسمية تحت الرمز',
    pdf.contains('DocCatalog.kMapQr,\n              align: pw.TextAlign.center'),
    true,
  );
  // موضعه: بعد التذييل لا قبله.
  final footerIdx = pdf.indexOf('tx(footerText, DocCatalog.kFooter');
  final qrIdx = pdf.indexOf('svg: mapQrSvg');
  check('[6] في الفاتورة: بعد التذييل', footerIdx > 0 && qrIdx > footerIdx, true);
  final stFooterIdx = pdf.indexOf('doc.text(DocCatalog.kFooter),');
  final stQrIdx = pdf.indexOf('svg: mapQrSvg', qrIdx + 1);
  check(
    '[6] في الكشف: بعد التذييل',
    stFooterIdx > 0 && stQrIdx > stFooterIdx,
    true,
  );

  // ─── [7] لا رمز مكسور ──────────────────────────────────────────────
  print('\n[7] حدود الأمان');
  final src = _read('lib/services/pdf/map_qr.dart');
  check('[7] لا يستورد Flutter (منطق خالص)', src.contains("import 'package:flutter"), false);
  check('[7] لا يقرأ قاعدة ولا حالة عامة', src.contains('SqlDB'), false);
  check(
    '[7] الرابط الفارغ يعني لا رمز لا رمزًا فارغًا',
    MapQr.resolve('') == '' && MapQr.isValid('') == false,
    true,
  );

  // ─── [8] إصلاح رمز المشاركة بلا نطاق ───────────────────────────────
  //
  // الحالة الواقعية (2026-10-30): حُفظ `https://ujfx8uiyhjfgksp8iuyrhjfsb`
  // — بروتوكول + رمز بلا نطاق — فلم يُطبع رمز، ولم يقل النظام شيئًا.
  // الإصلاح **اقتراح بزرّ** لا تطبيق تلقائي: تخمين رابط يفتح صفحة خطأ أسوأ
  // من عدم الطباعة.
  print('\n[8] إصلاح الرمز بلا نطاق');
  check(
    '[8] الحالة الواقعية تُقترح لها صيغة صحيحة',
    MapQr.repair('https://ujfx8uiyhjfgksp8iuyrhjfsb'),
    'https://maps.app.goo.gl/ujfx8uiyhjfgksp8iuyrhjfsb',
  );
  check(
    '[8] رمز مجرّد بلا بروتوكول',
    MapQr.repair('ujfx8uiyhjfgksp8iuyrhjfsb'),
    'https://maps.app.goo.gl/ujfx8uiyhjfgksp8iuyrhjfsb',
  );
  check(
    '[8] بروتوكول نسبي //',
    MapQr.repair('//AbCdEf123'),
    'https://maps.app.goo.gl/AbCdEf123',
  );
  check('[8] رابط صالح لا يُقترح تعديله', MapQr.repair('https://maps.app.goo.gl/x'), '');
  check('[8] الإحداثيات صالحة أصلًا', MapQr.repair('24.7,46.6'), '');
  check('[8] نطاق بلا نقطة مرفوض ولا يُخمَّن', MapQr.repair('https://a/b'), '');
  check('[8] النصّ العربي لا يُخمَّن', MapQr.repair('الرياض'), '');
  check('[8] القصير جدًا لا يُخمَّن', MapQr.repair('abc'), '');
  check('[8] الطويل جدًا لا يُخمَّن', MapQr.repair('a' * 200), '');
  check(
    '[8] الاقتراح نفسه صالح للترميز',
    MapQr.isValid(MapQr.repair('https://ujfx8uiyhjfgksp8iuyrhjfsb')),
    true,
  );

  // ─── [9] الحالة ظاهرة للمستخدم ─────────────────────────────────────
  //
  // المنطق الصحيح بلا إعلان = عيب صامت. هذا القسم يمنع أن يعود الرابط
  // الفاسد صامتًا في أي شاشة إدخال أو في المعاينة.
  print('\n[9] إعلان الحالة في الواجهة');
  final status = _read('lib/view/widget/common/map_link_status.dart');
  check('[9] ودجة الحالة موجودة', status.contains('class MapLinkStatus'), true);
  check(
    '[9] حكمها من النوع الخالص لا من نسخة ثانية',
    status.contains('MapQr.resolve(') && status.contains('MapQr.repair('),
    true,
  );
  check(
    '[9] تُحدَّث مع كل حرف',
    status.contains('ValueListenableBuilder<TextEditingValue>'),
    true,
  );
  final settingsUi = _read('lib/view/screen/settings/settings_sections.dart');
  check(
    '[9] في بطاقة معلومات النشاط',
    settingsUi.contains('MapLinkStatus(controller: locationCtrl)'),
    true,
  );
  check(
    '[9] وفي معاينة الفاتورة',
    settingsUi.contains('MapLinkStatusText('),
    true,
  );
  final onboarding = _read('lib/view/screen/onboarding_screen.dart');
  check(
    '[9] وفي الإعداد الأولي — حيث وقع العيب',
    onboarding.contains('MapLinkStatus(controller: _locationCtrl)'),
    true,
  );

  print('\n' + '═' * 64);
  print(_fail == 0 ? '✓ كل الفحوص ناجحة ($_ok)' : '✗ فشل $_fail من ${_ok + _fail}');
  print('═' * 64);
  if (_fail != 0) exitCode = 1;
}
