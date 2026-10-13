// ignore_for_file: avoid_print
//
// تحقّق من **سجل خيارات النظام** — منطق خالص بلا قاعدة بيانات.
//
// يُشغَّل بـ:
//     dart run tool/verify_setting_options.dart
//
// يغطي:
//   A. سلامة السجل (مفاتيح فريدة · أنواع · حدود · مفتاح تفعيل منطقي موجود)
//   B. مطابقة القيم الافتراضية لثوابت `AppConstants` (حارس ضد الانحراف)
//   C. تطبيع القيم: النوع · الحدود · رفض القيم الفاسدة
//   D. تفسير «مُفعَّل»: الغياب أو أي نص غير صريح = معطَّل (حارس الحذف التلقائي)

import 'package:laundry/config/constants.dart';
import 'package:laundry/services/settings/setting_option.dart';

int passed = 0;
int failed = 0;

void check(String name, Object? got, Object? expected) {
  final ok = '$got' == '$expected';
  if (ok) {
    passed++;
  } else {
    failed++;
  }
  print(
    '[${ok ? 'PASS' : 'FAIL'}] $name\n        got=${got!}  expected=$expected',
  );
}

void main() {
  print('=' * 70);
  print('A. سلامة السجل الواحد لخيارات النظام');
  print('=' * 70);

  final keys = SettingOptions.all.map((o) => o.key).toList();
  check(
    'A1. عدد الخيارات = عدد المفاتيح الفريدة',
    keys.length,
    keys.toSet().length,
  );
  check(
    'A2. لا خيار بلا تسمية أو وصف',
    SettingOptions.all
        .where((o) => o.label.trim().isEmpty || o.description.trim().isEmpty)
        .length,
    0,
  );
  check(
    'A3. الخيارات المنطقية افتراضيّها 0/1 فقط',
    SettingOptions.all
        .where(
          (o) => o.isBoolean && o.defaultValue != '0' && o.defaultValue != '1',
        )
        .length,
    0,
  );
  check(
    'A4. القيم الرقمية الافتراضية داخل حدودها',
    SettingOptions.all.where((o) => o.isNumeric).where((o) {
      final v = num.tryParse(o.defaultValue);
      if (v == null) return true;
      if (o.min != null && v < o.min!) return true;
      if (o.max != null && v > o.max!) return true;
      return false;
    }).length,
    0,
  );
  check(
    'A5. كل خيار تابع يشير إلى مفتاح تفعيل منطقي موجود',
    SettingOptions.all
        .where((o) => o.hasParent)
        .where((o) => SettingOptions.parentOf(o)?.isBoolean != true)
        .length,
    0,
  );
  check(
    'A6. المجموعات المعروضة كلها تحتوي خيارات',
    SettingGroups.ordered
        .where((g) => SettingOptions.ofGroup(g).isEmpty)
        .toList(),
    <String>[],
  );
  check(
    'A7. كل خيار انتقائي له قيم وافتراضيه ضمنها',
    SettingOptions.all
        .where((o) => o.isChoice)
        .where(
          (o) =>
              o.choices == null ||
              o.choices!.isEmpty ||
              !o.choices!.contains(o.defaultValue),
        )
        .length,
    0,
  );
  check(
    'A8. غير الانتقائي بلا قائمة قيم',
    SettingOptions.all.where((o) => !o.isChoice && o.choices != null).length,
    0,
  );
  check(
    'A9. كل خيار له مجموعة معروفة',
    SettingOptions.all
        .where((o) => !SettingGroups.ordered.contains(o.group))
        .length,
    0,
  );
  print('=' * 70);
  print('B. مطابقة القيم الافتراضية لثوابت الكود');
  print('=' * 70);

  check(
    'B1. invoice_start = AppConstants.invoiceCounterStart',
    SettingOptions.invoiceStart.defaultValue,
    AppConstants.invoiceCounterStart,
  );
  check(
    'B2. page_size = AppConstants.defaultPageSize',
    SettingOptions.pageSize.defaultValue,
    AppConstants.defaultPageSize,
  );
  check(
    'B3. مدة الاحتفاظ الافتراضية = الحد الأدنى (حماية السنة الجارية)',
    SettingOptions.invoiceRetentionDays.defaultValue,
    AppConstants.invoiceRetentionMinDays,
  );
  check(
    'B4. حدّ مدة الاحتفاظ الأدنى = invoiceRetentionMinDays',
    SettingOptions.invoiceRetentionDays.min,
    AppConstants.invoiceRetentionMinDays,
  );
  check(
    'B5. الحذف التلقائي معطَّل افتراضيًا',
    SettingOptions.invoiceAutoDeleteEnabled.defaultValue,
    AppConstants.invoiceAutoDeleteEnabledByDefault ? '1' : '0',
  );
  check(
    'B6. loyalty_enabled يطابق loyaltyEnabledByDefault',
    SettingOptions.loyaltyEnabled.defaultValue,
    AppConstants.loyaltyEnabledByDefault ? '1' : '0',
  );
  check(
    'B7. loyalty_rate = AppConstants.loyaltyPointsRate',
    SettingOptions.loyaltyRate.defaultValue,
    AppConstants.loyaltyPointsRate,
  );
  check(
    'B8. tax_enabled يطابق taxEnabledByDefault',
    SettingOptions.taxEnabled.defaultValue,
    AppConstants.taxEnabledByDefault ? '1' : '0',
  );
  check(
    'B9. tax_rate = AppConstants.taxRate',
    SettingOptions.taxRate.defaultValue,
    AppConstants.taxRate,
  );
  check(
    'B10. license_warn_days = AppConstants.licenseWarnDays',
    SettingOptions.licenseWarnDays.defaultValue,
    AppConstants.licenseWarnDays,
  );
  check(
    'B11. license_check_hours = AppConstants.licenseCheckInterval',
    SettingOptions.licenseCheckHours.defaultValue,
    AppConstants.licenseCheckInterval.inHours,
  );
  print('=' * 70);
  print('C. تطبيع القيم (النوع · الحدود)');
  print('=' * 70);

  check(
    'C1. منطقي: "true" ⇒ 1',
    normalizeValue(SettingOptions.taxEnabled, 'true'),
    '1',
  );
  check(
    'C2. منطقي: نص فاسد ⇒ 0',
    normalizeValue(SettingOptions.taxEnabled, 'ربما'),
    '0',
  );
  check(
    'C3. منطقي: فراغ ⇒ القيمة الافتراضية',
    normalizeValue(SettingOptions.taxEnabled, '   '),
    '0',
  );
  check(
    'C4. صحيح: كسور تُقرَّب',
    normalizeValue(SettingOptions.pageSize, '30.6'),
    '31',
  );
  check(
    'C5. صحيح: تحت الحد الأدنى ⇒ الحد الأدنى',
    normalizeValue(SettingOptions.pageSize, '1'),
    SettingOptions.pageSize.min,
  );
  check(
    'C6. صحيح: فوق الحد الأعلى ⇒ الحد الأعلى',
    normalizeValue(SettingOptions.pageSize, '99999'),
    SettingOptions.pageSize.max,
  );
  check(
    'C7. صحيح: نص غير رقمي ⇒ الافتراضي',
    normalizeValue(SettingOptions.pageSize, 'أيام'),
    SettingOptions.pageSize.defaultValue,
  );
  check(
    'C8. حارس السنة الجارية: 60 يومًا تُرفع إلى 400',
    normalizeValue(SettingOptions.invoiceRetentionDays, '60'),
    '400',
  );
  check(
    'C9. مدة احتفاظ كبيرة تمرّ كما هي',
    normalizeValue(SettingOptions.invoiceRetentionDays, '1200'),
    '1200',
  );
  check(
    'C10. عشري: 0.1500 ⇒ 0.15',
    normalizeValue(SettingOptions.taxRate, '0.1500'),
    '0.15',
  );
  check(
    'C11. عشري: 15% كنسبة مئوية تُحصر إلى 1',
    normalizeValue(SettingOptions.taxRate, '15'),
    '1',
  );
  check(
    'C12. نصّي: فراغ ⇒ الافتراضي',
    normalizeValue(SettingOptions.currency, '  '),
    'ر.س',
  );
  check(
    'C13. نصّي: الفراغات تُشطب',
    normalizeValue(SettingOptions.currency, ' ر.ي '),
    'ر.ي',
  );
  check(
    'C14. معدّل الولاء لا يقلّ عن 1',
    normalizeValue(SettingOptions.loyaltyRate, '0'),
    SettingOptions.loyaltyRate.min,
  );
  check(
    'C15. قراءة عددية بعد التطبيع',
    intValueOf(SettingOptions.pageSize, ' 42 '),
    42,
  );
  check(
    'C16. قراءة عشرية بعد التطبيع',
    doubleValueOf(SettingOptions.taxRate, '0.075'),
    0.075,
  );

  print('=' * 70);
  print('D. تفسير «مُفعَّل» — حارس الحذف التلقائي');
  print('=' * 70);

  check('D1. غياب المفتاح = معطَّل', isTruthy(null), false);
  check('D2. فراغ = معطَّل', isTruthy(''), false);
  check('D3. "0" = معطَّل', isTruthy('0'), false);
  check('D4. "false" = معطَّل', isTruthy('false'), false);
  check('D5. "1" = مُفعَّل', isTruthy('1'), true);
  check('D6. "true" = مُفعَّل', isTruthy('true'), true);
  check('D7. " TRUE " = مُفعَّل', isTruthy(' TRUE '), true);
  check('D8. أي نص آخر = معطَّل', isTruthy('yes please'), false);

  print('=' * 70);
  print('E. القيمة الفعلية عبر سلسلة التفعيل');
  print('=' * 70);

  String? Function(String) reader(Map<String, String> values) =>
      (key) => values[key];

  // الأب معطَّل ⇒ الخيار التابع معطَّل مهما كانت قيمته المخزَّنة.
  check(
    'E1. خيار تابع وأبوته معطَّل ⇒ منطفئ',
    effectiveValue(
      SettingOptions.invoiceShowTaxLine,
      reader({
        SettingOptions.taxEnabled.key: '0',
        SettingOptions.invoiceShowTaxLine.key: '1',
      }),
    ),
    '0',
  );
  check(
    'E2. تفعيل الأب ⇒ القيمة المخزَّنة تمرّ',
    effectiveValue(
      SettingOptions.taxRate,
      reader({
        SettingOptions.taxEnabled.key: '1',
        SettingOptions.taxRate.key: '0.15',
      }),
    ),
    '0.15',
  );
  check(
    'E3. خيار انتقائي بقيمة فاسدة ⇒ الافتراضي',
    normalizeValue(SettingOptions.invoicePaperSize, 'بلا'),
    AppConstants.invoicePaperSizeDefault,
  );
  check(
    'E4. خيار انتقائي بقيمة صحيحة تمرّ',
    normalizeValue(SettingOptions.invoicePaperSize, 'receipt_80mm'),
    'receipt_80mm',
  );
  check(
    'E5. سلسلة الأسلاف صحيحة',
    SettingOptions.ancestorsOf(SettingOptions.invoiceShowTaxLine)
        .map((o) => o.key)
        .toList(),
    <String>[AppConstants.settingTaxEnabled],
  );
  check(
    'E6. زاتكا تعتمد على tax_registered لا على تفعيل الضريبة',
    effectiveValue(
      SettingOptions.zatcaQrPhase1,
      reader({
        SettingOptions.taxRegistered.key: '1',
        SettingOptions.taxEnabled.key: '0',
        SettingOptions.zatcaQrPhase1.key: '1',
      }),
    ),
    '1',
  );

  print('=' * 70);
  if (failed > 0) {
    print('$failed من ${passed + failed} فحصًا فشل');
    throw StateError('$failed فحوصات فاشلة');
  }
  print('كل الفحوصات نجحت ($passed/${passed + failed})');
}
