import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:laundry/config/constants.dart';
import 'package:laundry/config/run_target.dart';
import 'package:laundry/core/services/paper_size.dart';
import 'package:laundry/services/i18n/l10n.dart';
import 'package:laundry/services/security/session_manager.dart';
import 'package:laundry/services/settings/app_settings_service.dart';
import 'package:laundry/services/settings/setting_option.dart';
import 'package:laundry/sqldb.dart';
import 'package:pdf/pdf.dart' show PdfPageFormat;
import 'package:printing/printing.dart';

/// اختيار الطابعة الافتراضية والطباعة المباشرة — **طبقة واحدة** لكل طباعة.
///
/// ## المشكلة التي يحلّها
/// كل مواضع الطباعة كانت تنادي `Printing.layoutPdf` بلا طابعة، فيظهر
/// **حوار طباعة النظام في كل مرة** ويُعاد اختيار الطابعة يدويًا. هذا مزعج
/// في نقطة بيع تُصدر عشرات الفواتير يوميًا.
///
/// ## الحل
/// يُختار المعرّف (`url`) الطابعة **مرة واحدة** من الإعدادات ويُحفظ في جدول
/// `settings`. وعند تفعيل «الطباعة على الطابعة المختارة تلقائيًا» تُطبَع
/// الفاتورة **مباشرةً** على تلك الطابعة بلا حوار (`Printing.directPrintPdf`).
///
/// ## لماذا خدمة واحدة؟
/// لأن المنطق نفسه مطلوب في أربعة مواضع (الفاتورة · الفاتورة السابقة ·
/// ملخص الوردية · كشف الحساب). تكراره في كل موضع يعني افتراق السلوك.
///
/// ## الحذر
/// إن حُذفت الطابعة المختارة من الجهاز (أو غاب معرّفها) نرجع تلقائيًا إلى
/// حوار النظام — **لا فشل صامت ولا منع طباعة**.
/// يعيد بناء مستند الطباعة حسب تخطيط الطابعة الفعلي.
///
/// يُستدعى من `onLayout` بعد أن يعرف تعريف الطابعة مقاس الورقة والهوامش غير
/// القابلة للطباعة، فتُولَّد نسخة تنطبق على المساحة القابلة للطباعة بدل قصّ
/// الجانب الأيمن من الورقة (بداية أسماء الأصناف في RTL).
typedef PdfRebuilder = FutureOr<Uint8List> Function(PdfPageFormat layout);

class PrinterService {
  PrinterService._();
  static final PrinterService instance = PrinterService._();

  final SqlDB _db = SqlDB();

  /// هل النظام يدعم سرد الطابعات؟ (سطح المكتب نعم · أندرويد لا).
  ///
  /// على أندرويد تُترك الطباعة لحوار النظام ولا تُسرد الطابعات.
  static bool get isDesktop => AppPlatform.isDesktop;

  /// فحص دعم سرد الطابعات من الحزمة نفسها (أدقّ من فحص النظام وحده).
  Future<bool> canListPrinters() async {
    if (!isDesktop) return false;
    try {
      final info = await Printing.info();
      return info.canListPrinters;
    } catch (e) {
      debugPrint('PrinterService.canListPrinters error: $e');
      return false;
    }
  }

  /// طابعات الجهاز المتاحة (قد تكون فارغة عند الفشل).
  Future<List<Printer>> listPrinters() async {
    if (!isDesktop) return const [];
    try {
      return await Printing.listPrinters();
    } catch (e) {
      debugPrint('PrinterService.listPrinters error: $e');
      return const [];
    }
  }

  // ─────────────────────────── الاختيار المخزَّن ───────────────────────────

  /// معرّف الطابعة المختارة (`url`) أو نص فارغ.
  Future<String> selectedUrl() async =>
      (await _db.getSetting(AppConstants.settingPrinterSelectedUrl))?.trim() ??
      '';

  /// اسم الطابعة المختارة للعرض.
  Future<String> selectedName() async =>
      (await _db.getSetting(AppConstants.settingPrinterSelectedName))?.trim() ??
      '';

  /// هل خيار «الطباعة التلقائية على الطابعة المختارة» مُفعَّل؟
  Future<bool> useDefaultEnabled() async {
    try {
      if (AppSettingsService.instance.isLoaded) {
        return AppSettingsService.instance.effectiveBool(
          AppConstants.settingPrintUseDefaultPrinter,
        );
      }
    } catch (_) {}
    return isTruthy(
      await _db.getSetting(AppConstants.settingPrintUseDefaultPrinter),
    );
  }

  /// حفظ الطابعة الافتراضية (يُسجَّل في التدقيق — قرار تشغيلي).
  Future<void> setDefault(Printer printer) async {
    await _db.updateSetting(
      AppConstants.settingPrinterSelectedUrl,
      printer.url,
    );
    await _db.updateSetting(
      AppConstants.settingPrinterSelectedName,
      printer.name,
    );
    await _db.logAudit(
      userId: SessionManager.currentUserId,
      action: 'printer_default_set',
      tableName: 'settings',
      newValues: '{"printer":"${printer.name}","url":"${printer.url}"}',
    );
  }

