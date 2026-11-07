/// **لوحة المفاتيح اللمسية في ويندوز** — إظهارها وإخفاؤها مع دورة حياة الحقل.
///
/// ════════════════════════════════════════════════════════════════════
///  ⚠️ اقرأ هذا قبل أي تعديل: العيب كان يُجمّد ويندوز كاملًا
/// ════════════════════════════════════════════════════════════════════
///
/// ## البلاغ (2026-11-07)
/// على جهاز كاشير بشاشة لمس: الكيبورد لا تظهر · الجهاز يتعلّق · ويندوز
/// يتجمّد كاملًا حتى تُعاد التهيئة.
///
/// ## السبب الجذري (ليس في هذا الملف وحده)
/// الطبقة الأصلية (`windows/runner/flutter_window.cpp`) كانت تستدعي
/// `ShowWindow()` على نافذة تملكها **عملية أخرى** من داخل معالج الرسائل —
/// وهو استدعاء **متزامن ينتظر**، فيحجب خيط واجهة Flutter ويُجمّد حزمة الإدخال
/// اللمسي في النظام. الإصلاح هناك: `ShowWindowAsync` + `PostMessage` + خيط
/// عامل. **لا تُعِد `ShowWindow` المتزامن ولا `ShellExecuteW` على خيط الواجهة.**
///
/// ## ما يفعله هذا الملف (ولماذا)
///   • **لا طلب إطار** (`scheduleFrame`) ولا `addPostFrameCallback` لكل لمسة.
///     كان ذلك يُجبر إعادة رسم متواصلة ⇒ استنزاف GPU ⇒ خطر TDR.
///   • **debounce 200ms**: النقرة الواحدة تُولّد تغيّر تركيز ولمسة معًا،
///     فلا نُرسل أمرين للطبقة الأصلية على نفس الحدث.
///   • **قرار الانتقال لا الحالة**: نُظهر عند الانتقال «لا حقل ← حقل»،
///     ونُخفي عند «حقل ← لا حقل». إعادة الإرسال على نفس الحالة تُرهق النظام
///     بلا فائدة (الطبقة الأصلية فيها debounce 300ms أيضًا، دفاعًا مزدوجًا).
///   • **إعداد `touch_keyboard_control`**: ثلاثة أوضاع ليتمكّن المشغّل من
///     تعطيل التحكّم كليًّا على جهاز مشاكس بلا إعادة بناء.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:laundry/services/settings/app_settings_service.dart';

/// وضع التحكّم في لوحة المفاتيح اللمسية — يُقرأ من الإعدادات.
enum TouchKeyboardMode {
  /// إظهار عند دخول الحقل وإخفاء عند مغادرته (الافتراضي).
  auto,

  /// إخفاء فقط — الإظهار متروك لويندوز (بعض الأجهزة تُظهرها بنفسها).
  hideOnly,

  /// معطَّل — لا يتدخّل التطبيق إطلاقًا.
  off;

  /// يحوّل قيمة الإعداد المخزَّنة إلى وضع. أي قيمة غير معروفة ⇒ [auto]
  /// (الفشل إلى السلوك الافتراضي لا إلى التعطيل).
  static TouchKeyboardMode fromKey(String? key) {
    switch (key) {
      case 'hide_only':
        return TouchKeyboardMode.hideOnly;
      case 'off':
        return TouchKeyboardMode.off;
      default:
        return TouchKeyboardMode.auto;
    }
  }
}

class TouchKeyboard {
  TouchKeyboard._();

  /// اسم القناة — مطابق حرفًا بحرف لِما يُسجَّل في `flutter_window.cpp`.
  static const MethodChannel _channel = MethodChannel('laundry/touch_keyboard');

  /// هل النظام يدعم هذا التحكّم؟ (ويندوز فقط — أندرويد وiOS يتولّاهما النظام)
  static bool get isSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;

  /// الوضع الحالي من الإعدادات.
  static TouchKeyboardMode get mode => TouchKeyboardMode.fromKey(
    AppSettingsService.instance.touchKeyboardControl,
  );

  /// هل التركيز الحالي على حقل نصّ؟
  ///
  /// نفحص **الأسلاف** لا الودجة نفسها: عقدة التركيز التي تُرفَق فعليًّا هي
  /// `Focus` **داخل** `EditableText`، فمقارنة `context.widget is EditableText`
  /// وحدها تفشل دائمًا. الصعود في الشجرة يجد `EditableText` في كل الحالات
  /// (`TextField` · `TextFormField` · حقول مخصّصة مبنية عليه).
  static bool get hasTextFocus {
    final context = FocusManager.instance.primaryFocus?.context;
    if (context == null) return false;
    if (context.widget is EditableText) return true;
    var found = false;
    context.visitAncestorElements((element) {
      if (element.widget is EditableText) {
        found = true;
        return false; // توقّف: وجدناه
      }
      return true;
    });
    return found;
  }

