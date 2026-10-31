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
- `flutter analyze lib/` يعمل؛ `flutter test` يعمل أيضًا (120 اختبارًا، شغّله بـ`--concurrency=1` عند تشابك الاختبارات). الاختبارات الحسابية الثقيلة في `tool/`: Python على SQLite حقيقي، أو `dart run` للمنطق الخالص المفصول في `*_rules.dart`/`*_service.dart`/`*_search.dart`.
- الإصدار **مصدر واحد**: `pubspec.yaml` (`1.2.0+2`) → `PackageInfo` في `main.dart` → `AppInfo.version`؛ لا رقم يدوي في الواجهة. عند الرفع زامن `AppInfo.fallbackVersion`.
- الخطوط: `cairo` (واجهة) · `noto` = `AL-Mohanad.ttf` (PDF عربي) · `DTHULUTH`.
- معلومات النشاط: `settings` + كاش SP بمفتاح `cached_<key>` (**لا** `cached_business_<key>`). واتساب `core/services/invoice_share_service.dart`.
- 🚨 **إغلاق الحوار/الشاشة بعد الحفظ**: `Get.back()` في GetX 4.x يفحص الـsnackbar أولًا ويغلقها ثم يعود، فيبقى الحوار مفتوحًا إذا عرض المتحكّم رسالة نجاح قبله. استعمل `core/navigation/route_dismissal.dart`: `dismissRoute(context)` للصفحات والحوارات التي تملك `BuildContext`، و`dismissOpenDialog()` لـ`Get.defaultDialog`. `showConfirmDialog` و`AppFormDialog` يغلقان أنفسهما بالمسار لا بـ`Get.back()`. لا تُعِد `Get.back()` إلى مسار يعرض نجاحًا ثم يُغلق.
- 🔄 **تحديث الكتالوج**: `AddCategoryController.loadClothing()` هو **مسار الجلب الوحيد** للأصناف وخدماتها الأربع (استعلام واحد). `_loadToken` يضمن أن آخر جلب بدأ هو من يكتب في `clothing`، فلا يطمس جلب قديم بدأ قبل إضافة/تعديل/حذف نتيجةً أحدث. `delete` يعيد `Future<bool>` ولا يعرض النجاح قبل إعادة الجلب. `CatalogRefreshButton` في شريط الرئيسية وإدارة الأصناف يعيد الجلب ويُعطَّل أثناءه (`isLoading`) فلا نقر مزدوج. `CustomViewCategory` يعيد الجلب عند كل دخول وعند عودة التطبيق (`resumed`). اختبار `test/catalog_refresh_button_test.dart`.

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

## 🧮 بنود الفاتورة: لا سطرين متطابقين (2026-10-31)
- **الملف الحاكم**: `services/invoice/invoice_lines.dart` — **منطق خالص** بلا Flutter ولا قاعدة. فيه `ServiceKind` (تسميات الخدمات الأربع `normalWash/urgentWash/normalIron/urgentIron` + `keyToLabel` + `priceColumn`) و`InvoiceLines` (`normalize` · `probe` · `merge` · `withQuantity` · `withPrice` · `lineTotal` · `quantityOfService` · **`applyAdd`** · **`applyUpdate`**).
- 🚨 **هوية البند خمسة عناصر**: الصنف · الخدمة · سعر الوحدة · الملاحظة · الصورة. تطابق تامّ ⇒ **زيادة كمية** (`LineAddOutcome.merged`)؛ اختلاف أيٍّ منها ⇒ سطر مستقلّ **بسببه المُعلَن** (`separateByNote/Photo/Price`) لأن الدمج الصامت يُخفي بقعة أو سعرًا وافق عليه الزبون.
- الأولوية عند اجتماع الأسباب: الملاحظة ثم الصورة ثم السعر.
- 🚨 **`InvoiceLines.lineTotal` مصدر الإجمالي** (سعر × كمية مقرَّبًا)، لا `total_price` المخزَّن؛ ولا يُقرأ المخزَّن إلا إذا كان السعر صفرًا (فاتورة قديمة/بند مجاني).
- **التعديل يعيد فحص التكرار** (`applyUpdate` + `ignoreIndex`): لو صار البند مطابقًا لبند آخر يُدمجان وتُحذف النسخة الزائدة (`mergedByEdit`) — وإلا بقي الباب الخلفي مفتوحًا لسطرين متطابقين. وخريطة تعديل ناقصة (بلا `count`/`price`) تحفظ القيمة القديمة.
- **`setItems` (استعادة مسودة/فاتورة) لا يدمج** — المستند المستعاد صورة الماضي.
- **الواجهة**: `customviewinvoice.dart` (عدّاد −/N/+ · تعديل · حذف بتأكيد) و`invoice_line_edit_dialog.dart` (خدمة · كمية · سعر · ملاحظة · إجمالي حيّ؛ تغيير الخدمة يُسعَّر من `priceColumn`) وشارة «في الفاتورة: N» في `home/dialog.dart`.
- الحراسة: `tool/verify_invoice_lines.dart` (**123**): سلوك على قوائم حقيقية + ربط المتحكّم/الواجهة + منع تكرار تسميات الخدمات.

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
- **افتراضي الدفع في نقطة البيع = شبكة (2026-10-26)**: `pos_default_payment_method` هو مصدر الحوار الوحيد؛ `posDefaultPaymentMethodDefault = 'card'`، و`_PaymentMethodDialogState._method` يقرأ الإعداد عند كل بناء (لا يورّث اختيار الجلسة السابقة) فيعود التحديد إلى «شبكة» كل فتح مع بقاء كاش/آجل/اشتراك قابلة للاختيار يدويًّا. القواعد القائمة تحمل `cash` المزروعة سابقًا، فترحيل `_migratePosDefaultPaymentToCard` يحوّلها مرة واحدة ويُعلَّم بـ`pos_default_payment_method_card_v1` كي لا يدهس اختيار المستخدم اللاحق. اختبار `test/pos_payment_default_test.dart` (4).
- **عدد أعمدة شبكة الأصناف (2026-10-26)**: `home_grid_columns` (`auto` · `2`..`6` · افتراضي `auto`) في `SettingGroups.pos`؛ `AppSettingsService.homeGridColumns` يُرجع `0` للـ`auto`. الزرّ `view/widget/home/home_grid_columns_menu.dart` في شريط «الأصناف والخدمات» يقرأ خياراته من السجلّ ويكتب عبر `AddCategoryController.changeGridColumns` (حفظ **قبل** تحديث `RxInt gridColumns`). الصريح يُقصّ بسقف أمان `(maxWidth / 145).floor()` فلا تُصغَّر البطاقة حتى يفيض محتواها؛ «تلقائي» يبقي `(maxWidth / 210).floor()` القديم. 🚨 **تُقرأ `gridColumns.value` في جسم `Obx` قبل `LayoutBuilder`، لا داخل `builder`**: قراءتها داخل builder تقع في طور التخطيط بعد حسم الاشتراكات فلا تتغيّر الشبكة أبدًا. اختبار `test/home_grid_columns_menu_test.dart` (4) وحارس `tool/verify_grid_columns_wiring.dart` (23).
- **الحذف التلقائي**: `invoice_auto_delete_enabled` معطَّل عند غيابه، و`invoice_retention_days` بحدّ أدنى `invoiceRetentionMinDays = 400`. الزرع غير مُتلِف (`ConflictAlgorithm.ignore`).
- الواجهة: `settings_screen._systemOptionsSections` من السجل (ترتيب `SettingGroups.ordered`)؛ التابع لا يظهر إلا عند تفعيل `enabledBy`. ⚠️ العملة تُحفظ وتُضبط لكن الشاشات تكتب الرمز ثابتًا (104 موضعًا).
- `SqlDB._seedDefaultUsers` من المواضع الثلاثة بـ`ConflictAlgorithm.ignore` على `username` ⇒ **لا يُعيد كلمة مرور حساب غيّرها صاحبه**. التشفير `sha256(utf8(password + salt))` ⇒ `"<salt>:<hash>"`.
- `admin`/`laundry123456` · `manager`/`m123` · `accountant`/`accountant123456` · `user`/`123`. (صُحّحت 2026-10-13 مقابل `config/constants.dart` — الذاكرة كانت تذكر `manager123456`/`user123456` خطأً.)
- دور `accountant`: يقرأ الدفاتر ويُمنع من السلطة التصحيحية (حذف فاتورة، إصلاح أرصدة، حدّ الائتمان، مستخدمين، إعدادات). لا تُمنح `manager`. اختبارات: `verify_setting_options.dart` (41) · `verify_settings_seed.py` (11) · `verify_default_users_seed.py` (14) · `verify_cleanup_and_guards.py`.

