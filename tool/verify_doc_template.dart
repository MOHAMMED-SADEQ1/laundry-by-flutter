/// حرس **قوالب المستندات** — يمنع انحراف التصميم عن السجلّ أو عودة النصوص
/// أو الأحجام المكتوبة في الكود.
///
///     dart run tool/verify_doc_template.dart
///
/// ## ما يحميه
/// الميزة كلها قائمة على قاعدة واحدة: **`DocCatalog` هو المصدر الوحيد** لكل
/// حقل (معرّفه · اسمه · قسمه · نصّه الافتراضي · **نمطه**). فإن عاد نصّ عربي
/// مكتوب داخل مولّد الـPDF، أو عاد حجم خطّ ثابت في الكود، أو أُضيف حقل بقسم
/// غير معروف، أو صار للقالب مرادف قديم غير مسجَّل في `SettingOptions` —
/// تنكسر الميزة صامتةً: الشاشة تعرض حقلًا لا يقرأه المولّد، أو مفتاحًا في
/// الإعدادات لا يزامن شيئًا، أو رقمًا في الشاشة لا أثر له في الورق.
///
/// ## لماذا حراس نصّية؟
/// `dart analyze` يتحقّق من الأنواع فقط. أما «هل ما زال هذا النصّ مكتوبًا في
/// الكود؟» و«هل كل حقل مذكور في المولّد؟» فلا يعرفها. وهذه الحراس تفحص
/// الملفات نفسها. (تُختبر بعيب مزروع قبل الاعتماد عليها — انظر آخر الملف.)
library;

import 'dart:io';

import 'package:laundry/services/pdf/arabic_text.dart';
import 'package:laundry/services/pdf/doc_template.dart';
import 'package:laundry/services/settings/setting_option.dart';

int _pass = 0;
int _fail = 0;
final List<String> _failures = <String>[];

void check(String label, bool ok, [String detail = '']) {
  if (ok) {
    _pass++;
  } else {
    _fail++;
    _failures.add('$label${detail.isEmpty ? '' : ' → $detail'}');
  }
}

String read(String path) => File(path).readAsStringSync();

/// يقرأ الملف **بلا تعليقات**.
///
/// لماذا؟ لأن الحراس النصّية تبحث عن «نصّ مكتوب في الكود» — والتعليقات تشرح
/// العيب القديم فتحتوي النصّ نفسه. لو فحصنا التعليقات لأبلغ الحرس عن نفسه
/// (سلبيّة كاذبة تُفقد الثقة فيه).
String readCode(String path) {
  final src = read(path);
  final noBlock = src.replaceAll(RegExp(r'/\*[\s\S]*?\*/'), '');
  return noBlock
      .split('\n')
      .where((l) => !l.trimLeft().startsWith('//'))
      .join('\n');
}

/// نصوص عربية **مسموح** بقاؤها في المولّد.
///
/// كلها **عناوين أعمدة جداول** (بنية بيانات لا نصّ مستند) ولاحقتا «له/عليه»
/// في صافي الموقف، واسم احتياطي عند غياب اسم النشاط. أي نصّ آخر في المولّد
/// يفشل الحرس — وهذا هو الفرق بين «حرس يفحص قائمة محفوظات» و«حرس يمنع
/// التكرار من أصله».
const Set<String> _allowedLiterals = <String>{
  // ترويسات أعمدة جداول كشف الحساب.
  'التاريخ والوقت',
  'الصنف',
  'العدد',
  'القيمة (ريال)',
  'رقم',
  'التاريخ',
  'الإجمالي',
  'المدفوع',
  'المتبقي',
  'المبلغ',
  'الطريقة',
  'ملاحظة',
  'الاشتراك',
  'القطع',
  'الفاتورة',
  // لاحقة صافي الموقف.
  '(له)',
  '(عليه)',
  // اسم احتياطي حين لا يُسجَّل اسم النشاط.
  'نظام المغاسل',
};

/// كل النصوص العربية المكتوبة حرفيًا في ملف.
Set<String> _arabicLiterals(String code) {
  final re = RegExp(r"'([^'\\]*(?:\\.[^'\\]*)*)'");
  return re
      .allMatches(code)
      .map((m) => m.group(1)!)
      .where((s) => RegExp(r'[\u0600-\u06FF]').hasMatch(s))
      .toSet();
}

void main() {
  print('═' * 62);
  print('حرس قوالب المستندات');
  print('═' * 62);

  _checkPurity();
  _checkCatalogIntegrity();
  _checkTemplateModel();
  _checkStyleModel();
  _checkTolerance();
  _checkLegacyLinks();
  _checkGenerators();
  _checkCallSites();
  _checkEditorUi();
  _checkArabicSanitizer();

  print('─' * 62);
  if (_fail > 0) {
    for (final f in _failures) {
      print('  ✗ $f');
    }
  }
  print('نجح: $_pass · فشل: $_fail');
  print(_fail == 0 ? '✅ كل الفحوص نجحت' : '❌ فشل');
  exit(_fail == 0 ? 0 : 1);
}

