// حرس **لغة المستندات** — يفصل قرار لغة الورقة عن قرار لغة الواجهة.
//
// العيب الصامت: أن يُعاد ربط لغة الفاتورة بلغة الشاشة (سطر `L10n.isRtl`
// واحد يكفي)، فيصير تبديل لغة الواجهة تغييرًا في مستند ضريبي بلا أن يفشل
// أي شيء. هذا الحرس يفحص المسار كاملًا: النوع الخالص · تسجيل الإعداد ·
// ختم اللغة في `transport` · حوامل الطباعة الأربعة · تسمية الدفع.
//
// التشغيل: dart run tool/verify_doc_language.dart
import 'dart:io';

import 'package:laundry/config/constants.dart';
import 'package:laundry/services/i18n/doc_language.dart';
import 'package:laundry/services/i18n/translations_en.dart';
import 'package:laundry/services/pdf/doc_template.dart';
import 'package:laundry/services/settings/setting_option.dart';

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

/// الكود بلا تعليقات — الحرس يفحص السلوك لا شرحه.
String _code(String path) =>
    _read(path).replaceAll(RegExp(r'//[^\n]*'), '');

void main() {
  print('═' * 64);
  print('حرس لغة الفاتورة والمستندات');
  print('═' * 64);

  // ─── [1] النوع الخالص ───────────────────────────────────────────────
  print('\n[1] نوع اللغة');
  check('[1] الافتراضي عربي', DocLanguage.defaultLanguage, DocLanguage.arabic);
  check('[1] الأكواد', DocLanguage.codes.join(','), 'ar,en');
  check('[1] المجهول يسقط للعربية', DocLanguage.byCode('fr'), DocLanguage.arabic);
  check('[1] الحالة لا تهمّ', DocLanguage.byCode('EN'), DocLanguage.english);

  final lang = _read('lib/services/i18n/doc_language.dart');
  check(
    '[1] النوع الخالص لا يستورد Flutter',
    lang.contains("import 'package:flutter"),
    false,
  );
  check(
    '[1] النوع الخالص لا يقرأ L10n',
    lang.contains('L10n.'),
    false,
  );

  // ─── [2] الإعداد ────────────────────────────────────────────────────
  print('\n[2] إعداد «لغة الفاتورة والمستندات»');
  final option = SettingOptions.byKey(AppConstants.settingDocLanguage);
  check('[2] مسجَّل', option != null, true);
  check('[2] المفتاح', option?.key, AppConstants.settingDocLanguage);
  check('[2] انتقائي', option?.isChoice, true);
  check('[2] القيم = أكواد النوع', option?.choices?.join(','), 'ar,en');
  check('[2] الافتراضي', option?.defaultValue, 'ar');
  check(
    '[2] مجموعة عرض الفاتورة',
    option?.group,
    SettingGroups.invoiceDisplay,
  );
  check(
    '[2] لكل قيمة تسمية عرض',
    option?.choiceLabels?.keys.toSet().join(','),
    'ar,en',
  );
  check(
    '[2] التسمية مترجمة',
    option != null && kEnglish.containsKey(option.label),
    true,
  );
  check(
    '[2] الوصف مترجم',
    option != null && kEnglish.containsKey(option.description),
    true,
  );

  // ─── [3] ختم اللغة في transport ─────────────────────────────────────
  print('\n[3] `DocTemplateService.transport`');
  final service = _read('lib/services/pdf/doc_template_service.dart');
  check(
    '[3] اللغة من الإعداد',
    service.contains('settings.docLanguage'),
    true,
  );
  check('[3] تُختم في الحمولة', service.contains("data['docLang']"), true);
  check(
    '[3] القاموس للإنجليزية فقط',
    service.contains('if (lang.isEnglish) data[\'docEnglish\'] = kEnglish;'),
    true,
  );
  check(
    '[3] لا اشتقاق من لغة الواجهة',
    service.contains('L10n.language') || service.contains('L10n.isEnglish'),
    false,
  );
  check(
    '[3] السقوط الآمن للافتراضي',
    service.contains('DocLanguage.defaultLanguage'),
    true,
  );

  // ─── [4] حوامل الطباعة ─────────────────────────────────────────────
  print('\n[4] المسارات الأربعة');
  final printController = _read('lib/controller/printInvoicecontroller.dart');
  check(
    '[4] تاريخ الفاتورة بلغة المستند',
    printController.contains('final dateLocale = docLang.code;'),
    true,
  );
  check(
    '[4] التاريخ المخزَّن محايد اللغة',
    printController.contains("DateFormat('yyyy-MM-dd HH:mm:ss')"),
    true,
  );
  check(
    '[4] ورقة المغسلة بلغة المستند',
    printController.contains('isRtl: settings.docLanguage.isRtl'),
    true,
  );
  check(
    '[4] لا لغة واجهة في الحامل',
    printController.contains('L10n.isRtl'),
    false,
  );

  final previous = _read('lib/controller/previousinvoicecontroller.dart');
  check(
    '[4] إعادة الطباعة بلغة المستند',
    previous.contains('isRtl: settings.docLanguage.isRtl'),
    true,
  );
  check(
    '[4] لا لغة واجهة في إعادة الطباعة',
    previous.contains('L10n.isRtl'),
    false,
  );

  final pdf = _read('lib/core/services/preparePDF.dart');
  check(
    '[4] الفاتورة تقرأ اللغة من الحمولة',
    pdf.contains('final isRtl = _rtlOf(data);'),
    true,
  );
  check(
    '[4] ملخّص الوردية يقرأ اللغة من الحمولة',
    pdf.contains('final isRtl = _rtlOf(shiftData);'),
    true,
  );
  check(
    '[4] الكشف يقرأ اللغة من الحمولة',
    pdf.contains('final isRtl = _rtlOf(data);'),
    true,
  );
  check(
    '[4] اتجاه الورقة من اللغة لا من L10n',
    pdf.contains('isRtl ? pw.TextDirection.rtl : pw.TextDirection.ltr'),
    true,
  );
  check(
    '[4] اتجاه ملخّص الوردية لا يقرأ L10n',
    pdf.contains(
      'L10n.isRtl ? pw.TextDirection.rtl : pw.TextDirection.ltr',
    ),
    false,
  );
  check(
    '[4] تسمية الدفع بلغة المستند',
    pdf.contains('PaymentMethods.labelIn(') && pdf.contains('english: !isRtl'),
    true,
  );
  check(
    '[4] جدول الكشف يتبع اللغة',
    pdf.contains('isRtl ? headers.reversed : headers') &&
        pdf.contains('isRtl ? r.reversed : r'),
    true,
  );
  check(
    '[4] صفوف «عنوان/قيمة» تتبع اللغة',
    pdf.contains(
      'children: isRtl\n          ? [tx(value, key), tx(label, key)]',
    ),
    true,
  );

  final slip = _read('lib/services/pdf/laundry_slip.dart');
  check(
    '[4] ورقة المغسلة تختم لغتها',
    slip.contains("'docLang': isRtl ? 'ar' : 'en'"),
    true,
  );

  // ─── [5] لا مسار طباعة يشتقّ اللغة من الواجهة ───────────────────────
  print('\n[5] استقلال الطباعة عن لغة الواجهة');
  final sources = <String>[
    'lib/core/services/preparePDF.dart',
    'lib/controller/printInvoicecontroller.dart',
    'lib/controller/previousinvoicecontroller.dart',
    'lib/controller/shift_controller.dart',
    'lib/controller/customer/customer_statement_controller.dart',
  ];
  final leaks = <String>[];
  for (final path in sources) {
    final src = _code(path);
    for (final banned in <String>[
      'L10n.isRtl',
      'L10n.isEnglish',
      'L10n.language',
    ]) {
      if (src.contains(banned)) {
        leaks.add('$path → $banned');
      }
    }
  }
  check('[5] لا مسار طباعة يقرأ لغة الواجهة', leaks.join(' | '), '');

  // ─── [6] السجل يعرف المفتاح ────────────────────────────────────────
  print('\n[6] ثبات المفتاح');
  check(
    '[6] المفتاح المخزَّن',
    AppConstants.settingDocLanguage,
    'doc_language',
  );
  check(
    '[6] لا تصادم في السجل',
    SettingOptions.all.map((o) => o.key).toSet().length,
    SettingOptions.all.length,
  );

  // ─── [7] كل نصّ افتراضي للقالب له مقابل إنجليزي ────────────────────
  // بدون هذا، تُطبع فاتورة إنجليزية بعنوان عربي صامت لأن `text()` يسقط
  // للعربية حين لا يجد مفتاحًا في القاموس.
  print('\n[7] ترجمة نصوص القوالب');
  final missing = <String>{};
  for (final kind in DocKind.values) {
    for (final field in DocCatalog.fieldsOf(kind)) {
      if (!field.hasText) continue;
      final text = field.defaultText.trim();
      if (text.isNotEmpty && !kEnglish.containsKey(text)) {
        missing.add('${kind.name}: $text');
      }
    }
  }
  check('[7] لا نصّ قالبه عربي في مستند إنجليزي', missing.join(' | '), '');

  // ─── [8] التحكّم الصريح في شاشة الإعدادات ──────────────────────────
  //
  // العيب الذي يمنعه: أن يعمل المحرّك بالإنجليزية بينما **لا يجد المستخدم
  // زرًّا يغيّر به اللغة** (كان الخيار سطرًا منسدلًا مدفونًا)، أو أن يوجد
  // تحكّمان لنفس المفتاح فيظهر أحدهما بقيمة غير الأخرى.
  print('\n[8] التحكّم في الإعدادات');
  final sections = _code('lib/view/screen/settings/settings_sections.dart');
  check(
    '[8] بطاقة لغة الطباعة موجودة',
    sections.contains('Widget docLanguageCard('),
    true,
  );
  check(
    '[8] البطاقة تكتب مفتاح اللغة الصحيح',
    RegExp(r'updateSetting\(\s*AppConstants\.settingDocLanguage').hasMatch(sections),
    true,
  );
  check(
    '[8] الأزرار مشتقّة من النوع لا من نصوص مكرّرة',
    sections.contains('for (final lang in DocLanguage.values)'),
    true,
  );
  check(
    '[8] لا تحكّمان لنفس المفتاح (السطر المنسدل مُستبعَد)',
    sections.contains('o.key != AppConstants.settingDocLanguage'),
    true,
  );
  final pages = _code('lib/view/screen/settings/settings_pages.dart');
  check(
    '[8] البطاقة في صفحتَي الفواتير والطباعة',
    RegExp(r'docLanguageCard\(c\)').allMatches(pages).length >= 2,
    true,
  );
  check(
    '[8] معاينة الفاتورة تتبع لغة الطباعة لا لغة الواجهة',
    sections.contains('kEnglish[arabic] ?? arabic'),
    true,
  );

  print('\n' + '═' * 64);
  print(_fail == 0 ? '✓ كل الفحوص ناجحة ($_ok)' : '✗ فشل $_fail من ${_ok + _fail}');
  print('═' * 64);
  if (_fail != 0) exitCode = 1;
}
