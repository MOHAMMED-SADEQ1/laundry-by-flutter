// اختبار منطق الضريبة والخصم — **خالص** بلا Flutter ولا قاعدة بيانات.
//
// التشغيل: dart run tool/verify_tax_and_discount.dart
//
// يختبر:
//   • TaxService: الضريبة الشاملة (الأسعار شاملة) · الحالات الحدّية ·
//     تفعيل/تعطيل · سلامة أرقام QR هيئة الزكاة والضريبة (TLV ثم Base64).
//   • DiscountRules: كل مسارات الرفض والقبول · سقف الخصم · حدّ الاستخدام ·
//     شمول تاريخ الانتهاء ليومه · التفاعل مع الضريبة.

import 'dart:convert';
import 'dart:typed_data';

import '../lib/services/discount/discount_rules.dart';
import '../lib/services/tax/tax_service.dart';

int pass = 0;
int fail = 0;

void check(String label, Object? got, Object? want) {
  final ok = got == want;
  if (ok) {
    pass++;
    print('  PASS  $label: $got');
  } else {
    fail++;
    print('  FAIL  $label: got $got  expected $want');
  }
}

void near(String label, double got, double want) {
  final ok = (got - want).abs() < 0.011;
  if (ok) {
    pass++;
    print('  PASS  $label: ${got.toStringAsFixed(2)}');
  } else {
    fail++;
    print(
      '  FAIL  $label: got ${got.toStringAsFixed(2)} '
      'expected ${want.toStringAsFixed(2)}',
    );
  }
}

Map<String, dynamic> code({
  int? id = 1,
  String code = 'WASH10',
  String name = 'خصم تجريبي',
  String type = 'percentage',
  double value = 10,
  String start = '2026-01-01',
  String? end,
  int active = 1,
  int? maxUses,
  int used = 0,
}) => {
  'discount_id': id,
  'code': code,
  'name': name,
  'type': type,
  'value': value,
  'start_date': start,
  'end_date': end,
  'is_active': active,
  'max_uses': maxUses,
  'current_uses': used,
};

