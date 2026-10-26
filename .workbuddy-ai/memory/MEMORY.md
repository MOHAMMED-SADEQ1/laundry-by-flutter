# `laundry` — فهرس الذاكرة (اقرأ `ARCHITECTURE.md` قبل أي تعديل جوهري)

> أُعيد بناء هذا الملف 2026-10-24 بعد أن صفّره انقطاع الكهرباء (كان 12,989 بايت كلها `\0`).
> المصدر الحيّ: `ARCHITECTURE.md` (32KB) + اليوميات اليومية. لا تُكرّر التفاصيل هنا — أضِفها هناك.

## المشروع
Flutter POS مغاسل (عربي/RTL، offline، sqflite/GetX، ~59k سطر/161 ملف).
`sqldb.dart` (قاعدة+ترحيلات+audit) · `main.dart` · `config/constants.dart` · `services/` · `controller/` · `view/`.
التحقق: `flutter analyze lib/` + `tool/verify_*.dart` (`dart run`) + `tool/verify_*.py` (SQLite حقيقي) + `flutter test --concurrency=1`.

## قواعد لا تُخالَف
- **GetX فقط**؛ كل SQL عبر `SqlDB` بمعاملات `?` — ممنوع دمج القيم ولا `rawQuery`.
- جدول/عمود جديد ⇒ أضفه للمواضع **الثلاثة** (`_onCreate` · `_onUpgrade` · `runPendingMigrations`). الفشل صامت.
- `intl` يصدّر `TextDirection` ⇒ `hide TextDirection`.
- 🚨 أي قراءة لـ`SharedPreferences` قد ترمي (`json.decode` بلا try/catch على سطح المكتب) — `PrefsGuard.repairIfCorrupt()` أول `main`.
- 🚨 `DATE(x,'localtime')` ممنوع على الأعمدة (الطوابع محلية أصلًا ⇒ إزاحة يوم).
- 🚨 كل `pw.Text` عربي في PDF يحمل `textDirection: rtl` وإلا حروف مقطّعة. نقطتا الرسم: `PreparePDF._docText` (فاتورة/كشف/وردية) و`text()` داخل `laundry_slip_pdf.dart`. كل ملف له **نقطة رسم واحدة** يفرضها حارس `verify_doc_template`.
- 🚨 الذمم: `toCents` قبل أي مقارنة؛ `invoices.remaining_amount` مصدر الحقيقة؛ كل دفعة عبر `allocatePaymentFifo` **مرة واحدة**.
- 🚨 بحث الزبون يمرّ من `CustomerSearch` (يغطي `phone_2` والفواصل) — لا `contains` محلي.
- 🚨 تكلفة الأصناف من `invoice_items_service.costFor` — لا `clothing.cost_price` مباشرة.
- 🚨 `pw.FittedBox` و`letterSpacing` مرفوضان في PDF؛ عرض النصّ **تضييق فقط** 75–100%.
- لا طابعة حرارية (أُلغيت 2026-09-21 بطلب المستخدم) — PDF فقط.

## الفهرس
| الموضوع | الملف |
|---|---|
| الذمم · الاشتراكات · الصندوق · الضريبة · الخصومات · الترخيص · الخيارات · النسخ الاحتياطي · الطباعة · القوالب · ويندوز/أندرويد | `ARCHITECTURE.md` |
| يوميات القرارات والعيوب المُثبتة | `YYYY-MM-DD.md` (الأحدث `2026-10-26.md`) |

## آخر الأعمال (2026-10-25) — **الدعم الثنائي مكتمل 100%**
`AppLanguage` · `L10n`/`tr()`/`trf()` · **2,086 نصًّا مترجمًا (100.0%)** · `Currency` · `LocaleController` · `flutter_localizations` · أعمدة `*_en` · **مفاتيح تخزين** لطرق الدفع وحالات المصنعية · `ui_direction` (لا `TextDirection.rtl` حرفية) · PDF يتبع اللغة · حقوق المطوّر من `tr`.
**`kUntranslatedCeiling = 0`** — أي نصّ واجهة جديد بلا ترجمة يُفشل الحارس فورًا.
`kNonUiLiterals` (38) تستثني ما لا يجوز ترجمته (سجلّات · تعبيرات نمطية · أسماء ملفّات · نصّ له `_en`).
حرّاس: `verify_i18n` **92/0** · 24 Dart + 20 Python = 0 · `dart analyze lib/` نظيف · بناء ويندوز ✅.

**ورقة المغسلة (2026-10-26)**: مستند داخلي ثانٍ يُطبع بعد الفاتورة بمهمة مستقلة، بمقاس `invoice_paper_size` نفسه، بلا أي مبلغ. مفتاح `invoice_print_laundry_slip` (افتراضي مُفعَّل) · **قالب مستقلّ `doc_template_laundry_slip` (20 حقلًا بلا حقل مالي) يُحرَّر من تبويب «ورقة المغسلة» أو من «تحرير قالب ورقة المغسلة» في صفحة الطباعة** · التفاصيل في `ARCHITECTURE.md § الطباعة` و`§ قوالب المستندات` · اختبار `test/laundry_slip_test.dart` (24).