## 🔐 إنفاذ الصلاحيات + المرتجعات (2026-10-30)

### قاعدة الكتالوج الآن: **لا صلاحية بلا موضع إنفاذ**
`verify_service_enforcement.dart` يُثبت 13 موضعًا حرجًا. من يضيف صلاحية جديدة
يضيف معها سطر إنفاذ + سطرًا في `enforcedConsts` وإلا فشل الحارس.

| المفتاح | موضع الإنفاذ |
|---|---|
| `invoice.create` | `printInvoicecontroller.printPDF` (أول سطر) |
| `invoice.print` | `InvoiceOutputService.deliverBundle` + `printLaundrySlipOnly` |
| `invoice.return` | `CreditNoteService.returnInvoice` |
| `reports.profit` | `ReportController._guardMetrics` + بطاقة الربح (تقارير · لوحة) |
| `reports.tax` | `_guardMetrics` + بطاقة الضريبة |
| `customer.credit_limit_override` | `credit_guard` (بدل `SessionManager.isManager`) |
| `subscription.usage_override` | `subscription_service` (بدل `isManager`) |

- 🚨 **`invoice.print` تُفحص في نقطة الإخراج لا في شاشة البيع**: الفاتورة
  **محفوظة قبل** `deliverBundle`، فغياب الصلاحية يمنع الورق ولا يُسقط بيعًا.
- 🚨 **الحجب بـ`null` لا بالصفر**: الصفر رقم كاذب («ربحت صفرًا»). الواجهة
  تُخفي البطاقة، والمتحكّم يُخرج `null` في الخريطة التي تصل إليها.
- `invoice.delete` و`invoice.edit_issued` و`export.data` **حُذفت من الكتالوج**
  (لا حذف فاتورة صادرة · لا تحرير بعد الإصدار · لا وظيفة تصدير أصلًا —
  التصدير الوحيد النسخة الاحتياطية المحروسة بـ`backup.perform`).
- `SqlDB._reconcilePermissionCatalog` (`permission_catalog_reconcile_v1`):
  يمنح `subscription.usage_override` لـadmin/manager مرة واحدة (كي لا يُسحب
  سلوك قائم من أيديهم)، ويحذف إسنادات المفاتيح المحذوفة من `role_permissions`
  و`permission_overrides`.

### المرتجعات: فاتورة عكسية سالبة لا حذف
`services/invoice/credit_note_service.dart` — مرتجع **كامل فقط** (قرار المستخدم):
1. صفّ في `credit_notes` (السجل القانوني الموجز).
2. **فاتورة سالبة** (`invoice_number_text = 'CN-<id>'`, `credit_note_of = الأصل`,
   `status = delivered`, `paid_amount` سالب عند الردّ نقدًا) ⇒ كل `SUM` قائم
   (تقارير · وردية · صندوق) يصحّ **بلا إعادة كتابة استعلام واحد**.
3. **بنود سالبة** في `invoice_items` ⇒ التكلفة تُلغى أيضًا. إلغاء الإيراد وحده
   يُظهر الربح ناقصًا بقيمة تكلفة القطع.
4. الأصل: `remaining_amount = 0` فقط — لا حذف ولا تعديل مبلغ ولا تاريخ.
5. الردّ رصيدًا يمرّ من **`allocatePaymentFifo`** (يسدّد أقدم الذمم ثم يقيّد
   الفائض سلفةً) لا من إضافة مباشرة إلى `customers.balance`: `syncBalance`
   يشتقّ الحقل من الفواتير فيمحو الإضافة.
6. حرس مزدوج داخل المعاملة ضد إشعارين لنفس الفاتورة.
- الإشعار **مستبعد** من: `invoice_count` في التقارير/اللوحة/الوردية، ولوحة
  المصنعية (`credit_note_of = 0`)، ولا ورقة مغسلة له، ويُطبع بعنوان
  «إشعار دائن» عبر `docTexts[DocCatalog.kTitle]`.
- حرّاس: `tool/verify_credit_notes.py` (22) · `tool/verify_processing_status.py` (10).

### حذف الإعدادات الميتة
`services/settings/legacy_setting_keys.dart` (50 مفتاحًا) +
`SqlDB._cleanupLegacySettings` (`settings_cleanup_v1`): ينسخ القيم إلى
`audit_log` (`settings_legacy_cleanup`) ثم يحذف بالمفاتيح فقط. القاعدة الحيّة
كانت تحمل **50/50** منها. حارس `tool/verify_legacy_settings.py` (14) يُثبت
أنه لا قارئ لأي مفتاح (لا بقيمته ولا بثابت `AppConstants`) وأن لا مفتاح منها
مُسجَّل في `SettingOptions`.
`label_paper_size` و`processing_print_item_tags` **بقيا** بنصّ صادق
(«غير مفعّلة بعد») — لا طباعة ملصقات في النظام.

