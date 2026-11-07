/// **قالب المستند** — منطق خالص (بلا Flutter ولا قاعدة) قابل للاختبار.
///
/// ## الفكرة
/// كان تصميم الفاتورة وكشف الحساب مكتوبًا في الكود: كل صفّ نصّه ثابت
/// (`'رقم الإيصال: '` · `'التاريخ: '` …) وقرار إظهاره مبعثرًا بين
/// `if` في مولّد الـPDF وخيارات متفرّقة بعضها **ميّت**. فيستحيل على صاحب
/// النشاط تغيير كلمة واحدة أو إخفاء سطر.
///
/// هنا سجلّ واحد لكل مستند: **حقل ⇒ (مُفعَّل؟ · نصّه · نمطه)**. والمولّد يقرأ
/// منه فقط، فلا يبقى نصّ مكتوب في الكود. إضافة حقل جديد = سطر واحد في السجل.
///
/// ## التخزين
/// مستند JSON واحد لكل قالب في جدول `settings`
/// (`doc_template_invoice` · `doc_template_statement` · `doc_template_shift` ·
/// `doc_template_laundry_slip`).
/// **لا** يُسجَّل في `SettingOptions` عمدًا: لا نريد حقل JSON خامًّا في شاشة
/// الإعدادات العامة؛ تحريره من شاشة «قوالب الطباعة» المخصّصة.
library;

import 'package:laundry/services/i18n/l10n.dart';
import 'package:laundry/services/pdf/arabic_text.dart';

/// أقسام المحرّر — تجميع بصري فقط.
class DocSections {
  DocSections._();
  static const String header = 'الترويسة';
  static const String body = 'تفاصيل المستند';
  static const String totals = 'الإجماليات';
  static const String footer = 'التذييل';

  static const List<String> ordered = <String>[header, body, totals, footer];
}

/// **نمط كتابة حقل**: الحجم · الوزن · العرض.
///
/// ## لماذا ثلاثة محاور لا واحد؟
/// طلب المستخدم (2026-10-24): «التحكم في حجم الخط وعرضه ووزنه». والمحاور
/// الثلاثة **مستقلّة فعليًا**، كلٌّ بآلية مختلفة في حزمة `pdf`:
///
///   • **الحجم** → `fontSize` (نقطة). مباشر.
///   • **الوزن** → **تعريض صناعي**: الخط `AL-Mohanad` بوزن واحد، وحزمة `pdf`
///     لا تُنحّف الحروف. فالطريقة الوحيدة التي لا تغيّر شكل الحرف هي رسم
///     السطر مرّتين بإزاحة أفقية صغيرة ([boldOffset]) — وهي ما تفعله
///     المتصفّحات نفسها (faux bold). أُثبتت بمسبار
///     `tool/_probe_weight_width.dart` ثم بالعين على 220 dpi.
///   • **العرض** → **تمديد أفقي** (`widthScale`) لا تباعد حروف.
///
/// 🚨 **لماذا ليس `letterSpacing` للعرض؟** لأنه **يكسر اتصال الحروف
/// العربية**: «ضريبية» تصير «ض ر ي ب ي ة» — أُثبت بالمسبار نفسه
/// (`_probe_font_weight.dart`، سطر العرض 130%). والتمديد الأفقي يُوسّع
/// الحرف نفسه فيبقى متّصلًا.
class DocStyle {
  /// الحجم بالنقطة.
  final double size;

  /// الوزن: 400 · 600 · 700 · 900.
  final int weight;

  /// العرض كنسبة مئوية: 75 … 100 (100 = طبيعي · أصغر = أضيق).
  ///
  /// 🚨 **لا توسيع فوق 100%** — قياس PyMuPDF على `invoice_extreme.pdf`:
  /// `pw.Transform` **يرسم فقط ولا يشارك في التخطيط**، فسطر يشغل عرضه كاملًا
  /// ويتضخّم 140% يخرج 20% من كل جهة **خارج الورقة** (`x0=-39.9` على صفحة
  /// 595) ويتداخل مع الخلية المجاورة في الصفوف. والتضييق لا يخرج أبدًا
  /// (المحتوى أضيق من صندوقه). ومن أراد خطًّا أعرض رفع الحجم.
  final int width;

  const DocStyle({this.size = 12, this.weight = 400, this.width = 100});

  /// مستويات الوزن المعروضة (المصدر الوحيد للواجهة والحراس).
  static const List<int> weights = <int>[400, 600, 700, 900];

  /// حدود الحجم المعقولة — خارجه يخرج النصّ عن الورقة أو يصير غير مقروء.
  static const double minSize = 6;

  /// 🚨 **36 لا 48** — الحدّ محسوب لا تعسّفي.
  ///
  /// أطول سطر لا يقبل الالتفاف في الفاتورة (رقم الإيصال · السجل التجاري)
  /// يشغل 655.9 نقطة عند 48 مع عرض 140%، والعرض القابل للطباعة في A4 بهامش
  /// 1 سم هو 538.6 نقطة. عند 48 كان يُقتطع **خارج الورقة** (قياس PyMuPDF:
  /// `x0=-20.6 … x1=635.3` على صفحة 595). أكبر حجم يتّسع = 48 × 538.6/655.9
  /// ≈ 39، فاخترنا 36 بهامش أمان 8%. وحارس `verify_doc_template.dart`
  /// يعيد حساب هذه المعادلة من هامش الصفحة فلا تعود القيمة للصعود بصمت.
  static const double maxSize = 36;

  /// حدود العرض — تضييق فقط (انظر [width]).
  static const int minWidth = 75;
  static const int maxWidth = 100;

  /// إزاحة التعريض الصناعي بالنقطة = الحجم × معامل الوزن.
  ///
  /// المعاملات مُعايَرة بصريًا على 220 dpi (المسبار): 0.25 · 0.45 · 0.70
  /// عند 20pt ⇒ 0.0125 · 0.0225 · 0.035.
  double get boldOffset {
    final f =
        switch (weight) {
          600 => 0.0125,
          700 => 0.0225,
          900 => 0.035,
          _ => 0.0,
        };
    return size * f;
  }

  /// معامل التمديد الأفقي.
  double get widthScale => width / 100;

  /// هل هو النمط الافتراضي «بلا تعريض ولا تمديد»؟
  bool get isPlain => weight == 400 && width == 100;

  /// نسخة معدَّلة.
  DocStyle copyWith({double? size, int? weight, int? width}) => DocStyle(
    size: size ?? this.size,
    weight: weight ?? this.weight,
    width: width ?? this.width,
  );

  /// يُقيَّد داخل الحدود ويُقرَّب الوزن لأقرب مستوى معروف.
  ///
  /// **لماذا؟** لأن القالب يُخزَّن JSON ويُقرأ من ملف قد يُحرَّر يدويًا أو
  /// يُستعاد من نسخة احتياطية قديمة. قيمة شاذّة (0 أو 999) يجب ألّا تُخرج
  /// ورقة بيضاء أو ترمي استثناءً أثناء الطباعة.
  DocStyle clamped() {
    final s = size.isFinite ? size.clamp(minSize, maxSize).toDouble() : 12.0;
    var w = weights.first;
    var best = double.infinity;
    for (final candidate in weights) {
      final d = (candidate - weight).abs().toDouble();
      if (d < best) {
        best = d;
        w = candidate;
      }
    }
    return DocStyle(
      size: s,
      weight: w,
      width: width.clamp(minWidth, maxWidth),
    );
  }

  /// وصف الوزن للواجهة.
  String get weightLabel =>
      switch (weight) {
        600 => 'متوسط',
        700 => 'عريض',
        900 => 'عريض جدًا',
        _ => 'عادي',
      };

  Map<String, dynamic> toJson() => <String, dynamic>{
    'size': size,
    'weight': weight,
    'width': width,
  };

