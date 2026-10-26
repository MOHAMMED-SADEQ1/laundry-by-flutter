// حرس خطوط الطباعة — يمنع أن يصير «اختيار الخطّ» زرًّا لا يطبع شيئًا.
//
// الخطر الحقيقي في هذه الميزة **صامت**: مفتاح خطّ في `settings` لا يقابله
// ملفّ محزوم، أو عائلة في `pubspec` لا تطابق مسار السجلّ ⇒ تُطبع الفاتورة
// بخطّ آخر بلا أي خطأ. لذلك كل فحص هنا يقرأ **القرص** لا النوايا.
//
// التشغيل: dart run tool/verify_print_font.dart
import 'dart:io';

import 'package:laundry/config/constants.dart';
import 'package:laundry/services/pdf/print_font.dart';
import 'package:laundry/services/settings/setting_option.dart';

int _ok = 0;
int _fail = 0;

void check(String name, Object? got, Object? expected) {
  final pass = got == expected;
  if (pass) {
    _ok++;
    print('  ✓ $name');
  } else {
    _fail++;
    print('  ✗ $name  → got=$got expected=$expected');
  }
}

void main() {
  print('═' * 62);
  print('حرس خطوط الطباعة');
  print('═' * 62);

  final all = PrintFonts.all;

  // ─── [1] سلامة السجلّ ───────────────────────────────────────────────
  print('\n[1] سلامة السجلّ');
  check('[1] لا سجلّ فارغ', all.isNotEmpty, true);
  check(
    '[1] المفاتيح فريدة',
    all.map((f) => f.key).toSet().length,
    all.length,
  );
  check(
    '[1] التسميات فريدة',
    all.map((f) => f.label).toSet().length,
    all.length,
  );
  check(
    '[1] عائلات Flutter فريدة',
    all.map((f) => f.family).toSet().length,
    all.length,
  );
  check(
    '[1] لا تسمية أو ملاحظة فارغة',
    all.where((f) => f.label.trim().isEmpty || f.note.trim().isEmpty).length,
    0,
  );
  check(
    '[1] كل مفتاح بصيغة snake_case لاتينية',
    all.where((f) => !RegExp(r'^[a-z0-9_]+$').hasMatch(f.key)).length,
    0,
  );

  // ─── [2] الملفّات موجودة وحقيقية ────────────────────────────────────
  print('\n[2] الملفّات على القرص');
  for (final f in all) {
    final file = File(f.asset);
    check('[2] ${f.key}: الملفّ موجود', file.existsSync(), true);
    if (!file.existsSync()) continue;
    final bytes = file.readAsBytesSync();
    check('[2] ${f.key}: حجم معقول', bytes.length > 20000, true);
    // TTF حقيقي = 00 01 00 00 (glyf) أو 'true'. woff2 يبدأ بـ'wOF2' ويرفضه
    // محلّل حزمة `pdf` — وهذا ما يحدث لو حُمّل الخطّ من رابط ويب خاطئ.
    final magic = String.fromCharCodes(bytes.sublist(0, 4));
    final isTtf =
        (bytes[0] == 0 && bytes[1] == 1 && bytes[2] == 0 && bytes[3] == 0) ||
        magic == 'true';
    check('[2] ${f.key}: TTF صالح (لا woff2)', isTtf, true);
  }

  // ─── [3] pubspec يحزمها ويسجّل عائلاتها ────────────────────────────
  print('\n[3] pubspec.yaml');
  final pubspec = File('pubspec.yaml').readAsStringSync();
  // 🚨 إعلان مجلد في `assets:` **لا يشمل مجلداته الفرعية** في Flutter.
  // فوجود `assets/fonts/` لا يحزم `assets/fonts/Noto/…` — وهذا عيب صامت:
  // البناء ينجح ويُطبع الخطأ عند العميل. لذلك نتحقّق من **مجلد كل خطّ**.
  for (final f in all) {
    final dir = f.asset.substring(0, f.asset.lastIndexOf('/') + 1);
    check('[3] ${f.key}: مجلد الأصل مُعلَن ($dir)', pubspec.contains('- $dir'), true);
  }
  for (final f in all) {
    check('[3] ${f.key}: المسار مذكور في pubspec', pubspec.contains(f.asset), true);
    // العائلة يجب أن تُعلَن باسمها الصحيح ومسارها نفسه — وإلا ظهرت المعاينة
    // في الواجهة بخطّ آخر غير الذي سيُطبع.
    final block = RegExp(
      r'-\s*family:\s*' + RegExp.escape(f.family) + r'\s*\n\s*fonts:\s*\n\s*-\s*asset:\s*(\S+)',
    ).firstMatch(pubspec);
    check('[3] ${f.key}: العائلة ${f.family} مربوطة بمسارها', block?.group(1), f.asset);
  }

  // ─── [4] الافتراضي لا يتغيّر بصمت ───────────────────────────────────
  print('\n[4] الخطّ الافتراضي');
  check('[4] مفتاح الافتراضي ثابت', PrintFonts.defaultKey, 'al_mohanad');
  check(
    '[4] الثابت في AppConstants مطابق',
    AppConstants.printFontDefault,
    PrintFonts.defaultKey,
  );
  check('[4] الافتراضي موجود في السجلّ', PrintFonts.isKnown(PrintFonts.defaultKey), true);
  check(
    '[4] الافتراضي أول السجلّ (يظهر أولًا في الواجهة)',
    all.first.key,
    PrintFonts.defaultKey,
  );
  check(
    '[4] الافتراضي هو نفس ملفّ النسخة السابقة',
    PrintFonts.byKey(PrintFonts.defaultKey).asset,
    'assets/fonts/Noto/AL-Mohanad.ttf',
  );

  // ─── [5] الإعداد والواجهة يقرآن من السجلّ نفسه ─────────────────────
  print('\n[5] ربط الإعداد بالسجلّ');
  final opt = SettingOptions.printFont;
  check('[5] المفتاح المحفوظ مطابق', opt.key, AppConstants.settingPrintFont);
  check('[5] النوع انتقائي', opt.isChoice, true);
  check('[5] القيمة الافتراضية = الافتراضي', opt.defaultValue, PrintFonts.defaultKey);
  check(
    '[5] الخيارات = مفاتيح السجلّ بالترتيب',
    (opt.choices ?? const <String>[]).join(','),
    all.map((f) => f.key).join(','),
  );
  for (final f in all) {
    check(
      '[5] ${f.key}: تسمية الإعداد = تسمية السجلّ',
      opt.labelOfChoice(f.key),
      f.label,
    );
  }
  check(
    '[5] كل خيار في الإعداد معروف في السجلّ',
    (opt.choices ?? const <String>[]).where((k) => !PrintFonts.isKnown(k)).length,
    0,
  );

  // ─── [6] التوصيات (حراري / ورق) ────────────────────────────────────
  print('\n[6] التوصيات');
  check('[6] توجد خطوط للحراري', PrintFonts.forThermal.isNotEmpty, true);
  check('[6] توجد خطوط للورق', PrintFonts.forPaper.isNotEmpty, true);
  check(
    '[6] كل خطّ له استخدام محدَّد',
    all.where((f) => !f.thermal && !f.paper).length,
    0,
  );
  check(
    '[6] الخفيف للحراري فقط (isLight)',
    PrintFonts.forThermal.where((f) => f.isLight).isNotEmpty,
    true,
  );
  // تسمية الاستخدام لا تكون فارغة ولا «زخرفي» لخطّ مُوصى به.
  check(
    '[6] تسمية الاستخدام متّسقة',
    all.where((f) => f.usageLabel.trim().isEmpty).length,
    0,
  );

  // ─── [7] الخطوط المستثناة (بدليل مقاس) ─────────────────────────────
  print('\n[7] المستثنى');
  // TRAD.ttf يرسم مربّعات .notdef (ترميز Windows-1256 لا Unicode)،
  // وDTHULUTH خطّ عرض تُبتر حروفه رأسيًا — كلاهما مُثبت برستر في
  // `build/probe/font_compare.pdf`. لا يجوز إضافتهما للاختيار.
  check('[7] TRAD ليس خيار طباعة', PrintFonts.isKnown('trad'), false);
  check('[7] DTHULUTH ليس خيار طباعة', PrintFonts.isKnown('dthuluth'), false);
  check(
    '[7] لا مسار TRAD في السجلّ',
    all.any((f) => f.asset.contains('TRAD')),
    false,
  );
  check(
    '[7] لا مسار DTHULUTH في السجلّ',
    all.any((f) => f.asset.contains('DTHULUTH')),
    false,
  );

  // ─── [8] لا مسار خطّ مكتوب في الكود ────────────────────────────────
  print('\n[8] مصدر واحد');
  final ctrl = File('lib/controller/printInvoicecontroller.dart').readAsStringSync();
  check(
    '[8] لا مسار خطّ مكتوب في متحكّم الطباعة',
    RegExp(r'assets/fonts/').hasMatch(ctrl),
    false,
  );
  check(
    '[8] المتحكّم يستعمل خدمة الخطوط',
    ctrl.contains('PrintFontService.resolve'),
    true,
  );
  check(
    '[8] لا استيراد لـpw.Font.ttf المباشر في المتحكّم',
    ctrl.contains('pw.Font.ttf'),
    false,
  );
  final svc = File('lib/services/pdf/print_font_service.dart').readAsStringSync();
  check('[8] الخدمة تحمّل من asset السجلّ', svc.contains('font.asset'), true);
  check('[8] الخدمة لا ترمي على خطّ تالف (بديل)', svc.contains('rethrow'), true);
  check(
    '[8] الخدمة تُخزّن بمفتاح الخطّ (لا متغيّر واحد)',
    svc.contains('_cache[font.key]'),
    true,
  );
  final settings = File('lib/controller/settings/settings_controller.dart').readAsStringSync();
  check(
    '[8] تغيير الإعداد يُفرّغ الخطّ المحمَّل',
    settings.contains('invalidateFont()'),
    true,
  );
  check(
    '[8] تغيير الإعداد يُعيد التحميل فورًا',
    settings.contains('ensureAssets()'),
    true,
  );

  print('\n' + '─' * 62);
  print('نجح: $_ok · فشل: $_fail');
  if (_fail == 0) {
    print('✅ كل الفحوص نجحت');
  } else {
    print('❌ فشل');
    exitCode = 1;
  }
}
