import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:laundry/controller/addeditcategorycontroller.dart';
import 'package:laundry/view/widget/home/catalog_refresh_button.dart';

/// متحكّم بلا قاعدة بيانات: يعدّ نداءات الجلب ويسمح لنا بإطالة الجلب
/// لاختبار تعطيل الزرّ أثناءه.
class _FakeAddCategoryController extends AddCategoryController {
  int calls = 0;
  bool allowLoad = false;
  Completer<void>? gate;

  @override
  Future<void> loadClothing() async {
    // `onInit` ينادي الجلب عند التسجيل؛ نتجاهله حتى يبدأ الاختبار نظيفًا.
    if (!allowLoad) return;
    calls++;
    isLoading.value = true;
    try {
      final pending = gate;
      if (pending != null) await pending.future;
    } finally {
      isLoading.value = false;
    }
  }
}

Widget _host() {
  return GetMaterialApp(
    home: Scaffold(
      appBar: AppBar(
        actions: const [CatalogRefreshButton(color: Colors.black)],
      ),
    ),
  );
}

void main() {
  tearDown(Get.reset);

  testWidgets('زر التحديث يعيد الجلب ويمنع النقر المزدوج', (tester) async {
    final controller = _FakeAddCategoryController();
    controller.gate = Completer<void>();
    Get.put<AddCategoryController>(controller);
    controller.allowLoad = true;

    await tester.pumpWidget(_host());
    expect(find.byKey(CatalogRefreshButton.buttonKey), findsOneWidget);

    await tester.tap(find.byKey(CatalogRefreshButton.buttonKey));
    await tester.pump();
    expect(controller.calls, 1);
    expect(controller.isLoading.value, isTrue);

    // الزرّ معطّل أثناء الجلب: لا نداء ثانٍ ولا طلب متزامن.
    await tester.tap(
      find.byKey(CatalogRefreshButton.buttonKey),
      warnIfMissed: false,
    );
    await tester.pump();
    expect(controller.calls, 1);

    controller.gate!.complete();
    await tester.pumpAndSettle();
    expect(controller.isLoading.value, isFalse);

    // بعد انتهاء الجلب يعمل الزرّ مرة أخرى.
    await tester.tap(find.byKey(CatalogRefreshButton.buttonKey));
    await tester.pump();
    expect(controller.calls, 2);
    await tester.pumpAndSettle();
  });

  testWidgets('زر التحديث ظاهر بلا صلاحيات إدارة', (tester) async {
    final controller = _FakeAddCategoryController();
    Get.put<AddCategoryController>(controller);

    await tester.pumpWidget(_host());
    expect(find.byKey(CatalogRefreshButton.buttonKey), findsOneWidget);
  });
}
