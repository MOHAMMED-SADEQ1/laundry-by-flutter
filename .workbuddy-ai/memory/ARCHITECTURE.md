# `laundry` — المرجع المعماري التفصيلي

> مرجع تفصيلي مصاحب لـ`MEMORY.md` (الفهرس المضغوط الذي يُحقَن تلقائيًا).
> اقرأ هذا الملف كاملًا قبل أي تعديل جوهري في الذمم/الاشتراكات/الصندوق/الضريبة/النسخ الاحتياطي.

# ثوابت معماريّة

Flutter POS مغاسل (عربي/RTL، offline، sqflite/GetX). البنية: `sqldb.dart` (القاعدة+الترحيلات+audit_log) · `main.dart` · `config/constants.dart` · `services/` · `core/services/` · `controller/` · `view/screen/`+`view/widget/`.

## قواعد حاكمة
- **GetX فقط**. كل وصول للقاعدة عبر `SqlDB`. `safeRead/Insert/Update/Delete` أو `readData(sql, args)` بمعاملات `?` — **ممنوع دمج القيم في SQL** ولا `rawQuery/rawUpdate`؛ `safeRead` لا يقبل `columns:`.
- جدول/عمود جديد ⇒ `runPendingMigrations()` (`_tryAlter` / `CREATE TABLE IF NOT EXISTS`)، **وأضفه إلى المواضع الثلاثة** (`_onCreate` · `_onUpgrade` · `runPendingMigrations`) — الفشل صامت. لا تغيّر `dbVersion` بلا داعٍ.
- حذف ناعم `is_active=0`. لا بيع بلا وردية مفتوحة. لا حذف تلقائي لفاتورة من السنة الجارية. `logAudit(oldValues:, newValues:)` لأي تغيير ائتماني/سعري.
- `intl` يصدّر `TextDirection` ⇒ `hide TextDirection` مع `TextDirection.rtl`.
- `flutter analyze lib/` يعمل؛ `flutter test` **يفشل** (WebSocket في flutter_tester). الاختبارات في `tool/`: Python على SQLite حقيقي، أو `dart run` للمنطق الخالص المفصول في `*_rules.dart`/`*_service.dart`/`*_search.dart`.
- الإصدار **مصدر واحد**: `pubspec.yaml` (`1.2.0+2`) → `PackageInfo` في `main.dart` → `AppInfo.version`؛ لا رقم يدوي في الواجهة. عند الرفع زامن `AppInfo.fallbackVersion`.
- الخطوط: `cairo` (واجهة) · `noto` = `AL-Mohanad.ttf` (PDF عربي) · `DTHULUTH`.
- معلومات النشاط: `settings` + كاش SP بمفتاح `cached_<key>` (**لا** `cached_business_<key>`). واتساب `core/services/invoice_share_service.dart`.

## دَين فني
`SessionManager.can*` كود ميت (الحي `PermissionService`) · لا فهارس على `invoices.invoice_date`/`customers.customer_name` · `previousinvoicecontroller` يبني `LIMIT/OFFSET` كنص · النسخ الاحتياطي بلا تشفير ولا جدولة.

