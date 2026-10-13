/// نتيجة تقييم كود خصم على فاتورة.
///
/// [amount] = قيمة الخصم المحسوبة (0 إن كان الكود غير صالح).
class DiscountCheck {
  final bool valid;
  final String message;
  final Map<String, dynamic>? record;
  final double amount;

  const DiscountCheck({
    required this.valid,
    required this.message,
    this.record,
    this.amount = 0,
  });

  int? get discountId => (record?['discount_id'] as num?)?.toInt();
  String get code => '${record?['code'] ?? ''}';
  String get name => '${record?['name'] ?? ''}';

  static const DiscountCheck none = DiscountCheck(valid: false, message: '');
}

/// قواعد الخصم — **منطق خالص** بلا Flutter ولا قاعدة بيانات، فيُختبر مباشرة.
///
/// فصلُه عن `DiscountService` مقصود: الخدمة تتحدّث مع القاعدة، والقواعد
/// تُحسب هنا. خلطهما كان يمنع اختبار الصلاحية والتواريخ والسقف بلا قاعدة.
///
/// ## دلالة `discounts.value`
///   • `type = 'percentage'` ⇒ **النسبة المئوية** (10 = 10%، لا 0.10).
///     اخترنا الرقم المألوف لأن الحقل عام ويُعرض في واجهة «النسبة %»،
///     بخلاف `tax_rate` الذي هو نسبة عشرية لأنه إعداد نظام.
///   • `type = 'fixed'` ⇒ **مبلغ بالريال** يُخصم مباشرة.
///
/// ## قاعدة الحماية
/// الخصم **لا يتجاوز إجمالي الفاتورة** أبدًا: كود بـ100 ريال على فاتورة 30
/// ريالًا يُخصم 30 لا 100 — وإلا صار الإجمالي سالبًا واختلّت الذمة والصندوق.
class DiscountRules {
  DiscountRules._();

  /// تقييم كود على مبلغ.
  ///
  /// [today] يُمرَّر صريحًا (لا يُقرأ من الساعة داخل الدالة) حتى يكون السلوك
  /// قابلًا للاختبار عند أي تاريخ.
  static DiscountCheck evaluate({
    required Map<String, dynamic>? record,
    required double gross,
    required DateTime today,
  }) {
    if (record == null) {
      return const DiscountCheck(
        valid: false,
        message: 'كود الخصم غير موجود',
      );
    }

    final code = '${record['code'] ?? ''}'.trim();
    if (code.isEmpty) {
      return const DiscountCheck(
        valid: false,
        message: 'هذا الخصم بلا كود — لا يمكن استدعاؤه',
      );
    }

    if (((record['is_active'] as num?)?.toInt() ?? 0) != 1) {
      return DiscountCheck(
        valid: false,
        message: 'كود «$code» معطَّل',
        record: record,
      );
    }

    final start = _parseDate(record['start_date']);
    if (start != null && _dayOnly(today).isBefore(start)) {
      return DiscountCheck(
        valid: false,
        message: 'كود «$code» لم يبدأ بعد — يبدأ ${_fmt(start)}',
        record: record,
      );
    }

    // تاريخ الانتهاء **شامل ليومه** — نفس دلالة ترخيص النظام، وإلا انتهى
    // الكود في منتصف يومه الأخير.
    final end = _parseDate(record['end_date']);
    if (end != null && _dayOnly(today).isAfter(end)) {
      return DiscountCheck(
        valid: false,
        message: 'انتهى كود «$code» في ${_fmt(end)}',
        record: record,
      );
    }

    final maxUses = (record['max_uses'] as num?)?.toInt();
    final used = (record['current_uses'] as num?)?.toInt() ?? 0;
    if (maxUses != null && maxUses > 0 && used >= maxUses) {
      return DiscountCheck(
        valid: false,
        message: 'استُنفد كود «$code» ($used/$maxUses)',
        record: record,
      );
    }

    final value = _num(record['value']);
    if (value <= 0) {
      return DiscountCheck(
        valid: false,
        message: 'قيمة كود «$code» غير صالحة',
        record: record,
      );
    }

    final safeGross = gross > 0 ? gross : 0.0;
    if (safeGross <= 0) {
      return DiscountCheck(
        valid: false,
        message: 'لا يوجد مبلغ لتطبيق الخصم عليه',
        record: record,
      );
    }

    final isPercentage = '${record['type'] ?? ''}'.toLowerCase() == 'percentage';
    var amount = isPercentage ? safeGross * (value / 100) : value;

    // سقف الحماية: لا خصم أكبر من الفاتورة
    if (amount > safeGross) amount = safeGross;
    amount = double.parse(amount.toStringAsFixed(2));

    if (amount <= 0) {
      return DiscountCheck(
        valid: false,
        message: 'الخصم المحسوب صفر — تحقّق من قيمة الكود',
        record: record,
      );
    }

    return DiscountCheck(
      valid: true,
      message: isPercentage
          ? 'خصم ${_plain(value)}% — «${record['name']}»'
          : 'خصم ${amount.toStringAsFixed(2)} ر.س — «${record['name']}»',
      record: record,
      amount: amount,
    );
  }

  /// تاريخ مجرّد من أي وقت — لتفادي انزياح اليوم بالساعات.
  static DateTime _dayOnly(DateTime t) => DateTime(t.year, t.month, t.day);

  static DateTime? _parseDate(dynamic raw) {
    final text = '${raw ?? ''}'.trim();
    if (text.isEmpty) return null;
    try {
      return _dayOnly(DateTime.parse(text));
    } catch (_) {
      return null;
    }
  }

  static String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  static String _plain(double v) {
    final s = v.toStringAsFixed(2);
    return s.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
  }

  static double _num(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse('${value ?? ''}') ?? 0.0;
  }
}
