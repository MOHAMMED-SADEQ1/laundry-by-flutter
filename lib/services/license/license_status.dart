/// حالة ترخيص النظام — **منطق خالص بلا Flutter وبلا قاعدة بيانات**.
///
/// فُصل هنا عن `SystemLicenseController` عن قصد: كل شرط «هل نقفل النظام؟»
/// يجب أن يُختبر بلا قاعدة وبلا `flutter_tester` (المعروف بفشله في هذا
/// المشروع)، لذا يقبل [evaluate] التاريخين صراحةً ويعيد نتيجة مكتملة.
///
/// **دلالة الصلاحية:** تاريخ الانتهاء **شامل ليومه** — النظام صالح طوال يوم
/// الانتهاء حتى 23:59:59، ويُقفل من اليوم التالي. والمقارنة **بتاريخ مجرّد**
/// (سنة/شهر/يوم) لا بطابع زمني، فلا تؤثر فيها الساعة ولا المنطقة الزمنية.
library;

/// نتيجة تقييم الترخيص
enum LicenseState {
  /// لا تاريخ انتهاء مُعيَّن ⇒ النظام غير محدود.
  unlimited,

  /// سارٍ وبعيد عن الانتهاء (أكثر من `warnDays`).
  active,

  /// سارٍ لكن بقي `warnDays` أو أقل ⇒ يُعرض تحذير.
  expiringSoon,

  /// انتهى (أو تعذّر التحقق من صحة ساعة الجهاز) ⇒ يُقفل النظام.
  expired,
}

class LicenseStatus {
  final LicenseState state;

  /// تاريخ الانتهاء (بمنتصف ليل ذلك اليوم) أو `null` إن كان غير محدود.
  final DateTime? expiry;

  /// الأيام المتبقية **شاملة يوم الانتهاء** (`0` = ينتهي اليوم)، وسالبة بعد
  /// الانتهاء. `null` إن كان النظام غير محدود.
  final int? daysRemaining;

  /// هل الوقت الحالي **أقدم** من آخر يوم شوهد فيه النظام بأكثر من يوم؟
  /// أي أن ساعة الجهاز أُرجعت للخلف — محاولة تجاوز للترخيص.
  final bool clockTampered;

  const LicenseStatus({
    required this.state,
    this.expiry,
    this.daysRemaining,
    this.clockTampered = false,
  });

  bool get isExpired => state == LicenseState.expired;
  bool get isUnlimited => state == LicenseState.unlimited;
  bool get isExpiringSoon => state == LicenseState.expiringSoon;
  bool get isActive => state == LicenseState.active || state == LicenseState.expiringSoon;

  /// تاريخ مجرّد (بلا وقت) بتوقيت UTC — لأجل حساب فروق أيام مستقرة.
  ///
  /// استخدام UTC هنا مقصود: `DateTime.difference` على تواريخ محلية قد يُعطي
  /// 23 أو 25 ساعة عند تغيّر التوقيت الصيفي، فيحتسب اليوم صفرًا. تجريد
  /// الأيام ثم تحويلها إلى UTC يجعل كل يوم 24 ساعة دائمًا.
  static DateTime dateOnly(DateTime d) => DateTime.utc(d.year, d.month, d.day);

  /// فرق الأيام التقويمية من [from] إلى [to] (موجب إذا كان `to` لاحقًا).
  static int daysBetween(DateTime from, DateTime to) =>
      dateOnly(to).difference(dateOnly(from)).inDays;

  /// هل يُكتب تاريخ الكود الافتراضي فوق المخزَّن؟
  ///
  /// هذا القرار **خالص** كي يُختبر بلا قاعدة بيانات. وثلاث قواعد تحكمه:
  ///  1. قيمة الكود الفارغة/غير الصالحة ⇒ لا بذر (نظام غير محدود).
  ///  2. سبق تطبيق نفس القيمة ([appliedRaw] == [codeRaw]) ⇒ لا بذر. وهذا
  ///     الحارس هو ما يحمي **التجديد اليدوي** و**خيار «بلا تاريخ»** من المحو
  ///     في كل تشغيل، ويجعل التطبيق يحدث **مرة واحدة لكل إصدار**.
  ///  3. **لا تقصير أبدًا**: إن وُجد تاريخ مخزَّن فلا يُكتب الكود إلا إن كان
  ///     **لاحقًا** له. فلا يمكن لإصدار أن يُنهي صلاحية أبعد حصل عليها العميل.
  static bool shouldSeed({
    required String codeRaw,
    required String? appliedRaw,
    required DateTime? stored,
    required DateTime? codeDate,
  }) {
    if (codeDate == null || codeRaw.trim().isEmpty) return false;
    if (appliedRaw != null && appliedRaw.trim() == codeRaw.trim()) return false;
    if (stored == null) return true;
    return dateOnly(codeDate).isAfter(dateOnly(stored));
  }

  /// تقييم الترخيص.
  ///
  /// [expiry] تاريخ الانتهاء (شامل) أو `null` لغير محدود، [now] الوقت الحالي،
  /// [lastSeen] آخر يوم شوهد فيه النظام (لكشف إرجاع الساعة) أو `null`.
  static LicenseStatus evaluate(
    DateTime? expiry,
    DateTime now, {
    int warnDays = 7,
    DateTime? lastSeen,
  }) {
    // لا تاريخ ⇒ غير محدود. لا معنى لكشف التلاعب حين لا شيء يُفرض أصلًا.
    if (expiry == null) {
      return const LicenseStatus(
        state: LicenseState.unlimited,
        expiry: null,
        daysRemaining: null,
      );
    }

    // إرجاع الساعة: نسمح بإزاحة يوم واحد (فروق المناطق والتوقيت الصيفي)،
    // وما زاد عليها تلاعب ⇒ قفل.
    final tampered = lastSeen != null &&
        daysBetween(now, lastSeen) > 1;

    final remaining = daysBetween(now, expiry);

    if (tampered || remaining < 0) {
      return LicenseStatus(
        state: LicenseState.expired,
        expiry: expiry,
        daysRemaining: remaining,
        clockTampered: tampered,
      );
    }

    return LicenseStatus(
      state: remaining <= warnDays ? LicenseState.expiringSoon : LicenseState.active,
      expiry: expiry,
      daysRemaining: remaining,
    );
  }
}