  /// إلغاء الطابعة المختارة (رجوع إلى حوار النظام دائمًا).
  Future<void> clearDefault() async {
    final old = await selectedName();
    await _db.updateSetting(AppConstants.settingPrinterSelectedUrl, '');
    await _db.updateSetting(AppConstants.settingPrinterSelectedName, '');
    await _db.logAudit(
      userId: SessionManager.currentUserId,
      action: 'printer_default_cleared',
      tableName: 'settings',
      oldValues: '{"printer":"$old"}',
    );
  }

  // ─────────────────────────── الطباعة ───────────────────────────

  /// آخر مشكلة واجهتها آخر محاولة طباعة (`null` = لا مشكلة).
  ///
  /// **لماذا حقل لا استثناء؟** لأن [printPdf] تُستدعى في مسار بيع مكتمل،
  /// فلا يجوز أن ترمي وتُسقط الفاتورة. لكن الفشل الصامت أسوأ: المستخدم يرى
  /// «تم البيع» ولا يرى ورقة. فيقرأ المُستدعي هذا الحقل ويُبلّغ.
  String? lastIssue;

  /// يُصفّر التبليغ قبل كل محاولة (كي لا يُقرأ تبليغ قديم).
  void clearIssue() => lastIssue = null;

  /// يُطبع مستندًا — على الطابعة المختارة مباشرةً إن أمكن، وإلا بحوار النظام.
  ///
  /// [paper] مقاس المستند الفعلي. يُمرَّر لأن الافتراضي في الحزمة **A4**،
  /// فإيصال 80 مم كان يُرسَل إلى تعريف بقياس A4 (محتوى صغير في الزاوية).
  ///
  /// [rebuild] يُعيد توليد المستند بعد أن تُبلّغ الطابعة عن مقاس الورقة
  /// وهوامشها الحقيقية. بدونه تُطبع البايتات كما هي، وقد يُقصّ الجانب الأيمن
  /// إن كان هامش الطابعة أوسع من هامش التصميم.
  ///
  /// يرجع `true` إن أُرسل المستند للطباعة. ولا يرمي استثناءً.
  Future<bool> printPdf(
    Uint8List bytes, {
    String jobName = '',
    PaperSize? paper,
    PdfRebuilder? rebuild,
  }) async {
    lastIssue = null;
    final effectiveJobName = jobName.trim().isEmpty ? tr('مستند') : jobName;
    if (bytes.isEmpty) {
      lastIssue = tr('ملف الطباعة فارغ — لم يُرسَل شيء إلى الطابعة.');
      return false;
    }

    if (await useDefaultEnabled()) {
      final url = await selectedUrl();
      debugPrint(
        trf('PrinterService: تلقائي=مُفعَّل · الطابعة="{0}"', [url]),
      );
      if (url.isEmpty) {
        lastIssue = tr('لم تُختَر طابعة بعد — يُفتح حوار النظام.');
      } else {
        final printers = await listPrinters();
        debugPrint(
          trf('PrinterService: طابعات الجهاز={0}', [printers.length]),
        );
        Printer? target;
        for (final p in printers) {
          if (p.url == url) {
            target = p;
            break;
          }
        }

        if (target == null) {
          lastIssue = trf(
            'الطابعة المختارة «{0}» غير موجودة على هذا الجهاز — يُفتح حوار النظام.',
            [url],
          );
        } else if (!target.isAvailable) {
          lastIssue = trf(
            'الطابعة «{0}» غير متصلة أو متوقفة أو موقوفة — يُفتح حوار النظام.',
            [target.name],
          );
        } else {
          debugPrint(
            trf(
              'PrinterService: الهدف="{0}" · التعريف="{1}" · متاحة={2}',
              [target.name, target.model, target.isAvailable],
            ),
          );
          if (await _tryDirect(
            bytes,
            target,
            effectiveJobName,
            paper,
            rebuild,
          )) {
            return true;
          }
          debugPrint(
            trf('PrinterService: فشلت المحاولتان — {0}', [lastIssue ?? '']),
          );
        }
      }
    } else {
      debugPrint(
        tr('PrinterService: الطباعة التلقائية معطّلة — حوار النظام.'),
      );
    }

    // المسار الافتراضي: حوار طباعة النظام (كما كان قبل الميزة).
    return Printing.layoutPdf(
      name: effectiveJobName,
      onLayout: _layoutCallback(bytes, rebuild),
    );
  }

  /// دالة `onLayout` الموحّدة: تُعيد نسخة الطباعة إن أمكن، وإلا الأصل.
  ///
  /// أي فشل في إعادة التوليد **لا يُسقط الطباعة**: نرجع الأصل بدل أن نفقد
  /// الورقة كلها. الطبقة الأصلية تعتبر رمي استثناء هنا فشلًا للمهمة.
  LayoutCallback _layoutCallback(
    Uint8List bytes,
    PdfRebuilder? rebuild,
  ) {
    return (PdfPageFormat format) async {
      if (rebuild == null) return bytes;
      try {
        return await rebuild(format);
      } catch (e) {
        debugPrint('PrinterService: تعذّرت إعادة توليد نسخة الطباعة — $e');
        return bytes;
      }
    };
  }

