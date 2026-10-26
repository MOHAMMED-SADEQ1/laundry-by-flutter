// سجل خطوط الطباعة — **منطق خالص** (بلا Flutter ولا قاعدة بيانات).
//
// مصدر واحد لكل خطّ يمكن اختياره لطباعة المستندات (فاتورة · كشف · وردية).
// لا نصّ اسم خطّ ولا مسار ملفّ يُكتب في أي مكان آخر: المولّدات تأخذ
// `pw.Font` جاهزًا، والواجهة تقرأ الأسماء والمسارات من هنا.
//
// ═══════════════════════════════════════════════════════════════════════════
// كيف اختيرت الخطوط؟ (لا ذوق شخصي — قياس على مسبار `_probe_print_fonts.dart`)
// ═══════════════════════════════════════════════════════════════════════════
// 1. كل خطّ هنا **رُسم فعلًا** بـ`pw.Font.ttf` ثم رُستر على 160 dpi ونُظر إليه:
//    الحروف العربية متّصلة، ولا مربّعات `.notdef`، ولا قطع رأسي.
// 2. **استُثني `TRAD.ttf`**: يرسم مربّعات فارغة تمامًا — ترميزه قديم
//    (Windows-1256) لا Unicode، فمحلّل `pdf` يقرأ المحارف خطأً.
// 3. **استُثني `DTHULUTH`**: خطّ عرض زخرفي، حروفه تُقتطع رأسيًا في سطر عادي
//    (الألف واللام تُبتر) — غير صالح لإيصال.
// 4. `thermal` ليست ذوقًا: الطابعة الحرارية تُحرق نقاطًا سوداء بلا تدرّج
//    رمادي، فكل ما هو **رفيع الحبر** (Light) يخرج أنقى، وما هو **عريض**
//    يلتحم على 8–10 نقطة. والقياس في المسبار: عرض السطر نفسه عند 9pt.
import 'package:laundry/config/constants.dart';

/// خطّ طباعة واحد.
class PrintFont {
  /// المفتاح المخزَّن في `settings` (لا يتغيّر — تغييره يُفقد اختيار المستخدم).
  final String key;

  /// الاسم المعروض.
  final String label;

  /// مسار ملفّ TTF داخل الحزمة (يُقرأ بـ`rootBundle`).
  final String asset;

  /// اسم العائلة في `pubspec.yaml` — لمعاينة الخطّ في الواجهة **بنفس الخطّ**.
  final String family;

  /// يُنصح به للطابعة الحرارية (خفيف الحبر · واضح عند 8–10pt).
  final bool thermal;

  /// يُنصح به للورق (A4/A5/A6).
  final bool paper;

  /// سبب التوصية أو التحذير — نصّ قصير يظهر في بطاقة الاختيار.
  final String note;

  const PrintFont({
    required this.key,
    required this.label,
    required this.asset,
    required this.family,
    required this.thermal,
    required this.paper,
    required this.note,
  });

  /// تسمية الاستخدام المعروضة («حراري وورق» · «حراري» · «ورق» · «زخرفي»).
  String get usageLabel {
    if (thermal && paper) return 'حراري وورق';
    if (thermal) return 'حراري';
    if (paper) return 'ورق';
    return 'زخرفي';
  }

  /// خطّ خفيف الحبر (المرشَّح الأول للحراري).
  bool get isLight => thermal && !paper;

  @override
  String toString() => 'PrintFont($key · $usageLabel)';
}

/// سجلّ خطوط الطباعة — **المصدر الوحيد**.
class PrintFonts {
  PrintFonts._();

  /// الخطّ الافتراضي — نفسه الذي كانت تطبعه النسخ السابقة.
  ///
  /// 🚨 تغييره يعني أن كل من لم يختر خطًّا ستتغيّر فواتيره. `verify_print_font`
  /// يثبّته على `al_mohanad` صراحةً.
  static const String defaultKey = 'al_mohanad';

  /// نصّ المعاينة في بطاقات الاختيار.
  static const String sample = 'مغاسل النظارة — فاتورة 1024';
  static const String sampleSmall = 'قيميص (غسيل) 3 × 10.00 = 30.00 ر.س';

