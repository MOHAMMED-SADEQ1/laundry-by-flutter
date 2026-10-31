/// **لوحة المفاتيح اللمسية في ويندوز** — إخفاؤها عند مغادرة حقل الإدخال.
///
/// ## المشكلة (بلاغ المستخدم)
/// على جهاز ويندوز يعمل باللمس تظهر لوحة المفاتيح عند التركيز على أي حقل
/// إدخال، **ولا تختفي** عند الانتهاء: تبقى طافية فوق الواجهة فتحجب نصف الشاشة،
/// ويضطر المستخدم إلى إغلاقها من شريط المهام في كل مرّة.
///
/// ## السبب
/// لوحة المفاتيح اللمسية في ويندوز **عملية مستقلة** (`TabTip.exe`، وفي
/// ويندوز ١١ مضيف `TextInputHost`) تُدار من النظام لا من التطبيق. وFlutter
/// يبلّغ محرّكه وحده عند زوال التركيز (`TextInput.hide`)، ولا يملك نافذة
/// النظام تلك ولا يطلب إغلاقها — فتبقى ظاهرة.
///
/// ## الحلّ
/// إغلاقها من الجهة الأصلية عبر قناة `laundry/touch_keyboard` (انظر
/// `windows/runner/flutter_window.cpp`)، ويُطلب ذلك **كلّما زال التركيز عن
/// حقل نصّ**:
///   • تغيّر التركيز (نقرة على زرّ أو خلفية أو إغلاق حوار).
///   • أي لمسة على الشاشة انتهت بلا حقل نصّ في التركيز.
///   • خروج التطبيق من المقدّمة أو من الشاشة.
///
/// ## لماذا لا يُغلق الحقل نفسه؟
/// لأن الإغلاق قرار **الواجهة** لا الحقل: بعض الحقول تفتح حوارًا (تاريخ،
/// منتقي عميل) فيجب ألّا تختفي اللوحة أثناءه. لذلك يُفحص **التركيز الفعلي**
/// بعد استقرار اللمسة، لا مجرّد وقوعها.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

class TouchKeyboard {
  TouchKeyboard._();

  /// اسم القناة — مطابق حرفًا بحرف لِما يُسجَّل في `flutter_window.cpp`.
  static const MethodChannel _channel = MethodChannel('laundry/touch_keyboard');

  /// هل النظام يدعم هذا التحكّم؟ (ويندوز فقط — أندرويد وiOS يتولّاهما النظام)
  static bool get isSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;

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

  /// يطلب من ويندوز إخفاء لوحة المفاتيح اللمسية.
  ///
  /// **لا يرمي أبدًا**: فشل إخفاء لوحة المفاتيح لا يجوز أن يُسقِط تفاعلًا في
  /// الواجهة. وعلى غير ويندوز لا يفعل شيئًا (النظام يتولّى الأمر).
  static Future<void> hide() async {
    if (!isSupported) return;
    try {
      await _channel.invokeMethod<void>('hide');
    } catch (e) {
      debugPrint('touch keyboard hide skipped: $e');
    }
  }
}

/// يلفّ التطبيق كلّه فيراقب التركيز واللمس ويُخفي لوحة المفاتيح عند الحاجة.
///
/// يُوضع في `builder` الخاص بـ`GetMaterialApp` (فوق الـNavigator) كي يشمل
/// **كل** الشاشات والحوارات — ولو وُضع في شاشة واحدة لبقي البلاغ قائمًا في
/// البقية.
class TouchKeyboardDismisser extends StatefulWidget {
  const TouchKeyboardDismisser({super.key, required this.child});

  final Widget child;

  @override
  State<TouchKeyboardDismisser> createState() => _TouchKeyboardDismisserState();
}

class _TouchKeyboardDismisserState extends State<TouchKeyboardDismisser>
    with WidgetsBindingObserver {
  /// يمنع جدولة فحصين لنفس الحدث (التركيز واللمس يقعان معًا في النقرة).
  bool _scheduled = false;

  @override
  void initState() {
    super.initState();
    FocusManager.instance.addListener(_onFocusChanged);
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    FocusManager.instance.removeListener(_onFocusChanged);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _onFocusChanged() => _scheduleCheck();

  /// يفحص **بعد** استقرار الحدث.
  ///
  /// الفحص الفوري خاطئ: أثناء النقرة على حقل آخر لم يُنقل التركيز بعد، فنظنّ
  /// أن لا حقل في التركيز فنُخفي اللوحة عن الحقل الذي يريده المستخدم.
  /// و`scheduleFrame` تضمن تنفيذ الردّ ولو لم يكن هناك إطار معلّق.
  void _scheduleCheck() {
    if (!TouchKeyboard.isSupported || _scheduled) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (!mounted) return;
      if (!TouchKeyboard.hasTextFocus) TouchKeyboard.hide();
    });
    WidgetsBinding.instance.scheduleFrame();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // الخروج من الشاشة أو تصغير النافذة: لا معنى للوحة مفاتيح فوق لا شيء.
    if (state != AppLifecycleState.resumed) TouchKeyboard.hide();
  }

  @override
  Widget build(BuildContext context) {
    // `Listener` لا يستهلك الإيماءة: يمرّرها للأبناء كما هي، ويكتفي بالعلم
    // بها — فالنقرة على خلفية لا تغيّر التركيز في Flutter، وبلا هذا السطر
    // تبقى اللوحة ظاهرة بعد النقر عليها (وهو أصل البلاغ).
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _scheduleCheck(),
      child: widget.child,
    );
  }
}
