import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:laundry/core/services/preparePDF.dart';
import 'package:laundry/services/invoice/invoice_output_service.dart';
import 'package:laundry/services/invoice/invoice_pdf_naming.dart';
import 'package:laundry/services/pdf/doc_template.dart';
import 'package:laundry/services/pdf/doc_template_service.dart';
import 'package:laundry/core/theme/app_colors.dart';
import 'package:laundry/services/business_info_service.dart';
import 'package:laundry/services/customer/customer_statement_service.dart';
import 'package:laundry/services/i18n/l10n.dart';
import 'package:laundry/core/services/paper_size.dart';
import 'package:laundry/services/settings/app_settings_service.dart';
import 'package:laundry/services/printer/printer_service.dart';
import 'package:printing/printing.dart';

/// تصدير كشف حساب الزبون: طباعة PDF أو مشاركته على واتساب.
///
/// **لماذا متحكّم منفصل؟** الكشف يُطلب من أكثر من شاشة (حساب الزبون، أعمار
/// الديون). لو كُتب في كل شاشة لتكرّر بناء البيانات وتفاوت التنسيق — وهو
/// نفس الخطأ الذي جعل منطق FIFO يتفرّع سابقًا.
class CustomerStatementController extends GetxController {
  final RxBool isBusy = false.obs;

  /// الفترة المختارة للكشف (null = الكشف كامل بلا تقييد).
  final Rxn<DateTimeRange> selectedRange = Rxn<DateTimeRange>();

  /// نصّ الفترة المختارة — للعرض في الواجهة.
  String get rangeLabel {
    final r = selectedRange.value;
    if (r == null) return tr('كل الفترة (بلا تقييد)');
    return trf('من {0} إلى {1}', [_day(r.start), _day(r.end)]);
  }

  /// ضبط الفترة (null = إلغاء التقييد).
  void setRange(DateTimeRange? range) => selectedRange.value = range;

