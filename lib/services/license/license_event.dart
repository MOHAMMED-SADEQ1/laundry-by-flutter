import 'dart:convert';

/// حدث واحد على ترخيص النظام، مستخرج من `audit_log`.
///
/// **دلالة الاسم:** `action` قيمتان فقط:
///  - `license_seed`: تطبيق التاريخ المضمَّن في الكود (عند تثبيت جديد أو إصدار
///    بتاريخ لاحق).
///  - `license_update`: تعديل/تجديد يدوي من إعدادات الترخيص أو شاشة القفل.
///
/// هذا الملف **خالص** (`dart:convert` فقط، بلا Flutter وبلا قاعدة بيانات)،
/// فيمكن اختبار استخراج التواريخ منه بمشغّل Dart مباشر.
class LicenseEvent {
  final int logId;
  final String action;
  final String userName;
  final DateTime? timestamp;

  /// القيمة السابقة/الجديدة لتاريخ الانتهاء، أو `''` إن كانت فارغة (غير محدود).
  final String oldExpiry;
  final String newExpiry;

  /// فشل تحليل JSON؟ يُعرض الحدث حينها بلا تواريخ بدل إخفائه.
  final bool hasParseError;

  const LicenseEvent({
    required this.logId,
    required this.action,
    this.userName = '',
    this.timestamp,
    this.oldExpiry = '',
    this.newExpiry = '',
    this.hasParseError = false,
  });

  factory LicenseEvent.fromMap(Map<String, dynamic> m) {
    final action = '${m['action'] ?? ''}';
    final oldRaw = m['old_values']?.toString();
    final newRaw = m['new_values']?.toString();
    return LicenseEvent(
      logId: (m['log_id'] as num?)?.toInt() ?? 0,
      action: action,
      userName: '${m['user_name'] ?? m['username'] ?? ''}',
      timestamp: DateTime.tryParse('${m['timestamp'] ?? ''}'),
      oldExpiry: extractExpiry(oldRaw),
      newExpiry: extractExpiry(newRaw),
      hasParseError: _isParseError(oldRaw) || _isParseError(newRaw),
    );
  }

  bool get isSeed => action == 'license_seed';
  bool get isManual => action == 'license_update';

  /// هل انتهى الحدث إلى «غير محدود» (تاريخ فارغ)؟
  bool get clearedToUnlimited => isManual && newExpiry.isEmpty;

  String get actionLabel {
    if (isSeed) return 'تطبيق تاريخ الكود';
    if (isManual) {
      return clearedToUnlimited ? 'إلغاء التاريخ (غير محدود)' : 'تجديد / تعديل يدوي';
    }
    return action.replaceAll('_', ' ');
  }

  /// استخراج `system_expiry_date` من نص JSON مخزَّن.
  ///
  /// يتحمّل الفشل: نص فارغ، أو JSON غير صالح، أو مفتاح مفقود ⇒ `''`.
  /// ولا يرمي استثناءً أبدًا لأن سجلًا تالفًا لا يجوز أن يُسقط الشاشة.
  static String extractExpiry(String? raw) => _parseExpiry(raw) ?? '';

  /// تحليل القيمة: `null` = تعذّر التحليل (لا تاريخ)، و`''` = قيمة موجودة
  /// وقيمتها فارغة أي **أُلغِي التاريخ عمدًا** (غير محدود).
  ///
  /// الفرق جوهري: خلطهما كان يجعل حدثًا صحيحًا («من غير محدود إلى تاريخ»)
  /// يُعرض كخطأ تحليل، لأن ``system_expiry_date":""`` قيمة شرعية لا تلف.
  static String? _parseExpiry(String? raw) {
    final s = (raw ?? '').trim();
    if (s.isEmpty) return null;
    try {
      final decoded = jsonDecode(s);
      if (decoded is! Map) return null;
      if (!decoded.containsKey('system_expiry_date')) return null;
      return '${decoded['system_expiry_date'] ?? ''}'.trim();
    } catch (_) {
      return null;
    }
  }

  /// هل نص القيم تالف فعلًا؟ (لا مجرد كونه فارغًا أو قيمته فارغة)
  static bool _isParseError(String? raw) {
    final s = (raw ?? '').trim();
    if (s.isEmpty) return false; // لا شيء لنحلّله ⇒ ليست خطأ
    return _parseExpiry(s) == null;
  }
}