  /// كل الخطوط المتاحة، **مرتَّبة**: الافتراضي أولًا ثم الأقرب للحراري.
  static const List<PrintFont> all = <PrintFont>[
    PrintFont(
      key: 'al_mohanad',
      label: 'المهنّد (الافتراضي)',
      asset: 'assets/fonts/Noto/AL-Mohanad.ttf',
      family: 'noto',
      thermal: true,
      paper: true,
      note: 'خفيف الحبر جدًا · أقل التصاقًا على الحراري · هو خطّ النظام الحالي',
    ),
    PrintFont(
      key: 'ibm_plex_light',
      label: 'IBM Plex — خفيف',
      asset: 'assets/fonts/IBMPlex/IBMPlexSansArabic-Light.ttf',
      family: 'ibmPlexLight',
      thermal: true,
      paper: false,
      note: 'الأخفّ حبرًا · صُمّم للقراءة الصغيرة · الأنقى على 80 مم',
    ),
    PrintFont(
      key: 'almarai_light',
      label: 'المراعي — خفيف',
      asset: 'assets/fonts/Almarai/Almarai-Light.ttf',
      family: 'almaraiLight',
      thermal: true,
      paper: false,
      note: 'خفيف وواسع · ارتفاع سطر مريح · ممتاز للحراري',
    ),
    PrintFont(
      key: 'ibm_plex',
      label: 'IBM Plex',
      asset: 'assets/fonts/IBMPlex/IBMPlexSansArabic-Regular.ttf',
      family: 'ibmPlex',
      thermal: true,
      paper: true,
      note: 'هندسي تقني · أرقام لاتينية واضحة لا تلتبس',
    ),
    PrintFont(
      key: 'noto_sans',
      label: 'نوتو سانس',
      asset: 'assets/fonts/Noto/NotoSansArabic-Regular.ttf',
      family: 'notoSans',
      thermal: true,
      paper: true,
      note: 'خطّ جوجل العالمي · أفضل توازن بين الخفّة والوضوح',
    ),
    PrintFont(
      key: 'noto_naskh',
      label: 'نسخ نوتو',
      asset: 'assets/fonts/Noto/NotoNaskhArabic-Regular.ttf',
      family: 'notoNaskh',
      thermal: true,
      paper: true,
      note: 'ناسخ عالمي · أوضح للعين · حبره أثقل قليلًا من سانس',
    ),
    PrintFont(
      key: 'tajawal',
      label: 'تجوال',
      asset: 'assets/fonts/Tajawal/Tajawal-Regular.ttf',
      family: 'tajawal',
      thermal: true,
      paper: true,
      note: 'الأضيق عرضًا · يوفّر مساحة على 58 مم ويقلّل الأسطر',
    ),
    PrintFont(
      key: 'almarai',
      label: 'المراعي',
      asset: 'assets/fonts/Almarai/Almarai-Regular.ttf',
      family: 'almarai',
      thermal: true,
      paper: true,
      note: 'نظيف ومقروء · متوسّط الحبر',
    ),
    PrintFont(
      key: 'cairo',
      label: 'القاهرة',
      asset: 'assets/fonts/Cairo/Cairo-Medium.ttf',
      family: 'cairo',
      thermal: false,
      paper: true,
      note: 'متوسّط الثقل · جميل على الورق · يُلتحم على الحراري الضيق',
    ),
    PrintFont(
      key: 'noto_kufi',
      label: 'كوفي نوتو',
      asset: 'assets/fonts/Noto/NotoKufiArabic-Regular.ttf',
      family: 'notoKufi',
      thermal: false,
      paper: true,
      note: 'كوفي هندسي عريض · للعناوين والورق لا للحراري',
    ),
    PrintFont(
      key: 'amiri',
      label: 'أميري',
      asset: 'assets/fonts/Amiri/Amiri-Regular.ttf',
      family: 'amiri',
      thermal: false,
      paper: true,
      note: 'ناسخ كلاسيكي رسمي · ثقيل الحبر · للفواتير الورقية الفخمة',
    ),
  ];

  /// الخطوط الموصى بها للحراري (مرتَّبة).
  static List<PrintFont> get forThermal =>
      all.where((f) => f.thermal).toList(growable: false);

  /// الخطوط الموصى بها للورق (مرتَّبة).
  static List<PrintFont> get forPaper =>
      all.where((f) => f.paper).toList(growable: false);

  /// الخطّ بالمفتاح، أو الافتراضي إن كان المفتاح مجهولًا.
  ///
  /// 🚨 **لا ترمي أبدًا**: مفتاح قديم أو تالف في `settings` يجب ألا يمنع
  /// طباعة فاتورة — يُطبع بالافتراضي ويُنبَّه في السجلّ.
  static PrintFont byKey(String? key) {
    final k = (key ?? '').trim();
    for (final f in all) {
      if (f.key == k) return f;
    }
    return byKey(defaultKey);
  }

  /// هل المفتاح معروف؟ (تستخدمه الإعدادات لتنظيف قيمة قديمة)
  static bool isKnown(String? key) => all.any((f) => f.key == (key ?? '').trim());

  /// مفتاح الخطّ الافتراضي — مربوط بـ`AppConstants` في الحارس.
  static String get settingKey => AppConstants.settingPrintFont;
}