  /// يبني الكشف ويرسله للطباعة أو المشاركة أو يحفظه PDF.
  ///
  /// [share] = true → قائمة مشاركة النظام (واتساب)، وإلا → حوار الطباعة.
  /// [savePdfOnly] = true → **حفظ فقط**: لا حوار طباعة ولا مشاركة. طُلب
  /// صريحًا كي يكون للكشف مسار حفظ مستقلّ عن الطباعة، فلا يُضطر المستخدم
  /// إلى إرسال ورقة إلى الطابعة ليحصل على ملف.
  /// [printAndSave] = true → **طباعة + حفظ PDF**: يطبع الكشف **و**يحفظ
  /// نسخة PDF في مجلد المستندات في إجراء واحد — كنمط الفاتورة تمامًا.
  /// ويُحترم فيه إعداد `statement_pdf_export`: إن كان مفعَّلًا يُحفظ
  /// تلقائيًّا حتى لو لم يختر المستخدم هذا الخيار صراحةً.
  /// [range] يتجاوز الفترة المخزَّنة إن مُرِّر.
  Future<void> export(
    int customerId, {
    bool share = false,
    bool savePdfOnly = false,
    bool printAndSave = false,
    DateTimeRange? range,
  }) async {
    if (isBusy.value) return;
    isBusy.value = true;
    try {
      final r = range ?? selectedRange.value;
      final st = await CustomerStatementService.instance.build(
        customerId,
        from: r?.start,
        to: r?.end,
      );
      if (st == null) {
        _info(tr('تعذّر تجهيز كشف الحساب'), AppColors.danger);
        return;
      }
      final data = buildPdfData(st);
      final bytes = await PreparePDF.generateCustomerStatementPdf(data);
      if (bytes.isEmpty) {
        _info(tr('تعذّر توليد ملف الكشف'), AppColors.danger);
        return;
      }
      final filename = 'كشف_حساب_${st.customerId}.pdf';

      // ─── حفظ فقط ───
      if (savePdfOnly) {
        await _saveToDisk(bytes, st.customerId);
        return;
      }

      // ─── مشاركة (واتساب PDF) ───
      if (share) {
        // إن كان إعداد الحفظ مفعَّلًا، نحفظ نسخة أيضًا قبل المشاركة.
        if (AppSettingsService.instance.statementPdfExport) {
          await _saveToDisk(bytes, st.customerId);
        }
        await Printing.sharePdf(
          bytes: bytes,
          filename: filename,
          subject: trf('كشف حساب — {0}', [st.customerName]),
          body: summaryText(st),
        );
        return;
      }

      // ─── طباعة (وحفظ PDF إن طُلب أو إن كان الإعداد مفعَّلًا) ───
      //
      // 🚨 **مقاس الورق من الإعداد لا من hardcoded**: كان `PaperSizes.a4`
      // ثابتًا فلا يُراعى اختيار المستخدم مقاسًا آخر من الإعدادات. صار يُقرأ
      // من `statement_paper_size` فيستجيب للحراري 80/58 مم و A5/A6.
      final settings = AppSettingsService.instance;
      final paper = PaperSizes.resolve(settings.statementPaperSize);
      final done = await PrinterService.instance.printPdf(
        bytes,
        jobName: filename,
        paper: paper,
      );
      if (!done) {
        // سبب الفشل (تعريف نصّي · طابعة متوقفة · مهلة) يُعرض قبل الحفظ،
        // وإلا ظنّ المستخدم أن الكشف طُبع وهو لم يُطبع.
        final issue = PrinterService.instance.lastIssue;
        if (issue != null) _info(issue, AppColors.warning);
      }

      // الحفظ التلقائي: إن كان `printAndSave` صريحًا أو الإعداد مفعَّلًا.
      //
      // 🚨 كان الحفظ يحدث **كأثر جانبي لفشل الطباعة فقط** — وكأنه تعويض
      // عن الفشل لا قرارًا. صار قرارًا صريحًا: إن أراد المستخدم الحفظ مع
      // الطباعة (الخيار الصريح أو الإعداد) يُحفظ سواء نجحت الطباعة أم لا.
      if (printAndSave || settings.statementPdfExport) {
        await _saveToDisk(bytes, st.customerId);
      } else if (!done) {
        // الطباعة فشلت ولم يُطلب الحفظ ولا الإعداد مفعَّل: نحفظ كأمان
        // حتى لا يضيع الكشف كليًّا.
        await _saveToDisk(bytes, st.customerId);
      }
    } catch (e) {
      debugPrint('CustomerStatementController.export error: $e');
      _info(trf('فشل تصدير الكشف: {0}', [e]), AppColors.danger);
    } finally {
      isBusy.value = false;
    }
  }

  /// ملخّص نصّي جاهز للإرسال على واتساب.
  String summaryText(CustomerStatement st) {
    final b = StringBuffer();
    final biz = BusinessInfoService.instance.name;
    if (biz.isNotEmpty) b.writeln(biz);
    b.writeln(trf('كشف حساب: {0}', [st.customerName]));
    if (st.hasRange) b.writeln(trf('الفترة: {0}', [periodLabel(st)]));
    b.writeln('────────────────');
    b.writeln(trf('إجمالي المشتريات: {0} ريال', [_m(st.totalPurchases)]));
    b.writeln(trf('المسدد: {0} ريال', [_m(st.totalPaidOnInvoices)]));
    if (st.hasDebt) {
      b.writeln(trf('الذمة المتبقية (عليه): {0} ريال', [_m(st.totalDebt)]));
      if (st.oldestDebtDate != null) {
        b.writeln(trf('أقدم ذمة: {0}', [_d(st.oldestDebtDate!)]));
      }
    }
    if (st.hasCredit) {
      b.writeln(trf('الرصيد الدائن (له): {0} ريال', [_m(st.creditBalance)]));
    }
    b.writeln(
      trf('صافي الموقف: {0} ريال {1}', [
        _m(st.netPosition.abs()),
        tr(st.netPosition >= 0 ? '(له)' : '(عليه)'),
      ]),
    );
    if (st.totalSubscriptionPieces > 0) {
      b.writeln(
        trf('قطع الاشتراك المستهلكة: {0}', [st.totalSubscriptionPieces]),
      );
    }
    b.writeln('────────────────');
    b.write(tr('مغاسل النظارة — شكرًا لتعاملكم معنا'));
    return b.toString();
  }

