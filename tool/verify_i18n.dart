// حرس الترجمة — يمنع أن يصير «زرّ اللغة» زرًّا لا يترجم شيئًا.
//
// الخطر الحقيقي هنا **صامت**: واجهة إنجليزية تعرض عربيًّا في نصف شاشاتها، أو
// ترجمة تُحذف من القاموس فيظهر النصّ العربي بلا أن يفشل أي شيء. لذلك:
//   • [2] يُشغّل محرّك الترجمة فعليًا على نصوص حقيقية.
//   • [6] **سقف متحرّك (ratchet)**: عدد النصوص غير المترجمة لا يجوز أن يزيد.
//     كل تحويل جديد يخفضه، وأي إضافة نصّ عربي جديد بلا ترجمة تفشل فورًا.
//
// التشغيل: dart run tool/verify_i18n.dart
import 'dart:io';

import 'package:laundry/config/app_info.dart';
import 'package:laundry/services/i18n/app_language.dart';
import 'package:laundry/services/i18n/currency.dart';
import 'package:laundry/services/i18n/l10n.dart';
import 'package:laundry/services/i18n/translations_en.dart';
import 'package:laundry/services/pdf/doc_template.dart';

int _ok = 0;
int _fail = 0;

void check(String name, Object? got, Object? expected, {String? detail}) {
  final pass = got == expected;
  if (pass) {
    _ok++;
    print('  ✓ $name');
  } else {
    _fail++;
    print('  ✗ $name  → got=$got expected=$expected');
    if (detail != null && detail.isNotEmpty) print('      $detail');
  }
}

/// سقف النصوص غير المترجمة — **ينزل فقط**. رفعه يعني تراجعًا في التغطية.
///
/// وصل إلى **صفر** في 2026-10-25: كل نصّ عربي يظهر للمستخدم له ترجمة. أي نصّ
/// واجهة جديد بلا ترجمة يُفشِل الحارس فورًا — وهذا هو المقصود، لا العكس.
const int kUntranslatedCeiling = 0;

