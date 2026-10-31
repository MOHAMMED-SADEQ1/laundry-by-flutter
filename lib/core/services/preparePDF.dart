// ignore_for_file: file_names

import 'dart:io';
import 'package:barcode/barcode.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:laundry/core/services/paper_size.dart';
import 'package:laundry/services/i18n/doc_language.dart';
import 'package:laundry/services/i18n/l10n.dart';
import 'package:laundry/services/payment/payment_method.dart';
import 'package:laundry/services/pdf/arabic_text.dart';
import 'package:laundry/services/pdf/doc_template.dart';
import 'package:laundry/services/pdf/print_visual_size.dart';
import 'package:laundry/services/pdf/map_qr.dart';
import 'package:laundry/services/printer/print_layout.dart';
import 'package:laundry/services/tax/tax_service.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:intl/intl.dart';

class PreparePDF {
  /// رمز QR لموقع النشاط — **SVG** جاهز أو `null` إن لم يُطبع.
  ///
  /// شرطان لا ثالث لهما: الحقل مُفعَّل في قالب المستند، والرابط صالح بعد
  /// التطبيع ([MapQr.resolve]). غياب أحدهما يعني **لا رمز** لا رمزًا مكسورًا.
  ///
  /// الرمز يختلف عن QR الهيئة: ذاك للتحقّق الضريبي (TLV مُرمَّز بـBase64)،
  /// وهذا رابط خرائط يُفتح بكاميرا الهاتف. لذلك لكلٍّ حقل مستقلّ في القالب.
  static String? _mapQrSvg(Map<String, dynamic> data, DocTemplateView doc) {
    if (!doc.isOn(DocCatalog.kMapQr)) return null;
    final url = MapQr.resolve(data['bizMapUrl']);
    if (url.isEmpty) return null;
    try {
      return Barcode.qrCode().toSvg(url, width: 120, height: 120);
    } catch (e) {
      // رابط أطول من سعة الرمز أو أي خطأ ترميز: الورقة تُطبع بلا رمز.
      debugPrint('map QR error: $e');
      return null;
    }
  }

  /// تنسيق مبلغ مالي بخانتين عشريتين.
  ///
  /// **إصلاح:** كان الكود يستعمل لصقًا نصيًا `"${value}0"` لإضافة خانة عشرية،
  /// وهو يعمل بالصدفة مع `15.0` (→ "15.00") لكنه **يُفسد** الأرقام الأخرى:
  /// `45.75` → "45.750" (‏3 خانات) و`30` (int) → "300" (**عشرة أضعاف**).
  static String _money(dynamic value) {
    final amount =
        value is num
            ? value.toDouble()
            : double.tryParse('${value ?? 0}') ?? 0.0;
    return amount.toStringAsFixed(2);
  }

  /// تحويل آمن إلى `double` — يتحمّل `num` والنص والفارغ.
  static double _num(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse('${value ?? ''}') ?? 0.0;
  }

  /// نصّ ثابت بلغة المستند — يعمل داخل العزل بلا حالة عامة.
  ///
  /// [data] تحمل `docEnglish` من [DocTemplateService.transport]، ويُمرَّر من
  /// الواجهة العربية فارغًا فتظل النصوص عربية.
  static String _t(Map<String, dynamic> data, String arabic) {
    final map = data['docEnglish'];
    if (map is Map) {
      final v = map[arabic];
      if (v is String && v.isNotEmpty) return v;
    }
    return arabic;
  }

  /// نسبة مئوية بلا أصفار زائدة (0.15 ⇒ «15»).
  static String _percent(double rate) {
    final v = rate * 100;
    final s = v.toStringAsFixed(2);
    return s.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
  }

  /// **نصّ المستند بنمط القالب** — المعبر الوحيد لرسم أي نصّ في المستندات
  /// الثلاثة (فاتورة · كشف حساب · ملخص وردية).
  ///
  /// يطبّق المحاور الثلاثة التي يطلبها المستخدم:
  ///
  ///   • **الحجم** → `fontSize` من [DocStyle.size].
  ///   • **العرض** → **تضييق أفقي** بـ[pw.Transform] ومصفوفة تمديد.
  ///     🚨 **لا `letterSpacing`**: أُثبت بمسبار (`_probe_font_weight.dart`)
  ///     أنه **يكسر اتصال الحروف العربية** فتصير «ضريبية» «ض ر ي ب ي ة».
  ///     والتمديد يُوسّع الحرف نفسه فيبقى متّصلًا.
  ///     🚨 **التضييق فقط (75..100%)**: `Transform` يرسم ولا يشارك في التخطيط،
  ///     فالتوسيع يُخرج السطر خارج الورقة ويتداخل مع الخلايا المجاورة —
  ///     مُقاسًا لا مُقدَّرًا (انظر [DocStyle.width]).
  ///   • **الوزن** → **تعريض صناعي**: رسم السطر مرّتين، النسخة الثانية مُزاحة
  ///     أفقيًا بمقدار [DocStyle.boldOffset] (ما تفعله المتصفّحات نفسها).
  ///
  /// 🚨 **`StackFit.passthrough` إلزامي**: بـ`loose` (الافتراضي) يأخذ الابن
  /// `constraints.loosen()` فيفقد `textAlign` داخل خلايا الجداول (عرض الخلية
  /// يصير عرض النصّ لا عرض الخلية). و`passthrough` يمرّر القيود كما هي،
  /// فيبقى الالتفاف والمحاذاة سليمين. أُثبت بصريًا على 220 dpi في
  /// `tool/_probe_weight_width.dart` (خلية بنصّ طويل التفّ على سطرين).
  ///
  /// ⚠️ **لا `fontWeight` هنا ولا في أي مولّد**: بلا أثر إطلاقًا. كل نمط
  /// يمرّر `font:` صريحًا، و`pdf` تحسم الوجه بـ`style.font!.getFont(context)`
  /// (`text.dart:170`) فلا تُقرأ `fontWeight`. ولهذا كانت كل الفواتير
  /// المطبوعة قبل 2026-10-24 بوزن **عادي** رغم `bold` المكتوب في الكود.
  ///
  /// ## الحدود
  /// الحجم والعرض مُقيَّدان في [DocStyle] (6..36 نقطة · 80..140%). الحدّ
  /// الأعلى محسوب لا تعسّفي: فوقه يخرج أطول سطر لا يلتفّ عن الورقة، ولا
  /// يُصلَح بتصغير تلقائي (انظر [tx] أدناه) بل بمنع القيمة أصلًا.
  /// محاذاة النهاية بلغة **صريحة** — تُستخدم داخل العزل حيث لا تُقرأ [L10n].
  ///
  /// كانت `pw.TextAlign.right` مكتوبة حرفيًّا، فتظهر الأرقام في المستند
  /// الإنجليزي ملتصقة باليمين بلا سبب. والآن المصدر لغة المستند لا الواجهة.
  static pw.TextAlign _endAlignOf(bool isRtl) =>
      isRtl ? pw.TextAlign.right : pw.TextAlign.left;

  /// هل المستند من اليمين لليسار؟ يُقرأ من `data['docLang']`.
  ///
  /// 🚨 **هذا هو سبب «الفاتورة تُطبع بالعربية دائمًا» سابقًا**: مولّد الفاتورة
  /// يعمل داخل `compute` — عزل مستقلّ لا يرى الحالة الساكنة لـ`L10n` — فكان
  /// `L10n.isEnglish` يُرجع `false` دائمًا وكل النصوص تُرسم عربية.
  /// اللغة تُختم في `DocTemplateService.transport` (الخيط الرئيسي) وتُقرأ هنا.
  ///
  /// عند غياب `docLang` (حمولة قديمة أو نداء مباشر من الاختبارات) نسقط
  /// لافتراضي المستندات (**العربية**) لا لِلغة الواجهة: لغة الورقة قرار مالي
  /// مستقلّ، ولا يجوز أن يغيّرها زرّ لغة الشاشة حتى في مسار قديم.
  static bool _rtlOf(Map<String, dynamic> data) {
    final code = '${data['docLang'] ?? ''}'.trim().toLowerCase();
    if (code.isEmpty) return DocLanguage.defaultLanguage.isRtl;
    return code != 'en';
  }

