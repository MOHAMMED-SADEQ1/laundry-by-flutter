import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:laundry/core/navigation/route_dismissal.dart';
import 'package:laundry/view/widget/common/app_dialog.dart';

Widget _host(Widget child) {
  return GetMaterialApp(
    home: Scaffold(body: Center(child: child)),
  );
}

void main() {
  testWidgets('dismissOpenDialog closes the dialog while a snackbar is open',
      (tester) async {
    addTearDown(Get.closeAllSnackbars);
    await tester.pumpWidget(
      _host(
        Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => Get.dialog(
              const AlertDialog(content: Text('DIALOG_BODY')),
            ),
            child: const Text('OPEN_DIALOG'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('OPEN_DIALOG'));
    await tester.pumpAndSettle();
    expect(find.text('DIALOG_BODY'), findsOneWidget);

    // الرسالة هي ما كان `Get.back()` يغلقه بدل الحوار.
    Get.snackbar('TITLE', 'SNACKBAR_BODY');
    await tester.pump();

    expect(dismissOpenDialog(), isTrue);
    await tester.pumpAndSettle();

    expect(find.text('DIALOG_BODY'), findsNothing);
    expect(find.text('SNACKBAR_BODY'), findsOneWidget);
    Get.closeAllSnackbars();
    await tester.pumpAndSettle();
  });

  testWidgets('Get.defaultDialog closes from onConfirm with a snackbar open',
      (tester) async {
    addTearDown(Get.closeAllSnackbars);
    await tester.pumpWidget(
      _host(
        Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => Get.defaultDialog(
              title: 'DEFAULT_DIALOG_TITLE',
              textConfirm: 'DEFAULT_OK',
              textCancel: 'DEFAULT_CANCEL',
              onConfirm: dismissOpenDialog,
            ),
            child: const Text('OPEN_DEFAULT_DIALOG'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('OPEN_DEFAULT_DIALOG'));
    await tester.pumpAndSettle();
    expect(find.text('DEFAULT_DIALOG_TITLE'), findsOneWidget);

    Get.snackbar('TITLE', 'SNACKBAR_BODY');
    await tester.pump();

    await tester.tap(find.text('DEFAULT_OK'));
    await tester.pumpAndSettle();

    expect(find.text('DEFAULT_DIALOG_TITLE'), findsNothing);
    Get.closeAllSnackbars();
    await tester.pumpAndSettle();
  });

  testWidgets('dismissOpenDialog never pops the page when no dialog is open',
      (tester) async {    await tester.pumpWidget(_host(const Text('PAGE_BODY')));

    expect(dismissOpenDialog(), isFalse);
    expect(find.text('PAGE_BODY'), findsOneWidget);
  });

  testWidgets('dismissRoute pops its page even with a snackbar on screen',
      (tester) async {
    addTearDown(Get.closeAllSnackbars);
    await tester.pumpWidget(
      _host(
        Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => Get.to(
              () => Scaffold(
                appBar: AppBar(title: const Text('SECOND_PAGE')),
                body: Builder(
                  builder: (innerContext) => ElevatedButton(
                    onPressed: () => dismissRoute(innerContext),
                    child: const Text('CLOSE_PAGE'),
                  ),
                ),
              ),
            ),
            child: const Text('OPEN_PAGE'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('OPEN_PAGE'));
    await tester.pumpAndSettle();
    expect(find.text('SECOND_PAGE'), findsOneWidget);

    Get.snackbar('TITLE', 'SNACKBAR_BODY');
    await tester.pump();

    await tester.tap(find.text('CLOSE_PAGE'));
    await tester.pumpAndSettle();

    expect(find.text('SECOND_PAGE'), findsNothing);
    expect(find.text('OPEN_PAGE'), findsOneWidget);
    Get.closeAllSnackbars();
    await tester.pumpAndSettle();
  });

  testWidgets('showConfirmDialog returns true when a snackbar is open',
      (tester) async {
    addTearDown(Get.closeAllSnackbars);
    bool? answer;
    await tester.pumpWidget(
      _host(
        Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              answer = await showConfirmDialog(
                title: 'CONFIRM_TITLE',
                message: 'CONFIRM_MESSAGE',
                confirmText: 'CONFIRM_OK',
              );
            },
            child: const Text('OPEN_CONFIRM'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('OPEN_CONFIRM'));
    await tester.pumpAndSettle();
    expect(find.text('CONFIRM_MESSAGE'), findsOneWidget);

    Get.snackbar('TITLE', 'SNACKBAR_BODY');
    await tester.pump();

    await tester.tap(find.text('CONFIRM_OK'));
    await tester.pumpAndSettle();

    expect(find.text('CONFIRM_MESSAGE'), findsNothing);
    expect(answer, isTrue);
    Get.closeAllSnackbars();
    await tester.pumpAndSettle();
  });
}