## النسخ الاحتياطي والاستعادة
- **الصيغة**: ملف SQLite خام `.db` — لا ZIP ولا JSON. `backup_naming.dart` (خالص) · `backup_service.dart` · `/backup` (admin وحده).
- **قاعدتان**: (1) النسخة بـ`VACUUM INTO` لا بنسخ الملف (نسخ ملف في WAL يُسقط بيانات مُثبَّتة). (2) تُحذف `-wal`/`-shm`/`-journal` قبل كل استعادة.
- **حُرّاس**: ترويسة SQLite ⇒ `integrity_check` ⇒ وجود `users`/`settings`/`invoices`/`shifts` ⇒ نسخة أمان تلقائية `pre_restore_*` ⇒ استبدال ⇒ فحص بعدي ⇒ رجوع تلقائي. حفظ مزدوج؛ أحدث نسخة أمان محمية من الحذف.
- 🔴 **بوابة الصيانة (`SqlDB.beginMaintenance`) لا تُزال**: توقف كل طلب قاعدة أثناء الاستبدال وإلا أُعيد فتح الملف أثناء النسخ. و`closeDB` لا يمرّ بها عمدًا.
- **لا إعادة تحميل لينة بعد الاستعادة**: `SystemNavigator.pop` ثم `exit(0)`، لا `Get.offAllNamed(splash)`. و`PRAGMA user_version` يُقارن بـ`AppConstants.dbVersion`. فحوص: `verify_backup_logic.dart` · `verify_backup_roundtrip.py` · `verify_restore_safety.dart`.

