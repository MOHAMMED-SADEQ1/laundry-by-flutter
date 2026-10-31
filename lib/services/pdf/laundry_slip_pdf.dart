/// **مولّد PDF لورقة المغسلة** — نسخة المحل التي تُرفق بكيس الغسيل.
///
/// ## القرارات الثابتة
///   • **نفس مقاس فاتورة العميل** (`invoice_paper_size`) — لا مقاس مستقلّ.
///   • **بلا أسعار أو خصم أو ضريبة أو QR أو طريقة دفع** — ورقة عمليات فقط.
///   • تتكيّف مع الورق: جدول على A4/A5، وسطور مضغوطة على الحراري/A6.
///   • الحراري ارتفاعه مُقدَّر من المحتوى لا A4 كاملًا — لتقليل هدر الورق.
///   • رقم الفاتورة يتكرّر أعلى الصفحات التالية عند امتداد الأصناف.
///
/// ## لماذا يقرأ القالب؟
/// كان كل نصّ وحجم وخطّ في هذه الورقة مكتوبًا في الكود. الآن كل عنصر يمرّ من
/// `DocTemplate` (`doc_template_laundry_slip`): يُفعَّل/يُعطَّل، ويُحرَّر نصّه،
/// ويُضبط حجمه ووزنه وعرضه من شاشة «قوالب الطباعة» — بلا إعادة بناء.
library;

import 'dart:typed_data';

