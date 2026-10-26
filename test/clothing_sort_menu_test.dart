// اختبار ودجة ترتيب الأصناف — الواجهة فقط.
//
// **العيب الصامت الذي يحرسه:** سجلّ فيه ثمانية أنماط وقائمة تعرض ثلاثة
// (أو تعرضها بترتيب مختلف عن السجلّ). لا خطأ في التحليل ولا استثناء — الزرّ
// يعمل ويُظهر «شيئًا». لذلك نعدّ البنود ونطابق نصوصها بالسجلّ نفسه.
//
// ملاحظة حدود: **اختيار** نمط يحتاج قاعدة بيانات (الحفظ في `settings` ثم
// إعادة الجلب)، وهو مُغطّى في مكانين: `tool/verify_clothing_sort.dart`
// (الحفظ والجلب في الكود) و`test/clothing_sort_test.dart` (ترتيب الصفوف على
// SQLite حقيقية). هنا نتحقّق من العرض والتفاعل فقط.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:laundry/controller/addeditcategorycontroller.dart';
import 'package:laundry/services/catalog/clothing_sort.dart';
import 'package:laundry/view/widget/home/clothing_sort_menu.dart';

Widget _host() => GetMaterialApp(
  home: Scaffold(body: Center(child: ClothingSortMenu())),
);

void main() {
  setUp(() {
    // `onInit` يحاول تحميل الأصناف من القاعدة؛ لا قاعدة هنا فالفشل مُلتقَط
    // داخل `loadClothing` ولا يُسقط الاختبار.
    Get.put(AddCategoryController());
  });

  tearDown(Get.reset);

  testWidgets('يعرض الترتيب الافتراضي عند البداية', (tester) async {
    await tester.pumpWidget(_host());
    await tester.pump();
    expect(find.text(ClothingSort.byKey(ClothingSort.defaultKey).label),
        findsOneWidget);
  });

  testWidgets('يفتح قائمة بكل أنماط السجلّ — لا أقل ولا أكثر', (tester) async {
    await tester.pumpWidget(_host());
    await tester.pump();

    await tester.tap(find.byKey(ClothingSortMenu.menuKey));
    await tester.pumpAndSettle();

    for (final s in ClothingSort.all) {
      expect(
        find.byKey(ClothingSortMenu.itemKeyOf(s.key)),
        findsOneWidget,
        reason: 'النمط ${s.key} غائب عن القائمة',
      );
      expect(
        find.text(s.label),
        findsWidgets,
        reason: 'تسمية ${s.key} لا تُعرض',
      );
    }
  });

  testWidgets('عدد البنود = عدد أنماط السجلّ', (tester) async {
    await tester.pumpWidget(_host());
    await tester.pump();
    await tester.tap(find.byKey(ClothingSortMenu.menuKey));
    await tester.pumpAndSettle();

    expect(find.byType(PopupMenuItem<ClothingSort>), findsNWidgets(
      ClothingSort.all.length,
    ));
  });

  testWidgets('النمط الحالي وحده مُعلَّم', (tester) async {
    await tester.pumpWidget(_host());
    await tester.pump();
    await tester.tap(find.byKey(ClothingSortMenu.menuKey));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.radio_button_checked), findsOneWidget);
    expect(
      find.byIcon(Icons.radio_button_unchecked),
      findsNWidgets(ClothingSort.all.length - 1),
    );
  });

  testWidgets('تغيّر النمط في المتحكّم يغيّر النصّ المعروض', (tester) async {
    await tester.pumpWidget(_host());
    await tester.pump();

    final controller = Get.find<AddCategoryController>();
    controller.sortMode.value = ClothingSort.priceDesc;
    await tester.pump();

    expect(find.text(ClothingSort.priceDesc.label), findsOneWidget);
    expect(find.text(ClothingSort.nameAsc.label), findsNothing);
  });

  testWidgets('كل نمط له تسمية ووصف غير فارغين (لا بند فارغ في القائمة)',
      (tester) async {
    await tester.pumpWidget(_host());
    await tester.pump();
    await tester.tap(find.byKey(ClothingSortMenu.menuKey));
    await tester.pumpAndSettle();

    for (final s in ClothingSort.all) {
      expect(s.label.trim().isNotEmpty, true);
      expect(s.description.trim().isNotEmpty, true);
      expect(find.text(s.description), findsOneWidget, reason: s.key);
    }
  });
}