  /// يطلب من ويندوز **إظهار** لوحة المفاتيح اللمسية.
  ///
  /// **لا يرمي أبدًا**: فشل الإظهار لا يُسقِط تفاعلًا.
  static Future<void> show() async {
    if (!isSupported) return;
    if (mode == TouchKeyboardMode.off) return;
    try {
      await _channel.invokeMethod<void>('show');
    } catch (e) {
      debugPrint('touch keyboard show skipped: $e');
    }
  }

  /// يطلب من ويندوز **إخفاء** لوحة المفاتيح اللمسية.
  ///
  /// **لا يرمي أبدًا**: فشل الإخفاء لا يجوز أن يُسقِط تفاعلًا.
  static Future<void> hide() async {
    if (!isSupported) return;
    if (mode == TouchKeyboardMode.off) return;
    try {
      await _channel.invokeMethod<void>('hide');
    } catch (e) {
      debugPrint('touch keyboard hide skipped: $e');
    }
  }
}

/// يلفّ التطبيق كلّه فيراقب التركيز ويُظهر/يُخفي لوحة المفاتيح عند الحاجة.
///
/// يُوضع في `builder` الخاص بـ`GetMaterialApp` (فوق الـNavigator) كي يشمل
/// **كل** الشاشات والحوارات.
class TouchKeyboardDismisser extends StatefulWidget {
  const TouchKeyboardDismisser({super.key, required this.child});

  final Widget child;

  @override
  State<TouchKeyboardDismisser> createState() => _TouchKeyboardDismisserState();
}

class _TouchKeyboardDismisserState extends State<TouchKeyboardDismisser>
    with WidgetsBindingObserver {
  /// يجمّع الأحداث المتلاحقة (تغيّر تركيز + لمسة) في قرار واحد.
  Timer? _debounce;

  /// آخر حالة تركيز **طُبِّقت** — نقارن بها لنُرسل الانتقال وحده.
  bool _wasTextFocus = false;

  /// فاصل التجميع. 200ms أقل من إحساس المستخدم بالبطء وأكبر من الفجوة
  /// بين تغيّر التركيز ولمسة الرفع في النقرة الواحدة.
  static const Duration _settle = Duration(milliseconds: 200);

  @override
  void initState() {
    super.initState();
    FocusManager.instance.addListener(_onFocusChanged);
    WidgetsBinding.instance.addObserver(this);
    // الحالة الابتدائية: قد تُفتح شاشة وفيها حقل في التركيز.
    _wasTextFocus = TouchKeyboard.hasTextFocus;
  }

  @override
  void dispose() {
    _debounce?.cancel();
    FocusManager.instance.removeListener(_onFocusChanged);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _onFocusChanged() => _schedule();

  /// يُجمّع ثم يُطبّق بعد استقرار الحدث.
  ///
  /// ⚠️ **لا `scheduleFrame` ولا `addPostFrameCallback`**: كلاهما كان يفرض
  /// إطارًا إضافيًا لكل لمسة، فيُعيد رسم الواجهة بلا تغيير ⇒ استنزاف GPU.
  /// `Timer` لا يرسم شيئًا.
  void _schedule() {
    if (!TouchKeyboard.isSupported) return;
    _debounce?.cancel();
    _debounce = Timer(_settle, _apply);
  }

  /// يطبّق **الانتقال** فقط: لا يرسل أمرًا إن لم تتغيّر الحالة.
  void _apply() {
    if (!mounted || !TouchKeyboard.isSupported) return;

    final mode = TouchKeyboard.mode;
    if (mode == TouchKeyboardMode.off) {
      _wasTextFocus = TouchKeyboard.hasTextFocus;
      return;
    }

    final hasFocus = TouchKeyboard.hasTextFocus;
    if (hasFocus == _wasTextFocus) return; // لا انتقال ⇒ لا أمر
    _wasTextFocus = hasFocus;

    if (hasFocus) {
      // «إخفاء فقط»: الإظهار متروك لويندوز.
      if (mode == TouchKeyboardMode.auto) TouchKeyboard.show();
    } else {
      TouchKeyboard.hide();
    }
  }

  /// لمسة على منطقة بلا حقل نصّ.
  ///
  /// **ليس مصدر الطوفان**: نفحص قيمة منطقية واحدة فقط ولا نطلب إطارًا.
  /// ولازم — فالنقرة على خلفية أو زرّ لا تُزيل التركيز في Flutter، وبلا هذا
  /// تبقى اللوحة ظاهرة بعدها (وهو أصل البلاغ الأصلي).
  void _onPointerSettled() {
    if (!TouchKeyboard.isSupported) return;
    if (TouchKeyboard.hasTextFocus) return; // حقل ما زال في التركيز
    _schedule();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // الخروج من الشاشة أو تصغير النافذة: لا معنى للوحة مفاتيح فوق لا شيء.
    if (state != AppLifecycleState.resumed) {
      _debounce?.cancel();
      _wasTextFocus = false;
      TouchKeyboard.hide();
    }
  }

  @override
  Widget build(BuildContext context) {
    // `Listener` لا يستهلك الإيماءة: يمرّرها للأبناء كما هي.
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerUp: (_) => _onPointerSettled(),
      child: widget.child,
    );
  }
}