  /// من JSON — متسامح: أي قيمة مفقودة أو خاطئة تعود إلى [fallback].
  factory DocStyle.fromJson(Map? json, DocStyle fallback) {
    if (json == null) return fallback;
    final s = json['size'];
    final w = json['weight'];
    final d = json['width'];
    if (s is! num || w is! num || d is! num) return fallback;
    return DocStyle(
      size: s.toDouble(),
      weight: w.toInt(),
      width: d.toInt(),
    ).clamped();
  }

  /// من مصفوفة النقل `[size, weight, width]` (أنواع أوّلية عبر العزل).
  factory DocStyle.fromTransport(Object? raw, DocStyle fallback) {
    if (raw is! List || raw.length < 3) return fallback;
    final s = raw[0];
    final w = raw[1];
    final d = raw[2];
    if (s is! num || w is! num || d is! num) return fallback;
    return DocStyle(
      size: s.toDouble(),
      weight: w.toInt(),
      width: d.toInt(),
    ).clamped();
  }

  /// للتمرير عبر `compute` — مصفوفة أرقام فقط.
  List<num> toTransport() => <num>[size, weight, width];

  @override
  bool operator ==(Object other) =>
      other is DocStyle &&
      other.size == size &&
      other.weight == weight &&
      other.width == width;

  @override
  int get hashCode => Object.hash(size, weight, width);

  @override
  String toString() => 'DocStyle($size pt · $weightLabel · $width%)';
}

/// حقل واحد في قالب المستند.
class DocField {
  /// المعرّف الثابت (يُخزَّن في JSON — **لا تُغيّره** بعد النشر).
  final String key;

  /// الاسم المعروض في المحرّر.
  final String label;

  /// شرح مختصر يظهر تحت الاسم.
  final String hint;

  /// القسم في المحرّر.
  final String section;

  /// هل للحقل **نصّ قابل للتعديل**؟ (بعض الحقول مجرّد إظهار/إخفاء).
  final bool hasText;

  /// النصّ الافتراضي (قد يكون فارغًا = بلا بادئة).
  final String defaultText;

  /// مُفعَّل افتراضيًا؟
  final bool defaultEnabled;

  /// النمط الافتراضي (حجم · وزن · عرض).
  ///
  /// ⚠️ **الوزن الافتراضي 400 في كل الحقول عن قصد**: الكود القديم كان يمرّر
  /// `fontWeight: pw.FontWeight.bold` في كل نصّ تقريبًا، لكنه **بلا أثر**
  /// لأن كل `TextStyle` يمرّر `font:` صريحًا و`pdf` تحسم الوجه بـ
  /// `style.font!.getFont(context)` (text.dart:170) — فالفاتورة المطبوعة
  /// اليوم **كلها بوزن عادي**. لو جعلنا الافتراضي عريضًا لتغيّر شكل كل
  /// فاتورة قائمة بعد التحديث. فالتعريض الآن **قرار المستخدم** وحده.
  final DocStyle style;

  /// هل للحقل نصّ **يُرسم** فيمكن ضبط نمطه؟ (الشعار والصور وQR لا).
  final bool hasStyle;

  /// مفتاح الخيار القديم **المنطقي** في `SettingOptions` (إن وُجد).
  ///
  /// **لماذا هنا؟** لأن هوية الحقل ومرادفه القديم معلومتان في مكان واحد،
  /// فنقدر نزرع القالب من إعدادات المستخدم الحالية عند أول تحميل، ونُزامن
  /// أي تعديل من شاشة الإعدادات القديمة إلى القالب — بلا جدول ربط منفصل
  /// يفصل بينهما فينسى أحدهما.
  ///
  /// ⚠️ منفصل عن [legacyText] لأن بعض الحقول لها **مرادف منطقي ونصّي معًا**
  /// (الرقم الضريبي: مفتاح إظهار + بادئة نصّية) — ولو جمعناهما في حقل واحد
  /// لاحتاج الأمر تخمينًا من نوع القيمة.
  final String? legacyToggle;

  /// مفتاح الخيار القديم **النصّي** (عنوان الفاتورة · التذييل).
  final String? legacyText;

  const DocField({
    required this.key,
    required this.label,
    required this.section,
    this.hint = '',
    this.hasText = false,
    this.defaultText = '',
    this.defaultEnabled = true,
    this.style = const DocStyle(),
    this.hasStyle = true,
    this.legacyToggle,
    this.legacyText,
  });

  /// هل لهذا الحقل مرادف قديم (منطقي أو نصّي)؟
  bool get hasLegacy => legacyToggle != null || legacyText != null;
}

/// نوع المستند — لكل نوع سجلّ حقول مستقل.
enum DocKind { invoice, statement, shift, laundrySlip }

/// القيمة الفعلية لحقل: مُفعَّل؟ + النص.
class DocFieldValue {
  final bool enabled;
  final String text;
  const DocFieldValue({required this.enabled, required this.text});
}

/// قالب مستند كامل.
class DocTemplate {
  final DocKind kind;

  /// `key` ⇒ مُفعَّل.
  final Map<String, bool> enabled;

  /// `key` ⇒ النصّ (لحقول [DocField.hasText]).
  final Map<String, String> texts;

  /// `key` ⇒ النمط (حجم · وزن · عرض).
  final Map<String, DocStyle> styles;

  const DocTemplate({
    required this.kind,
    required this.enabled,
    required this.texts,
    required this.styles,
  });

  /// القالب الافتراضي (المطابق للسلوك الحالي تمامًا).
  factory DocTemplate.defaults(DocKind kind) {
    final en = <String, bool>{};
    final tx = <String, String>{};
    final st = <String, DocStyle>{};
    for (final f in DocCatalog.fieldsOf(kind)) {
      en[f.key] = f.defaultEnabled;
      st[f.key] = f.style;
      if (f.hasText) tx[f.key] = f.defaultText;
    }
    return DocTemplate(kind: kind, enabled: en, texts: tx, styles: st);
  }

  /// مُفعَّل؟ — **الغياب = مُفعَّل** (لا نُخفي شيئًا بلا قرار صريح).
  bool isOn(String key) => enabled[key] ?? true;

  /// النصّ: المخزَّن إن كان غير فارغ، وإلا الافتراضي من السجلّ.
  ///
  /// **لماذا ليس العكس؟** لأن المستخدم قد يريد **حذف** نصّ (بادئة بلا كلمة)
  /// فيكتب فراغًا — لكن الفراغ أيضًا هو حالة «لم يُحرَّر بعد». فاصلنا:
  /// النصّ الفارغ يعني «استخدم الافتراضي»، ولإخفاء السطر كاملًا يُعطَّل
  /// الحقل. هذا يمنع مستندًا بلا عناوين بسبب حقل تُرك فارغًا سهوًا.
  String textOf(String key, [String? fallback]) {
    final v = texts[key];
    if (v != null && v.trim().isNotEmpty) return v;
    if (fallback != null) return fallback;
    return DocCatalog.fieldOf(kind, key)?.defaultText ?? '';
  }

  /// النمط: المخزَّن، وإلا افتراضي السجلّ.
  DocStyle styleOf(String key) =>
      styles[key] ?? DocCatalog.fieldOf(kind, key)?.style ?? const DocStyle();

  /// نسخة بحقل واحد معدَّل.
  DocTemplate withField(
    String key, {
    bool? enabled,
    String? text,
    DocStyle? style,
  }) {
    final en = Map<String, bool>.from(this.enabled);
    final tx = Map<String, String>.from(texts);
    final st = Map<String, DocStyle>.from(styles);
    if (enabled != null) en[key] = enabled;
    if (text != null) tx[key] = text;
    if (style != null) st[key] = style.clamped();
    return DocTemplate(kind: kind, enabled: en, texts: tx, styles: st);
  }

