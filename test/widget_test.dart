// اختبار دخاني (smoke test) لمعلومات النظام وحقوق المطوّر.
//
// كان هذا الملف قالب Flutter الافتراضي يختبر «عدّادًا» (Counter) لا وجود له
// في نظام المغاسل إطلاقًا، فكان `flutter test` يفشل دائمًا بلا علاقة بالتطبيق.
// استُبدل باختبار حقيقي يتحقّق من: مصدر واحد لرقم الإصدار، ومصدر واحد لجملة
// حقوق المطوّر، وأن الـWidget يعرضها فعلًا.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:laundry/config/app_info.dart';
import 'package:laundry/view/widget/common/developer_credit.dart';

void main() {
  test('الإصدار له قيمة احتياطية صالحة حتى قبل قراءته من الحزمة', () {
    expect(AppInfo.version.trim(), isNotEmpty);
    expect(AppInfo.fallbackVersion.trim(), isNotEmpty);
    expect(AppInfo.full, contains(AppInfo.version));
  });

  test('جملة حقوق المطوّر ومعلومات التواصل معرّفة في مصدر واحد', () {
    expect(AppInfo.developerCredit, 'برمجة وتطوير المهندس محمد صادق');
    expect(AppInfo.developerCredit, contains('محمد صادق'));
    expect(AppInfo.developerName, contains('محمد صادق'));
    expect(AppInfo.developerEmail, contains('@'));
    expect(AppInfo.developerPhone, isNotEmpty);
  });

  testWidgets('DeveloperCredit يعرض الجملة على خلفية فاتحة', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: DeveloperCredit())),
    );
    expect(find.text(AppInfo.developerCredit), findsOneWidget);
  });

  testWidgets('DeveloperCredit يعرض الجملة على خلفية داكنة', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          backgroundColor: Colors.black,
          body: DeveloperCredit(onDark: true, showIcon: false),
        ),
      ),
    );
    expect(find.text(AppInfo.developerCredit), findsOneWidget);
  });
}