## الذمم
- **المحرّك** `services/customer/customer_ledger_service.dart` — كل دفعة عبر `allocatePaymentFifo`.
- `toCents`/`fromCents` إلزامية قبل أي مقارنة؛ ممنوع `balance > 0` على double. العتبة `> 0.004`.
- **مصدر الحقيقة** = الفواتير (`remaining_amount`)؛ `customers.balance` مشتق ⇒ `syncBalance`. الإشارة: `-` مدين · `+` دائن/سلفة · `0` صفر.
- `customer_payments` (`source` ∈ manual|delivery|credit_use|cancel_refund) · `customer_balance_log`.
- **ذهبية 1**: لا تُعدَّل `invoices.paid_amount` بلا صف مقابل في `customer_payments`. **ذهبية 2**: زيادة بلا نقدية (استهلاك سلفة) تُوسَم `credit_use` و`totalCashIn` يستثنيها.
- 🚨 **لا تُكرّر FIFO داخل متحكّم**: `customer_account_controller.recordPayment` كان يكرّره ويمحو سلفة الزبون صامتًا (سلفة 100 + ذمة 50 + دفعة 10 ⇒ -40 بدل +60). أُصلح 2026-10-01 بالتفويض. السلفة **لا تُستهلك تلقائيًا** (`consumeCredit` بزر يدوي).
- `controller/customer/customer_controller.dart` **محذوف**؛ الفعلي `CustomersNumberController`. خدمات: `credit_guard` · `debt_report_service` · `debt_reminder_service`.
- **البحث**: `services/customer/customer_search.dart` (خالص) = الاسم + `phone_1` + `phone_2`، بتطبيع الفواصل والأرقام العربية، وكل القيم بـ`?`. يستعمله `searchSuggestions` (شريط الفاتورة `custominputname.dart`) · `customernumber.dart` (`CustomerSearch.filter`) · `customer_search_dialog.dart` · `debt_report_controller.filteredAging` (`CustomerSearch.matches(r.toSearchMap(), q)`). حرس `looksLikePhone` يمنع «محمد 5» من مطابقة الأرقام. اختبار `verify_customer_search_sql.py` (47) + `verify_customer_search.dart` (47).
  - 🚨 **العيب المتكرّر**: فلترة محلية بـ`row.phone.contains(q)` تُسقط **الرقم الثاني** (`phone_2`) ولا تتجاوز الفواصل/الأرقام العربية. حدث في حقل الفاتورة وقائمة الزبائن وتقرير أعمار الديون. **أي بحث زبون جديد يمرّ من `CustomerSearch`.**
- شاشات `/debt-aging` · `/debt-reconciliation` · `/customer-account` · كشف الحساب `view/widget/customer/customer_statement_sheet.dart` + `customer_statement_service.dart` (قراءة فقط، `json_each` واحد) + `preparePDF.dart::generateCustomerStatementPdf` (A4 RTL). `StatementPayment.isCash` يستثني `credit_use`/`cancel_refund`/طريقة `رصيد`. اختبار `verify_customer_statement.py` (28).
- إعدادات: `debt_provision_rate` (0.25 لما >90 يومًا) · `default_credit_limit` (0 = بلا حد).

## الاشتراكات (dbVersion 6)
- **المحرّك** `services/subscription/subscription_service.dart` — لا حساب تغطية/حالة/سقف/استرداد خارجها.
- **دلالة الحقول**: `paid_until_date` = **نهاية** التغطية · `last_billed_date` = **بداية الدورة (المرساة)** — لا تُساوِ بينهما · `cycle_start_date` تُشتق من `last_billed_date`/`start_date` لا من `paid_until_date`.
- `SubStatus` ∈ pending|active|capped|overdue|cancelled **مُشتقّة في Dart**؛ `status TEXT` للفلترة فقط.
- **السقف**: `usage_limit_pieces` و`usage_limit_value` معًا؛ أيّهما ينفد أولًا يوقف. تحذير 80% غير مانع، منع + تجاوز مدير عند 100%. `price = 0` يرمي استثناءً.
- `pay()` ذرّية: `Database.transaction()` + `UPDATE … WHERE subscription_id=? AND COALESCE(paid_until_date,'')=?` (يرمي عند `updated == 0`).
- **الاسترداد** (`cancelWithSettlement`): المعدّل = المُقبَض ÷ طول نافذة التغطية (أقدم `covers_from` → `paid_until_date`)، ولا يتجاوز المُقبَض.
- 🚨 **الاسترداد كسلفة يخفض الذمة FIFO ولا يُضاف للرصيد**: `appliedToDebt = min(refund, debtCents)` → `allocatePaymentFifo` (مع صف `source='cancel_refund'` **قبل** الاستدعاء)، والفائض فقط سلفة. لا تُعِد `stored > 0 ? stored : 0`.
- `subscription_coverage_log` · `invoices.subscription_used_value/pieces`. الدفعة المقدَّمة **إيراد مؤجَّل** يُعترف به عند الاستهلاك. `totalCashIn` يشمل دفعات الاشتراك النقدية فقط. شاشة `/subscription-dashboard`.
- اختبارات: `verify_subscription_migration.py` (**شغّله بعد أي تعديل على `sqldb.dart`**) · `verify_subscription_settlement.py` · `verify_subscription_status_refresh.py` · `verify_report_revenue_fallback.py`.

