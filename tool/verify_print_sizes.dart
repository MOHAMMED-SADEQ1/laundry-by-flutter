// حرس **مقاسات العناصر المطبوعة** + **إخفاء لوحة المفاتيح اللمسية**.
//
// ## ما يمنعه
// (١) مقاس يضبطه المستخدم ولا يُنفَّذ: القيمة تُحفظ ثم تُقصّ في المولّد بلا
//     إعلان — فيظنّ أن شعاره ٨٠ مم وهو يُطبع ٤٨. أو شعار بارتفاع ٢٠٠ مم يدفع
//     أصناف الفاتورة إلى صفحة ثانية بلا سبب مفهوم.
// (٢) لوحة مفاتيح ويندوز اللمسية تبقى ظاهرة بعد مغادرة الحقل: العيب ليس في
//     Flutter وحده بل في **عقد** بين Dart وC++ — لو اختلف اسم القناة حرفًا
//     واحدًا لما أُخفيت أبدًا، ولما اشتكى أحد (الاستدعاء يفشل بصمت).
//
// التشغيل: dart run tool/verify_print_sizes.dart
import 'dart:io';

import 'package:laundry/config/constants.dart';
import 'package:laundry/core/services/paper_size.dart';
import 'package:laundry/services/pdf/print_visual_size.dart';
import 'package:laundry/services/settings/setting_option.dart';

int _ok = 0;
int _fail = 0;

void check(String name, Object? got, Object? expected) {
  final pass = '$got' == '$expected';
  if (pass) {
    _ok++;
    print('  ✓ $name');
  } else {
    _fail++;
    print('  ✗ $name  → got=$got expected=$expected');
  }
}

bool near(double a, double b, [double tol = 0.05]) => (a - b).abs() <= tol;

void checkNear(String name, double got, double expected, [double tol = 0.05]) {
  if (near(got, expected, tol)) {
    _ok++;
    print('  ✓ $name  (${got.toStringAsFixed(2)})');
  } else {
    _fail++;
    print('  ✗ $name  → got=${got.toStringAsFixed(2)} expected=$expected');
  }
}

// يُطبَّع نهاية السطر: ملفّات المشروع مختلطة (LF وCRLF)، وفحصٌ يعتمد
// على `\n` وحده يفشل أو ينجح بحسب محرّر فتح الملف — وهو حرس كاذب.
String _read(String path) =>
    File(path).readAsStringSync().replaceAll('\r\n', '\n');

/// النصّ بلا تعليقات — كي لا يمرّ فحص بسبب جملة في تعليق.
String _code(String path) =>
    _read(path).replaceAll(RegExp(r'//[^\n]*'), '');