// ───────────────────────────────────────────────────────────────────────
// [1] المنطق خالص: بلا Flutter ولا قاعدة
// ───────────────────────────────────────────────────────────────────────
void _checkPurity() {
  final src = read('lib/services/pdf/doc_template.dart');
  final imports =
      RegExp(r"^import\s+'([^']+)'", multiLine: true)
          .allMatches(src)
          .map((m) => m.group(1)!)
          .toList();
  // مسموح فقط باستيراد منطق خالص آخر (لا Flutter ولا قاعدة).
  const allowed = <String>{
    'package:laundry/services/pdf/arabic_text.dart',
    // `l10n` منطق خالص أيضًا (لا Flutter ولا قاعدة): يقرأ اللغة الحالية
    // فقط، ولهذا يجوز استيراده هنا.
    'package:laundry/services/i18n/l10n.dart',
  };
  final bad = imports.where((i) => !allowed.contains(i)).toList();
  check('[1] doc_template.dart يستورد منطقًا خالصًا فقط', bad.isEmpty, '$bad');
  check(
    '[1] بلا مرجع Flutter/قاعدة',
    !src.contains('package:flutter') && !src.contains('sqldb.dart'),
  );
}

// ───────────────────────────────────────────────────────────────────────
// [2] سلامة السجلّ: مفاتيح فريدة · أقسام معروفة · حقول مكتملة
// ───────────────────────────────────────────────────────────────────────
void _checkCatalogIntegrity() {
  for (final kind in DocKind.values) {
    final fields = DocCatalog.fieldsOf(kind);
    check('[2] ${kind.name}: السجلّ غير فارغ', fields.isNotEmpty);

    final keys = fields.map((f) => f.key).toList();
    final dup = <String>{};
    final seen = <String>{};
    for (final k in keys) {
      if (!seen.add(k)) dup.add(k);
    }
    check('[2] ${kind.name}: لا مفاتيح مكرّرة', dup.isEmpty, '$dup');

    final badSection =
        fields
            .where((f) => !DocSections.ordered.contains(f.section))
            .map((f) => '${f.key}:${f.section}')
            .toList();
    check('[2] ${kind.name}: كل قسم معروف', badSection.isEmpty, '$badSection');

    final badLabel = fields.where((f) => f.label.trim().isEmpty).length;
    check('[2] ${kind.name}: كل حقل له اسم', badLabel == 0, '$badLabel');

    // الحقول التي تُطبع كـ«بادئة: قيمة» يجب أن تعرف نصّها الافتراضي،
    // وإلا خرجت «: 1024» بلا عنوان.
    const needDefault = <String>[
      DocCatalog.kReceiptNo,
      DocCatalog.kDatetime,
      DocCatalog.kTaxNumber,
      DocCatalog.kCrNumber,
      DocCatalog.kCashier,
      DocCatalog.kCustomerName,
      DocCatalog.kItemNote,
      DocCatalog.kShiftId,
      DocCatalog.kStartTime,
      DocCatalog.kEndTime,
      DocCatalog.kInvoiceCount,
      DocCatalog.kTotalCash,
      DocCatalog.kTotalNetwork,
    ];
    final missing =
        fields
            .where(
              (f) =>
                  needDefault.contains(f.key) &&
                  (!f.hasText || f.defaultText.trim().isEmpty),
            )
            .map((f) => f.key)
            .toList();
    check(
      '[2] ${kind.name}: حقول «بادئة: قيمة» لها افتراضي',
      missing.isEmpty,
      '$missing',
    );

    // أي حقل بلا نمط معقول؟ الحجم يجب أن يقع داخل الحدود.
    final badSize =
        fields
            .where(
              (f) =>
                  f.style.size < DocStyle.minSize ||
                  f.style.size > DocStyle.maxSize,
            )
            .map((f) => '${f.key}:${f.style.size}')
            .toList();
    check('[2] ${kind.name}: أحجام افتراضية داخل الحدود', badSize.isEmpty, '$badSize');

    final badWeight =
        fields
            .where((f) => !DocStyle.weights.contains(f.style.weight))
            .map((f) => f.key)
            .toList();
    check('[2] ${kind.name}: أوزان افتراضية معروفة', badWeight.isEmpty, '$badWeight');
  }

  // كل حقل في السجلّ مذكور في مولّده (وإلا صار مفتاحًا لا أثر له).
  for (final kind in DocKind.values) {
    final generator =
        kind == DocKind.laundrySlip
            ? readCode('lib/services/pdf/laundry_slip_pdf.dart')
            : readCode('lib/core/services/preparePDF.dart');
    final missing =
        DocCatalog.fieldsOf(kind)
            .where((f) => !generator.contains('DocCatalog.${_constName(f.key)}'))
            .map((f) => f.key)
            .toList();
    check('[2] ${kind.name}: كل حقل يُقرأ في المولّد', missing.isEmpty, '$missing');
  }

  // كل الأنواع لها مفاتيح تخزين متمايزة ومسجَّلة في القاعدة.
  final keys = DocKind.values.map(DocCatalog.storageKey).toSet();
  check('[2] مفاتيح التخزين متمايزة', keys.length == DocKind.values.length);
  final svc = read('lib/services/pdf/doc_template_service.dart');
  check(
    '[2] الخدمة تقرأ مفتاح السجلّ لا نصًّا ثابتًا',
    svc.contains('DocCatalog.storageKey(kind)'),
  );
}

/// `receipt_no` ⇒ `kReceiptNo`
String _constName(String key) {
  final parts = key.split('_');
  final b = StringBuffer('k');
  for (final p in parts) {
    if (p.isEmpty) continue;
    b.write(p[0].toUpperCase() + p.substring(1));
  }
  return b.toString();
}