## 🖨️ الطباعة
- **⚠️ لا طابعة حرارية — أُلغيت بطلب المستخدم (2026-09-21)**: PDF عادي فقط (A4 للفاتورة، A6 لملخص الوردية). حُذفت كل مضافة (`receipt_paper` · `receipt_side_margin_mm` · `SettingGroups.printing` · `SettingOption.choices` · `services/printing/`). لا تُعِد بناء أي منها بلا طلب صريح.
- **ورقة المغسلة (2026-10-26)**: مستند ثانٍ داخلي يُطبع بعد فاتورة العميل بنفس مهمة الإخراج (`invoice_output_service.deliverBundle`) — **مهمّة طباعة مستقلة** ليقطعها القاطع التلقائي وحدها، وملف PDF مستقلّ بلاحقة `_laundry`. المفتاح `invoice_print_laundry_slip` (افتراضي `1`) في `SettingGroups.invoiceOutput`. المولّدان: `services/pdf/laundry_slip.dart` (بيانات خالصة بلا أي مفتاح مالي) و`laundry_slip_pdf.dart` (جدول على A4/A5 · أسطر مضغوطة على A6/الحراري · ارتفاع حراري مُقدَّر بهامش أمان + 26 مم للشعار). **المقاس يتبع `invoice_paper_size` حرفيًّا — لا مقاس مستقلّ**. الأرقام اللاتينية (تاريخ · هاتف · رمز استلام) تُرسم بـ`ltr` داخل السطر العربي وإلا أعاد محرّك الاتجاه ترتيبها. فشل توليدها معزول: لا يمنع فاتورة العميل ولا يُبقي السلة ممتلئة. إعادة الطباعة من «الفواتير السابقة» تُخرج الاثنين، وزرّ مستقلّ يطبع الورقة وحدها (`printLaundrySlip`). **ورقتها قالب رابع مستقلّ** `doc_template_laundry_slip` (20 حقلًا بلا أي حقل مالي) يُحرَّر من تبويب «ورقة المغسلة» في محرّر القوالب أو مباشرة من صفحة الطباعة (`تحرير قالب ورقة المغسلة`) ومن فهرس الإعدادات (`قالب ورقة المغسلة`). اختبر: `test/laundry_slip_test.dart` (24).
- المواضع الثلاثة: `await Printing.layoutPdf(onLayout: (PdfPageFormat format) => pdfBytes);` في `printInvoicecontroller` · `previousinvoicecontroller` · `shift_controller`؛ والنمط `(_) => pdfBytes` مقصود.
- **دروس**: `pw.MultiPage` يرفض الارتفاع اللانهائي وasserts معطّلة في `dart run` وفي نسخة الإصدار ⇒ `MediaBox` بارتفاع `Infinity` بلا استثناء · `roll57` عرضه 57mm · `Printing.layoutPdf` يتجاهل `onLayout` إن أعدتَ مستندًا جاهزًا.
- **لقطة واحدة قبل الطباعة**: `onLayout` قد يُستدعى مرتين وسلة الفاتورة تُفرَّغ بعده ⇒ البناء داخل الـcallback يُنتج مستندًا فارغًا. تُبنى قبل النداء.
- **لغة المستندات مستقلة عن لغة الواجهة (2026-10-29)**: إعداد `doc_language` (`ar` افتراضي · `en`) في `SettingGroups.invoiceDisplay` هو **الحاكم الوحيد** للورق: الفاتورة · كشف الحساب · ملخص الوردية · ورقة المغسلة. لا يُشتقّ من `settings.language` ولا من `L10n`، فتبديل لغة الشاشة لا يغيّر مستندًا ماليًّا. `DocLanguage` (`services/i18n/doc_language.dart`) منطق خالص، و`DocTemplateService.transport` يختم `docLang` من الإعداد ويُرفق `docEnglish` للإنجليزية فقط. العربية هي المطلوبة نظامًا في الفاتورة الضريبية السعودية، والإنجليزية خيار تجاري. اختبار `test/doc_language_test.dart` (16) · `tool/verify_doc_language.dart` (39).
- **نوع الدفع المطبوع بلغة المستند (2026-10-29)**: `data['payment']` يمرّ في `PreparePDF.generatePdfData` عبر `PaymentMethods.labelIn(raw, english: !isRtl)` — لا `L10n` ولا لغة واجهة. مستند عربي ⇒ كاش · شبكة · آجل · رصيد · اشتراك شهري · استرداد نقدي، ومستند إنجليزي ⇒ Cash · Card · Credit. القيمة المجهولة تُترك كما هي. التحويل في المولّد يغطّي البيع وإعادة الطباعة والمشاركة بلا تكرار في كل حمولة.
- **مقاسات الشعار ورمز QR (2026-10-31 · بديل `invoice_logo_size`)**: ثلاثة مفاتيح في `SettingGroups.invoiceDisplay` بالمليمتر — `invoice_logo_width` (5..120 · افتراضي 53) · `invoice_logo_height` (5..120 · افتراضي 53) · `map_qr_size` (10..70 · افتراضي 30 ≈ 85 نقطة). **عرض وارتفاع مستقلّان** لأن الشعار المستطيل كان يُقصّ إلى مربّع فيضيع طرفاه. المنطق الخالص في `services/pdf/print_visual_size.dart`: `PrintVisualSize.logo/qr` يحوّل مم⇒نقاط ثم **يقصّ** على الورق (العرض = `availableWidth`، الارتفاع = **35%** من `availableHeight`) ويعيد `VisualBox{width, height, widthClamped, heightClamped, areaMm2}`، و`pageOf(PaperSize)` يحسب المساحة المطبوعة بنفس هوامش `PreparePDF` (حراري 2.5 مم/جهة · غيره 11.5) و`shareOfPage`/`verticalBudget` (تنبيه عند 60%). رمز QR يبقى **مربّعًا** بعد القصّ (أصغر البعدين) وإلا صار غير قابل للقراءة. المفتاح القديم `invoice_logo_size` لا يظهر في الإعدادات: يُرحَّل مرة واحدة (`_migrateLogoSizeToBox` + علامة `logo_size_box_v1`، **قبل** `_ensureDefaultSettings` وإلا كتب الزرع الافتراضي 53) ويبقى مقروءًا كحمولة قديمة (`legacyMm: data['logoSizeMm']`) فإعادة طباعة فاتورة سابقة تُخرج الشكل نفسه. الحمولة: `logoWidthMm` · `logoHeightMm` · `mapQrSizeMm` في `printInvoicecontroller` · `previousinvoicecontroller` · `invoice_share_service` (والكشف يقرأ `mapQrSizeMm`). الرسم: `pw.Image(..., fit: pw.BoxFit.contain)` — **مثبّت صراحةً** ضد تغيير سلوك المكتبة، ولذلك تقول البطاقة «المساحة **القصوى**» لأن المربّع في صندوق 80×30 يُطبع 30×30. الواجهة: `printSizesCard` في صفحتي «الفواتير» و«الطباعة» (حقول + «اجعل الشعار مربّعًا» + «القيم الافتراضية» + ثلاثة أسطر حساب حيّة + **إعلان القصّ**)، والمفاتيح الثلاثة **مستثناة** من `optionsSection` فلا تحكّمين لنفس المفتاح. الدليل: رمز 30 مم ⇒ مساحة رسم واحدة **85.04×85.04 نقطة = 30.00 مم**، ويُقرأ على الحراري عند 203 و150 dpi. حارس `tool/verify_print_sizes.dart` (63) · مسبار `tool/_probe_map_qr_pdf.dart`.
- **عدد نسخ الفاتورة من حوار الدفع (2026-10-26)**: `InvoiceCopiesSelector` (`view/widget/invoice/invoice_copies_selector.dart`) يعرض 1..5 داخل حوار «طريقة الدفع» ويكتب `invoice_copies` **فورًا** — وهو المفتاح نفسه الذي تقرأه `InvoiceOutputService._invoiceCopies()` وتُكرّر عليه مهمة الطباعة (اسم المهمة `فاتورة #N (i/total)` عند أكثر من نسخة). لا مفتاح ثانٍ: مصدر حقيقة واحد للإعداد واختيار الحوار. `_PaymentMethodDialogState._confirm` ينتظر `_copiesSave` قبل الإصدار كي لا تُطبع القيمة القديمة عند نقر سريع. اختبار `test/invoice_copies_selector_test.dart` (5).
- **عدد النسخ عند إعادة الطباعة من السجل (2026-10-26)**: زرّ «طباعة» في `previousinvoice.dart` يفتح `showInvoiceReprintCopiesDialog` (`view/widget/invoice/invoice_reprint_copies_dialog.dart`) الذي يستعمل `InvoiceCopiesSelector` نفسه ويبدأ من `invoice_copies`. العدد يعود إلى `PreviousInvoiceController.printInvoice(invoice, copies:)` ثم `InvoiceOutputService.deliverBundle(copies:)` الذي يقصّه على `1..5`؛ `null` = السلوك السابق. **الحوار لا يكتب الإعداد** كي لا تُغيّر إعادةُ طباعة عرَضية عدد نسخ الطباعة التلقائية، وورقة المغسلة تبقى نسخة واحدة. حرّاس: `test/invoice_reprint_copies_dialog_test.dart` (4) · `tool/verify_reprint_copies.dart` (18).
- **نسخة الطباعة تتّبع ورقة الطابعة الفعلية (2026-10-26)**: الطبقة الأصلية في ويندوز (`printing/windows/print_job.cpp`) ترسم `FPDF_RenderPage(hDC, page, -marginLeft, -marginTop, bWidth, bHeight, ...)` أي بكامل عرض الورقة المادية من حدّها، بلا تصغير إلى المساحة القابلة للطباعة ⇒ يُقصّ أي محتوى في هامش العتاد، وفي RTL يُقصّ **يمين** الصفحة (بداية أسماء الأصناف)، ويضاعفه اختلاف مقاس تعريف الطابعة عن `invoice_paper_size`. الحل: `services/printer/print_layout.dart` (`PrintLayout`) يحمل مقاس الورقة الفعلية وهوامش العتاد بالنقاط؛ `PrinterService.printPdf({PdfRebuilder? rebuild})` يبني عبره داخل `onLayout` ويعود للبايتات الأصلية عند أي فشل. `PreparePDF.generatePdfData` و`LaundrySlipPdf.generateLaundrySlipPdf` يستعملان `PrintLayout.pageFormat` (هامش = `max(التصميم, العتاد + أمان)`؛ أمان 1.5 مم ورقي · 0.5 مم حراري · سقف 30% لكل جهة؛ الحراري يبقي ارتفاع التصميم). **بلا خريطة `printLayout` لا يتغيّر شيء** ⇒ تصدير PDF كما هو. اختبار `test/print_layout_test.dart` (7) + MediaBox في `test/doc_template_pdf_test.dart` + `tool/verify_grid_columns_wiring.dart §4`.
- **رمز QR لموقع النشاط (2026-10-30)**: `business_location` كان يُحفظ من «معلومات النشاط» والإعداد الأولي ثم **لا يُقرأ في أي مستند** (`BusinessInfoService.location` يُحمَّل ويُكاش بلا مستهلك). الآن: `services/pdf/map_qr.dart` (منطق خالص) `resolve()` يطبّع الرابط — بلا بروتوكول ⇒ `https://` · `//` ⇒ `https:` · إحداثيات خام `24.7,46.6` ⇒ `https://www.google.com/maps?q=…` · المسافات تُحذف — ويَرفض الفراغ وغير `http/https` (`javascript:` · `tel:`) والمضيف بلا نقطة وما يزيد على **512** محرفًا (كثافة وحدات QR تكبر مع المحتوى والرمز بعرض ثابت ⇒ رمز لا يُقرأ). الحقل `DocCatalog.kMapQr = 'map_qr'` في `DocSections.footer` للفاتورة وكشف الحساب **فقط** (ورقة تُسلَّم للزبون؛ ملخّص الوردية وورقة المغسلة مستندان داخليان)، `hasText` فتسميته قابلة للتحرير، `defaultEnabled: true` ولا يُطبع شيء إن كان الرابط فارغًا. الرسم: `PreparePDF._mapQrSvg(data, doc)` (شرطان: الحقل مُفعَّل + `MapQr.resolve` غير فارغ) → `Barcode.qrCode().toSvg` → `pw.SvgImage` **بعد التذييل** بمقاس `PrintVisualSize.qr(sizeMm: data['mapQrSizeMm'], maxWidth: availableWidth, maxHeight: availableHeight)` (من الإعداد ثم مقصوص على الورق). الحمولة: `bizMapUrl` في `printInvoicecontroller` · `previousinvoicecontroller` · `invoice_share_service` · `customer_statement_controller`. **مُثبت بالقياس**: مساحة رسم واحدة 84.00×84.00 نقطة مركزها منتصف A4، ويُقرأ الرمز من الصفحة المصوّرة (OpenCV) عند 300 dpi، والنسخة الحرارية 41.1 نقطة تُقرأ عند 203 dpi و150 dpi. حارس `tool/verify_map_qr.dart` (51) · مسبار `tool/_probe_map_qr_pdf.dart`.
- **حفظ PDF قرار لا أثر جانبي (2026-10-30)**: كل مستند يُكتب عبر `InvoiceOutputService.saveDocumentPdf(bytes, fileName:)` **وحده** — المجلد المختار (`invoice_pdf_directory`) أو `<المستندات>/فواتير` + `InvoicePdfNaming.dedupe` فلا كتابة فوق ملف. `savePdf` صار يبني الاسم ثم يُفوّض إليه (كتابة واحدة). **أُزيل `Directory.systemTemp` من كشف الحساب**: كان يُحفظ في مجلد مؤقّت عند فشل الطباعة فقط ⇒ رسالة «حُفظ الكشف في …\Temp\…» والملف يُمحى عند أول تنظيف. المسارات الصريحة: الأرشيف `PreviousInvoiceController.saveInvoicePdf` → `deliverBundle(print: false, savePdf: true, printSlip: false)` وزرّه محروس بـ`invoice.print` · الكشف `export(..., savePdfOnly: true)` · الوردية `ShiftController.saveShiftPdf` + مخرج ثالث في حوار الإقفال. التسمية الحرة: `InvoicePdfNaming.sanitizeStem` (محارف ويندوز · مسار ملصوق · طول 100 · فراغ ⇒ `document`) ثم `buildDocumentFileName` = `<الجذر>_<التاريخ>.pdf` — **لم** نُعِد استخدام `BackupNaming.sanitizeBackupName` لأنها تُلحق `.db`. الاستثناء المُعلَن: `invoice_share_service` يكتب في مجلد مؤقّت **ليُشارك** الملف فورًا (مستند عابر لا أرشيف). حارس `tool/verify_pdf_save_paths.dart` (33) يمنع عودة `systemTemp` وأي `writeAsBytes` في متحكّم.
- **حجم الـPDF**: النص وحده سريع (28–41ms) والصور هي العنق الوحيد (`_compressToJpeg` فارغة): صورة كاملة 287ms/3.7MB مقابل 30ms/119KB عند تصغيرها إلى 160×160. الخط ليس سببًا. أندرويد: `printing` لا ترى طابعات البلوتوث ⇒ يلزم RawBT.
- 🚨 **كل `pw.Text` عربي في أي PDF يحمل `textDirection: pw.TextDirection.rtl`** — حزمة `pdf` (3.11.3) لا تُشكّل العربية إلا بهذا الشرط: `final _textDirection = textDirection ?? Directionality.of(context);` ثم `useArabic && rtl ? arabic.convert(...) : useBidi && rtl ? bidi.logicalToVisual(...) : span.text`، و`options.dart` يجعل `useBidi=true` و`useArabic=false` افتراضيًا (ولا `--dart-define` في المشروع). بدون الاتجاه = **حروف مقطّعة ومعكوسة**.
  - **الوقوعات**: `generatePdfData` (الفاتورة) تضبطه على 22 نصًّا ⇒ سليمة **بلا أي استثناء الآن**. `generateShiftSummaryPdf` تلتفّ بـ`pw.Directionality` **باتجاه لغة المستند** (`isRtl` من الحمولة) فيرث كل محتواها الاتجاه (بما فيه `_buildRow`) ⇒ سليمة عربيًّا وإنجليزيًّا. `generateCustomerStatementPdf` كانت **بلا أي ضبط** ⇒ كشف الحساب ظهر مقطّعًا (أُصلح 2026-10-03 بمُساعد `tx`، وصار الاتجاه والجداول يتبعان `docLang` في 2026-10-29). **أي دالة PDF جديدة: إما `Directionality` أب أو `rtl` على كل نصّ.**
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
- **لوحة المفاتيح اللمسية لا تختفي (2026-10-31)**: على جهاز لمس تُظهر ويندوز لوحة المفاتيح عند التركيز على حقل ولا تُخفيها بعده — لأنها **عملية مستقلة** (`TabTip.exe` في ويندوز 10 · مضيف `TextInputHost` في ويندوز 11) لا يملكها Flutter، و`TextInput.hide` يبلّغ المحرّك فقط. الحل: قناة أصلية `laundry/touch_keyboard` بميثود `hide` في `windows/runner/flutter_window.cpp` (`FindWindowW("IPTip_Main_Window")` + `SC_CLOSE` · `FindWindowW("Windows.UI.Core.CoreWindow", "Microsoft Text Input Application")` + `SW_HIDE` · **لا `TerminateProcess`**) و`WM_ACTIVATE`/`WA_INACTIVE` يُخفيها عند الخروج من المقدّمة. في Dart: `core/platform/touch_keyboard.dart` — `TouchKeyboard.hide()` (ويندوز فقط عبر `defaultTargetPlatform` لا `dart:io` كي لا ينكسر الويب) و`hasTextFocus` (يصعد في شجرة الأسلاف لأن عقدة التركيز هي `Focus` **داخل** `EditableText`)، و`TouchKeyboardDismisser` يلفّ التطبيق في `main.dart` (تغيّر التركيز + `Listener.onPointerDown` — النقرة على خلفية **لا** تغيّر التركيز في Flutter — + دورة الحياة) ويفحص **بعد** `addPostFrameCallback` لا فورًا. عقد الاسم بين Dart وC++ يُثبته `verify_print_sizes [10]`.
- **`discounts`** كانت ناقصة من `runPendingMigrations` (موجودة في `_onCreate`/`_onUpgrade` فقط) ⇒ أُضيف `IF NOT EXISTS "discounts"`. (اكتُشف بـ`grep -n "discounts" lib/sqldb.dart`.)

