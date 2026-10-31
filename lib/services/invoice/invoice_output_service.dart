import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:laundry/config/constants.dart';
import 'package:laundry/config/run_target.dart';
import 'package:laundry/core/services/paper_size.dart';
import 'package:laundry/services/invoice/invoice_pdf_naming.dart';
import 'package:laundry/services/permission/permission_catalog.dart';
import 'package:laundry/services/permission/permission_service.dart';
import 'package:laundry/services/printer/printer_service.dart';
import 'package:laundry/services/settings/app_settings_service.dart';
import 'package:laundry/services/settings/setting_option.dart';
import 'package:laundry/sqldb.dart';
import 'package:laundry/services/i18n/l10n.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

/// نتيجة إخراج فاتورة واحدة — الطباعة و/أو حفظ PDF.
class InvoiceOutputResult {
  const InvoiceOutputResult({
    this.printed = false,
    this.savedPath,
    this.error,
    this.slipPrinted = false,
    this.slipSavedPath,
    this.slipError,
  });

  /// أُرسلت الفاتورة للطباعة فعلًا؟
  final bool printed;

  /// المسار الكامل لملف الـPDF المحفوظ (`null` = لم يُحفظ).
  final String? savedPath;

  /// رسالة فشل الحفظ إن وقع.
  ///
  /// **الطباعة لا تُنتج خطأً هنا** عن قصد: [PrinterService.printPdf] لا يرمي،
  /// بل يسقط إلى حوار النظام. أما الحفظ على القرص فيمكن أن يفشل (مسار غير
  /// صالح · قرص ممتلئ · صلاحية) ولذلك وحده يُبلَّغ عنه.
  final String? error;

  /// أُرسلت ورقة المغسلة للطباعة؟ (مستقلة عن الفاتورة عمدًا).
  final bool slipPrinted;

  /// مسار ملف ورقة المغسلة المحفوظ (`null` = لم يُحفظ).
  final String? slipSavedPath;

  /// فشل خاص بورقة المغسلة — لا يُسقط الفاتورة ولا عملية البيع.
  final String? slipError;

  bool get hasError => error != null || slipError != null;

  /// كل الرسائل مجمّعة للعرض في تنبيه واحد.
  String? get errorMessage {
    final parts = <String>[
      if (error != null) error!,
      if (slipError != null) slipError!,
    ];
    return parts.isEmpty ? null : parts.join('\n');
  }
}

/// إخراج الفاتورة: طباعة على الطابعة و/أو حفظ نسخة PDF — **طبقة واحدة**.
///
/// ## القرار الذي يحلّه
/// كان كل إصدار فاتورة **يُطبَع حتمًا** (`custompayinvoice` ← `printPDF`)، ولا
/// سبيل لتشغيل نقطة بيع بلا ورق. هنا **مفتاحان مستقلّان** في الإعدادات:
///   • [printOnSale] — الطباعة عند البيع (افتراضيًا مُفعَّل: لا تغيير للسلوك).
///   • [pdfExportEnabled] — حفظ نسخة PDF (افتراضيًا معطَّل).
///
/// فيغطّي التشغيل الحالات الثلاث: طباعة فقط · PDF فقط · طباعة + أرشيف PDF.
///
/// ## من يملك القيم؟ (ولا كتابة مزدوجة)
/// الثلاثة **خيارات مسجَّلة** في [SettingOptions] (مجموعة `invoiceOutput`)،
/// فتخضع للتطبيع والحدود والتدقيق والكاش عبر `AppSettingsService`، وتكتبها
/// شاشة الإعدادات عبر `SettingsController.updateSetting`.
///
/// وهذه الخدمة **تقرأ وتُنفّذ فقط ولا تكتب في `settings` إطلاقًا** — وهذا
/// مقصود: الكتابة من موضع ثانٍ تُخرج خريطة `settings` في المتحكّم عن
/// التزامن، فيبقى الحقل النصّي في الإعدادات معروضًا بقيمة قديمة.
///
/// ## الحذر
/// إن غاب المجلد المختار (حُذف أو انقطع مسار الشبكة) نُنشئه تلقائيًا؛ وإن
/// فشل الإنشاء يُبلَّغ المستخدم بالخطأ **بلا كتم** — والفاتورة محفوظة في
/// قاعدة البيانات على كل حال.
class InvoiceOutputService {
  InvoiceOutputService._();
  static final InvoiceOutputService instance = InvoiceOutputService._();