// ───────────────────────────────────────────────────────────────────────
// [3] نموذج القالب: الافتراضي · التعديل · الحفظ · الاستعادة
// ───────────────────────────────────────────────────────────────────────
void _checkTemplateModel() {
  for (final kind in DocKind.values) {
    final d = DocTemplate.defaults(kind);
    check('[3] ${kind.name}: الافتراضي غير معدَّل', !d.isModified);
    check('[3] ${kind.name}: isOn يقرأ الافتراضي', d.isOn(DocCatalog.kTitle));
    check('[3] ${kind.name}: isOn للغياب = مُفعَّل', d.isOn('مفتاح_غير_موجود'));

    // نختار حقلًا **مُفعَّلًا افتراضيًا** لا حقلًا بعينه: تغيير الافتراضيات
    // (كما فعلنا لشعار كشف الحساب) لا يجوز أن يُسقط الحرس.
    final onKey =
        DocCatalog.fieldsOf(kind).firstWhere((f) => f.defaultEnabled).key;
    final off = d.withField(onKey, enabled: false);
    check('[3] ${kind.name}: تعطيل حقل يعمل', !off.isOn(onKey));
    check('[3] ${kind.name}: التعطيل لا يمسّ الأصل', d.isOn(onKey));
    check('[3] ${kind.name}: التعطيل يُعلِّم التعديل', off.isModified);

    final txt = d.withField(DocCatalog.kTitle, text: 'نصّ مخصّص');
    check(
      '[3] ${kind.name}: نصّ مخصّص يُقرأ',
      txt.textOf(DocCatalog.kTitle) == 'نصّ مخصّص',
    );

    // الفراغ يعود للافتراضي (لا مستند بلا عنوان بسبب حقل تُرك فارغًا).
    final blank = d.withField(DocCatalog.kTitle, text: '   ');
    check(
      '[3] ${kind.name}: الفراغ ⇒ الافتراضي',
      blank.textOf(DocCatalog.kTitle) ==
          DocCatalog.fieldOf(kind, DocCatalog.kTitle)!.defaultText,
      blank.textOf(DocCatalog.kTitle),
    );

    final allOff = d.withAllEnabled(false);
    final anyOn = DocCatalog.fieldsOf(kind).any((f) => allOff.isOn(f.key));
    check('[3] ${kind.name}: إيقاف الكل يعطّل كل الحقول', !anyOn);

    final allOn = d.withAllEnabled(true);
    final anyOff = DocCatalog.fieldsOf(kind).any((f) => !allOn.isOn(f.key));
    check('[3] ${kind.name}: تفعيل الكل يفعّل كل الحقول', !anyOff);

    // رحلة JSON كاملة
    final round = DocTemplate.fromJson(
      kind,
      off.withField(DocCatalog.kTitle, text: 'عنوان').toJson(),
    );
    check('[3] ${kind.name}: JSON يحفظ التفعيل', !round.isOn(onKey));
    check(
      '[3] ${kind.name}: JSON يحفظ النصّ',
      round.textOf(DocCatalog.kTitle) == 'عنوان',
    );

    final tr = off.toTransport();
    check(
      '[3] ${kind.name}: النقل أنواع أوّلية',
      tr['docEnabled'] is Map<String, bool> &&
          tr['docTexts'] is Map<String, String> &&
          tr['docStyles'] is Map<String, dynamic>,
    );
    // 🚨 عقد الأسماء: `DocTemplateView.of` يقرأ هذه المفاتيح بالتحديد.
    check(
      '[3] ${kind.name}: مفاتيح النقل تطابق قارئ العزل',
      tr.containsKey('docEnabled') &&
          tr.containsKey('docTexts') &&
          tr.containsKey('docStyles'),
      '${tr.keys}',
    );
    final roundTrip = DocTemplateView.of(<String, dynamic>{...tr}, kind);
    check(
      '[3] ${kind.name}: toTransport ⇄ DocTemplateView.of',
      !roundTrip.isOn(onKey),
    );
    final view = DocTemplateView(
      kind,
      tr['docEnabled'] as Map,
      tr['docTexts'] as Map,
      tr['docStyles'] as Map,
    );
    check('[3] ${kind.name}: النقل يحفظ التعطيل', !view.isOn(onKey));
  }
}