> تفاصيل الأيام في `2026-09-17.md` · `2026-09-18.md` · `2026-09-19.md` · `2026-09-21.md` · `2026-10-01.md` · `2026-10-03.md`.

## 🎨 قوالب المستندات (2026-10-23 → 2026-10-24)

**الغرض**: صاحب النشاط يتحكّم في كل عنصر من المستندات الثلاثة — تفعيله
ونصّه **وحجم خطّه ووزنه وعرضه** — بلا مبرمج. كان كل نصّ مكتوبًا في الكود
(`'رقم الإيصال: '` …) وقرار إظهاره `if` على خيارات **7 منها ميّتة لا تُقرأ**.

### الملفات
| الملف | الدور |
|---|---|
| `services/pdf/doc_template.dart` | منطق خالص: `DocField` · `DocStyle` · `DocKind` · `DocTemplate` · `DocCatalog` (28 فاتورة + 17 كشف + 13 وردية + **20 ورقة مغسلة**) · `DocTemplateView` |
| `services/pdf/doc_template_service.dart` | قراءة/كتابة `settings.doc_template_invoice|statement|shift|laundry_slip` · كاش · `transport` · `mirrorLegacy` |
| `services/pdf/arabic_text.dart` | مُطبِّع «ا ل ا» قبل الرسم (منطق خالص) |
| `view/screen/settings/doc_template_screen.dart` | المحرّر (مسار `/settings/doc-template`، `settingsManage`) — **4 تبويبات** (يفتح على أيّها بـ`Get.arguments: DocKind`) · بحث · معاينة · لوحة نمط لكل حقل + **نمط موحّد للقسم** |

