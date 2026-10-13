// ignore_for_file: avoid_print
//
// تحقّق من **الإقرار الضريبي** (`lib/services/tax/vat_return.dart`).
//
//     dart run tool/verify_vat_return.dart

import 'package:laundry/services/tax/vat_return.dart';

int passed = 0;
int failed = 0;

void check(String name, Object? got, Object? expected) {
  final ok = '$got' == '$expected';
  ok ? passed++ : failed++;
  print('[${ok ? 'PASS' : 'FAIL'}] $name\n        got=$got  expected=$expected');
}

void main() {
  print('=' * 70);
  print('A. الصافي المستحق');
  print('=' * 70);

  final due = VatReturn.compute(
    salesBase: 10000,
    outputTax: 1500,
    purchasesBase: 4000,
    inputTax: 600,
  );
  check('A1. ضريبة المخرجات', due.outputTax, 1500.0);
  check('A2. ضريبة المدخلات', due.inputTax, 600.0);
  check('A3. الصافي المستحق', due.netPayable, 900.0);
  check('A4. ليس رصيدًا دائنًا', due.isCredit, false);

  final credit = VatReturn.compute(
    salesBase: 0,
    outputTax: 400,
    purchasesBase: 0,
    inputTax: 900,
  );
  check('A5. رصيد دائن', credit.netPayable, -500.0);
  check('A6. isCredit صحيح', credit.isCredit, true);
  check('A7. القيمة الفارغة صفر', VatReturn.empty.netPayable, 0.0);

  print('=' * 70);
  print('B. الدمج (فترة ربع = ثلاثة أشهر)');
  print('=' * 70);

  final q = VatReturn.compute(
        salesBase: 0,
        outputTax: 100,
        purchasesBase: 0,
        inputTax: 10,
      )
      .plus(
        VatReturn.compute(
          salesBase: 0,
          outputTax: 200,
          purchasesBase: 0,
          inputTax: 20,
        ),
      )
      .plus(
        VatReturn.compute(
          salesBase: 0,
          outputTax: 300,
          purchasesBase: 0,
          inputTax: 30,
        ),
      );
  check('B1. مجموع المخرجات', q.outputTax, 600.0);
  check('B2. مجموع المدخلات', q.inputTax, 60.0);
  check('B3. الصافي', q.netPayable, 540.0);

  print('=' * 70);
  print('C. التقريب والاتساق');
  print('=' * 70);

  final rounded = VatReturn.compute(
    salesBase: 33.333,
    outputTax: 5.006,
    purchasesBase: 10.999,
    inputTax: 1.006,
  );
  check('C1. الأساس يُقرَّب لخانتين', rounded.salesBase, 33.33);
  check('C2. المخرجات تُقرَّب', rounded.outputTax, 5.01);
  check('C3. المدخلات تُقرَّب', rounded.inputTax, 1.01);
  check('C4. الصافي = 4', rounded.netPayable, 4.0);

  print('=' * 70);
  if (failed > 0) {
    print('$failed من ${passed + failed} فحصًا فشل');
    throw StateError('$failed فحوصات فاشلة');
  }
  print('كل الفحوصات نجحت ($passed/${passed + failed})');
}