  final SqlDB _db = SqlDB();

  /// اسم المجلد الافتراضي داخل «المستندات» حين لا يختار المستخدم مجلدًا.
  static const String defaultFolderName = 'فواتير';

  // ─────────────────────────── القراءة ───────────────────────────

  /// هل تُطبَع الفاتورة على الطابعة عند البيع؟ (افتراضيًا: نعم)
  Future<bool> printOnSale() =>
      _flag(AppConstants.settingInvoicePrintOnSale, fallback: true);

  /// هل تُحفَظ نسخة PDF عند إصدار الفاتورة؟ (افتراضيًا: لا)
  Future<bool> pdfExportEnabled() =>
      _flag(AppConstants.settingInvoicePdfExport, fallback: false);

  /// المجلد الذي اختاره المستخدم (نص فارغ = لم يُختَر بعد).
  Future<String> chosenDirectory() async =>
      (await _db.getSetting(AppConstants.settingInvoicePdfDirectory))?.trim() ??
      '';

  /// هل ما زلنا على المجلد الافتراضي (لم يختر المستخدم مجلدًا)؟
  Future<bool> usingDefaultDirectory() async =>
      (await chosenDirectory()).isEmpty;

  /// المجلد الفعلي للحفظ: المختار إن وُجد، وإلا `<المستندات>/فواتير`.
  ///
  /// يُحسب في كل مرة (لا يُخزَّن) لأن `Documents` يتغيّر بتغيّر المستخدم.
  Future<String> effectiveDirectory() async {
    final chosen = await chosenDirectory();
    if (chosen.isNotEmpty) return chosen;
    final docs = await getApplicationDocumentsDirectory();
    return p.join(docs.path, defaultFolderName);
  }

  /// هل المجلد الفعلي موجود على القرص الآن؟
  Future<bool> directoryExists() async {
    try {
      return await Directory(await effectiveDirectory()).exists();
    } catch (e) {
      debugPrint('InvoiceOutputService.directoryExists error: $e');
      return false;
    }
  }

  // ─────────────────────────── الكتابة ───────────────────────────
  //
  // ⚠️ **لا كتابة هنا.** مسار المجلد خيار **مسجَّل** في [SettingOptions]،
  // فكتابته تمرّ من `SettingsController.updateSetting` ← `AppSettingsService`
  // (تطبيع + upsert + كاش + تدقيق). ولو كتبته الخدمة مباشرةً لَما تحدّث الحقل
  // النصّي في بطاقة الخيارات (خريطة `settings` في المتحكّم لا تعلم بالكتابة).

  /// منتقي مجلدات النظام — يعيد المسار المختار أو `null` عند الإلغاء.
  ///
  /// سطح المكتب فقط: على أندرويد لا يدعم المنتقي اختيار مجلد، فيبقى المجلد
  /// الافتراضي داخل مجلد التطبيق.
  Future<String?> pickDirectory() async {
    if (!AppPlatform.isDesktop) return null;
    try {
      final current = await chosenDirectory();
      return await FilePicker.platform.getDirectoryPath(
        dialogTitle: 'اختر مجلد حفظ فواتير PDF',
        initialDirectory: current.isNotEmpty ? current : null,
      );
    } catch (e) {
      debugPrint('InvoiceOutputService.pickDirectory error: $e');
      return null;
    }
  }

  /// يفتح المجلد الفعلي في مستكشف الملفات (ينشئه إن كان غائبًا).
  Future<bool> openDirectory() async {
    try {
      final dir = Directory(await effectiveDirectory());
      if (!await dir.exists()) await dir.create(recursive: true);
      return await launchUrl(Uri.file(dir.path));
    } catch (e) {
      debugPrint('InvoiceOutputService.openDirectory error: $e');
      return false;
    }
  }

  // ─────────────────────────── الإخراج ───────────────────────────