### الأنواع الأربعة
`DocKind.invoice` · `statement` · **`shift`** (ملخّص الوردية A6، ضُمّ
2026-10-24 عبر `shift_controller.dart` → `DocTemplateService.transport(shift)`) ·
**`laundrySlip`** (ورقة المغسلة، ضُمّت 2026-10-26 عبر مساري البيع وإعادة
الطباعة → `transport(DocKind.laundrySlip)`).
مفتاح التخزين: `doc_template_<name>`.

### ورقة المغسلة داخل القالب
- **20 حقلًا بلا أي حقل مالي**: لا سعر · خصم · ضريبة · QR · عملة · إجمالي
  مبلغ. الحارس يرفض أي كلمة مالية في السجلّ.
- الحقول المشتركة تحمل **نفس مفاتيح الفاتورة** (`logo` · `business_name` ·
  `title` · `receipt_no` · `datetime` · `customer_name` · `customer_phone` ·
  `pickup_code` · `divider` · `item_note`) فلا جدول ربط جديد.
- **`DocStyle.size` يُقرأ كنسبة** إلى حجم الحقل الافتراضي في السجلّ
  (`ratioOf`) ثم يُضرب في حجم التخطيط التكيّفي (واسع/مضغوط) — لأن الورقة
  الواحدة لها مقاسان. تعديل حجم على A4 لا يكسر 58 مم.
- **الأوزان الافتراضية 700** لاسم النشاط والعنوان والرقم والإجماليات فقط —
  الاستثناء الوحيد المسموح في حارس `[4]` (ورقة جديدة، لا سلوك قديم يُحفظ).
- الحراري: تعطيل الأقسام يخصم من الارتفاع المقدَّر
  (`estimatedHeightMm(doc:)`) فلا ورقة طويلة فارغة.

### النمط — `DocStyle{size, weight, width}`
- **الحجم** 6..**36** نقطة. الحدّ **محسوب لا تعسّفي**: أطول سطر لا يلتفّ
  (رقم الإيصال · السجل التجاري) يشغل 655.9pt عند 48 مع عرض 140%، والعرض
  القابل للطباعة في A4 بهامش 1سم = 538.6pt ⇒ أقصى حجم 39؛ اخترنا 36 بهامش 8%.
  الحارس يعيد حساب المعادلة من هامش الصفحة.
- **الوزن** 400 · 600 · 700 · 900 — **تعريض صناعي** (رسم السطر مرّتين بإزاحة
  `size × 0.0125|0.0225|0.035`). 🚨 `fontWeight` **بلا أثر** في `pdf` عند
  تمرير `font:` (`text.dart:170`)، ولهذا كانت كل الفواتير قبل 2026-10-24
  عادية رغم `bold` المكتوب. **كل الأوزان الافتراضية 400** حفاظًا على الشكل —
  إلا عناوين ورقة المغسلة (700) لأنها ورقة جديدة لا سلوك قديم لها.
- **العرض** 75..100% — **تضييق فقط**. `pw.Transform` يرسم ولا يشارك في
  التخطيط، فالتوسيع يُخرج السطر 20% من كل جهة **خارج الورقة** (مقاس
  `x0=-39.9` على صفحة 595) ويتداخل مع الخلايا المجاورة.
- 🚨 **`StackFit.passthrough` إلزامي** في `Stack` التعريض: بـ`loose` يفقد
  النصّ `textAlign` داخل خلايا الجداول.
- 🚨 **`letterSpacing` مرفوض** — يكسر اتصال الحروف العربية.
- 🚨 **`FittedBox` مرفوض** كملاءمة تلقائية — يُخطّط بلا قيود فيُلغي الالتفاف
  ويقتطع في وسط النصّ (أسوأ من الفائض).

### نقطة الرسم الوحيدة
كل نصّ مستند يمرّ من `PreparePDF._docText(text, style, font:, align:, color:)`
— وهذا ما يجعل الحارس ممكنًا: `pw.Text(` و`pw.TextStyle(` تظهر **مرة واحدة**
في الملف كله، و`fontSize:` مرة واحدة (`fontSize: style.size`).

### العقود الحاكمة
- **`toTransport()` تُصدّر `docEnabled` + `docTexts` + `docStyles` بالتحديد** —
  هي ما يقرأه `DocTemplateView.of`. أي اسم آخر ⇒ القالب لا يُقرأ **بصمت**.
- **اللغة ليست جزءًا من القالب**: `transport` يضيف `docLang` من إعداد
  `doc_language` و`docEnglish` عند الإنجليزية فقط، فلا يتكرّر قرار اللغة في
  أربعة قوالب ولا يتغيّر القالب عند تبديل لغة الشاشة.
- **الفراغ = الافتراضي** (`textOf`): لإخفاء سطر يُعطَّل مفتاحه لا يُفرَّغ نصّه.
- **الغياب = مُفعَّل** في `DocTemplate.isOn`، لكن `DocTemplateView.isOn`
  يعود **للسجلّ** عند غياب الخريطة (مسار قديم نسي تمرير القالب) — فلا مستند
  أسوأ من الافتراضي.
- **`hasStyle: false`** للشعار/الصور/QR/الفاصل — ليست نصوصًا فلا لوحة نمط لها.
- **`withField` و`withSectionStyle` تُقيِّد النمط** (`clamped()`) فلا تدخل
  قيمة شاذّة النموذج أصلًا.
- **الزرع من الخيارات القديمة مرة واحدة** عند غياب قالب محفوظ
  (`seededFromLegacy`) ⇒ لا يتغيّر شكل فاتورة قائمة بعد التحديث.
- **`mirrorLegacy`** في `SettingsController.updateSetting`: تغيير خيار من
  `invoiceDisplay` يُزامَن إلى القالب، فلا تتناقض الشاشتان.
- **`SettingGroups.invoiceOutput` يبقى في `ordered`** (حرس A9) — ولا علاقة
  له بالقالب.