## الصندوق (`daily_cash_controller` + `daily_cash_screen`)
- وضعان `CashViewMode.byDate`/`byShift`. بالوردية ⇒ `shift_id = ?` حصرًا (لا مقارنة زمنية) — «الوردية هي الصندوق».
- 🚨 **تاريخ الصندوق = تاريخ فتح الوردية**: `byDate` = كل وردية `DATE(start_time) = ?` (تشمل المفتوحة)، ثم حركاتها بـ`shift_id IN (…)`. الصفوف `shift_id IS NULL` بتاريخ حركتها. `invoice_date` يبقى للضريبة/الفاتورة.
- رصيد افتتاح الوردية = `opening_balance`، وإن كان صفرًا فـ`total_cash` للسابقة. وافتتاح يوم العمل = افتتاح أول وردية فقط (كل وردية ترحّل نقد سابقتها).
- `appBar: Obx(...)` يفشل نوعيًا ⇒ يُلفّ بـ`PreferredSize(Size.fromHeight(64))`.
- 🚨 **`DATE(x,'localtime')` ممنوع على الأعمدة**: الطوابع محلية (`DateTime.now().toIso8601String()`، ولا `toUtc()`) و`'localtime'` تفترض UTC ⇒ تحويل مزدوج يزيح اليوم (+3h). استخدم `DATE(x)` مجرّدة؛ أما `DATE('now','localtime')` صحيحة وتبقى. أُصلح 2026-09-19 — **الدرس**: `expense_service.list` و`_expensesFor` يقيسان نفس الفترة، فلا تُصلح أحدهما وحده.
- `shift_id` يُحقن مركزيًا في `SqlDB.safeInsert` لـ`expenses`/`customer_payments`/`subscription_payments` + ترحيل `shift_link_backfill_v1`.
- الجرد في `shifts`: `counted_cash` · `cash_difference` · `difference_reason` · `stocktake_at`. `NULL` = لم يُجرَد ≠ `0` = جُرِد وطابق. اختبارات `verify_cash_view_modes.py` (19) · `verify_shift_link.py` (8) · `verify_localtime_removal.py` (19).

## 💰 لقطة البنود `invoice_items` (2026-10-01)
- **الفصل الحاكم**: `invoices.list_data` (JSON) = مصدر العرض/الطباعة؛ `invoice_items` = مصدر التكلفة/الربح. المحرّك `services/invoice/invoice_items_service.dart` (`writeSnapshot` · `costFor({where,args})` · `hasSnapshot` · `itemsOf`).
- 🚨 لا تقرأ `clothing.cost_price` مباشرة في أي تقرير — كل التكلفة من `costFor`: `report_controller._costForRange` · `dashboard_controller` · `subscription_service.profitabilityOf`.
- `costFor` = `SUM(ii.total_cost)` + رجوع قديم بالاسم محروس بـ`NOT EXISTS (SELECT 1 FROM invoice_items …)` ⇒ لا احتساب مزدوج.
- `writeSnapshot` idempotent (يحذف صفوف الفاتورة أولًا) و**يبتلع الفشل** (`debugPrint`) كي لا يُسقط بيعًا مكتملًا. اللقطة **مجمَّدة وقت الإصدار** ⇒ إعادة التسمية لا تقطع التكلفة التاريخية، وتعديل `cost_price` لا يعيد كتابة أرباح الماضي. ترحيل `invoice_items_backfill_v1`. اختبار `verify_invoice_items.py` (21).

