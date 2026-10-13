# ذاكرة `laundry` — فهرس الثوابت الحاكمة

Flutter POS مغاسل (عربي/RTL، offline، sqflite/GetX). البنية: `sqldb.dart` (القاعدة+الترحيلات+audit_log) · `main.dart` · `config/constants.dart` · `services/` · `core/services/` · `controller/` · `view/screen/`+`view/widget/`.

> 📖 **التفاصيل الكاملة في `.workbuddy-ai/memory/ARCHITECTURE.md`** — الذمم · الاشتراكات · الصندوق · لقطة البنود · الضريبة · الخصومات · الترخيص · الإعدادات والأدوار · النسخ الاحتياطي · الطباعة · تشغيل ويندوز/أندرويد. **اقرأه قبل أي تعديل جوهري.** هذا الملف فهرس مضغوط.

## قواعد حاكمة
- GetX فقط · كل وصول للقاعدة عبر `SqlDB` بـ`safeRead/Insert/Update/Delete` أو `readData(sql, args)` بمعاملات `?` — **ممنوع دمج القيم في SQL** ولا `rawQuery/rawUpdate`؛ `safeRead` لا يقبل `columns:`.
- جدول/عمود جديد ⇒ `runPendingMigrations()` (`_tryAlter` / `CREATE TABLE IF NOT EXISTS`) **في المواضع الثلاثة**: `_onCreate` · `_onUpgrade` · `runPendingMigrations` — الفشل صامت. لا تغيّر `dbVersion` بلا داعٍ.
- حذف ناعم `is_active=0` · لا بيع بلا وردية مفتوحة · لا حذف تلقائي لفاتورة من السنة الجارية · `logAudit(oldValues:, newValues:)` لأي تغيير ائتماني/سعري.
- `intl` يصدّر `TextDirection` ⇒ `hide TextDirection` مع `TextDirection.rtl`.
- `flutter analyze lib/` يعمل؛ `flutter test` **يعمل أيضًا** (صُحّح 2026-10-03 — ملاحظة «يفشل بسبب WebSocket» كانت خاطئة؛ شُغِّل بنجاح على اختبارات ودجت وتوليد PDF) ⇒ **أسرع دليل** على أخطاء الواجهة/الحزمة. وتبقى اختبارات `tool/` (Python على SQLite حقيقي، أو `dart run` لمنطق خالص في `*_rules.dart`/`*_service.dart`/`*_search.dart`) هي الأنسب لمنطق القاعدة.
- الإصدار **مصدر واحد**: `pubspec.yaml` (`1.2.0+2`) → `PackageInfo` في `main.dart` → `AppInfo.version`؛ لا رقم يدوي في الواجهة، وزامن `AppInfo.fallbackVersion` عند الرفع.
- الخطوط: `cairo` (واجهة) · `noto` = `AL-Mohanad.ttf` (PDF عربي) · `DTHULUTH`.
- معلومات النشاط: `settings` + كاش SP بمفتاح `cached_<key>` (**لا** `cached_business_<key>`) · واتساب `core/services/invoice_share_service.dart`.