  /// نصّ الفترة للعرض («من 2026-10-01 إلى 2026-10-03» أو طرف واحد).
  String periodLabel(CustomerStatement st) {
    final f = st.rangeFrom;
    final t = st.rangeTo;
    if (f == null && t == null) return '';
    if (f != null && t != null) {
      return trf('من {0} إلى {1}', [_day(f), _day(t)]);
    }
    if (f != null) return trf('من {0} حتى الآن', [_day(f)]);
    return trf('حتى {0}', [_day(t!)]);
  }

  /// خريطة البيانات التي يستهلكها مولّد الـPDF.
  Map<String, dynamic> buildPdfData(CustomerStatement st) {
    final biz = BusinessInfoService.instance;
    final settings = AppSettingsService.instance;
    return {
      'bizName': biz.name,
      'bizPhone': biz.phone,
      'bizAddress': biz.address,
      // رابط الموقع — يُرمَّز QR أسفل الكشف.
      'bizMapUrl': biz.location,
      // ─── مقاس الورق + مقاسات الشعار/QR — يقرأها المولّد لبناء الصفحة ───
      // 🚨 كانت **مفقودة** فكان المولّد يبني الكشف دائمًا على A4 بصرف النظر
      // عن إعداد المستخدم، وإعداد «مقاس كشف الحساب» في الإعدادات كان معطَّلًا
      // فعليًّا: يُعرض ويُحفظ ولا يُقرأ. صار يُمرَّر كما يُمرَّر للفاتورة.
      'paperSize': settings.statementPaperSize,
      'logoWidthMm': settings.invoiceLogoWidthMm,
      'logoHeightMm': settings.invoiceLogoHeightMm,
      'mapQrSizeMm': settings.mapQrSizeMm,
      'customerName': st.customerName,
      'customerPhone': st.phone,
      'printedAt': DateFormat('yyyy-MM-dd hh:mm a').format(DateTime.now()),
      // فارغ = كشف كامل؛ غير فارغ ⇒ يُطبع سطر «الفترة» تحت العنوان.
      'period': periodLabel(st),
      'totals': {
        'purchases': st.totalPurchases,
        'paid': st.totalPaidOnInvoices,
        'debt': st.totalDebt,
        'credit': st.creditBalance,
        'net': st.netPosition,
        'pieces': st.totalPieces,
        'subPieces': st.totalSubscriptionPieces,
        'subValue': st.totalSubscriptionValue,
      },
      'invoices': st.invoices
          .map(
            (e) => {
              'id': e.id,
              'date': _d(e.date),
              'total': e.total,
              'paid': e.paid,
              'remaining': e.remaining,
            },
          )
          .toList(),
      // الأصناف في **جدول واحد**: كل بند بتاريخه وعدده وقيمته.
      // (حُذف الجدول المجمَّع `items` 2026-10-03 بطلب المستخدم: كان يكرّر
      //  الصنف بلا تاريخ ويطيل الكشف بلا جدوى. `st.itemSummary` يبقى لأنه
      //  مستخدم في شاشة حساب الزبون.)
      'itemsDetailed': [
        for (final inv in st.invoices)
          for (final it in inv.items)
            {
              'date': _dt(inv.date),
              // الاسم بلغة الواجهة — والـPDF يقرأ ما هنا كما هو.
              'name': localizedText(it.name, it.nameEn),
              'count': it.count,
              'value': it.value,
            },
      ],
      'payments': st.payments
          .map(
            (e) => {
              'date': _d(e.date),
              'amount': e.amount,
              'method': e.method,
              'note': _sourceLabel(e),
            },
          )
          .toList(),
      'usages': st.usages
          .map(
            (e) => {
              'date': _d(e.date),
              'subscriptionId': e.subscriptionId,
              'pieces': e.pieces,
              'value': e.value,
              'invoiceId': e.invoiceId,
            },
          )
          .toList(),
      // ─── قالب المستند: تفعيل ونصوص كل عنصر (شاشة «قوالب الطباعة») ───
      ...DocTemplateService.instance.transport(DocKind.statement),
    };
  }