/// نصوص عربية **ليست واجهة** — تُستثنى من قياس التغطية، كلٌّ بسببه.
///
/// لماذا استثناء صريح لا ترجمة؟ لأن ترجمتها **خطأ** لا إنجاز:
///   • سجلّات `debugPrint` لا يراها المستخدم أبدًا — ترجمتها تُهدر القاموس
///     وتُخفي نصوصًا حقيقية خلف ضجيج.
///   • تعبيرات نمطية وجداول أرقام عربية: تُقارَن لا تُعرَض، وترجمتها تُعطّل
///     وظيفتها (تطبيع البحث، تحليل الأرقام).
///   • أسماء ملفّات: تُكتب على القرص، وترجمتها تُنتج ملفًّا لا يجده المستخدم.
///   • نصّ له شقيق `_en` في نفس الصفّ: مُعرَّب أصلًا على مستوى البيانات.
///
/// كل مدخل هنا **مُدقَّق يدويًّا**؛ لا يُضاف نصّ واجهة إلى هذه القائمة.
const Set<String> kNonUiLiterals = <String>{
  // ─── سجلّات تشخيص (debugPrint فقط) ───
  'قاعدة البيانات: محرّك ffi (\$label).',
  '⚠️ RunTarget: مطلوب «\${kRunTarget.name}» والنظام الفعلي «\${real.name}» '
      '⇒ يُستخدم الفعلي. عدّل kRunTarget في lib/config/run_target.dart.',
  'التفضيلات غير متاحة — العداد من القاعدة فقط: \$e',
  'ترقيم الفواتير: قاعدة=\$dbMax، إعداد=\$startFrom، محفوظ=\$_storedValue '
      '⇒ البداية=\$floorValue',
  'PrefsGuard: أُصلح ملفّ التفضيلات التالف (كان \${raw.length} محرفًا غير صالح)',
  'PrefsGuard: تعذّر إصلاح التفضيلات: \$e',
  'PrefsGuard: تعذّر تحديد مسار التفضيلات: \$e',
  'PrefsGuard: تعذّر نسخ الملفّ التالف: \$e',
  'PrefsGuard: تعذّرت قراءة التفضيلات: \$e',
  'تاريخ الكود غير صالح: \$codeRaw',
  'طُبِّق تاريخ الترخيص المضمَّن في الكود: \$codeRaw',
  'rebuildAllBalances مرفوض: لا صلاحية debt.repair',
  'deleteOldInvoices مرفوض: لا صلاحية data.delete',
  'أُزيل جدول غير مستخدم: \$table',
  'إصلاح مجموع \$repaired فاتورة كانت مخزَّنة بصفر',
  'تطبيع حالات المصنعية: \$changed صفًّا',
  'تنظيف إعدادات قديمة: \${rows.length} مفتاحًا',
  'ترحيل طرق الدفع: \$changed قيمة',
  'ترحيل مقاس الشعار: \$legacy مم ⇒ عرض × ارتفاع',
  'PrinterService: تعذّرت إعادة توليد نسخة الطباعة — \$e',
  'تعبئة \$inserted بند في invoice_items من الفواتير القديمة',
  'تعذّر إزالة الجدول \$table: \$e',
  'تم إنشاء قاعدة البيانات! تم إنشاء الجداول بنجاح',
  'تم تحديث قاعدة البيانات! من الإصدار \$oldVersion إلى \$newVersion',
  'تمت إعادة احتساب إجمالي مشتريات الزبائن',
  'تمت إعادة مزامنة أرصدة الزبائن المدينين من الفواتير',
  'ربط \$linked حركة قديمة بوردياتها',

  // ─── تعبيرات نمطية وجداول تطبيع ───
  r'^[0-9٠-٩۰-۹+\-()\s]+$',
  '٠١٢٣٤٥٦٧٨٩',
  '۰۱۲۳۴۵۶۷۸۹',
  r'[,،\s]+',
  'آ', 'أ', 'إ', 'ا', 'ة', 'ه', 'ى', 'ي',
  // حروف يحملها **جدول التطبيع** في `InvoiceLines` (توحيد الهمزات) — تُقارَن
  // لا تُعرَض، وترجمتها تُعطّل المطابقة.
  'ٱ', 'ئ', 'ؤ', 'و',
  // نطاق الأرقام العربية/الهندية — يُقارَن لا يُعرَض.
  '[٠-٩۰-۹]',

  // ─── أسماء ملفّات على القرص ───
  'كشف_حساب_\${st.customerId}.pdf',
  'كشف_حساب_\$customerId',
  'ملخص_الوردية',
  'ملخص_الوردية_\$id',

  // ─── نصّ له شقيق `_en` في نفس الصفّ ───
  'استرداد قيمة أيام غير مُقدَّمة — \$custName '
      '(اشتراك #\$subscriptionId، \$remaining يوم)',
};

/// يجمع كل نصّ عربي حرفي في `lib/` خارج ملفات الترجمة.
Set<String> _arabicLiterals() {
  final out = <String>{};
  final re = RegExp(r"'([^'\n]*[\u0600-\u06FF][^'\n]*)'");
  for (final f in Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))) {
    if (f.path.replaceAll('\\', '/').contains('/i18n/')) continue;
    for (final line in f.readAsLinesSync()) {
      if (line.trimLeft().startsWith('//')) continue;
      for (final m in re.allMatches(line)) {
        out.add(_unescape(m.group(1)!));
      }
    }
  }
  return out;
}

