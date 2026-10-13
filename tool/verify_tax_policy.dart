// ignore_for_file: avoid_print
//
// تحقّق من **السياسة الضريبية** (`lib/services/tax/tax_policy.dart`) — منطق
// خالص بلا قاعدة بيانات ولا Flutter.
//
// يُشغَّل بـ:
//     dart run tool/verify_tax_policy.dart

import 'package:laundry/config/constants.dart';
import 'package:laundry/services/tax/tax_policy.dart';

int passed = 0;
int failed = 0;

void check(String name, Object? got, Object? expected) {
  final ok = '$got' == '$expected';
  ok ? passed++ : failed++;
  print('[${ok ? 'PASS' : 'FAIL'}] $name\n        got=$got  expected=$expected');
}

TaxPolicy policyFrom(Map<String, String> values) =>
    TaxPolicy.fromReader((key) => values[key]);

void main() {
  print('=' * 70);
  print('A. الوضع المعطَّل (وضع النظام غير المسجَّل ضريبيًا)');
  print('=' * 70);

  final off = policyFrom(<String, String>{});
  check('A1. الضريبة معطَّلة افتراضيًا', off.enabled, false);
  check('A2. لا نسبة فعلية', off.effectiveRate(), 0.0);
  check('A3. لا ضريبة على مبلغ 115', off.apply(115).tax, 0.0);
  check('A4. الإجمالي = المبلغ', off.apply(115).gross, 115.0);
  check('A5. غير مسجَّل لدى الهيئة افتراضيًا', off.registered, false);

  print('=' * 70);
  print('B. شامل التسعير (الافتراضي)');
  print('=' * 70);

  final inc = policyFrom(<String, String>{
    AppConstants.settingTaxEnabled: '1',
    AppConstants.settingTaxRate: '0.15',
  });
  check('B1. الضريبة مفعَّلة', inc.enabled, true);
  check('B2. النسبة الفعلية 0.15', inc.effectiveRate(), 0.15);
  check('B3. الأساس من 115 = 100', inc.apply(115).base, 100.0);
  check('B4. الضريبة = 15', inc.apply(115).tax, 15.0);
  check('B5. الإجمالي يبقى 115 (شامل)', inc.apply(115).gross, 115.0);
  check('B6. الوضع شامل', inc.pricesInclude, true);

  print('=' * 70);
  print('C. غير شامل التسعير (الضريبة تُضاف فوق السعر)');
  print('=' * 70);

  final exc = policyFrom(<String, String>{
    AppConstants.settingTaxEnabled: '1',
    AppConstants.settingTaxRate: '0.15',
    AppConstants.settingTaxPricesInclude: '0',
  });
  check('C1. الأساس = المبلغ', exc.apply(100).base, 100.0);
  check('C2. الضريبة = 15', exc.apply(100).tax, 15.0);
  check('C3. الإجمالي المستحق = 115', exc.apply(100).gross, 115.0);
  check('C4. الوضع غير شامل', exc.pricesInclude, false);

  print('=' * 70);
  print('D. الاستثناءات (اشتراكات · تصنيفات · توصيل)');
  print('=' * 70);

  check(
    'D1. الاشتراك معفى افتراضيًا',
    inc.apply(115, isSubscription: true).tax,
    0.0,
  );

  final subTaxed = policyFrom(<String, String>{
    AppConstants.settingTaxEnabled: '1',
    AppConstants.settingTaxRate: '0.15',
    AppConstants.settingTaxApplyToSubscriptions: '1',
  });
  check(
    'D2. الاشتراك خاضع عند التفعيل',
    subTaxed.apply(115, isSubscription: true).tax,
    15.0,
  );

  final exempt = policyFrom(<String, String>{
    AppConstants.settingTaxEnabled: '1',
    AppConstants.settingTaxRate: '0.15',
    AppConstants.settingTaxExemptCategories: '3، 5,7',
  });
  check('D3. تصنيف معفى لا ضريبة', exempt.apply(115, categoryId: 5).tax, 0.0);
  check('D4. تصنيف غير معفى عليه ضريبة', exempt.apply(115, categoryId: 9).tax, 15.0);
  check('D5. التصنيفات المعفاة تُقرأ صحيحة', exempt.exemptCategoryIds.length, 3);
  check(
    'D6. التوصيل معفى عند تعطيل خياره',
    policyFrom(<String, String>{
      AppConstants.settingTaxEnabled: '1',
      AppConstants.settingTaxRate: '0.15',
      AppConstants.settingTaxApplyToDelivery: '0',
    }).apply(115, isDelivery: true).tax,
    0.0,
  );

  print('=' * 70);
  print('E. تقريب الإجمالي');
  print('=' * 70);

  check('E1. بلا تقريب', TaxRounding.apply(10.03, TaxRounding.none), 10.03);
  check(
    'E2. أقرب 0.05',
    TaxRounding.apply(10.03, TaxRounding.nearest005),
    10.05,
  );
  check(
    'E3. أقرب 0.25',
    TaxRounding.apply(10.10, TaxRounding.nearest025),
    10.0,
  );
  check('E4. أقرب ريال', TaxRounding.apply(10.60, TaxRounding.nearest1), 11.0);
  check(
    'E5. السياسة تمرّر التقريب',
    policyFrom(<String, String>{
      AppConstants.settingInvoiceRounding: 'nearest_1',
    }).roundPayable(30.40),
    30.0,
  );

  print('=' * 70);
  print('F. أساس الإقرار والجاهزية');
  print('=' * 70);

  check('F1. أساس الإقرار افتراضيًا استحقاق', off.vatReturnBasis, 'accrual');
  check(
    'F2. أساس نقدي يُقرأ',
    policyFrom(<String, String>{
      AppConstants.settingVatReturnBasis: 'cash',
    }).vatReturnBasis,
    'cash',
  );
  check(
    'F3. تسجيل الهيئة مستقل عن تفعيل الضريبة',
    policyFrom(<String, String>{
      AppConstants.settingTaxRegistered: '1',
    }).registered,
    true,
  );
  check(
    'F4. `isActive` يمنع نسبة فاسدة',
    policyFrom(<String, String>{
      AppConstants.settingTaxEnabled: '1',
      AppConstants.settingTaxRate: '1.5',
    }).isActive,
    false,
  );

  print('=' * 70);
  if (failed > 0) {
    print('$failed من ${passed + failed} فحصًا فشل');
    throw StateError('$failed فحوصات فاشلة');
  }
  print('كل الفحوصات نجحت ($passed/${passed + failed})');
}
