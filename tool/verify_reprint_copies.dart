// حرس «عدد نسخ إعادة الطباعة» من سجل الفواتير.
//
// **العيب الصامت الذي يحرسه:** إضافة الحوار ثم إهمال قيمته في الطريق إلى
// `deliverBundle`، فتظل الطباعة نسخة واحدة وتبدو الميزة موجودة. أو أن يكتب
// الحوار `invoice_copies` فيتغيّر سلوك الطباعة التلقائية عند البيع لمجرد
// إعادة طباعة عرَضية.
//
// التشغيل: dart run tool/verify_reprint_copies.dart
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
  print('حرس عدد نسخ إعادة الطباعة');
  print('═' * 62);

  // ─── [1] الإعداد المرجعي ────────────────────────────────────────────
  print('\n[1] الإعداد');
  final option = SettingOptions.invoiceCopies;
  check('[1] المفتاح', option.key, AppConstants.settingInvoiceCopies);
  check('[1] الحد الأدنى', option.min, 1);
  check('[1] الحد الأقصى', option.max, 5);

  // ─── [2] خدمة الإخراج ───────────────────────────────────────────────
  print('\n[2] خدمة الإخراج');
  final service = File(
    'lib/services/invoice/invoice_output_service.dart',
  ).readAsStringSync();
  check(
    '[2] `deliverBundle` تقبل عددًا صريحًا',
    service.contains('int? copies'),
    true,
  );
  check(
    '[2] القيمة الصريحة تُقصّ 1..5',
    service.contains('copies.clamp(1, 5)'),
    true,
  );
  check(
    '[2] الغياب يعود إلى الإعداد المحفوظ',
    service.contains('copies == null ? _invoiceCopies()'),
    true,
  );
  check(
    '[2] حلقة الطباعة تستخدم العدد المحسوب',
    service.contains('copy <= copyCount'),
    true,
  );
  check(
    '[2] اسم المهمة يذكر الرقم/الإجمالي',
    RegExp(
      r'فاتورة #\{0\} \(\{1\}/\{2\}\)[\s\S]{0,80}invoiceNumber,'
      r'[\s\S]{0,40}copy,[\s\S]{0,40}copyCount',
    ).hasMatch(service),
    true,
  );

  // ─── [3] المتحكّم ───────────────────────────────────────────────────
  print('\n[3] المتحكّم');
  final controller = File(
    'lib/controller/previousinvoicecontroller.dart',
  ).readAsStringSync();
  check(
    '[3] `printInvoice` تقبل عدد النسخ',
    RegExp(r'printInvoice\(\s*Map<String, dynamic> invoice, \{\s*int\? copies,')
        .hasMatch(controller),
    true,
  );
  check(
    '[3] تُمرَّر إلى خدمة الإخراج',
    controller.contains('copies: copies'),
    true,
  );

  // ─── [4] الواجهة ────────────────────────────────────────────────────
  print('\n[4] الواجهة');
  final screen = File('lib/view/screen/previousinvoice.dart').readAsStringSync();
  check(
    '[4] السجل يستورد الحوار',
    screen.contains('invoice/invoice_reprint_copies_dialog.dart'),
    true,
  );
  check(
    '[4] الزرّ يفتح الحوار',
    screen.contains('showInvoiceReprintCopiesDialog()'),
    true,
  );
  check(
    '[4] الإلغاء لا يطبع',
    screen.contains('if (copies == null) return;'),
    true,
  );
  check(
    '[4] العدد المختار يُمرَّر للطباعة',
    screen.contains('printInvoice(invoice, copies: copies)'),
    true,
  );

  final dialog = File(
    'lib/view/widget/invoice/invoice_reprint_copies_dialog.dart',
  ).readAsStringSync();
  check(
    '[4] الحوار يستعمل منتقي النسخ نفسه',
    dialog.contains('InvoiceCopiesSelector('),
    true,
  );
  check('[4] الحدّان 1 و5', dialog.contains('kReprintCopiesMin = 1') &&
      dialog.contains('kReprintCopiesMax = 5'), true);
  check(
    '[4] الإرجاع بالقيمة المختارة',
    dialog.contains('result: value'),
    true,
  );
  // القرار: الحوار لا يكتب الإعداد. وجود `.set(` هنا يغيّر الطباعة التلقائية.
  check(
    '[4] لا يكتب `invoice_copies`',
    dialog.contains('AppSettingsService.instance.set(') ||
        dialog.contains('.set(SettingOptions.invoiceCopies'),
    false,
  );

  // ─── النتيجة ────────────────────────────────────────────────────────
  print('');
  print('─' * 62);
  print('نجح: $_ok · فشل: $_fail');
  if (_fail > 0) exit(1);
}