/// يفكّ هروب Dart في النصّ المستخرج (`\n` · `\t` · `\'` · `\\`).
///
/// بدونه يصل نصّ فيه `\n` مكتوبًا إلى المقارنة بينما القاموس يحمل سطرًا
/// حقيقيًّا، فيُحسب **مترجمًا وهو كذلك** على أنه مفقود — إنذار كاذب دائم.
String _unescape(String raw) {
  final sb = StringBuffer();
  for (var i = 0; i < raw.length; i++) {
    final c = raw[i];
    if (c != '\\' || i + 1 >= raw.length) {
      sb.write(c);
      continue;
    }
    final next = raw[++i];
    switch (next) {
      case 'n':
        sb.write('\n');
      case 't':
        sb.write('\t');
      case 'r':
        sb.write('\r');
      default:
        // أي هروب آخر (`\-` · `\s` · `\.`) يبقى **كما هو**: التعبيرات
        // النمطية تُقارَن لا تُعرَض، وحذف الشرطة العكسية يُفسِدها.
        sb.write('\\');
        sb.write(next);
    }
  }
  return sb.toString();
}

/// جسم `generatePdfData` وحده — للتحقق من أنه لا يقرأ حالة `L10n` العامة.
///
/// المولّد يعمل داخل `compute` (عزل مستقلّ)، فأي قراءة لـ`L10n` فيه تعطي
/// اللغة الافتراضية (العربية) مهما بدّل المستخدم — وهذا سبب طباعة الفاتورة
/// بالعربية دائمًا. الحدّ: من توقيع الدالة إلى `_loadPhotoBytes`.
String _invoiceBody(String src) {
  const startMark = 'static Future<Uint8List> generatePdfData(';
  final start = src.indexOf(startMark);
  if (start < 0) return '';
  final end = src.indexOf('static Future<List<Uint8List?>> _loadPhotoBytes', start);
  return src.substring(start, end < 0 ? src.length : end);
}

