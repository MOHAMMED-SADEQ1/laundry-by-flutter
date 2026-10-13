// اختبار انحدار: ربط الفاتورة تلقائيًا بالزبون المكتوب.
//
// **الخطأ الذي يحرسه هذا الاختبار:** المطابقة غير المحكمة تربط الفاتورة
// بشخص آخر **بصمت** — فيُخصم من اشتراكه أو يُسجّل الدين على حسابه. لذلك
// يُختبر هنا الحدّ الأدنى لطول الرقم ورفض التخمين عند التعدّد، لا النجاح فقط.

import 'package:flutter_test/flutter_test.dart';
import 'package:laundry/services/subscription/subscriber_match.dart';

Map<String, dynamic> customer(int id, String name, {String? p1, String? p2}) => {
  'customer_id': id,
  'customer_name': name,
  'phone_1': p1,
  'phone_2': p2,
};

void main() {
  final customers = [
    customer(1, 'أحمد العتيبي', p1: '0551234567'),
    customer(2, 'فاطمة الزهراني', p1: '+966509876543'),
    customer(3, 'محمد صادق', p1: '0537498756'),
    customer(4, 'أحمد الغامدي', p1: '0500000000'),
  ];

  group('SubscriberMatcher — تطبيع الاسم', () {
    test('يوحّد صيغ الألف والياء والتاء المربوطة والتشكيل', () {
      expect(
        SubscriberMatcher.normalizeName('  أَحْمَد  العتيبى '),
        SubscriberMatcher.normalizeName('احمد العتيبي'),
      );
      expect(
        SubscriberMatcher.normalizeName('فاطمة'),
        SubscriberMatcher.normalizeName('فاطمه'),
      );
    });

    test('يطوي المسافات المتعددة', () {
      expect(
        SubscriberMatcher.normalizeName('محمد     صادق'),
        'محمد صادق',
      );
    });
  });

  group('SubscriberMatcher — تطابق الاسم', () {
    test('يطابق مع اختلاف صيغة الحروف والمسافات', () {
      expect(SubscriberMatcher.matchCustomerId('احمد العتيبي', customers), 1);
      expect(SubscriberMatcher.matchCustomerId(' أحمد  العتيبي ', customers), 1);
      expect(SubscriberMatcher.matchCustomerId('فاطمه الزهراني', customers), 2);
    });

    test('لا يطابق التطابق الجزئي المتعدّد (التخمين ممنوع)', () {
      // «احمد» يطابق زبونين ⇒ نترك الاختيار للموظف بدل ربط خاطئ
      expect(SubscriberMatcher.matchCustomerId('احمد', customers), isNull);
    });

    test('يطابق الاحتواء الفريد', () {
      expect(SubscriberMatcher.matchCustomerId('الزهراني', customers), 2);
    });

    test('نص فارغ أو غريب لا يُطابق أحدًا', () {
      expect(SubscriberMatcher.matchCustomerId('', customers), isNull);
      expect(SubscriberMatcher.matchCustomerId('   ', customers), isNull);
      expect(SubscriberMatcher.matchCustomerId('زبون غير مسجّل', customers), isNull);
    });
  });

  group('SubscriberMatcher — تطابق الهاتف', () {
    test('يطابق الرقم المحلي بالصيغة الدولية المخزَّنة', () {
      // المكتوب 0509876543 والمخزَّن 966509876543
      expect(SubscriberMatcher.matchCustomerId('0509876543', customers), 2);
      expect(SubscriberMatcher.matchCustomerId('+966 50 987 6543', customers), 2);
    });

    test('يطابق صيغة الصفر الدولي المزدوج', () {
      expect(SubscriberMatcher.matchCustomerId('00966509876543', customers), 2);
    });

    test('مفتاح الهاتف يوحّد الصيغ المحلية والدولية', () {
      expect(SubscriberMatcher.phoneKey('0551234567'), '551234567');
      expect(SubscriberMatcher.phoneKey('00966551234567'), '966551234567');
      expect(SubscriberMatcher.phoneKey('+966 55 123 4567'), '966551234567');
    });

    test('لا يطابق رقمًا أقل من الحد الأدنى للأرقام', () {
      expect(SubscriberMatcher.matchCustomerId('34567', customers), isNull);
    });

    test('لا يطابق رقمًا طويلًا بحقل هاتف تالف قصير', () {
      // «5» يجب ألا يبتلع الرقم الكامل — هذا هو الخطأ الذي أُصلح
      final broken = [customer(9, 'زبون بحقل تالف', p1: '5')];
      expect(
        SubscriberMatcher.matchCustomerId('0551234567', broken),
        isNull,
      );
    });

    test('يتجاهل حقل الهاتف الفارغ ويتابع بقية الزبائن', () {
      final list = [
        customer(10, 'بلا رقم', p1: null, p2: ''),
        customer(11, 'له رقم', p1: '0551234567'),
      ];
      expect(SubscriberMatcher.matchCustomerId('0551234567', list), 11);
    });
  });
}
