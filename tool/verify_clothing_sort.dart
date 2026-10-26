// حرس ترتيب الأصناف — يمنع أن يصير «خيار الفرز» زرًّا لا يغيّر شيئًا.
//
// الخطر الحقيقي هنا **صامت** كسابقه: قائمة ترتيب في الشاشة لا يقابلها مفتاح
// في `settings` ⇒ الاختيار يبدو ناجحًا ويعود للافتراضي عند إعادة الفتح؛ أو
// مفتاح في `settings` لا يقابله نمط في السجلّ ⇒ `choice` لا يُطبَّع فتُحفظ
// قيمة مرفوضة. لذلك كل فحص يقارن **السجلّين** أحدهما بالآخر.
//
// التشغيل: dart run tool/verify_clothing_sort.dart
import 'dart:io';

import 'package:laundry/config/constants.dart';
import 'package:laundry/services/catalog/clothing_sort.dart';
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
  print('حرس ترتيب الأصناف');
  print('═' * 62);

  final all = ClothingSort.all;

  // ─── [1] سلامة السجلّ ───────────────────────────────────────────────
  print('\n[1] سلامة السجلّ');
  check('[1] السجلّ غير فارغ', all.isNotEmpty, true);
  check('[1] المفاتيح فريدة', all.map((s) => s.key).toSet().length, all.length);
  check('[1] التسميات فريدة', all.map((s) => s.label).toSet().length, all.length);
  // الوصف المكرّر يجعل بندين متطابقين في القائمة (سعر صاعد وسعر نازل كانا
  // يحملان «سعر الغسيل والكوي العادي» معًا) ⇒ المستخدم لا يفرّق بينهما.
  check(
    '[1] الأوصاف فريدة',
    all.map((s) => s.description).toSet().length,
    all.length,
  );
  check(
    '[1] لا مفتاح فارغ',
    all.every((s) => s.key.trim().isNotEmpty && s.key == s.key.trim()),
    true,
  );
  check(
    '[1] لا تسمية أو وصف فارغ',
    all.every((s) => s.label.trim().isNotEmpty && s.description.trim().isNotEmpty),
    true,
  );
  check(
    '[1] كل المفاتيح لاتينية صغيرة بشرطة سفلية',
    all.every((s) => RegExp(r'^[a-z][a-z0-9_]*$').hasMatch(s.key)),
    true,
  );
  check(
    '[1] `keys` يطابق السجلّ',
    ClothingSort.keys.join(','),
    all.map((s) => s.key).join(','),
  );
  check(
    '[1] `labels` يطابق السجلّ',
    ClothingSort.labels.values.join('|'),
    all.map((s) => s.label).join('|'),
  );

  // ─── [2] الافتراضي = سلوك ما قبل الميزة ─────────────────────────────
  print('\n[2] الافتراضي');
  final def = ClothingSort.byKey(ClothingSort.defaultKey);
  check('[2] مفتاح الافتراضي موجود', def.key, ClothingSort.defaultKey);
  check('[2] الافتراضي أبجدي صاعد', def.key, 'name_asc');
  check('[2] `byKey(null)` يعطي الافتراضي', ClothingSort.byKey(null).key, def.key);
  check('[2] `byKey('')` يعطي الافتراضي', ClothingSort.byKey('').key, def.key);
  check(
    '[2] مفتاح مجهول يعطي الافتراضي ولا يرمي',
    ClothingSort.byKey('nope_xyz').key,
    def.key,
  );
  check(
    '[2] مفتاح بمسافات زائدة يُقبل',
    ClothingSort.byKey('  name_desc  ').key,
    'name_desc',
  );

  // ─── [3] بناء الاستعلام ─────────────────────────────────────────────
  print('\n[3] الاستعلام');
  final base = 'SELECT * FROM "clothing" WHERE "is_active" = 1';
  check('[3] بدون فرز ⇒ بلا ORDER BY', ClothingSort.unsorted.query, base);
  check(
    '[3] لا ORDER BY في أي نمط غير مجمَّع غير `unsorted`',
    all
        .where((s) => !s.grouped && s.key != 'unsorted')
        .every((s) => s.query.contains('ORDER BY')),
    true,
  );
  check(
    '[3] كل استعلام يبدأ بالجدول الصحيح',
    all.every((s) => s.query.contains('"clothing"')),
    true,
  );
  check(
    '[3] كل استعلام يفلتر غير النشط (غير المجمَّع)',
    all
        .where((s) => !s.grouped)
        .every((s) => s.query.contains('"is_active" = 1')),
    true,
  );
  check(
    '[3] المجمَّع يستخدم LEFT JOIN لا JOIN',
    ClothingSort.bestSelling.query.contains('LEFT JOIN "invoice_items"'),
    true,
  );
  check(
    '[3] المجمَّع يجمّع على معرّف الصنف',
    ClothingSort.bestSelling.query.contains('GROUP BY c."clothing_id"'),
    true,
  );
  check(
    '[3] المجمَّع يستخدم COALESCE ليشمل غير المبيع',
    ClothingSort.bestSelling.query.contains('COALESCE(SUM(i."qty"), 0)'),
    true,
  );
  check(
    '[3] المجمَّع يفلتر الصنف النشط',
    ClothingSort.bestSelling.query.contains('c."is_active" = 1'),
    true,
  );
  check(
    '[3] لا استعلام مجمَّع في الأنماط العادية',
    all.where((s) => s.grouped).length,
    1,
  );
  // الترتيب الأبجدي يجب أن يكون **بلا COLLATE NOCASE**: لا أثر لها في العربية
  // لكنها تكسر تطابق الحالة في أسماء لاتينية مختلطة ⇒ نتائج غير متوقعة.
  check(
    '[3] لا COLLATE في أي استعلام',
    all.every((s) => !s.query.toUpperCase().contains('COLLATE')),
    true,
  );
  check(
    '[3] كل سعر يُرتَّب على عمود السعر المعروض في البطاقة',
    ClothingSort.priceAsc.query.contains('"normal_washing_and_ironing_price"'),
    true,
  );
  check(
    '[3] الصاعد والنازل على العمود نفسه',
    ClothingSort.priceAsc.query.contains('ASC') &&
        ClothingSort.priceDesc.query.contains('DESC'),
    true,
  );

  // ─── [4] التطابق مع خيار الإعدادات ──────────────────────────────────
  print('\n[4] التطابق مع `settings`');
  final opt = SettingOptions.clothingSort;
  final choices = opt.choices ?? const <String>[];
  final choiceLabels = opt.choiceLabels ?? const <String, String>{};
  check('[4] المفتاح في الثوابت', opt.key, AppConstants.settingClothingSort);
  check('[4] النوع اختياري', opt.kind, SettingKind.choice);
  check('[4] المجموعة نقطة البيع', opt.group, SettingGroups.pos);
  check('[4] القيمة الافتراضية = مفتاح الافتراضي', opt.defaultValue, def.key);
  check(
    '[4] الخيارات تطابق مفاتيح السجلّ بالترتيب',
    choices.join(','),
    ClothingSort.keys.join(','),
  );
  check(
    '[4] التسميات تطابق تسميات السجلّ',
    choices.map((c) => choiceLabels[c]).join('|'),
    all.map((s) => s.label).join('|'),
  );
  check(
    '[4] لا خيار بلا تسمية',
    choices.every((c) => (choiceLabels[c] ?? '').trim().isNotEmpty),
    true,
  );
  check(
    '[4] كل خيار قابل للتطبيع (لا يُرفض)',
    choices.every((c) => normalizeValue(opt, c) == c),
    true,
  );
  check(
    '[4] الخيار مُدرَج في `SettingOptions.all`',
    SettingOptions.all.any((o) => o.key == opt.key),
    true,
  );
  check(
    '[4] المفتاح مُدرَج في مجموعة `pos`',
    SettingOptions.ofGroup(SettingGroups.pos).any((o) => o.key == opt.key),
    true,
  );
  check(
    '[4] قيمة تالفة تُطبَّع إلى الافتراضي',
    normalizeValue(opt, 'garbage'),
    opt.defaultValue,
  );

  // ─── [5] لا ترتيب مكتوب خارج السجلّ ────────────────────────────────
  print('\n[5] مصدر واحد للترتيب');
  final controller =
      File('lib/controller/addeditcategorycontroller.dart').readAsStringSync();
  check(
    '[5] المتحكّم يستخدم استعلام النمط لا SQL مكتوبًا',
    controller.contains('_db.readData(current.query)'),
    true,
  );
  check(
    '[5] لا `ORDER BY clothing_name` مكتوب يدويًا',
    controller.contains('ORDER BY clothing_name'),
    false,
  );
  check(
    '[5] لا `SELECT * FROM "clothing"` مكتوب يدويًا',
    controller.contains('SELECT * FROM "clothing"'),
    false,
  );
  check(
    '[5] تغيير الترتيب يحفظ في الإعدادات',
    controller.contains('AppConstants.settingClothingSort'),
    true,
  );
  check(
    '[5] تغيير الترتيب يعيد الجلب من القاعدة',
    controller.contains('await loadClothing();'),
    true,
  );

  // لا استعلام آخر على `clothing` يفرض ترتيبًا خاصًا به في أي مكان.
  final offenders = <String>[];
  for (final f in Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))) {
    final src = f.readAsStringSync();
    if (src.contains('ORDER BY clothing_name') ||
        src.contains('ORDER BY "clothing_name"')) {
      offenders.add(f.path);
    }
  }
  check('[5] لا ملفّ آخر يفرض ترتيبًا على الأصناف', offenders.join(','), '');

  // ─── [6] الواجهة ────────────────────────────────────────────────────
  print('\n[6] الواجهة');
  final home = File('lib/view/screen/home.dart').readAsStringSync();
  final menu =
      File('lib/view/widget/home/clothing_sort_menu.dart').readAsStringSync();
  check(
    '[6] الزرّ مُدرَج فعلًا في شجرة شاشة البيع (لا تعريفًا معلَّقًا)',
    home.contains('const ClothingSortMenu(),'),
    true,
  );
  check(
    '[6] شاشة البيع تستورد الودجة',
    home.contains('widget/home/clothing_sort_menu.dart'),
    true,
  );
  check(
    '[6] القائمة تُبنى من السجلّ لا من قائمة مكتوبة',
    menu.contains('ClothingSort.all.map'),
    true,
  );
  check(
    '[6] الاختيار يمرّ بالمتحكّم (حفظ + جلب)',
    menu.contains('catController.changeSort(next)'),
    true,
  );
  check('[6] التسمية المعروضة من السجلّ', menu.contains('current.label'), true);
  check(
    '[6] لا تسمية نمط مكتوبة يدويًا في الواجهة',
    RegExp(r"'الاسم:|'بدون فرز'|'الأكثر مبيعًا'").hasMatch(menu),
    false,
  );
  check(
    '[6] لكل نمط مفتاح اختبار من مفاتيح السجلّ',
    menu.contains('itemKeyOf(s.key)'),
    true,
  );

  // ─── النتيجة ────────────────────────────────────────────────────────
  print('\n' + '─' * 62);
  print('نجح: $_ok · فشل: $_fail');
  if (_fail > 0) exit(1);
}