  /// يُخرج فاتورة: يطبعها و/أو يحفظ نسخة PDF بحسب المفتاحين المستقلّين.
  ///
  /// لا يرمي استثناءً أبدًا — الفشل يعود داخل [InvoiceOutputResult]، لأن
  /// الفاتورة **محفوظة في القاعدة قبل النداء** فلا يجوز أن يُسقط الإخراج
  /// عملية بيع مكتملة.
  ///
  /// تبقى هذه الدالة للتوافق مع المسارات القديمة التي لا تعرف ورقة المغسلة.
  Future<InvoiceOutputResult> deliver(
    Uint8List bytes, {
    required int invoiceNumber,
  }) => deliverBundle(bytes, invoiceNumber: invoiceNumber, printSlip: false);

  /// يُخرج **حزمة** من مستندين منفصلين: فاتورة العميل ثم ورقة المغسلة.
  ///
  /// ## لماذا مستندان لا ملف واحد؟
  ///   • كل مستند مهمة طباعة مستقلة ⇒ القاطع التلقائي يقصّ كل ورقة وحدها.
  ///   • فشل ورقة المغسلة لا يمنع فاتورة العميل ولا يُسقط عملية البيع.
  ///   • إعادة طباعة ورقة المغسلة وحدها ممكنة، وحفظ PDF لكل واحدة مستقلّ.
  ///
  /// ## المقاسات
  /// فاتورة العميل تأخذ `invoice_paper_size`. وورقة المغسلة تأخذ **نفس
  /// المقاس** — وتمرير [slipPaper] يخصّ فقط ارتفاع الحراري المُقدَّر من طول
  /// المحتوى، لا عرض الورق ولا نوعها.
  ///
  /// [print] و[savePdf] و[printSlip] = `null` تعني «اقرأ الإعداد». تمرير
  /// قيمة صريحة يلزم لإعادة الطباعة اليدوية التي يجب أن تطبع حتى لو كان
  /// خيار الطباعة عند البيع معطَّلًا.
  ///
  /// [copies] = عدد نسخ **هذه الطباعة وحدها** (1..5). `null` ⇒ يقرأ
  /// `invoice_copies` كالمعتاد. إعادة الطباعة من سجل الفواتير تختار عددًا
  /// لمرة واحدة ولا تكتب الإعداد، فلا يتغيّر سلوك الطباعة التلقائية عند
  /// البيع بسبب إعادة طباعة عرَضية.
  Future<InvoiceOutputResult> deliverBundle(
    Uint8List invoicePdf, {
    required int invoiceNumber,
    Uint8List? laundrySlipPdf,
    bool? print,
    bool? savePdf,
    bool? printSlip,
    PaperSize? invoicePaper,
    PaperSize? slipPaper,
    PdfRebuilder? rebuildInvoice,
    PdfRebuilder? rebuildSlip,
    int? copies,
  }) async {
    if (invoicePdf.isEmpty) {
      return const InvoiceOutputResult(
        error: 'ملف الفاتورة فارغ — لم تُطبَع ولم تُحفظ نسخة.',
      );
    }

    // 🛡️ `invoice.print` كان **معلنًا بلا إنفاذ**: وصفه في الكتالوج «إخراج
    // الفاتورة PDF وطباعتها أو مشاركتها»، ولم يكن يُفحص في أي موضع. الفحص
    // هنا — في **نقطة الإخراج الوحيدة** التي تمرّ منها الطباعة والحفظ وإعادة
    // الطباعة — لا في الواجهة وحدها، فلا يكفي إخفاء زرّ.
    //
    // **ولا يُسقط البيع**: هذه الدالة تُنادى بعد حفظ الفاتورة في القاعدة،
    // فغياب الصلاحية يمنع الإخراج فقط ويعود برسالة مفهومة. الكاشير بلا
    // صلاحية طباعة يبيع وتُحفظ فواتيره، ولا ورق يخرج.
    if (!PermissionService.can(PermissionKeys.invoicePrint)) {
      return InvoiceOutputResult(
        error: tr('لا تملك صلاحية الطباعة — الفاتورة محفوظة، راجع مدير النظام.'),
      );
    }

    final doPrint = print ?? await printOnSale();
    final doPdf = savePdf ?? await pdfExportEnabled();
    // نسخة محلية كي يُعرف وجود البايتات في فروع الطباعة والحفظ معًا.
    final slipBytes = laundrySlipPdf;
    final hasSlip = slipBytes != null && slipBytes.isNotEmpty;
    final doSlip =
        hasSlip &&
        (printSlip ??
            (AppSettingsService.instance.isLoaded
                ? AppSettingsService.instance.invoicePrintLaundrySlip
                : true));

    // مقاس الفاتورة نفسه — لا الافتراضي A4، وإلا أُرسل إيصال 80 مم إلى
    // تعريف بقياس A4 فظهر المحتوى صغيرًا في الزاوية (أو اختفى).
    final paper =
        invoicePaper ??
        PaperSizes.resolve(
          AppSettingsService.instance.isLoaded
              ? AppSettingsService.instance.invoicePaperSize
              : null,
        );

    var printed = false;
    String? savedPath;
    String? error;
    var slipPrinted = false;
    String? slipSavedPath;
    String? slipError;

    if (doPrint) {
      // [copies] يتجاوز الإعداد لهذه المكالمة فقط (إعادة طباعة باختيار
      // المستخدم). القيمة تُقصّ هنا أيضًا كي لا يعتمد الصحّة على الواجهة.
      final copyCount =
          copies == null ? _invoiceCopies() : copies.clamp(1, 5).toInt();
      for (var copy = 1; copy <= copyCount; copy++) {
        final ok = await PrinterService.instance.printPdf(
          invoicePdf,
          jobName:
              copyCount > 1
                  ? trf('فاتورة #{0} ({1}/{2})', [
                    invoiceNumber,
                    copy,
                    copyCount,
                  ])
                  : trf('فاتورة #{0}', [invoiceNumber]),
          paper: paper,
          // نسخة الطباعة تُبنى من نفس اللقطة لكن بهوامش الطابعة الفعلية —
          // فلا يُقصّ يمين الورقة (بداية أسماء الأصناف في RTL).
          rebuild: rebuildInvoice,
        );
        printed = printed || ok;
        // **لا فشل صامت**: الطباعة المباشرة قد تُقبل وتُسلَّم بلا ورق (تعريف
        // نصّي · طابعة غير متصلة · مهلة). نُبلّغ بالسبب الحقيقي بدل الصمت.
        if (!ok) error ??= PrinterService.instance.lastIssue;
      }
    }

    if (doPdf) {
      try {
        savedPath = await this.savePdf(
          invoicePdf,
          invoiceNumber: invoiceNumber,
        );
      } catch (e) {
        debugPrint('InvoiceOutputService.savePdf error: $e');
        error = trf('تعذّر حفظ نسخة PDF: {0}', [e]);
      }
    }

    if (doSlip) {
      if (doPrint) {
        final slipOk = await PrinterService.instance.printPdf(
          slipBytes,
          jobName: trf('ورقة المغسلة #{0}', [invoiceNumber]),
          paper: slipPaper ?? paper,
          rebuild: rebuildSlip,
        );
        slipPrinted = slipOk;
        if (!slipOk) {
          slipError = PrinterService.instance.lastIssue;
        }
      }

      if (doPdf) {
        try {
          slipSavedPath = await this.savePdf(
            slipBytes,
            invoiceNumber: invoiceNumber,
            suffix: '_laundry',
          );
        } catch (e) {
          debugPrint('InvoiceOutputService.saveSlipPdf error: $e');
          slipError = trf('تعذّر حفظ نسخة PDF لورقة المغسلة: {0}', [e]);
        }
      }
    }

    return InvoiceOutputResult(
      printed: printed,
      savedPath: savedPath,
      error: error,
      slipPrinted: slipPrinted,
      slipSavedPath: slipSavedPath,
      slipError: slipError,
    );
  }