## 🧾 الضريبة (2026-10-01)
- **خالص** في `services/tax/tax_service.dart`. **السعر شامل الضريبة**: `base = gross/(1+rate)` · `tax = gross − base`. **الترتيب: الخصم قبل الضريبة**.
- **تُجمَّد لكل فاتورة**: `invoices.tax_amount` · `tax_rate` · `tax_base`.
- 🚨 `final_amount` يبقى شامل الضريبة (المستحق) — إعادة تعريفه صافيًا تُفسد سلاسل الذمم. الإيراد الصافي = `tax_base`. الفواتير الاشتراكية معفاة (`rate = 0`).
- الضريبة التزام لا إيراد ⇒ تُطرح في كل نطاقات التقرير: `net_profit = (totalSales − totalTax) + subRevenue − totalCost − subCost (− expenses)`، وكل تقرير يعرض `total_tax`.
- `taxEnabled`/`taxRate` من `AppSettingsService` · `business_tax_number` + `BusinessInfoService.taxNumber`/`isVatRegistered`.
- **QR زاتكا م1**: `TaxService.zatcaQrPayload` (TLV ثم Base64) + `Barcode.qrCode().toSvg` في `preparePDF.dart`، يُطبع فقط عند وجود رقم ضريبي. بطاقة «الضريبة المستحقة» في `reports_screen` (`AppColors.inkGradient`؛ لا يوجد `slateGradient`).

## 🏷️ الخصومات (2026-10-01)
- جدول `discounts` كان ميتًا ⇒ أُحيي. `services/discount/discount_rules.dart` خالص (`evaluate({record, gross, today})`) · `discount_service.dart` (`check`/`consume`/`save`/`deactivate`/`all`/`byId`).
- **النسبة**: `type == 'percentage'` ⇒ `value` نسبة صحيحة (10 = 10%) بخلاف `tax_rate` العشري. **السقف**: `amount = min(amount, gross)` ⇒ لا إجمالي سالب.
- الرفض: معطَّل · لم يبدأ · انتهى (شامل ليومه) · نفدت `max_uses` · `value<=0` · `gross<=0`. `consume()` بعد نجاح البيع فقط + `logAudit('discount_applied')`.
- الشاشة `/discounts` (`canManageDiscounts` = admin|manager) · التطبيق في `custompayinvoice.dart` عبر `_payable`.
- ⚠️ كان `replaceAll('.', ',')` والصحيح `replaceAll(',', '.')`. اختبار `verify_tax_and_discount.dart` (47) · `verify_discounts_schema.py` (28).

## الترخيص
- `settings.system_expiry_date` (`yyyy-MM-dd`) + كاش `cached_system_expiry_date`. **غيابه = غير محدود**، والانتهاء شامل ليومه. المنطق خالص في `services/license/license_status.dart`.
- `shouldSeed`: تثبيت جديد أو إصدار بتاريخ لاحق — **ولا يُقصّر أبدًا**. `SystemLicenseController` (permanent): إقلاع + كل ساعة + العودة من الخلفية.
- **البوابة** في `MyApp.builder`: القفل طبقة فوق `child` داخل `Stack` + `Navigator` خاص. **لا تستبدل `child`** (يقتلع الـNavigator فيتعطّل حوار التجديد).
- مقاومة إرجاع الساعة: `cached_license_last_seen` يكتب الأبعد فقط؛ التلاعب ⇒ قفل، والتجديد يعيد ضبطه. التجديد بزر يتحقق من admin نشِط؛ القسم لـ`canManageSettings`.
- `/license-log` عبر `license_log_service.dart` بلا فلتر زمني و`log_id DESC` عمدًا (لا `AuditService` لأنها تفلتر بـ`DATE(timestamp,'localtime')`). `showLicenseExpiryNoticeIfDue()` مرة واحدة يوميًا من مسارَي الدخول.