**إغلاق الحوارات بعد الحفظ (2026-10-26)**: عيب `Get.back()` في GetX 4.x أنه يغلق رسالة snackbar المفتوحة ويعود قبل إغلاق الحوار. أُضيف `core/navigation/route_dismissal.dart` (`dismissRoute` · `dismissOpenDialog`) وطُبّق على إضافة/تعديل/حذف المستخدم والأدوار والتجاوزات، وإضافة/تعديل صنف اللبس. `showConfirmDialog` صار يغلق بسياق حواره. الحفظ يمنع النقر المزدوج ويُظهر تقدّمًا، والقائمة تتحدّث بعد التعديل. اختبار `test/route_dismissal_test.dart` (5).

**تحديث الأصناف والخدمات (2026-10-26)**: `AddCategoryController.loadClothing()` مسار الجلب الوحيد (الصنف + خدماته الأربع في استعلام واحد)، و`_loadToken` يمنع جلبًا قديمًا من طمس نتيجة أحدث. أُضيف `CatalogRefreshButton` (سهمان دائران) إلى شريط الرئيسية وإدارة الأصناف، ويُعطَّل أثناء الجلب. `CustomViewCategory` يعيد الجلب عند كل دخول وعند `resumed`، و`delete` ينتظر إعادة الجلب قبل رسالة النجاح. اختبار `test/catalog_refresh_button_test.dart` (2).

**عربي نوع الدفع + مقاس الشعار (2026-10-26)**: سطر الدفع في فاتورة العميل يمرّ عبر `PaymentMethods.arabicLabel` داخل `PreparePDF` ⇒ يُطبع «الدفع: كاش/شبكة/آجل/رصيد/اشتراك شهري/استرداد نقدي» حتى في الواجهة الإنجليزية. وأُضيف إعداد `invoice_logo_size` (مم · 10..120 · افتراضي 53 ≈ 150 نقطة) في «ما يظهر على الفاتورة» يتبع `invoice_show_logo`، ويُقصّ على عرض الورق فلا يتجاوز الحراري 58 مم. `test/invoice_print_labels_test.dart` (8) · `flutter test` 128 ناجحًا · `verify_doc_template` 329/0، والتفاصيل في `ARCHITECTURE.md § الطباعة` و`2026-10-26.md § 4`.

**افتراضي الدفع «شبكة» (2026-10-26)**: حوار الدفع في نقطة البيع يقرأ `pos_default_payment_method` عند كل فتح، وافتراضيه صار `card`، فلا يبدأ على «كاش» بعد اليوم مع بقاء كاش/آجل/اشتراك قابلة للاختيار يدويًّا. القواعد القائمة تُرحَّل مرة واحدة (`pos_default_payment_method_card_v1`) من `cash` إلى `card`. اختبار `test/pos_payment_default_test.dart` (4) · `flutter test` 132 ناجحًا · التفاصيل في `2026-10-26.md § 5`.

🚨 **الفاتورة تُطبع عربية دائمًا — السبب والحلّ**: `generatePdfData` داخل `compute`
(عزل مستقلّ) لا يرى `L10n` ⇒ اللغة تُختم في الحمولة (`docLang`) لا تُقرأ من الحالة العامة.
**أي كود `compute` لا يقرأ حالة عامّة.**

🚨 **رمز العملة يتبع اللغة**: `Currency.symbol` = `tr('ر.س')` ⇒ `SAR`.
لا تكتب `ر.س` حرفيًّا في جملة تُعرَض؛ داخل `trf` أو `${Currency.symbol}`.

التفاصيل الكاملة في `ARCHITECTURE.md § دعم اللغتين` و`2026-10-25.md`.

**إصلاح «الأصناف تبقى عربية» (بلاغ المستخدم)**: `L10n.localized` صار على **ثلاث درجات** — `_en` ⇒ القاموس ⇒ العربي (الصفوف القديمة `_en = NULL` لا تترجم أبدًا بدونه). أسماء البذر (43 صنفًا + 8 فئات + أوصافها) نُقلت من `namesEn` الخاصة إلى `kEnglish` وحُذف التكرار. سُدَّت **6 مواضع** كانت تعرض الاسم خامًّا: PDF · مشاركة · فواتير سابقة · جدول بنود · ورديات · لوحة التحكم. `StatementItem`/`ItemSummary` يحملان `nameEn` والتجميع يبقى على العربي. البحث صار غير حسّاس لحالة الأحرف. حرّاس: `verify_i18n` 67/0 (سقف 304) · 24 Dart + 20 Python = 0 · بناء ويندوز ✅.