### 🚨 عيب حزمة `pdf`: المسافة قبل «ا ل ا»
«رمز الاستلام» تُرسم **«رمزالاستلام»**. المسبار
`tool/_probe_arabic_space.dart` (27pt، AL-Mohanad):
مسافة عادية ❌ · `U+00A0` ❌ · `U+2009` ❌ · **مسافتان ✅**.
`ArabicText.safe` تستبدل المسافة التي تسبق `ا ل ا` بمسافتين (عاطلة التكرار
بشرط `input[i-1] != ' '`). تُطبَّق داخل `_docText` نفسها.

### حدود معروفة
- الحراري يغيّر المقاس فقط ولا يصغّر الخطوط تلقائيًا (التحكّم بالنمط).
- القالب لا يتحكّم في **مقاس الورق** (ذلك في `printing.invoice_paper_size`).
- ملخّص الوردية **داخل** القالب الآن (2026-10-24) — أُزيل من الدَّين الفني.
- 🟡 مدخل `Helvetica` زائد في خطوط PDF الفاتورة («no Unicode support»)،
  غير مؤثّر ولم يُشخَّص؛ `invoice_empty` نظيف.

### التحقّق
`tool/verify_doc_template.dart` (**329 فحصًا / 10 كتل**، مُختبَر بخمسة عيوب
مزروعة: حجم افتراضي · `StackFit.loose` · `fontSize` مكتوب · نصّ عربي في
المولّد · `letterSpacing`، وحدّ أعلى 48، ويحرس أيضًا مرور نوع الدفع بلغة
المستند ومقاس الشعار من الإعداد) · `test/doc_template_pdf_test.dart`
(13 — منها نسختان عربية/إنجليزية لكل مستند في `build/probe` للفحص البصري) ·
`test/doc_language_test.dart` (16 — استقلال اللغة في الاتجاهين) ·
`test/doc_template_screen_test.dart` (9) · `test/laundry_slip_test.dart`
(24 — منها 8 لقوالب الورقة: نصوص · نمط · تعطيل · ارتفاع حراري · خلوّ مالي) ·
`test/invoice_print_labels_test.dart` (8 — تسميات الدفع وحدود مقاس الشعار).
`tool/verify_doc_language.dart` (**39 / 7**) يحرس ختم اللغة في المسارات الأربعة.
`tool/verify_statement_pdf.py` و`verify_statement_range.py` يقرآن من السجلّ
لا من نصوص مكتوبة.

## 🌐 دعم اللغتين (2026-10-25)

### 🖨️ لغة الطباعة — تحكّم صريح (2026-10-30)
`doc_language` يحكم **كل** مستند يخرج من النظام (فاتورة · كشف حساب · ملخص
وردية · ورقة مغسلة · مشاركة واتساب) وهو مستقلّ عن `language` (الواجهة).

- **الواجهة**: `docLanguageCard(controller)` في `settings_sections.dart` —
  زرّان (العربية / English) بنفس شكل أزرار «لغة النظام»، في صفحتي
  «الفواتير والترقيم» و«الطباعة وإخراج الفاتورة».
- 🚨 **لا سطر منسدل ثانٍ**: `optionsSection` يستبعد `settingDocLanguage`
  (مثل `settingPrintFont`) كي لا يوجد تحكّمان لنفس المفتاح.
- 🚨 **معاينة الفاتورة تتبع لغة الطباعة** لا لغة الواجهة: `doc()` / `docf()`
  داخل `invoicePreviewCard` تمرّ من `kEnglish` نفسه الذي يمرّ منه الـPDF.
  (كانت `tr()` أي لغة الشاشة ⇒ يبدّل الطباعة إلى الإنجليزية فيرى معاينة
  عربية ويظنّ الزرّ لا يعمل.)
- **حدّ معروف**: اللغة **غير مخزَّنة في صفّ الفاتورة** ⇒ إعادة طباعة فاتورة
  قديمة تستخدم اللغة المختارة الآن. مكتوب في البطاقة نفسها.
- الحارس: `tool/verify_doc_language.dart` قسم `[8]` (45 فحصًا).

**الفكرة الحاكمة**: النصّ العربي هو **مفتاح** القاموس، و`tr('نصّ')` يُرجع
الإنجليزية حين تكون الواجهة إنجليزية وإلا النصّ نفسه. السبب: 2,262 نصًّا في
100 ملف؛ اختراع رمز لكل واحد يعني تعديل كل ملف لا تغليفه.

### الملفات
| الملف | الدور |
|---|---|
| `services/i18n/app_language.dart` | `enum AppLanguage {ar, en, system}` + `resolve` |
| `services/i18n/translations_en.dart` | `kEnglish` — 1,900+ مفتاحًا (عربي ⇒ إنجليزي) |
| `services/i18n/l10n.dart` | المحرّك: `t` · `tf` · `localized` + `tr()`/`trf()`/`localized()` |
| `services/i18n/doc_language.dart` | **لغة المستندات المطبوعة** (`ar`/`en`) — مستقلة عن لغة الواجهة، تُقرأ في `compute` |
| `services/i18n/ui_direction.dart` | `appTextDirection` — الجسر الوحيد إلى `dart:ui` |
| `controller/settings/locale_controller.dart` | القراءة/الكتابة + `Get.forceAppUpdate()` |
| `services/payment/payment_method.dart` | طرق الدفع: مفاتيح تخزين + تسميات عرض |
| `services/invoice/processing_status.dart` | حالات المصنعية: مفاتيح + تسميات |

### عقود
- **`L10n` خالص** (لا Flutter ولا قاعدة) ⇒ يُشغَّل بـ`dart run` في الحرّاس.
  كل ما يحتاج `dart:ui` يذهب إلى `ui_direction.dart`.
- **`t()` على مرحلتين**: مطابقة حرفية، ثم مطابقة بعد **طيّ المسافات**
  (`_flatEnglish` تُبنى مرة واحدة). بدونها يفشل أي نصّ مكتوب على عدّة أسطر.
- **لا `TextDirection.rtl` في أي ملف واجهة** — يُقرأ من `appTextDirection`.
  الحارس يفشل إن عادت. الاستثناءان: `ui_direction.dart` و`preparePDF.dart`.
- **`pw.TextDirection` في PDF يتبع لغة المستند** (`docLang`)، و`ArabicText.safe`
  للعربية فقط.
- 🚨 **لغة المستند قرار مستقلّ عن لغة الواجهة** (2026-10-29، بعد طلب صريح):
  `DocLanguage {ar, en}` + مفتاح `doc_language` في «ما يظهر على الفاتورة»،
  وافتراضيه **عربي** لأنه المطلوب نظامًا. `DocTemplateService.transport()`
  يكتب `data['docLang'] = settings.docLanguage.code` (لا `L10n.language.code`)
  ويُرفق `docEnglish` للإنجليزية فقط، والمولّد يستعمل `_rtlOf(data)` و
  `DocTemplateView.of` يستعمل `isEnglishDoc`. `_rtlOf` يسقط للعربية عند غياب
  `docLang`، لا للغة الشاشة — فلا يعيد مسار قديم ربط الورقة بالواجهة.
  يغطّي الفاتورة · كشف الحساب · ملخص الوردية · ورقة المغسلة. تاريخ
  `map_data` يُخزَّن محايد اللغة (`yyyy-MM-dd HH:mm:ss`) لأن إعادة الطباعة قد
  تكون بلغة مختلفة، فلا تُطبع «ص» في نسخة إنجليزية.
  **قاعدة عامّة: كود `compute` لا يقرأ حالة عامّة — تُمرَّر له في الحمولة.**