// ───────────────────────────────────────────────────────────────────────
// [4] النمط: الحجم · الوزن · العرض
// ───────────────────────────────────────────────────────────────────────
void _checkStyleModel() {
  const plain = DocStyle(size: 20);

  // الوزن = تعريض صناعي متزايد.
  final off = const DocStyle(size: 20, weight: 400).boldOffset;
  final mid = const DocStyle(size: 20, weight: 600).boldOffset;
  final bold = const DocStyle(size: 20, weight: 700).boldOffset;
  final heavy = const DocStyle(size: 20, weight: 900).boldOffset;
  check('[4] الوزن العادي بلا إزاحة', off == 0);
  check('[4] الإزاحة تتزايد مع الوزن', mid < bold && bold < heavy);
  check('[4] الإزاحة تتناسب مع الحجم', const DocStyle(size: 40, weight: 700).boldOffset == bold * 2);

  // العرض = تضييق أفقي.
  check('[4] العرض 100% بلا تمديد', plain.widthScale == 1.0);
  check('[4] العرض 80% ⇒ 0.8', const DocStyle(width: 80).widthScale == 0.8);
  // 🚨 التوسيع ممنوع: `Transform` يرسم ولا يخطّط فيُخرج النصّ عن الورقة.
  check(
    '[4] التوسيع فوق 100% يُقيَّد',
    const DocStyle(width: 140).clamped().width == DocStyle.maxWidth &&
        DocStyle.maxWidth == 100,
    'maxWidth=${DocStyle.maxWidth}',
  );

  // التقيد: قيم شاذّة لا تُخرج ورقة بيضاء ولا ترمي.
  final wild = const DocStyle(size: 900, weight: 1234, width: 9000).clamped();
  check(
    '[4] الحجم الشاذّ يُقيَّد',
    wild.size == DocStyle.maxSize,
    '${wild.size}',
  );
  check(
    '[4] العرض الشاذّ يُقيَّد',
    wild.width == DocStyle.maxWidth,
    '${wild.width}',
  );
  check(
    '[4] الوزن الشاذّ يُقرَّب لمستوى معروف',
    DocStyle.weights.contains(wild.weight),
    '${wild.weight}',
  );
  check(
    '[4] الحجم الصغير يُقيَّد',
    const DocStyle(size: 1).clamped().size == DocStyle.minSize,
  );

  // 🚨 الحدّ الأعلى محسوب من عرض الورقة لا مُختار.
  //
  // أطول سطر لا يلتفّ (رقم الإيصال · السجل التجاري) يشغل `_widestPt` نقطة
  // عند 48 مع عرض 140% — قياس PyMuPDF على `build/probe/invoice_extreme.pdf`.
  // والعرض القابل للطباعة = A4 − 2×هامش 1 سم. الحدّ يجب أن يتّسع، ولا يزيد
  // عن 39 (فوقه يقتطع) — فلا تعود القيمة للصعود بصمت.
  const widestPt = 655.9; // عند 48pt · 140%
  const usablePt = 595.2755 - 2 * 28.3464; // A4 − هامش 1 سم
  final maxAllowed = 48 * usablePt / widestPt;
  check(
    '[4] الحدّ الأعلى يتّسع في الورقة',
    DocStyle.maxSize <= maxAllowed,
    'maxSize=${DocStyle.maxSize} > ${maxAllowed.toStringAsFixed(1)}',
  );
  check(
    '[4] الحدّ الأعلى لا يُفرِّط في التقييد',
    DocStyle.maxSize >= 30,
    '${DocStyle.maxSize}',
  );

  // النقل عبر العزل: مصفوفة أرقام.
  final tr = const DocStyle(size: 17.5, weight: 700, width: 85).toTransport();
  check('[4] النقل مصفوفة أرقام', tr.length == 3 && tr.every((e) => e is num));
  final back = DocStyle.fromTransport(tr, plain);
  check(
    '[4] النقل ⇄ fromTransport',
    back == const DocStyle(size: 17.5, weight: 700, width: 85),
    '$back',
  );
  // تالف: يعود للافتراضي لا يرمي.
  for (final bad in <Object?>[null, 'x', <num>[], <Object?>[1, 2], <Object?>['a', 'b', 'c']]) {
    check(
      '[4] نقل تالف (${bad.runtimeType}) ⇒ الافتراضي',
      DocStyle.fromTransport(bad, plain) == plain,
    );
  }

  // JSON.
  final j = const DocStyle(size: 15, weight: 600, width: 90).toJson();
  check('[4] JSON ⇄ fromJson', DocStyle.fromJson(j, plain) == const DocStyle(size: 15, weight: 600, width: 90));
  check('[4] JSON تالف ⇒ الافتراضي', DocStyle.fromJson(<String, dynamic>{'size': 'كبير'}, plain) == plain);

  // القالب يحفظ النمط ويعدّه تعديلًا، ويطبّقه على القسم.
  for (final kind in DocKind.values) {
    final d = DocTemplate.defaults(kind);
    final key =
        DocCatalog.fieldsOf(kind).firstWhere((f) => f.hasStyle).key;
    final changed = d.withField(key, style: d.styleOf(key).copyWith(size: 31));
    check('[4] ${kind.name}: تعديل النمط يُقرأ', changed.styleOf(key).size == 31);
    check('[4] ${kind.name}: تعديل النمط يُعلِّم التعديل', changed.isModified);

    final round = DocTemplate.fromJson(kind, changed.toJson());
    check(
      '[4] ${kind.name}: JSON يحفظ النمط',
      round.styleOf(key).size == 31,
      '${round.styleOf(key)}',
    );

    final field = DocCatalog.fieldOf(kind, key)!;
    final section = field.section;
    final styled = d.withSectionStyle(
      section,
      const DocStyle(size: 22, weight: 700, width: 90),
    );
    final sectionFields =
        DocCatalog.fieldsIn(kind, section).where((f) => f.hasStyle).toList();
    final allStyled = sectionFields.every(
      (f) => styled.styleOf(f.key) == const DocStyle(size: 22, weight: 700, width: 90),
    );
    check('[4] ${kind.name}: «نمط القسم» يطبّق على كل حقول القسم', allStyled);

    // حقل غير نصّي (الشعار) لا يُضبط نمطه.
    final noStyle = DocCatalog.fieldsOf(kind).where((f) => !f.hasStyle);
    check(
      '[4] ${kind.name}: الحقول غير النصّية معلَّمة',
      noStyle.isNotEmpty,
    );
  }

  // القيم الافتراضية تحفظ الشكل الحالي (لا تتغيّر فاتورة قائمة بعد التحديث).
  final st = DocKind.statement;
  check(
    '[4] كشف الحساب: عنوان 19 (كما كان)',
    DocCatalog.fieldOf(st, DocCatalog.kTitle)!.style.size == 19,
  );
  check(
    '[4] كشف الحساب: خلايا الجداول 12',
    DocCatalog.fieldOf(st, DocCatalog.kItemsTable)!.style.size == 12,
  );
  check(
    '[4] كشف الحساب: عنوان القسم 14',
    DocCatalog.fieldOf(st, DocCatalog.kSectionTitle)!.style.size == 14,
  );
  check(
    '[4] كشف الحساب: الإجماليات 13',
    DocCatalog.fieldOf(st, DocCatalog.kTotals)!.style.size == 13,
  );
  final inv = DocKind.invoice;
  check(
    '[4] الفاتورة: سطر الصنف 27',
    DocCatalog.fieldOf(inv, DocCatalog.kItemLine)!.style.size == 27,
  );
  check(
    '[4] الفاتورة: سعر الصنف 24',
    DocCatalog.fieldOf(inv, DocCatalog.kItemPrice)!.style.size == 24,
  );
  // 🚨 كل الأوزان الافتراضية 400 في المستندات القائمة: الكود القديم كان
  // يمرّر `fontWeight: bold` بلا أثر (الوجه صريح) ⇒ الافتراضي «عادي» هو
  // الشكل الحالي فعلًا. ورقة المغسلة مستند **جديد**، فتصميمها المطبوع عريض
  // في العنوان والرقم والإجماليات عن قصد — ويبقى الوزن قابلًا للتغيير.
  final anyBoldDefault = DocKind.values
      .where((k) => k != DocKind.laundrySlip)
      .any(
        (k) => DocCatalog.fieldsOf(k).any((f) => f.style.weight != 400),
      );
  check('[4] الأوزان الافتراضية للمستندات القائمة عادية', !anyBoldDefault);
}

