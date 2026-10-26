// محرّك الترجمة — **منطق خالص** (بلا Flutter ولا قاعدة بيانات).
//
// `LocaleController` يضبط [L10n.language] عند الإقلاع وعند التبديل، وكل
// الواجهة تنادي `tr('نصّ عربي')` فتأخذ الترجمة أو تعود للنصّ نفسه.
//
// **لماذا دالّة عامّة `tr` لا صنفًا يُمرَّر في كل مكان؟** لأن 2,987 نصًّا في
// 100 ملف: تمرير كائن ترجمة لكل ودجة يعني تعديل التوقيعات كلها. الدالّة
// العامة تجعل التحويل **ميكانيكيًا** (`'نصّ'` ⇒ `tr('نصّ')`) وقابلًا للحراسة.

import 'package:laundry/services/i18n/app_language.dart';
import 'package:laundry/services/i18n/translations_en.dart';

class L10n {
  L10n._();

  /// اللغة **الفعلية** الحالية (بعد حسم `system`). يضبطها `LocaleController`.
  static AppLanguage language = AppLanguage.defaultLanguage;

  /// لغة الجهاز كما أبلغها النظام — تُستخدم لحسم `system`.
  static String? deviceLanguageCode;

  /// هل الواجهة الآن إنجليزية؟
  static bool get isEnglish => language == AppLanguage.en;

  /// هل الاتجاه الآن من اليمين لليسار؟
  static bool get isRtl => language == AppLanguage.ar;

  /// كود اللغة الفعلي (`ar` أو `en`) — يُمرَّر إلى `intl` و`MaterialApp`.
  static String get localeCode => language.code;

  /// اسم اللغة كما يفهمه `intl` (`ar` · `en`).
  static String get intlLocale => language.code;

  /// يضبط اللغة الفعلية (يُستدعى من `LocaleController` فقط).
  static void setLanguage(AppLanguage resolved, {String? deviceCode}) {
    language = resolved;
    deviceLanguageCode = deviceCode ?? deviceLanguageCode;
  }

  /// يترجم نصًّا عربيًّا إلى لغة الواجهة الحالية.
  ///
  /// **سلسلة السقوط:** إنجليزية موجودة ⇒ هي · غير موجودة ⇒ **النصّ العربي**
  /// نفسه · النصّ فارغ ⇒ فراغ. لا يُعاد مفتاح ولا `null` أبدًا، فلا تظهر
  /// شاشة فيها `???` أو نصّ مفقود لأن ترجمة سطر لم تُكتب.
  ///
  /// **البحث على مرحلتين**: مطابقة حرفية أولًا (الأشيع، أرخص)، ثم مطابقة
  /// **مُطبَّعة** (المسافات المتتابعة والسطرية تُطوى إلى مسافة واحدة). السبب:
  /// كثير من النصوص مكتوبة في الكود على عدّة أسطر متجاورة
  /// (`'سطر أول '\n'سطر ثانٍ'`) فيصل النصّ للدالّة بفواصل أسطر، بينما
  /// القاموس يكتبه في سطر واحد. بدون التطبيع تفشل الترجمة **بصمت** ويظهر
  /// العربي في واجهة إنجليزية. الخريطة المطابقة تُبنى **مرة واحدة** عند أول
  /// طلب (لا حساب لكل بناء واجهة) فلا تُثقل العمليات.
  static String t(String arabic) {
    if (arabic.isEmpty) return arabic;
    if (language != AppLanguage.en) return arabic;
    final exact = kEnglish[arabic];
    if (exact != null) return exact;
    return _flatEnglish[_flatten(arabic)] ?? arabic;
  }

  /// يطوي كل مسافة متتابعة (بما فيها الأسطر) إلى مسافة واحدة ويقصّ الطرفين.
  static String _flatten(String text) => text.replaceAll(_wsRun, ' ').trim();

  static final RegExp _wsRun = RegExp(r'\s+');

  /// القاموس نفسه بمفاتيح مُطبَّعة — يُبنى عند أول استخدام إنجليزي فقط.
  static final Map<String, String> _flatEnglish = <String, String>{
    for (final entry in kEnglish.entries) _flatten(entry.key): entry.value,
  };