## خيارات النظام والأدوار
- سجل واحد `services/settings/setting_option.dart` (خالص): `key` · `label` · `kind` · `defaultValue` · `min/max` · `group` · `enabledBy` + `normalizeValue` + `isTruthy` (**الغياب أو أي نص غير صريح = معطَّل**).
- `app_settings_service.dart` (singleton): `settings` ← افتراضي السجل ← كاش SP (`cached_app_setting_<key>`)؛ `set()` تُطبّع + upsert + كاش + `logAudit('setting_update')`. يُحمَّل في `main.dart` قبل `license.start()`.
- **الحذف التلقائي**: `invoice_auto_delete_enabled` معطَّل عند غيابه، و`invoice_retention_days` بحدّ أدنى `invoiceRetentionMinDays = 400`. الزرع غير مُتلِف (`ConflictAlgorithm.ignore`).
- الواجهة: `settings_screen._systemOptionsSections` من السجل (ترتيب `SettingGroups.ordered`)؛ التابع لا يظهر إلا عند تفعيل `enabledBy`. ⚠️ العملة تُحفظ وتُضبط لكن الشاشات تكتب الرمز ثابتًا (104 موضعًا).
- `SqlDB._seedDefaultUsers` من المواضع الثلاثة بـ`ConflictAlgorithm.ignore` على `username` ⇒ **لا يُعيد كلمة مرور حساب غيّرها صاحبه**. التشفير `sha256(utf8(password + salt))` ⇒ `"<salt>:<hash>"`.
- `admin`/`laundry123456` · `manager`/`manager123456` · `accountant`/`accountant123456` · `user`/`user123456`.
- دور `accountant`: يقرأ الدفاتر ويُمنع من السلطة التصحيحية (حذف فاتورة، إصلاح أرصدة، حدّ الائتمان، مستخدمين، إعدادات). لا تُمنح `manager`. اختبارات: `verify_setting_options.dart` (41) · `verify_settings_seed.py` (11) · `verify_default_users_seed.py` (14) · `verify_cleanup_and_guards.py`.

## النسخ الاحتياطي والاستعادة
- **الصيغة**: ملف SQLite خام `.db` — لا ZIP ولا JSON. `backup_naming.dart` (خالص) · `backup_service.dart` · `/backup` (admin وحده).
- **قاعدتان**: (1) النسخة بـ`VACUUM INTO` لا بنسخ الملف (نسخ ملف في WAL يُسقط بيانات مُثبَّتة). (2) تُحذف `-wal`/`-shm`/`-journal` قبل كل استعادة.
- **حُرّاس**: ترويسة SQLite ⇒ `integrity_check` ⇒ وجود `users`/`settings`/`invoices`/`shifts` ⇒ نسخة أمان تلقائية `pre_restore_*` ⇒ استبدال ⇒ فحص بعدي ⇒ رجوع تلقائي. حفظ مزدوج؛ أحدث نسخة أمان محمية من الحذف.
- 🔴 **بوابة الصيانة (`SqlDB.beginMaintenance`) لا تُزال**: توقف كل طلب قاعدة أثناء الاستبدال وإلا أُعيد فتح الملف أثناء النسخ. و`closeDB` لا يمرّ بها عمدًا.
- **لا إعادة تحميل لينة بعد الاستعادة**: `SystemNavigator.pop` ثم `exit(0)`، لا `Get.offAllNamed(splash)`. و`PRAGMA user_version` يُقارن بـ`AppConstants.dbVersion`. فحوص: `verify_backup_logic.dart` · `verify_backup_roundtrip.py` · `verify_restore_safety.dart`.