  /// يطبّق نمطًا واحدًا على **كل حقول قسم** — «حجم موحّد للقسم».
  DocTemplate withSectionStyle(String section, DocStyle style) {
    final st = Map<String, DocStyle>.from(styles);
    for (final f in DocCatalog.fieldsIn(kind, section)) {
      if (!f.hasStyle) continue;
      st[f.key] = style.clamped();
    }
    return DocTemplate(kind: kind, enabled: enabled, texts: texts, styles: st);
  }

  /// نسخة بحقول كثيرة معدَّلة دفعةً واحدة (زرّ «الكل»).
  DocTemplate withAllEnabled(bool value, {Iterable<String>? keys}) {
    final en = Map<String, bool>.from(enabled);
    for (final f in DocCatalog.fieldsOf(kind)) {
      if (keys != null && !keys.contains(f.key)) continue;
      en[f.key] = value;
    }
    return DocTemplate(kind: kind, enabled: en, texts: texts, styles: styles);
  }

  /// يزرع القالب من قيم الإعدادات القديمة (`legacy key` ⇒ نصّ خام).
  ///
  /// **يُستخدم مرة واحدة فقط** عند غياب قالب محفوظ: فنبدأ من الشكل الذي
  /// يراه المستخدم اليوم بدل أن تُفاجئه فاتورة مختلفة بعد التحديث.
  ///
  /// القيم المنطقية تُقرأ بـ`'1'` (أي نصّ آخر = معطَّل)، والنصّية تُنسخ كما
  /// هي بلا قصّ — إلا الفراغ فلا يُكتب كي يبقى الافتراضي فعّالًا.
  DocTemplate seededFromLegacy(Map<String, String> legacy) {
    if (legacy.isEmpty) return this;
    var t = this;
    for (final f in DocCatalog.legacyFields(kind)) {
      final raw = legacy[f.legacyToggle ?? f.legacyText ?? ''];
      if (raw == null) continue;
      final v = raw.trim();
      if (f.legacyToggle != null) {
        t = t.withField(f.key, enabled: v == '1' || v.toLowerCase() == 'true');
      } else if (v.isNotEmpty) {
        t = t.withField(f.key, text: v);
      }
    }
    return t;
  }

  /// هل عُدِّل شيء عن الافتراضي؟
  bool get isModified {
    final d = DocTemplate.defaults(kind);
    for (final f in DocCatalog.fieldsOf(kind)) {
      if (isOn(f.key) != d.isOn(f.key)) return true;
      if (f.hasText && textOf(f.key) != d.textOf(f.key)) return true;
      if (f.hasStyle && styleOf(f.key) != d.styleOf(f.key)) return true;
    }
    return false;
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'kind': kind.name,
    'enabled': enabled,
    'texts': texts,
    'styles': <String, dynamic>{
      for (final e in styles.entries) e.key: e.value.toJson(),
    },
  };

  /// من JSON — **متسامح**: أي مفتاح مفقود أو نوع خاطئ يعود للافتراضي،
  /// فلا يُفسد قالبٌ تالفٌ الطباعة.
  factory DocTemplate.fromJson(DocKind kind, Map? json) {
    final base = DocTemplate.defaults(kind);
    if (json == null) return base;

    final en = Map<String, bool>.from(base.enabled);
    final rawEn = json['enabled'];
    if (rawEn is Map) {
      for (final f in DocCatalog.fieldsOf(kind)) {
        final v = rawEn[f.key];
        if (v is bool) en[f.key] = v;
      }
    }

    final tx = Map<String, String>.from(base.texts);
    final rawTx = json['texts'];
    if (rawTx is Map) {
      for (final f in DocCatalog.fieldsOf(kind)) {
        if (!f.hasText) continue;
        final v = rawTx[f.key];
        if (v is String) tx[f.key] = v;
      }
    }

    final st = Map<String, DocStyle>.from(base.styles);
    final rawSt = json['styles'];
    if (rawSt is Map) {
      for (final f in DocCatalog.fieldsOf(kind)) {
        if (!f.hasStyle) continue;
        final v = rawSt[f.key];
        if (v is Map) st[f.key] = DocStyle.fromJson(v, f.style);
      }
    }

    return DocTemplate(kind: kind, enabled: en, texts: tx, styles: st);
  }

  /// خريطة للتمرير إلى `compute` (عزل) — أنواع أوّلية فقط.
  ///
  /// 🚨 **المفاتيح `docEnabled` و`docTexts` و`docStyles` هي العقد مع
  /// [DocTemplateView]** — لا `enabled`/`texts`/`styles`. أُصلح 2026-10-23
  /// بعد أن كشف اختبار التوليد أن القالب لم يكن يُقرأ إطلاقًا: كل مستند كان
  /// يخرج بالافتراضي، والأسوأ أن الخطأ **صامت** (لا استثناء ولا فرق في
  /// الحجم) لأن العرض يرجع للسجلّ.
  Map<String, dynamic> toTransport() => <String, dynamic>{
    'docEnabled': Map<String, bool>.from(enabled),
    'docTexts': Map<String, String>.from(texts),
    'docStyles': <String, dynamic>{
      for (final e in styles.entries) e.key: e.value.toTransport(),
    },
  };
}

/// سجلّ الحقول لكل نوع مستند — **المصدر الوحيد**.
class DocCatalog {
  DocCatalog._();

  static const String invoiceTitleDefault = 'فاتورة ضريبية مبسطة';
  static const String statementTitleDefault = 'كشف حساب زبون';
  static const String statementFooterDefault =
      '--- هذا الكشف صادر آليًا من النظام ---';
  static const String shiftTitleDefault = 'ملخص الوردية';
  static const String shiftFooterDefault = '--- شكراً لكم ---';
  static const String slipTitleDefault = 'ورقة المغسلة';
  static const String slipSubtitleDefault = 'نسخة المحل';
  static const String slipNoticeDefault = 'لا تُسلَّم للعميل - تُرفق بالكيس';

  /// مفاتيح مشتركة بين المستندات (نفس المعنى).
  static const String kLogo = 'logo';
  static const String kBusinessName = 'business_name';
  static const String kBusinessAddress = 'business_address';
  static const String kTaxNumber = 'tax_number';
  static const String kCrNumber = 'cr_number';
  static const String kShortAddress = 'short_address';
  static const String kTitle = 'title';
  static const String kPhoneLine = 'phone_line';
  static const String kDivider = 'divider';
  static const String kFooter = 'footer';
  static const String kCurrency = 'currency';
  static const String kCustomerName = 'customer_name';
  static const String kCustomerPhone = 'customer_phone';

  /// الفاتورة فقط.
  static const String kReceiptNo = 'receipt_no';
  static const String kDatetime = 'datetime';
  static const String kCashier = 'cashier';
  static const String kPickupCode = 'pickup_code';
  static const String kQr = 'qr';
  static const String kPhotos = 'photos';
  static const String kItemNote = 'item_note';
  static const String kItemLine = 'item_line';
  static const String kItemPrice = 'item_price';
  static const String kDiscount = 'discount';
  static const String kTaxBase = 'tax_base';
  static const String kTaxLine = 'tax_line';
  static const String kPaid = 'paid';
  static const String kRemaining = 'remaining';
  static const String kGross = 'gross';
  static const String kDue = 'due';
  static const String kSum = 'sum';
  static const String kTotalAmount = 'total_amount';
  static const String kSubsBadge = 'subs_badge';
  static const String kSubsNote = 'subs_note';