  /// يترجم ويستبدل رموزًا موضعية `{0}` `{1}` … بالترتيب.
  ///
  /// مثال: `L10n.tf('إجمالي {0}', ['120.00'])`. الرموز تُستبدل **بعد**
  /// الترجمة، فترتيب الكلمات في الإنجليزية لا يُقيَّد بترتيب العربية.
  static String tf(String arabic, List<Object?> args) {
    var out = t(arabic);
    for (var i = 0; i < args.length; i++) {
      out = out.replaceAll('{$i}', '${args[i]}');
    }
    return out;
  }

  /// هل لهذا النصّ ترجمة إنجليزية؟ (يستخدمه الحارس والتشخيص)
  static bool hasTranslation(String arabic) =>
      kEnglish.containsKey(arabic) ||
      _flatEnglish.containsKey(_flatten(arabic));

  /// عدد النصوص المترجمة — للمعاينة في شاشة الإعدادات والتشخيص.
  static int get translationCount => kEnglish.length;

  /// يعيد قيمة صفّ قاعدة بيانات بلغة الواجهة مع سقوط للعربية.
  ///
  /// `localized(row, 'clothing_name')` يقرأ `clothing_name_en` إن كانت
  /// الواجهة إنجليزية **وكانت القيمة غير فارغة**، وإلا يعيد العربية.
  /// **الفراغ = العربي** مقصود: لا يُجبَر المستخدم على ترجمة كتالوجه يوم
  /// التحديث، وأي صنف غير مترجم يبقى مقروءًا.
  static String localized(
    Map<String, dynamic> row,
    String baseColumn, {
    bool? english,
  }) {
    final base = row[baseColumn]?.toString() ?? '';
    if (english ?? (language == AppLanguage.en)) {
      final en = row['${baseColumn}_en'];
      if (en != null) {
        final text = en.toString().trim();
        if (text.isNotEmpty) return text;
      }
      // 🚨 سقوط ثالث ضروري: صنف أُنشئ **قبل** وجود العمود الإنجليزي قيمته
      // `NULL`، فيبقى عربيًّا إلى الأبد ما لم يُعَد إدخاله يدويًّا. القاموس
      // يعرف أسماء الكتالوج الشائعة، فنعرضها بالإنجليزية بلا تدخّل المستخدم.
      final known = _dictionaryFor(base);
      if (known != null) return known;
    }
    return base;
  }

  /// يعيد النصّ الإنجليزي إن وُجد، وإلا النصّ العربي — بلا الحاجة إلى صفّ.
  ///
  /// تُستخدم في النماذج والكائنات (`ClothingModel.displayName` مثلًا) حيث
  /// لا يوجد `Map`. نفس قاعدة [localized]: الفراغ ليس ترجمة.
  static String pick(String arabic, String? english) {
    if (language == AppLanguage.en) {
      final text = (english ?? '').trim();
      if (text.isNotEmpty) return text;
      final known = _dictionaryFor(arabic);
      if (known != null) return known;
    }
    return arabic;
  }

  /// بحث القاموس عن قيمة بيانات (اسم صنف/تصنيف) — مطابقة حرفية ثم مُطبَّعة.
  static String? _dictionaryFor(String arabic) {
    if (arabic.isEmpty) return null;
    final exact = kEnglish[arabic];
    if (exact != null) return exact;
    return _flatEnglish[_flatten(arabic)];
  }
}

/// الاختصار الذي تناديه الواجهة: `Text(tr('حفظ'))`.
String tr(String arabic) => L10n.t(arabic);

/// نسخة مع رموز موضعية: `trf('إجمالي {0}', [total])`.
String trf(String arabic, List<Object?> args) => L10n.tf(arabic, args);

/// قيمة صفّ قاعدة بيانات بلغة الواجهة.
///
/// [english] يُمرَّر صريحًا حين لا تُقرأ حالة [L10n] — أهمّها مولّد الفاتورة
/// العامل داخل `compute` (عزل مستقلّ)، حيث اللغة تأتي من حمولة البيانات.
String localized(
  Map<String, dynamic> row,
  String baseColumn, {
  bool? english,
}) => L10n.localized(row, baseColumn, english: english);

/// نصّان لنفس القيمة: يُعرض الإنجليزي في الواجهة الإنجليزية إن كان غير فارغ.
String localizedText(String arabic, String? english) =>
    L10n.pick(arabic, english);
