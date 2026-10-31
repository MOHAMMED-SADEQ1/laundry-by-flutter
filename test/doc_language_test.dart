// حرس **لغة المستندات** — القرار المالي المستقلّ عن لغة الواجهة.
//
// **العيب الصامت الذي يحرسه:** أن تعود لغة الفاتورة لتُشتقّ من `L10n` (أو من
// `settings.language`) فيصير تبديل لغة الشاشة تغييرًا في مستند ضريبي. لذلك
// نختبر النوع الخالص، وتسجيل الإعداد، وختم اللغة في `transport`، وترجمة
// النصّ والقالب **في كلا الاتجاهين**: واجهة عربية + فاتورة إنجليزية، والعكس.
//
// التشغيل: flutter test test/doc_language_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:laundry/config/constants.dart';
import 'package:laundry/services/i18n/app_language.dart';
import 'package:laundry/services/i18n/doc_language.dart';
import 'package:laundry/services/i18n/l10n.dart';
import 'package:laundry/services/i18n/translations_en.dart';
import 'package:laundry/services/payment/payment_method.dart';
import 'package:laundry/services/pdf/doc_template.dart';
import 'package:laundry/services/pdf/doc_template_service.dart';
import 'package:laundry/services/settings/setting_option.dart';

void main() {
  // لا نترك لغة الواجهة مُبدَّلة لبقيّة الملفّات.
  tearDown(() => L10n.setLanguage(AppLanguage.ar));

  group('DocLanguage — النوع الخالص', () {
    test('الافتراضي عربي والأكواد ثابتة', () {
      expect(DocLanguage.defaultLanguage, DocLanguage.arabic);
      expect(DocLanguage.codes, <String>['ar', 'en']);
      expect(DocLanguage.arabic.code, 'ar');
      expect(DocLanguage.english.code, 'en');
      expect(DocLanguage.arabic.isRtl, isTrue);
      expect(DocLanguage.english.isRtl, isFalse);
      expect(DocLanguage.english.isEnglish, isTrue);
      expect(DocLanguage.arabic.isEnglish, isFalse);
    });

    test('`byCode` يتسامح مع الفراغ والحالة والأقواس الفاسدة', () {
      expect(DocLanguage.byCode(null), DocLanguage.arabic);
      expect(DocLanguage.byCode(''), DocLanguage.arabic);
      expect(DocLanguage.byCode('   '), DocLanguage.arabic);
      expect(DocLanguage.byCode('EN'), DocLanguage.english);
      expect(DocLanguage.byCode(' en '), DocLanguage.english);
      expect(DocLanguage.byCode('ar'), DocLanguage.arabic);
      // قيمة مجهولة (نسخة قديمة أو كتابة يدوية) لا تُعطّل الطباعة.
      expect(DocLanguage.byCode('fr'), DocLanguage.arabic);
      expect(DocLanguage.byCode('english'), DocLanguage.arabic);
    });
  });

  group('الإعداد — مصدر واحد للحقيقة', () {
    test('مسجَّل بمفتاح ثابت ونوع انتقائي ومجموعة عرض الفاتورة', () {
      final option = SettingOptions.byKey(AppConstants.settingDocLanguage);
      expect(option, isNotNull);
      expect(identical(option, SettingOptions.docLanguage), isTrue);
      expect(SettingOptions.all.contains(option), isTrue);
      expect(option!.isChoice, isTrue);
      expect(option.group, SettingGroups.invoiceDisplay);
    });

    test('القيم المسموحة تطابق أكواد `DocLanguage` بلا انحراف', () {
      final option = SettingOptions.docLanguage;
      expect(option.choices, DocLanguage.codes);
      expect(option.choices!.toSet(), DocLanguage.codes.toSet());
      expect(option.choiceLabels!.keys.toSet(), DocLanguage.codes.toSet());
      expect(option.defaultValue, DocLanguage.defaultLanguage.code);
    });

    test('التسمية والوصف لهما ترجمة إنجليزية', () {
      final option = SettingOptions.docLanguage;
      expect(kEnglish.containsKey(option.label), isTrue);
      expect(kEnglish.containsKey(option.description), isTrue);
      expect(kEnglish[option.label], isNotEmpty);
    });

    test('القيمة المخزَّنة المجهولة تُطبَّع إلى العربية', () {
      final option = SettingOptions.docLanguage;
      expect(normalizeValue(option, 'en'), 'en');
      expect(normalizeValue(option, 'AR'), 'ar');
      expect(normalizeValue(option, 'fr'), 'ar');
      expect(normalizeValue(option, ''), 'ar');
    });
  });

  group('`transport` — اللغة تُختم من الإعداد لا من الوجهة', () {
    test('الإنجليزية تُرفق القاموس وتضع `docLang=en`', () {
      final data = DocTemplateService.instance.transport(
        DocKind.invoice,
        language: DocLanguage.english,
      );
      expect(data['docLang'], 'en');
      expect(data['docEnglish'], isA<Map>());
      expect((data['docEnglish'] as Map).containsKey('فاتورة ضريبية مبسطة'),
          isTrue);
    });

    test('العربية لا ترفق قاموس الإنجليزية', () {
      final data = DocTemplateService.instance.transport(
        DocKind.invoice,
        language: DocLanguage.arabic,
      );
      expect(data['docLang'], 'ar');
      expect(data.containsKey('docEnglish'), isFalse);
    });

    test('اختيار الفاتورة الإنجليزي لا يتأثر بواجهة عربية', () {
      L10n.setLanguage(AppLanguage.ar);
      final data = DocTemplateService.instance.transport(
        DocKind.invoice,
        language: DocLanguage.english,
      );
      final doc = DocTemplateView.of(data, DocKind.invoice);
      expect(doc.isEnglishDoc, isTrue);
      expect(doc.text(DocCatalog.kTitle), 'Simplified tax invoice');
    });

    test('اختيار الفاتورة العربي لا يتأثر بواجهة إنجليزية', () {
      L10n.setLanguage(AppLanguage.en);
      final data = DocTemplateService.instance.transport(
        DocKind.invoice,
        language: DocLanguage.arabic,
      );
      final doc = DocTemplateView.of(data, DocKind.invoice);
      expect(doc.isEnglishDoc, isFalse);
      expect(doc.text(DocCatalog.kTitle), 'فاتورة ضريبية مبسطة');
    });

    test('كل مستند مطبوع يحمل لغته (فاتورة · كشف · وردية · مغسلة)', () {
      for (final kind in DocKind.values) {
        final en = DocTemplateService.instance.transport(
          kind,
          language: DocLanguage.english,
        );
        final ar = DocTemplateService.instance.transport(
          kind,
          language: DocLanguage.arabic,
        );
        expect(en['docLang'], 'en', reason: kind.name);
        expect(en.containsKey('docEnglish'), isTrue, reason: kind.name);
        expect(ar['docLang'], 'ar', reason: kind.name);
        expect(ar.containsKey('docEnglish'), isFalse, reason: kind.name);
      }
    });
  });

  group('`PaymentMethods.labelIn` — تسمية الدفع بلغة الورقة', () {
    test('المفاتيح والعربية القديمة تُطبع بالإنجليزية عند الطلب', () {
      expect(PaymentMethods.labelIn('cash', english: true), 'Cash');
      expect(PaymentMethods.labelIn('card', english: true), 'Card');
      expect(PaymentMethods.labelIn('شبكة', english: true), 'Card');
      expect(PaymentMethods.labelIn('آجل', english: true), 'Credit');
    });

    test('المستند العربي يبقى عربيًّا بلا حالة عامة', () {
      expect(PaymentMethods.labelIn('cash', english: false), 'كاش');
      expect(PaymentMethods.labelIn('card', english: false), 'شبكة');
      expect(PaymentMethods.labelIn('شبكة', english: false), 'شبكة');
    });

    test('القيمة المجهولة لا تُبتلع ولا تُترجم', () {
      expect(PaymentMethods.labelIn('محفظة', english: true), 'محفظة');
      expect(PaymentMethods.labelIn('Wallet', english: false), 'Wallet');
    });

    test('الفراغ يعطي الافتراضي بلغة المستند', () {
      expect(PaymentMethods.labelIn('', english: true), 'Cash');
      expect(PaymentMethods.labelIn(null, english: false), 'كاش');
    });
  });
}