- **`DocTemplateView.text()`**: الإنجليزية **مشروطة** بـ`isEnglishDoc` —
  بدون الشرط تُطبع فاتورة عربية بالإنجليزية.
- **القيم المخزَّنة مفاتيح لا نصوص**: `cash|card|credit|balance|cash_refund` ·
  `received|in_progress|ready|delivered`. الترحيل في `sqldb.dart`
  (`payment_method_key_v1` · `processing_status_key_v1`) مرة واحدة، لكن
  **القراءة تقبل العربي أيضًا** فلا تعتمد على نجاح الترحيل.
- **الأعمدة `*_en` تُضاف في `_ensureBilingualColumns`** (تعمل كل فتح) —
  وليست بديلًا عن إضافتها في `_onCreate`/`_onUpgrade` للجداول الجديدة.
- **الفراغ = العربي**: العمود الإنجليزي `NULL`/فارغ ⇒ يُعرض العربي. **لا نسخ
  آلي** من العربي (وإلا صارت التراجم غير قابلة للاكتشاف).
- 🚨 **`localized()` على ثلاث درجات** (2026-10-25، بعد بلاغ «الأصناف تبقى
  عربية»): `_en` صالح ⇒ القاموس (`_dictionaryFor`: مطابقة حرفية ثم مُطبَّعة)
  ⇒ العربي. الدرجة الثانية ضرورية لأن الصفوف التي أُنشئت **قبل** وجود العمود
  قيمتها `NULL` للأبد. **`_en` الصريح يتقدّم دائمًا** (المستخدم قد يسمّي
  صنفه بنفسه).
- 🚨 **لا تقرأ اسم صنف خامًّا في أي سطح عرض**: `'${item['vestments']}'` أو
  `data['clothing_name']` ⇒ عربي أبدي في الواجهة الإنجليزية. المواضع التي
  أُصلحت: `preparePDF` · `invoice_share_service` · `previousinvoice` ·
  `customviewinvoice` · `shifts_history_screen` · `dashboard_controller`.
- **التجميع على العربي والعرض على المترجَم**: `StatementItem`/`ItemSummary`
  تحمل `name` + `nameEn`، والـ`summary` مفتاحه الاسم **العربي**. لو خُزِّن
  المترجَم لانقسم الصنف الواحد إلى مجموعتين عند تبديل اللغة.
- **بيانات البذر مصدرها القاموس**: `_insertDefaultClothing` يقرأ `kEnglish`
  (كانت `namesEn` خاصة مكرّرة لا تراها الواجهة).
- **البحث غير حسّاس لحالة الأحرف** ويقرأ الاسم المعروض (`toLowerCase` على
  الطرفين، والمفتاح يُحسب مرّة واحدة خارج `where`).

- **حقوق المطوّر تمرّ من `tr`**: `AppInfo.developerNameKey`/`developerCreditKey`
  + `get developerName => tr(...)`. كانت `const` عربية ⇒ لا تُترجم أبدًا.
  المصدر واحد والمستهلك واحد (`DeveloperCredit`) في 12 شاشة.
- 🚨 **رمز العملة يتبع اللغة**: `Currency.symbol` = `tr('ر.س')` ⇒ `SAR`
  بالإنجليزية. لا تكتب `ر.س` حرفيًّا في جملة تُعرَض؛ إمّا داخل مفتاح `trf`
  (فالقيمة الإنجليزية تقول `SAR`) أو `${Currency.symbol}`.
  `Currency.of(stored)` تُبقي رمز المستخدم (`$` · `EUR`) كما هو.
- **الرسائل الموسومة `trf` لا تُبنى بالدمج**: `'متبقٍّ $x ر.س'` لا تُترجم أبدًا
  (المفتاح لا يطابق). الصواب `trf('متبقٍّ {0} ر.س', [x])` — الترتيب في
  الإنجليزية يختلف، والرموز تُستبدل **بعد** الترجمة.
- **لا اقتباس متداخل داخل literal**: `'... ${sub['name']}'` يقطع استخراج
  النصوص. ارفع القيمة إلى متغيّر مستقلّ أولًا.

### الحراسة
`tool/verify_i18n.dart` — **92 فحصًا / 9 كتل**: اللغة · المحرّك · سلامة القاموس
(كل مفتاح عربي · لا ترجمة وهمية) · التركيب (`main` + `pubspec`) · الأعمدة ·
الاتجاه والطباعة · القيم المخزَّنة · **السقف المتحرّك** · العملة والرسائل.

`tool/verify_doc_language.dart` — **39 فحصًا / 7 كتل**: النوع الخالص ·
تسجيل الإعداد وتطابق القيم · ختم `docLang` في `transport` بلا `L10n` ·
المسارات الأربعة · خلوّ مسار الطباعة من لغة الواجهة · ثبات المفتاح ·
**كل نصّ افتراضي في القوالب له ترجمة إنجليزية**.
`test/doc_language_test.dart` (16) يثبت الاتجاهين: واجهة عربية + فاتورة
إنجليزية، وواجهة إنجليزية + فاتورة عربية.

- 🚨 **`kUntranslatedCeiling = 0`** (2026-10-25): 2,090 نصًّا · 2,086 مترجمًا ·
  **0 متبقٍّ**. أي نصّ واجهة جديد بلا ترجمة يُفشل الحارس فورًا.
- **`kNonUiLiterals` (38)** — استثناء صريح مُدقَّق لما **لا يجوز** ترجمته:
  سجلّات `debugPrint` · تعبيرات نمطية وجداول أرقام عربية · أسماء ملفّات ·
  نصّ له شقيق `_en` في نفس الصفّ. حارسان يمنعان التهريب: الاستثناء لا يكون
  موجودًا في القاموس، وكل استثناء موجود فعلًا في الكود.
- **المستخرج يفكّ `\n`/`\t` فقط** ويُبقي `\-`/`\s` — وإلا صار التعبير
  النمطي `[,،s]+` نصًّا آخر فلا يُطابق استثناءه.
من كتلته الثانية: **كل اسم في بيانات البذر له ترجمة** — تُستخرج الأسماء من
`auth_controller.dart` نفسه بـregex، فأي صنف يُضاف لاحقًا بلا ترجمة يُفشل
الحارس فورًا.
`tool/scan_i18n_gaps.py` — ماسح Dart (ثلاثي الاقتباس · تعليقات · فكّ `\n`)
لقياس الفجوة الحقيقية؛ `grep` يعطي أرقامًا كاذبة على النصوص متعدّدة الأسطر.