  /// كشف الحساب فقط.
  static const String kPeriod = 'period';
  static const String kPrintedAt = 'printed_at';
  static const String kItemsTable = 'items_table';
  static const String kInvoicesTable = 'invoices_table';
  static const String kUsagesTable = 'usages_table';
  static const String kPaymentsTable = 'payments_table';
  static const String kTotals = 'totals';
  static const String kSectionTitle = 'section_title';
  static const String kSummaryTitle = 'summary_title';
  static const String kSummaryTitlePeriod = 'summary_title_period';
  static const String kTotalsPurchases = 'totals_purchases';
  static const String kTotalsPaid = 'totals_paid';
  static const String kTotalsDebt = 'totals_debt';
  static const String kTotalsCredit = 'totals_credit';
  static const String kTotalsNet = 'totals_net';
  static const String kTotalsPieces = 'totals_pieces';
  static const String kTotalsSubPieces = 'totals_sub_pieces';
  static const String kTotalsSubValue = 'totals_sub_value';

  /// ملخّص الوردية فقط.
  static const String kShiftId = 'shift_id';
  static const String kStartTime = 'start_time';
  static const String kEndTime = 'end_time';
  static const String kInvoiceCount = 'invoice_count';
  static const String kTotalCash = 'total_cash';
  static const String kTotalNetwork = 'total_network';

  /// ورقة المغسلة فقط — الحقول المشتركة (الشعار · اسم النشاط · العنوان ·
  /// رقم الفاتورة · التاريخ · العميل · رمز الاستلام) تُعاد هنا بنفس المفاتيح.
  static const String kSlipSubtitle = 'slip_subtitle';
  static const String kSlipNotice = 'slip_notice';
  static const String kItemName = 'item_name';
  static const String kService = 'service';
  static const String kQty = 'qty';
  static const String kEmptyItems = 'empty_items';
  static const String kTotalPieces = 'total_pieces';
  static const String kItemsCount = 'items_count';
  static const String kWorkerSignature = 'worker_signature';
  static const String kNotesSignature = 'notes_signature';
  static const String kBusinessPhone = 'business_phone';

  /// رمز QR لموقع النشاط — مشترك بين الفاتورة وكشف الحساب (كلاهما ورقة
  /// تُسلَّم للزبون). **لا يُضاف إلى ملخّص الوردية ولا ورقة المغسلة**:
  /// كلاهما مستند داخلي لا يخرج من المحل، فرمز خريطة فيهما ضجيج لا فائدة.
  static const String kMapQr = 'map_qr';

  /// النصّ الافتراضي أسفل رمز الموقع.
  static const String mapQrDefaultText = 'امسح الرمز للوصول إلى موقعنا';

  static const List<DocField> invoiceFields = <DocField>[
    // ── الترويسة ──
    DocField(
      key: kLogo,
      label: 'شعار النشاط',
      hint: 'صورة الشعار أعلى المستند.',
      section: DocSections.header,
      hasStyle: false,
      legacyToggle: 'invoice_show_logo',
    ),
    DocField(
      key: kBusinessName,
      label: 'اسم النشاط',
      hint: 'اتركه فارغًا لاستخدام الاسم من «معلومات النشاط».',
      section: DocSections.header,
      hasText: true,
      style: DocStyle(size: 27),
    ),
    DocField(
      key: kBusinessAddress,
      label: 'عنوان النشاط',
      hint: 'اتركه فارغًا لاستخدام العنوان المسجَّل.',
      section: DocSections.header,
      hasText: true,
      style: DocStyle(size: 22),
    ),
    DocField(
      key: kTitle,
      label: 'عنوان المستند',
      hint: 'مثل: فاتورة ضريبية مبسطة.',
      section: DocSections.header,
      hasText: true,
      defaultText: invoiceTitleDefault,
      style: DocStyle(size: 27),
      legacyText: 'invoice_title_text',
    ),
    DocField(
      key: kTaxNumber,
      label: 'الرقم الضريبي',
      hint: 'البادئة قبل الرقم. الرقم نفسه من «معلومات النشاط».',
      section: DocSections.header,
      hasText: true,
      defaultText: 'الرقم الضريبي',
      style: DocStyle(size: 20),
      legacyToggle: 'invoice_show_tax_number',
    ),
    DocField(
      key: kCrNumber,
      label: 'السجل التجاري',
      hint: 'البادئة قبل الرقم.',
      section: DocSections.header,
      hasText: true,
      defaultText: 'السجل التجاري',
      style: DocStyle(size: 27),
      legacyToggle: 'invoice_show_cr_number',
    ),
    DocField(
      key: kShortAddress,
      label: 'العنوان الوطني',
      hint: 'يظهر فقط إن كان مسجَّلًا في معلومات النشاط.',
      section: DocSections.header,
      hasText: true,
      defaultText: 'العنوان الوطني',
      defaultEnabled: false,
      style: DocStyle(size: 27),
      legacyToggle: 'invoice_show_short_address',
    ),
    DocField(
      key: kPhoneLine,
      label: 'سطر الهاتف',
      hint: 'نصّ يظهر قبل رقم الهاتف.',
      section: DocSections.header,
      hasText: true,
      defaultText: 'نسعد بتواصلكم عبر الأرقام:',
      style: DocStyle(size: 27),
    ),
    DocField(
      key: kDivider,
      label: 'الخط الفاصل',
      hint: 'الخط النصّي الفاصل بين الترويسة والأصناف.',
      section: DocSections.header,
      hasStyle: false,
    ),
    DocField(
      key: kQr,
      label: 'رمز QR (زاتكا)',
      hint: 'يُطبع فقط عند وجود رقم ضريبي.',
      section: DocSections.header,
      hasStyle: false,
      legacyToggle: 'invoice_show_qr',
    ),
    // ── تفاصيل ──
    DocField(
      key: kReceiptNo,
      label: 'رقم الإيصال',
      hint: 'البادئة قبل الرقم.',
      section: DocSections.body,
      hasText: true,
      defaultText: 'رقم الإيصال',
      style: DocStyle(size: 27),
    ),
    DocField(
      key: kDatetime,
      label: 'التاريخ والوقت',
      hint: 'البادئة قبل التاريخ.',
      section: DocSections.body,
      hasText: true,
      defaultText: 'التاريخ',
      style: DocStyle(size: 27),
      legacyToggle: 'invoice_show_datetime',
    ),
    DocField(
      key: kCashier,
      label: 'اسم المستخدم',
      hint: 'البادئة قبل اسم من أصدر الفاتورة.',
      section: DocSections.body,
      hasText: true,
      defaultText: 'صدر بواسطة',
      style: DocStyle(size: 20),
      legacyToggle: 'invoice_show_cashier',
    ),
    DocField(
      key: kCustomerName,
      label: 'اسم العميل',
      hint: 'البادئة قبل اسم الزبون.',
      section: DocSections.body,
      hasText: true,
      defaultText: 'اسم العميل',
      style: DocStyle(size: 27),
    ),
    DocField(
      key: kCustomerPhone,
      label: 'هاتف العميل',
      hint: 'البادئة قبل رقم هاتف الزبون.',
      section: DocSections.body,
      hasText: true,
      defaultText: 'الهاتف',
      defaultEnabled: false,
      style: DocStyle(size: 20),
      legacyToggle: 'invoice_show_customer_phone',
    ),
    DocField(
      key: kPickupCode,
      label: 'رمز الاستلام',
      hint: 'البادئة قبل رمز استلام القطع.',
      section: DocSections.body,
      hasText: true,
      defaultText: 'رمز الاستلام',
      // كان مُعرَّفًا في الإعدادات ولا يُقرأ في أي موضع — يُفعَّل الآن
      // افتراضيًا **معطَّلًا** كي لا يتغيّر شكل فواتير قائمة بلا طلب.
      defaultEnabled: false,
      style: DocStyle(size: 27),
      legacyToggle: 'invoice_show_pickup_code',
    ),
    DocField(
      key: kPhotos,
      label: 'صور القطع',
      hint: 'صور البقع المرفقة ببنود الفاتورة.',
      section: DocSections.body,
      hasStyle: false,
    ),
    DocField(
      key: kItemLine,
      label: 'سطر الصنف',
      hint: 'اسم القطعة ونوعها في قائمة الأصناف.',
      section: DocSections.body,
      style: DocStyle(size: 27),
    ),
    DocField(
      key: kItemPrice,
      label: 'سعر وعدد الصنف',
      hint: 'السعر الإجمالي وسطر «السعر × العدد».',
      section: DocSections.body,
      style: DocStyle(size: 24),
    ),
    DocField(
      key: kItemNote,
      label: 'بادئة ملاحظة البند',
      hint: 'الكلمة قبل ملاحظة القطعة (مثل: ملاحظة).',
      section: DocSections.body,
      hasText: true,
      defaultText: 'ملاحظة',
      style: DocStyle(size: 20),
    ),
    // ── الإجماليات ──
    DocField(
      key: kGross,
      label: 'الإجمالي قبل الخصم',
      hint: 'سطر يظهر فقط عند وجود خصم.',
      section: DocSections.totals,
      hasText: true,
      defaultText: 'الإجمالي قبل الخصم',
      style: DocStyle(size: 20),
    ),
    DocField(
      key: kDiscount,
      label: 'سطر الخصم',
      hint: 'البادئة قبل مبلغ الخصم.',
      section: DocSections.totals,
      hasText: true,
      defaultText: 'الخصم',
      style: DocStyle(size: 20),
      legacyToggle: 'invoice_show_discount_line',
    ),
    DocField(
      key: kTaxBase,
      label: 'الأساس الخاضع للضريبة',
      hint: 'سطر المبلغ قبل الضريبة.',
      section: DocSections.totals,
      hasText: true,
      defaultText: 'الأساس الخاضع للضريبة',
      style: DocStyle(size: 20),
      legacyToggle: 'invoice_show_tax_base',
    ),
    DocField(
      key: kTaxLine,
      label: 'سطر الضريبة',
      hint: 'البادئة قبل مبلغ الضريبة (تُضاف النسبة آليًا).',
      section: DocSections.totals,
      hasText: true,
      defaultText: 'ضريبة القيمة المضافة',
      style: DocStyle(size: 20),
      legacyToggle: 'invoice_show_tax_line',
    ),
    DocField(
      key: kPaid,
      label: 'المدفوع',
      hint: 'البادئة قبل المبلغ المدفوع.',
      section: DocSections.totals,
      hasText: true,
      defaultText: 'الدفع',
      style: DocStyle(size: 18),
      legacyToggle: 'invoice_show_paid',
    ),
    DocField(
      key: kRemaining,
      label: 'المتبقي',
      hint: 'البادئة قبل المبلغ المتبقي على الزبون.',
      section: DocSections.totals,
      hasText: true,
      defaultText: 'المتبقي',
      // لم يكن يُطبع أصلًا — خيار جديد، مُعطَّل افتراضيًا.
      defaultEnabled: false,
      style: DocStyle(size: 18),
      legacyToggle: 'invoice_show_remaining',
    ),
    DocField(
      key: kCurrency,
      label: 'رمز العملة',
      hint: 'يظهر بعد المبلغ المستحق.',
      section: DocSections.totals,
      hasText: true,
      defaultText: 'ر.س',
      style: DocStyle(size: 24),
    ),
    DocField(
      key: kDue,
      label: 'المستحق بعد الخصم',
      hint: 'العنوان المقابل للمبلغ عند وجود خصم.',
      section: DocSections.totals,
      hasText: true,
      defaultText: 'المستحق بعد الخصم',
      style: DocStyle(size: 27),
    ),
    DocField(
      key: kSum,
      label: 'المجموع',
      hint: 'العنوان المقابل للمبلغ عند عدم وجود خصم.',
      section: DocSections.totals,
      hasText: true,
      defaultText: 'المجموع',
      style: DocStyle(size: 27),
    ),
    DocField(
      key: kTotalAmount,
      label: 'المبلغ المستحق',
      hint: 'المبلغ الكبير أسفل الفاتورة.',
      section: DocSections.totals,
      style: DocStyle(size: 24),
    ),
    DocField(
      key: kSubsBadge,
      label: 'وسم الاشتراك',
      hint: 'الكلمة التي تحلّ محلّ السعر في فاتورة الاشتراك.',
      section: DocSections.totals,
      hasText: true,
      defaultText: 'اشتراك',
      style: DocStyle(size: 20),
    ),
    DocField(
      key: kSubsNote,
      label: 'تنبيه الاشتراك',
      hint: 'الشريط الذي يظهر أسفل فاتورة الاشتراك بدل الإجماليات.',
      section: DocSections.totals,
      hasText: true,
      defaultText: 'مغطّى بالاشتراك الشهري – لا يُطلب مبلغ عند التسليم',
      style: DocStyle(size: 24),
    ),
    // ── التذييل ──
    DocField(
      key: kFooter,
      label: 'التذييل',
      hint: 'نصّ حرّ أسفل الفاتورة.',
      section: DocSections.footer,
      hasText: true,
      style: DocStyle(size: 20),
      legacyText: 'invoice_footer_note',
    ),
    DocField(
      key: kMapQr,
      label: 'رمز QR لموقع النشاط',
      hint:
          'يُطبع أسفل الفاتورة ويفتح موقع النشاط على خرائط جوجل. يحتاج رابطًا في «معلومات النشاط ← رابط الموقع»، ولا يُطبع شيء إن كان الرابط فارغًا.',
      section: DocSections.footer,
      hasText: true,
      defaultText: mapQrDefaultText,
      style: DocStyle(size: 16),
    ),
  ];