## 🖨️ الطباعة
- **⚠️ لا طابعة حرارية — أُلغيت بطلب المستخدم (2026-09-21)**: PDF عادي فقط (A4 للفاتورة، A6 لملخص الوردية). حُذفت كل مضافة (`receipt_paper` · `receipt_side_margin_mm` · `SettingGroups.printing` · `SettingOption.choices` · `services/printing/`). لا تُعِد بناء أي منها بلا طلب صريح.
- المواضع الثلاثة: `await Printing.layoutPdf(onLayout: (PdfPageFormat format) => pdfBytes);` في `printInvoicecontroller` · `previousinvoicecontroller` · `shift_controller`؛ والنمط `(_) => pdfBytes` مقصود.
- **دروس**: `pw.MultiPage` يرفض الارتفاع اللانهائي وasserts معطّلة في `dart run` وفي نسخة الإصدار ⇒ `MediaBox` بارتفاع `Infinity` بلا استثناء · `roll57` عرضه 57mm · `Printing.layoutPdf` يتجاهل `onLayout` إن أعدتَ مستندًا جاهزًا.
- **لقطة واحدة قبل الطباعة**: `onLayout` قد يُستدعى مرتين وسلة الفاتورة تُفرَّغ بعده ⇒ البناء داخل الـcallback يُنتج مستندًا فارغًا. تُبنى قبل النداء.
- **حجم الـPDF**: النص وحده سريع (28–41ms) والصور هي العنق الوحيد (`_compressToJpeg` فارغة): صورة كاملة 287ms/3.7MB مقابل 30ms/119KB عند تصغيرها إلى 160×160. الخط ليس سببًا. أندرويد: `printing` لا ترى طابعات البلوتوث ⇒ يلزم RawBT.
- 🚨 **كل `pw.Text` عربي في أي PDF يحمل `textDirection: pw.TextDirection.rtl`** — حزمة `pdf` (3.11.3) لا تُشكّل العربية إلا بهذا الشرط: `final _textDirection = textDirection ?? Directionality.of(context);` ثم `useArabic && rtl ? arabic.convert(...) : useBidi && rtl ? bidi.logicalToVisual(...) : span.text`، و`options.dart` يجعل `useBidi=true` و`useArabic=false` افتراضيًا (ولا `--dart-define` في المشروع). بدون الاتجاه = **حروف مقطّعة ومعكوسة**.
  - **الوقوعات**: `generatePdfData` (الفاتورة) تضبطه على 22 نصًّا ⇒ سليمة **بلا أي استثناء الآن**. `generateShiftSummaryPdf` تلتفّ بـ`pw.Directionality(rtl)` فيرث كل محتواها الاتجاه (بما فيه `_buildRow`) ⇒ سليمة. `generateCustomerStatementPdf` كانت **بلا أي ضبط** ⇒ كشف الحساب ظهر مقطّعًا (أُصلح 2026-10-03 بمُساعد `tx`). **أي دالة PDF جديدة: إما `Directionality` أب أو `rtl` على كل نصّ.**
  - ✅ **ازدواج المبلغ — مُصلَح 2026-10-03**: كان الفوتر يطبع `payable` **مرتين** (`'س.ر X'` 24pt بترتيب بصري يدوي + `'X ر.س'` 16pt). السطر 24pt كان بقية من تعديل سابق غير موجود في `HEAD`. حُذف، وبقي **سطر واحد كبير 24pt** بصيغة `'${_money(payable)} ر.س'` + `rtl` (أمر المستخدم: «سطر واحد كبير»). أُثبت بعرض الـPDF: مقطع واحد `size=24.0 '30.00ﺭ.ﺱ'` بدل مقطعين.
  - **الأصل في الحزمة**: `bidi.logicalToVisual` يُعيد الترتيب فقط؛ والتشكيل الفعلي (ابتدائي/وسطي/نهائي) في `arabic.convert` المُعطَّل افتراضيًا.
  - حرس: `tool/verify_statement_pdf.py` (**31**) — يمنع أي `pw.Text` عارية خارج `tx`، **ويرفض أي استثناء** (`ALLOWED_WITHOUT_RTL` صار فارغًا)، و[8] يمنع عودة ازدواج المبلغ (يفحص `'س.ر '` في الملف كله + عدد `pw.Text` التي تطبع `payable` = 1).