## 🚨 أخطاء صامتة موثّقة — لا تُعِدها (13)
1. **`DATE(x,'localtime')` ممنوع على الأعمدة** — الطوابع محلية (`DateTime.now().toIso8601String()`، ولا `toUtc()`) و`'localtime'` تفترض UTC ⇒ تحويل مزدوج يزيح اليوم (+3h). استخدم `DATE(x)` مجرّدة؛ `DATE('now','localtime')` صحيحة وتبقى. والدرس: `expense_service.list` و`_expensesFor` يقيسان نفس الفترة.
2. **لا تُكرّر FIFO داخل متحكّم** — `customer_account_controller.recordPayment` كان يكرّره ويمحو سلفة الزبون صامتًا ⇒ التفويض إلى `customer_ledger_service.allocatePaymentFifo` إلزامي.
3. **لا تقرأ `clothing.cost_price` مباشرة في أي تقرير** — كل التكلفة من `invoice_items_service.costFor` (وإلا احتساب مزدوج أو صفر).
4. **`final_amount` يبقى شامل الضريبة** — إعادة تعريفه صافيًا تُفسد سلاسل الذمم. الإيراد الصافي = `tax_base`.
5. **الاسترداد كسلفة يخفض الذمة FIFO ولا يُضاف للرصيد**: `appliedToDebt = min(refund, debtCents)` → `allocatePaymentFifo` (بصف `source='cancel_refund'` **قبل** الاستدعاء)، والفائض فقط سلفة.
6. **لا تُعدَّل `invoices.paid_amount` بلا صف مقابل في `customer_payments`** (يختلّ صندوق اليوم)؛ وزيادة بلا نقدية تُوسَم `source='credit_use'` و`totalCashIn` يستثنيها.
7. **`appBar: Obx(...)` يفشل نوعيًا** ⇒ يُلفّ بـ`PreferredSize(Size.fromHeight(64))`.
8. **لا تستبدل `child` في `MyApp.builder`** (بوابة الترخيص) — يقتلع الـNavigator فيتعطّل حوار التجديد.
9. **بوابة الصيانة `SqlDB.beginMaintenance` لا تُزال** — و`closeDB` لا يمرّ بها عمدًا.
10. **كل `pw.Text` عربي في PDF يحمل `textDirection: pw.TextDirection.rtl`** — حزمة `pdf` لا تُشكّل العربية إلا بهذا الشرط (الافتراضي `useArabic=false`) وإلا ظهرت **مقطّعة ومعكوسة**. حرس `verify_statement_pdf.py` (31) يمنع أي `pw.Text` عارية خارج مُساعد `tx` **ويرفض أي استثناء**.
11. **خط `AL-Mohanad` لا يحوي الشرطة الطويلة `—` (U+2014)** ⇒ تُرسم محرفًا خاطئًا. استخدم `–` (U+2013) أو `-`.
12. **لا تمرّر `locale:` لمنتقي التاريخ (`showDatePicker`/`showDateRangePicker`)** — كان **يُنهي التطبيق** عند «من تاريخ إلى تاريخ» (أُصلح 2026-10-03). السبب: `main.dart` يضبط `MaterialApp.locale: ar` بلا `flutter_localizations`، و`LocalizationsResolver` **يحسم اللغة مقابل `supportedLocales`** (`[en_US]`) فيهبط للإنجليزية — لذلك يعمل التطبيق كله. لكن المنتقي يلفّ الحوار بـ`Localizations.override(locale: ar)` **متجاوزًا** الحسم، و`_MaterialLocalizationsDelegate.isSupported` تقبل `en` فقط ⇒ `MaterialLocalizations.of(context)` = `null` ⇒ debug: «No MaterialLocalizations found» · release: `!` على null = انهيار. **الأربعة مواضع أُزيلت**؛ حرس في `verify_statement_range.py` يفحص وسائط كل منتقي في `lib/`. (التحسين الكامل `flutter_localizations` + `supportedLocales:[ar,en]` **مؤجَّل** لأنه يعكس `Directionality` للتطبيق كله.)
13. **كتلة PDF قصيرة يجب ألا تُقتطع بين صفحتين ⇒ لفّها في `pw.Row` لا `pw.Container`/`pw.Column`** — `MultiPage` تنقل العنصر كاملًا لصفحة جديدة فقط إذا كان `canSpan == false` (`pdf-3.11.3`: `multi_page.dart:338`). و`Flex.canSpan => direction == Axis.vertical` (`flex.dart:527`) ⇒ `Column` يقبل الانقسام **دائمًا**، و`StatelessWidget.canSpan` (`widget.dart:269`) **يورّث** قيمة الابن ⇒ `Container(child: Column)` لا يُجدي. `pw.Row` الأفقي هو الحل (+ `pw.Expanded` ليبقى العرض كاملًا). مطبَّق على كتلة ختام الكشف (الملخّص + التذييل). حرس [4د] في `verify_statement_pdf.py`. ⚠️ **واقرأ المصدر من النسخة المحلولة في `.dart_tool/package_config.json` لا من أول مجلد في الكاش** (قرأت `pdf-3.8.4` خطأً والمحلول `pdf-3.11.3`).

## محاور سريعة
- **البحث عن زبون — محرّك واحد لا نسخ**: `services/customer/customer_search.dart` (خالص) = الاسم + `phone_1` + `phone_2` بتطبيع الفواصل والأرقام العربية، وكل القيم بـ`?`. **أي بحث زبون جديد يمرّ منه.** المواضع: `searchSuggestions` (`custominputname.dart`) · `customernumber.dart` · `customer_search_dialog.dart` · `debt_report_controller.filteredAging`. اختبارات 47+47.
  - 🚨 **العيب المتكرّر**: فلترة محلية بـ`row.phone.contains(q)` تُسقط **الرقم الثاني** (`phone_2`) ولا تتجاوز الفواصل/الأرقام العربية — حدث في 3 مواضع.
- **المستحق في الفاتورة**: سطر واحد كبير 24pt بصيغة `'X ر.س'` + `rtl` — **لا تكرّره بصيغتين** (كان يظهر مرتين، أُصلح 2026-10-03).
- **⚠️ لا طابعة حرارية — أُلغيت بطلب المستخدم (2026-09-21)**: PDF عادي فقط (A4 فاتورة، A6 ملخص وردية). لا تُعِد `services/printing/` ولا خياراتها بلا طلب صريح.
- **مُسبارات العرض** (`tool/_probe_statement.dart` · `_repro_footer.dart`) يجب أن تنسخ كود الإنتاج **حرفيًا** (بما فيه `rtl`) وإلا أنتجت دليلًا مضلّلًا. العرض بـPyMuPDF في venv `~/.workbuddy-ai/binaries/python/envs/default`.
- **تشغيل ويندوز/أندرويد**: مفتاح واحد `config/run_target.dart` → `kRunTarget`. `sqflite_common_ffi ^2.3.7` + `sqlite3 ^2.9.4` (v3 يفشل على ويندوز). التفصيل في ARCHITECTURE.

## دَين فني
`SessionManager.can*` كود ميت (الحي `PermissionService`) · لا فهارس على `invoices.invoice_date`/`customers.customer_name` · `previousinvoicecontroller` يبني `LIMIT/OFFSET` كنص · النسخ الاحتياطي بلا تشفير ولا جدولة.

> تفاصيل الأيام في `2026-09-17.md` · `2026-09-18.md` · `2026-09-19.md` · `2026-09-21.md` · `2026-10-01.md` · `2026-10-03.md`.