  /// الطباعة المباشرة — **محاولتان** لأن لكل تعريف مزاجه في ويندوز.
  ///
  /// ## لماذا محاولتان؟
  /// الحزمة تبني في ويندوز `DEVMODE` مخصّصًا إن كان `usePrinterSettings`
  /// مساويًا `false`، وتتركه `null` (إعدادات التعريف) إن كان `true`.
  /// و`CreateDC` تفشل عند بعض التعريفات مع الـ`DEVMODE` المخصّص — **وأخطر
  /// من ذلك أن الطبقة الأصلية لا تُكمل الـFuture عند فشلها**
  /// (`print_job.cpp:150` ترجع `false` بلا `onCompleted`)، فيتجمّد النداء
  /// بلا حوار ولا ورق ولا خطأ. ولهذا نُسقط مهلة على كل محاولة.
  ///
  /// الترتيب: **إعدادات التعريف أولًا** — لأنها ما تستعمله البرامج الأخرى
  /// التي تطبع بنجاح على نفس الجهاز؛ ثم مقاس المستند صريحًا كبديل.
  Future<bool> _tryDirect(
    Uint8List bytes,
    Printer target,
    String jobName,
    PaperSize? paper,
    PdfRebuilder? rebuild,
  ) async {
    if (await _attempt(bytes, target, jobName, paper, true, rebuild)) {
      return true;
    }
    debugPrint(
      trf('PrinterService: المحاولة 1 (إعدادات التعريف) فشلت — {0}', [
        lastIssue ?? '',
      ]),
    );
    if (await _attempt(bytes, target, jobName, paper, false, rebuild)) {
      return true;
    }
    debugPrint(
      trf('PrinterService: المحاولة 2 (مقاس المستند) فشلت — {0}', [
        lastIssue ?? '',
      ]),
    );

    // فشلت المحاولتان: نُضيف اسم التعريف إلى الرسالة لأنه أول ما يُشتبه به.
    final driver = (target.model ?? '').trim();
    if (driver.isNotEmpty) {
      lastIssue = trf(
        '{0} (تعريف الطابعة: «{1}» — تحقّق أنه يدعم طباعة الرسومات.)',
        [lastIssue ?? tr('تعذّرت الطباعة المباشرة.'), driver],
      );
    }
    return false;
  }

  /// محاولة واحدة. ترجع `true` عند النجاح، وتضبط [lastIssue] عند الفشل.
  Future<bool> _attempt(
    Uint8List bytes,
    Printer target,
    String jobName,
    PaperSize? paper,
    bool usePrinterSettings,
    PdfRebuilder? rebuild,
  ) async {
    try {
      // ⚠️ `directPrintPdf` ترجع **`FutureOr<bool>`** لا `Future<bool>`
      // (تكون متزامنة على بعض المنصّات)، و`FutureOr` لا يملك `.timeout`.
      // فنُغلّفها في `Future<bool>.value` أولًا ثم نُسقط المهلة عليها.
      final Future<bool> pending = Future<bool>.value(
        Printing.directPrintPdf(
          printer: target,
          name: jobName,
          format: formatFor(paper),
          // المستند جاهز ومبنيّ مسبقًا ⇒ لا إعادة تخطيط تلقائي، لكن
          // الطابعة تُبلّغ عن ورقتها الفعلية فنُعيد بناء نسخة الطباعة.
          dynamicLayout: false,
          usePrinterSettings: usePrinterSettings,
          onLayout: _layoutCallback(bytes, rebuild),
        ),
      );
      // ٨ ثوانٍ لكل محاولة: النجاح يعود فورًا بعد الإرسال للـspooler،
      // والانتظار الطويل يعني أن الطبقة الأصلية لم تُكمل الـFuture.
      final done = await pending.timeout(const Duration(seconds: 8));
      if (done) return true;
      lastIssue = tr('لم تُكمل الطابعة المهمة.');
    } on TimeoutException {
      lastIssue = tr('لم تستجب الطابعة خلال ٨ ثوانٍ.');
    } catch (e) {
      debugPrint('PrinterService.directPrintPdf error: $e');
      lastIssue = trf('تعذّر الإرسال المباشر ({0}).', [e]);
    }
    return false;
  }

  /// مقاس PDF من مقاس الورق المختار (نفس حساب `PreparePDF`).
  static PdfPageFormat formatFor(PaperSize? paper) {
    if (paper == null) return PdfPageFormat.standard;
    return PdfPageFormat(
      PaperSizes.mmToPoints(paper.widthMm),
      PaperSizes.mmToPoints(paper.heightMm),
      marginAll:
          paper.isThermal ? PaperSizes.mmToPoints(2) : PdfPageFormat.cm,
    );
  }
}