- 🚨 **خط `AL-Mohanad` لا يحوي الشرطة الطويلة `—` (U+2014)** ⇒ تُرسم محرفًا خاطئًا (أُثبت بمقارنة `—`/`–`/`-`). استخدم `–` (U+2013) أو `-`.
- **كشف الحساب**: **جدول واحد** للأصناف باسم «الأصناف التي أخذها» بأعمدة (التاريخ والوقت · الصنف · العدد · القيمة) وعرض أعمدة مُثبَّت بـ`columnWidths` (1.55/2.05/0.65/1.05). كان جدولين («مجمَّعة» بلا تاريخ + «تفاصيل») فحُذف المجمَّع 2026-10-03 بطلب المستخدم (كان يكرّر الصنف ويطيل الكشف بلا جدوى) وأُزيل `items` من خريطة البيانات (`st.itemSummary` يبقى لأنه مستخدم في `customer_account_screen`). التفاصيل تُبنى في `customer_statement_controller.buildPdfData` من `st.invoices` (كل فاتورة تحمل تاريخها وبنودها) ⇒ **بلا SQL جديد ولا N+1**. `_dt()` = `yyyy-MM-dd HH:mm` بلا تحويل مناطق زمنية (الطوابع محلية).
- **أحجام خطّ الكشف** (كُبِّرت 2026-10-03 بطلب المستخدم): `base = 13` · `small = 11` · `cellSize = 12` (خلايا الجداول) · `sectionTitle = 14` · «كشف حساب زبون» = 19 · اسم النشاط = 20. **⚠️ لا تُسمِّ ثابتًا `cell`** — يتعارض مع دالة `cell` الداخلية في مُساعد `table` فيُظلّلها ويُفشل التحليل.
- ✅ **ترتيب أعمدة الجداول RTL** (أُصلح 2026-10-03): `pw.Table` يرصف الأبناء من **اليسار** ولا يعكس للـRTL ⇒ كان العمود الأول يظهر في أقصى اليسار فيقرأ العربي الجدول من آخره. الحل داخل مُساعد `table()` نفسه: `headers.reversed` + `r.reversed` لكل صف + عكس مفاتيح `widths` (`n - 1 - e.key`) ⇒ العمود الأول (التاريخ) صار في **أقصى اليمين**، وكل منادات `table()` تمرّر الأعمدة بترتيبها المنطقي. أُثبت بعرض الـPDF.
- **مراجعة بصرية بلا تشغيل التطبيق**: `tool/_probe_statement.dart` يبني نسخة أمينة من بنية الكشف ويُخرج PDF+PNG · `tool/_repro_footer.dart` يفعل الشيء نفسه لفوتر الفاتورة (المستحق). العرض بـPyMuPDF في venv `~/.workbuddy-ai/binaries/python/envs/default`. **القاعدة**: أي مُسبار يجب أن ينسخ كود الإنتاج حرفيًا (بما فيه `rtl`) وإلا أنتج دليلًا مضلّلًا.

## 🖥️ تشغيل ويندوز + أندرويد (2026-10-03)
- **مفتاح واحد**: `lib/config/run_target.dart` → `const RunTarget kRunTarget = RunTarget.auto;` (`auto` | `windows` | `android`). هذا هو «الملف والسطر» الذي يبدّله المستخدم.
- `AppPlatform.prepareDatabaseEngine()` يُستدعى في `main.dart` **أول سطر** بعد `WidgetsFlutterBinding.ensureInitialized()` وقبل أي لمس للقاعدة: على الديسكتوب `sqfliteFfiInit()` + `databaseFactory = databaseFactoryFfi`.
- `resolveDatabaseDirectory()`: ديسكتوب ⇒ `getApplicationSupportDirectory()` (`%APPDATA%`)؛ أندرويد ⇒ `getDatabasesPath()` **كما هي بلا تغيير**. `sqldb._initDB()` و`getDatabasePath()` (النسخ الاحتياطي/الاستعادة) يمرّان من هنا — وإلا لاستعاد المستخدم ملفًا في مسار غير المسار الحقيقي.
- `_resolve()` **يرفض** اختيارًا يدويًا يخالف النظام الفعلي ويطبع تحذيرًا (منع فتح قاعدة فارغة في مسار خاطئ).
- **`pubspec`**: `sqflite_common_ffi ^2.3.7` (**ليس** ^2.4.0) + `sqlite3 ^2.9.4` + `sqlite3_flutter_libs ^0.5.24`. sqlite3 **v3** يستخدم build hooks / native assets ويفشل على ويندوز بـ`Target dart_build failed : Building native assets failed` ⇒ العلاج الرسمي هو الرجوع إلى v2.
- **بناء من sandbox**: `env 'PROGRAMFILES(X86)=C:\Program Files (x86)' flutter build windows --debug` — لأن الصندوق لا يورّث المتغيّر (جهاز المستخدم عنده إياه). و`flutter doctor` يفشل في فحص ويندوز داخل الصندوق بسبب حجب `reg.exe` — ليس عيبًا حقيقيًا. تأكيد الأدوات: `vswhere.exe`.
- **`discounts`** كانت ناقصة من `runPendingMigrations` (موجودة في `_onCreate`/`_onUpgrade` فقط) ⇒ أُضيف `IF NOT EXISTS "discounts"`. (اكتُشف بـ`grep -n "discounts" lib/sqldb.dart`.)

> تفاصيل الأيام في `2026-09-17.md` · `2026-09-18.md` · `2026-09-19.md` · `2026-09-21.md` · `2026-10-01.md` · `2026-10-03.md`.
