// منطق **خالص** لفحص ملفّ التفضيلات (بلا قرص ولا Flutter) — ليُختبَر وحده.
//
// الفصل مقصود: `prefs_guard.dart` يلمس القرص و`path_provider` فلا يُشغَّل
// بـ`dart run`، بينما الحكم «أهذا المحتوى صالح؟» منطق مجرّد يُختبر بمدخلات
// مصنوعة — وأهمّها محتوى الحادثة نفسه: 8836 بايت أصفار.

import 'dart:convert';

/// نتيجة الفحص — تُعرَض للمستخدم مرة واحدة عند الإقلاع.
enum PrefsHealth {
  /// الملفّ غير موجود (أول تشغيل) أو محتواه صالح.
  ok,

  /// كان تالفًا وأُصلح (ونُسخ الأصل جانبًا).
  repaired,

  /// تالف ولم نستطع إصلاحه (صلاحيات/قرص) — التطبيق قد يفشل لاحقًا.
  unrepaired,
}

class PrefsHealthCheck {
  PrefsHealthCheck._();

  /// اسم الملفّ نفسه الذي تستخدمه `shared_preferences` على سطح المكتب
  /// (ويندوز · لينكس · ماك). على أندرويد لا يوجد ملفّ JSON (تخزين أصلي).
  static const String fileName = 'shared_preferences.json';

  /// هل هذا المحتوى الخام صالح لـ`shared_preferences`؟
  ///
  /// **الفراغ صالح** لأن الحزمة تعامله كخريطة فارغة
  /// (`if (stringMap.isNotEmpty)` قبل `json.decode`)، والقيمة الصالحة
  /// **خريطة** لأن الحزمة تفعل `data.cast<String, Object>()` وتتجاهل غيره.
  ///
  /// و`jsonDecode` هو الحدّ الفاصل الحقيقي: هو بالضبط ما يرمي في الحزمة
  /// (`shared_preferences_windows-2.3.2/...:69`) بلا التقاط.
  static bool isUsable(String raw) {
    if (raw.isEmpty) return true;
    try {
      return jsonDecode(raw) is Map;
    } catch (_) {
      // `FormatException` للأصفار والنصّ المقطوع، وأي خطأ آخر يُرفض كذلك:
      // الشكّ في ملفّ تفضيلات يعني إصلاحه لا المراهنة عليه.
      return false;
    }
  }
}