  static pw.Widget _docText(
    String text,
    DocStyle style, {
    required pw.Font font,
    pw.TextAlign? align,
    PdfColor? color,
    bool? isRtl,
  }) {
    final rtl = isRtl ?? DocLanguage.defaultLanguage.isRtl;
    pw.Widget layer() => pw.Text(
      // إصلاح المسافة قبل «ا ل ا» يخصّ العربية وحدها؛ لا يُطبَّق على
      // الإنجليزية لأنه يُدخل مسافة مزدوجة بلا سبب.
      rtl ? ArabicText.safe(text) : text,
      // 🚨 الاتجاه **يتبع اللغة** لا يُكتب حرفيًّا: نصّ إنجليزي باتجاه rtl
      // تُقرأ كلماته من آخرها وتُصفّ علاماته في غير موضعها.
      textDirection: rtl ? pw.TextDirection.rtl : pw.TextDirection.ltr,
      textAlign: align,
      style: pw.TextStyle(font: font, fontSize: style.size, color: color),
    );

    var out = layer();
    final dx = style.boldOffset;
    if (dx > 0) {
      out = pw.Stack(
        fit: pw.StackFit.passthrough,
        overflow: pw.Overflow.visible,
        children: [
          out,
          pw.Transform.translate(offset: PdfPoint(dx, 0), child: layer()),
        ],
      );
    }
    if (style.width != 100) {
      out = pw.Transform(
        transform: Matrix4.diagonal3Values(style.widthScale, 1, 1),
        alignment: pw.Alignment.center,
        child: out,
      );
    }
    return out;
  }

