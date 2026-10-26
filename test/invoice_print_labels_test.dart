// اختبارات **ما يُطبع** في فاتورة العميل: تسمية نوع الدفع ومقاس الشعار.
//
// هذان العيبان صامتان بطبيعتهما: لا المحلّل ولا المترجم يشتكيان إذا طُبع
// `cash` بجانب «المدفوع»، أو بقي الشعار 150 نقطة بعد إضافة إعداد المقاس.
// لذلك نختبر المنطق الخالص الذي يستدعيه المولّد، لا شكل الورقة.
import 'package:flutter_test/flutter_test.dart';
import 'package:laundry/config/constants.dart';
import 'package:laundry/services/payment/payment_method.dart';
import 'package:laundry/services/pdf/invoice_logo_size.dart';
import 'package:laundry/services/settings/setting_option.dart';

void main() {
  group('نوع الدفع المطبوع بالعربية', () {
    const expected = <String, String>{
      'cash': 'كاش',
      'card': 'شبكة',
      'credit': 'آجل',
      'balance': 'رصيد',
      'subscription': 'اشتراك شهري',
      'cash_refund': 'استرداد نقدي',
    };

    test('كل مفتاح تخزين يُترجم إلى تسميته العربية', () {
      expected.forEach((key, label) {
        expect(PaymentMethods.arabicLabel(key), label, reason: key);
      });
    });

    test('القيم القديمة والمرادفات الإنجليزية تُقرأ عربيًّا أيضًا', () {
      expect(PaymentMethods.arabicLabel('كاش'), 'كاش');
      expect(PaymentMethods.arabicLabel('شبكة'), 'شبكة');
      expect(PaymentMethods.arabicLabel('آجل'), 'آجل');
      expect(PaymentMethods.arabicLabel('اشتراك'), 'اشتراك شهري');
      expect(PaymentMethods.arabicLabel('network'), 'شبكة');
      expect(PaymentMethods.arabicLabel('mada'), 'شبكة');
      expect(PaymentMethods.arabicLabel('deferred'), 'آجل');
      expect(PaymentMethods.arabicLabel(' CASH '), 'كاش');
    });

    test('القيمة المجهولة لا تُبتلع خلف تسمية مضلِّلة', () {
      expect(PaymentMethods.arabicLabel('تحويل بنكي'), 'تحويل بنكي');
      expect(PaymentMethods.arabicLabel('  '), '');
      expect(PaymentMethods.arabicLabel(null), '');
    });
  });

  group('مقاس شعار الفاتورة', () {
    const double tolerance = 0.01;

    test('غياب الإعداد يعطي المقاس القديم (53 مم ≈ 150 نقطة)', () {
      expect(
        InvoiceLogoSize.resolvePoints(null, maxWidth: 500),
        closeTo(150.24, tolerance),
      );
      expect(
        InvoiceLogoSize.resolvePoints('غير رقم', maxWidth: 500),
        closeTo(150.24, tolerance),
      );
    });

    test('القيمة تُقرأ من num أو نصّ (عبر عزل compute)', () {
      expect(
        InvoiceLogoSize.resolvePoints(80, maxWidth: 500),
        closeTo(226.77, tolerance),
      );
      expect(
        InvoiceLogoSize.resolvePoints('80', maxWidth: 500),
        closeTo(226.77, tolerance),
      );
    });

    test('الحدود تُطبَّق فلا شعار ضئيل ولا شعار أوسع من الورق', () {
      expect(
        InvoiceLogoSize.resolvePoints(1, maxWidth: 500),
        closeTo(28.35, tolerance),
      );
      expect(
        InvoiceLogoSize.resolvePoints(999, maxWidth: 500),
        closeTo(340.16, tolerance),
      );
      // ورقة حرارية ضيقة: العرض المتاح هو السقف الفعلي.
      expect(
        InvoiceLogoSize.resolvePoints(120, maxWidth: 152),
        closeTo(152, tolerance),
      );
    });

    test('العرض المتاح الشاذ لا ينتج مقاسًا سالبًا أو صفرًا', () {
      expect(
        InvoiceLogoSize.resolvePoints(53, maxWidth: 2),
        InvoiceLogoSize.minPoints,
      );
    });

    test('الإعداد مسجَّل ويتبع مفتاح إظهار الشعار', () {
      final option = SettingOptions.byKey(AppConstants.settingInvoiceLogoSize);
      expect(option, isNotNull);
      expect(option!.isInteger, isTrue);
      expect(option.defaultValue, '${AppConstants.invoiceLogoSizeDefaultMm}');
      expect(option.min, AppConstants.invoiceLogoSizeMinMm);
      expect(option.max, AppConstants.invoiceLogoSizeMaxMm);
      expect(option.enabledBy, AppConstants.settingInvoiceShowLogo);
      expect(SettingOptions.all.contains(option), isTrue);
    });
  });
}