import 'package:flutter/services.dart' show Matrix4;
import 'package:laundry/core/services/paper_size.dart';
import 'package:laundry/services/pdf/arabic_text.dart';
import 'package:laundry/services/pdf/doc_template.dart';
import 'package:laundry/services/pdf/laundry_slip.dart';
import 'package:laundry/services/printer/print_layout.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class LaundrySlipPdf {
  LaundrySlipPdf._();

  /// ارتفاع حراري مُقدَّر — أقلّ ما يمكن مع بقاء الترويسة والتوقيع مقروءين.
  ///
  /// الحراري ورق متصل، فالصفحة القصيرة تُقلّل الهدر. القيمة تُستخدم في
  /// **مقاس مهمة الطباعة** أيضًا (`paperFor…`) كي لا يُرسل الإيصال إلى تعريف
  /// بارتفاع A4 كامل.
  ///
  /// [doc] يسمح بخصم الأقسام المُعطَّلة من التقدير. غيابه (المسارات القديمة
  /// والاختبارات) يُبقي الأرقام الأصلية المجرَّبة بلا تغيير.
  static double estimatedHeightMm({
    required PaperSize base,
    required int itemsCount,
    required int notesCount,
    bool hasLogo = false,
    DocTemplateView? doc,
  }) {
    if (!base.isThermal) return base.heightMm;
    final narrow = base.widthMm <= 58;
    // القيم مُقاسة على التوليد الفعلي بهامش أمان: التقدير الأقلّ يُنتج صفحة
    // ثانية فيها التوقيعات وحدها — وهي ورقة يُقصّها القاطع التلقائي وحدها.
    final logo = hasLogo ? 26.0 : 0.0;
    var header = narrow ? 82.0 : 78.0;
    if (doc != null) {
      if (!doc.isOn(DocCatalog.kBusinessName)) header -= narrow ? 6 : 7;
      if (!doc.isOn(DocCatalog.kTitle) &&
          !doc.isOn(DocCatalog.kSlipSubtitle)) {
        header -= narrow ? 10 : 12;
      }
      if (!doc.isOn(DocCatalog.kSlipNotice)) header -= narrow ? 4 : 5;
      if (!doc.isOn(DocCatalog.kReceiptNo)) header -= narrow ? 16 : 15;
      var rows = 0;
      if (doc.isOn(DocCatalog.kDatetime)) rows++;
      if (doc.isOn(DocCatalog.kCustomerName)) rows++;
      if (doc.isOn(DocCatalog.kCustomerPhone)) rows++;
      if (doc.isOn(DocCatalog.kPickupCode)) rows++;
      header -= (4 - rows) * (narrow ? 5.0 : 5.5);
      if (!doc.isOn(DocCatalog.kTotalPieces) &&
          !doc.isOn(DocCatalog.kItemsCount)) {
        header -= narrow ? 9 : 10;
      }
      if (!doc.isOn(DocCatalog.kDivider)) header -= narrow ? 6 : 8;
      if (!doc.isOn(DocCatalog.kWorkerSignature)) header -= narrow ? 7 : 8;
      if (!doc.isOn(DocCatalog.kNotesSignature)) header -= narrow ? 7 : 8;
      if (!doc.isOn(DocCatalog.kBusinessPhone)) header -= narrow ? 5 : 6;
    }
    final perItem = narrow ? 12.0 : 11.0;
    final perNote =
        doc != null && !doc.isOn(DocCatalog.kItemNote)
            ? 0.0
            : (narrow ? 6.5 : 6.0);
    final height =
        logo +
        (header < 20 ? 20 : header) +
        itemsCount * perItem +
        notesCount * perNote;
    return height.clamp(80.0, 500.0);
  }

  /// مقاس ورقة المغسلة من رمز مقاس الفاتورة نفسه.
  static PaperSize paperForValues({
    required String paperSize,
    required int itemsCount,
    required int notesCount,
    bool hasLogo = false,
    DocTemplateView? doc,
  }) {
    final base = PaperSizes.resolve(paperSize);
    if (!base.isThermal) return base;
    return PaperSize(
      token: base.token,
      label: base.label,
      widthMm: base.widthMm,
      heightMm: estimatedHeightMm(
        base: base,
        itemsCount: itemsCount,
        notesCount: notesCount,
        hasLogo: hasLogo,
        doc: doc,
      ),
      isThermal: true,
    );
  }

  /// مقاس الورقة من بيانات الورقة الجاهزة (يُستخدم عند الطباعة).
  ///
  /// [hasLogo] يُمرَّر من المسار الخارجي لأن [LaundrySlipData] لا تحمل
  /// الشعار؛ وإغفاله يجعل الشعار يأكل 26 مم من ورقة لم تُحسب لها.
  static PaperSize paperFor(
    LaundrySlipData data, {
    bool hasLogo = false,
    DocTemplateView? doc,
  }) => paperForValues(
    paperSize: data.paperSize,
    itemsCount: data.itemsCount,
    notesCount:
        doc != null && !doc.isOn(DocCatalog.kItemNote)
            ? 0
            : data.items.where((item) => item.note.isNotEmpty).length,
    hasLogo: hasLogo,
    doc: doc,
  );

  /// مقاس الورقة من حمولة PDF (يُستخدم داخل المولّد نفسه).
  ///
  /// هي الطريقة المفضّلة في مسارات الطباعة: تقرأ التفعيلات من الحمولة نفسها
  /// فلا يقدّر المسار الخارجي ارتفاعًا لمحتوى لن يُطبع.
  static PaperSize paperForData(Map<String, dynamic> data) {
    final doc = DocTemplateView.of(data, DocKind.laundrySlip);
    final items = _itemsOf(data);
    final notes =
        doc.isOn(DocCatalog.kItemNote)
            ? items.where((item) => item.note.isNotEmpty).length
            : 0;
    final hasLogo =
        doc.isOn(DocCatalog.kLogo) &&
        data['showLogo'] != false &&
        data['logoImage'] is Uint8List;
    return paperForValues(
      paperSize: '${data['paperSize'] ?? ''}',
      itemsCount: items.length,
      notesCount: notes,
      hasLogo: hasLogo,
      doc: doc,
    );
  }

  /// يبني ملف PDF لورقة المغسلة.
  ///
  /// [data] أنواع أوّلية فقط + `arabicFont` (كائن `pw.Font`). يعمل في
  /// `compute` كما يعمل مباشرةً في الاختبارات.
  static Future<Uint8List> generateLaundrySlipPdf(
    Map<String, dynamic> data,
  ) async {
    final pdf = pw.Document();
    final font = data['arabicFont'] as pw.Font;
    final rtl = _rtlOf(data);
    final paper = paperForData(data);
    // نسخة الطباعة تتكيّف مع ورق الطابعة الفعلي وهوامشها (انظر PrintLayout).
    // الشرح الكامل في `preparePDF.dart`؛ القاعدة نفسها: لا محتوى في هامش
    // غير قابل للطباعة، ولا صفحة أعرض من الورق المادي.
    final printLayout = PrintLayout.fromData(data[PrintLayout.dataKey]);
    final pageWidth =
        printLayout?.width ?? PaperSizes.mmToPoints(paper.widthMm);
    final widthMm = pageWidth / PdfPageFormat.mm;
    final compact = paper.isThermal || widthMm <= 105;
    final narrow = widthMm <= 58;

    // 🚨 القالب هو مصدر النصّ والتفعيل والنمط — لا نصوص مكتوبة هنا.
    final doc = DocTemplateView.of(data, DocKind.laundrySlip);

    final baseMargin = PaperSizes.mmToPoints(
      paper.isThermal ? 2 : (compact ? 7 : 12),
    );
    final safety = PaperSizes.mmToPoints(paper.isThermal ? 0.5 : 1.0);
    final pdfFormat = PrintLayout.pageFormat(
      width: PaperSizes.mmToPoints(paper.widthMm),
      height: PaperSizes.mmToPoints(paper.heightMm),
      layout: printLayout,
      baseMargin: baseMargin,
      safety: safety,
      keepHeight: paper.isThermal,
    );

    final items = _itemsOf(data);
    final invoiceNumber = '${data['invoiceNumber'] ?? ''}'.trim();
    final date = '${data['date'] ?? ''}'.trim();
    final customerName = '${data['customerName'] ?? ''}'.trim();
    final customerPhone = '${data['customerPhone'] ?? ''}'.trim();
    final pickupCode = '${data['pickupCode'] ?? ''}'.trim();
    final bizName = '${data['bizName'] ?? ''}'.trim();
    final bizPhone = '${data['bizPhone'] ?? ''}'.trim();
    final totalPieces =
        int.tryParse('${data['totalPieces'] ?? ''}') ??
        items.fold<int>(0, (sum, item) => sum + item.qty);
    final itemsCount = items.length;

    final logoBytes = data['logoImage'];
    final showLogo =
        doc.isOn(DocCatalog.kLogo) &&
        data['showLogo'] != false &&
        logoBytes is Uint8List;

    /// نسبة حجم المستخدم إلى الحجم الافتراضي للحقل.
    ///
    /// القالب يخزّن **حجمًا واحدًا**، والورقة لها مقاسان (واسع ومضغوط).
    /// فنقرأ الحجم كنسبة: 28 افتراضيًّا و30 مخصّصًا ⇒ +7% على المقاس
    /// التكيّفي، فلا ينكسر التخطيط على الحراري عند تعديل A4.
    double ratioOf(String key) {
      final def =
          DocCatalog.fieldOf(DocKind.laundrySlip, key)?.style.size ?? 9.0;
      if (def <= 0 || !def.isFinite) return 1.0;
      return (doc.style(key).size / def).clamp(0.35, 4.0);
    }

    double scaled(
      String key, {
      required double wide,
      required double compactSize,
    }) {
      final base = compact ? compactSize : wide;
      return (base * ratioOf(key)).clamp(4.0, 72.0);
    }

    /// نقطة رسم واحدة: اتجاه اللغة + تطبيع «لا» + تعريض صناعي + تمديد.
    pw.Widget text(
      String value, {
      required String key,
      double? size,
      PdfColor? color,
      pw.TextAlign? align,
      /// قيم لاتينية داخل سطر عربي (تاريخ · هاتف · رمز): اتجاهها LTR وإلا
      /// أعاد محرّك الاتجاه ترتيب أجزاء التاريخ فظهر «ص 09:30 2026-10-23».
      bool ltr = false,
    }) {
      final style = doc.style(key);
      final actual = size ?? scaled(key, wide: 9, compactSize: 8.2);
      final content = (rtl && !ltr) ? ArabicText.safe(value) : value;
      final direction =
          (rtl && !ltr) ? pw.TextDirection.rtl : pw.TextDirection.ltr;
      pw.Widget layer() => pw.Text(
        content,
        textDirection: direction,
        textAlign: align,
        style: pw.TextStyle(font: font, fontSize: actual, color: color),
      );

      var out = layer();
      // التعريض الصناعي — الخط واحد الوزن، فالمتاح رسم السطر مرّتين.
      final dx = actual * _weightFactor(style.weight);
      if (dx > 0) {
        out = pw.Stack(
          fit: pw.StackFit.passthrough,
          overflow: pw.Overflow.visible,
          children: [
            out,
            pw.Transform.translate(
              offset: PdfPoint(dx, 0),
              child: layer(),
            ),
          ],
        );
      }
      // التضييق الأفقي فقط (القالب يمنع التوسيع فوق 100%).
      if (style.width != 100) {
        out = pw.Transform(
          transform: Matrix4.diagonal3Values(style.widthScale, 1, 1),
          alignment: pw.Alignment.center,
          child: out,
        );
      }
      return out;
    }

    /// سطر «عنوان: قيمة» — يعيد `null` إذا كان الحقل معطَّلًا أو القيمة فارغة.
    pw.Widget? kv(
      String key,
      String value, {
      bool ltrValue = false,
      double wide = 9,
      double compactSize = 8.2,
    }) {
      if (!doc.isOn(key)) return null;
      final v = value.trim();
      if (v.isEmpty) return null;
      final label = doc.text(key).trim();
      final size = scaled(key, wide: wide, compactSize: compactSize);
      final valueWidget = text(
        v,
        key: key,
        size: size,
        align: rtl ? pw.TextAlign.left : pw.TextAlign.right,
        ltr: ltrValue,
      );
      if (label.isEmpty) {
        return pw.Padding(
          padding: pw.EdgeInsets.symmetric(vertical: compact ? 1 : 1.5),
          child: pw.Row(children: [pw.Expanded(child: valueWidget)]),
        );
      }
      return pw.Padding(
        padding: pw.EdgeInsets.symmetric(vertical: compact ? 1 : 1.5),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children:
              rtl
                  ? [
                    pw.Expanded(child: valueWidget),
                    text('$label:', key: key, size: size),
                  ]
                  : [
                    text('$label:', key: key, size: size),
                    pw.Expanded(child: valueWidget),
                  ],
        ),
      );
    }

    pw.Widget twoColumns(pw.Widget? first, pw.Widget? second) {
      final children = <pw.Widget>[];
      if (first != null) children.add(pw.Expanded(child: first));
      if (first != null && second != null) children.add(pw.SizedBox(width: 12));
      if (second != null) children.add(pw.Expanded(child: second));
      if (children.isEmpty) return pw.SizedBox();
      return pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: children,
      );
    }

    pw.Widget numberCard() {
      final label = doc.text(DocCatalog.kReceiptNo).trim();
      final labelSize =
          ((compact ? 7.0 : 10.0) *
                  ratioOf(DocCatalog.kReceiptNo).clamp(0.7, 1.6))
              .clamp(5.0, 24.0);
      final numberSize = scaled(
        DocCatalog.kReceiptNo,
        wide: 28,
        compactSize: narrow ? 15 : 17,
      );
      return pw.Container(
        width: double.infinity,
        padding: pw.EdgeInsets.symmetric(vertical: compact ? 3 : 8),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.black, width: 1),
          borderRadius: pw.BorderRadius.circular(compact ? 4 : 5),
        ),
        child: pw.Column(
          children: [
            if (label.isNotEmpty)
              text(
                label,
                key: DocCatalog.kReceiptNo,
                size: labelSize,
                color: PdfColors.grey700,
                align: pw.TextAlign.center,
              ),
            text(
              invoiceNumber,
              key: DocCatalog.kReceiptNo,
              size: numberSize,
              align: pw.TextAlign.center,
            ),
          ],
        ),
      );
    }

    pw.Widget cell(
      String key,
      String value, {
      required bool head,
      pw.TextAlign align = pw.TextAlign.center,
      double wide = 8.5,
      double compactSize = 8,
    }) => pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 3),
      child: text(
        value,
        key: key,
        size: scaled(key, wide: wide, compactSize: compactSize),
        align: align,
        color: head ? PdfColors.white : null,
      ),
    );

    /// جدول A4/A5 — أعمدته تُبنى من الحقول المُفعَّلة وحدها.
    pw.Widget? wideTable() {
      final active = <String>[
        if (doc.isOn(DocCatalog.kItemName)) DocCatalog.kItemName,
        if (doc.isOn(DocCatalog.kService)) DocCatalog.kService,
        if (doc.isOn(DocCatalog.kQty)) DocCatalog.kQty,
        if (doc.isOn(DocCatalog.kItemNote)) DocCatalog.kItemNote,
      ];
      if (active.isEmpty) return null;
      final columns = <_WideColumn>[
        const _WideColumn(key: '', header: '#', flex: 0.55),
        for (final key in active)
          _WideColumn(
            key: key,
            header: doc.text(key),
            flex: _flexOf(key),
            text: key == DocCatalog.kItemName || key == DocCatalog.kItemNote,
          ),
      ];
      final visual = rtl ? columns.reversed.toList() : columns;
      final nameAlign = rtl ? pw.TextAlign.right : pw.TextAlign.left;
      return pw.Table(
        border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
        columnWidths: <int, pw.TableColumnWidth>{
          for (var i = 0; i < visual.length; i++)
            i: pw.FlexColumnWidth(visual[i].flex),
        },
        children: [
          pw.TableRow(
            decoration: pw.BoxDecoration(color: PdfColor.fromInt(0xFF374151)),
            children:
                visual
                    .map(
                      (c) => cell(
                        c.key.isEmpty ? DocCatalog.kQty : c.key,
                        c.header,
                        head: true,
                      ),
                    )
                    .toList(growable: false),
          ),
          for (var i = 0; i < items.length; i++)
            pw.TableRow(
              children:
                  visual
                      .map(
                        (c) => cell(
                          c.key.isEmpty ? DocCatalog.kQty : c.key,
                          c.key.isEmpty
                              ? '${i + 1}'
                              : _valueOf(items[i], c.key),
                          head: false,
                          align: c.text ? nameAlign : pw.TextAlign.center,
                        ),
                      )
                      .toList(growable: false),
            ),
        ],
      );
    }

    pw.Widget? compactItem(LaundrySlipItem item) {
      final showName =
          doc.isOn(DocCatalog.kItemName) && item.name.isNotEmpty;
      final showService =
          doc.isOn(DocCatalog.kService) && item.service.isNotEmpty;
      final showQty = doc.isOn(DocCatalog.kQty);
      final showNote =
          doc.isOn(DocCatalog.kItemNote) && item.note.isNotEmpty;
      if (!showName && !showService && !showQty && !showNote) return null;

      final badge =
          showQty
              ? pw.Container(
                width: compact ? 18 : 22,
                height: compact ? 18 : 22,
                alignment: pw.Alignment.center,
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromInt(0xFFE5E7EB),
                  borderRadius: pw.BorderRadius.circular(4),
                ),
                child: text(
                  '${item.qty}',
                  key: DocCatalog.kQty,
                  size: scaled(
                    DocCatalog.kQty,
                    wide: 10,
                    compactSize: 8.5,
                  ),
                ),
              )
              : null;

      final noteLabel = doc.text(DocCatalog.kItemNote).trim();
      final content = pw.Column(
        crossAxisAlignment:
            rtl ? pw.CrossAxisAlignment.end : pw.CrossAxisAlignment.start,
        children: [
          if (showName)
            text(
              item.name,
              key: DocCatalog.kItemName,
              size: scaled(
                DocCatalog.kItemName,
                wide: 11,
                compactSize: 9.5,
              ),
            ),
          if (showService)
            text(
              item.service,
              key: DocCatalog.kService,
              size: scaled(
                DocCatalog.kService,
                wide: 8.5,
                compactSize: 7.5,
              ),
              color: PdfColors.grey700,
            ),
          if (showNote)
            pw.Container(
              margin: const pw.EdgeInsets.only(top: 1.5),
              padding: const pw.EdgeInsets.symmetric(
                horizontal: 3,
                vertical: 1,
              ),
              decoration: pw.BoxDecoration(
                color: PdfColor.fromInt(0xFFFEF3C7),
                borderRadius: pw.BorderRadius.circular(3),
              ),
              child: text(
                noteLabel.isEmpty ? item.note : '$noteLabel: ${item.note}',
                key: DocCatalog.kItemNote,
                size: scaled(
                  DocCatalog.kItemNote,
                  wide: 8,
                  compactSize: 7,
                ),
                color: PdfColor.fromInt(0xFF92400E),
              ),
            ),
        ],
      );

      return pw.Container(
        padding: pw.EdgeInsets.symmetric(vertical: compact ? 2 : 3),
        decoration: pw.BoxDecoration(
          border: pw.Border(
            bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.4),
          ),
        ),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            if (rtl) ...[
              pw.Expanded(child: content),
              if (badge != null) pw.SizedBox(width: 6),
              if (badge != null) badge,
            ] else ...[
              if (badge != null) badge,
              if (badge != null) pw.SizedBox(width: 6),
              pw.Expanded(child: content),
            ],
          ],
        ),
      );
    }

    pw.Widget totalBox(String key, String value) {
      final label = doc.text(key).trim();
      final size = scaled(key, wide: 9, compactSize: 7.5);
      final valueSize = scaled(key, wide: 11, compactSize: 9.5);
      return pw.Container(
        padding: pw.EdgeInsets.symmetric(
          horizontal: compact ? 5 : 8,
          vertical: compact ? 2.5 : 5,
        ),
        decoration: pw.BoxDecoration(
          color: PdfColor.fromInt(0xFFF3F4F6),
          borderRadius: pw.BorderRadius.circular(4),
        ),
        child: pw.Row(
          children:
              rtl
                  ? [
                    text(
                      value,
                      key: key,
                      size: valueSize,
                    ),
                    pw.Spacer(),
                    if (label.isNotEmpty)
                      text(label, key: key, size: size),
                  ]
                  : [
                    if (label.isNotEmpty)
                      text(label, key: key, size: size),
                    pw.Spacer(),
                    text(value, key: key, size: valueSize),
                  ],
        ),
      );
    }

    pw.Widget signature(String key) {
      final label = doc.text(key).trim();
      final size = scaled(key, wide: 9, compactSize: 8);
      return pw.Row(
        children:
            rtl
                ? [
                  text('____________________', key: key, size: size),
                  pw.Spacer(),
                  text('$label:', key: key, size: size),
                ]
                : [
                  text('$label:', key: key, size: size),
                  pw.Spacer(),
                  text('____________________', key: key, size: size),
                ],
      );
    }

    /// فاصل رفيع للنسخة المضغوطة — `pw.Divider` الافتراضي يحجز 16 نقطة
    /// عموديًا (≈5.6 مم) لكل فاصل، وموضعان منه يأكلان سنتيمترًا كاملًا من
    /// إيصال حراري.
    pw.Widget thinRule() => pw.Container(
      height: 0.5,
      margin: pw.EdgeInsets.symmetric(vertical: compact ? 2 : 4),
      color: PdfColors.grey400,
    );

    // ─── النصوص القابلة للتحرير من القالب ───
    final bizNameText =
        doc.isOn(DocCatalog.kBusinessName)
            ? doc.text(DocCatalog.kBusinessName, bizName).trim()
            : '';
    final titleText =
        doc.isOn(DocCatalog.kTitle) ? doc.text(DocCatalog.kTitle).trim() : '';
    final subtitleText =
        doc.isOn(DocCatalog.kSlipSubtitle)
            ? doc.text(DocCatalog.kSlipSubtitle).trim()
            : '';
    final noticeText =
        doc.isOn(DocCatalog.kSlipNotice)
            ? doc.text(DocCatalog.kSlipNotice).trim()
            : '';
    final emptyText =
        doc.isOn(DocCatalog.kEmptyItems)
            ? doc.text(DocCatalog.kEmptyItems).trim()
            : '';

    final headerThreshold = compact ? 14 : 26;

    final dateRow = kv(DocCatalog.kDatetime, date, ltrValue: true);
    final customerRow = kv(DocCatalog.kCustomerName, customerName);
    final phoneRow = kv(
      DocCatalog.kCustomerPhone,
      customerPhone,
      ltrValue: true,
    );
    final pickupRow = kv(
      DocCatalog.kPickupCode,
      pickupCode,
      ltrValue: true,
    );

    /// في النسخة المضغوطة غير الضيّقة يُدمج العميل وهاتفه في سطر واحد
    /// (كما كان) إلا إذا عُطِّل أحدهما.
    pw.Widget? compactCustomerRow() {
      final canCombine =
          !narrow &&
          doc.isOn(DocCatalog.kCustomerName) &&
          doc.isOn(DocCatalog.kCustomerPhone) &&
          customerName.isNotEmpty &&
          customerPhone.isNotEmpty;
      if (canCombine) {
        return kv(
          DocCatalog.kCustomerName,
          '$customerName - $customerPhone',
          compactSize: 8.2,
        );
      }
      if (customerName.isNotEmpty) return customerRow;
      return phoneRow;
    }

    final repeatTitle =
        doc.isOn(DocCatalog.kTitle) ? doc.text(DocCatalog.kTitle).trim() : '';
    final repeatNoLabel =
        doc.isOn(DocCatalog.kReceiptNo)
            ? doc.text(DocCatalog.kReceiptNo).trim()
            : '';
    final repeatText = <String>[
      if (repeatTitle.isNotEmpty) repeatTitle,
      if (repeatNoLabel.isNotEmpty && invoiceNumber.isNotEmpty)
        '$repeatNoLabel: $invoiceNumber',
    ].join(' - ');

    pdf.addPage(
      pw.MultiPage(
        pageFormat: pdfFormat,
        theme: pw.ThemeData.withFont(base: font, bold: font),
        header:
            items.length > headerThreshold && repeatText.isNotEmpty
                ? (pw.Context context) => pw.Container(
                  padding: const pw.EdgeInsets.only(bottom: 3),
                  margin: const pw.EdgeInsets.only(bottom: 5),
                  decoration: pw.BoxDecoration(
                    border: pw.Border(
                      bottom: pw.BorderSide(
                        color: PdfColors.grey500,
                        width: 0.5,
                      ),
                    ),
                  ),
                  child: pw.Align(
                    alignment:
                        rtl ? pw.Alignment.centerRight : pw.Alignment.centerLeft,
                    child: text(
                      repeatText,
                      key:
                          doc.isOn(DocCatalog.kTitle)
                              ? DocCatalog.kTitle
                              : DocCatalog.kReceiptNo,
                      size: compact ? 8.5 : 10,
                      color: PdfColors.grey700,
                    ),
                  ),
                )
                : null,
        build: (pw.Context context) {
          final totalBoxes = <pw.Widget>[];
          void addTotal(String key, String value) {
            if (!doc.isOn(key)) return;
            if (doc.text(key).trim().isEmpty) return;
            if (totalBoxes.isNotEmpty) {
              totalBoxes.add(pw.SizedBox(width: compact ? 6 : 10));
            }
            totalBoxes.add(pw.Expanded(child: totalBox(key, value)));
          }

          addTotal(DocCatalog.kTotalPieces, '$totalPieces');
          addTotal(DocCatalog.kItemsCount, '$itemsCount');

          final signatures = <pw.Widget>[];
          void addSignature(String key) {
            if (!doc.isOn(key)) return;
            if (doc.text(key).trim().isEmpty) return;
            if (signatures.isNotEmpty) {
              signatures.add(pw.SizedBox(height: compact ? 4 : 8));
            }
            signatures.add(signature(key));
          }

          addSignature(DocCatalog.kWorkerSignature);
          addSignature(DocCatalog.kNotesSignature);

          final itemWidgets = <pw.Widget>[];
          if (items.isEmpty) {
            if (emptyText.isNotEmpty) {
              itemWidgets.add(
                pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(vertical: 10),
                  child: pw.Center(
                    child: text(
                      emptyText,
                      key: DocCatalog.kEmptyItems,
                      size: 9,
                      color: PdfColors.grey700,
                    ),
                  ),
                ),
              );
            }
          } else if (compact) {
            for (final item in items) {
              final widget = compactItem(item);
              if (widget != null) itemWidgets.add(widget);
            }
          } else {
            final table = wideTable();
            if (table != null) itemWidgets.add(table);
          }

          final customerLine = compact ? compactCustomerRow() : null;

          return <pw.Widget>[
            if (showLogo)
              pw.Center(
                child: pw.Image(
                  pw.MemoryImage(logoBytes),
                  width: compact ? 24 : 62,
                  height: compact ? 24 : 62,
                ),
              ),
            if (bizNameText.isNotEmpty) ...[
              if (!showLogo) pw.SizedBox(height: compact ? 0 : 2),
              pw.Center(
                child: text(
                  bizNameText,
                  key: DocCatalog.kBusinessName,
                  size: scaled(
                    DocCatalog.kBusinessName,
                    wide: 17,
                    compactSize: 10.5,
                  ),
                  align: pw.TextAlign.center,
                ),
              ),
            ],
            pw.SizedBox(height: compact ? 1.5 : 4),
            if (titleText.isNotEmpty || subtitleText.isNotEmpty)
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.center,
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  if (titleText.isNotEmpty)
                    pw.Flexible(
                      child: text(
                        titleText,
                        key: DocCatalog.kTitle,
                        size: scaled(
                          DocCatalog.kTitle,
                          wide: 14,
                          compactSize: 9.5,
                        ),
                        align: pw.TextAlign.center,
                      ),
                    ),
                  if (titleText.isNotEmpty && subtitleText.isNotEmpty)
                    pw.SizedBox(width: 4),
                  if (subtitleText.isNotEmpty)
                    pw.Flexible(
                      child: text(
                        subtitleText,
                        key: DocCatalog.kSlipSubtitle,
                        size: scaled(
                          DocCatalog.kSlipSubtitle,
                          wide: 9.5,
                          compactSize: 9.5,
                        ),
                        align: pw.TextAlign.center,
                      ),
                    ),
                ],
              ),
            if (noticeText.isNotEmpty) ...[
              pw.SizedBox(height: 1),
              pw.Center(
                child: text(
                  noticeText,
                  key: DocCatalog.kSlipNotice,
                  size: scaled(
                    DocCatalog.kSlipNotice,
                    wide: 9,
                    compactSize: 6.5,
                  ),
                  color: PdfColors.grey700,
                  align: pw.TextAlign.center,
                ),
              ),
            ],
            pw.SizedBox(height: compact ? 3 : 8),
            if (doc.isOn(DocCatalog.kReceiptNo) && invoiceNumber.isNotEmpty)
              numberCard(),
            pw.SizedBox(height: compact ? 3 : 8),
            if (compact) ...[
              if (dateRow != null) dateRow,
              if (customerLine != null) customerLine,
              if (narrow) ...[
                if (customerLine == null && customerRow != null) customerRow,
                if (phoneRow != null) phoneRow,
              ],
              if (pickupRow != null) pickupRow,
            ] else ...[
              twoColumns(dateRow, customerRow),
              twoColumns(phoneRow, pickupRow),
            ],
            pw.SizedBox(height: compact ? 2 : 8),
            if (doc.isOn(DocCatalog.kDivider)) thinRule(),
            ...itemWidgets,
            pw.SizedBox(height: compact ? 2 : 6),
            if (doc.isOn(DocCatalog.kDivider)) thinRule(),
            if (totalBoxes.isNotEmpty) pw.Row(children: totalBoxes),
            pw.SizedBox(height: compact ? 5 : 16),
            ...signatures,
            if (doc.isOn(DocCatalog.kBusinessPhone) && bizPhone.isNotEmpty) ...[
              pw.SizedBox(height: compact ? 4 : 8),
              pw.Center(
                child: text(
                  bizPhone,
                  key: DocCatalog.kBusinessPhone,
                  size: scaled(
                    DocCatalog.kBusinessPhone,
                    wide: 9,
                    compactSize: 7.5,
                  ),
                  color: PdfColors.grey600,
                  align: pw.TextAlign.center,
                ),
              ),
            ],
          ];
        },
      ),
    );

    return pdf.save();
  }

  static List<LaundrySlipItem> _itemsOf(Map<String, dynamic> data) {
    final raw = data['items'];
    if (raw is! List) return const <LaundrySlipItem>[];
    return raw
        .whereType<Map>()
        .map(
          (item) => LaundrySlipItem(
            name: '${item['name'] ?? ''}'.trim(),
            service: '${item['service'] ?? ''}'.trim(),
            qty: int.tryParse('${item['qty'] ?? ''}') ?? 0,
            note: '${item['note'] ?? ''}'.trim(),
          ),
        )
        .where((item) => item.name.isNotEmpty)
        .toList(growable: false);
  }

  static bool _rtlOf(Map<String, dynamic> data) {
    final code = '${data['docLang'] ?? ''}'.trim().toLowerCase();
    return code.isEmpty || code != 'en';
  }

  /// معامل التعريض الصناعي — مطابق لـ`DocStyle.boldOffset` لكن على الحجم
  /// النهائي بعد التكيّف مع الورق.
  static double _weightFactor(int weight) => switch (weight) {
    600 => 0.0125,
    700 => 0.0225,
    900 => 0.035,
    _ => 0.0,
  };

  /// عرض عمود الجدول الواسع بحسب الحقل.
  static double _flexOf(String key) => switch (key) {
    DocCatalog.kItemName => 2.3,
    DocCatalog.kService => 1.7,
    DocCatalog.kQty => 0.65,
    DocCatalog.kItemNote => 2.0,
    _ => 1.0,
  };

  static String _valueOf(LaundrySlipItem item, String key) => switch (key) {
    DocCatalog.kItemName => item.name,
    DocCatalog.kService => item.service,
    DocCatalog.kQty => '${item.qty}',
    DocCatalog.kItemNote => item.note,
    _ => '',
  };
}

/// عمود في جدول A4/A5.
class _WideColumn {
  const _WideColumn({
    required this.key,
    required this.header,
    required this.flex,
    this.text = false,
  });

  /// مفتاح الحقل في القالب (فارغ لعمود الترقيم).
  final String key;

  /// عنوان العمود كما يظهر في الورق.
  final String header;

  final double flex;

  /// هل يُحاذى بداية السطر (نصّ) لا الوسط (رقم)؟
  final bool text;
}
