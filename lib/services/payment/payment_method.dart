// طرق الدفع — **منطق خالص** (بلا Flutter ولا قاعدة بيانات).
//
// ── لماذا وُجد هذا الملف؟ ────────────────────────────────────────────────
// كانت طرق الدفع تُخزَّن في القاعدة **نصًّا عربيًّا** (`'كاش'` · `'شبكة'` ·
// `'آجل'` · `'رصيد'` · `'استرداد نقدي'`) في 4 جداول و101 موضعًا في الكود.
// هذا يجعل اللغة **جزءًا من البيانات**: تبديل الواجهة إلى الإنجليزية يُبقي
// «كاش» مطبوعة في الفاتورة والتقارير، وأي تغيير في صياغة التسمية يُفسد كل
// صفّ قديم (لا `WHERE payment_method='كاش'` يجد شيئًا بعدها).
//
// الحل: **مفتاح ثابت لا يتغيّر أبدًا** يُخزَّن، و**تسمية** تُعرض بلغة الواجهة.
//   تخزين  ⇒ `cash` | `card` | `credit` | `balance` | `cash_refund`
//   عرض    ⇒ `PaymentMethods.label('cash')` ⇒ «كاش» أو «Cash»
//
// ── عقد الرجوع للخلف ─────────────────────────────────────────────────────
// [tryParse] يقبل **المفتاح والعربي معًا**، فقاعدة لم تُرحَّل بعد (أو نسخة
// احتياطية قديمة استُعيدت) تُقرأ صحيحة ولا تظهر شاشة فارغة. والترحيل في
// `sqldb.dart` يكتب المفاتيح، لكن **القراءة لا تعتمد عليه**.

import 'package:laundry/services/i18n/l10n.dart';
import 'package:laundry/services/i18n/translations_en.dart';

/// طريقة دفع واحدة: مفتاح ثابت للتخزين + تسمية عربية للعرض.
enum PaymentMethod {
  /// نقدًا — الافتراضي في التخزين ومعظم الشاشات، أما حوار الدفع في نقطة البيع
  /// فيبدأ على «شبكة» حسب إعداد `pos_default_payment_method`.
  cash('cash', 'كاش'),

  /// شبكة / مدى.
  card('card', 'شبكة'),

  /// آجل — دين على الزبون، يتطلب عميلًا محددًا.
  credit('credit', 'آجل'),

  /// من رصيد الزبون الدائن (سلفة) — **تسوية دفاتر لا نقدية**.
  balance('balance', 'رصيد'),

  /// خصم من تغطية اشتراك شهري — **ليست نقدية**.
  subscription('subscription', 'اشتراك شهري'),

  /// استرداد نقدي لاشتراك ملغى — نقدية خارجة.
  cashRefund('cash_refund', 'استرداد نقدي');

  const PaymentMethod(this.key, this.arabicLabel);

  /// ما يُخزَّن في القاعدة. **لا يُترجَم ولا يتغيّر** — تغييره يكسر كل صفّ.
  final String key;

  /// التسمية العربية — مفتاح في قاموس `kEnglish` أيضًا.
  final String arabicLabel;

  /// التسمية بلغة الواجهة الحالية.
  String get label => tr(arabicLabel);
}

class PaymentMethods {
  PaymentMethods._();

  /// الافتراضي حين لا تُمرَّر طريقة (يطابق `DEFAULT 'cash'` في المخطط).
  static const PaymentMethod defaultMethod = PaymentMethod.cash;

  /// كل الطرق المعروفة.
  static const List<PaymentMethod> all = <PaymentMethod>[
    PaymentMethod.cash,
    PaymentMethod.card,
    PaymentMethod.credit,
    PaymentMethod.balance,
    PaymentMethod.subscription,
    PaymentMethod.cashRefund,
  ];

  /// الطرق المعروضة في **شاشة البيع** — لا تشمل `balance` (تسوية) ولا
  /// `cashRefund` (أثر استرداد يُكتب تلقائيًّا).
  static const List<PaymentMethod> saleChoices = <PaymentMethod>[
    PaymentMethod.cash,
    PaymentMethod.card,
    PaymentMethod.credit,
  ];

  /// مفاتيح التخزين بالترتيب.
  static List<String> get keys =>
      all.map((m) => m.key).toList(growable: false);

  /// مفاتيح شاشة البيع.
  static List<String> get saleKeys =>
      saleChoices.map((m) => m.key).toList(growable: false);