  static const List<DocField> statementFields = <DocField>[
    DocField(
      key: kLogo,
      label: 'شعار النشاط',
      hint:
        'صورة الشعار أعلى الكشف. مُعطَّل افتراضيًا لأن إضافته تُطيل الترويسة وقد تدفع ملخّص الكشف إلى صفحة ثانية.',
      section: DocSections.header,
      hasStyle: false,
      // الكشف لم يكن يحمل شعارًا قبل 2026-10-23 — نُبقيه كما كان.
      defaultEnabled: false,
    ),
    DocField(
      key: kBusinessName,
      label: 'اسم النشاط',
      hint: 'اتركه فارغًا لاستخدام الاسم المسجَّل.',
      section: DocSections.header,
      hasText: true,
      style: DocStyle(size: 20),
    ),
    DocField(
      key: kBusinessAddress,
      label: 'عنوان النشاط',
      hint: 'اتركه فارغًا لاستخدام العنوان المسجَّل.',
      section: DocSections.header,
      hasText: true,
      style: DocStyle(size: 11),
    ),
    DocField(
      key: kPhoneLine,
      label: 'سطر الهاتف',
      hint: 'البادئة قبل رقم الهاتف.',
      section: DocSections.header,
      hasText: true,
      defaultText: 'هاتف',
      style: DocStyle(size: 11),
    ),
    DocField(
      key: kTitle,
      label: 'عنوان المستند',
      hint: 'مثل: كشف حساب زبون.',
      section: DocSections.header,
      hasText: true,
      defaultText: statementTitleDefault,
      style: DocStyle(size: 19),
    ),
    DocField(
      key: kCustomerName,
      label: 'اسم الزبون',
      hint: 'البادئة قبل اسم الزبون.',
      section: DocSections.body,
      hasText: true,
      defaultText: 'الزبون',
      style: DocStyle(size: 13),
    ),
    DocField(
      key: kCustomerPhone,
      label: 'هاتف الزبون',
      hint: 'البادئة قبل رقم الهاتف.',
      section: DocSections.body,
      hasText: true,
      defaultText: 'الهاتف',
      style: DocStyle(size: 13),
    ),
    DocField(
      key: kPeriod,
      label: 'فترة الكشف',
      hint: 'البادئة قبل «من … إلى …».',
      section: DocSections.body,
      hasText: true,
      defaultText: 'الفترة',
      style: DocStyle(size: 11),
    ),
    DocField(
      key: kPrintedAt,
      label: 'تاريخ الطباعة',
      hint: 'البادئة قبل تاريخ ووقت الطباعة.',
      section: DocSections.body,
      hasText: true,
      defaultText: 'طُبع في',
      style: DocStyle(size: 13),
    ),
    DocField(
      key: kSectionTitle,
      label: 'عناوين الأقسام',
      hint: '«الأصناف التي أخذها» · «الفواتير» · «الدفعّات» …',
      section: DocSections.body,
      style: DocStyle(size: 14),
    ),
    DocField(
      key: kTotals,
      label: 'ملخّص الإجماليات',
      hint: 'بطاقة الإجماليات أسفل الكشف (المشتريات · الذمة · الصافي).',
      section: DocSections.totals,
      style: DocStyle(size: 13),
    ),
    DocField(
      key: kItemsTable,
      label: 'جدول الأصناف',
      hint: 'عنوان القسم + حجم خطّ خلاياه.',
      section: DocSections.body,
      hasText: true,
      defaultText: 'الأصناف التي أخذها',
      style: DocStyle(size: 12),
    ),
    DocField(
      key: kInvoicesTable,
      label: 'جدول الفواتير',
      hint: 'عنوان القسم + حجم خطّ خلاياه.',
      section: DocSections.body,
      hasText: true,
      defaultText: 'الفواتير',
      style: DocStyle(size: 12),
    ),
    DocField(
      key: kPaymentsTable,
      label: 'جدول الدفعات',
      hint: 'عنوان القسم + حجم خطّ خلاياه.',
      section: DocSections.body,
      hasText: true,
      defaultText: 'الدفعات المسجلة',
      style: DocStyle(size: 12),
    ),
    DocField(
      key: kUsagesTable,
      label: 'جدول استهلاك الاشتراك',
      hint: 'عنوان القسم + حجم خطّ خلاياه.',
      section: DocSections.body,
      hasText: true,
      defaultText: 'سجل استهلاك الاشتراك (القطع المغسولة)',
      style: DocStyle(size: 12),
    ),
    DocField(
      key: kCurrency,
      label: 'رمز العملة',
      hint: 'يظهر بعد كل مبلغ في الكشف.',
      section: DocSections.body,
      hasText: true,
      defaultText: 'ريال',
      style: DocStyle(size: 13),
    ),
    DocField(
      key: kSummaryTitle,
      label: 'عنوان الملخّص',
      hint: 'يظهر فوق إجماليات الكشف.',
      section: DocSections.totals,
      hasText: true,
      defaultText: 'الملخّص',
      style: DocStyle(size: 14),
    ),
    DocField(
      key: kSummaryTitlePeriod,
      label: 'عنوان الملخّص (مقيَّد بفترة)',
      hint: 'يُستخدم عندما يكون الكشف بين تاريخين.',
      section: DocSections.totals,
      hasText: true,
      defaultText: 'الملخّص (تدفّقات الفترة + الرصيد الحالي)',
      style: DocStyle(size: 14),
    ),
    DocField(
      key: kTotalsPurchases,
      label: 'إجمالي المشتريات',
      hint: 'البادئة قبل مجموع المشتريات.',
      section: DocSections.totals,
      hasText: true,
      defaultText: 'إجمالي المشتريات',
      style: DocStyle(size: 13),
    ),
    DocField(
      key: kTotalsPaid,
      label: 'المسدد',
      hint: 'البادئة قبل مجموع المسدد.',
      section: DocSections.totals,
      hasText: true,
      defaultText: 'المسدد',
      style: DocStyle(size: 13),
    ),
    DocField(
      key: kTotalsDebt,
      label: 'الذمة المتبقية',
      hint: 'البادئة قبل ما على الزبون.',
      section: DocSections.totals,
      hasText: true,
      defaultText: 'الذمة المتبقية (عليه)',
      style: DocStyle(size: 13),
    ),
    DocField(
      key: kTotalsCredit,
      label: 'الرصيد الدائن',
      hint: 'البادئة قبل ما للزبون.',
      section: DocSections.totals,
      hasText: true,
      defaultText: 'الرصيد الدائن (له)',
      style: DocStyle(size: 13),
    ),
    DocField(
      key: kTotalsNet,
      label: 'صافي الموقف',
      hint: 'البادئة قبل صافي الرصيد.',
      section: DocSections.totals,
      hasText: true,
      defaultText: 'صافي الموقف',
      style: DocStyle(size: 13),
    ),
    DocField(
      key: kTotalsPieces,
      label: 'عدد القطع',
      hint: 'البادئة قبل عدد القطع (يظهر إن كان أكبر من صفر).',
      section: DocSections.totals,
      hasText: true,
      defaultText: 'عدد القطع',
      style: DocStyle(size: 13),
    ),
    DocField(
      key: kTotalsSubPieces,
      label: 'قطع الاشتراكات',
      hint: 'البادئة قبل عدد قطع الاشتراك المستهلكة.',
      section: DocSections.totals,
      hasText: true,
      defaultText: 'قطع الاشتراكات المستهلكة',
      style: DocStyle(size: 13),
    ),
    DocField(
      key: kTotalsSubValue,
      label: 'قيمة قطع الاشتراك',
      hint: 'الكلمة قبل قيمة القطع المستهلكة بين قوسين.',
      section: DocSections.totals,
      hasText: true,
      defaultText: 'بقيمة',
      style: DocStyle(size: 13),
    ),
    DocField(
      key: kDivider,
      label: 'الخط الفاصل',
      hint: 'الخط أسفل الترويسة.',
      section: DocSections.header,
      hasStyle: false,
    ),
    DocField(
      key: kFooter,
      label: 'التذييل',
      hint: 'نصّ حرّ أسفل الكشف.',
      section: DocSections.footer,
      hasText: true,
      defaultText: statementFooterDefault,
      style: DocStyle(size: 11),
    ),
    DocField(
      key: kMapQr,
      label: 'رمز QR لموقع النشاط',
      hint:
          'يُطبع أسفل الكشف ويفتح موقع النشاط على خرائط جوجل. يحتاج رابطًا في «معلومات النشاط ← رابط الموقع».',
      section: DocSections.footer,
      hasText: true,
      defaultText: mapQrDefaultText,
      style: DocStyle(size: 10),
    ),
  ];