void main() {
  print('═' * 62);
  print('حرس الترجمة');
  print('═' * 62);

  // ─── [1] سجلّ اللغات ────────────────────────────────────────────────
  print('\n[1] AppLanguage');
  check('[1] ثلاث لغات', AppLanguage.choices.length, 3);
  check(
    '[1] الأكواد فريدة',
    AppLanguage.codes.toSet().length,
    AppLanguage.codes.length,
  );
  check('[1] الافتراضي عربي', AppLanguage.defaultLanguage.code, 'ar');
  check('[1] `byCode(null)` يعطي الافتراضي', AppLanguage.byCode(null).code, 'ar');
  check(
    '[1] كود مجهول يعطي الافتراضي',
    AppLanguage.byCode('xx').code,
    'ar',
  );
  check('[1] `byCode` يطبّع الحالة', AppLanguage.byCode(' EN ').code, 'en');
  check('[1] العربية RTL', AppLanguage.ar.isRtl, true);
  check('[1] الإنجليزية LTR', AppLanguage.en.isRtl, false);
  check(
    '[1] `system` + جهاز عربي ⇒ عربي',
    AppLanguage.system.resolve('ar').code,
    'ar',
  );
  check(
    '[1] `system` + جهاز عربي سعودي ⇒ عربي',
    AppLanguage.system.resolve('ar-SA').code,
    'ar',
  );
  check(
    '[1] `system` + جهاز فرنسي ⇒ إنجليزي',
    AppLanguage.system.resolve('fr').code,
    'en',
  );
  check(
    '[1] `system` + جهاز مجهول ⇒ إنجليزي',
    AppLanguage.system.resolve(null).code,
    'en',
  );
  check(
    '[1] اللغة الصريحة تتجاوز الجهاز',
    AppLanguage.ar.resolve('en').code,
    'ar',
  );
  check('[1] `isKnown` يرفض المجهول', AppLanguage.isKnown('de'), false);

  // ─── [2] محرّك الترجمة ──────────────────────────────────────────────
  print('\n[2] L10n');
  L10n.setLanguage(AppLanguage.ar, deviceCode: 'ar');
  check('[2] العربية تُعيد النصّ كما هو', L10n.t('حفظ'), 'حفظ');
  check('[2] الفراغ يبقى فراغًا', L10n.t(''), '');
  check('[2] العربية: لا ترجمة تُطبَّق', L10n.t('نصّ غير مترجم'), 'نصّ غير مترجم');

  L10n.setLanguage(AppLanguage.en, deviceCode: 'en');
  check('[2] الإنجليزية تترجم', L10n.t('حفظ'), 'Save');
  check('[2] الإنجليزية: نصّ غير مترجم يعود عربيًّا', L10n.t('نصّ غير مترجم'), 'نصّ غير مترجم');
  check('[2] الإنجليزية: الفراغ يبقى فراغًا', L10n.t(''), '');
  check('[2] `tf` يستبدل الرمز الموضعي', L10n.tf('إجمالي {0}', <Object?>['120']), 'Total 120');
  check('[2] الاتجاه يتبع اللغة', L10n.isRtl, false);

  L10n.setLanguage(AppLanguage.ar, deviceCode: 'ar');
  check('[2] العودة للعربية فورية', L10n.t('حفظ'), 'حفظ');
  check('[2] الاتجاه عاد RTL', L10n.isRtl, true);

  // سقوط صفوف القاعدة
  final row = <String, dynamic>{
    'clothing_name': 'ثوب أبيض',
    'clothing_name_en': 'White Thobe',
  };
  check('[2] عربي: يقرأ العمود الأساسي', L10n.localized(row, 'clothing_name'), 'ثوب أبيض');
  L10n.setLanguage(AppLanguage.en, deviceCode: 'en');
  check('[2] إنجليزي: يقرأ `_en`', L10n.localized(row, 'clothing_name'), 'White Thobe');
  check(
    '[2] إنجليزي: `_en` فارغ ⇒ القاموس',
    L10n.localized(<String, dynamic>{
      'clothing_name': 'غترة',
      'clothing_name_en': '   ',
    }, 'clothing_name'),
    'Ghutra',
  );
  check(
    '[2] إنجليزي: `_en` غائب ⇒ القاموس',
    L10n.localized(<String, dynamic>{'clothing_name': 'شماغ'}, 'clothing_name'),
    'Shemagh',
  );
  check(
    '[2] إنجليزي: `_en` غائب وغير معروف ⇒ عربي',
    L10n.localized(<String, dynamic>{
      'clothing_name': 'صنف مخصّص للمستخدم',
    }, 'clothing_name'),
    'صنف مخصّص للمستخدم',
  );
  check(
    '[2] `_en` الصريح يتقدّم على القاموس',
    L10n.localized(<String, dynamic>{
      'clothing_name': 'غترة',
      'clothing_name_en': 'Custom Ghutra',
    }, 'clothing_name'),
    'Custom Ghutra',
  );
  // 🚨 بيانات البذر: الصنف المزروع **قبل** وجود العمود الإنجليزي `_en = NULL`
  // فيبقى عربيًّا إلى الأبد إن لم يسقط العرض على القاموس. هذا الحارس يمنع
  // عودة العطل الذي أبلغ عنه المستخدم.
  //
  // نستخرج أسماء البذر **من المصدر نفسه** لا من قائمة منسوخة هنا: أي صنف
  // يُضاف إلى `_insertDefaultClothing` بلا ترجمة يُفشل الحارس فورًا.
  final seedSrc = File('lib/controller/auth/auth_controller.dart').readAsStringSync();
  final seedRe = RegExp(
    r"""'(?:clothing_name|name|description)':\s*'((?:[^'\\]|\\.)*)'""",
  );
  final seeds = <String>{
    for (final m in seedRe.allMatches(seedSrc)) m.group(1)!.replaceAll(r"\'", "'"),
  };
  check('[2] بيانات البذر مُستخرَجة', seeds.length > 50, true, detail: '${seeds.length}');
  final missingSeeds = seeds.where((s) => !kEnglish.containsKey(s)).toList()..sort();
  check(
    '[2] كل صنف/فئة في بيانات البذر مترجم',
    missingSeeds.join(' · '),
    '',
    detail: 'بلا ترجمة (${missingSeeds.length}): ${missingSeeds.take(8).join(' · ')}',
  );
  for (final seed in <String>['ثوب أبيض', 'سجاد', 'ملابس رجالية', 'مفروشات']) {
    final shown = L10n.localized(<String, dynamic>{
      'clothing_name': seed,
    }, 'clothing_name');
    check(
      '[2] بيانات البذر «$seed» تُترجم بلا `_en`',
      shown != seed && kEnglish[seed] != null,
      true,
      detail: 'ظهر: $shown',
    );
  }
  check(
    '[2] إنجليزي: `_en` غير نصّي لا يُسقط',
    L10n.localized(<String, dynamic>{
      'clothing_name': 'طاقية',
      'clothing_name_en': 42,
    }, 'clothing_name'),
    '42',
  );
  L10n.setLanguage(AppLanguage.ar, deviceCode: 'ar');

  // ─── [3] سلامة القاموس ──────────────────────────────────────────────
  print('\n[3] القاموس');
  check('[3] القاموس غير فارغ', kEnglish.isNotEmpty, true);
  check(
    '[3] لا مفتاح فارغ',
    kEnglish.keys.any((k) => k.trim().isEmpty),
    false,
  );
  check(
    '[3] لا قيمة فارغة',
    kEnglish.values.any((v) => v.trim().isEmpty),
    false,
  );
  check(
    '[3] كل المفاتيح عربية',
    kEnglish.keys.every((k) => RegExp(r'[\u0600-\u06FF]').hasMatch(k)),
    true,
  );
  check(
    '[3] كل القيم لاتينية (لا عربي في الترجمة)',
    kEnglish.values.any((v) => RegExp(r'[\u0600-\u06FF]').hasMatch(v)),
    false,
  );
  check(
    '[3] لا ترجمة مطابقة للمفتاح (ترجمة وهمية)',
    kEnglish.entries.where((e) => e.key == e.value).length,
    0,
  );

  // ─── [4] الربط في التطبيق ───────────────────────────────────────────
  print('\n[4] الربط');
  final main = File('lib/main.dart').readAsStringSync();
  check('[4] main يحمّل اللغة', main.contains('localeController.load()'), true);
  check(
    '[4] `locale` من `L10n` لا ثابتًا',
    main.contains('locale: Locale(L10n.language.code)'),
    true,
  );
  check(
    '[4] `supportedLocales` يشمل العربية والإنجليزية',
    main.contains("supportedLocales: const <Locale>[Locale('ar'), Locale('en')]"),
    true,
  );
  check(
    '[4] مفوَّضو التعريب مركَّبون',
    main.contains('GlobalMaterialLocalizations.delegate') &&
        main.contains('GlobalWidgetsLocalizations.delegate'),
    true,
  );
  final pubspec = File('pubspec.yaml').readAsStringSync();
  check('[4] `flutter_localizations` في pubspec', pubspec.contains('flutter_localizations:'), true);

  // ─── [5] قاعدة البيانات ─────────────────────────────────────────────
  print('\n[5] قاعدة البيانات');
  final sqldb = File('lib/sqldb.dart').readAsStringSync();
  check(
    '[5] الترحيل مُستدعى عند كل فتح',
    sqldb.contains('await _ensureBilingualColumns(mydb);'),
    true,
  );
  for (final col in <String>[
    'clothing_name_en',
    'name_en',
    'description_en',
    'item_name_en',
    'content_en',
    'note_en',
    'label_en',
  ]) {
    check('[5] عمود $col مُهاجَر', sqldb.contains('ADD COLUMN "$col" TEXT'), true);
  }
  check(
    '[5] لا نسخ آلي للعربية في العمود الإنجليزي',
    sqldb.contains('SET "clothing_name_en" = "clothing_name"'),
    false,
  );

  // ─── [6] الاتجاه: لا كتابة حرفية ─────────────────────────────────────
  print('\n[6] الاتجاه والطباعة');
  // `TextDirection.rtl` الحرفية تجعل الاتجاه قرارًا مكتوبًا لا نتيجةً للغة،
  // فتظهر واجهة إنجليزية من اليمين لليسار. الاستثناءان الوحيدان: مُساعد
  // الاتجاه نفسه، ومولّد PDF (يحسم اتجاهه من اللغة داخل `_docText`).
  final rtlFiles = <String>[];
  for (final f in Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))) {
    final path = f.path.replaceAll('\\', '/');
    if (path.endsWith('ui_direction.dart') ||
        path.endsWith('preparePDF.dart') ||
        // مولّد ورقة المغسلة يحسم اتجاهه من `docLang` في الحمولة، لا من
        // اللغة العامة — فهو مستند لا واجهة.
        path.endsWith('laundry_slip_pdf.dart')) {
      continue;
    }
    if (f.readAsStringSync().contains('TextDirection.rtl')) rtlFiles.add(path);
  }
  check(
    '[6] لا TextDirection.rtl حرفية في الواجهة',
    rtlFiles.isEmpty,
    true,
    detail: rtlFiles.join(' · '),
  );
  final pdf = File('lib/core/services/preparePDF.dart').readAsStringSync();
  check(
    '[6] اتجاه PDF يتبع لغة المستند',
    pdf.contains('final isRtl = _rtlOf(data);') &&
        pdf.contains('final isRtl = _rtlOf(shiftData);'),
    true,
  );
  final docTemplate =
      File('lib/services/pdf/doc_template.dart').readAsStringSync();
  check(
    '[6] نصوص القالب الإنجليزية مشروطة باللغة',
    docTemplate.contains('if (!isEnglishDoc) return ArabicText.safe(raw);'),
    true,
  );
  // 🚨 **جذر عطل «الفاتورة تُطبع بالعربية دائمًا»**: المولّد يعمل في عزل
  // `compute` لا يرى `L10n`، فقراءة اللغة من `L10n` داخل العزل تعطي
  // الافتراضي (العربية) دائمًا. اللغة تُختم في `transport` (الخيط الرئيسي)
  // وتُقرأ من `docLang` داخل العزل.
  final docService = File(
    'lib/services/pdf/doc_template_service.dart',
  ).readAsStringSync();
  check(
    '[6] `transport` يختم لغة المستند من الإعداد',
    docService.contains("data['docLang'] = lang.code;") &&
        docService.contains('settings.docLanguage'),
    true,
  );
  check(
    '[6] لغة المستند لا تُشتقّ من لغة الواجهة',
    docService.contains('L10n.language') || docService.contains('L10n.isEnglish'),
    false,
  );
  check(
    '[6] `DocTemplateView` يقرأ `docLang` لا `L10n`',
    docTemplate.contains("data['docLang']") &&
        docTemplate.contains('this.isEnglishDoc = false'),
    true,
  );
  final pdfSrc = File('lib/core/services/preparePDF.dart').readAsStringSync();
  check(
    '[6] مولّد الفاتورة يقرأ اللغة من الحمولة',
    pdfSrc.contains('static bool _rtlOf(Map<String, dynamic> data)') &&
        pdfSrc.contains("data['docLang']") &&
        pdfSrc.contains('final isRtl = _rtlOf(data);'),
    true,
  );
  check(
    '[6] لا قراءة `L10n.isRtl` داخل مولّد الفاتورة',
    _invoiceBody(pdfSrc).contains('L10n.isRtl'),
    false,
  );

  // ─── إثبات **تشغيلي** أن العزل يختار اللغة من الحمولة ────────────────
  //
  // نحاكي العزل بدقّة: `L10n` على العربية (كما هي داخل `compute` فعلًا)،
  // ثم نطلب مستندًا إنجليزيًّا بحمولة `docLang: en`. قبل الإصلاح كان
  // `DocTemplateView.text()` يقرأ `L10n.isEnglish` فيرجع عربيًّا دائمًا.
  L10n.setLanguage(AppLanguage.ar, deviceCode: 'ar');
  final enPayload = <String, dynamic>{
    'docLang': 'en',
    'docEnglish': kEnglish,
  };
  final arPayload = <String, dynamic>{
    'docLang': 'ar',
    'docEnglish': kEnglish,
  };
  final enDoc = DocTemplateView.of(enPayload, DocKind.invoice);
  final arDoc = DocTemplateView.of(arPayload, DocKind.invoice);
  check(
    '[6] حمولة `en` تُنتج عنوان فاتورة إنجليزيًّا',
    enDoc.text(DocCatalog.kTitle),
    kEnglish[DocCatalog.invoiceTitleDefault],
  );
  check(
    '[6] حمولة `ar` تُنتج عنوان فاتورة عربيًّا',
    arDoc.text(DocCatalog.kTitle),
    DocCatalog.invoiceTitleDefault,
  );
  check(
    '[6] الحمولة تتقدّم على `L10n` داخل العزل',
    enDoc.text(DocCatalog.kTitle) != arDoc.text(DocCatalog.kTitle),
    true,
  );
  check(
    '[6] بلا `docLang` نرجع لـ`L10n` (توافق خلفي)',
    () {
      // نضبط `L10n` على الإنجليزية: الحمولة بلا `docLang` فيجب أن تُقرأ
      // الحالة العامة كما كانت قبل الإصلاح (المسارات في الخيط الرئيسي).
      L10n.setLanguage(AppLanguage.en, deviceCode: 'en');
      final v = DocTemplateView.of(<String, dynamic>{
        'docEnglish': kEnglish,
      }, DocKind.invoice).text(DocCatalog.kTitle);
      L10n.setLanguage(AppLanguage.ar, deviceCode: 'ar');
      return v;
    }(),
    kEnglish[DocCatalog.invoiceTitleDefault],
  );
  // اسم بند قديم بلا `_en` داخل العزل: يُترجم بالقاموس لا يبقى عربيًّا.
  check(
    '[6] اسم بند بلا `_en` يُترجم داخل العزل',
    localized(<String, dynamic>{
      'vestments': 'غترة',
    }, 'vestments', english: true),
    'Ghutra',
  );

  // 🚨 حقوق المطوّر كانت `const` عربيًّا ⇒ لا تُترجم أبدًا، فتبقى الجملة
  // العربية وحدها في واجهة إنجليزية بالكامل. الآن تمرّ من `tr`.
  final appInfo = File('lib/config/app_info.dart').readAsStringSync();
  check(
    '[6] حقوق المطوّر تمرّ من `tr`',
    appInfo.contains('static String get developerCredit => tr(') &&
        appInfo.contains('static String get developerName => tr('),
    true,
  );
  check(
    '[6] لا جملة حقوق مطوّر ثابتة عربية',
    RegExp(r"static const String developer(Credit|Name) =").hasMatch(appInfo),
    false,
  );
  check(
    '[6] جملة الحقوق لها ترجمة في القاموس',
    kEnglish[AppInfo.developerCreditKey] != null &&
        kEnglish[AppInfo.developerNameKey] != null,
    true,
  );

  // ─── [7] القيم المخزَّنة: مفاتيح لا نصوص عربية ────────────────────────
  print('\n[7] القيم المخزَّنة');
  check(
    '[7] ترحيل طرق الدفع مُستدعى عند كل فتح',
    sqldb.contains('await _migratePaymentMethodKeys(mydb);'),
    true,
  );
  check(
    '[7] ترحيل حالات المصنعية مُستدعى',
    sqldb.contains('await _migrateProcessingStatusKeys(mydb);'),
    true,
  );
  check(
    '[7] لا قيمة افتراضية عربية في المخطط',
    RegExp(r"""DEFAULT\s+'[^']*[\u0600-\u06FF]""").hasMatch(sqldb),
    false,
  );
  final payment =
      File('lib/services/payment/payment_method.dart').readAsStringSync();
  check(
    '[7] طرق الدفع مفاتيح ثابتة',
    payment.contains("cash('cash', 'كاش')") &&
        payment.contains("card('card', 'شبكة')") &&
        payment.contains("credit('credit', 'آجل')"),
    true,
  );
  check(
    '[7] قراءة طرق الدفع تقبل العربي والمفتاح',
    payment.contains('_aliases[text] ?? _aliases[text.toLowerCase()]'),
    true,
  );

  // ─── [8] التغطية (سقف متحرّك) ───────────────────────────────────────
  print('\n[8] التغطية');
  final all = _arabicLiterals();
  // المستثنى = ما ليس واجهة (سجلّ · تعبير نمطي · اسم ملف · نصّ له شقيق `_en`).
  final excluded = all.where(kNonUiLiterals.contains).toSet();
  final literals = all.difference(excluded);
  final untranslated = literals.where((s) => !kEnglish.containsKey(s)).toList();
  final pct = literals.isEmpty
      ? 100.0
      : ((literals.length - untranslated.length) / literals.length * 100);
  print(
    '  • نصوص عربية فريدة: ${literals.length} · '
    'مترجمة: ${literals.length - untranslated.length} '
    '(${pct.toStringAsFixed(1)}%) · متبقّية: ${untranslated.length} '
    '· مستثناة (ليست واجهة): ${excluded.length}',
  );
  if (untranslated.isNotEmpty) {
    print('  • المتبقّي: ${untranslated.take(12).join(' · ')}');
  }
  // الاستثناء لا يجوز أن يبتلع نصًّا موجودًا فعلًا في القاموس — وإلا صار
  // مخرجًا للتهريب: نصّ واجهة «يُستثنى» فيختفي من القياس بلا أن يُترجم.
  check(
    '[8] الاستثناءات ليست نصوص واجهة مترجمة',
    excluded.where(kEnglish.containsKey).isEmpty,
    true,
  );
  check(
    '[8] كل استثناء موجود فعلًا في الكود',
    kNonUiLiterals.difference(all).isEmpty,
    true,
    detail: 'غير موجود: ${kNonUiLiterals.difference(all).take(5).join(' · ')}',
  );
  check(
    '[8] لا تزيد النصوص غير المترجمة عن السقف',
    untranslated.length <= kUntranslatedCeiling,
    true,
  );
  check(
    '[8] نصوص المظهر واللغة مترجمة',
    <String>['المظهر', 'لغة النظام', 'حفظ', 'إلغاء'].every(kEnglish.containsKey),
    true,
  );

  // ─── [9] رمز العملة والرسائل الموسومة ───────────────────────────────
  print('\n[9] العملة والرسائل');
  L10n.setLanguage(AppLanguage.en);
  check('[9] رمز العملة إنجليزيًّا', Currency.symbol, 'SAR');
  check('[9] الرمز المخزَّن الافتراضي يُترجم', Currency.of('ر.س'), 'SAR');
  check('[9] صيغة «ريال» تُترجم', Currency.of('ريال'), 'SAR');
  check('[9] الرمز الفارغ يسقط للافتراضي', Currency.of(''), 'SAR');
  check('[9] رمز يضبطه المستخدم يبقى كما هو', Currency.of('\$'), '\$');
  check(
    '[9] رسالة موسومة تُترجم وتُستبدل',
    trf('المتبقي: {0} ر.س', ['120.00']),
    'Remaining: 120.00 SAR',
  );
  check(
    '[9] رسالة موسومة بوسمين',
    trf('{0} ر.س — التغطية حتى {1}', ['90.00', '2026-12-01']),
    '90.00 SAR — covered until 2026-12-01',
  );
  check(
    '[9] رسالة رفض الصلاحية مترجمة',
    trf('لا تملك صلاحية «{0}»، راجع مدير النظام.', ['invoice_delete']),
    'You do not hold the "invoice_delete" permission — contact the system administrator.',
  );

  L10n.setLanguage(AppLanguage.ar);
  check('[9] رمز العملة عربيًّا', Currency.symbol, 'ر.س');
  check('[9] الرمز المخزَّن عربيًّا', Currency.of('ر.س'), 'ر.س');
  check(
    '[9] رسالة موسومة عربيًّا',
    trf('المتبقي: {0} ر.س', ['120.00']),
    'المتبقي: 120.00 ر.س',
  );

  print('\n' + '─' * 62);
  print('نجح: $_ok · فشل: $_fail');
  if (_fail > 0) exit(1);
}
