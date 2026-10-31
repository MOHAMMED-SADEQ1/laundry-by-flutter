import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:laundry/controller/printInvoicecontroller.dart';
import 'package:laundry/core/services/invoice_share_service.dart';
import 'package:laundry/core/services/paper_size.dart';
import 'package:laundry/core/services/preparePDF.dart';
import 'package:laundry/core/theme/app_colors.dart';
import 'package:laundry/services/business_info_service.dart';
import 'package:laundry/services/i18n/l10n.dart';
import 'package:laundry/services/invoice/invoice_items_service.dart';
import 'package:laundry/services/invoice/credit_note_service.dart';
import 'package:laundry/services/invoice/invoice_output_service.dart';
import 'package:laundry/services/pdf/doc_template.dart';
import 'package:laundry/services/pdf/doc_template_service.dart';
import 'package:laundry/services/pdf/laundry_slip.dart';
import 'package:laundry/services/pdf/laundry_slip_pdf.dart';
import 'package:laundry/services/printer/print_layout.dart';
import 'package:laundry/services/settings/app_settings_service.dart';
import 'package:laundry/sqldb.dart';
import 'package:laundry/view/widget/invoice/invoice_return_dialog.dart';

class PreviousInvoiceController extends GetxController {
  final invoices = <Map<String, dynamic>>[].obs;
  final isLoading = false.obs;
  final hasMore = true.obs;
  var page = 1;

  /// عدد الفواتير في الصفحة الواحدة — يُضبط من «الإعدادات ← خيارات النظام».
  int get limit => AppSettingsService.instance.pageSize;

  final ScrollController scrollController = ScrollController();
  final isRefreshing = false.obs;
  final loadingMessage = tr('جاري تحميل الفواتير...').obs;
  final Random random = Random();

  @override
  void onInit() {
    super.onInit();
    scrollController.addListener(_scrollListener);
    loadInitialData();
  }