  /// ملخّص الوردية — A6، كان **خارج** نظام القوالب حتى 2026-10-24.
  static const List<DocField> shiftFields = <DocField>[
    DocField(
      key: kBusinessName,
      label: 'اسم النشاط',
      hint: 'اتركه فارغًا لاستخدام الاسم المسجَّل.',
      section: DocSections.header,
      hasText: true,
      style: DocStyle(size: 20),
    ),
    DocField(
      key: kBusinessAddress,
      label: 'عنوان النشاط',
      hint: 'اتركه فارغًا لاستخدام العنوان المسجَّل.',
      section: DocSections.header,
      hasText: true,
      style: DocStyle(size: 12),
    ),
    DocField(
      key: kPhoneLine,
      label: 'سطر الهاتف',
      hint: 'البادئة قبل رقم الهاتف.',
      section: DocSections.header,
      hasText: true,
      defaultText: 'هاتف',
      style: DocStyle(size: 12),
    ),
    DocField(
      key: kTitle,
      label: 'عنوان المستند',
      hint: 'مثل: ملخص الوردية.',
      section: DocSections.header,
      hasText: true,
      defaultText: shiftTitleDefault,
      style: DocStyle(size: 18),
    ),
    DocField(
      key: kDivider,
      label: 'الخط الفاصل',
      hint: 'الخط بين الترويسة والبيانات.',
      section: DocSections.header,
      hasStyle: false,
    ),
    DocField(
      key: kShiftId,
      label: 'رقم الوردية',
      hint: 'البادئة قبل رقم الوردية.',
      section: DocSections.body,
      hasText: true,
      defaultText: 'رقم الوردية',
      style: DocStyle(size: 12),
    ),
    DocField(
      key: kStartTime,
      label: 'وقت البدء',
      hint: 'البادئة قبل تاريخ ووقت فتح الوردية.',
      section: DocSections.body,
      hasText: true,
      defaultText: 'وقت البدء',
      style: DocStyle(size: 12),
    ),
    DocField(
      key: kEndTime,
      label: 'وقت الانتهاء',
      hint: 'البادئة قبل تاريخ ووقت إغلاق الوردية.',
      section: DocSections.body,
      hasText: true,
      defaultText: 'وقت الانتهاء',
      style: DocStyle(size: 12),
    ),
    DocField(
      key: kInvoiceCount,
      label: 'عدد الفواتير',
      hint: 'البادئة قبل عدد فواتير الوردية.',
      section: DocSections.body,
      hasText: true,
      defaultText: 'عدد الفواتير',
      style: DocStyle(size: 12),
    ),
    DocField(
      key: kTotalCash,
      label: 'مجموع الكاش',
      hint: 'البادئة قبل إجمالي المدفوع نقدًا.',
      section: DocSections.body,
      hasText: true,
      defaultText: 'مجموع الكاش',
      style: DocStyle(size: 12),
    ),
    DocField(
      key: kTotalNetwork,
      label: 'مجموع الشبكة',
      hint: 'البادئة قبل إجمالي المدفوع بالشبكة.',
      section: DocSections.body,
      hasText: true,
      defaultText: 'مجموع الشبكة',
      style: DocStyle(size: 12),
    ),
    DocField(
      key: kCurrency,
      label: 'رمز العملة',
      hint: 'يظهر بعد مبالغ الكاش والشبكة.',
      section: DocSections.body,
      hasText: true,
      defaultText: 'ريال',
      style: DocStyle(size: 12),
    ),
    DocField(
      key: kFooter,
      label: 'التذييل',
      hint: 'نصّ حرّ أسفل الملخّص.',
      section: DocSections.footer,
      hasText: true,
      defaultText: shiftFooterDefault,
      style: DocStyle(size: 12),
    ),
  ];

