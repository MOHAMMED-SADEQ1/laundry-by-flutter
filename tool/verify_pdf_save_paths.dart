// حرس **حفظ PDF من كل مسارات الإخراج**.
//
// العيب الذي يمنعه: أن يبقى «حفظ PDF» أثرًا جانبيًّا لفشل الطباعة بدل قرار
// صريح، أو أن يُحفظ المستند في مجلد مؤقّت يمحوه النظام، أو أن يوجد مسار
// إخراج واحد (أرشيف · كشف · وردية) بلا مخرج ملفّي.
//
// التشغيل: dart run tool/verify_pdf_save_paths.dart
import 'dart:io';

import 'package:laundry/services/database/backup_naming.dart';
import 'package:laundry/services/invoice/invoice_pdf_naming.dart';

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
  print('حرس حفظ PDF من كل مسارات الإخراج');
  print('═' * 64);

  // ─── [1] تسمية الملفات ─────────────────────────────────────────────
  print('\n[1] تسمية ملف المستند');
  check('[1] الامتداد pdf', InvoicePdfNaming.extension, 'pdf');
  check(
    '[1] اسم عادي',
    InvoicePdfNaming.buildDocumentFileName(
      'كشف_حساب_7',
      when: DateTime(2026, 10, 30),
    ),
    'كشف_حساب_7_2026-10-30.pdf',
  );
  check(
    '[1] محارف ويندوز الممنوعة تُستبدل',
    InvoicePdfNaming.sanitizeStem('a:b*c?d"e<f>g|h'),
    'a_b_c_d_e_f_g_h',
  );
  check(
    '[1] المسار الملصوق يُنزع ويبقى الاسم',
    InvoicePdfNaming.sanitizeStem(r'C:\Users\x\فاتورة.pdf'),
    'فاتورة.pdf',
  );
  check(
    '[1] المسافات المتتالية تُضغط',
    InvoicePdfNaming.sanitizeStem('كشف   حساب'),
    'كشف_حساب',
  );
  check(
    '[1] النقطة في الطرفين تُنزع',
    InvoicePdfNaming.sanitizeStem('..اسم..'),
    'اسم',
  );
  check(
    '[1] الفراغ يسقط لاسم لاتيني محايد',
    InvoicePdfNaming.sanitizeStem('   '),
    'document',
  );
  check(
    '[1] الطول يُقصّ إلى 100',
    InvoicePdfNaming.sanitizeStem('ا' * 300).length,
    100,
  );
  check(
    '[1] لا محرف ممنوع في أي اسم ناتج',
    InvoicePdfNaming.buildDocumentFileName('x:y*z')
        .split('')
        .where(BackupNaming.forbiddenChars.contains)
        .isEmpty,
    true,
  );
  check(
    '[1] الاسم القياسي للفاتورة لم يتغيّر',
    InvoicePdfNaming.buildFileName(
      invoiceNumber: 1042,
      when: DateTime(2026, 10, 13),
    ),
    'فاتورة-1042_2026-10-13.pdf',
  );

  // ─── [2] الكتابة في مكان واحد ──────────────────────────────────────
  print('\n[2] مسار الكتابة');
  final svc = _code('lib/services/invoice/invoice_output_service.dart');
  check(
    '[2] دالة حفظ عامّة موجودة',
    svc.contains('Future<String> saveDocumentPdf('),
    true,
  );
  check(
    '[2] تكتب في المجلد الفعلي',
    svc.contains('Directory(await effectiveDirectory())'),
    true,
  );
  check(
    '[2] savePdf يمرّ من المسار الواحد لا يكتب بنفسه',
    RegExp(r'return saveDocumentPdf\(').hasMatch(svc),
    true,
  );
  check(
    '[2] لا مجلد مؤقّت في خدمة الإخراج',
    svc.contains('systemTemp'),
    false,
  );
  check(
    '[2] منع الكتابة فوق ملف قائم',
    svc.contains('InvoicePdfNaming.dedupe('),
    true,
  );

  // ─── [3] كشف الحساب: لا مجلد مؤقّت ─────────────────────────────────
  //
  // هذا كان **حفظًا وهميًّا**: رسالة نجاح بمسار داخل `%TEMP%` يُمحى عند أول
  // تنظيف. الحرس يمنع رجوعه.
  print('\n[3] كشف الحساب');
  final stmt = _code(
    'lib/controller/customer/customer_statement_controller.dart',
  );
  check('[3] لا systemTemp', stmt.contains('systemTemp'), false);
  check(
    '[3] الحفظ عبر خدمة الإخراج',
    stmt.contains('InvoiceOutputService.instance.saveDocumentPdf('),
    true,
  );
  check(
    '[3] الاسم من مولّد الأسماء',
    stmt.contains('InvoicePdfNaming.buildDocumentFileName('),
    true,
  );
  check(
    '[3] مسار حفظ صريح لا أثر جانبي',
    stmt.contains('savePdfOnly'),
    true,
  );
  check(
    '[3] الحفظ لا يطبع',
    stmt.contains('if (savePdfOnly) {'),
    true,
  );

  // ─── [4] الأرشيف: حفظ بلا طباعة ────────────────────────────────────
  print('\n[4] الفواتير السابقة');
  final prev = _code('lib/controller/previousinvoicecontroller.dart');
  check(
    '[4] دالة حفظ مستقلة',
    prev.contains('Future<void> saveInvoicePdf('),
    true,
  );
  check(
    '[4] الحفظ بلا طباعة',
    RegExp(
      r'saveInvoicePdf[\s\S]{0,900}?print: false,\s*savePdf: true',
    ).hasMatch(prev),
    true,
  );
  check(
    '[4] إعادة الطباعة لا تحفظ نسخة تلقائيًا',
    prev.contains('savePdf: false'),
    true,
  );
  check(
    '[4] يمرّ من خدمة الإخراج (صلاحية + تسمية + أخطاء)',
    prev.contains('InvoiceOutputService.instance.deliverBundle('),
    true,
  );

  // ─── [5] الوردية ───────────────────────────────────────────────────
  print('\n[5] ملخّص الوردية');
  final shift = _code('lib/controller/shift_controller.dart');
  check(
    '[5] دالة حفظ مستقلة',
    shift.contains('Future<void> saveShiftPdf('),
    true,
  );
  check(
    '[5] تستعمل المسار الواحد',
    shift.contains('saveDocumentPdf('),
    true,
  );
  check(
    '[5] لا systemTemp',
    shift.contains('systemTemp'),
    false,
  );
  check(
    '[5] الحفظ متاح من حوار الإقفال',
    shift.contains("tr('حفظ PDF')"),
    true,
  );

  // ─── [6] الأزرار في الواجهة ────────────────────────────────────────
  //
  // المنطق بلا زرّ لا يراه أحد — وهو العيب الذي تكرّر في هذا المشروع:
  // إعداد أو دالة صحيحة لا يصل إليها المستخدم.
  print('\n[6] الأزرار');
  final archiveUi = _code('lib/view/screen/previousinvoice.dart');
  check(
    '[6] زرّ حفظ في بطاقة الفاتورة',
    archiveUi.contains('.saveInvoicePdf(invoice)'),
    true,
  );
  check(
    '[6] الزرّ محروس بصلاحية الطباعة',
    archiveUi.contains('PermissionService.can(PermissionKeys.invoicePrint)'),
    true,
  );
  final stmtUi = _code(
    'lib/view/widget/customer/customer_statement_sheet.dart',
  );
  check(
    '[6] خيار حفظ الكشف',
    stmtUi.contains('savePdfOnly: true'),
    true,
  );
  final shiftUi = _code('lib/view/screen/shifts_history_screen.dart');
  check(
    '[6] زرّ حفظ الملخّص',
    shiftUi.contains('.saveShiftPdf(shift)'),
    true,
  );

  // ─── [7] لا كتابة ملف مبعثرة ───────────────────────────────────────
  //
  // كل مستند يخرج من النظام يجب أن يسكن مجلدًا واحدًا يعرفه المستخدم؛
  // `writeAsBytes` خارج خدمة الإخراج تعني مكانًا ثانيًا لا يجده.
  //
  // الاستثناءان المُعلَنان:
  //   • النسخ الاحتياطي والاستعادة — ملفّاتهما لها تسمية ومجلد آخر.
  //   • `invoice_share_service` — يكتب في مجلد مؤقّت **ليُشارك** الملف
  //     فورًا مع تطبيق آخر (واتساب · بريد). مستند عابر لا أرشيف، ولو
  //     حُفظ في مجلد المستخدمين لامتلأ بأسماء مكرّرة لا معنى لها.
  print('\n[7] مصدر كتابة واحد');
  const allowed = <String>{
    'lib/services/invoice/invoice_output_service.dart',
    'lib/services/database/backup_service.dart',
    'lib/services/database/restore_service.dart',
    'lib/core/services/invoice_share_service.dart',
  };
  final writers = <String>[];
  for (final f in Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))) {
    final rel = f.path.replaceAll('\\', '/');
    if (rel.contains('/i18n/')) continue;
    if (allowed.any(rel.endsWith)) continue;
    if (_code(f.path).contains('writeAsBytes(')) writers.add(rel);
  }
  check('[7] لا كاتب PDF خارج خدمة الإخراج', writers.join(' | '), '');

  print('\n' + '═' * 64);
  print(_fail == 0 ? '✓ كل الفحوص ناجحة ($_ok)' : '✗ فشل $_fail من ${_ok + _fail}');
  print('═' * 64);
  if (_fail != 0) exitCode = 1;
}