  Future<void> loadInitialData() async {
    try {
      isLoading.value = true;
      final data = await readData(page: 1);
      // debugPrint('$data');
      invoices.assignAll(data);
      hasMore.value = data.length == limit;
    } catch (e) {
      Get.snackbar(
        tr('خطأ'),
        tr('فشل في تحميل الفواتير'),
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> loadMoreData() async {
    if (isLoading.value || !hasMore.value) return;

    try {
      isLoading.value = true;
      loadingMessage.value = tr('جاري تحميل المزيد من الفواتير...');

      await Future.delayed(Duration(milliseconds: 500));

      page++;
      final newData = await readData(page: page);

      if (newData.isEmpty) {
        hasMore.value = false;
        loadingMessage.value = tr('تم تحميل كل الفواتير');
        return;
      }

      invoices.addAll(newData);
      hasMore.value = newData.length == limit;
    } catch (e) {
      page--;
      Get.snackbar(
        tr('خطأ'),
        tr('فشل في تحميل المزيد من الفواتير'),
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      isLoading.value = false;
    }
  }

  void _scrollListener() {
    if (scrollController.position.pixels >=
        scrollController.position.maxScrollExtent - 200) {
      loadMoreData();
    }
  }

  Future<List<Map<String, dynamic>>> readData({required int page}) async {
    try {
      SqlDB db = SqlDB();
      // القيمة تُقرأ مرة واحدة في هذا الاستدعاء — فـ`LIMIT` و`OFFSET`
      // يُحسبان على نفس الدفعة حتى لو تغيّر الإعداد أثناء التمرير.
      final pageSize = limit;
      final offset = (page - 1) * pageSize;

      // `is_returned` يُحسب لكل صفّ في نفس الاستعلام — بلا استعلام فرعي
      // لكل فاتورة في الواجهة (كان يعني N+1 على كل تمرير).
      return await db.readData('''
        SELECT i.*,
               (SELECT COUNT(*) FROM "credit_notes" cn
                 WHERE cn."invoice_id" = i."invoices_id") AS "is_returned"
        FROM "invoices" i
        ORDER BY i."invoices_id" DESC
        LIMIT $pageSize OFFSET $offset
      ''');
    } catch (e) {
      debugPrint('Error reading data: $e');
      return [];
    }
  }

  Future<void> refreshData() async {
    try {
      isRefreshing.value = true;
      page = 1;
      await loadInitialData();
    } finally {
      isRefreshing.value = false;
    }
  }

  @override
  void onClose() {
    scrollController.dispose();
    super.onClose();
  }

  // ═══════════════════════════════════════════════════════════════════════
  // إعادة الطباعة من الفواتير السابقة
  // ═══════════════════════════════════════════════════════════════════════

  /// يعيد طباعة **فاتورة العميل + ورقة المغسلة** من صفّ قاعدة البيانات.
  ///
  /// ## ما أُصلح هنا؟
  /// النسخة السابقة كانت:
  ///   • تفرض A4 دائمًا ولو كانت الطابعة حرارية.
  ///   • تُهمل `invoice_number_text` و`customer_phone` و`pickup_code`
  ///     والرقم الضريبي والسجل التجاري.
  ///   • تتجاوز `InvoiceOutputService` فلا تعرف إعدادات الطباعة/PDF.
  ///
  /// الآن تُبنى الحمولة كاملة من `invoices` + لقطة `invoice_items` (أو
  /// `list_data` عند غيابها)، وتُقرأ مقاسات الورق من الإعدادات.
  ///
  /// [copies] = عدد نسخ الفاتورة لهذه الطباعة (1..5). `null` ⇒ `invoice_copies`
  /// المحفوظ. الاختيار من سجل الفواتير لا يُكتب في الإعدادات.
  Future<void> printInvoice(
    Map<String, dynamic> invoice, {
    int? copies,
  }) async {
    try {
      final payload = await _invoicePayload(invoice);
      final invoiceNumber = _invoiceId(invoice);
      final pdfBytes = await compute(PreparePDF.generatePdfData, payload);

      // ورقة المغسلة تُطبع مع الفاتورة فقط إن كان خيارها مفعّلًا.
      //
      // 🚨 فشلها معزول: تعذّر الخطّ أو الأصول أو التخطيط لا يمنع طباعة
      // فاتورة العميل، بل يُبلَّغ عنه مع نتيجة الإخراج.
      _SlipBundle? slip;
      String? slipBuildError;
      // إشعار دائن لا ورقة مغسلة له: لا قطع تُتابَع، ولا رمز استلام يُطبع.
      final isCreditNote = invoice['credit_note_of'] != null;
      if (!isCreditNote &&
          AppSettingsService.instance.invoicePrintLaundrySlip) {
        try {
          slip = await _slipBundle(invoice);
        } catch (e) {
          debugPrint('PreviousInvoiceController.slip build error: $e');
          slipBuildError = trf('تعذّر تجهيز ورقة المغسلة: {0}', ['$e']);
        }
      }

      final slipBundle = slip;
      final output = await InvoiceOutputService.instance.deliverBundle(
        pdfBytes,
        invoiceNumber: invoiceNumber,
        laundrySlipPdf: slipBundle?.bytes,
        // إعادة الطباعة اليدوية: اطبع الآن مهما كان خيار «الطباعة عند البيع»،
        // ولا تحفظ نسخة PDF — الأرشفة تمّت وقت البيع.
        print: true,
        savePdf: false,
        printSlip: slipBundle != null,
        copies: copies,
        invoicePaper: PaperSizes.resolve('${payload['paperSize'] ?? ''}'),
        slipPaper: slipBundle?.paper,
        rebuildInvoice:
            (layout) => compute(
              PreparePDF.generatePdfData,
              PrintLayout.fromPdfPageFormat(layout).applyTo(payload),
            ),
        rebuildSlip:
            slipBundle == null
                ? null
                : (layout) {
                  final slipPayload = slipBundle.payload;
                  return compute(
                    LaundrySlipPdf.generateLaundrySlipPdf,
                    PrintLayout.fromPdfPageFormat(layout).applyTo(slipPayload),
                  );
                },
      );
      _report(output, slipBuildError: slipBuildError);
    } catch (e) {
      debugPrint('PreviousInvoiceController.printInvoice error: $e');
      Get.snackbar(tr('خطأ'), '$e', snackPosition: SnackPosition.BOTTOM);
    }
  }

  /// يحفظ نسخة PDF من الأرشيف — **بلا طباعة**.
  ///
  /// ## لماذا زرّ مستقلّ؟
  /// إعادة الطباعة كانت تُمرّر `savePdf: false` عن قصد («الأرشفة تمّت وقت
  /// البيع»)، وذلك صحيح للطباعة لكنه يترك المستخدم بلا سبيل لأخذ نسخة
  /// رقمية من فاتورة قديمة (لإرسالها بالبريد، أو لملفّ محاسبي، أو حين لا
  /// طابعة متصلة). هذا المسار يفعل الحفظ وحده: لا يستهلك ورقًا ولا يغيّر
  /// إعداد «الطباعة عند البيع».
  ///
  /// يمرّ من [InvoiceOutputService] لا من كتابة ملف مباشرة — فيرث فحص
  /// `invoice.print`، والتسمية الفريدة، ومنع الكتابة فوق ملف قائم، ورسالة
  /// الخطأ الحقيقية عند فشل القرص.
  Future<void> saveInvoicePdf(Map<String, dynamic> invoice) async {
    try {
      final payload = await _invoicePayload(invoice);
      final invoiceNumber = _invoiceId(invoice);
      final pdfBytes = await compute(PreparePDF.generatePdfData, payload);
      final output = await InvoiceOutputService.instance.deliverBundle(
        pdfBytes,
        invoiceNumber: invoiceNumber,
        print: false,
        savePdf: true,
        printSlip: false,
      );
      _report(output);
    } catch (e) {
      debugPrint('PreviousInvoiceController.saveInvoicePdf error: $e');
      Get.snackbar(tr('خطأ'), '$e', snackPosition: SnackPosition.BOTTOM);
    }
  }

  /// ورقة المغسلة وحدها — للورقة التي فُقدت أو تلفت.
  ///
  /// تتجاوز مفتاح «الطباعة عند البيع» لأن الزرّ نفسه أمر صريح بالطباعة.
  Future<void> printLaundrySlip(Map<String, dynamic> invoice) async {
    try {
      final slip = await _slipBundle(invoice);
      if (slip == null) {
        Get.snackbar(
          tr('تنبيه'),
          tr('تعذّر تجهيز ورقة المغسلة — الخطّ أو الأصول غير جاهزة.'),
          snackPosition: SnackPosition.BOTTOM,
        );
        return;
      }
      final output = await InvoiceOutputService.instance.printLaundrySlipOnly(
        slip.bytes,
        invoiceNumber: _invoiceId(invoice),
        paper: slip.paper,
        rebuild:
            (layout) => compute(
              LaundrySlipPdf.generateLaundrySlipPdf,
              PrintLayout.fromPdfPageFormat(layout).applyTo(slip.payload),
            ),
      );
      _report(output);
    } catch (e) {
      debugPrint('PreviousInvoiceController.printLaundrySlip error: $e');
      Get.snackbar(tr('خطأ'), '$e', snackPosition: SnackPosition.BOTTOM);
    }
  }

  /// إرجاع الفاتورة كاملة بإشعار دائن.
  ///
  /// الواجهة تجمع القرار (سبب + طريقة الردّ)، و`CreditNoteService` تنفّذه في
  /// معاملة واحدة. **لا منطق محاسبي هنا** — المتحكّم لا يحسب مبالغ ولا يكتب
  /// صفوفًا، كي يبقى القرار في طبقة واحدة قابلة للاختبار.
  Future<void> returnInvoice(Map<String, dynamic> invoice) async {
    final choice = await showInvoiceReturnDialog(invoice: invoice);
    if (choice == null) return;

    final result = await CreditNoteService.instance.returnInvoice(
      invoiceId: _invoiceId(invoice),
      reason: choice.reason,
      refundAsCredit: choice.refundAsCredit,
    );

    Get.snackbar(
      result.ok ? tr('تم الإرجاع') : tr('تعذّر الإرجاع'),
      result.message,
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: result.ok ? const Color(0xFF16A34A) : AppColors.danger,
      colorText: Colors.white,
      duration: Duration(seconds: result.ok ? 4 : 6),
      icon: Icon(
        result.ok ? Icons.assignment_turned_in : Icons.error_outline,
        color: Colors.white,
      ),
    );

    if (result.ok) {
      await refreshData();
    }
  }

  /// حمولة `PreparePDF` كاملة من الصفّ المخزَّن — بلا أي رقم مخترَع.
  Future<Map<String, dynamic>> _invoicePayload(
    Map<String, dynamic> invoice,
  ) async {
    await PrintInvoiceController.ensureAssets();
    final settings = AppSettingsService.instance;
    final extra = InvoiceShareService.decodeMap(invoice['map_data']);
    final items = await _displayItems(invoice);

    final total =
        _num(
          extra['summation'] ??
              invoice['total_price'] ??
              invoice['final_amount'],
        ).toDouble();
    final discount = _num(invoice['discount_amount']).toDouble();
    final payable =
        invoice['final_amount'] != null
            ? _num(invoice['final_amount']).toDouble()
            : (total - discount);
    final tax = _num(invoice['tax_amount']).toDouble();

    final transport = DocTemplateService.instance.transport(DocKind.invoice);
    // إشعار الدائن يُطبع بعنوانه لا بعنوان الفاتورة: القالب واحد والأرقام
    // واحدة، لكن الورقة التي تُسلَّم للزبون يجب أن تقول «إشعار دائن» —
    // ورقم سالب تحت كلمة «فاتورة ضريبية» مستند مضلِّل لا مجرّد شكل.
    if (invoice['credit_note_of'] != null) {
      transport['docTexts'] = <String, String>{
        ...Map<String, String>.from(transport['docTexts'] as Map),
        DocCatalog.kTitle: tr('إشعار دائن'),
      };
    }

    return <String, dynamic>{
      'payment': '${extra['payment'] ?? invoice['payment_method'] ?? ''}',
      'logoImage': PrintInvoiceController.logoImageBytes,
      'riyalImage': PrintInvoiceController.riyalImageBytes,
      'arabicFont': PrintInvoiceController.arabicFont,
      'invoiceItems': items,
      'summation': total,
      'invoiceNumber': _invoiceId(invoice),
      // رقم العرض: البادئة والحشو كما طُبع وقت البيع، لا المعرّف الداخلي.
      'invoiceNumberText': _displayNumber(invoice),
      'customername':
          '${extra['customername'] ?? invoice['customer_name'] ?? ''}',
      'customerPhone': '${invoice['customer_phone'] ?? ''}',
      'pickupCode': '${invoice['pickup_code'] ?? ''}',
      // فاتورة المشترك تُطبع بلا أسعار (على حساب الاشتراك).
      'hidePrices': invoice['subscription_id'] != null,
      'date': _dateText(invoice, extra),
      'bizName': BusinessInfoService.instance.name,
      'bizPhone': BusinessInfoService.instance.phone,
      'bizAddress': BusinessInfoService.instance.address,
      'bizTaxNumber': BusinessInfoService.instance.taxNumber,
      'bizCrNumber': BusinessInfoService.instance.crNumber,
      'bizShortAddress': BusinessInfoService.instance.shortAddress,
      // رمز QR للموقع يُطبع أسفل نسخة إعادة الطباعة كذلك — وإلا اختلفت
      // ورقتان لنفس الفاتورة في آخر سطر منها.
      'bizMapUrl': BusinessInfoService.instance.location,
      'createdByName': '',
      // ─── خيارات العرض والطباعة (من الإعدادات الحالية) ───
      'paperSize': settings.invoicePaperSize,
      'invoiceTitle': settings.invoiceTitleText,
      'footerNote': settings.invoiceFooterNote,
      'showLogo': settings.invoiceShowLogo,
      'logoWidthMm': settings.invoiceLogoWidthMm,
      'logoHeightMm': settings.invoiceLogoHeightMm,
      'mapQrSizeMm': settings.mapQrSizeMm,
      'showTaxNumber': settings.invoiceShowTaxNumber,
      'showCrNumber': settings.invoiceShowCrNumber,
      'showShortAddress': settings.invoiceShowShortAddress,
      'showCashier': settings.invoiceShowCashier,
      'showDatetime': settings.invoiceShowDatetime,
      'showQr': settings.invoiceShowQr,
      // ─── الأرقام كما حُفظت ───
      'discountAmount': discount,
      'discountCode': '${invoice['discount_code'] ?? ''}',
      'taxAmount': tax,
      'taxRate': _num(invoice['tax_rate']).toDouble(),
      'taxBase': _num(invoice['tax_base']).toDouble(),
      'payable': payable,
      'paidAmount': _num(invoice['paid_amount']).toDouble(),
      'remainingAmount': _num(invoice['remaining_amount']).toDouble(),
      // ─── قالب المستند ───
      ...transport,
    };
  }

  /// يُجهّز ورقة المغسلة من نفس المصدر — بلا أسعار.
  Future<_SlipBundle?> _slipBundle(Map<String, dynamic> invoice) async {
    await PrintInvoiceController.ensureAssets();
    if (PrintInvoiceController.arabicFont == null) return null;

    final settings = AppSettingsService.instance;
    final extra = InvoiceShareService.decodeMap(invoice['map_data']);
    final data = LaundrySlipData.fromItems(
      items: await _displayItems(invoice),
      invoiceNumber: _displayNumber(invoice),
      date: _dateText(invoice, extra),
      customerName:
          '${extra['customername'] ?? invoice['customer_name'] ?? ''}',
      customerPhone: '${invoice['customer_phone'] ?? ''}',
      pickupCode: '${invoice['pickup_code'] ?? ''}',
      bizName: BusinessInfoService.instance.name,
      bizPhone: BusinessInfoService.instance.phone,
      paperSize: settings.invoicePaperSize,
      isRtl: settings.docLanguage.isRtl,
    );

    final payload = <String, dynamic>{
      ...data.toMap(),
      // قالب ورقة المغسلة المستقلّ — نصوصه وتفعيلاته وأنماطه.
      ...DocTemplateService.instance.transport(DocKind.laundrySlip),
      'arabicFont': PrintInvoiceController.arabicFont,
      'logoImage': PrintInvoiceController.logoImageBytes,
      'showLogo': settings.invoiceShowLogo,
    };
    final bytes = await compute(LaundrySlipPdf.generateLaundrySlipPdf, payload);
    return _SlipBundle(
      bytes: bytes,
      paper: LaundrySlipPdf.paperForData(payload),
      payload: payload,
    );
  }

  /// بنود العرض: لقطة `invoice_items` أولًا (أدقّ وأثبت)، ثم `list_data`.
  Future<List<Map<String, dynamic>>> _displayItems(
    Map<String, dynamic> invoice,
  ) async {
    final snapshot = await InvoiceItemsService.instance.itemsOf(
      _invoiceId(invoice),
    );
    if (snapshot.isNotEmpty) {
      return snapshot
          .map(
            (row) => <String, dynamic>{
              'vestments': '${row['item_name'] ?? ''}',
              'vestments_en': row['item_name_en'],
              'content': '${row['content'] ?? ''}',
              'content_en': row['content_en'],
              'count': row['qty'] ?? 0,
              'price': row['unit_price'] ?? 0,
              'total_price': row['total_price'] ?? 0,
              'note': '${row['note'] ?? ''}',
              'note_en': row['note_en'],
            },
          )
          .toList(growable: false);
    }
    return InvoiceShareService.decodeItems(invoice['list_data']);
  }

  /// رقم الفاتورة المعروض (بادئة + حشو) مع سقوط آمن للقديم.
  String _displayNumber(Map<String, dynamic> invoice) {
    final stored = '${invoice['invoice_number_text'] ?? ''}'.trim();
    if (stored.isNotEmpty) return stored;
    final id = _invoiceId(invoice);
    final settings = AppSettingsService.instance;
    final padding = settings.invoiceNumberPadding;
    return '${settings.invoiceNumberPrefix}'
        '${padding > 0 ? id.toString().padLeft(padding, '0') : id}';
  }

  /// التاريخ المخزَّن في `map_data` (محايد اللغة منذ 2026-10-29).
  ///
  /// الفواتير الأقدم قد تحمل لاحقة «ص/م» بلغة إصدارها؛ نُبقيها كما هي بدل
  /// تخمين لغة نصّ مخزَّن. الفواتير الجديدة تُخزَّن `yyyy-MM-dd HH:mm:ss`
  /// فيصلح إعادة طباعتها بالعربية أو الإنجليزية بلا خلط.
  String _dateText(Map<String, dynamic> invoice, Map<String, dynamic> extra) {
    final stored = '${extra['date'] ?? ''}'.trim();
    if (stored.isNotEmpty) return stored;
    return '${invoice['invoice_date'] ?? ''}'
        .replaceFirst('T', ' ')
        .split('.')
        .first
        .trim();
  }

  int _invoiceId(Map<String, dynamic> invoice) =>
      (invoice['invoices_id'] as num?)?.toInt() ??
      int.tryParse('${invoice['invoices_id'] ?? ''}') ??
      0;

  num _num(dynamic value) =>
      value is num ? value : num.tryParse('${value ?? ''}') ?? 0;

  void _report(InvoiceOutputResult output, {String? slipBuildError}) {
    final errors = <String>[
      if (output.error != null) output.error!,
      if (output.slipError != null) output.slipError!,
      if (slipBuildError != null) slipBuildError,
    ];
    if (errors.isNotEmpty) {
      Get.snackbar(
        tr('تنبيه'),
        errors.join('\n'),
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 6),
      );
      return;
    }
    if (output.savedPath != null || output.slipSavedPath != null) {
      Get.snackbar(
        tr('حُفظت نسخة PDF'),
        <String>[
          if (output.savedPath != null) output.savedPath!,
          if (output.slipSavedPath != null) output.slipSavedPath!,
        ].join('\n'),
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 4),
      );
    }
  }
}

/// نتيجة تجهيز ورقة المغسلة: البايتات + مقاس مهمة الطباعة + الحمولة.
class _SlipBundle {
  const _SlipBundle({
    required this.bytes,
    required this.paper,
    required this.payload,
  });
  final Uint8List bytes;
  final PaperSize paper;

  /// تُستخدم لإعادة التوليد بهوامش الطابعة عند الطباعة المباشرة.
  final Map<String, dynamic> payload;
}