  /// ورقة المغسلة (نسخة المحل) — **بلا أي حقل مالي** عن قصد.
  ///
  /// كل حقل هنا يقابله رسم في `laundry_slip_pdf.dart`. والحقول المشتركة مع
  /// الفاتورة تحمل نفس المفاتيح (`logo` · `business_name` · `title` …) كي
  /// يفهمها `DocTemplateView` بلا جدول ربط جديد.
  static const List<DocField> laundrySlipFields = <DocField>[
    // ── الترويسة ──
    DocField(
      key: kLogo,
      label: 'شعار النشاط',
      hint: 'صورة الشعار أعلى ورقة المغسلة.',
      section: DocSections.header,
      hasStyle: false,
    ),
    DocField(
      key: kBusinessName,
      label: 'اسم النشاط',
      hint: 'اتركه فارغًا لاستخدام الاسم المسجَّل.',
      section: DocSections.header,
      hasText: true,
      // الورقة تُقرأ من بعيد على كيس الغسيل: الاسم عريض افتراضيًا.
      style: DocStyle(size: 17, weight: 700),
    ),
    DocField(
      key: kTitle,
      label: 'عنوان الورقة',
      hint: 'مثل: ورقة المغسلة.',
      section: DocSections.header,
      hasText: true,
      defaultText: slipTitleDefault,
      style: DocStyle(size: 14, weight: 700),
    ),
    DocField(
      key: kSlipSubtitle,
      label: 'العنوان الفرعي',
      hint: 'مثل: نسخة المحل. يُطبع بجانب العنوان.',
      section: DocSections.header,
      hasText: true,
      defaultText: slipSubtitleDefault,
      style: DocStyle(size: 9.5, weight: 700),
    ),
    DocField(
      key: kSlipNotice,
      label: 'تنبيه الورقة',
      hint: 'سطر صغير تحت العنوان (لا تُسلَّم للعميل…).',
      section: DocSections.header,
      hasText: true,
      defaultText: slipNoticeDefault,
      // الحجم الافتراضي = ما يراه المستخدم على A4 (يُصغَّر تلقائيًّا على
      // الحراري/الضيِّق بنسبة التخطيط).
      style: DocStyle(size: 9),
    ),
    // ── تفاصيل ──
    DocField(
      key: kReceiptNo,
      label: 'رقم الفاتورة',
      hint: 'البادئة والرقم الكبير داخل الإطار.',
      section: DocSections.body,
      hasText: true,
      defaultText: 'رقم الفاتورة',
      style: DocStyle(size: 28, weight: 700),
    ),
    DocField(
      key: kDatetime,
      label: 'التاريخ والوقت',
      hint: 'البادئة قبل تاريخ الفاتورة.',
      section: DocSections.body,
      hasText: true,
      defaultText: 'التاريخ',
      style: DocStyle(size: 9),
    ),
    DocField(
      key: kCustomerName,
      label: 'اسم العميل',
      hint: 'يظهر فقط عند وجود اسم.',
      section: DocSections.body,
      hasText: true,
      defaultText: 'العميل',
      style: DocStyle(size: 9),
    ),
    DocField(
      key: kCustomerPhone,
      label: 'هاتف العميل',
      hint: 'يظهر فقط عند وجود رقم.',
      section: DocSections.body,
      hasText: true,
      defaultText: 'هاتف العميل',
      style: DocStyle(size: 9),
    ),
    DocField(
      key: kPickupCode,
      label: 'رمز الاستلام',
      hint: 'البادئة قبل رمز استلام القطع.',
      section: DocSections.body,
      hasText: true,
      defaultText: 'رمز الاستلام',
      style: DocStyle(size: 9),
    ),
    DocField(
      key: kDivider,
      label: 'الخط الفاصل',
      hint: 'الخطوط بين الترويسة والأصناف والإجماليات.',
      section: DocSections.body,
      hasStyle: false,
    ),
    DocField(
      key: kItemName,
      label: 'اسم الصنف',
      hint: 'عنوان عمود الصنف ونصّ الاسم في النسخة المضغوطة.',
      section: DocSections.body,
      hasText: true,
      defaultText: 'الصنف',
      style: DocStyle(size: 9),
    ),
    DocField(
      key: kService,
      label: 'الخدمة',
      hint: 'عنوان عمود الخدمة ونصّها.',
      section: DocSections.body,
      hasText: true,
      defaultText: 'الخدمة',
      style: DocStyle(size: 8),
    ),
    DocField(
      key: kQty,
      label: 'العدد',
      hint: 'عنوان عمود العدد والرقم داخل الشارة.',
      section: DocSections.body,
      hasText: true,
      defaultText: 'العدد',
      style: DocStyle(size: 8),
    ),
    DocField(
      key: kItemNote,
      label: 'ملاحظة البند',
      hint: 'الكلمة قبل ملاحظة القطعة (مثل: ملاحظة).',
      section: DocSections.body,
      hasText: true,
      defaultText: 'ملاحظة',
      style: DocStyle(size: 8),
    ),
    DocField(
      key: kEmptyItems,
      label: 'رسالة «لا توجد أصناف»',
      hint: 'تظهر إذا كانت الفاتورة بلا بنود.',
      section: DocSections.body,
      hasText: true,
      defaultText: 'لا توجد أصناف في هذه الفاتورة',
      style: DocStyle(size: 9),
    ),
    // ── الإجماليات (عدد فقط — لا مبالغ) ──
    DocField(
      key: kTotalPieces,
      label: 'إجمالي القطع',
      hint: 'البادئة قبل مجموع القطع.',
      section: DocSections.totals,
      hasText: true,
      defaultText: 'إجمالي القطع',
      style: DocStyle(size: 9.5, weight: 700),
    ),
    DocField(
      key: kItemsCount,
      label: 'عدد الأصناف',
      hint: 'البادئة قبل عدد الأسطر.',
      section: DocSections.totals,
      hasText: true,
      defaultText: 'عدد الأصناف',
      style: DocStyle(size: 9.5, weight: 700),
    ),
    // ── التذييل ──
    DocField(
      key: kWorkerSignature,
      label: 'توقيع العامل',
      hint: 'سطر التوقيع الأول.',
      section: DocSections.footer,
      hasText: true,
      defaultText: 'توقيع العامل',
      style: DocStyle(size: 8),
    ),
    DocField(
      key: kNotesSignature,
      label: 'ملاحظات',
      hint: 'سطر التوقيع الثاني.',
      section: DocSections.footer,
      hasText: true,
      defaultText: 'ملاحظات',
      style: DocStyle(size: 8),
    ),
    DocField(
      key: kBusinessPhone,
      label: 'هاتف النشاط',
      hint: 'رقم الهاتف أسفل الورقة.',
      section: DocSections.footer,
      // مطابق لحجم A4 الافتراضي (يُصغَّر تلقائيًّا على الحراري).
      style: DocStyle(size: 9),
    ),
  ];