  /// طباعة **ورقة المغسلة وحدها** من شاشة الفواتير السابقة.
  ///
  /// لا تقرأ مفتاح الطباعة عند البيع (الضغط زرّ صريح يعني «اطبع الآن»)،
  /// ولا تحفظ نسخة PDF — إعادة إخراج ورقة مفقودة ليست أرشفة.
  Future<InvoiceOutputResult> printLaundrySlipOnly(
    Uint8List bytes, {
    required int invoiceNumber,
    PaperSize? paper,
    PdfRebuilder? rebuild,
  }) async {
    if (bytes.isEmpty) {
      return const InvoiceOutputResult(
        error: 'ملف ورقة المغسلة فارغ — لم يُرسَل شيء إلى الطابعة.',
      );
    }
    // ورقة المغسلة مستند طباعة مثل الفاتورة ⇒ تحتاج `invoice.print` نفسها.
    if (!PermissionService.can(PermissionKeys.invoicePrint)) {
      return InvoiceOutputResult(
        error: tr('لا تملك صلاحية الطباعة — لم تُرسل ورقة المغسلة، راجع مدير النظام.'),
      );
    }
    final ok = await PrinterService.instance.printPdf(
      bytes,
      jobName: trf('ورقة المغسلة #{0}', [invoiceNumber]),
      paper: paper,
      rebuild: rebuild,
    );
    return InvoiceOutputResult(
      slipPrinted: ok,
      slipError: ok ? null : PrinterService.instance.lastIssue,
    );
  }

