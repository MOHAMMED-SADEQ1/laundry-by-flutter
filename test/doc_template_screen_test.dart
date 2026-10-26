// دخان واجهة محرّر القوالب — يثبت أن الشاشة تُبنى وتتفاعل بلا استثناء.
//
// **لماذا؟** الحرس النصّي يثبت وجود `Switch` و`TextField` في الملف، لا أن
// الشاشة **تعمل**. وهذه الشاشة تبني عشرات الودجات من سجلّ متغيّر الحجم، فخطأ
// واحد في `TextEditingController` أو في مفتاح مكرّر يُسقطها في التشغيل فقط.
//
// التشغيل: flutter test test/doc_template_screen_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:laundry/services/pdf/doc_template.dart';
import 'package:laundry/view/screen/settings/doc_template_screen.dart';

void main() {
  setUp(() {
    Get.testMode = true;
  });

  /// يبني الشاشة وينتظر **التحميل الحقيقي**.
  ///
  /// 🚨 نقطتان تعلّمتاهما بالفشل الفعلي:
  ///   1. `tester.pump` وحده لا يكفي — التحميل يمرّ على قناة نظام
  ///      (`path_provider`) غير متاحة في الاختبار، والـ`Future` يبقى معلّقًا
  ///      في منطقة الوقت الوهمي. الحلّ `runAsync` **مرّتين**: الأولى تُشغّل
  ///      الطلب، والثانية تُكمل ما بعده (قالب الفاتورة ثم قالب الكشف).
  ///   2. `ListView` تبني ما يظهر فقط — فبلا تكبير سطح العرض لا يُبنى إلا
  ///      ربع الحقول، ويسقط أي فحص «كل الحقول معروضة» زورًا.
  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1400, 24000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const GetMaterialApp(home: DocTemplateScreen(), locale: Locale('ar')),
    );
    for (var i = 0; i < 4; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 40)),
      );
      await tester.pump();
    }
  }

  testWidgets('تُبنى وتعرض كل حقول الفاتورة', (tester) async {
    await pump(tester);

    expect(find.byType(DocTemplateScreen), findsOneWidget);
    // كل حقل في السجلّ له صفّ ظاهر (اسمه) — لا حقل ساقط من العرض.
    for (final f in DocCatalog.invoiceFields) {
      expect(
        find.text(f.label),
        findsWidgets,
        reason: 'الحقل «${f.label}» (${f.key}) غير معروض',
      );
    }
  });

  testWidgets('كل حقل مُفعَّل له TextField بمفتاحه', (tester) async {
    await pump(tester);
    final tpl = DocTemplate.defaults(DocKind.invoice);
    final withText = DocCatalog.invoiceFields.where(
      (f) => f.hasText && tpl.isOn(f.key),
    );
    expect(withText, isNotEmpty);
    for (final f in withText) {
      expect(
        find.byKey(ValueKey<String>('doc-text-${f.key}')),
        findsOneWidget,
        reason: 'حقل النصّ «${f.key}» غير معروض',
      );
    }
  });

  testWidgets('كل حقل مُفعَّل له لوحة نمط (حجم · وزن · عرض)', (tester) async {
    await pump(tester);
    final tpl = DocTemplate.defaults(DocKind.invoice);
    final styled = DocCatalog.invoiceFields.where(
      (f) => f.hasStyle && tpl.isOn(f.key),
    );
    expect(styled, isNotEmpty);
    for (final f in styled) {
      expect(
        find.byKey(ValueKey<String>('doc-style-${f.key}')),
        findsOneWidget,
        reason: 'لوحة نمط «${f.key}» غير معروضة',
      );
    }
    // الشعار والصور وQR ليست نصوصًا ⇒ بلا لوحة نمط.
    expect(find.byKey(const ValueKey<String>('doc-style-logo')), findsNothing);
  });

  testWidgets('زيادة الحجم تُحدّث الرقم المعروض في لوحة النمط', (tester) async {
    await pump(tester);

    final panel = find.byKey(const ValueKey<String>('doc-style-title'));
    expect(panel, findsOneWidget);

    final before = DocTemplate.defaults(
      DocKind.invoice,
    ).styleOf(DocCatalog.kTitle).size;
    // أول زرّ «+» داخل اللوحة يخصّ الحجم (الترتيب: الحجم · الوزن · العرض).
    final plus = find
        .descendant(of: panel, matching: find.byIcon(Icons.add))
        .first;
    await tester.tap(plus);
    await tester.pump();

    expect(
      find.descendant(
        of: panel,
        matching: find.text((before + 1).toStringAsFixed(0)),
      ),
      findsOneWidget,
      reason: 'لم يتغيّر الحجم المعروض بعد الضغط على «+»',
    );
  });

  testWidgets('زرّ «إيقاف الكل» يُخفي حقول النصّ ولوحات النمط', (tester) async {
    await pump(tester);
    expect(find.byType(TextField), findsWidgets);

    await tester.tap(find.text('إيقاف الكل'));
    await tester.pump();

    // كل المفاتيح صارت false ⇒ لا حقل نصّ ولا لوحة نمط.
    // (حقل «البحث» في الشريط ليس حقل مستند، ويبقى.)
    expect(
      find.byKey(ValueKey<String>('doc-text-${DocCatalog.kTitle}')),
      findsNothing,
    );
    expect(
      find.byKey(ValueKey<String>('doc-style-${DocCatalog.kTitle}')),
      findsNothing,
    );
    expect(find.byKey(const Key('doc-template-filter')), findsOneWidget);
    // ولا ينهار شيء: عدد المفاتيح ثابت.
    expect(
      find.byType(Switch),
      findsNWidgets(DocCatalog.invoiceFields.length),
    );
  });

  testWidgets('التبديل إلى «كشف الحساب» يعرض حقوله', (tester) async {
    await pump(tester);

    await tester.tap(find.text(DocCatalog.labelOf(DocKind.statement)).first);
    await tester.pump();

    for (final f in DocCatalog.statementFields) {
      expect(
        find.text(f.label),
        findsWidgets,
        reason: 'حقل الكشف «${f.label}» غير معروض',
      );
    }
  });

  testWidgets('التبديل إلى «ملخص الوردية» يعرض حقوله', (tester) async {
    await pump(tester);

    await tester.tap(find.text(DocCatalog.labelOf(DocKind.shift)).first);
    await tester.pump();

    for (final f in DocCatalog.shiftFields) {
      expect(
        find.text(f.label),
        findsWidgets,
        reason: 'حقل الملخّص «${f.label}» غير معروض',
      );
    }
    expect(
      find.byKey(ValueKey<String>('doc-text-${DocCatalog.kStartTime}')),
      findsOneWidget,
    );
  });

  testWidgets('التبديل إلى «ورقة المغسلة» يعرض حقولها القابلة للتحرير', (
    tester,
  ) async {
    await pump(tester);

    // النقر على المفتاح لا على النصّ: «ورقة المغسلة» يظهر أيضًا في المعاينة.
    await tester.tap(
      find.byKey(const ValueKey<String>('doc-kind-laundrySlip')),
    );
    await tester.pump();

    for (final f in DocCatalog.laundrySlipFields) {
      expect(
        find.text(f.label),
        findsWidgets,
        reason: 'حقل ورقة المغسلة «${f.label}» غير معروض',
      );
    }
    // العنوان الفرعي («نسخة المحل») حقل نصّ مستقلّ يُحرَّر من هنا.
    expect(
      find.byKey(
        const ValueKey<String>('doc-text-${DocCatalog.kSlipSubtitle}'),
      ),
      findsOneWidget,
    );
    // ولا يظهر أي حقل مالي من قالب الفاتورة.
    expect(
      find.byKey(
        const ValueKey<String>('doc-text-${DocCatalog.kTotalAmount}'),
      ),
      findsNothing,
    );
  });
}
