// اتجاه الواجهة — جسر واحد بين اللغة والاتجاه.
//
// ── لماذا ملف مستقلّ؟ ────────────────────────────────────────────────────
// `L10n` منطق **خالص** (يُشغَّل بـ`dart run` في الحرّاس) فلا يجوز أن يستورد
// Flutter. لكن `TextDirection` نوع من `dart:ui`. فنضع الجسر هنا: هذا الملف
// وحده يعرف أن العربية RTL والإنجليزية LTR، وكل الواجهة تقرأ منه.
//
// ── العيب الذي يمنعه ────────────────────────────────────────────────────
// كان `textDirection: appTextDirection` مكتوبًا **حرفيًّا** في 44 موضعًا.
// النتيجة: واجهة إنجليزية تبقى من اليمين لليسار، فتُقرأ الجملة من آخرها
// وتُصفّ الأيقونات معكوسة. الكتابة الحرفية تجعل الاتجاه **قرارًا مكتوبًا**
// لا نتيجةً للغة، وهو خطأ لا يظهر إلا بعد التبديل.
//
// القاعدة: لا يُكتب `appTextDirection` في أي ملف واجهة — يُقرأ من هنا.

import 'package:flutter/widgets.dart';
import 'package:laundry/services/i18n/l10n.dart';

/// اتجاه الواجهة الحالي: RTL للعربية، LTR للإنجليزية.
TextDirection get appTextDirection =>
    L10n.isRtl ? TextDirection.rtl : TextDirection.ltr;

/// محاذاة «بداية السطر» حسب الاتجاه — بدل `TextAlign.right` الحرفية.
///
/// `TextAlign.start` تعمل تلقائيًّا مع `Directionality`، لكن بعض المواضع
/// تحتاج محاذاة صريحة (خلايا جداول PDF، نصوص داخل `Row` بلا اتجاه).
TextAlign get appTextAlignStart =>
    L10n.isRtl ? TextAlign.right : TextAlign.left;

/// محاذاة «نهاية السطر» حسب الاتجاه.
TextAlign get appTextAlignEnd =>
    L10n.isRtl ? TextAlign.left : TextAlign.right;

/// اتجاه أفقي للنصوص التي تُبنى خارج شجرة الودجات (رسائل واتساب/مشاركة).
///
/// تُستخدم مع `BidiFormatter` أو عند بناء نصّ متعدّد الأسطر يدويًّا.
bool get appIsRtl => L10n.isRtl;