  /// المرادفات المقبولة عند القراءة — المفتاح **والعربي** ومرادفات إنجليزية.
  ///
  /// المفاتيح كلها بحروف صغيرة، والبحث بعد `trim().toLowerCase()`، فـ`'Cash'`
  /// و`' CASH '` تُقرأ صحيحة.
  static const Map<String, PaymentMethod> _aliases = <String, PaymentMethod>{
    // المفاتيح
    'cash': PaymentMethod.cash,
    'card': PaymentMethod.card,
    'credit': PaymentMethod.credit,
    'balance': PaymentMethod.balance,
    'subscription': PaymentMethod.subscription,
    'cash_refund': PaymentMethod.cashRefund,
    // العربية (القواعد القديمة)
    'كاش': PaymentMethod.cash,
    'شبكة': PaymentMethod.card,
    'آجل': PaymentMethod.credit,
    'رصيد': PaymentMethod.balance,
    'اشتراك': PaymentMethod.subscription,
    'اشتراك شهري': PaymentMethod.subscription,
    'استرداد نقدي': PaymentMethod.cashRefund,
    // مرادفات إنجليزية شائعة (استيراد/تكامل خارجي)
    'network': PaymentMethod.card,
    'mada': PaymentMethod.card,
    'deferred': PaymentMethod.credit,
    'credit_refund': PaymentMethod.cashRefund,
  };

  /// يحلّ قيمة مخزَّنة إلى طريقة، أو `null` إن كانت مجهولة.
  ///
  /// **لا يرمي أبدًا** — قيمة غريبة (فارغة أو نصّ حرّ) تُعيد `null` فيقرّر
  /// المنادي: [keyOf] يعطي الافتراضي، و[isCash] يعطي `false`.
  static PaymentMethod? tryParse(String? raw) {
    if (raw == null) return null;
    final text = raw.trim();
    if (text.isEmpty) return null;
    return _aliases[text] ?? _aliases[text.toLowerCase()];
  }

  /// مفتاح التخزين لأي قيمة مقروءة — مع سقوط آمن.
  static String keyOf(String? raw, {String fallback = 'cash'}) =>
      tryParse(raw)?.key ?? fallback;

  /// التسمية بلغة الواجهة لأي قيمة مقروءة.
  ///
  /// القيمة المجهولة تُعاد **كما هي** (لا تُبتلع) كي يراها المطوّر في الشاشة
  /// بدل أن تختفي خلف «كاش» مضلِّلة.
  static String label(String? raw) {
    final method = tryParse(raw);
    if (method != null) return method.label;
    final text = raw?.trim() ?? '';
    return text.isEmpty ? defaultMethod.label : text;
  }

  /// التسمية العربية بلا ترجمة — للطباعة في PDF عربي والتقارير المُصدَّرة.
  static String arabicLabel(String? raw) =>
      tryParse(raw)?.arabicLabel ?? (raw?.trim() ?? '');

  /// التسمية بلغة **صريحة** بلا حالة عامة.
  ///
  /// تُستعمل داخل `compute` (عزل لا يرى `L10n`) وفي أي مستند لغته محدَّدة
  /// بإعداد مستقلّ عن لغة الواجهة. [tr] كان يقرأ الحالة العامة فيعطي العربية
  /// دائمًا داخل العزل — وهذا سبب طباعة «كاش» في فاتورة إنجليزية.
  static String labelIn(String? raw, {required bool english}) {
    final method = tryParse(raw);
    if (method == null) {
      final text = raw?.trim() ?? '';
      if (text.isNotEmpty) return text;
      return english ? _englishOf(defaultMethod) : defaultMethod.arabicLabel;
    }
    return english ? _englishOf(method) : method.arabicLabel;
  }

  static String _englishOf(PaymentMethod method) =>
      kEnglish[method.arabicLabel] ?? method.arabicLabel;

  /// هل القيمة نقدية؟
  static bool isCash(String? raw) => tryParse(raw) == PaymentMethod.cash;

  /// هل القيمة آجلة (دين)؟
  static bool isCredit(String? raw) => tryParse(raw) == PaymentMethod.credit;

  /// هل القيمة **ليست** نقدية؟ (شبكة أو آجل أو رصيد أو استرداد)
  static bool isNotCash(String? raw) => !isCash(raw);

  /// القيم العربية القديمة التي يجب أن تختفي من التخزين بعد الترحيل.
  static const List<String> legacyValues = <String>[
    'كاش',
    'شبكة',
    'آجل',
    'رصيد',
    'اشتراك',
    'اشتراك شهري',
    'استرداد نقدي',
  ];
}
