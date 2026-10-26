// اختبارات **الطريقة المحدَّدة عند فتح نافذة الدفع** في نقطة البيع.
//
// العيب صامت: الحوار يفتح ويبدو سليمًا، لكنه يبدأ على «كاش» فيسجّل الموظف
// دفعة نقدية بضغطة واحدة بدل الشبكة. نثبّت هنا الافتراضي في السجل وفي
// القراءة، مع بقاء كل الطرق الأخرى قابلة للاختيار يدويًّا.
import 'package:flutter_test/flutter_test.dart';
import 'package:laundry/config/constants.dart';
import 'package:laundry/services/payment/payment_method.dart';
import 'package:laundry/services/settings/setting_option.dart';

void main() {
  group('افتراضي طريقة الدفع عند فتح الحوار', () {
    test('الافتراضي المسجَّل هو الشبكة لا الكاش', () {
      expect(
        AppConstants.posDefaultPaymentMethodDefault,
        PaymentMethod.card.key,
      );
      expect(
        SettingOptions.posDefaultPaymentMethod.defaultValue,
        PaymentMethod.card.key,
      );
    });

    test('الخيار مسجَّل ويقبل الطرق الثلاث مع تسميات عربية', () {
      final option = SettingOptions.byKey(
        AppConstants.settingPosDefaultPaymentMethod,
      );
      expect(option, isNotNull);
      expect(option!.isChoice, isTrue);
      expect(option.choices, containsAll(<String>['cash', 'card', 'credit']));
      expect(option.defaultValue, PaymentMethod.card.key);
      expect(option.choiceLabels?[PaymentMethod.card.key], 'شبكة');
      expect(SettingOptions.all.contains(option), isTrue);
    });

    test('القيمة الغائبة أو المجهولة تسقط إلى الشبكة لا إلى الكاش', () {
      expect(
        PaymentMethods.keyOf(null, fallback: PaymentMethod.card.key),
        PaymentMethod.card.key,
      );
      expect(
        PaymentMethods.keyOf('', fallback: PaymentMethod.card.key),
        PaymentMethod.card.key,
      );
      expect(
        PaymentMethods.keyOf('غير معروف', fallback: PaymentMethod.card.key),
        PaymentMethod.card.key,
      );
    });

    test('الاختيار اليدوي لأي طريقة أخرى يظل صالحًا', () {
      for (final method in PaymentMethods.saleChoices) {
        expect(PaymentMethods.keyOf(method.key), method.key);
      }
      // «شبكة» القديمة تبقى مقروءة بعد الترحيل.
      expect(PaymentMethods.keyOf('شبكة'), PaymentMethod.card.key);
    });
  });
}