void main() {
  print('═' * 68);
  print('حرس مقاسات الطباعة + لوحة المفاتيح اللمسية');
  print('═' * 68);

  // ─── [1] الحساب الخالص ──────────────────────────────────────────────
  print('\n[1] حساب المقاس والمساحة');
  final a4 = PrintVisualSize.pageOf(PaperSizes.a4);
  checkNear('[1] A4: عرض متاح ١٨٧ مم', a4.widthMm, 187);
  checkNear('[1] A4: ارتفاع متاح ٢٧٤ مم', a4.heightMm, 274);
  checkNear('[1] A4: مساحة الورق ٥١٢٣٨ مم²', a4.areaMm2, 51238);

  final square = PrintVisualSize.logo(
    maxWidth: a4.widthPoints,
    maxHeight: a4.heightPoints,
  );
  checkNear('[1] الافتراضي ٥٣ مم عرضًا', square.widthMm, 53);
  checkNear('[1] الافتراضي ٥٣ مم ارتفاعًا', square.heightMm, 53);
  checkNear('[1] مساحته ٢٨٠٩ مم²', square.areaMm2, 2809);
  check('[1] لا تقييد في المقاس الافتراضي', square.clamped, false);

  final rect = PrintVisualSize.logo(
    widthMm: 80,
    heightMm: 30,
    maxWidth: a4.widthPoints,
    maxHeight: a4.heightPoints,
  );
  checkNear('[1] العرض مستقلّ (٨٠)', rect.widthMm, 80);
  checkNear('[1] الارتفاع مستقلّ (٣٠)', rect.heightMm, 30);
  checkNear('[1] المساحة = عرض × ارتفاع', rect.areaMm2, 2400);
  check('[1] الشعار المستطيل لا يُقصّ إلى مربّع', rect.isSquare, false);

  // ─── [2] التقييد على الورق ──────────────────────────────────────────
  print('\n[2] التقييد والإعلان');
  final wide = PrintVisualSize.logo(
    widthMm: 120,
    heightMm: 60,
    maxWidth: 137,
    maxHeight: 700,
  );
  checkNear('[2] العرض يُقصّ على عرض الورق', wide.width, 137);
  check('[2] ويُعلَن أنه قُصّ', wide.widthClamped, true);

  final tall = PrintVisualSize.logo(
    widthMm: 60,
    heightMm: 120,
    maxWidth: 500,
    maxHeight: 700,
  );
  checkNear(
    '[2] الارتفاع يُقيَّد بسقف ٣٥٪ من الصفحة',
    tall.height,
    700 * PrintVisualSize.logoMaxHeightShare,
  );
  check('[2] ويُعلَن تقييد الارتفاع', tall.heightClamped, true);

  final tiny = PrintVisualSize.logo(
    widthMm: 0,
    heightMm: 0,
    maxWidth: 500,
    maxHeight: 700,
  );
  checkNear('[2] الصفر يُرفع إلى الحدّ الأدنى ٥ مم', tiny.widthMm, 5);

  final broken = PrintVisualSize.logo(
    widthMm: 'غير رقم',
    heightMm: null,
    maxWidth: 500,
    maxHeight: 700,
  );
  checkNear('[2] القيمة الفاسدة تسقط للافتراضي', broken.widthMm, 53);
  check('[2] ولا ترمي', broken.clamped, false);

  final degenerate = PrintVisualSize.logo(
    widthMm: 53,
    heightMm: 53,
    maxWidth: 0,
    maxHeight: 0,
  );
  check('[2] ورقة بعرض صفر لا تُنتج صفرًا', degenerate.width > 0, true);

  // ─── [3] رمز QR ─────────────────────────────────────────────────────
  print('\n[3] رمز QR');
  final qr = PrintVisualSize.qr(sizeMm: 30, maxWidth: 538, maxHeight: 793);
  checkNear('[3] ٣٠ مم ⇒ ٨٥ نقطة', qr.width, 85.04, 0.02);
  check('[3] مربّع دائمًا', qr.isSquare, true);
  check('[3] ٣٠ مم لا يُقصّ على A4', qr.clamped, false);

  final qrNarrow = PrintVisualSize.qr(
    sizeMm: 70,
    maxWidth: 137,
    maxHeight: 793,
  );
  checkNear('[3] على الحراري يُقصّ على العرض', qrNarrow.width, 137);
  check('[3] ويبقى مربّعًا بعد القصّ', qrNarrow.isSquare, true);
  check('[3] ويُعلَن التقييد', qrNarrow.clamped, true);

  // ─── [4] النسبة والتنبيه ────────────────────────────────────────────
  print('\n[4] نسبة المساحة والتنبيه');
  final share = PrintVisualSize.shareOfPage(square, a4);
  checkNear('[4] الشعار الافتراضي ≈ ٥٫٥٪ من الورق', share * 100, 5.48, 0.05);

  final budget = PrintVisualSize.verticalBudget(square, qr, a4);
  check(
    '[4] مجموع الارتفاع أقلّ من حدّ التنبيه',
    budget < PrintVisualSize.verticalBudgetWarn,
    true,
  );

  final hugeLogo = PrintVisualSize.logo(
    widthMm: 120,
    heightMm: 120,
    maxWidth: a4.widthPoints,
    maxHeight: a4.heightPoints,
  );
  final hugeQr = PrintVisualSize.qr(
    sizeMm: 70,
    maxWidth: a4.widthPoints,
    maxHeight: a4.heightPoints,
  );
  check(
    '[4] الشعار الكبير + الرمز الكبير يتجاوزان الحدّ فيُنبَّه',
    PrintVisualSize.verticalBudget(hugeLogo, hugeQr, a4) >
        PrintVisualSize.verticalBudgetWarn,
    true,
  );

  // ─── [5] السجلّ: ثلاثة مفاتيح لا واحد ───────────────────────────────
  print('\n[5] خيارات الإعداد');
  check(
    '[5] عرض الشعار مسجَّل',
    SettingOptions.byKey(AppConstants.settingInvoiceLogoWidth)?.isInteger,
    true,
  );
  check(
    '[5] ارتفاع الشعار مسجَّل',
    SettingOptions.byKey(AppConstants.settingInvoiceLogoHeight)?.isInteger,
    true,
  );
  check(
    '[5] مقاس الرمز مسجَّل',
    SettingOptions.byKey(AppConstants.settingMapQrSize)?.isInteger,
    true,
  );
  check(
    '[5] المفتاح القديم لم يبقَ خيارًا معروضًا',
    SettingOptions.byKey(AppConstants.settingInvoiceLogoSize),
    null,
  );
  check(
    '[5] الافتراضي ٥٣×٥٣ يحفظ شكل الفواتير القائمة',
    SettingOptions.invoiceLogoWidth.defaultValue == '53' &&
        SettingOptions.invoiceLogoHeight.defaultValue == '53',
    true,
  );

  // ─── [6] المولّد يقرأها ويرسمها ─────────────────────────────────────
  print('\n[6] المولّد');
  final pdf = _code('lib/core/services/preparePDF.dart');
  check('[6] يستورد منطق المقاس', pdf.contains('print_visual_size.dart'), true);
  check(
    '[6] يقرأ العرض والارتفاع من الحمولة',
    pdf.contains("data['logoWidthMm']") &&
        pdf.contains("data['logoHeightMm']"),
    true,
  );
  check(
    '[6] يقرأ مقاس الرمز من الحمولة',
    pdf.contains("data['mapQrSizeMm']"),
    true,
  );
  check(
    '[6] يرسم الشعار بعرضين لا بُعد واحد',
    pdf.contains('width: logoBox.width') &&
        pdf.contains('height: logoBox.height'),
    true,
  );
  check(
    '[6] لا مقاس ثابت في الكود',
    pdf.contains('width: 150, height: 150'),
    false,
  );
  check(
    '[6] الحمولة القديمة تُقرأ بديلًا (إعادة طباعة قديمة)',
    pdf.contains("legacyMm: data['logoSizeMm']"),
    true,
  );

  // ─── [7] كل مسارات الإخراج تمرّرها ─────────────────────────────────
  print('\n[7] مسارات الإخراج');
  for (final entry in <String, String>{
    'البيع': 'lib/controller/printInvoicecontroller.dart',
    'إعادة الطباعة': 'lib/controller/previousinvoicecontroller.dart',
    'المشاركة': 'lib/core/services/invoice_share_service.dart',
  }.entries) {
    final src = _code(entry.value);
    check(
      '[7] ${entry.key}: العرض والارتفاع ومقاس الرمز',
      src.contains('logoWidthMm') &&
          src.contains('logoHeightMm') &&
          src.contains('mapQrSizeMm'),
      true,
    );
  }

  // ─── [8] ترحيل المقاس القديم ────────────────────────────────────────
  print('\n[8] الترحيل');
  final db = _code('lib/sqldb.dart');
  check('[8] دالة الترحيل موجودة', db.contains('_migrateLogoSizeToBox'), true);
  check(
    '[8] تقرأ المفتاح القديم',
    db.contains('AppConstants.settingInvoiceLogoSize'),
    true,
  );
  check('[8] تُعلَّم مرة واحدة', db.contains('logo_size_box_v1'), true);
  final migrateAt = db.indexOf('await _migrateLogoSizeToBox(mydb);');
  final seedAt = db.indexOf('await _ensureDefaultSettings();');
  check(
    '[8] تعمل قبل زرع الافتراضيات (وإلا لا يمكن التمييز)',
    migrateAt > 0 && seedAt > 0 && migrateAt < seedAt,
    true,
  );

  // ─── [9] تحكّم واحد لا اثنان ────────────────────────────────────────
  print('\n[9] الواجهة');
  final ui = _read('lib/view/screen/settings/settings_sections.dart');
  check('[9] بطاقة المقاسات موجودة', ui.contains('Widget printSizesCard('), true);
  check(
    '[9] تُظهر المساحة والنسبة',
    ui.contains('_areaText(') && ui.contains('_pctText('),
    true,
  );
  check(
    '[9] تُعلن القصّ بدل أن تُخفي الرقم',
    ui.contains('logoBox.clamped') && ui.contains('qrBox.clamped'),
    true,
  );
  check(
    '[9] المفاتيح الثلاثة مستثناة من القائمة العامة (لا تحكّمين)',
    ui.contains('o.key != AppConstants.settingInvoiceLogoWidth') &&
        ui.contains('o.key != AppConstants.settingInvoiceLogoHeight') &&
        ui.contains('o.key != AppConstants.settingMapQrSize'),
    true,
  );
  final pages = _read('lib/view/screen/settings/settings_pages.dart');
  check(
    '[9] البطاقة في صفحتي الفواتير والطباعة',
    'printSizesCard(c)'.allMatches(pages).length == 2,
    true,
  );

  // ─── [10] لوحة المفاتيح: عقد Dart ⇄ C++ ─────────────────────────────
  //
  // 🚨 يحرس **سببَي تجميد ويندوز** (بلاغا 2026-11-04 و 2026-11-07):
  //   (أ) `ShowWindow` متزامن على نافذة عملية أخرى من داخل معالج الرسائل.
  //   (ب) إخفاء نافذة **مضيف الإدخال اللمسي** في ويندوز ١١ — وهو مكوّن نظام
  //       مشترك؛ إخفاؤه يُربك خطّ اللمس في النظام كلّه ويُجمّده بعد الإغلاق.
  print('\n[10] لوحة المفاتيح اللمسية');
  final dartKb = _read('lib/core/platform/touch_keyboard.dart');
  final cpp = _read('windows/runner/flutter_window.cpp');
  // نفحص **الكود** لا التعليقات: الشرح يذكر أسماء النوافذ الممنوعة نصًّا
  // ليُعلّم القارئ سبب المنع.
  final cppCode = _code('windows/runner/flutter_window.cpp');

  const channel = 'laundry/touch_keyboard';
  check('[10] القناة في Dart', dartKb.contains("'$channel'"), true);
  check('[10] القناة نفسها في C++', cpp.contains('"$channel"'), true);

  // ── (ب) الأخطر: لا نلمس مضيف الإدخال اللمسي إطلاقًا ──
  check(
    '[10] لا لمس لمضيف الإدخال اللمسي (Windows.UI.Core.CoreWindow)',
    !cppCode.contains('Windows.UI.Core.CoreWindow') &&
        !cppCode.contains('Microsoft Text Input Application'),
    true,
  );
  check(
    '[10] لا إطلاق عملية TabTip (تراكم عمليات)',
    !cppCode.contains('ShellExecuteW') && !cppCode.contains('TabTip.exe'),
    true,
  );

  // ── (أ) لا استدعاء حاجب ──
  check(
    '[10] لا ShowWindow متزامن (بل ShowWindowAsync)',
    cppCode.contains('::ShowWindowAsync(') &&
        !cppCode.contains('::ShowWindow('),
    true,
  );
  check(
    '[10] الإخفاء من WM_ACTIVATE مؤجَّل بـPostMessage لا مباشر',
    cpp.contains('RegisterWindowMessageW') &&
        cpp.contains('::PostMessageW(hwnd, GetHideTouchKeyboardMessage()'),
    true,
  );
  check(
    '[10] TabTip: إخفاء بـSW_HIDE لا إغلاق بـSC_CLOSE',
    cpp.contains('IPTip_Main_Window') &&
        cpp.contains('SW_HIDE') &&
        !cpp.contains('WM_SYSCOMMAND, SC_CLOSE'),
    true,
  );
  check(
    '[10] القناة تستقبل show و hide',
    cpp.contains('"show"') && cpp.contains('"hide"'),
    true,
  );
  check(
    '[10] الإخفاء عند خروج التطبيق من المقدّمة',
    cpp.contains('WM_ACTIVATE') && cpp.contains('WA_INACTIVE'),
    true,
  );
  check(
    '[10] لا يُقتل الإدخال: لا TerminateProcess',
    cpp.contains('TerminateProcess'),
    false,
  );
  check(
    '[10] مراقب التعليق يسجّل حجب خيط الواجهة',
    cpp.contains('StartHangWatchdog') && cpp.contains('SMTO_ABORTIFHUNG'),
    true,
  );

  // ── معركة التركيز في النافذة الأصلية ──
  final win32 = _read('windows/runner/win32_window.cpp');
  check(
    '[10] لا SetFocus عند WA_INACTIVE (معركة تركيز)',
    win32.contains('LOWORD(wparam) != WA_INACTIVE'),
    true,
  );

  // ── وضع الأمان (رسم برمجي) ──
  final runnerMain = _read('windows/runner/main.cpp');
  check(
    '[10] وضع الأمان متاح (safe_mode.txt ⇒ رسم برمجي)',
    runnerMain.contains('EnableSafeModeIfRequested') &&
        runnerMain.contains('enable-software-rendering'),
    true,
  );

  final main = _read('lib/main.dart');
  check('[10] المراقب يلفّ التطبيق كلّه',
      main.contains('TouchKeyboardDismisser('), true);
  check(
    '[10] يُخفي عند مغادرة الحقل (انتقال من حقل إلى لا-حقل)',
    dartKb.contains('TouchKeyboard.hide()') && dartKb.contains('_wasTextFocus'),
    true,
  );
  check(
    '[10] يُظهر عند دخول الحقل (انتقال من لا-حقل إلى حقل)',
    dartKb.contains('TouchKeyboard.show()'),
    true,
  );
  check(
    '[10] لا طلب إطار لكل لمسة (كان يستنزف GPU)',
    !dartKb.contains('WidgetsBinding.instance.scheduleFrame') &&
        !dartKb.contains('WidgetsBinding.instance.addPostFrameCallback'),
    true,
  );
  check(
    '[10] debounce يجمّع أحداث النقرة الواحدة',
    dartKb.contains('Timer(') && dartKb.contains('_debounce'),
    true,
  );
  check(
    '[10] إعداد touch_keyboard_control بثلاثة أوضاع',
    dartKb.contains('TouchKeyboardMode') &&
        dartKb.contains("'hide_only'") &&
        dartKb.contains("'off'"),
    true,
  );
  check(
    '[10] «معطَّل» يمنع النداء قبل وصوله للقناة',
    dartKb.contains('if (mode == TouchKeyboardMode.off) return;'),
    true,
  );
  check(
    '[10] يفحص عند انتهاء اللمسة لا بدايتها',
    dartKb.contains('onPointerUp:') && !dartKb.contains('onPointerDown:'),
    true,
  );
  check(
    '[10] ويندوز فقط — لا تعطيل للأندرويد',
    dartKb.contains('TargetPlatform.windows') &&
        !dartKb.contains('Platform.isWindows'),
    true,
  );
  check('[10] لا يرمي عند غياب القناة', dartKb.contains('catch (e)'), true);


  print('\n' + '═' * 68);
  print(_fail == 0 ? '✓ كل الفحوص ناجحة ($_ok)' : '✗ فشل $_fail من ${_ok + _fail}');
  print('═' * 68);
  if (_fail != 0) exitCode = 1;
}
