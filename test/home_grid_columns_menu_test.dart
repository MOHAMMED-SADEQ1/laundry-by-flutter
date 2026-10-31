// اختبار ودجة عدد أعمدة «الأصناف والخدمات» — الواجهة فقط.
//
// **العيب الصامت الذي يحرسه:** إعداد يُحفظ في القاعدة ولا يجد طريقه إلى
// الشبكة، أو قائمة تعرض بعض الخيارات فقط. نطابق البنود بسجلّ
// `SettingOptions.homeGridColumns` نفسه لا بقائمة مكتوبة هنا.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:laundry/controller/addeditcategorycontroller.dart';
import 'package:laundry/services/settings/setting_option.dart';
import 'package:laundry/view/widget/home/home_grid_columns_menu.dart';

Widget _host() => GetMaterialApp(
  home: Scaffold(body: Center(child: HomeGridColumnsMenu())),
);

void main() {
  setUp(() {
    // `onInit` يحاول تحميل الأصناف؛ الفشل مُلتقَط داخل `loadClothing`.
    Get.put(AddCategoryController());
  });

  tearDown(Get.reset);

  testWidgets('يعرض الوضع التلقائي عند البداية', (tester) async {
    await tester.pumpWidget(_host());
    await tester.pump();

    expect(find.text('تلقائي'), findsOneWidget);
  });

  testWidgets('يفتح قائمة بكل خيارات السجلّ — لا أقل ولا أكثر', (
    tester,
  ) async {
    await tester.pumpWidget(_host());
    await tester.pump();
    await tester.tap(find.byKey(HomeGridColumnsMenu.menuKey));
    await tester.pumpAndSettle();

    final choices = SettingOptions.homeGridColumns.choices!;
    expect(
      find.byType(PopupMenuItem<int>),
      findsNWidgets(choices.length),
    );
    for (final value in choices) {
      expect(
        find.byKey(HomeGridColumnsMenu.itemKeyOf(value)),
        findsOneWidget,
        reason: 'الخيار $value غائب عن القائمة',
      );
    }
  });

  testWidgets('الخيار الحالي وحده مُعلَّم', (tester) async {
    await tester.pumpWidget(_host());
    await tester.pump();
    await tester.tap(find.byKey(HomeGridColumnsMenu.menuKey));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.radio_button_checked), findsOneWidget);
    expect(
      find.byIcon(Icons.radio_button_unchecked),
      findsNWidgets(SettingOptions.homeGridColumns.choices!.length - 1),
    );
  });

  testWidgets('تغيّر القيمة في المتحكّم يُحدّث الزرّ فورًا', (tester) async {
    await tester.pumpWidget(_host());
    await tester.pump();

    Get.find<AddCategoryController>().gridColumns.value = 4;
    await tester.pump();

    expect(find.text('4'), findsOneWidget);
    expect(find.text('تلقائي'), findsNothing);
  });
}