// ───────────────────────────────────────────────────────────────────────
// [5] التسامح: قالب تالف لا يُسقط الطباعة
// ───────────────────────────────────────────────────────────────────────
void _checkTolerance() {
  for (final kind in DocKind.values) {
    for (final bad in <Object?>[
      null,
      <String, dynamic>{},
      <String, dynamic>{'enabled': 'نصّ لا خريطة'},
      <String, dynamic>{'enabled': <String, dynamic>{DocCatalog.kLogo: 'yes'}},
      <String, dynamic>{'texts': <String, dynamic>{DocCatalog.kTitle: 42}},
      <String, dynamic>{'styles': <String, dynamic>{DocCatalog.kTitle: 'كبير'}},
      <String, dynamic>{
        'styles': <String, dynamic>{
          DocCatalog.kTitle: <String, dynamic>{'size': 'كبير'},
        },
      },
      <String, dynamic>{'enabled': null, 'texts': null, 'styles': null},
    ]) {
      final t = DocTemplate.fromJson(kind, bad as Map?);
      check(
        '[5] ${kind.name}: قالب تالف (${bad.runtimeType}) ⇒ الافتراضي',
        t.isOn(DocCatalog.kLogo) ==
                DocTemplate.defaults(kind).isOn(DocCatalog.kLogo) &&
            t.styleOf(DocCatalog.kTitle) ==
                DocTemplate.defaults(kind).styleOf(DocCatalog.kTitle),
      );
    }
  }

  // عرض غائب (مسار قديم نسي تمرير القالب) يعود للسجلّ لا لـ«الكل مُفعَّل».
  const view = DocTemplateView(DocKind.invoice, null, null, null);
  check(
    '[5] خريطة غائبة ⇒ افتراضي السجلّ (لا الكل مُفعَّل)',
    view.isOn(DocCatalog.kShortAddress) ==
        DocCatalog.fieldOf(DocKind.invoice, DocCatalog.kShortAddress)!
            .defaultEnabled,
  );
  check(
    '[5] خريطة غائبة: نصّ الحقل من السجلّ',
    view.text(DocCatalog.kReceiptNo) == 'رقم الإيصال',
    view.text(DocCatalog.kReceiptNo),
  );
  check(
    '[5] خريطة غائبة: نمط الحقل من السجلّ',
    view.style(DocCatalog.kReceiptNo) ==
        DocCatalog.fieldOf(DocKind.invoice, DocCatalog.kReceiptNo)!.style,
  );
}

// ───────────────────────────────────────────────────────────────────────
// [6] الروابط بالخيارات القديمة: كل مرادف مسجَّل فعلًا
// ───────────────────────────────────────────────────────────────────────
void _checkLegacyLinks() {
  for (final kind in DocKind.values) {
    final links = DocCatalog.legacyFields(kind);
    // كشف الحساب وملخّص الوردية لا خيارات قديمة لهما في `invoiceDisplay`.
    if (kind == DocKind.invoice) {
      check('[6] ${kind.name}: له مرادفات قديمة', links.isNotEmpty);
    }

    for (final f in links) {
      final key = f.legacyToggle ?? f.legacyText!;
      final opt = SettingOptions.byKey(key);
      check('[6] ${kind.name}: «$key» مسجَّل في SettingOptions', opt != null);
      if (opt == null) continue;

      // النوع يجب أن يطابق: مفتاح منطقي ⇐ boolean، ونصّي ⇐ text.
      if (f.legacyToggle != null) {
        check(
          '[6] ${kind.name}: «$key» منطقي',
          opt.kind == SettingKind.boolean,
          '${opt.kind}',
        );
      } else {
        check(
          '[6] ${kind.name}: «$key» نصّي',
          opt.kind == SettingKind.text,
          '${opt.kind}',
        );
      }
    }

    // الزرع: قيمة قديمة '0' تُعطّل، و'1' تُفعّل، والنصّ يُنسخ.
    final seeded = DocTemplate.defaults(kind).seededFromLegacy(
      <String, String>{
        for (final f in links)
          (f.legacyToggle ?? f.legacyText!):
              f.legacyToggle != null ? '0' : 'نصّ من الإعدادات القديمة',
      },
    );
    for (final f in links) {
      if (f.legacyToggle != null) {
        check('[6] ${kind.name}: الزرع يعطّل «${f.key}»', !seeded.isOn(f.key));
      } else {
        check(
          '[6] ${kind.name}: الزرع ينسخ نصّ «${f.key}»',
          seeded.textOf(f.key) == 'نصّ من الإعدادات القديمة',
          seeded.textOf(f.key),
        );
      }
    }
  }

  // كل مفتاح في `SettingOptions` مرتبط بحقل واحد على الأكثر لكل نوع.
  for (final kind in DocKind.values) {
    final seen = <String, String>{};
    for (final f in DocCatalog.legacyFields(kind)) {
      final key = f.legacyToggle ?? f.legacyText!;
      check(
        '[6] ${kind.name}: «$key» مرتبط بحقل واحد',
        !seen.containsKey(key),
        '${seen[key]} و${f.key}',
      );
      seen[key] = f.key;
    }
  }
}

