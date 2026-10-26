// حرس المرحلة 7: الواجهة مرتبطة بالمفاتيح الصريحة.
//
// **العيب الذي يمنعه:** العودة إلى الخصائص القديمة (`canDeleteInvoice`)
// لأنها «أقصر». المشكلة ليست الطول بل **أن الاسم القديم لا يحمل المفتاح**:
// مَن يقرأ `canDeleteInvoice` لا يعرف أن المفتاح `invoice.delete` فيقع في
// خطأ حرف واحد عند البحث في القاعدة. الثابت الصريح يجعل التحليل النوعي
// يكشف أي انزلاق.
//
// التشغيل: dart run tool/verify_ui_wiring.dart

import 'dart:io';

int _pass = 0;
int _fail = 0;
final List<String> _errs = <String>[];

void check(String name, bool ok, [String? detail]) {
  if (ok) {
    _pass++;
  } else {
    _fail++;
    _errs.add('✗ $name${detail == null ? '' : ' — $detail'}');
  }
}

void main() {
  print('═══ حرس المرحلة 7: ربط الواجهة بالمفاتيح ═══\n');

  // ── [1] لا استخدام للخصائص القديمة خارج الخدمة ───────────────────
  //
  // الخصائص تبقى **معرَّفة** في `PermissionService` (توافق خلفي للكود
  // الخارجي)، لكن لا موضع في `lib/` يستعملها — كلها تمرّ بالثابت الصريح.
  final legacy = RegExp(r'PermissionService\.can[A-Z]\w*');
  final offenders = <String>[];
  final explicitSites = <String>[];

  for (final f in Directory('lib').listSync(recursive: true)) {
    if (f is! File || !f.path.endsWith('.dart')) continue;
    final p = f.path.replaceAll(r'\', '/');
    if (p.endsWith('services/permission/permission_service.dart')) continue;
    final src = f.readAsStringSync();
    for (final m in legacy.allMatches(src)) {
      offenders.add('$p: ${m.group(0)}');
    }
    final n = RegExp(r'PermissionService\.can\(PermissionKeys\.\w+\)')
        .allMatches(src)
        .length;
    if (n > 0) explicitSites.add('$p ($n)');
  }

  print('[1] لا خصائص قديمة في الواجهة');
  check('لا موضع يستعمل خاصية قديمة', offenders.isEmpty,
      offenders.take(5).join(' · '));
  check('الواجهة تستعمل المفاتيح الصريحة', explicitSites.isNotEmpty,
      '${explicitSites.length} ملفًا');

  // ── [2] المفاتيح المستعملة كلها معروفة ───────────────────────────
  //
  // ⚠️ **نُسقِط أسطر التعليق**: التوثيق نفسه يكتب `PermissionKeys.x`
  // كمثال، ولو فُحص كنصّ لعُدّ مفتاحًا مجهولًا. الفحص يستهدف الكود وحده.
  print('\n[2] المفاتيح معروفة في الكتالوج');
  final catalog = File('lib/services/permission/permission_catalog.dart')
      .readAsStringSync();
  final knownConsts = RegExp(r'static const String (\w+) = ')
      .allMatches(catalog)
      .map((m) => m.group(1)!)
      .toSet();

  /// يُزيل أسطر التعليق (// و /// و * ) من نصّ Dart.
  String stripComments(String src) => src
      .split('\n')
      .where((l) {
        final t = l.trimLeft();
        return !t.startsWith('//') && !t.startsWith('*') && !t.startsWith('/*');
      })
      .join('\n');

  final unknown = <String>[];
  for (final f in Directory('lib').listSync(recursive: true)) {
    if (f is! File || !f.path.endsWith('.dart')) continue;
    final src = stripComments(f.readAsStringSync());
    for (final m in RegExp(r'PermissionKeys\.(\w+)').allMatches(src)) {
      final name = m.group(1)!;
      // `PermissionKeys._()` هو **مُنشئ خاص** يمنع إنشاء الحزمة — ليس مفتاحًا.
      if (name == '_') continue;
      if (!knownConsts.contains(name)) {
        unknown.add('${f.path.replaceAll(r'\', '/')}: $name');
      }
    }
  }
  check('كل مفتاح مستعمل معرَّف في الكتالوج', unknown.isEmpty,
      unknown.take(6).join(' · '));

  // ── [3] مفتاح صريح لا مجاوره في المواضع الحسّاسة ─────────────────
  //
  // **لماذا؟** لأن `canManageShifts` كان يُترجَم إلى `shiftOpen`، لكن
  // إغلاق الوردية مفتاح آخر. ولو فُتح المسار بمفتاح مجاور لعمل من لا يملك
  // الإغلاق. هذا الفحص يُثبِّت **التمييز** في الواجهة كي لا يُدمَج لاحقًا.
  print('\n[3] التمييز بين المفاتيح المتجاورة');
  final files = <String, String>{
    for (final p in <String>[
      'lib/view/widget/home/customdrawer.dart',
      'lib/view/screen/home.dart',
      'lib/view/screen/settings/settings_screen.dart',
      'lib/view/screen/backup/backup_screen.dart',
      'lib/view/screen/discount/discounts_screen.dart',
      'lib/view/widget/invoice/custompayinvoice.dart',
    ])
      p: File(p).readAsStringSync(),
  };

  check('الورديات في القائمة: فتح وإغلاق كمفتاحين',
      files['lib/view/widget/home/customdrawer.dart']!
              .contains('PermissionKeys.shiftOpen') &&
          (File('lib/controller/shift_controller.dart').readAsStringSync())
              .contains('PermissionKeys.shiftClose'));
  check('الفاتورة: البيع الآجل مفتاح مستقل',
      files['lib/view/widget/invoice/custompayinvoice.dart']!
          .contains('PermissionKeys.invoiceSellOnCredit'));
  check('الفاتورة: الخصم مفتاح مستقل',
      files['lib/view/widget/invoice/custompayinvoice.dart']!
          .contains('PermissionKeys.invoiceDiscountApply'));

  // ── [4] الاستيراد موجود حيث يُستعمل المفتاح ───────────────────────
  print('\n[4] الاستيراد');
  for (final e in files.entries) {
    if (!e.value.contains('PermissionKeys.')) continue;
    check('${e.key.split('/').last} يستورد الكتالوج',
        e.value.contains('permission_catalog.dart'));
  }

  // ── [5] الأزرار الخطرة لا تُعرض بلا صلاحية ──────────────────────
  //
  // **العيب الذي يمنعه:** زر «حذف» ظاهر لكل من يفتح الشاشة، ثم يُرفَض
  // عند الضغط (أو يُنفَّذ قبل أن تُشحَن الخدمة بالحرس). العرض نفسه وعدٌ
  // يجب ألّا يُقطَع.
  print('\n[5] إخفاء الأزرار الخطرة');
  final gated = <String, ({String file, String key})>{
    'حذف الصنف': (
      file: 'lib/view/screen/deletecategory.dart',
      key: 'PermissionKeys.categoryManage',
    ),
    'حذف الزبون': (
      file: 'lib/view/widget/customer/customdeletecustomer.dart',
      key: 'PermissionKeys.customerDelete',
    ),
    'تفريغ سلة الفاتورة': (
      file: 'lib/view/widget/invoice/customremoveinvoce.dart',
      key: 'PermissionKeys.invoiceDraft',
    ),
    'حذف المصروف': (
      file: 'lib/view/screen/expenses_screen.dart',
      key: 'PermissionKeys.expenseManage',
    ),
  };

  for (final e in gated.entries) {
    final src = File(e.value.file).readAsStringSync();
    // نُزيل **كل** المسافات وعلامات السطر الجديد معًا: `can(` قد تكون على
    // سطر والمفتاح على تاليه، أو متّصلين. المقارنة بعد التطبيع تنجح في
    // الحالتين.
    final flat = src.replaceAll(RegExp(r'\s+'), '');
    final needle =
        'PermissionService.can(${e.value.key})'.replaceAll(' ', '');
    check('${e.key} محروس في ${e.value.file.split('/').last}',
        flat.contains(needle));
  }

  // التمييز الحرج: زر تفريغ السلة **لا** يُحرَس بـ`invoice.delete`
  // (المحفوظ لمحو فاتورة صادرة فعلًا) — الخلط بينهما يعطّل تفريغ السلة
  // على من لا يملك المحو، وهو فعل غير خطِر.
  final removeInv =
      File('lib/view/widget/invoice/customremoveinvoce.dart').readAsStringSync();
  check('تفريغ السلة ليس بحرس invoice.delete',
      !removeInv.contains('PermissionKeys.invoiceDelete'));

  print('\n═══ النتيجة: نجح $_pass · فشل $_fail ═══');
  for (final e in _errs) {
    print(e);
  }
  if (_fail > 0) exit(1);
  print('✅ كل الفحوص نجحت');
}