  static List<DocField> fieldsOf(DocKind kind) =>
      switch (kind) {
        DocKind.invoice => invoiceFields,
        DocKind.statement => statementFields,
        DocKind.shift => shiftFields,
        DocKind.laundrySlip => laundrySlipFields,
      };

  static DocField? fieldOf(DocKind kind, String key) {
    for (final f in fieldsOf(kind)) {
      if (f.key == key) return f;
    }
    return null;
  }

  /// الحقل المرتبط بخيار إعدادات قديم (منطقي أو نصّي) — للزرع والمزامنة.
  static DocField? fieldByLegacy(DocKind kind, String legacyKey) {
    for (final f in fieldsOf(kind)) {
      if (f.legacyToggle == legacyKey || f.legacyText == legacyKey) return f;
    }
    return null;
  }

  /// كل الحقول التي لها خيار قديم (مصدر قائمة المزامنة).
  static List<DocField> legacyFields(DocKind kind) =>
      fieldsOf(kind).where((f) => f.hasLegacy).toList();

  static List<DocField> fieldsIn(DocKind kind, String section) =>
      fieldsOf(kind).where((f) => f.section == section).toList();

  /// مفتاح التخزين في جدول `settings`.
  static String storageKey(DocKind kind) =>
      switch (kind) {
        DocKind.invoice => 'doc_template_invoice',
        DocKind.statement => 'doc_template_statement',
        DocKind.shift => 'doc_template_shift',
        DocKind.laundrySlip => 'doc_template_laundry_slip',
      };

  static String labelOf(DocKind kind) =>
      switch (kind) {
        DocKind.invoice => 'الفاتورة',
        DocKind.statement => 'كشف الحساب',
        DocKind.shift => 'ملخص الوردية',
        DocKind.laundrySlip => 'ورقة المغسلة',
      };
}

/// مُساعدات قراءة آمنة من خريطة النقل (داخل عزل `compute`).
///
/// **الدلالة عند غياب الخريطة**: يعود للسجلّ ([DocCatalog]) لا إلى «الكل
/// مُفعَّل». لماذا؟ لأن مسارًا قديمًا قد ينسى تمرير القالب (مثل مشاركة
/// الفاتورة على واتساب) — فبدل أن تظهر حقول مُعطَّلة افتراضيًا (العنوان
/// الوطني · رمز الاستلام) على مستند لم يطلبها أحد، نُرجع **نفس** الشكل
/// الافتراضي المعلن في السجلّ. فالنتيجة: لا مستند أسوأ من الافتراضي أبدًا.
class DocTemplateView {
  final DocKind kind;
  final Map? _enabled;
  final Map? _texts;
  final Map? _styles;
  final Map? _english;

  /// هل المستند إنجليزي؟ **يُقرأ من الحمولة** لا من [L10n].
  ///
  /// 🚨 مولّد الفاتورة يعمل في `compute` (عزل مستقلّ) لا يرى الحالة الساكنة
  /// لـ`L10n`، فكان `L10n.isEnglish` يُرجع `false` دائمًا ⇒ كل عناوين
  /// الفاتورة عربية في الوضع الإنجليزي. اللغة تُختم في
  /// `DocTemplateService.transport` تحت `docLang`.
  final bool isEnglishDoc;

  const DocTemplateView(
    this.kind,
    this._enabled,
    this._texts, [
    this._styles,
    this._english,
    this.isEnglishDoc = false,
  ]);

  /// من خريطة بيانات المولّد (`docEnabled` · `docTexts` · `docStyles`).
  ///
  /// عند غياب `docLang` (حمولة قديمة أو نداء من الاختبارات) نرجع لـ[L10n]
  /// كي لا يتغيّر سلوك المسارات التي تعمل في الخيط الرئيسي.
  factory DocTemplateView.of(Map<String, dynamic> data, DocKind kind) {
    final code = '${data['docLang'] ?? ''}'.trim().toLowerCase();
    return DocTemplateView(
      kind,
      data['docEnabled'] as Map?,
      data['docTexts'] as Map?,
      data['docStyles'] as Map?,
      data['docEnglish'] as Map?,
      code.isEmpty ? L10n.isEnglish : code == 'en',
    );
  }

  /// مُفعَّل؟ — المخزَّن إن وُجد، وإلا افتراضي السجلّ.
  bool isOn(String key) {
    final v = _enabled?[key];
    if (v is bool) return v;
    return DocCatalog.fieldOf(kind, key)?.defaultEnabled ?? true;
  }

  /// النصّ: المخزَّن إن كان غير فارغ، وإلا [fallback]، وإلا افتراضي السجلّ.
  ///
  /// ⚠️ يُمرَّر على [ArabicText.safe] لأن هذا هو **المعبر الوحيد** لنصوص
  /// القالب إلى الرسم: حزمة `pdf` تُسقط المسافة قبل أي كلمة تبدأ بـ«لا»
  /// («رمز الاستلام» ⇒ «رمزالاستلام»). الإصلاح هنا يغطّي المستندات الأربعة
  /// معًا بلا تكرار. (وواجهة المحرّر تقرأ `DocTemplate.textOf` بلا
  /// تطبيع، لأن Flutter يرسم المسافة صحيحة.)
  String text(String key, [String? fallback]) {
    final v = _texts?[key];
    final raw =
        v is String && v.trim().isNotEmpty
            ? v
            : fallback ??
                DocCatalog.fieldOf(kind, key)?.defaultText ??
                '';
    // 🚨 الإنجليزية **فقط** حين يكون المستند إنجليزيًّا. كان الشرط يقرأ
    // `L10n.isEnglish` وهو `false` داخل عزل `compute` ⇒ فاتورة عربية دائمًا.
    if (!isEnglishDoc) return ArabicText.safe(raw);
    final en = _english?[raw];
    if (en is String && en.trim().isNotEmpty) return en;
    return ArabicText.safe(raw);
  }

  /// النمط: المخزَّن (مُقيَّدًا) وإلا افتراضي السجلّ.
  ///
  /// **لماذا التقيد هنا أيضًا؟** لأن هذا هو المعبر إلى العزل: خريطة النقل
  /// قد تأتي من قالب محفوظ قديم أو من `compute` بعد تعديل يدوي. التقيد في
  /// [DocStyle.clamped] يجعل الحجم الشاذّ يُرسم معقولًا بدل أن يخرج عن
  /// الورقة أو يرمي.
  DocStyle style(String key) {
    final fallback = DocCatalog.fieldOf(kind, key)?.style ?? const DocStyle();
    return DocStyle.fromTransport(_styles?[key], fallback);
  }
}