// ───────────────────────────────────────────────────────────────────────
// [7] المولّدات: لا نصوص ولا أحجام مكتوبة في الكود
// ───────────────────────────────────────────────────────────────────────
void _checkGenerators() {
  final pdf = readCode('lib/core/services/preparePDF.dart');
  final slip = readCode('lib/services/pdf/laundry_slip_pdf.dart');

  for (final kind in DocKind.values) {
    final src = kind == DocKind.laundrySlip ? slip : pdf;
    check(
      '[7] المولّد يقرأ قالب ${DocCatalog.labelOf(kind)}',
      src.contains('DocTemplateView.of(shiftData, DocKind.${kind.name})') ||
          src.contains('DocTemplateView.of(data, DocKind.${kind.name})'),
    );
  }

  // 🚨 الحرس الشامل: النصوص العربية المسموحة في المولّد هي المعلنة فقط.
  final extra = _arabicLiterals(pdf).difference(_allowedLiterals);
  check(
    '[7] لا نصّ مستند مكتوب في المولّد (خارج المسموح)',
    extra.isEmpty,
    '${extra.toList()..sort()}',
  );

  // ورقة المغسلة: كل نصوصها من القالب — لا حرف عربي مكتوب في المولّد.
  final slipExtra = _arabicLiterals(slip);
  check(
    '[7] ورقة المغسلة: لا نصّ عربي مكتوب في المولّد',
    slipExtra.isEmpty,
    '${slipExtra.toList()..sort()}',
  );

  // 🚨 لا أحجام في الكود: كل نصّ يمرّ من نمط القالب. الاستثناء الوحيد هو
  // السطر الذي **يبني** النمط داخل `_docText` (`fontSize: style.size`).
  check(
    '[7] `fontSize` مرة واحدة فقط (من النمط)',
    'fontSize:'.allMatches(pdf).length == 1 &&
        pdf.contains('fontSize: style.size'),
    '${'fontSize:'.allMatches(pdf).length}',
  );
  // ورقة المغسلة: نقطة رسم واحدة بحجمها النهائي بعد نسبة القالب.
  check(
    '[7] ورقة المغسلة: `fontSize` مرة واحدة فقط',
    'fontSize:'.allMatches(slip).length == 1 &&
        slip.contains('fontSize: actual'),
    '${'fontSize:'.allMatches(slip).length}',
  );

  // نوع الدفع يُطبع **بلغة المستند** لا بلغة الواجهة: مستند عربي ⇒ «كاش»،
  // ومستند إنجليزي ⇒ `Cash`. التحويل في المولّد نفسه، فيغطّي البيع وإعادة
  // الطباعة والمشاركة بلا تكرار في كل حمولة.
  check(
    '[7] نوع الدفع المطبوع يمرّ عبر PaymentMethods.labelIn',
    pdf.contains('PaymentMethods.labelIn(') &&
        pdf.contains('english: !isRtl') &&
        !pdf.contains("data['payment']}"),
  );

  // مقاس الشعار من الإعداد لا ثابتًا في الكود (150 نقطة القديمة)،
  // وعرضه وارتفاعه مستقلّان وكلاهما مقصوص على الورق.
  check(
    '[7] مقاس الشعار يُقرأ من الإعداد (عرض × ارتفاع)',
    pdf.contains('PrintVisualSize.logo(') &&
        pdf.contains("data['logoWidthMm']") &&
        pdf.contains("data['logoHeightMm']") &&
        !pdf.contains('width: 150, height: 150'),
  );
  check(
    '[7] مقاس رمز الموقع يُقرأ من الإعداد',
    pdf.contains('PrintVisualSize.qr(') && pdf.contains("data['mapQrSizeMm']"),
  );
  // `fontWeight` بلا أثر مع وجه صريح (`text.dart:170`) — وجوده يعني نمطًا
  // يبدو مضبوطًا ولا يُرى في الورق.
  check('[7] لا `fontWeight` في المولّد', !pdf.contains('fontWeight'));
  check(
    '[7] ورقة المغسلة: لا `fontWeight`',
    !slip.contains('fontWeight'),
  );
  // `letterSpacing` يكسر اتصال الحروف العربية (مُثبَت بمسبار).
  check('[7] لا `letterSpacing` في المولّد', !pdf.contains('letterSpacing'));
  check(
    '[7] ورقة المغسلة: لا `letterSpacing`',
    !slip.contains('letterSpacing'),
  );

  // 🚨 نقطة رسم واحدة: `pw.Text` و`pw.TextStyle` لا يُستخدمان إلا داخل
  // `_docText` — وإلا تسلّل نصّ بلا نمط ولا RTL ولا تطبيع.
  int count(String needle, String src) => needle.allMatches(src).length;
  check('[7] `pw.Text(` مرة واحدة فقط', count('pw.Text(', pdf) == 1, '${count('pw.Text(', pdf)}');
  check(
    '[7] `pw.TextStyle(` مرة واحدة فقط',
    count('pw.TextStyle(', pdf) == 1,
    '${count('pw.TextStyle(', pdf)}',
  );
  check(
    '[7] ورقة المغسلة: `pw.Text(` مرة واحدة فقط',
    count('pw.Text(', slip) == 1,
    '${count('pw.Text(', slip)}',
  );
  check(
    '[7] ورقة المغسلة: `pw.TextStyle(` مرة واحدة فقط',
    count('pw.TextStyle(', slip) == 1,
    '${count('pw.TextStyle(', slip)}',
  );
  check('[7] التعريض الصناعي بـ StackFit.passthrough', pdf.contains('pw.StackFit.passthrough'));
  check('[7] التمديد الأفقي بـ Matrix4', pdf.contains('Matrix4.diagonal3Values'));
  check(
    '[7] ورقة المغسلة: التعريض والتمديد من القالب',
    slip.contains('pw.StackFit.passthrough') &&
        slip.contains('Matrix4.diagonal3Values'),
  );
  check(
    '[7] ورقة المغسلة: نصوصها تُطبَّع بـArabicText.safe',
    slip.contains('ArabicText.safe'),
  );

  // قرارات الإظهار القديمة لم تعد تُقرأ من خريطة البيانات.
  const staleFlags = <String>[
    "data['showLogo']",
    "data['showTaxNumber']",
    "data['showCrNumber']",
    "data['showShortAddress']",
    "data['showCashier']",
    "data['showDatetime']",
    "data['showQr']",
    "data['invoiceTitle']",
    "data['footerNote']",
  ];
  final stale = staleFlags.where(pdf.contains).toList();
  check('[7] لا قرارات إظهار قديمة في المولّد', stale.isEmpty, '$stale');

  // 🚨 قاعدة المشروع: كل نصّ عربي في PDF يحمل RTL صريحًا.
  // الاتجاه **يتبع لغة المستند** لا لغة الواجهة: عربي ⇒ rtl، إنجليزي ⇒ ltr.
  // كتابته حرفيًّا كانت تجعل المستند الإنجليزي يُقرأ من آخر السطر.
  check(
    '[7] الاتجاه يتبع لغة المستند في نقطة الرسم',
    pdf.contains('isRtl ? pw.TextDirection.rtl : pw.TextDirection.ltr'),
  );
  check(
    '[7] ورقة المغسلة: الاتجاه يتبع لغة الحمولة',
    slip.contains("data['docLang']") &&
        slip.contains('pw.TextDirection.rtl : pw.TextDirection.ltr'),
  );
}

// ───────────────────────────────────────────────────────────────────────
// [8] مواضع الاستدعاء تُمرّر القالب فعلًا
// ───────────────────────────────────────────────────────────────────────
void _checkCallSites() {
  final sites = <String, String>{
    'lib/controller/printInvoicecontroller.dart': 'DocKind.invoice',
    'lib/core/services/invoice_share_service.dart': 'DocKind.invoice',
    'lib/controller/previousinvoicecontroller.dart': 'DocKind.invoice',
    'lib/controller/customer/customer_statement_controller.dart':
        'DocKind.statement',
    // ملخّص الوردية كان خارج النظام — يُفحص الآن كغيره.
    'lib/controller/shift_controller.dart': 'DocKind.shift',
  };
  sites.forEach((path, kind) {
    final src = read(path);
    check(
      '[8] $path يمرّر $kind',
      src.contains('DocTemplateService.instance.transport($kind)'),
    );
  });

  // ورقة المغسلة لها قالب مستقلّ يُمرَّر من مساري البيع وإعادة الطباعة.
  for (final path in <String>[
    'lib/controller/printInvoicecontroller.dart',
    'lib/controller/previousinvoicecontroller.dart',
  ]) {
    check(
      '[8] $path يمرّر DocKind.laundrySlip',
      read(path).contains(
        'DocTemplateService.instance.transport(DocKind.laundrySlip)',
      ),
    );
  }

  // الإقلاع يحمّل القوالب قبل بناء الواجهة.
  final main = read('lib/main.dart');
  check(
    '[8] main يحمّل القوالب بعد خيارات النظام',
    main.indexOf('DocTemplateService.instance.loadAll()') >
        main.indexOf('AppSettingsService.instance.load()'),
  );

  // شاشة الإعدادات القديمة تُزامن القالب (وإلا تناقض المنظران).
  final settings = read('lib/controller/settings/settings_controller.dart');
  check('[8] updateSetting يزامن القالب', settings.contains('mirrorLegacy('));
}

// ───────────────────────────────────────────────────────────────────────
// [9] واجهة المحرّر
// ───────────────────────────────────────────────────────────────────────
void _checkEditorUi() {
  const path = 'lib/view/screen/settings/doc_template_screen.dart';
  final ui = read(path);

  check('[9] المحرّر يبني حقوله من السجلّ', ui.contains('DocCatalog.fieldsOf'));
  check('[9] المحرّر يعرض كل الأقسام', ui.contains('DocSections.ordered'));
  check('[9] المحرّر فيه مفتاح تفعيل لكل حقل', ui.contains('Switch('));
  check('[9] المحرّر فيه حقل نصّ', ui.contains('TextField('));
  check('[9] المحرّر فيه تفعيل/إيقاف الكل', ui.contains('withAllEnabled('));
  check(
    '[9] المحرّر يمرّر القيمة من زرّ الكل',
    ui.contains('_setAll(true)') && ui.contains('_setAll(false)'),
  );
  check('[9] المحرّر فيه استعادة الافتراضي', ui.contains('_svc.reset('));
  check('[9] الحفظ يمرّ من الخدمة وحدها', ui.contains('_svc.save('));
  check('[9] لا كتابة مباشرة للقاعدة من الشاشة', !ui.contains('SqlDB'));

  // ─── النمط: لكل حقل، ولكل قسم ───
  check('[9] لوحة نمط لكل حقل', ui.contains('_StyleControls('));
  check('[9] الحجم والوزن والعرض معروضة', ui.contains('DocStyle.weights') && ui.contains('width'));
  check('[9] تعديل النمط يمرّ بالقالب', ui.contains('withField(f.key, style:'));
  check('[9] «نمط القسم» يطبّق على القسم', ui.contains('withSectionStyle('));
  check('[9] الحقول غير النصّية لا تُعرض لوحة نمطها', ui.contains('f.hasStyle'));
  check('[9] المعاينة تقرأ النمط من القالب', ui.contains('styleOf(f.key)'));

  // التبويبات الأربعة.
  for (final kind in DocKind.values) {
    check(
      '[9] تبويب ${DocCatalog.labelOf(kind)} موجود',
      ui.contains('DocCatalog.labelOf(kind)') || ui.contains('DocKind.${kind.name}'),
    );
  }
  check(
    '[9] فتح الشاشة على تبويب محدَّد',
    ui.contains('Get.arguments') && ui.contains('arg is DocKind'),
  );

  // المسار مُعلَن ومحروس.
  final routes = read('lib/routes.dart');
  check(
    '[9] المسار مُسجَّل',
    routes.contains('name: AppRoute.settingsDocTemplate'),
  );
  check(
    '[9] المسار محروس بصلاحية الإعدادات',
    RegExp(r'settingsDocTemplate[\s\S]{0,240}settingsManage').hasMatch(routes),
  );
  check(
    '[9] لا `const [` في الحراس (get-4.7.3)',
    !routes.contains('middlewares: const ['),
  );

  final constants = read('lib/core/constant/routes.dart');
  check(
    '[9] الثابت معرَّف',
    constants.contains('settingsDocTemplate = "/settings/doc-template"'),
  );

  final index = read('lib/view/screen/settings/settings_screen.dart');
  check(
    '[9] للمدخل وجود في فهرس الإعدادات',
    index.contains('AppRoute.settingsDocTemplate'),
  );
}

// ───────────────────────────────────────────────────────────────────────
// [10] مُطبِّع «لا» — المسافة المبتلعة قبل الوصلة
// ───────────────────────────────────────────────────────────────────────
void _checkArabicSanitizer() {
  // العيب: «رمز الاستلام» تُرسم «رمزالاستلام» (مُثبَت بمسبار على الحزمة).
  final fixed = ArabicText.safe('رمز الاستلام');
  check('[10] «رمز الاستلام» ⇒ مسافتان', fixed == 'رمز  الاستلام', fixed);
  check('[10] التطبيع معلَّم', ArabicText.needsFix('رمز الاستلام'));
  check('[10] الحروف لم تتغيّر', fixed.replaceAll(' ', '') == 'رمزالاستلام');
  // التطبيع عاطل التكرار: تمريره مرّتين لا يضيف مسافة.
  check('[10] التطبيع عاطل التكرار', ArabicText.safe(fixed) == fixed);

  // ما لا يحتاج إصلاحًا يبقى كما هو حرفيًا.
  for (final ok in <String>[
    '',
    'رمز',
    'رمز القطع',
    'رمز الوردية',
    'السلام عليكم',
    'رقم الإيصال',
    'Invoice 1024',
    'لا يوجد',
  ]) {
    check('[10] بلا تغيير: «$ok»', ArabicText.safe(ok) == ok, ArabicText.safe(ok));
  }

  // نهايات النصّ: مسافة ثم لام فقط (بلا ألف) لا تُعدّ وصلة.
  check('[10] «رمز ل» بلا تغيير', ArabicText.safe('رمز ل') == 'رمز ل');
  check('[10] «رمز لا» بلا تغيير (لا وصلة)', ArabicText.safe('رمز لا') == 'رمز لا');
  check('[10] «رمز الاسم» يُصلَح', ArabicText.needsFix('رمز الاسم'));
  check('[10] «رمز الاشتراك» يُصلَح', ArabicText.needsFix('رمز الاشتراك'));
  check(
    '[10] «رمز الاشتراك» ⇒ مسافتان',
    ArabicText.safe('رمز الاشتراك') == 'رمز  الاشتراك',
    ArabicText.safe('رمز الاشتراك'),
  );

  // التطبيق الفعلي في مسار الرسم.
  final pdf = readCode('lib/core/services/preparePDF.dart');
  check('[10] نقطة الرسم تُطبِّع كل نصّ', pdf.contains('ArabicText.safe(text)'));

  final tpl = read('lib/services/pdf/doc_template.dart');
  check(
    '[10] نصوص القالب تُطبَّع عند القراءة',
    tpl.contains('ArabicText.safe(raw)'),
  );
  check(
    '[10] الإنجليزية مشروطة بلغة المستند',
    tpl.contains('if (!isEnglishDoc) return ArabicText.safe(raw);'),
  );
  // 🚨 العزل لا يرى `L10n`؛ اللغة تُقرأ من الحمولة (`docLang`).
  check(
    '[10] اللغة تُقرأ من الحمولة لا من `L10n`',
    tpl.contains("data['docLang']") && tpl.contains('this.isEnglishDoc = false'),
  );
  check('[10] الواجهة تقرأ النصّ الخام (لا تطبيع)', tpl.contains('String textOf(String key'));
}
