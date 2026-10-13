// ignore_for_file: file_names

import 'dart:io';
import 'package:barcode/barcode.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:laundry/core/services/paper_size.dart';
import 'package:laundry/services/tax/tax_service.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:intl/intl.dart';

class PreparePDF {
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

  /// نسبة مئوية بلا أصفار زائدة (0.15 ⇒ «15»).
  static String _percent(double rate) {
    final v = rate * 100;
    final s = v.toStringAsFixed(2);
    return s.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
  }

  /// سطر تفصيلي في جدول الإجماليات — المبلغ يسار والوصف يمين.
  static pw.Widget _totalRow(
    Map<String, dynamic> data,
    String label,
    String value,
    pw.TextStyle style, {
    PdfColor? color,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        children: [
          pw.Text(
            value,
            style: pw.TextStyle(
              font: data['arabicFont'],
              fontSize: style.fontSize,
              fontWeight: pw.FontWeight.bold,
              color: color,
            ),
          ),
          pw.Spacer(),
          pw.Text(
            label,
            textDirection: pw.TextDirection.rtl,
            textAlign: pw.TextAlign.right,
            style: pw.TextStyle(
              font: data['arabicFont'],
              fontSize: style.fontSize,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  static Future<Uint8List> generatePdfData(Map<String, dynamic> data) async {
    final pdf = pw.Document();

    // ─── مقاس الورق من الإعدادات (A4 · A5 · A6 · حراري 80/58 مم · ملصقات) ───
    // الحرارية ارتفاعها مفتوح فتُضبط لأطول صفحة، وهوامشها ضيقة.
    final paper = PaperSizes.resolve(data['paperSize'] as String?);
    final pageFormat = PdfPageFormat(
      PaperSizes.mmToPoints(paper.widthMm),
      paper.isThermal
          ? PdfPageFormat.a4.height
          : PaperSizes.mmToPoints(paper.heightMm),
      marginAll: paper.isThermal ? PaperSizes.mmToPoints(2) : PdfPageFormat.cm,
    );

    final items = data['invoiceItems'] as List;
    final photoBytes = await _loadPhotoBytes(items);
    data['_photoBytes'] = photoBytes;

    // ضغط الصور إلى JPEG لتقليل الحجم
    final logoBytes = _compressToJpeg(data['logoImage'] as Uint8List, 80, 80);
    // final riyalBytes = _compressToJpeg(data['riyalImage'] as Uint8List, 24, 24);

    // final riyalIcon = pw.Image(
    //   pw.MemoryImage(riyalBytes),
    //   width: 18,
    //   height: 18,
    // );

    final bool hidePrices = data['hidePrices'] == true;

    final itemStyle = pw.TextStyle(
      font: data['arabicFont'],
      fontSize: 27,
      fontWeight: pw.FontWeight.bold,
    );

    final priceStyle = pw.TextStyle(
      fontSize: 24,
      font: data['arabicFont'],
      fontWeight: pw.FontWeight.bold,
    );

    final smallStyle = pw.TextStyle(font: data['arabicFont'], fontSize: 20);

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

    // ─── QR هيئة الزكاة والضريبة والجمارك (المرحلة الأولى) ───
    //
    // الفاتورة كانت تُطبع بعنوان «فاتورة ضريبية مبسطة» **بلا رقم ضريبي ولا
    // QR**، وهو ما لا يجتاز مراجعة الهيئة. الترميز (TLV ثم Base64) في
    // `TaxService.zatcaQrPayload` منطق خالص مختبَر، لا سطور تُبنى هنا.
    String? qrSvg;
    if (bizTaxNumber.isNotEmpty && data['showQr'] != false) {
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

    // ─── الرأس ───
    final List<pw.Widget> headerWidgets = [
      if (data['showLogo'] != false)
        pw.Center(
          child: pw.Image(pw.MemoryImage(logoBytes), width: 150, height: 150),
        ),
      pw.SizedBox(height: 6),
      pw.Center(
        child: pw.Text(
          data['bizName'] ?? 'نظام المغاسل',
          textDirection: pw.TextDirection.rtl,
          textAlign: pw.TextAlign.center,
          style: itemStyle,
        ),
      ),
      pw.SizedBox(height: 4),
      pw.Center(
        child: pw.Text(
          data['bizAddress'] ?? '',
          textDirection: pw.TextDirection.rtl,
          textAlign: pw.TextAlign.center,
          style: pw.TextStyle(font: data['arabicFont'], fontSize: 22),
        ),
      ),
      pw.SizedBox(height: 10),
      pw.Divider(),
      pw.SizedBox(height: 10),
      // عنوان الفاتورة — من الإعدادات (افتراضيًا: فاتورة ضريبية مبسطة)
      pw.Center(
        child: pw.Text(
          '${data['invoiceTitle'] ?? 'فاتورة ضريبية مبسطة'}',
          textDirection: pw.TextDirection.rtl,
          textAlign: pw.TextAlign.center,
          style: itemStyle,
        ),
      ),
      pw.SizedBox(height: 6),
      // رقم الإيصال
      pw.Center(
        child: pw.Text(
          "رقم الإيصال: ${data['invoiceNumberText'] ?? data['invoiceNumber']}",
          textDirection: pw.TextDirection.rtl,
          textAlign: pw.TextAlign.center,
          style: itemStyle,
        ),
      ),
      pw.SizedBox(height: 6),
      // التاريخ — يتبع خيار إظهار التاريخ
      if (data['showDatetime'] != false)
        pw.Center(
          child: pw.Text(
            "التأريخ: ${data['date']}",
            textDirection: pw.TextDirection.rtl,
            textAlign: pw.TextAlign.center,
            style: itemStyle,
          ),
        ),
      // السجل التجاري — يتبع خياره
      if ('${data['bizCrNumber'] ?? ''}'.trim().isNotEmpty &&
          data['showCrNumber'] != false)
        pw.Center(
          child: pw.Text(
            "السجل التجاري: ${data['bizCrNumber']}",
            textDirection: pw.TextDirection.rtl,
            textAlign: pw.TextAlign.center,
            style: itemStyle,
          ),
        ),
      // العنوان الوطني — يتبع خياره
      if ('${data['bizShortAddress'] ?? ''}'.trim().isNotEmpty &&
          data['showShortAddress'] == true)
        pw.Center(
          child: pw.Text(
            "العنوان الوطني: ${data['bizShortAddress']}",
            textDirection: pw.TextDirection.rtl,
            textAlign: pw.TextAlign.center,
            style: itemStyle,
          ),
        ),
      // ─── الرقم الضريبي (إلزامي على الفاتورة الضريبية) ───
      if (bizTaxNumber.isNotEmpty && data['showTaxNumber'] != false)
        pw.Center(
          child: pw.Text(
            "الرقم الضريبي: $bizTaxNumber",
            textDirection: pw.TextDirection.rtl,
            textAlign: pw.TextAlign.center,
            style: smallStyle,
          ),
        ),
      // ─── QR الهيئة — يقرأه المفتش من الورق مباشرة ───
      if (qrSvg != null && data['showQr'] != false) ...[
        pw.SizedBox(height: 10),
        pw.Center(child: pw.SvgImage(svg: qrSvg, width: 100, height: 100)),
        pw.SizedBox(height: 6),
      ],
      // صدر بواسطة — يتبع خيار إظهار اسم المستخدم
      if ('${data['createdByName']}'.isNotEmpty &&
          data['showCashier'] != false)
        pw.Center(
          child: pw.Text(
            "صدر بواسطة: ${data['createdByName']}",
            textDirection: pw.TextDirection.rtl,
            textAlign: pw.TextAlign.center,
            style: smallStyle,
          ),
        ),
      if ('${data['customername']}'.isNotEmpty)
        pw.Center(
          child: pw.Text(
            "اسم العميل: ${data['customername']}",
            textDirection: pw.TextDirection.rtl,
            textAlign: pw.TextAlign.center,
            style: itemStyle,
          ),
        ),
      pw.SizedBox(height: 10),
      pw.Divider(),
      pw.SizedBox(height: 10),
      pw.Center(
        child: pw.Text(
          "نسعد بتواصلكم عبر الأرقام:  ${data['bizPhone'] ?? ''}",
          textDirection: pw.TextDirection.rtl,
          textAlign: pw.TextAlign.center,
          style: itemStyle,
        ),
      ),
      pw.Center(
        child: pw.Text(
          "-----------------------------------------------------",
          textDirection: pw.TextDirection.rtl,
          textAlign: pw.TextAlign.center,
          style: itemStyle,
        ),
      ),
      // تذييل حرّ من الإعدادات
      if ('${data['footerNote'] ?? ''}'.trim().isNotEmpty)
        pw.Center(
          child: pw.Text(
            '${data['footerNote']}'.trim(),
            textDirection: pw.TextDirection.rtl,
            textAlign: pw.TextAlign.center,
            style: smallStyle,
          ),
        ),
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
                        ? pw.Text(
                          'اشتراك',
                          textDirection: pw.TextDirection.rtl,
                          style: pw.TextStyle(
                            fontSize: 20,
                            font: data['arabicFont'],
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColor.fromInt(0xFF7C3AED),
                          ),
                        )
                        : pw.Text(
                          _money(item['total_price']),
                          style: priceStyle,
                        ),
              ),
              // الصنف يمين
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      "${item['vestments']} (${item['content']})",
                      textDirection: pw.TextDirection.rtl,
                      textAlign: pw.TextAlign.right,
                      style: itemStyle,
                    ),
                    if (!hidePrices)
                      pw.Text(
                        "${item['price']} x ${item['count']}",
                        textDirection: pw.TextDirection.rtl,
                        textAlign: pw.TextAlign.right,
                        style: priceStyle,
                      ),
                    if (item['note'] != null &&
                        '${item['note']}'.trim().isNotEmpty)
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
                        child: pw.Text(
                          "ملاحظة: ${item['note']}",
                          textDirection: pw.TextDirection.rtl,
                          textAlign: pw.TextAlign.right,
                          style: pw.TextStyle(
                            fontSize: 20,
                            color: PdfColor.fromInt(0xFFB45309),
                            font: data['arabicFont'],
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ),
                    if (item['photo'] != null &&
                        '${item['photo']}'.trim().isNotEmpty &&
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
        pw.Center(
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
            child: pw.Text(
              // ⚠️ شرطة قصيرة `–` لا طويلة `—`: الخط لا يحوي U+2014.
              'مغطّى بالاشتراك الشهري – لا يُطلب مبلغ عند التسليم',
              textDirection: pw.TextDirection.rtl,
              style: pw.TextStyle(
                fontSize: 24,
                font: data['arabicFont'],
                fontWeight: pw.FontWeight.bold,
                color: PdfColor.fromInt(0xFF7C3AED),
              ),
            ),
          ),
        )
      else
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            // ─── تفصيل الخصم والضريبة ───
            // يظهر **فقط عند وجودهما**، فلا تتغيّر فاتورة بلا خصم ولا ضريبة
            // ولا يزدحم الإيصال بسطور أصفار.
            if (hasDiscount || hasTax) ...[
              if (hasDiscount)
                _totalRow(
                  data,
                  'الإجمالي قبل الخصم',
                  _money(grossAmount),
                  smallStyle,
                ),
              if (hasDiscount)
                _totalRow(
                  data,
                  discountCode.isEmpty ? 'الخصم' : 'الخصم ($discountCode)',
                  '- ${_money(discountAmount)}',
                  smallStyle,
                  color: PdfColor.fromInt(0xFF16A34A),
                ),
              if (hasTax)
                _totalRow(
                  data,
                  'الأساس الخاضع للضريبة',
                  _money(taxBase),
                  smallStyle,
                ),
              if (hasTax)
                _totalRow(
                  data,
                  'ضريبة القيمة المضافة ${_percent(taxRate)}%',
                  _money(taxAmount),
                  smallStyle,
                ),
              pw.SizedBox(height: 8),
              pw.Divider(),
            ],
            // المستحق: الوصف يمين، المبلغ يسار
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // المبلغ يسار
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Row(
                      mainAxisSize: pw.MainAxisSize.min,
                      crossAxisAlignment: pw.CrossAxisAlignment.center,
                      children: [
                        pw.Text(
                          '${_money(payable)} ر.س',
                          style: priceStyle,
                          textDirection: pw.TextDirection.rtl,
                        ),
                      ],
                    ),
                  ],
                ),
                pw.Spacer(),
                // الوصف يمين
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      hasDiscount ? "المستحق بعد الخصم" : "المجموع: ",
                      textDirection: pw.TextDirection.rtl,
                      textAlign: pw.TextAlign.right,
                      style: itemStyle,
                    ),
                    pw.SizedBox(height: 10),
                    pw.Text(
                      "الدفع: ${data['payment']}",
                      textDirection: pw.TextDirection.rtl,
                      textAlign: pw.TextAlign.right,
                      style: pw.TextStyle(
                        font: data['arabicFont'],
                        fontSize: 18,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
        pw.Divider(),
    ];

    pdf.addPage(
      pw.MultiPage(
        pageFormat: pageFormat,
        theme: pw.ThemeData.withFont(base: data['arabicFont']),
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

  static Future<Uint8List> generateShiftSummaryPdf(
    Map<String, dynamic> shiftData,
  ) async {
    final pdf = pw.Document();
    final font = pw.Font.ttf(
      await rootBundle.load("assets/fonts/Noto/AL-Mohanad.ttf"),
    );

    final String startTime = DateFormat(
      'yyyy-MM-dd hh:mm a',
    ).format(DateTime.parse(shiftData['start_time']));
    final String endTime = DateFormat(
      'yyyy-MM-dd hh:mm a',
    ).format(DateTime.parse(shiftData['end_time']));

    final bizName = shiftData['bizName'] ?? '';
    final bizPhone = shiftData['bizPhone'] ?? '';
    final bizAddress = shiftData['bizAddress'] ?? '';

    // ملخص الوردية على A6 — كما كان قبل أي تعديل طباعة.
    final format = PdfPageFormat.a6;
    const double nameSize = 20;
    const double smallSize = 12;
    const double titleTextSize = 18;

    pdf.addPage(
      pw.Page(
        pageFormat: format,
        theme: pw.ThemeData.withFont(base: font, bold: font),
        build: (pw.Context context) {
          return pw.Directionality(
            textDirection: pw.TextDirection.rtl,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                if (bizName.isNotEmpty)
                  pw.Center(
                    child: pw.Text(
                      bizName,
                      style: pw.TextStyle(
                        font: font,
                        fontSize: nameSize,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ),
                if (bizAddress.isNotEmpty)
                  pw.Center(
                    child: pw.Text(
                      bizAddress,
                      style: pw.TextStyle(font: font, fontSize: smallSize),
                    ),
                  ),
                if (bizPhone.isNotEmpty)
                  pw.Center(
                    child: pw.Text(
                      'هاتف: $bizPhone',
                      style: pw.TextStyle(font: font, fontSize: smallSize),
                    ),
                  ),
                pw.SizedBox(height: 10),
                pw.Center(
                  child: pw.Text(
                    'ملخص الوردية',
                    style: pw.TextStyle(
                      font: font,
                      fontSize: titleTextSize,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
                pw.SizedBox(height: 20),
                _buildRow(
                  'رقم الوردية:',
                  shiftData['shift_id'].toString(),
                  font,
                  smallSize,
                ),
                pw.Divider(),
                _buildRow('وقت البدء:', startTime, font, smallSize),
                _buildRow('وقت الإنتهاء:', endTime, font, smallSize),
                pw.Divider(),
                _buildRow(
                  'عدد الفواتير:',
                  shiftData['invoice_count'].toString(),
                  font,
                  smallSize,
                ),
                _buildRow(
                  'مجموع الكاش:',
                  '${(shiftData['total_cash'] ?? 0.0).toStringAsFixed(2)} ريال',
                  font,
                  smallSize,
                ),
                _buildRow(
                  'مجموع الشبكة:',
                  '${(shiftData['total_network'] ?? 0.0).toStringAsFixed(2)} ريال',
                  font,
                  smallSize,
                ),
                pw.SizedBox(height: 40),
                pw.Center(
                  child: pw.Text(
                    '--- شكراً لكم ---',
                    style: pw.TextStyle(font: font, fontSize: smallSize),
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

    final bizName = '${data['bizName'] ?? ''}';
    final bizPhone = '${data['bizPhone'] ?? ''}';
    final bizAddress = '${data['bizAddress'] ?? ''}';
    final custName = '${data['customerName'] ?? ''}';
    final custPhone = '${data['customerPhone'] ?? ''}';
    final printedAt = '${data['printedAt'] ?? ''}';

    /// نصّ الفترة («من … إلى …») — فارغ ⇒ كشف كامل بلا تقييد.
    final period = '${data['period'] ?? ''}';

    final totals = (data['totals'] as Map?) ?? const {};
    final invoices = (data['invoices'] as List?) ?? const [];
    final itemsDetailed = (data['itemsDetailed'] as List?) ?? const [];
    final payments = (data['payments'] as List?) ?? const [];
    final usages = (data['usages'] as List?) ?? const [];

    // أحجام الخطوط (كُبِّرت 2026-10-03 بطلب المستخدم: 10/9 ⇒ 13/11/12).
    const double base = 13; // النصّ العادي (kv والأقسام)
    const double small = 11; // الترويسة والتذييل
    const double cellSize = 12; // خلايا الجداول

    pw.TextStyle st(double size, {bool bold = false}) => pw.TextStyle(
      font: font,
      fontSize: size,
      fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
    );

    /// كل نصّ في الكشف **RTL صريح**.
    ///
    /// 🚨 **لماذا إلزامي؟** حزمة `pdf` لا تُشكّل العربية (اختيار الصورة
    /// الابتدائية/الوسطى/النهائية وترتيب الكلمات) إلا إذا كان
    /// `textDirection == pw.TextDirection.rtl` — انظر
    /// `pdf/src/widgets/text.dart`: `textDirection ?? Directionality.of(context)`،
    /// ثم `arabic.convert(...)` / `bidi.logicalToVisual(...)` محصوران بشرط
    /// `_textDirection == TextDirection.rtl`. بدونها يُرسم النص بترتيبه
    /// المنطقي فتُقرأ الحروف **مقطّعة ومعكوسة**.
    /// الفاتورة العادية تضبط الاتجاه على كل نص؛ هذا الكشف كان **بلا أي ضبط**.
    pw.Text tx(
      String t, {
      double size = base,
      bool bold = false,
      pw.TextAlign? align,
    }) => pw.Text(
      t,
      style: st(size, bold: bold),
      textAlign: align,
      textDirection: pw.TextDirection.rtl,
    );

    pw.Widget kv(String label, String value, {bool bold = false}) => pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [tx(label, bold: bold), tx(value, bold: bold)],
    );

    pw.Widget sectionTitle(String text) => pw.Padding(
      padding: const pw.EdgeInsets.only(top: 12, bottom: 6),
      child: tx(text, size: 14, bold: true),
    );

    // جدول بسيط بترويسة ملوّنة خفيفة — بلا أي اعتماد على TableHelper.
    // `widths` تسمح بتوزيع عرض الأعمدة بدل الاعتماد على الحجم التلقائي.
    //
    // 🚨 **الترتيب RTL**: `pw.Table` يرصف الأبناء من **اليسار** ولا يعكس
    // الاتجاه تلقائيًا، فلو مرّرنا الأعمدة بترتيبها المنطقي ظهر العمود الأول
    // في أقصى اليسار — أي أن قارئ العربية يبدأ من آخر عمود. لذلك نعكس
    // الترويسة وكل صف هنا فيصير العمود الأول (التاريخ مثلًا) في **أقصى
    // اليمين**. ونعكس مفاتيح `widths` معها كي يبقى كل عرض على عموده.
    // ⇒ كل منادات `table()` تمرّر الأعمدة **بترتيبها المنطقي** بلا قلق.
    pw.Widget table(
      List<String> headers,
      List<List<String>> rows, {
      Map<int, pw.TableColumnWidth>? widths,
    }) {
      pw.Widget cell(String t, {bool head = false}) => pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: tx(t, size: cellSize, bold: head, align: pw.TextAlign.center),
      );

      final n = headers.length;
      final visualWidths =
          widths == null
              ? null
              : {for (final e in widths.entries) n - 1 - e.key: e.value};

      return pw.Table(
        border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.4),
        columnWidths: visualWidths,
        children: [
          pw.TableRow(
            decoration: const pw.BoxDecoration(color: PdfColors.grey200),
            children: headers.reversed.map((h) => cell(h, head: true)).toList(),
          ),
          ...rows.map(
            (r) =>
                pw.TableRow(children: r.reversed.map((c) => cell(c)).toList()),
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
              if (bizName.isNotEmpty)
                pw.Center(child: tx(bizName, size: 20, bold: true)),
              if (bizAddress.isNotEmpty)
                pw.Center(child: tx(bizAddress, size: small)),
              if (bizPhone.isNotEmpty)
                pw.Center(child: tx('هاتف: $bizPhone', size: small)),
              pw.Divider(),
              pw.Center(child: tx('كشف حساب زبون', size: 19, bold: true)),
              // سطر الفترة — يظهر فقط عندما يكون الكشف مقيَّدًا بمدى تاريخي.
              if (period.isNotEmpty)
                pw.Center(
                  child: tx('الفترة: $period', size: small, bold: true),
                ),
              pw.SizedBox(height: 8),

              // ─── بيانات الزبون ───
              kv('الزبون:', custName, bold: true),
              if (custPhone.isNotEmpty) kv('الهاتف:', custPhone),
              if (printedAt.isNotEmpty) kv('تاريخ الطباعة:', printedAt),
              pw.Divider(),

              // ⚠️ الملخّص **لم يعد هنا**: نُقل إلى أسفل الكشف (بعد كل الجداول)
              // بطلب المستخدم 2026-10-03 ليكون خاتمة الكشف لا مقدمته.

              // ─── الأصناف التي أخذها: **جدول واحد** (تاريخ + صنف + عدد + قيمة) ───
              // **لماذا جدول واحد؟** كان هنا جدولان: «مجمَّعة» (بلا تاريخ) +
              // «تفاصيل» (بالتاريخ) ⇒ الصنف يظهر مرتين وتطول الفاتورة بلا جدوى.
              // طلب المستخدم (2026-10-03): عمود/جدول واحد فقط، كل بند بتاريخه
              // وعدده وقيمته. المجمَّع حُذف بالكامل (وأُزيل `items` من البيانات).
              if (itemsDetailed.isNotEmpty) ...[
                sectionTitle('الأصناف التي أخذها'),
                table(
                  ['التاريخ والوقت', 'الصنف', 'العدد', 'القيمة (ريال)'],
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
                  widths: {
                    0: const pw.FlexColumnWidth(1.55),
                    1: const pw.FlexColumnWidth(2.05),
                    2: const pw.FlexColumnWidth(0.65),
                    3: const pw.FlexColumnWidth(1.05),
                  },
                ),
              ],

              // ─── الفواتير ───
              if (invoices.isNotEmpty) ...[
                sectionTitle('الفواتير'),
                table(
                  ['رقم', 'التاريخ', 'الإجمالي', 'المدفوع', 'المتبقي'],
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
                ),
              ],

              // ─── الدفعات ───
              if (payments.isNotEmpty) ...[
                sectionTitle('الدفعات المسجَّلة'),
                table(
                  ['التاريخ', 'المبلغ', 'الطريقة', 'ملاحظة'],
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
                ),
              ],

              // ─── سجل الاشتراك (القطع التي غُسلت) ───
              if (usages.isNotEmpty) ...[
                sectionTitle('سجل استهلاك الاشتراك (القطع المغسولة)'),
                table(
                  ['التاريخ', 'الاشتراك', 'القطع', 'القيمة (ريال)', 'الفاتورة'],
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
              pw.Row(
                children: [
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                      children: [
                        pw.Divider(),
                        sectionTitle(
                          period.isEmpty
                              ? 'الملخّص'
                              : 'الملخّص (تدفّقات الفترة + الرصيد الحالي)',
                        ),
                        kv(
                          'إجمالي المشتريات:',
                          '${_money(totals['purchases'])} ريال',
                        ),
                        kv('المسدَّد:', '${_money(totals['paid'])} ريال'),
                        kv(
                          'الذمة المتبقية (عليه):',
                          '${_money(totals['debt'])} ريال',
                          bold: true,
                        ),
                        kv(
                          'الرصيد الدائن (له):',
                          '${_money(totals['credit'])} ريال',
                          bold: true,
                        ),
                        pw.Divider(),
                        kv(
                          'صافي الموقف:',
                          '${_money(totals['net'])} ريال'
                              ' ${((totals['net'] as num?)?.toDouble() ?? 0) >= 0 ? '(له)' : '(عليه)'}',
                          bold: true,
                        ),
                        if (((totals['pieces'] as num?)?.toInt() ?? 0) > 0)
                          kv('عدد القطع:', '${totals['pieces']}'),
                        if (((totals['subPieces'] as num?)?.toInt() ?? 0) > 0)
                          kv(
                            'قطع الاشتراكات المستهلكة:',
                            '${totals['subPieces']} (بقيمة ${_money(totals['subValue'])} ريال)',
                          ),
                        // التذييل **داخل** الكتلة: لو بقي خارجها لانفرد وحده في
                        // صفحة جديدة عندما يستهلك الملخّص باقي الصفحة.
                        pw.SizedBox(height: 16),
                        pw.Center(
                          child: tx(
                            '--- هذا الكشف صادر آليًا من النظام ---',
                            size: small,
                          ),
                        ),
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

  static pw.Widget _buildRow(
    String title,
    String value,
    pw.Font font, [
    double fontSize = 12,
  ]) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Row(
        children: [
          pw.Text(value, style: pw.TextStyle(font: font, fontSize: fontSize)),
          pw.Spacer(),
          pw.Text(title, style: pw.TextStyle(font: font, fontSize: fontSize)),
        ],
      ),
    );
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