  /// وصف مقروء لمصدر الدفعة — يفصل النقدي عن التسويات.
  ///
  /// ⚠️ الفاصل **شرطة قصيرة `–` لا طويلة `—`**: خط `AL-Mohanad` لا يحوي
  /// محرف الشرطة الطويلة (U+2014) فيُرسم مربّعًا/محرفًا خاطئًا في الـPDF.
  String _sourceLabel(StatementPayment p) {
    final base = switch (p.source) {
      'credit_use' => tr('استهلاك رصيد سلفة'),
      'cancel_refund' => tr('استرداد إلغاء اشتراك'),
      'delivery' => tr('تحصيل عند التسليم'),
      _ => p.method.isNotEmpty ? p.method : tr('دفعة'),
    };
    final note = p.note.trim();
    return note.isEmpty ? base : '$base – $note';
  }

  /// يحفظ الكشف في **مجلد إخراج المستندات** نفسه الذي تُحفظ فيه الفواتير.
  ///
  /// 🚨 **كان يُحفظ في مجلد مؤقّت** (`Directory.systemTemp.createTemp`) فتبدو
  /// الرسالة نجاحًا («حُفظ الكشف في …\Temp\statementXXXX\…») والملف يمحوه
  /// النظام عند أول تنظيف — أي أنه لا يُحفظ أصلًا. صار المسار من
  /// [InvoiceOutputService] فمكان واحد لكل ما يخرج من النظام، والاسم فريد
  /// بالتاريخ ([InvoicePdfNaming.buildDocumentFileName]) فلا يدهس كشفًا سابقًا.
  Future<void> _saveToDisk(Uint8List bytes, int customerId) async {
    try {
      final path = await InvoiceOutputService.instance.saveDocumentPdf(
        bytes,
        fileName: InvoicePdfNaming.buildDocumentFileName(
          'كشف_حساب_$customerId',
        ),
      );
      _info(trf('حُفظ الكشف في: {0}', [path]), AppColors.info);
    } catch (e) {
      debugPrint('saveStatement error: $e');
      _info(tr('تعذّر حفظ الكشف'), AppColors.danger);
    }
  }

  static String _m(double v) => v.toStringAsFixed(2);

  /// يوم فقط `yyyy-MM-dd` من كائن تاريخ.
  static String _day(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

  /// تنسيق تاريخ ISO إلى صيغة مقروءة (يتحمّل الفشل).
  static String _d(String raw) {
    if (raw.isEmpty) return '';
    try {
      return DateFormat('yyyy-MM-dd').format(DateTime.parse(raw));
    } catch (_) {
      return raw.length >= 10 ? raw.substring(0, 10) : raw;
    }
  }

  /// تاريخ **ووقت** — لبند الصنف («في أي يوم وكم الساعة أخذه»).
  ///
  /// ⚠️ الطوابع مخزَّنة محليًا (`toIso8601String` بلا `toUtc`) ⇒ لا تحويل
  /// مناطق زمنية هنا، وإلا أُزيح الوقت بإزاحة الجهاز.
  static String _dt(String raw) {
    if (raw.isEmpty) return '';
    try {
      return DateFormat('yyyy-MM-dd HH:mm').format(DateTime.parse(raw));
    } catch (_) {
      return raw;
    }
  }

  void _info(String message, Color color) {
    Get.snackbar(
      tr('كشف الحساب'),
      message,
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: color,
      colorText: Colors.white,
      duration: const Duration(seconds: 4),
    );
  }
}
