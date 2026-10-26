// ignore_for_file: avoid_print
//
// تحقّق من **قواعد تسمية ملفات فواتير PDF** — منطق خالص بلا قاعدة بيانات.
//
// يُشغَّل بـ:
//     dart run tool/verify_invoice_pdf_naming.dart
//
// يغطي:
//   A. بناء الاسم القياسي (رقم الفاتورة + التاريخ)
//   B. خلوّه من المحارف الممنوعة على ويندوز (وأهمّها النقطتان)
//   C. منع الكتابة فوق ملف قائم (dedupe) بلا حساسية لحالة الأحرف
//   D. ثبات الاسم: نفس المدخلات ⇒ نفس المخرج (لا وقت حقيقي داخله)

import 'package:laundry/services/database/backup_naming.dart';
import 'package:laundry/services/invoice/invoice_pdf_naming.dart';

int passed = 0;
int failed = 0;

void check(String name, Object? got, Object? expected) {
  final ok = '$got' == '$expected';
  if (ok) {
    passed++;
  } else {
    failed++;
  }
  print('[${ok ? 'PASS' : 'FAIL'}] $name\n        got=$got  expected=$expected');
}

void main() {
  final when = DateTime(2026, 10, 13, 14, 32, 5);

  print('=' * 70);
  print('A. الاسم القياسي');
  print('=' * 70);

  check(
    'A1. فاتورة-<الرقم>_<التاريخ>.pdf',
    InvoicePdfNaming.buildFileName(invoiceNumber: 1042, when: when),
    'فاتورة-1042_2026-10-13.pdf',
  );
  check(
    'A2. اليمين صفريًا لليوم والشهر',
    InvoicePdfNaming.buildFileName(
      invoiceNumber: 7,
      when: DateTime(2026, 1, 5, 9, 0),
    ),
    'فاتورة-7_2026-01-05.pdf',
  );
  check(
    'A3. رقم كبير بلا فواصل ولا بادئة',
    InvoicePdfNaming.buildFileName(invoiceNumber: 999999, when: when),
    'فاتورة-999999_2026-10-13.pdf',
  );
  check('A4. الامتداد pdf', InvoicePdfNaming.extension, 'pdf');
  check('A5. البادئة فاتورة', InvoicePdfNaming.prefix, 'فاتورة');

  print('=' * 70);
  print('B. خلوّ الاسم من محارف ممنوعة على ويندوز');
  print('=' * 70);

  final built = InvoicePdfNaming.buildFileName(
    invoiceNumber: 1042,
    when: when,
  );
  final offending = <String>[];
  for (final ch in BackupNaming.forbiddenChars.split('')) {
    if (built.contains(ch)) offending.add(ch);
  }
  check('B1. لا يحوي أي محرف ممنوع', offending.join(','), '');
  check('B2. لا نقطتان (مرفوضة على ويندوز)', built.contains(':'), false);
  check('B3. لا شرطة مائلة', built.contains('/'), false);
  check('B4. امتداد واحد فقط', '.'.allMatches(built).length, 1);
  check('B5. لا ينتهي بنقطة أو فراغ', built.endsWith('.pdf'), true);

  print('=' * 70);
  print('C. منع الكتابة فوق ملف قائم');
  print('=' * 70);

  check(
    'C1. لا ملف مطابق ⇒ الاسم كما هو',
    InvoicePdfNaming.dedupe(built, <String>{}),
    built,
  );
  check(
    'C2. ملف مطابق ⇒ _2 قبل الامتداد',
    InvoicePdfNaming.dedupe(built, <String>{built}),
    'فاتورة-1042_2026-10-13_2.pdf',
  );
  check(
    'C3. _2 موجود أيضًا ⇒ _3',
    InvoicePdfNaming.dedupe(built, <String>{built, 'فاتورة-1042_2026-10-13_2.pdf'}),
    'فاتورة-1042_2026-10-13_3.pdf',
  );
  check(
    'C4. مطابقة بلا حساسية لحالة الأحرف (ويندوز)',
    InvoicePdfNaming.dedupe('INV.PDF', <String>{'inv.pdf'}),
    'INV_2.PDF',
  );
  check(
    'C5. ملفات أخرى لا تُحرّك الاسم',
    InvoicePdfNaming.dedupe(built, <String>{'فاتورة-9_2026-01-01.pdf'}),
    built,
  );

  print('=' * 70);
  print('D. الثبات (لا وقت حقيقي داخل الدالة)');
  print('=' * 70);

  final a = InvoicePdfNaming.buildFileName(invoiceNumber: 55, when: when);
  final b = InvoicePdfNaming.buildFileName(invoiceNumber: 55, when: when);
  check('D1. نفس المدخلات ⇒ نفس المخرج', a == b, true);
  check(
    'D2. اختلاف اليوم يغيّر الاسم',
    a !=
        InvoicePdfNaming.buildFileName(
          invoiceNumber: 55,
          when: DateTime(2026, 10, 14, 14, 32, 5),
        ),
    true,
  );
  check(
    'D3. الوقت لا يؤثر (الاسم بالتاريخ فقط)',
    a ==
        InvoicePdfNaming.buildFileName(
          invoiceNumber: 55,
          when: DateTime(2026, 10, 13, 23, 59, 59),
        ),
    true,
  );

  print('=' * 70);
  if (failed == 0) {
    print('كل الفحوصات نجحت ($passed/$passed)');
  } else {
    print('فشل $failed من ${passed + failed}');
  }
  print('=' * 70);
}
