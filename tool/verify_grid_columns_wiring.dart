// حرس ربط «عدد أعمدة الأصناف» — يمنع أن يعود زرًّا لا يغيّر الشبكة.
//
// **العيب الصامت الذي يحرسه:** كان `gridColumns.value` يُقرأ داخل
// `LayoutBuilder.builder`، أي في طور التخطيط بعد أن يكون `Obx` قد حسم
// اشتراكاته. فكان الاختيار يُحفظ ويُحدّث الزرّ، **ولا تُعاد الشبكة** أبدًا.
// الفحص يضمن أن القراءة في جسم `Obx` قبل `LayoutBuilder` وأن القيمة المقروءة
// هي المستخدمة في `crossAxisCount`.
//
// التشغيل: dart run tool/verify_grid_columns_wiring.dart
import 'dart:io';

import 'package:laundry/config/constants.dart';
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
  print('حرس ربط عدد أعمدة الأصناف');
  print('═' * 62);

  // ─── [1] السجلّ والإعداد ────────────────────────────────────────────
  print('\n[1] الإعداد');
  final opt = SettingOptions.homeGridColumns;
  final choices = opt.choices ?? const <String>[];
  check('[1] المفتاح في الثوابت', opt.key, AppConstants.settingHomeGridColumns);
  check('[1] النوع اختياري', opt.kind, SettingKind.choice);
  check('[1] «تلقائي» أول خيار', choices.isEmpty ? '' : choices.first, 'auto');
  check('[1] الخيارات 2..6', choices.skip(1).join(','), '2,3,4,5,6');
  check('[1] الافتراضي تلقائي', opt.defaultValue, 'auto');
  check(
    '[1] مُدرَج في `SettingOptions.all`',
    SettingOptions.all.any((o) => o.key == opt.key),
    true,
  );

  // ─── [2] المتحكّم ───────────────────────────────────────────────────
  print('\n[2] المتحكّم');
  final controller =
      File('lib/controller/addeditcategorycontroller.dart').readAsStringSync();
  check(
    '[2] `gridColumns` حالة تفاعلية RxInt',
    RegExp(r'final\s+RxInt\s+gridColumns').hasMatch(controller),
    true,
  );
  final save = controller.indexOf('AppConstants.settingHomeGridColumns');
  final assign = controller.indexOf('gridColumns.value = safe');
  check('[2] الحفظ قبل تحديث الحالة', save >= 0 && assign > save, true);
  check(
    '[2] التغيير يقبل «تلقائي» (صفر)',
    controller.contains('columns <= 0 ? 0 : columns.clamp(2, 6)'),
    true,
  );

  // ─── [3] الشاشة الرئيسية — سبب العيب الأصلي ─────────────────────────
  print('\n[3] اشتراك الشبكة');
  final home = File('lib/view/screen/home.dart').readAsStringSync();
  final read = home.indexOf('catController.gridColumns.value');
  final layout = home.indexOf('return LayoutBuilder(');
  final obx = home.indexOf('child: Obx(() {');
  check(
    '[3] الزرّ مُدرَج فعلًا',
    home.contains('const HomeGridColumnsMenu()'),
    true,
  );
  check(
    '[3] الشاشة تستورد الودجة',
    home.contains('widget/home/home_grid_columns_menu.dart'),
    true,
  );
  check('[3] القراءة داخل جسم Obx', obx >= 0 && read > obx, true);
  check(
    '[3] القراءة **قبل** LayoutBuilder (لا في طور التخطيط)',
    read >= 0 && layout > read,
    true,
  );
  final layoutBlock = layout < 0 ? home : home.substring(layout);
  check(
    '[3] لا قراءة للأعمدة داخل builder',
    layoutBlock.contains('gridColumns.value'),
    false,
  );
  check(
    '[3] القيمة المقروءة هي المستخدمة في الشبكة',
    home.contains('configuredColumns > 0'),
    true,
  );
  check(
    '[3] `crossAxisCount` يأخذ المحسوب',
    home.contains('crossAxisCount: cols'),
    true,
  );

  // ─── [4] الطباعة: نسخة تُبنى بهوامش الطابعة ────────────────────────
  print('\n[4] الطباعة');
  final printer =
      File('lib/services/printer/printer_service.dart').readAsStringSync();
  check(
    '[4] `printPdf` يقبل إعادة التوليد',
    printer.contains('PdfRebuilder? rebuild'),
    true,
  );
  check(
    '[4] `onLayout` يستعمل إعادة التوليد',
    printer.contains('_layoutCallback(bytes, rebuild)'),
    true,
  );
  check(
    '[4] فشل إعادة التوليد يرجع الأصل',
    printer.contains('return bytes;'),
    true,
  );
  final invoiceService =
      File(
        'lib/services/invoice/invoice_output_service.dart',
      ).readAsStringSync();
  check(
    '[4] خدمة الإخراج تمرّر إعادة التوليد للفاتورة',
    invoiceService.contains('rebuild: rebuildInvoice'),
    true,
  );
  check(
    '[4] خدمة الإخراج تمرّرها لورقة المغسلة',
    invoiceService.contains('rebuild: rebuildSlip'),
    true,
  );
  final invoiceGen =
      File('lib/core/services/preparePDF.dart').readAsStringSync();
  check(
    '[4] مولّد الفاتورة يستخدم تخطيط الطباعة',
    invoiceGen.contains('PrintLayout.fromData(data[PrintLayout.dataKey])'),
    true,
  );
  check(
    '[4] المولّد يبني الصفحة عبر `pageFormat`',
    invoiceGen.contains('PrintLayout.pageFormat('),
    true,
  );

  // ─── النتيجة ────────────────────────────────────────────────────────
  print('\n' + '─' * 62);
  print('نجح: $_ok · فشل: $_fail');
  if (_fail > 0) exit(1);
}
