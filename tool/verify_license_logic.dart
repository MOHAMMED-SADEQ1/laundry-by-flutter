// فحوص منطق ترخيص النظام — يُشغَّل بـ`dart run tool/verify_license_logic.dart`.
//
// لا يعتمد على Flutter ولا على قاعدة بيانات ولا على `flutter_tester` (المعروف
// بفشله في هذا المشروع)، لأن منطق التواريخ في `license_status.dart` خالص.
//
// الاستدعاءات منسوخة حرفيًا من `SystemLicenseController._evaluate`
// و`_applyCodeDefaultSeed`.

// ignore_for_file: avoid_print

import 'package:laundry/services/license/license_event.dart';
import 'package:laundry/services/license/license_status.dart';

final List<bool> _results = [];

void check(String name, Object? got, Object? expected) {
  final ok = got == expected;
  _results.add(ok);
  print('[${ok ? 'PASS' : 'FAIL'}] $name\n        got=$got expected=$expected');
}

LicenseStatus eval(DateTime? expiry, DateTime now, {DateTime? lastSeen}) =>
    LicenseStatus.evaluate(expiry, now, warnDays: 7, lastSeen: lastSeen);

void main() {
  final now = DateTime(2026, 9, 19);

  // ── بلا تاريخ ⇒ غير محدود، ولو أُرجعت ساعة الجهاز (لا شيء يُفرض أصلًا) ──
  final unlimited = eval(null, now);
  check('بلا تاريخ ⇒ غير محدود', unlimited.state, LicenseState.unlimited);
  check('بلا تاريخ ⇒ daysRemaining = null', unlimited.daysRemaining, null);
  check('بلا تاريخ ⇒ لا قفل',
      eval(null, now, lastSeen: DateTime(2027, 1, 1)).isExpired, false);

  // ── الشمول: يوم الانتهاء نفسه صالح ──
  final today = eval(DateTime(2026, 9, 19), now);
  check('ينتهي اليوم ⇒ ليست منتهية', today.isExpired, false);
  check('ينتهي اليوم ⇒ 0 يوم متبقٍ', today.daysRemaining, 0);
  check('ينتهي اليوم ⇒ تحذير', today.isExpiringSoon, true);

  // ── حدود التحذير (7 أيام) ──
  check('يتبقى يوم واحد', eval(DateTime(2026, 9, 20), now).daysRemaining, 1);
  check('يتبقى 7 أيام ⇒ تحذير',
      eval(DateTime(2026, 9, 26), now).state, LicenseState.expiringSoon);
  check('يتبقى 8 أيام ⇒ سارٍ بلا تحذير',
      eval(DateTime(2026, 9, 27), now).state, LicenseState.active);
  check('يتبقى 8 أيام ⇒ ليست منتهية',
      eval(DateTime(2026, 9, 27), now).isExpired, false);

  // ── الانتهاء: من اليوم التالي ليوم الانتهاء ──
  final overdue = eval(DateTime(2026, 9, 18), now);
  check('انتهى أمس ⇒ قفل', overdue.isExpired, true);
  check('انتهى أمس ⇒ daysRemaining سالب', overdue.daysRemaining, -1);
  check('انتهى منذ 7 أيام ⇒ -7',
      eval(DateTime(2026, 9, 12), now).daysRemaining, -7);

  // ── كشف إرجاع ساعة الجهاز ──
  final tampered = eval(
    DateTime(2026, 12, 31),
    now,
    lastSeen: DateTime(2026, 9, 24),
  );
  check('الساعة أُرجعت 5 أيام ⇒ قفل', tampered.isExpired, true);
  check('الساعة أُرجعت ⇒ وسم التلاعب', tampered.clockTampered, true);
  check('آخر مشاهدة اليوم ⇒ لا تلاعب',
      eval(DateTime(2026, 12, 31), now, lastSeen: now).clockTampered, false);
  check('إزاحة يوم واحد مسموحة ⇒ لا تلاعب',
      eval(DateTime(2026, 12, 31), now, lastSeen: DateTime(2026, 9, 20))
          .clockTampered,
      false);

  // ── دقة فرق الأيام (بلا حساسية للمنطقة/التوقيت الصيفي) ──
  check('فرق شهر كامل = 30 يومًا',
      LicenseStatus.daysBetween(DateTime(2026, 9, 19), DateTime(2026, 10, 19)),
      30);
  check('عبور نهاية الشهر: 29/09 → 01/10 = يومان',
      eval(DateTime(2026, 10, 1), DateTime(2026, 9, 29)).daysRemaining, 2);
  check('سنة كبيسة: 28/02/2028 → 01/03/2028 = يومان',
      eval(DateTime(2028, 3, 1), DateTime(2028, 2, 28)).daysRemaining, 2);

  // ── بذر تاريخ الكود: LicenseStatus.shouldSeed ──
  // قرار التطبيق مركزيّ هنا، تكراره في المتحكم ممنوع.
  const code = '2027-09-19';
  final codeDate = DateTime(2027, 9, 19);

  bool seed({
    String codeRaw = code,
    String? applied,
    DateTime? stored,
    DateTime? asOf,
  }) =>
      LicenseStatus.shouldSeed(
        codeRaw: codeRaw,
        appliedRaw: applied,
        stored: stored,
        // نسخة الكود الجديدة تعني تاريخًا محلَّلًا جديدًا.
        codeDate: asOf ?? codeDate,
      );

  check('تثبيت جديد ⇒ يُبذر تاريخ الكود', seed(), true);
  check('سبق تطبيق نفس القيمة ⇒ لا يُعاد',
      seed(applied: code, stored: codeDate), false);
  check('«بلا تاريخ» بعد البذر ⇒ يبقى غير محدود',
      seed(applied: code, stored: null), false);
  check('تجديد يدوي أبعد ⇒ لا يُقصّر',
      seed(stored: DateTime(2028, 1, 1)), false);
  check('تجديد يدوي أقرب ⇒ يُمدّد إلى تاريخ الكود',
      seed(stored: DateTime(2026, 1, 1)), true);
  check(
      'إصدار بتاريخ أحدث ⇒ يُطبّق فورًا',
      seed(
        codeRaw: '2028-09-19',
        asOf: DateTime(2028, 9, 19),
        applied: code,
        stored: codeDate,
      ),
      true);
  check('تاريخ الكود فارغ ⇒ لا بذر (غير محدود)',
      LicenseStatus.shouldSeed(
        codeRaw: '',
        appliedRaw: null,
        stored: null,
        codeDate: null,
      ),
      false);
  check('تاريخ الكود غير صالح ⇒ لا بذر',
      LicenseStatus.shouldSeed(
        codeRaw: 'غير صالح',
        appliedRaw: null,
        stored: null,
        codeDate: null,
      ),
      false);

  // ── استخراج تاريخ الانتهاء من سجل التدقيق (LicenseEvent) ──
  check('JSON صالح ⇒ يُستخرج التاريخ',
      LicenseEvent.extractExpiry('{"system_expiry_date":"2027-09-19"}'),
      '2027-09-19');
  check('نص فارغ ⇒ لا تاريخ (غير محدود)', LicenseEvent.extractExpiry(''), '');
  check('null ⇒ لا تاريخ', LicenseEvent.extractExpiry(null), '');
  check('JSON تالف ⇒ لا يرمي ولا يختلق تاريخًا',
      LicenseEvent.extractExpiry('{ليس بالضرورة JSON'), '');
  check('JSON بلا المفتاح ⇒ لا تاريخ',
      LicenseEvent.extractExpiry('{"another_key":"x"}'), '');
  check('قيمة فارغة ⇒ لا تاريخ (أُلغِي)',
      LicenseEvent.extractExpiry('{"system_expiry_date":""}'), '');

  final seedEvent = LicenseEvent.fromMap({
    'log_id': 7,
    'action': 'license_seed',
    'old_values': '{"system_expiry_date":""}',
    'new_values': '{"system_expiry_date":"2027-09-19"}',
    'timestamp': '2026-09-19T10:00:00.000',
  });
  check('حدث البذر يُعرَف', seedEvent.isSeed, true);
  check('حدث البذر: من غير محدود إلى تاريخ',
      '${seedEvent.oldExpiry}|${seedEvent.newExpiry}', '|2027-09-19');
  check('حدث صالح ⇒ لا خطأ تحليل', seedEvent.hasParseError, false);

  final manualEvent = LicenseEvent.fromMap({
    'log_id': 8,
    'action': 'license_update',
    'old_values': '{"system_expiry_date":"2027-09-19"}',
    'new_values': '{"system_expiry_date":""}',
  });
  check('تعديل يدوي يُعرَف', manualEvent.isManual, true);
  check('إلغاء التاريخ يُوسَم غير محدود', manualEvent.clearedToUnlimited, true);

  check('سجل تالف يُوسَم بخطأ تحليل',
      LicenseEvent.fromMap({
        'log_id': 9,
        'action': 'license_update',
        'new_values': '{تالف',
      }).hasParseError,
      true);

  final passed = _results.where((r) => r).length;
  print('\n$passed/${_results.length} نجحت');
  if (passed != _results.length) {
    throw StateError('فشل ${_results.length - passed} فحصًا');
  }
}
