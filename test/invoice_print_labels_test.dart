// اختبارات **ما يُطبع** في فاتورة العميل: تسمية نوع الدفع ومقاس الشعار.
//
// هذان العيبان صامتان بطبيعتهما: لا المحلّل ولا المترجم يشتكيان إذا طُبع
// `cash` بجانب «المدفوع»، أو بقي الشعار 150 نقطة بعد إضافة إعداد المقاس.
// لذلك نختبر المنطق الخالص الذي يستدعيه المولّد، لا شكل الورقة.
import 'package:flutter_test/flutter_test.dart';
import 'package:laundry/config/constants.dart';
import 'package:laundry/services/payment/payment_method.dart';
import 'package:laundry/services/pdf/print_visual_size.dart';
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

  group('مقاس الشعار ورمز الموقع', () {
    const double tolerance = 0.01;

    test('غياب الإعداد يعطي المقاس القديم (53 مم ≈ 150 نقطة)', () {
      final box = PrintVisualSize.logo(maxWidth: 500, maxHeight: 700);
      expect(box.width, closeTo(150.24, tolerance));
      expect(box.height, closeTo(150.24, tolerance));
      expect(box.clamped, isFalse);
    });

    test('القيمة تُقرأ من num أو نصّ (عبر عزل compute)', () {
      final fromNum = PrintVisualSize.logo(
        widthMm: 80,
        heightMm: 80,
        maxWidth: 500,
        maxHeight: 700,
      );
      final fromText = PrintVisualSize.logo(
        widthMm: '80',
        heightMm: '80',
        maxWidth: 500,
        maxHeight: 700,
      );
      expect(fromNum.width, closeTo(226.77, tolerance));
      expect(fromText.width, closeTo(226.77, tolerance));
    });

    test('العرض والارتفاع مستقلّان — الشعار المستطيل لا يُقصّ إلى مربّع', () {
      final box = PrintVisualSize.logo(
        widthMm: 80,
        heightMm: 30,
        maxWidth: 500,
        maxHeight: 700,
      );
      expect(box.widthMm, closeTo(80, tolerance));
      expect(box.heightMm, closeTo(30, tolerance));
      // المساحة = العرض × الارتفاع (طلب المستخدم صريحًا).
      expect(box.areaMm2, closeTo(2400, 0.5));
      expect(box.isSquare, isFalse);
    });

    test('الحدود تُطبَّق فلا شعار ضئيل ولا شعار أوسع من الورق', () {
      final tiny = PrintVisualSize.logo(
        widthMm: 1,
        heightMm: 1,
        maxWidth: 500,
        maxHeight: 700,
      );
      expect(tiny.widthMm, closeTo(5, tolerance));

      final huge = PrintVisualSize.logo(
        widthMm: 999,
        heightMm: 999,
        maxWidth: 500,
        maxHeight: 700,
      );
      expect(huge.width, closeTo(340.16, tolerance)); // 120 مم = الحدّ الأعلى
      expect(huge.widthClamped, isFalse); // الحدّ الأعلى للمفتاح لا للورق
    });

    test('العرض المتاح هو السقف الفعلي ويُعلَن التقييد', () {
      final box = PrintVisualSize.logo(
        widthMm: 120,
        heightMm: 120,
        maxWidth: 152,
        maxHeight: 700,
      );
      expect(box.width, closeTo(152, tolerance));
      expect(box.widthClamped, isTrue);
    });

    test('ارتفاع الشعار يُقيَّد كي لا يدفع الأصناف إلى صفحة ثانية', () {
      final box = PrintVisualSize.logo(
        widthMm: 60,
        heightMm: 120,
        maxWidth: 500,
        maxHeight: 700,
      );
      expect(box.height, closeTo(700 * PrintVisualSize.logoMaxHeightShare, tolerance));
      expect(box.heightClamped, isTrue);
    });

    test('العرض المتاح الشاذ لا ينتج مقاسًا سالبًا أو صفرًا', () {
      final box = PrintVisualSize.logo(
        widthMm: 53,
        heightMm: 53,
        maxWidth: 2,
        maxHeight: 2,
      );
      expect(box.width, PrintVisualSize.minPoints);
      expect(box.height, PrintVisualSize.minPoints);
    });

    test('رمز QR يبقى مربّعًا بعد التقييد', () {
      final box = PrintVisualSize.qr(
        sizeMm: 30,
        maxWidth: 500,
        maxHeight: 700,
      );
      expect(box.isSquare, isTrue);
      expect(box.widthMm, closeTo(30, tolerance));

      final narrow = PrintVisualSize.qr(
        sizeMm: 70,
        maxWidth: 137,
        maxHeight: 700,
      );
      expect(narrow.isSquare, isTrue);
      expect(narrow.width, closeTo(137, tolerance));
      expect(narrow.widthClamped, isTrue);
    });

    test('الإعدادات مسجَّلة وتتبع مفتاح إظهار الشعار', () {
      final width = SettingOptions.byKey(AppConstants.settingInvoiceLogoWidth);
      final height = SettingOptions.byKey(AppConstants.settingInvoiceLogoHeight);
      final qr = SettingOptions.byKey(AppConstants.settingMapQrSize);

      expect(width, isNotNull);
      expect(height, isNotNull);
      expect(qr, isNotNull);
      expect(width!.defaultValue, '${AppConstants.invoiceLogoWidthDefaultMm}');
      expect(height!.defaultValue, '${AppConstants.invoiceLogoHeightDefaultMm}');
      expect(qr!.defaultValue, '${AppConstants.mapQrSizeDefaultMm}');
      expect(width.enabledBy, AppConstants.settingInvoiceShowLogo);
      expect(height.enabledBy, AppConstants.settingInvoiceShowLogo);
      expect(SettingOptions.all.contains(width), isTrue);
      expect(SettingOptions.all.contains(height), isTrue);
      expect(SettingOptions.all.contains(qr), isTrue);
      // المفتاح القديم لم يبقَ خيارًا معروضًا — لا تحكّمين لنفس المقاس.
      expect(SettingOptions.byKey(AppConstants.settingInvoiceLogoSize), isNull);
    });
  });
}