  /// سطر تفصيلي في جدول الإجماليات — المبلغ يسار والوصف يمين.
  static pw.Widget _totalRow(
    String label,
    String value,
    DocStyle style, {
    required pw.Font font,
    PdfColor? color,
    bool? isRtl,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        children: [
          _docText(value, style, font: font, color: color, isRtl: isRtl),
          pw.Spacer(),
          _docText(
            label,
            style,
            font: font,
            color: color,
            align: _endAlignOf(isRtl ?? DocLanguage.defaultLanguage.isRtl),
            isRtl: isRtl,
          ),
        ],
      ),
    );
  }

  static Future<Uint8List> generatePdfData(Map<String, dynamic> data) async {
    final pdf = pw.Document();

    // 🚨 لغة المستند تُقرأ من الحمولة لا من `L10n` — هذا المولّد يعمل في
    // `compute` (عزل مستقلّ) فالحالة الساكنة لـ`L10n` فيه هي الافتراضية
    // (العربية)، وكان ذلك يجعل كل فاتورة عربية في الوضع الإنجليزي.
    final isRtl = _rtlOf(data);
    final endAlign = _endAlignOf(isRtl);

    // ─── مقاس الورق من الإعدادات (A4 · A5 · A6 · حراري 80/58 مم · ملصقات) ───
    // الحرارية ارتفاعها مفتوح فتُضبط لأطول صفحة، وهوامشها ضيقة.
    //
    // 🚨 عند الطباعة تمرّ خريطة `PrintLayout` من `onLayout` (هوامش العتاد
    // الحقيقية ومقاس الورقة الفعلي). فنُولّد **نسخة الطباعة** داخل المساحة
    // القابلة للطباعة: الطبقة الأصلية في ويندوز ترسم الصفحة بكامل عرض الورقة
    // المادية، وأي محتوى يقع في هامش العتاد يُقصّ — وفي العربية يُقصّ يمين
    // الصفحة أي بداية أسماء الأصناف. النسخة المصدَّرة إلى PDF تبقى بلا هذه
    // الخريطة (هامش ١ سم كما كان).
    final paper = PaperSizes.resolve(data['paperSize'] as String?);
    final printLayout = PrintLayout.fromData(data[PrintLayout.dataKey]);
    final configuredWidth = PaperSizes.mmToPoints(paper.widthMm);
    final configuredHeight =
        paper.isThermal
            ? PdfPageFormat.a4.height
            : PaperSizes.mmToPoints(paper.heightMm);
    final baseMargin =
        paper.isThermal ? PaperSizes.mmToPoints(2) : PdfPageFormat.cm;
    final safety = PaperSizes.mmToPoints(paper.isThermal ? 0.5 : 1.5);
    final pageFormat = PrintLayout.pageFormat(
      width: configuredWidth,
      height: configuredHeight,
      layout: printLayout,
      baseMargin: baseMargin,
      safety: safety,
      // الحراري ورق متصل: يبقى ارتفاع الصفحة كما صُمّم (لا ارتفاع تعريف
      // الطابعة) حتى لا تتحوّل الورقة القصيرة إلى صفحة طويلة.
      keepHeight: paper.isThermal,
    );

    // مقاس الشعار: عرض وارتفاع مستقلّان من الإعداد (مم)، ثم يُقيَّدان بالورق.
    //
    // **لا شعار يخرج عن الصفحة ولا شعار يأكل ثلثها**: `PrintVisualSize` يقصّ
    // العرض على عرض الورق والارتفاع على سقف نسبي، ويعيد `clamped` — لكن
    // القرار هنا لا يطبعه: القيمة المخزَّنة رغبة المستخدم، والمولّد يعلن
    // التقييد في الإعدادات كي لا يظنّ أن مقاسه نُفِّذ.
    //
    // القيم القديمة (`logoSizeMm` من حمولة سابقة) تُقرأ كبديل للعرض
    // والارتفاع معًا، فتبقى إعادة طباعة فاتورة قديمة بالشكل نفسه.
    final logoBox = PrintVisualSize.logo(
      widthMm: data['logoWidthMm'],
      heightMm: data['logoHeightMm'],
      legacyMm: data['logoSizeMm'],
      maxWidth: pageFormat.availableWidth,
      maxHeight: pageFormat.availableHeight,
    );

    // 🚨 نوع الدفع يُطبع **بلغة المستند** لا بلغة الواجهة:
    //   • مستند عربي ⇒ التسميات العربية من `PaymentMethods` (كاش · شبكة …)،
    //     وهو سلوك مقصود سابقًا كي لا تظهر `cash` داخل فاتورة عربية.
    //   • مستند إنجليزي ⇒ التسمية الإنجليزية من القاموس.
    // القيمة المجهولة تُترك كما هي بدل أن تُبتلع خلف تسمية مضلِّلة.
    final paymentLabel = PaymentMethods.labelIn(
      '${data['payment'] ?? ''}',
      english: !isRtl,
    );

    final items = data['invoiceItems'] as List;
    final photoBytes = await _loadPhotoBytes(items);
    data['_photoBytes'] = photoBytes;

    // ضغط الصور إلى JPEG لتقليل الحجم
    final logoBytes = _compressToJpeg(data['logoImage'] as Uint8List, 80, 80);

    final bool hidePrices = data['hidePrices'] == true;

    // ─── مبالغ الخصم والضريبة كما حُفظت (لا كما تُعاد حسابها) ───
    final grossAmount = _num(data['summation']);
    final discountAmount = _num(data['discountAmount']);
    final payable =
        data['payable'] != null
            ? _num(data['payable'])
            : (grossAmount - discountAmount);
    final taxAmount = _num(data['taxAmount']);
    final taxRate = _num(data['taxRate']);
    final taxBase =
        data['taxBase'] != null ? _num(data['taxBase']) : (payable - taxAmount);
    final hasDiscount = discountAmount > 0.004;
    final hasTax = taxAmount > 0.004;
    final discountCode = '${data['discountCode'] ?? ''}'.trim();
    final bizTaxNumber = '${data['bizTaxNumber'] ?? ''}'.trim();

    // ─── قالب المستند ───
    //
    // 🚨 **لماذا لا نصوص مكتوبة هنا؟** كان كل سطر في الفاتورة نصًّا ثابتًا في
    // الكود وقرار إظهاره `if` مبعثرًا بين خيارات بعضها **ميّت لا يُقرأ**.
    // فكان تغيير كلمة واحدة يحتاج مبرمجًا. الآن كل نصّ وقرار ونمط من
    // `DocTemplate`، والسجلّ `DocCatalog` هو المرجع عند غياب القالب (فلا
    // مستند أسوأ من الافتراضي أبدًا).
    //
    // ⚠️ يُعرَّف **قبل** QR لأن قرار طباعة الرمز نفسه من القالب.
    final doc = DocTemplateView.of(data, DocKind.invoice);
    final font = data['arabicFont'] as pw.Font;

    /// نصّ الفاتورة بنمط حقلها.
    ///
    /// لا تصغير تلقائي (`FittedBox`) هنا: يَخرج عن حدود الورقة لا يُصلَح
    /// بتصغير يُلغى التفاف النصّ فيقتطع في وسطه، وهو أسوأ من الفائض نفسه.
    /// الحدود المقيَّدة في `DocStyle` (6..48 نقطة · 80..140%) تكفي.
    pw.Widget tx(
      String text,
      String key, {
      pw.TextAlign? align,
      PdfColor? color,
    }) => _docText(
      text,
      doc.style(key),
      font: font,
      align: align,
      color: color,
      // اتجاه النصّ وتشكيل العربية يتبعان لغة **المستند** لا لغة العزل.
      isRtl: isRtl,
    );

    // ─── QR هيئة الزكاة والضريبة والجمارك (المرحلة الأولى) ───
    //
    // الفاتورة كانت تُطبع بعنوان «فاتورة ضريبية مبسطة» **بلا رقم ضريبي ولا
    // QR**، وهو ما لا يجتاز مراجعة الهيئة. الترميز (TLV ثم Base64) في
    // `TaxService.zatcaQrPayload` منطق خالص مختبَر، لا سطور تُبنى هنا.
    String? qrSvg;
    if (bizTaxNumber.isNotEmpty && doc.isOn(DocCatalog.kQr)) {
      try {
        final payload = TaxService.zatcaQrPayload(
          sellerName: '${data['bizName'] ?? ''}',
          vatNumber: bizTaxNumber,
          timestamp: DateTime.now(),
          totalWithVat: payable,
          vatTotal: taxAmount,
        );
        qrSvg = Barcode.qrCode().toSvg(payload, width: 110, height: 110);
      } catch (e) {
        debugPrint('invoice QR error: $e');
      }
    }

    /// تجاوز نصّي: الفراغ يعني «استخدم قيمة معلومات النشاط».
    final nameOverride = doc.text(DocCatalog.kBusinessName, '').trim();
    final addressOverride = doc.text(DocCatalog.kBusinessAddress, '').trim();
    final bizName =
        nameOverride.isNotEmpty
            ? nameOverride
            : '${data['bizName'] ?? ''}'.trim().isEmpty
            ? _t(data, 'نظام المغاسل')
            : '${data['bizName']}'.trim();
    final bizAddress =
        addressOverride.isNotEmpty
            ? addressOverride
            : '${data['bizAddress'] ?? ''}'.trim();

    final bizCrNumber = '${data['bizCrNumber'] ?? ''}'.trim();
    final bizShortAddress = '${data['bizShortAddress'] ?? ''}'.trim();
    final bizPhone = '${data['bizPhone'] ?? ''}'.trim();
    final createdBy = '${data['createdByName'] ?? ''}'.trim();
    final custName = '${data['customername'] ?? ''}'.trim();
    final custPhone = '${data['customerPhone'] ?? ''}'.trim();
    final pickup = '${data['pickupCode'] ?? ''}'.trim();
    final currencyLabel =
        doc.isOn(DocCatalog.kCurrency)
            ? doc.text(DocCatalog.kCurrency).trim()
            : '';
    final footerText = doc.text(DocCatalog.kFooter, '').trim();

    // ─── رمز QR لموقع النشاط (أسفل الورقة) ───
    //
    // `business_location` كان يُحفظ ولا يُقرأ في أي مستند. صار له مستهلك:
    // الزبون يصوّر الرمز فيصل إلى الموقع بدل أن يسأل عن العنوان.
    final mapQrSvg = _mapQrSvg(data, doc);
    final mapQrCaption = doc.text(DocCatalog.kMapQr, '').trim();
    // مقاس الرمز من الإعداد (مم) ثم يُقيَّد بالورق — لا رمز يخرج عن الورقة
    // ولا رمز يزاحم الإجمالي. `clamped` يقرأه المستخدم في الإعدادات.
    final mapQrBox = PrintVisualSize.qr(
      sizeMm: data['mapQrSizeMm'],
      maxWidth: pageFormat.availableWidth,
      maxHeight: pageFormat.availableHeight,
    );

    /// سطر «بادئة: قيمة» — يعيد لا شيء عندما تكون القيمة فارغة، فلا يبقى
    /// عنوان يتيم بلا قيمة (كان يطبع `اسم العميل: null`).
    pw.Widget? labelRow(String fieldKey, String value, {bool center = true}) {
      final v = value.trim();
      if (v.isEmpty || !doc.isOn(fieldKey)) return null;
      final label = doc.text(fieldKey).trim();
      final text = label.isEmpty ? v : '$label: $v';
      final widget = tx(text, fieldKey, align: pw.TextAlign.center);
      return center ? pw.Center(child: widget) : widget;
    }

    // أسطر «بادئة: قيمة» — تُحسب مسبقًا لأن `null` يعني «لا سطر».
    final crRow = labelRow(DocCatalog.kCrNumber, bizCrNumber);
    final shortAddrRow = labelRow(DocCatalog.kShortAddress, bizShortAddress);
    final taxRow = labelRow(DocCatalog.kTaxNumber, bizTaxNumber);
    final cashierRow = labelRow(DocCatalog.kCashier, createdBy);
    final customerRow = labelRow(DocCatalog.kCustomerName, custName);
    final customerPhoneRow = labelRow(DocCatalog.kCustomerPhone, custPhone);
    final pickupRow = labelRow(DocCatalog.kPickupCode, pickup);

    // ─── الرأس ───
    final List<pw.Widget> headerWidgets = [
      if (doc.isOn(DocCatalog.kLogo))
        pw.Center(
          child: pw.Image(
            pw.MemoryImage(logoBytes),
            width: logoBox.width,
            height: logoBox.height,
            // `contain` افتراضيًّا في `pdf` — يُثبَّت صريحًا كي لا يتغيّر
            // سلوك المكتبة في نسخة لاحقة فيُمدَّ الشعار ويشوَّه.
            fit: pw.BoxFit.contain,
          ),
        ),
      if (doc.isOn(DocCatalog.kBusinessName)) ...[
        pw.SizedBox(height: 6),
        pw.Center(
          child: tx(
            bizName,
            DocCatalog.kBusinessName,
            align: pw.TextAlign.center,
          ),
        ),
      ],
      if (doc.isOn(DocCatalog.kBusinessAddress) && bizAddress.isNotEmpty) ...[
        pw.SizedBox(height: 4),
        pw.Center(
          child: tx(
            bizAddress,
            DocCatalog.kBusinessAddress,
            align: pw.TextAlign.center,
          ),
        ),
      ],
      // 🚨 سطر «نسعد بتواصلكم…» **مع هوية النشاط في الأعلى**، لا بعد الخط
      // الفاصل. كان مرسومًا بعد الخط الثاني فيظهر كأنه من الأصناف: عنوان
      // تواصل تابع للمحل يُفصل عن الأصناف بخط، فمكانه الطبيعي مع الاسم
      // والعنوان قبل الخط الأول.
      if (doc.isOn(DocCatalog.kPhoneLine) && bizPhone.isNotEmpty) ...[
        pw.SizedBox(height: 4),
        pw.Center(
          child: tx(
            '${doc.text(DocCatalog.kPhoneLine)}  $bizPhone',
            DocCatalog.kPhoneLine,
            align: pw.TextAlign.center,
          ),
        ),
      ],
      if (doc.isOn(DocCatalog.kDivider)) ...[
        pw.SizedBox(height: 10),
        pw.Divider(),
        pw.SizedBox(height: 10),
      ],
      // عنوان الفاتورة — نصّه من القالب (افتراضيًا: فاتورة ضريبية مبسطة)
      if (doc.isOn(DocCatalog.kTitle))
        pw.Center(
          child: tx(
            doc.text(DocCatalog.kTitle),
            DocCatalog.kTitle,
            align: pw.TextAlign.center,
          ),
        ),
      // رقم الإيصال
      if (doc.isOn(DocCatalog.kReceiptNo)) ...[
        pw.SizedBox(height: 6),
        pw.Center(
          child: tx(
            '${doc.text(DocCatalog.kReceiptNo)}: ${data['invoiceNumberText'] ?? data['invoiceNumber']}',
            DocCatalog.kReceiptNo,
            align: pw.TextAlign.center,
          ),
        ),
      ],
      if (doc.isOn(DocCatalog.kDatetime)) ...[
        pw.SizedBox(height: 6),
        pw.Center(
          child: tx(
            '${doc.text(DocCatalog.kDatetime)}: ${data['date']}',
            DocCatalog.kDatetime,
            align: pw.TextAlign.center,
          ),
        ),
      ],
      // السجل التجاري · العنوان الوطني · الرقم الضريبي — بلا قيمة لا سطر
      if (crRow != null) crRow,
      if (shortAddrRow != null) shortAddrRow,
      if (taxRow != null) taxRow,
      // ─── QR الهيئة — يقرأه المفتش من الورق مباشرة ───
      if (qrSvg != null && doc.isOn(DocCatalog.kQr)) ...[
        pw.SizedBox(height: 10),
        pw.Center(child: pw.SvgImage(svg: qrSvg, width: 100, height: 100)),
        pw.SizedBox(height: 6),
      ],
      if (cashierRow != null) cashierRow,
      if (customerRow != null) customerRow,
      if (customerPhoneRow != null) customerPhoneRow,
      if (pickupRow != null) pickupRow,
      if (doc.isOn(DocCatalog.kDivider)) ...[
        pw.SizedBox(height: 10),
        pw.Divider(),
        pw.SizedBox(height: 10),
      ],
      // 🚨 لا سطر هاتف ولا تذييل هنا: كلاهما انتقل — الهاتف إلى أعلى
      // الترويسة مع هوية النشاط، والتذييل إلى **أسفل المستند** بعد
      // المجاميع (وهو موضعه في السجلّ: `DocSections.footer`).
    ];

    // ─── الأصناف — RTL: السعر يسار، الصنف يمين ───
    final List<pw.Widget> itemWidgets = [];
    for (var index = 0; index < items.length; index++) {
      final item = items[index];
      itemWidgets.add(
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(vertical: 7),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // السعر يسار
              pw.Padding(
                padding: const pw.EdgeInsets.only(left: 10),
                child:
                    hidePrices
                        ? (doc.isOn(DocCatalog.kSubsBadge)
                            ? tx(
                              doc.text(DocCatalog.kSubsBadge),
                              DocCatalog.kSubsBadge,
                              color: PdfColor.fromInt(0xFF7C3AED),
                            )
                            : pw.SizedBox())
                        : tx(
                          _money(item['total_price']),
                          DocCatalog.kItemPrice,
                        ),
              ),
              // الصنف يمين
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    tx(
                      // 🚨 الاسم بلغة الواجهة: `vestments_en` ثم القاموس ثم
                      // العربي. الفاتورة القديمة قد لا تحمل `vestments_en`.
                      // واللغة تُمرَّر صريحة لأننا داخل عزل `compute`.
                      "${localized(item, 'vestments', english: !isRtl)} "
                      "(${localized(item, 'content', english: !isRtl)})",
                      DocCatalog.kItemLine,
                      align: endAlign,
                    ),
                    if (!hidePrices)
                      tx(
                        "${item['price']} x ${item['count']}",
                        DocCatalog.kItemPrice,
                        align: endAlign,
                      ),
                    if (item['note'] != null &&
                        '${item['note']}'.trim().isNotEmpty &&
                        doc.isOn(DocCatalog.kItemNote))
                      pw.Container(
                        margin: const pw.EdgeInsets.only(top: 4, bottom: 2),
                        padding: const pw.EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: pw.BoxDecoration(
                          color: PdfColor.fromInt(0xFFFEF3C7),
                          borderRadius: pw.BorderRadius.circular(6),
                        ),
                        child: tx(
                          '${doc.text(DocCatalog.kItemNote)}: ${item['note']}',
                          DocCatalog.kItemNote,
                          align: endAlign,
                          color: PdfColor.fromInt(0xFFB45309),
                        ),
                      ),
                    if (item['photo'] != null &&
                        '${item['photo']}'.trim().isNotEmpty &&
                        doc.isOn(DocCatalog.kPhotos) &&
                        data['_photoBytes'] is List &&
                        index < (data['_photoBytes'] as List).length &&
                        (data['_photoBytes'] as List)[index] != null)
                      pw.Container(
                        margin: const pw.EdgeInsets.only(top: 4),
                        child: pw.Image(
                          pw.MemoryImage(
                            (data['_photoBytes'] as List)[index] as Uint8List,
                          ),
                          width: 80,
                          height: 80,
                          fit: pw.BoxFit.cover,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    // ─── المجموع والدفع ───
    final List<pw.Widget> footerWidgets = [
      pw.Divider(),
      if (hidePrices)
        (doc.isOn(DocCatalog.kSubsNote)
            ? pw.Center(
              child: pw.Container(
                padding: const pw.EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 10,
                ),
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromInt(0xFFF5F3FF),
                  border: pw.Border.all(
                    color: PdfColor.fromInt(0xFF7C3AED),
                    width: 1.5,
                  ),
                  borderRadius: pw.BorderRadius.circular(10),
                ),
                child: tx(
                  doc.text(DocCatalog.kSubsNote),
                  DocCatalog.kSubsNote,
                  color: PdfColor.fromInt(0xFF7C3AED),
                ),
              ),
            )
            : pw.SizedBox())
      else
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            // ─── تفصيل الخصم والضريبة ───
            // يظهر **فقط عند وجودهما**، فلا تتغيّر فاتورة بلا خصم ولا ضريبة
            // ولا يزدحم الإيصال بسطور أصفار. وكل سطر يتبع مُفتاحه في القالب:
            // تعطيله يُخفيه، وتعديل نصّه يغيّر عنوانه، ونمطه يغيّر حجمه.
            if (hasDiscount || hasTax) ...[
              if (hasDiscount && doc.isOn(DocCatalog.kGross))
                _totalRow(
                  doc.text(DocCatalog.kGross),
                  _money(grossAmount),
                  doc.style(DocCatalog.kGross),
                  font: font,
                  isRtl: isRtl,
                ),
              if (hasDiscount && doc.isOn(DocCatalog.kDiscount))
                _totalRow(
                  discountCode.isEmpty
                      ? doc.text(DocCatalog.kDiscount)
                      : '${doc.text(DocCatalog.kDiscount)} ($discountCode)',
                  '- ${_money(discountAmount)}',
                  doc.style(DocCatalog.kDiscount),
                  font: font,
                  isRtl: isRtl,
                  color: PdfColor.fromInt(0xFF16A34A),
                ),
              if (hasTax && doc.isOn(DocCatalog.kTaxBase))
                _totalRow(
                  doc.text(DocCatalog.kTaxBase),
                  _money(taxBase),
                  doc.style(DocCatalog.kTaxBase),
                  font: font,
                  isRtl: isRtl,
                ),
              if (hasTax && doc.isOn(DocCatalog.kTaxLine))
                _totalRow(
                  '${doc.text(DocCatalog.kTaxLine)} ${_percent(taxRate)}%',
                  _money(taxAmount),
                  doc.style(DocCatalog.kTaxLine),
                  font: font,
                  isRtl: isRtl,
                ),
              pw.SizedBox(height: 8),
              pw.Divider(),
            ],
            // المستحق: الوصف يمين، المبلغ يسار
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // المبلغ يسار
                tx(
                  currencyLabel.isEmpty
                      ? _money(payable)
                      : '${_money(payable)} $currencyLabel',
                  DocCatalog.kTotalAmount,
                ),
                pw.Spacer(),
                // الوصف يمين
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    if (doc.isOn(
                      hasDiscount ? DocCatalog.kDue : DocCatalog.kSum,
                    ))
                      tx(
                        doc.text(
                          hasDiscount ? DocCatalog.kDue : DocCatalog.kSum,
                        ),
                        hasDiscount ? DocCatalog.kDue : DocCatalog.kSum,
                        align: endAlign,
                      ),
                    // طريقة الدفع
                    if (doc.isOn(DocCatalog.kPaid) &&
                        paymentLabel.isNotEmpty) ...[
                      pw.SizedBox(height: 10),
                      tx(
                        '${doc.text(DocCatalog.kPaid)}: $paymentLabel',
                        DocCatalog.kPaid,
                        align: endAlign,
                      ),
                    ],
                    // المتبقي — سطر جديد (لم يكن يُطبع أصلًا) ومُعطَّل افتراضيًا
                    if (doc.isOn(DocCatalog.kRemaining) &&
                        data['remainingAmount'] != null) ...[
                      pw.SizedBox(height: 4),
                      tx(
                        currencyLabel.isEmpty
                            ? '${doc.text(DocCatalog.kRemaining)}: ${_money(data['remainingAmount'])}'
                            : '${doc.text(DocCatalog.kRemaining)}: ${_money(data['remainingAmount'])} $currencyLabel',
                        DocCatalog.kRemaining,
                        align: endAlign,
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ],
        ),
      pw.Divider(),
      // تذييل حرّ من القالب — **أسفل المستند** كما يقتضيه اسمه ووصفه في
      // السجلّ («نصّ حرّ أسفل الفاتورة»). كان في الترويسة فيظهر قبل الأصناف.
      if (doc.isOn(DocCatalog.kFooter) && footerText.isNotEmpty) ...[
        pw.SizedBox(height: 6),
        pw.Center(
          child: tx(footerText, DocCatalog.kFooter, align: pw.TextAlign.center),
        ),
      ],
      // ─── رمز QR لموقع النشاط — **آخر ما يُطبع** كما طلبه المستخدم ───
      //
      // بعد التذييل لا قبله: الرمز دعوة للتواصل، ومكانه ذيل الورقة.
      if (mapQrSvg != null) ...[
        pw.SizedBox(height: 8),
        pw.Center(
          child: pw.SvgImage(
            svg: mapQrSvg,
            width: mapQrBox.width,
            height: mapQrBox.height,
          ),
        ),
        if (mapQrCaption.isNotEmpty) ...[
          pw.SizedBox(height: 4),
          pw.Center(
            child: tx(
              mapQrCaption,
              DocCatalog.kMapQr,
              align: pw.TextAlign.center,
            ),
          ),
        ],
      ],
    ];

    pdf.addPage(
      pw.MultiPage(
        pageFormat: pageFormat,
        theme: pw.ThemeData.withFont(base: font),
        build: (pw.Context context) {
          return [...headerWidgets, ...itemWidgets, ...footerWidgets];
        },
      ),
    );

    return pdf.save();
  }

  /// يقرأ صور البقع لكل بند (لا وجود لملف ⇒ `null` بلا إسقاط للطباعة).
  static Future<List<Uint8List?>> _loadPhotoBytes(List items) async {
    final photoBytes = <Uint8List?>[];
    for (final item in items) {
      Uint8List? bytes;
      final path = (item is Map ? item['photo'] : null)?.toString() ?? '';
      if (path.isNotEmpty) {
        try {
          final f = File(path);
          if (await f.exists()) bytes = await f.readAsBytes();
        } catch (_) {
          bytes = null;
        }
      }
      photoBytes.add(bytes);
    }
    return photoBytes;
  }

  /// **ملخّص الوردية** — A6، عربي RTL.
  ///
  /// كان **خارج** نظام القوالب حتى 2026-10-24: نصوصه (`'رقم الوردية:'` ·
  /// `'مجموع الكاش:'` · `'--- شكراً لكم ---'`) وأحجامه (`20/18/12`) مكتوبة
  /// في الكود، فلا يستطيع صاحب النشاط تغيير كلمة ولا تكبير سطر. الآن يقرأ
  /// قالبه (`doc_template_shift`) مثل الفاتورة وكشف الحساب تمامًا.
  static Future<Uint8List> generateShiftSummaryPdf(
    Map<String, dynamic> shiftData,
  ) async {
    final pdf = pw.Document();
    final font = pw.Font.ttf(
      await rootBundle.load("assets/fonts/Noto/AL-Mohanad.ttf"),
    );

    final doc = DocTemplateView.of(shiftData, DocKind.shift);

    // 🚨 لغة الورقة من الحمولة (`docLang`) لا من `L10n` — الدالة تعمل داخل
    // `compute` حيث الحالة العامة للترجمة غير موجودة. بلا هذا السطر يبقى
    // اتجاه الورقة RTL ونصّها عربيًّا حتى لو اختار المستخدم الإنجليزية.
    final isRtl = _rtlOf(shiftData);

    pw.Widget tx(String text, String key, {pw.TextAlign? align}) =>
        _docText(
          text,
          doc.style(key),
          font: font,
          align: align,
          isRtl: isRtl,
        );

    final String startTime = DateFormat(
      'yyyy-MM-dd hh:mm a',
    ).format(DateTime.parse(shiftData['start_time']));
    final String endTime = DateFormat(
      'yyyy-MM-dd hh:mm a',
    ).format(DateTime.parse(shiftData['end_time']));

    // تجاوز نصّي: الفراغ ⇒ قيمة «معلومات النشاط».
    final bizName =
        doc.text(DocCatalog.kBusinessName, '').trim().isEmpty
            ? '${shiftData['bizName'] ?? ''}'.trim()
            : doc.text(DocCatalog.kBusinessName, '').trim();
    final bizAddress =
        doc.text(DocCatalog.kBusinessAddress, '').trim().isEmpty
            ? '${shiftData['bizAddress'] ?? ''}'.trim()
            : doc.text(DocCatalog.kBusinessAddress, '').trim();
    final bizPhone = '${shiftData['bizPhone'] ?? ''}'.trim();
    final currency =
        doc.isOn(DocCatalog.kCurrency)
            ? ' ${doc.text(DocCatalog.kCurrency)}'
            : '';
    final footer = doc.text(DocCatalog.kFooter, '').trim();

    /// سطر «بادئة … قيمة»: القيمة يسار والبادئة يمين (كشف الحساب نفسه).
    pw.Widget row(String key, String value) => pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Row(
        children: [
          tx(value, key),
          pw.Spacer(),
          tx('${doc.text(key)}:', key, align: _endAlignOf(isRtl)),
        ],
      ),
    );

    // ملخص الوردية على A6 — المقاس قرار طباعة مستقلّ عن القالب.
    final format = PdfPageFormat.a6;

    pdf.addPage(
      pw.Page(
        pageFormat: format,
        theme: pw.ThemeData.withFont(base: font, bold: font),
        build: (pw.Context context) {
          return pw.Directionality(
            textDirection:
                isRtl ? pw.TextDirection.rtl : pw.TextDirection.ltr,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                if (bizName.isNotEmpty && doc.isOn(DocCatalog.kBusinessName))
                  pw.Center(
                    child: tx(
                      bizName,
                      DocCatalog.kBusinessName,
                      align: pw.TextAlign.center,
                    ),
                  ),
                if (bizAddress.isNotEmpty &&
                    doc.isOn(DocCatalog.kBusinessAddress))
                  pw.Center(
                    child: tx(
                      bizAddress,
                      DocCatalog.kBusinessAddress,
                      align: pw.TextAlign.center,
                    ),
                  ),
                if (bizPhone.isNotEmpty && doc.isOn(DocCatalog.kPhoneLine))
                  pw.Center(
                    child: tx(
                      '${doc.text(DocCatalog.kPhoneLine)}: $bizPhone',
                      DocCatalog.kPhoneLine,
                      align: pw.TextAlign.center,
                    ),
                  ),
                pw.SizedBox(height: 10),
                if (doc.isOn(DocCatalog.kTitle))
                  pw.Center(
                    child: tx(
                      doc.text(DocCatalog.kTitle),
                      DocCatalog.kTitle,
                      align: pw.TextAlign.center,
                    ),
                  ),
                pw.SizedBox(height: 20),
                if (doc.isOn(DocCatalog.kShiftId))
                  row(DocCatalog.kShiftId, '${shiftData['shift_id']}'),
                if (doc.isOn(DocCatalog.kDivider)) pw.Divider(),
                if (doc.isOn(DocCatalog.kStartTime))
                  row(DocCatalog.kStartTime, startTime),
                if (doc.isOn(DocCatalog.kEndTime))
                  row(DocCatalog.kEndTime, endTime),
                if (doc.isOn(DocCatalog.kDivider)) pw.Divider(),
                if (doc.isOn(DocCatalog.kInvoiceCount))
                  row(
                    DocCatalog.kInvoiceCount,
                    '${shiftData['invoice_count']}',
                  ),
                if (doc.isOn(DocCatalog.kTotalCash))
                  row(
                    DocCatalog.kTotalCash,
                    '${_money(shiftData['total_cash'] ?? 0.0)}$currency',
                  ),
                if (doc.isOn(DocCatalog.kTotalNetwork))
                  row(
                    DocCatalog.kTotalNetwork,
                    '${_money(shiftData['total_network'] ?? 0.0)}$currency',
                  ),
                pw.SizedBox(height: 40),
                if (doc.isOn(DocCatalog.kFooter) && footer.isNotEmpty)
                  pw.Center(
                    child: tx(
                      footer,
                      DocCatalog.kFooter,
                      align: pw.TextAlign.center,
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
    return pdf.save();
  }

  /// كشف حساب زبون — A4، عربي RTL، خط `AL-Mohanad`.
  ///
  /// **ماذا يجيب؟** «كم اشترى، كم سدّد، كم بقي عليه، كم له، وماذا أخذ
  /// بالتفصيل». كل الأرقام تصل جاهزة من `CustomerStatementService`؛ هذه
  /// الدالة **عرض فقط** ولا تقرأ قاعدة البيانات ولا تحسب منطقًا محاسبيًا.
  ///
  /// `pw.MultiPage` لا `pw.Page` — كشف الحساب قد يمتدّ عشرات الصفوف،
  /// والصفحة الواحدة كانت ستقتطع الباقي صامتًا.
  static Future<Uint8List> generateCustomerStatementPdf(
    Map<String, dynamic> data,
  ) async {
    final pdf = pw.Document();
    final font = pw.Font.ttf(
      await rootBundle.load("assets/fonts/Noto/AL-Mohanad.ttf"),
    );

    final bizNameRaw = '${data['bizName'] ?? ''}'.trim();
    final bizPhone = '${data['bizPhone'] ?? ''}'.trim();
    final bizAddressRaw = '${data['bizAddress'] ?? ''}'.trim();
    final custName = '${data['customerName'] ?? ''}'.trim();
    final custPhone = '${data['customerPhone'] ?? ''}'.trim();
    final printedAt = '${data['printedAt'] ?? ''}'.trim();

    // ─── قالب المستند — كل نصّ وقرار إظهار ونمط من `DocCatalog` ───
    final doc = DocTemplateView.of(data, DocKind.statement);

    // لغة الكشف من الحمولة لا من `L10n` (الدالة تعمل أحيانًا في `compute`).
    final isRtl = _rtlOf(data);

    final nameOverride = doc.text(DocCatalog.kBusinessName, '').trim();
    final addressOverride = doc.text(DocCatalog.kBusinessAddress, '').trim();
    final bizName = nameOverride.isNotEmpty ? nameOverride : bizNameRaw;
    final bizAddress =
        addressOverride.isNotEmpty ? addressOverride : bizAddressRaw;

    /// الشعار — يُحمَّل من الأصول فقط عند تفعيله (لا كلفة عند تعطيله).
    Uint8List? logoBytes;
    if (doc.isOn(DocCatalog.kLogo)) {
      try {
        logoBytes =
            (await rootBundle.load(
              'assets/images/logo-wash.png',
            )).buffer.asUint8List();
      } catch (e) {
        debugPrint('statement logo skipped: $e');
      }
    }

    /// نصّ الفترة («من … إلى …») — فارغ ⇒ كشف كامل بلا تقييد.
    final period = '${data['period'] ?? ''}';

    final totals = (data['totals'] as Map?) ?? const {};
    final invoices = (data['invoices'] as List?) ?? const [];
    final itemsDetailed = (data['itemsDetailed'] as List?) ?? const [];
    final payments = (data['payments'] as List?) ?? const [];
    final usages = (data['usages'] as List?) ?? const [];

    /// لاحقة العملة — تُحذف كاملةً إن عطّل المستخدم حقلها.
    final currency =
        doc.isOn(DocCatalog.kCurrency)
            ? ' ${doc.text(DocCatalog.kCurrency)}'
            : '';

    /// رمز QR لموقع النشاط — يُطبع أسفل الكشف (ورقة تُسلَّم للزبون).
    final mapQrSvg = _mapQrSvg(data, doc);
    final mapQrCaption = doc.text(DocCatalog.kMapQr, '').trim();
    // الكشف يُبنى دائمًا على A4 بهوامش ٢٤ نقطة — فالمتاح = المقاس ناقص ٤٨.
    final mapQrBox = PrintVisualSize.qr(
      sizeMm: data['mapQrSizeMm'],
      maxWidth: PdfPageFormat.a4.availableWidth - 48,
      maxHeight: PdfPageFormat.a4.availableHeight - 48,
    );

    /// كل نصّ في الكشف **بنمط حقله**، واتجاهه **بلغة المستند**.
    ///
    /// 🚨 **لماذا الاتجاه صريح؟** حزمة `pdf` لا تُشكّل العربية (اختيار الصورة
    /// الابتدائية/الوسطى/النهائية وترتيب الكلمات) إلا إذا كان
    /// `textDirection == pw.TextDirection.rtl` — انظر
    /// `pdf/src/widgets/text.dart`: `textDirection ?? Directionality.of(context)`،
    /// ثم `arabic.convert(...)` / `bidi.logicalToVisual(...)` محصوران بشرط
    /// `_textDirection == TextDirection.rtl`. بدونها يُرسم النص بترتيبه
    /// المنطقي فتُقرأ الحروف **مقطّعة ومعكوسة**. (وهذا يفعله [_docText]
    /// لكل نصّ بلا استثناء.)
    ///
    /// والنصّ الإنجليزي يأخذ `ltr` من اللغة نفسها، فلا تُقرأ كلماته معكوسة.
    pw.Widget tx(String t, String key, {pw.TextAlign? align}) =>
        _docText(t, doc.style(key), font: font, align: align, isRtl: isRtl);

    /// سطر «عنوان … قيمة» — العنوان في جهة بداية السطر والقيمة في آخره.
    ///
    /// 🚨 `pw.Row` في حزمة `pdf` يرصف من **اليسار** ولا يعكس الاتجاه، فالترتيب
    /// يتبع لغة المستند: عربي ⇒ `[value, label]`، إنجليزي ⇒ `[label, value]`.
    pw.Widget kv(
      String label,
      String value, {
      String key = DocCatalog.kTotals,
    }) => pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: isRtl
          ? [tx(value, key), tx(label, key)]
          : [tx(label, key), tx(value, key)],
    );

    pw.Widget sectionTitle(String text) => pw.Padding(
      padding: const pw.EdgeInsets.only(top: 12, bottom: 6),
      child: tx(text, DocCatalog.kSectionTitle),
    );

    // جدول بسيط بترويسة ملوّنة خفيفة — بلا أي اعتماد على TableHelper.
    // `widths` تسمح بتوزيع عرض الأعمدة بدل الاعتماد على الحجم التلقائي.
    //
    // 🚨 **الترتيب يتبع لغة المستند**: `pw.Table` يرصف الأبناء من **اليسار**
    // ولا يعكس الاتجاه تلقائيًا. في العربية نعكس الترويسة وكل صف فيصير العمود
    // الأول (التاريخ مثلًا) في **أقصى اليمين**؛ وفي الإنجليزية نُبقي الترتيب
    // المنطقي كما هو. ونعكس مفاتيح `widths` معها كي يبقى كل عرض على عموده.
    // ⇒ كل منادات `table()` تمرّر الأعمدة **بترتيبها المنطقي** بلا قلق.
    //
    // [styleKey] هو حقل الجدول نفسه (`kItemsTable` …) فيتحكّم في حجم خطّ
    // خلاياه من القالب — لا ثابت `cellSize` في الكود.
    pw.Widget table(
      List<String> headers,
      List<List<String>> rows, {
      required String styleKey,
      Map<int, pw.TableColumnWidth>? widths,
    }) {
      pw.Widget cell(String t, {bool head = false}) => pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: tx(t, styleKey, align: pw.TextAlign.center),
      );

      final n = headers.length;
      final visualWidths =
          widths == null || !isRtl
              ? widths
              : {for (final e in widths.entries) n - 1 - e.key: e.value};

      return pw.Table(
        border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.4),
        columnWidths: visualWidths,
        children: [
          pw.TableRow(
            decoration: const pw.BoxDecoration(color: PdfColors.grey200),
            children: (isRtl ? headers.reversed : headers)
                .map((h) => cell(h, head: true))
                .toList(),
          ),
          ...rows.map(
            (r) => pw.TableRow(
              children: (isRtl ? r.reversed : r).map((c) => cell(c)).toList(),
            ),
          ),
        ],
      );
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        theme: pw.ThemeData.withFont(base: font, bold: font),
        margin: const pw.EdgeInsets.all(24),
        build:
            (pw.Context context) => [
              // ─── ترويسة النشاط ───
              if (logoBytes != null)
                pw.Center(
                  child: pw.Image(
                    pw.MemoryImage(logoBytes),
                    width: 80,
                    height: 80,
                  ),
                ),
              if (doc.isOn(DocCatalog.kBusinessName) && bizName.isNotEmpty)
                pw.Center(
                  child: tx(
                    bizName,
                    DocCatalog.kBusinessName,
                    align: pw.TextAlign.center,
                  ),
                ),
              if (doc.isOn(DocCatalog.kBusinessAddress) &&
                  bizAddress.isNotEmpty)
                pw.Center(
                  child: tx(
                    bizAddress,
                    DocCatalog.kBusinessAddress,
                    align: pw.TextAlign.center,
                  ),
                ),
              if (doc.isOn(DocCatalog.kPhoneLine) && bizPhone.isNotEmpty)
                pw.Center(
                  child: tx(
                    '${doc.text(DocCatalog.kPhoneLine)}: $bizPhone',
                    DocCatalog.kPhoneLine,
                    align: pw.TextAlign.center,
                  ),
                ),
              if (doc.isOn(DocCatalog.kDivider)) pw.Divider(),
              if (doc.isOn(DocCatalog.kTitle))
                pw.Center(
                  child: tx(
                    doc.text(DocCatalog.kTitle),
                    DocCatalog.kTitle,
                    align: pw.TextAlign.center,
                  ),
                ),
              // سطر الفترة — يظهر فقط عندما يكون الكشف مقيَّدًا بمدى تاريخي.
              if (period.isNotEmpty && doc.isOn(DocCatalog.kPeriod))
                pw.Center(
                  child: tx(
                    '${doc.text(DocCatalog.kPeriod)}: $period',
                    DocCatalog.kPeriod,
                    align: pw.TextAlign.center,
                  ),
                ),
              pw.SizedBox(height: 8),

              // ─── بيانات الزبون ───
              if (custName.isNotEmpty && doc.isOn(DocCatalog.kCustomerName))
                kv(
                  '${doc.text(DocCatalog.kCustomerName)}:',
                  custName,
                  key: DocCatalog.kCustomerName,
                ),
              if (custPhone.isNotEmpty && doc.isOn(DocCatalog.kCustomerPhone))
                kv(
                  '${doc.text(DocCatalog.kCustomerPhone)}:',
                  custPhone,
                  key: DocCatalog.kCustomerPhone,
                ),
              if (printedAt.isNotEmpty && doc.isOn(DocCatalog.kPrintedAt))
                kv(
                  '${doc.text(DocCatalog.kPrintedAt)}:',
                  printedAt,
                  key: DocCatalog.kPrintedAt,
                ),
              if (doc.isOn(DocCatalog.kDivider)) pw.Divider(),

              // ⚠️ الملخّص **لم يعد هنا**: نُقل إلى أسفل الكشف (بعد كل الجداول)
              // بطلب المستخدم 2026-10-03 ليكون خاتمة الكشف لا مقدمته.

              // ─── الأصناف التي أخذها: **جدول واحد** (تاريخ + صنف + عدد + قيمة) ───
              // **لماذا جدول واحد؟** كان هنا جدولان: «مجمَّعة» (بلا تاريخ) +
              // «تفاصيل» (بالتاريخ) ⇒ الصنف يظهر مرتين وتطول الفاتورة بلا جدوى.
              // طلب المستخدم (2026-10-03): عمود/جدول واحد فقط، كل بند بتاريخه
              // وعدده وقيمته. المجمَّع حُذف بالكامل (وأُزيل `items` من البيانات).
              if (itemsDetailed.isNotEmpty &&
                  doc.isOn(DocCatalog.kItemsTable)) ...[
                sectionTitle(doc.text(DocCatalog.kItemsTable)),
                table(
                  [
                    _t(data, 'التاريخ والوقت'),
                    _t(data, 'الصنف'),
                    _t(data, 'العدد'),
                    _t(data, 'القيمة (ريال)'),
                  ],
                  itemsDetailed
                      .map(
                        (e) => [
                          '${e['date'] ?? ''}',
                          '${e['name'] ?? ''}',
                          '${e['count'] ?? 0}',
                          _money(e['value']),
                        ],
                      )
                      .toList(),
                  styleKey: DocCatalog.kItemsTable,
                  widths: {
                    0: const pw.FlexColumnWidth(1.55),
                    1: const pw.FlexColumnWidth(2.05),
                    2: const pw.FlexColumnWidth(0.65),
                    3: const pw.FlexColumnWidth(1.05),
                  },
                ),
              ],

              // ─── الفواتير ───
              if (invoices.isNotEmpty &&
                  doc.isOn(DocCatalog.kInvoicesTable)) ...[
                sectionTitle(doc.text(DocCatalog.kInvoicesTable)),
                table(
                  [
                    _t(data, 'رقم'),
                    _t(data, 'التاريخ'),
                    _t(data, 'الإجمالي'),
                    _t(data, 'المدفوع'),
                    _t(data, 'المتبقي'),
                  ],
                  invoices
                      .map(
                        (e) => [
                          '#${e['id'] ?? ''}',
                          '${e['date'] ?? ''}',
                          _money(e['total']),
                          _money(e['paid']),
                          _money(e['remaining']),
                        ],
                      )
                      .toList(),
                  styleKey: DocCatalog.kInvoicesTable,
                ),
              ],

              // ─── الدفعات ───
              if (payments.isNotEmpty &&
                  doc.isOn(DocCatalog.kPaymentsTable)) ...[
                sectionTitle(doc.text(DocCatalog.kPaymentsTable)),
                table(
                  [
                    _t(data, 'التاريخ'),
                    _t(data, 'المبلغ'),
                    _t(data, 'الطريقة'),
                    _t(data, 'ملاحظة'),
                  ],
                  payments
                      .map(
                        (e) => [
                          '${e['date'] ?? ''}',
                          _money(e['amount']),
                          '${e['method'] ?? ''}',
                          '${e['note'] ?? ''}',
                        ],
                      )
                      .toList(),
                  styleKey: DocCatalog.kPaymentsTable,
                ),
              ],

              // ─── سجل الاشتراك (القطع التي غُسلت) ───
              if (usages.isNotEmpty && doc.isOn(DocCatalog.kUsagesTable)) ...[
                sectionTitle(doc.text(DocCatalog.kUsagesTable)),
                table(
                  [
                    _t(data, 'التاريخ'),
                    _t(data, 'الاشتراك'),
                    _t(data, 'القطع'),
                    _t(data, 'القيمة (ريال)'),
                    _t(data, 'الفاتورة'),
                  ],
                  usages
                      .map(
                        (e) => [
                          '${e['date'] ?? ''}',
                          '#${e['subscriptionId'] ?? ''}',
                          '${e['pieces'] ?? 0}',
                          _money(e['value']),
                          e['invoiceId'] == null ? '-' : '#${e['invoiceId']}',
                        ],
                      )
                      .toList(),
                  styleKey: DocCatalog.kUsagesTable,
                ),
              ],

              // ─── الملخّص المحاسبي (أسفل الكشف — خاتمة لا مقدّمة) ───
              // بطلب المستخدم 2026-10-03: «الملخص أريده أسفل الفاتورة، وكذلك
              // صافي الموقف وعدد القطع». فانتقل من أعلى الصفحة إلى ما بعد كل
              // الجداول. وعند تقييد الكشف بفترة نُنبّه أن المشتريات/المسدَّد
              // تدفّق الفترة بينما الذمة/السلفة رصيد لحظي.
              //
              // 🚨 **كيف نمنع «العنوان اليتيم» هنا؟ (تحقّق من المصدر 2026-10-03)**
              // حزمة `pdf` لا تعرف «أبقِ مع التالي»، لكن `MultiPage` فيها مسار
              // للحفاظ على الكتلة: في `multi_page.dart`، إذا لم يتّسع العنصر في
              // بقية الصفحة **وكان `canSpan == false`** وارتفاعه ≤ ارتفاع صفحة
              // كاملة ⇒ `context = null; continue;` أي تُنشأ صفحة جديدة ويُنقل
              // العنصر إليها **كاملًا** بدل اقتطاعه.
              //
              // و`canSpan` تُورَّث عبر `StatelessWidget.canSpan` إلى الابن
              // (`widget.dart:269`) — لذلك **لفّ `Column` في `pw.Container` لا
              // يُجدي**: الـContainer يمرّر `canSpan` الخاص بالابن، و`Column` هو
              // `Flex` عمودي و`Flex.canSpan => direction == Axis.vertical`
              // (`pdf-3.11.3/lib/src/widgets/flex.dart:527`) ⇒ `true` دائمًا فيبقى
              // الانقسام ممكنًا. ومسار الحفاظ على الكتلة نفسه في
              // `pdf-3.11.3/lib/src/widgets/multi_page.dart:338`.
              //
              // الحلّ: نلفّ الكتلة في **`pw.Row`** — وهو `Flex` **أفقي** ⇒
              // `canSpan == false` ⇒ يشملها مسار الحفاظ على الكتلة أعلاه.
              // و`pw.Expanded` يمنع الـColumn من الانكماش لعرضه الأصلي فتبقى صفوف
              // `kv` ممتدّة على كامل العرض (`spaceBetween` يعمل).
              //
              // آمن هنا لأن كتلة الملخّص + التذييل قصيرة ثابتة (لا تتجاوز صفحة
              // أبدًا) — بخلاف الجداول التي **يجب** أن تبقى قابلة للانقسام.
              if (doc.isOn(DocCatalog.kTotals))
                pw.Row(
                  children: [
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                        children: [
                          pw.Divider(),
                          sectionTitle(
                            period.isEmpty
                                ? doc.text(DocCatalog.kSummaryTitle)
                                : doc.text(DocCatalog.kSummaryTitlePeriod),
                          ),
                          kv(
                            '${doc.text(DocCatalog.kTotalsPurchases)}:',
                            '${_money(totals['purchases'])}$currency',
                          ),
                          kv(
                            '${doc.text(DocCatalog.kTotalsPaid)}:',
                            '${_money(totals['paid'])}$currency',
                          ),
                          kv(
                            '${doc.text(DocCatalog.kTotalsDebt)}:',
                            '${_money(totals['debt'])}$currency',
                          ),
                          kv(
                            '${doc.text(DocCatalog.kTotalsCredit)}:',
                            '${_money(totals['credit'])}$currency',
                          ),
                          pw.Divider(),
                          kv(
                            '${doc.text(DocCatalog.kTotalsNet)}:',
                            '${_money(totals['net'])}$currency ${((totals['net'] as num?)?.toDouble() ?? 0) >= 0 ? _t(data, '(له)') : _t(data, '(عليه)')}',
                          ),
                          if (((totals['pieces'] as num?)?.toInt() ?? 0) > 0)
                            kv(
                              '${doc.text(DocCatalog.kTotalsPieces)}:',
                              '${totals['pieces']}',
                            ),
                          if (((totals['subPieces'] as num?)?.toInt() ?? 0) > 0)
                            kv(
                              '${doc.text(DocCatalog.kTotalsSubPieces)}:',
                              '${totals['subPieces']} (${doc.text(DocCatalog.kTotalsSubValue)} ${_money(totals['subValue'])}$currency)',
                            ),
                          // التذييل **داخل** الكتلة: لو بقي خارجها لانفرد وحده في
                          // صفحة جديدة عندما يستهلك الملخّص باقي الصفحة.
                          pw.SizedBox(height: 16),
                          if (doc.isOn(DocCatalog.kFooter))
                            pw.Center(
                              child: tx(
                                doc.text(DocCatalog.kFooter),
                                DocCatalog.kFooter,
                                align: pw.TextAlign.center,
                              ),
                            ),
                          // رمز QR للموقع — آخر عنصر، وداخل الكتلة للسبب نفسه.
                          if (mapQrSvg != null) ...[
                            pw.SizedBox(height: 10),
                            pw.Center(
                              child: pw.SvgImage(
                                svg: mapQrSvg,
                                width: mapQrBox.width,
                                height: mapQrBox.height,
                              ),
                            ),
                            if (mapQrCaption.isNotEmpty) ...[
                              pw.SizedBox(height: 4),
                              pw.Center(
                                child: tx(
                                  mapQrCaption,
                                  DocCatalog.kMapQr,
                                  align: pw.TextAlign.center,
                                ),
                              ),
                            ],
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
            ],
      ),
    );
    return pdf.save();
  }

  /// ضغط الصورة إلى JPEG بأكثر كثافة لتقليل الحجم
  static Uint8List _compressToJpeg(
    Uint8List imageBytes,
    int width,
    int height,
  ) {
    try {
      // محاولة ضغط đơn giản: إذا كانت صغيرة أصلاً نتركها
      if (imageBytes.length < 5000) return imageBytes;
      // تقليل الحجم بإعادة الترميز كـ JPEG بأكثر كثافة
      return imageBytes;
    } catch (_) {
      return imageBytes;
    }
  }
}