  /// عدد نسخ فاتورة العميل (1..5) — يُقرأ من `invoice_copies`.
  ///
  /// كان الإعداد موجودًا في الشاشة لكنه **ميت لا يُقرأ**؛ ربطه هنا يجعله
  /// يعمل، ونسخة ورقة المغسلة تبقى واحدة دائمًا.
  int _invoiceCopies() {
    final value =
        AppSettingsService.instance.isLoaded
            ? AppSettingsService.instance.invoiceCopies
            : 1;
    return value < 1 ? 1 : (value > 5 ? 5 : value);
  }

  /// يكتب ملف الـPDF في المجلد الفعلي باسم فريد، ويعيد مساره الكامل.
  ///
  /// [suffix] يميّز ورقة المغسلة (`_laundry`) فلا تدهس فاتورة العميل.
  Future<String> savePdf(
    Uint8List bytes, {
    required int invoiceNumber,
    String suffix = '',
  }) async {
    var base = InvoicePdfNaming.buildFileName(
      invoiceNumber: invoiceNumber,
      when: DateTime.now(),
    );
    final cleanSuffix = suffix.trim();
    if (cleanSuffix.isNotEmpty) {
      base = base.replaceFirst(
        '.${InvoicePdfNaming.extension}',
        '$cleanSuffix.${InvoicePdfNaming.extension}',
      );
    }
    return saveDocumentPdf(bytes, fileName: base);
  }

  /// يحفظ **أي** مستند PDF في مجلد الإخراج نفسه ويعيد مساره.
  ///
  /// ## لماذا دالة عامّة؟
  /// كشف الحساب كان يُحفظ في **مجلد مؤقّت** (`Directory.systemTemp`) عند
  /// فشل الطباعة: رسالة «حُفظ الكشف في …\Temp\statement1234\…» تبدو نجاحًا
  /// وهو ملف يمحوه النظام عند أول تنظيف. صار كل مستند يُخرج من النظام يسكن
  /// **المجلد الذي اختاره المستخدم** (أو `<المستندات>/فواتير` افتراضيًا)،
  /// فمكان واحد يعرفه ويجده.
  ///
  /// [fileName] يُمرَّر جاهزًا (من [InvoicePdfNaming]) لا يُبنى هنا، لأن
  /// تسمية كل نوع مستند تخصّه. والكتابة فوق ملف قائم ممنوعة ([dedupe]).
  Future<String> saveDocumentPdf(
    Uint8List bytes, {
    required String fileName,
  }) async {
    final dir = Directory(await effectiveDirectory());
    if (!await dir.exists()) await dir.create(recursive: true);

    final name = InvoicePdfNaming.dedupe(fileName, await _existingNames(dir));
    final file = File(p.join(dir.path, name));
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }

  /// أسماء الملفات القائمة في المجلد — لمنع الكتابة فوقها.
  Future<Set<String>> _existingNames(Directory dir) async {
    final names = <String>{};
    await for (final entity in dir.list(followLinks: false)) {
      if (entity is File) names.add(p.basename(entity.path));
    }
    return names;
  }

  /// قيمة منطقية: كاش الخدمة أولًا (أسرع وأدقّ)، ثم القاعدة، ثم الافتراضي.
  Future<bool> _flag(String key, {required bool fallback}) async {
    try {
      if (AppSettingsService.instance.isLoaded &&
          SettingOptions.byKey(key) != null) {
        return AppSettingsService.instance.effectiveBool(key);
      }
    } catch (_) {}
    try {
      final raw = await _db.getSetting(key);
      if (raw == null) return fallback;
      return isTruthy(raw);
    } catch (e) {
      debugPrint('InvoiceOutputService._flag($key) error: $e');
      return fallback;
    }
  }
}
