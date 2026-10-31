// اختبار زرّ عدد نسخ الفاتورة — الواجهة فقط.
//
// **العيب الصامت:** زرّ يبدو مفعّلًا لكنه لا يغيّر القيمة، أو يسمح بالنزول
// تحت نسخة واحدة/الزيادة فوق سقف الإعداد (5). الحفظ والطباعة مُختبَران في
// `InvoiceOutputService`، وهنا تُثبت حدود الواجهة نفسها.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:laundry/view/widget/invoice/invoice_copies_selector.dart';

Widget _host(int value, ValueChanged<int> onChanged) => GetMaterialApp(
  home: Scaffold(
    body: Center(
      child: SizedBox(
        width: 360,
        child: InvoiceCopiesSelector(value: value, onChanged: onChanged),
      ),
    ),
  ),
);

void main() {
  testWidgets('يعرض القيمة الحالية', (tester) async {
    await tester.pumpWidget(_host(3, (_) {}));
    expect(
      find.descendant(
        of: find.byKey(InvoiceCopiesSelector.valueKey),
        matching: find.text('3'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('زر + يطلب القيمة التالية', (tester) async {
    final values = <int>[];
    await tester.pumpWidget(_host(2, values.add));
    await tester.tap(find.byKey(InvoiceCopiesSelector.plusKey));
    await tester.pump();
    expect(values, <int>[3]);
  });

  testWidgets('زر − يطلب القيمة السابقة', (tester) async {
    final values = <int>[];
    await tester.pumpWidget(_host(2, values.add));
    await tester.tap(find.byKey(InvoiceCopiesSelector.minusKey));
    await tester.pump();
    expect(values, <int>[1]);
  });

  testWidgets('لا ينزل تحت نسخة واحدة', (tester) async {
    final values = <int>[];
    await tester.pumpWidget(_host(1, values.add));
    await tester.tap(
      find.byKey(InvoiceCopiesSelector.minusKey),
      warnIfMissed: false,
    );
    await tester.pump();
    expect(values, isEmpty);
  });

  testWidgets('لا يزيد فوق خمس نسخ', (tester) async {
    final values = <int>[];
    await tester.pumpWidget(_host(5, values.add));
    await tester.tap(
      find.byKey(InvoiceCopiesSelector.plusKey),
      warnIfMissed: false,
    );
    await tester.pump();
    expect(values, isEmpty);
  });
}
