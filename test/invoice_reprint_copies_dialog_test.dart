// اختبار حوار عدد نسخ إعادة الطباعة من سجل الفواتير.
//
// **العيب الذي يحرسه:** زرّ «طباعة» في السجل يطبع نسخة واحدة دائمًا، أو حوار
// يُغيّر `invoice_copies` (إعداد الطباعة التلقائية) لمجرد إعادة طباعة عرَضية.
// الاختبار يثبت أن العدد العائد هو المختار فعلًا، وأن الإلغاء لا يطبع.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:laundry/view/widget/invoice/invoice_copies_selector.dart';
import 'package:laundry/view/widget/invoice/invoice_reprint_copies_dialog.dart';

Widget _host(void Function(int?) onResult) => GetMaterialApp(
  home: Scaffold(
    body: Builder(
      builder: (context) => Center(
        child: ElevatedButton(
          onPressed: () async {
            onResult(await showInvoiceReprintCopiesDialog(initial: 1));
          },
          child: const Text('فتح'),
        ),
      ),
    ),
  ),
);

Future<void> _open(WidgetTester tester, void Function(int?) onResult) async {
  await tester.pumpWidget(_host(onResult));
  await tester.tap(find.text('فتح'));
  await tester.pumpAndSettle();
}

void main() {
  tearDown(Get.reset);

  testWidgets('يفتح على القيمة الابتدائية ويعيد العدد المختار', (tester) async {
    int? result;
    await _open(tester, (value) => result = value);

    expect(find.text('طباعة الفاتورة'), findsOneWidget);
    expect(find.text('عدد نسخ الفاتورة'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);

    await tester.tap(find.byKey(InvoiceCopiesSelector.plusKey));
    await tester.pump();
    await tester.tap(find.byKey(InvoiceCopiesSelector.plusKey));
    await tester.pump();
    expect(find.text('3'), findsOneWidget);

    await tester.tap(find.widgetWithText(ElevatedButton, 'طباعة'));
    await tester.pumpAndSettle();

    expect(result, 3);
    expect(find.text('عدد نسخ الفاتورة'), findsNothing);
  });

  testWidgets('الإلغاء يرجع null ولا يطبع', (tester) async {
    var called = false;
    int? result;
    await _open(tester, (value) {
      called = true;
      result = value;
    });

    await tester.tap(find.text('إلغاء'));
    await tester.pumpAndSettle();

    expect(called, isTrue);
    expect(result, isNull);
  });

  testWidgets('القيمة خارج الحدود تُقصّ إلى 5', (tester) async {
    await tester.pumpWidget(
      GetMaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: ElevatedButton(
                onPressed: () => showInvoiceReprintCopiesDialog(initial: 99),
                child: const Text('فتح'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('فتح'));
    await tester.pumpAndSettle();

    expect(find.text('5'), findsOneWidget);
  });

  testWidgets('حدّ − عند 1 معطّل (لا نسخة صفرية)', (tester) async {
    await _open(tester, (_) {});

    final minus = tester.widget<Material>(
      find.byKey(InvoiceCopiesSelector.minusKey),
    );
    // لون الخلفية الشفاف = الزرّ معطّل في الودجة.
    expect(minus.color, Colors.transparent);
  });
}