void main() {
  final today = DateTime(2026, 6, 15);

  // ═════════════════════════ الضريبة ═════════════════════════
  print('\n[1] TaxService.inclusive — الأسعار شاملة الضريبة');

  var t = TaxService.inclusive(115, 0.15);
  near('115 شاملًا ⇒ الأساس 100', t.base, 100);
  near('115 شاملًا ⇒ الضريبة 15', t.tax, 15);
  near('115 شاملًا ⇒ الإجمالي 115', t.gross, 115);

  t = TaxService.inclusive(100, 0.15);
  near('100 شاملًا ⇒ الأساس 86.96', t.base, 86.96);
  near('100 شاملًا ⇒ الضريبة 13.04', t.tax, 13.04);

  t = TaxService.inclusive(100, 0);
  near('نسبة صفر ⇒ لا ضريبة', t.tax, 0);
  near('نسبة صفر ⇒ الأساس = الإجمالي', t.base, 100);

  t = TaxService.inclusive(-50, 0.15);
  near('مبلغ سالب ⇒ لا ضريبة', t.tax, 0);
  near('مبلغ سالب ⇒ أساس صفر', t.base, 0);

  // خاصية رياضية: الأساس + الضريبة = الإجمالي، لكل مبلغ
  var consistent = true;
  for (final gross in <double>[0.01, 1, 7.5, 33.33, 99.99, 1234.56, 99999.99]) {
    final b = TaxService.inclusive(gross, 0.15);
    if ((b.base + b.tax - b.gross).abs() > 0.011) consistent = false;
  }
  check('الأساس + الضريبة = الإجمالي لكل المبالغ', consistent, true);

  check(
    'effectiveRate معطَّل ⇒ صفر',
    TaxService.effectiveRate(enabled: false, rate: 0.15),
    0,
  );
  near(
    'effectiveRate مُفعَّل ⇒ النسبة',
    TaxService.effectiveRate(enabled: true, rate: 0.15),
    0.15,
  );
  check(
    'effectiveRate نسبة شاذة (>1) ⇒ صفر',
    TaxService.effectiveRate(enabled: true, rate: 1.5),
    0,
  );
  check(
    'effectiveRate نسبة سالبة ⇒ صفر',
    TaxService.effectiveRate(enabled: true, rate: -0.1),
    0,
  );

  print('\n[2] QR هيئة الزكاة والضريبة (TLV ثم Base64)');

  final payload = TaxService.zatcaQrPayload(
    sellerName: 'مغاسل النظارة',
    vatNumber: '310123456700003',
    timestamp: DateTime(2026, 6, 15, 14, 30, 5),
    totalWithVat: 115,
    vatTotal: 15,
  );

  final raw = base64.decode(payload);
  final fields = <int, String>{};
  var i = 0;
  var wellFormed = true;
  while (i + 1 < raw.length) {
    final tag = raw[i];
    final len = raw[i + 1];
    if (i + 2 + len > raw.length) {
      wellFormed = false;
      break;
    }
    fields[tag] = utf8.decode(raw.sublist(i + 2, i + 2 + len));
    i += 2 + len;
  }

  check('البنية سليمة (لا حقل مقطوع)', wellFormed, true);
  check('عدد الحقول = 5', fields.length, 5);
  check('الوسم 1 = اسم البائع', fields[1], 'مغاسل النظارة');
  check('الوسم 2 = الرقم الضريبي', fields[2], '310123456700003');
  check('الوسم 3 = الطابع الزمني', fields[3], '2026-06-15T14:30:05');
  check('الوسم 4 = الإجمالي شامل الضريبة', fields[4], '115.00');
  check('الوسم 5 = مبلغ الضريبة', fields[5], '15.00');
  check('كل البايتات مستهلكة', i, raw.length);
  check('يُفكّ بلا استثناء', raw is Uint8List, true);

  // ═════════════════════════ الخصم ═════════════════════════
  print('\n[3] DiscountRules — مسارات الرفض');

  check(
    'كود غير موجود',
    DiscountRules.evaluate(record: null, gross: 200, today: today).valid,
    false,
  );
  check(
    'خصم بلا كود',
    DiscountRules.evaluate(
      record: code(code: '  '),
      gross: 200,
      today: today,
    ).valid,
    false,
  );
  check(
    'كود معطَّل',
    DiscountRules.evaluate(
      record: code(active: 0),
      gross: 200,
      today: today,
    ).valid,
    false,
  );
  check(
    'لم يبدأ بعد',
    DiscountRules.evaluate(
      record: code(start: '2026-07-01'),
      gross: 200,
      today: today,
    ).valid,
    false,
  );
  check(
    'انتهى قبل اليوم',
    DiscountRules.evaluate(
      record: code(start: '2026-01-01', end: '2026-06-14'),
      gross: 200,
      today: today,
    ).valid,
    false,
  );
  check(
    'استُنفد حدّ الاستخدام',
    DiscountRules.evaluate(
      record: code(maxUses: 5, used: 5),
      gross: 200,
      today: today,
    ).valid,
    false,
  );
  check(
    'قيمة صفر ⇒ مرفوض',
    DiscountRules.evaluate(
      record: code(value: 0),
      gross: 200,
      today: today,
    ).valid,
    false,
  );
  check(
    'مبلغ فاتورة صفر ⇒ مرفوض',
    DiscountRules.evaluate(record: code(), gross: 0, today: today).valid,
    false,
  );

  print('\n[4] DiscountRules — مسارات القبول والحساب');

  var c = DiscountRules.evaluate(record: code(), gross: 200, today: today);
  check('نسبة 10% صالحة', c.valid, true);
  near('نسبة 10% على 200 ⇒ 20', c.amount, 20);

  c = DiscountRules.evaluate(
    record: code(type: 'fixed', value: 50),
    gross: 200,
    today: today,
  );
  near('مبلغ ثابت 50 على 200 ⇒ 50', c.amount, 50);

  c = DiscountRules.evaluate(
    record: code(type: 'fixed', value: 500),
    gross: 200,
    today: today,
  );
  near('مبلغ 500 على فاتورة 200 ⇒ يُسقَف على 200 (لا إجمالي سالب)', c.amount, 200);

  c = DiscountRules.evaluate(
    record: code(value: 100),
    gross: 200,
    today: today,
  );
  near('نسبة 100% ⇒ كل الفاتورة', c.amount, 200);

  c = DiscountRules.evaluate(
    record: code(start: '2026-06-15'),
    gross: 200,
    today: today,
  );
  check('يبدأ اليوم ⇒ صالح (شامل ليومه)', c.valid, true);

  c = DiscountRules.evaluate(
    record: code(start: '2026-01-01', end: '2026-06-15'),
    gross: 200,
    today: today,
  );
  check('ينتهي اليوم ⇒ صالح (شامل ليومه)', c.valid, true);

  c = DiscountRules.evaluate(
    record: code(maxUses: 5, used: 4),
    gross: 200,
    today: today,
  );
  check('قبل الحدّ بخطوة ⇒ صالح', c.valid, true);

  c = DiscountRules.evaluate(
    record: code(maxUses: 0),
    gross: 200,
    today: today,
  );
  check('max_uses = 0 ⇒ بلا حدّ', c.valid, true);

  c = DiscountRules.evaluate(
    record: code(maxUses: null),
    gross: 200,
    today: today,
  );
  check('max_uses غائب ⇒ بلا حدّ', c.valid, true);

  c = DiscountRules.evaluate(record: code(), gross: 0.5, today: today);
  near('فاتورة 0.50 مع خصم 10% ⇒ 0.05 (لا صفر)', c.amount, 0.05);

  print('\n[5] التفاعل: الخصم قبل الضريبة (الترتيب المحاسبي)');

  // فاتورة 200، خصم 10% ⇒ مستحق 180، الضريبة تُستخرج من 180 لا من 200.
  final d = DiscountRules.evaluate(record: code(), gross: 200, today: today);
  final payable = 200 - d.amount;
  near('المستحق بعد الخصم', payable, 180);

  final tx = TaxService.inclusive(payable, 0.15);
  near('الضريبة على الصافي (180) لا على الإجمالي (200)', tx.tax, 23.48);
  near('الأساس الخاضع للضريبة', tx.base, 156.52);
  near('المستحق = الأساس + الضريبة', tx.base + tx.tax, payable);

  final taxIfWrongOrder = TaxService.inclusive(200, 0.15);
  final wrongNet = 200 - taxIfWrongOrder.tax - d.amount;
  // الفرق = أساس صحيح 156.52 − أساس خاطئ 153.91 = 2.61 ر.س على فاتورة 200
  near(
    'الترتيب الخاطئ (ضريبة قبل الخصم) يُنقص الإيراد بـ '
        '${(tx.base - wrongNet).toStringAsFixed(2)} ر.س',
    tx.base - wrongNet,
    2.61,
  );

  print('\n${'=' * 50}');
  print('  النتيجة: $pass ناجح · $fail فاشل');
  print('=' * 50);
  if (fail > 0) throw StateError('$fail فحصًا فاشلًا');
}
