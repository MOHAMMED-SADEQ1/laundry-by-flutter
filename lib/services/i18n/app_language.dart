// لغات التطبيق — **منطق خالص** (بلا Flutter ولا قاعدة بيانات).
//
// مصدر واحد لثلاثة قرارات تُشتقّ من اللغة: كود `Locale`، اتجاه الكتابة،
// وتسمية الاختيار في الإعدادات. أي مكان آخر يكتب `'ar'` أو `'en'` بيده
// يُعدّ خرقًا (يحرسه `tool/verify_i18n.dart`).

/// لغة واجهة النظام.
enum AppLanguage {
  /// العربية — الاتجاه من اليمين لليسار.
  ar('ar', 'العربية', 'Arabic', true),

  /// الإنجليزية — الاتجاه من اليسار لليمين.
  en('en', 'English', 'English', false),

  /// تلقائي: تتبع لغة الجهاز (عربي ⇒ عربي، غير ذلك ⇒ إنجليزي).
  system('system', 'لغة الجهاز', 'Device language', false);

  const AppLanguage(this.code, this.label, this.labelEn, this.isRtl);

  /// الكود المخزَّن في `settings.language`.
  final String code;

  /// التسمية بالعربية (تُعرض دائمًا بالعربية في قائمة الاختيار).
  final String label;

  /// التسمية بالإنجليزية.
  final String labelEn;

  /// هل اتجاه هذه اللغة من اليمين لليسار؟ (`system` تُحسم قبل السؤال).
  final bool isRtl;

  /// القيمة الافتراضية — **العربية** لأن كل النصوص الحالية عربية، فتغيير
  /// الافتراضي يعني تغيير شكل النظام لكل مستخدم قائم.
  static const AppLanguage defaultLanguage = AppLanguage.ar;

  /// كل الخيارات المعروضة في الإعدادات.
  static const List<AppLanguage> choices = <AppLanguage>[ar, en, system];

  /// اللغة الفعلية بعد حسم `system` بلغة الجهاز.
  ///
  /// [deviceLanguageCode] هو `PlatformDispatcher.locale.languageCode`
  /// (مثل `'ar'` أو `'en'`). أي قيمة غير عربية ⇒ إنجليزية، لأن الإنجليزية
  /// هي اللغة الاحتياطية العالمية — لا نترك الواجهة بلا لغة مفهومة.
  AppLanguage resolve(String? deviceLanguageCode) {
    if (this != AppLanguage.system) return this;
    final code = (deviceLanguageCode ?? '').toLowerCase();
    return code.startsWith('ar') ? AppLanguage.ar : AppLanguage.en;
  }

  /// كود `Locale` الفعلي (`ar` أو `en`) بعد الحسم.
  String resolveCode(String? deviceLanguageCode) =>
      resolve(deviceLanguageCode).code;

  /// الاتجاه الفعلي بعد الحسم.
  bool resolveIsRtl(String? deviceLanguageCode) =>
      resolve(deviceLanguageCode) == AppLanguage.ar;

  /// اللغة المسجَّلة بكودها، والافتراضي عند كود مجهول أو فارغ.
  ///
  /// لا ترمي ولا تعيد `null`: قيمة تالفة في القاعدة يجب أن تُنتج واجهة
  /// عربية (الحالة الآمنة) لا شاشة بلا لغة.
  static AppLanguage byCode(String? code) {
    final c = (code ?? '').trim().toLowerCase();
    for (final l in choices) {
      if (l.code == c) return l;
    }
    return defaultLanguage;
  }

  static List<String> get codes =>
      choices.map((l) => l.code).toList(growable: false);

  /// هل هذا الكود مسجَّل؟
  static bool isKnown(String? code) =>
      choices.any((l) => l.code == (code ?? '').trim().toLowerCase());

  @override
  String toString() => 'AppLanguage($code)';
}
