// القاموس الإنجليزي — **منطق خالص** (بلا Flutter ولا قاعدة بيانات).
//
// ═══════════════════════════════════════════════════════════════════════════
// لماذا النصّ العربي هو **المفتاح** لا رمز مخترع (`settings.tax.rate`)؟
// ═══════════════════════════════════════════════════════════════════════════
// 1. النظام فيه **2,987 نصًّا** عربيًّا في 100 ملف. اختراع رمز لكل واحد يعني
//    تعديل الملفّ كاملًا لا تغليفه، ويجعل المراجعة مستحيلة.
// 2. **الانتقال التدريجي**: ملفّ لم يُترجم بعد يعمل كما هو (العربي يظهر)، فلا
//    تنكسر شاشة لأن ترجمتها لم تُكتب.
// 3. **الحارس يقيس التقدّم**: أي نصّ عربي في الكود ولم يكن مفتاحًا هنا = نقص
//    معروف العدد، لا خطأ صامت.
//
// الثمن: تعديل صياغة نصّ عربي واحد يُفقد ترجمته (يصير «غير مترجم»). لذلك
// الحارس يفشل عند **أي** نصّ عربي بلا ترجمة، فتظهر الفجوة فورًا لا بعد شهور.
//
// القاعدة الحاكمة: **لا نصّ إنجليزي مكتوب في أي مكان آخر.** كل ما يظهر
// بالإنجليزية يمرّ من هنا.

/// ترجمة نصّ عربي إلى الإنجليزية. المفتاح = النصّ العربي **حرفيًا**.
const Map<String, String> kEnglish = <String, String>{
  // ═══ عام ═══
  'نجاح': 'Success',
  'خطأ': 'Error',
  'فشل': 'Failed',
  'فشل العملية': 'Operation failed',
  'نجاح العملية': 'Operation succeeded',
  'تم': 'Done',
  'حفظ': 'Save',
  'إلغاء': 'Cancel',
  'تأكيد': 'Confirm',
  'موافق': 'OK',
  'حذف': 'Delete',
  'تعديل': 'Edit',
  'إضافة': 'Add',
  'بحث': 'Search',
  'طباعة': 'Print',
  'إغلاق': 'Close',
  'رجوع': 'Back',
  'التالي': 'Next',
  'السابق': 'Previous',
  'الكل': 'All',
  'لا': 'No',
  'نعم': 'Yes',
  'الاسم': 'Name',
  'الهاتف': 'Phone',
  'العنوان': 'Address',
  'التاريخ': 'Date',
  'الوقت': 'Time',
  'المبلغ': 'Amount',
  'الإجمالي': 'Total',
  'الخصم': 'Discount',
  'الضريبة': 'VAT',
  'المدفوع': 'Paid',
  'المتبقي': 'Remaining',
  'الزبون': 'Customer',
  'الزبائن': 'Customers',
  'الصنف': 'Item',
  'الأصناف': 'Items',
  'الكمية': 'Qty',
  'السعر': 'Price',
  'ملاحظات': 'Notes',
  'ملاحظة': 'Note',
  'حالة': 'Status',
  'نشط': 'Active',
  'غير نشط': 'Inactive',
  'الوردية': 'Shift',
  'الورديات': 'Shifts',
  'التقارير': 'Reports',
  'الإعدادات': 'Settings',
  'المستخدم': 'User',
  'المستخدمون': 'Users',
  'الصلاحيات': 'Permissions',
  'الأدوار': 'Roles',
  'النسخ الاحتياطي': 'Backup',
  'الترخيص': 'License',
  'الاشتراكات': 'Subscriptions',
  'المصروفات': 'Expenses',
  'الخصومات': 'Discounts',
  'الفاتورة': 'Invoice',
  'الفواتير': 'Invoices',
  'نقطة البيع': 'Point of sale',
  'الشاشة الرئيسية': 'Home',
  'لوحة التحكم': 'Dashboard',
  'من': 'From',
  'إلى': 'To',
  'اليوم': 'Today',
  'الأمس': 'Yesterday',
  'هذا الشهر': 'This month',
  'الفاتورة الضريبية': 'Tax invoice',
  'ريال': 'SAR',
  'ر.س': 'SAR',

  // ═══ المظهر واللغة ═══
  'المظهر': 'Appearance',
  'حجم الخط والواجهة': 'Text size and interface',
  'حجم الخط': 'Text size',
  'اللغة': 'Language',
  'لغة النظام': 'System language',
  'العربية': 'Arabic',
  'لغة الجهاز': 'Device language',
  'تُطبَّق على كل شاشات النظام فورًا بلا إعادة تشغيل.':
      'Applies to every screen immediately, no restart.',

  // ═══ ترقيم الفواتير ═══
  'بداية ترقيم الفواتير': 'Invoice numbering start',
  'بادئة رقم الفاتورة': 'Invoice number prefix',
  'حشو رقم الفاتورة': 'Invoice number padding',
  'عدد الفواتير في الصفحة': 'Invoices per page',
  'العملة': 'Currency',
  'نصّ يُسبق رقم الفاتورة المعروض (مثال: INV-). اتركه فارغًا لِلا بادئة.':
      'Text prefixed to the displayed invoice number (e.g. INV-). Leave empty for none.',
  'عدد الخانات بإضافة أصفار (6 ⇒ 000123). الصفر يعني بلا حشو.':
      'Digit count with leading zeros (6 ⇒ 000123). Zero means no padding.',
  'حجم الدفعة في شاشة الفواتير السابقة (تحميل عند التمرير).':
      'Batch size in the previous invoices screen (load on scroll).',

  // ═══ سلوك البيع ═══
  'إلزام اختيار زبون': 'Require customer selection',
  'السماح بالبيع الآجل': 'Allow credit sales',
  'السماح بالخصومات': 'Allow discounts',
  'عند التعطيل لا يُقبل أي كود خصم في نقطة البيع.':
      'When off, no discount code is accepted at the point of sale.',
  'الحد الأدنى للفاتورة': 'Minimum invoice amount',
  'أقل مبلغ مسموح لفاتورة جديدة. صفر = بلا حدّ.':
      'Lowest amount allowed for a new invoice. Zero means no limit.',
  'طباعة تلقائية في نقطة البيع': 'Auto-print at the point of sale',
  'تأكيد قبل الدفع': 'Confirm before payment',
  'طريقة الدفع الافتراضية': 'Default payment method',
  'نبرة نجاح البيع': 'Sale success sound',
  'ترتيب الأصناف في شاشة البيع': 'Item order on the sales screen',
  'نسخة من طباعة الفاتورة بعد البيع مباشرة.':
      'Print a copy right after the sale.',
  'حوار تأكيد قبل حفظ الفاتورة.':
      'Confirmation dialog before saving the invoice.',
  'الطريقة المحدَّدة مسبقًا عند فتح الدفع.':
      'Method preselected when the payment dialog opens.',
  'تشغيل صوت عند إتمام البيع.': 'Play a sound when the sale completes.',
  'الطريقة التي تُعرض بها بطاقات الأصناف عند البيع.':
      'How item cards are ordered on the sales screen.',
  'عدد أعمدة الأصناف والخدمات': 'Items and services columns',
  'عدد البطاقات في الصف الواحد في شبكة الأصناف والخدمات.':
      'Number of cards per row in the items and services grid.',
  'عدد الأعمدة': 'Column count',
  'تلقائي': 'Auto',
  'عمودان': 'Two columns',
  '3 أعمدة': '3 columns',
  '4 أعمدة': '4 columns',
  '5 أعمدة': '5 columns',
  '6 أعمدة': '6 columns',
  'تعذّر حفظ عدد الأعمدة': 'Could not save the column count',

  // ═══ ما يظهر على الفاتورة ═══
  'لغة الفاتورة والمستندات': 'Invoice & document language',
  'لغة طباعة الفواتير والكشوف، مستقلة تمامًا عن لغة النظام. العربية هي المطلوبة نظامًا.':
      'Language used for printed invoices and statements, independent of the system language. Arabic is the legally required language.',
  'عنوان الفاتورة': 'Invoice title',
  'إظهار الشعار': 'Show logo',
  'حجم شعار الفاتورة (مم)': 'Invoice logo size (mm)',
  'إظهار الرقم الضريبي': 'Show tax number',
  'إظهار السجل التجاري': 'Show CR number',
  'إظهار العنوان الوطني': 'Show national address',
  'إظهار اسم المستخدم': 'Show cashier name',
  'إظهار التاريخ والوقت': 'Show date and time',
  'إظهار رمز الاستلام': 'Show pickup code',
  'إظهار هاتف الزبون': 'Show customer phone',
  'إظهار سطر الضريبة': 'Show VAT line',
  'إظهار الأساس قبل الضريبة': 'Show pre-VAT base',
  'إظهار سطر الخصم': 'Show discount line',
  'إظهار المدفوع': 'Show paid amount',
  'إظهار المتبقي': 'Show remaining',
  'إظهار رمز QR': 'Show QR code',
  'تذييل الفاتورة': 'Invoice footer',
  'تقريب الإجمالي': 'Round the total',
  'النصّ المطبوع أعلى الفاتورة (مثال: فاتورة ضريبية مبسطة).':
      'Text printed at the top of the invoice (e.g. Simplified tax invoice).',
  'طبع شعار النشاط أعلى الفاتورة.': 'Print the business logo on the invoice.',
  'عرض الشعار المربّع أعلى الفاتورة بالمليمتر (53 = الحجم الافتراضي ≈ 5.3 سم).':
      'Square logo width at the top of the invoice in millimetres (53 = the default size ≈ 5.3 cm).',
  'طبع الرقم الضريبي للنشاط على الفاتورة.':
      'Print the business tax number on the invoice.',
  'طبع رقم السجل التجاري على الفاتورة.':
      'Print the commercial registration number on the invoice.',
  'طبع العنوان الوطني المختصر على الفاتورة.':
      'Print the short national address on the invoice.',
  'طبع اسم الكاشير الذي أصدر الفاتورة.':
      'Print the name of the cashier who issued the invoice.',
  'طبع تاريخ ووقت إصدار الفاتورة.': 'Print the invoice issue date and time.',
  'طبع رمز استلام الغسيل على الفاتورة.':
      'Print the laundry pickup code on the invoice.',
  'طبع رقم هاتف الزبون على الفاتورة.':
      'Print the customer phone on the invoice.',
  'طبع سطر ضريبة القيمة المضافة في تفصيل الفاتورة.':
      'Print the VAT line in the invoice breakdown.',
  'طبع المبلغ قبل الضريبة بجانب الإجمالي.':
      'Print the pre-VAT amount next to the total.',
  'طبع قيمة الخصم إن وُجد.': 'Print the discount amount when present.',
  'طبع المبلغ المدفوع على الفاتورة.': 'Print the paid amount on the invoice.',
  'طبع المبلغ المتبقي على الفاتورة.':
      'Print the remaining amount on the invoice.',
  'نصّ حرّ يُطبع أسفل الفاتورة (شروط · شكر · ضمان).':
      'Free text printed at the bottom of the invoice (terms, thanks, warranty).',
  'تقريب المبلغ المستحق لأقرب وحدة نقدية عند الطباعة.':
      'Round the amount due to the nearest currency unit when printing.',

  // ═══ الطباعة ═══
  'خطّ الطباعة': 'Print font',
  'مقاس الفاتورة': 'Invoice paper size',
  'مقاس ملخص الوردية': 'Shift summary paper size',
  'مقاس كشف الحساب': 'Statement paper size',
  'مقاس ملصق القطع': 'Item label size',
  'اسأل عن المقاس عند الطباعة': 'Ask for paper size when printing',
  'طباعة تلقائية بعد البيع': 'Auto-print after sale',
  'مقاس الطباعة التلقائية': 'Auto-print paper size',
  'عدد نسخ الفاتورة': 'Invoice copies',
  'تذييل الإيصال الحراري': 'Thermal receipt footer',
  'الطباعة على الطابعة المختارة تلقائيًا': 'Print to the selected printer',
  'طباعة الفاتورة على الطابعة عند البيع': 'Print the invoice at sale time',
  'طباعة ورقة المغسلة مع الفاتورة': 'Print the laundry slip with the invoice',
  'تُطبع بعد فاتورة العميل ورقة داخلية للمحل بنفس مقاس الورق المختار، بلا أسعار أو ضريبة، وتحتوي رقم الفاتورة والأصناف والكميات ورمز الاستلام. تُطبع كمهمة مستقلة ليقطعها القاطع التلقائي وحدها.':
      'After the customer invoice, an internal shop copy is printed on the same paper size, with no prices or tax. It shows the invoice number, items, quantities and pickup code. It is sent as a separate job so an auto-cutter can cut it independently.',
  'حفظ نسخة PDF عند إصدار الفاتورة': 'Save a PDF copy when issuing',
  'مجلد حفظ الفواتير': 'Invoice PDF folder',
  // ═══ ورقة المغسلة (نسخة المحل) ═══
  'ورقة المغسلة': 'Laundry slip',
  'ورقة المغسلة - نسخة المحل': 'Laundry slip - shop copy',
  'لا تُسلَّم للعميل - تُرفق بالكيس':
      'Not for the customer - attach to the bag',
  'رقم الفاتورة': 'Invoice number',
  'العميل': 'Customer',
  'الخدمة': 'Service',
  'إجمالي القطع': 'Total pieces',
  'عدد الأصناف': 'Items count',
  'توقيع العامل': 'Worker signature',
  'طباعة ورقة المغسلة فقط': 'Print laundry slip only',
  'لا توجد أصناف في هذه الفاتورة': 'No items on this invoice',
  'تعذّر تجهيز ورقة المغسلة — الخطّ أو الأصول غير جاهزة.':
      'Could not prepare the laundry slip — the font or assets are not ready.',
  'فاتورة #{0} ({1}/{2})': 'Invoice #{0} ({1}/{2})',
  'ورقة المغسلة #{0}': 'Laundry slip #{0}',
  'تعذّر حفظ نسخة PDF لورقة المغسلة: {0}':
      'Could not save the laundry slip PDF: {0}',
  'ملف ورقة المغسلة فارغ — لم يُرسَل شيء إلى الطابعة.':
      'The laundry slip file is empty — nothing was sent to the printer.',
  'تعذّر تجهيز ورقة المغسلة: {0}': 'Could not prepare the laundry slip: {0}',
  // ═══ تحرير قالب ورقة المغسلة ═══
  'نسخة المحل': 'Shop copy',
  'صورة الشعار أعلى ورقة المغسلة.':
      'The logo image at the top of the laundry slip.',
  'عنوان الورقة': 'Slip title',
  'مثل: ورقة المغسلة.': 'For example: Laundry slip.',
  'العنوان الفرعي': 'Subtitle',
  'مثل: نسخة المحل. يُطبع بجانب العنوان.':
      'For example: Shop copy. Printed next to the title.',
  'تنبيه الورقة': 'Slip notice',
  'سطر صغير تحت العنوان (لا تُسلَّم للعميل…).':
      'A small line under the title (not for the customer…).',
  'البادئة والرقم الكبير داخل الإطار.':
      'The prefix and the large number inside the box.',
  'البادئة قبل تاريخ الفاتورة.': 'The prefix before the invoice date.',
  'يظهر فقط عند وجود اسم.': 'Only appears when a name exists.',
  'يظهر فقط عند وجود رقم.': 'Only appears when a number exists.',
  'الخطوط بين الترويسة والأصناف والإجماليات.':
      'The rules between the header, items and totals.',
  'اسم الصنف': 'Item name',
  'عنوان عمود الصنف ونصّ الاسم في النسخة المضغوطة.':
      'The item column heading and the name in the compact layout.',
  'عنوان عمود الخدمة ونصّها.': 'The service column heading and its text.',
  'عنوان عمود العدد والرقم داخل الشارة.':
      'The quantity column heading and the badge number.',
  'ملاحظة البند': 'Item note',
  'رسالة «لا توجد أصناف»': 'The "No items" message',
  'تظهر إذا كانت الفاتورة بلا بنود.': 'Shown when the invoice has no items.',
  'البادئة قبل مجموع القطع.': 'The prefix before the total pieces.',
  'البادئة قبل عدد الأسطر.': 'The prefix before the line count.',
  'سطر التوقيع الأول.': 'The first signature line.',
  'سطر التوقيع الثاني.': 'The second signature line.',
  'هاتف النشاط': 'Business phone',
  'رقم الهاتف أسفل الورقة.': 'The phone number at the bottom of the slip.',
  'قالب ورقة المغسلة': 'Laundry slip template',
  'نسخة المحل — كل عنصر: تفعيل ونصّ وحجم ووزن':
      'Shop copy — every element: visibility, text, size and weight',
  'تحرير قالب ورقة المغسلة': 'Edit the laundry slip template',
  'تصميم الفاتورة وكشف الحساب وملخص الوردية وورقة المغسلة — نصًّا ونمطًا':
      'Design the invoice, statement, shift summary and laundry slip — text and style',
  'غسيل + كوي': 'Wash + iron',
  'المقاس الافتراضي لطباعة ملخص إغلاق الوردية.':
      'Default paper size for the shift close summary.',
  'المقاس الافتراضي لطباعة كشف حساب الزبون.':
      'Default paper size for the customer statement.',
  'مقاس ملصق تتبّع قطع الغسيل (يُطبع مع لوحة المصنعية).':
      'Label size for laundry piece tracking (printed with the processing board).',
  'طباعة الفاتورة تلقائيًا بمجرد إتمام البيع.':
      'Print the invoice automatically once the sale completes.',
  'المقاس المستخدم عند الطباعة التلقائية.': 'Paper size used for auto-print.',
  'عدد النسخ المطبوعة في كل عملية.': 'Number of copies per print.',
  'نصّ يُطبع أسفل الإيصال الحراري فقط.':
      'Text printed at the bottom of the thermal receipt only.',

  // ═══ الضريبة ═══
  'تفعيل الضريبة': 'Enable VAT',
  'نسبة الضريبة': 'VAT rate',
  'الأسعار شاملة الضريبة': 'Prices include VAT',
  'إخضاع الاشتراكات للضريبة': 'Apply VAT to subscriptions',
  'إخضاع رسوم التوصيل للضريبة': 'Apply VAT to delivery fees',
  'تصنيفات معفاة من الضريبة': 'VAT-exempt categories',
  'إظهار الضريبة في كشف الحساب': 'Show VAT on the statement',
  'إظهار الضريبة في تقرير الصندوق': 'Show VAT in the cash report',
  'النشاط مسجَّل لدى الهيئة': 'Business is ZATCA-registered',
  'رمز QR (المرحلة الأولى)': 'QR code (phase 1)',
  'تجهيز المرحلة الثانية': 'Phase 2 readiness',
  'أساس الإقرار الضريبي': 'Tax return basis',
  'تفعيل ضريبة المدخلات': 'Enable input VAT',
  'نسبة ضريبة المدخلات الافتراضية': 'Default input VAT rate',
  'إلزام رقم فاتورة المورّد': 'Require supplier invoice number',
  'عند التفعيل تُحتسب الضريبة على رسوم التوصيل أيضًا.':
      'When on, VAT is also applied to delivery fees.',
  'إظهار أعمدة الأساس والضريبة والإجمالي الضريبي في الكشف.':
      'Show base, VAT and VAT-inclusive total columns on the statement.',
  'عند التفعيل يُدخَل مبلغ ضريبة المدخلات في كل مصروف خاضع.':
      'When on, input VAT is captured for every taxable expense.',
  'النسبة المعروضة افتراضيًا عند إدخال مصروف خاضع.':
      'Rate prefilled when entering a taxable expense.',
  'تنبيه عند حفظ مصروف خاضع بلا رقم فاتورة ضريبية.':
      'Warn when saving a taxable expense without a tax invoice number.',

  // ═══ الائتمان والتحصيل ═══
  'حدّ الائتمان الافتراضي': 'Default credit limit',
  'نسبة مخصّص الديون المشكوكة': 'Bad debt provision rate',
  'منع البيع عند تجاوز حدّ الائتمان': 'Block sales beyond the credit limit',
  'إظهار تفصيل ضريبي في الكشف': 'Show VAT breakdown on the statement',
  'تذييل كشف الحساب': 'Statement footer',
  'الحدّ المطبَّق على الزبون بلا حدّ خاص. صفر = بلا حدّ.':
      'Limit applied to customers without their own. Zero means no limit.',
  'نسبة تُحمَّل على الديون المتجاوزة 90 يومًا في تقارير الأعمار.':
      'Rate applied to debt over 90 days in aging reports.',
  'يتبع تفعيل الضريبة؛ يضيف ملخّصًا ضريبيًا لكشف الحساب.':
      'Follows VAT enablement; adds a VAT summary to the statement.',
  'نصّ يُطبع أسفل كشف الحساب.': 'Text printed at the bottom of the statement.',

  // ═══ الاشتراكات ═══
  'نسبة التحذير من سقف الاستخدام': 'Usage cap warning percentage',
  'إلزام سداد الاشتراك قبل الاستخدام': 'Require payment before use',
  'مهلة السماح بعد انتهاء التغطية (أيام)':
      'Grace period after coverage ends (days)',
  'تجديد الاشتراك تلقائيًا': 'Auto-renew subscriptions',
  'يوم بداية دورة الاشتراك': 'Subscription cycle start day',
  'يُنبَّه الكاشير عند بلوغ هذه النسبة من سقف الاشتراك.':
      'Warn the cashier at this percentage of the usage cap.',
  'عند التفعيل لا تُغطّى فاتورة باشتراك غير مسدَّد.':
      'When on, an unpaid subscription does not cover any invoice.',
  'أيام تبقى فيها التغطية نافذة بعد انتهائها قبل اعتبارها منتهية.':
      'Days the coverage stays valid after expiry before it is considered ended.',
  'عند التفعيل يُولَّد استحقاق الدورة الجديدة تلقائيًا عند الإغلاق.':
      'When on, the next cycle charge is generated automatically on close.',
  'اليوم من الشهر الذي تبدأ فيه دورة الفوترة (1 = بداية الشهر).':
      'Day of month the billing cycle starts (1 = month start).',

  // ═══ المصنعية ═══
  'لوحة المصنعية': 'Processing board',
  'تتبع الغسيل من الاستلام حتى التسليم':
      'Track laundry from intake to delivery',
  'ابحث برمز الاستلام أو رقم الفاتورة أو اسم الزبون...':
      'Search by pickup code, invoice number or customer name...',
  'قيد التنفيذ: {0}': 'In progress: {0}',
  'جاهز: {0}': 'Ready: {0}',
  'متوسط الإنجاز: {0}': 'Average completion: {0}',
  'لا توجد فواتير قيد التنفيذ': 'No invoices in progress',
  'عند إصدار فواتير جديدة ستظهر هنا في لوحة المصنعية':
      'New invoices will appear here on the processing board.',
  'لا توجد نتائج في هذا التبويب': 'No results in this tab',
  'جرّب تغيير التبويب أو كلمة البحث':
      'Try another tab or a different search term.',
  'غير مستلمة 1+ يوم': 'Uncollected 1+ day',
  'متأخر 3+ أيام': 'Late 3+ days',
  'اختر العامل': 'Select worker',
  'العامل: {0}': 'Worker: {0}',
  'بدء التنفيذ': 'Start processing',
  'تأكيد التسليم': 'Confirm delivery',
  'تسليم {0}': 'Deliver {0}',
  'سداد المتبقي': 'Settle remaining',
  'على الزبون سداد {0} ر.س نقداً عند الاستلام.':
      'The customer owes {0} SAR cash on pickup.',
  'هل تريد تأكيد التسليم والسداد؟': 'Confirm delivery and payment?',
  'إشعار العميل بالجاهزية (واتساب)': 'Notify customer (WhatsApp)',
  'تعذر فتح واتساب — تأكد من حفظ رقم العميل':
      'Could not open WhatsApp — make sure the customer phone is saved.',
  'رمز الاستلام: {0}': 'Pickup code: {0}',
  'فاتورة #{0}': 'Invoice #{0}',
  'مدة الانتظار: {0}': 'Waiting: {0}',
  'الإجمالي: {0} ر.س': 'Total: {0} SAR',
  'متبقي {0}': 'Due {0}',
  'تم تحديث حالة الفاتورة رقم #{0} إلى "{1}"':
      'Invoice #{0} status changed to "{1}"',
  'تم تسليم الفاتورة رقم #{0}': 'Invoice #{0} delivered',
  'حذف البند': 'Delete item',
  'حذف البند؟': 'Delete item?',
  // ═══ بنود الفاتورة: الدمج والتعديل (2026-10-31) ═══
  'تعديل البند': 'Edit item',
  'إجمالي البند': 'Line total',
  'سعر الوحدة': 'Unit price',
  'زيادة الكمية': 'Quantity increased',
  '{0} — {1}: الكمية في الفاتورة صارت {2}':
      '{0} — {1}: the invoice quantity is now {2}',
  'أُضيف كبند منفصل': 'Added as a separate line',
  '{0} — {1}: الملاحظة مختلفة عن البند الموجود، فبقيا سطرين.':
      '{0} — {1}: the note differs from the existing line, so they stayed separate.',
  '{0} — {1}: صورة البقعة مختلفة، فبقيا سطرين.':
      '{0} — {1}: the stain photo differs, so they stayed separate.',
  '{0} — {1}: سعر الوحدة مختلف عن البند الموجود.':
      '{0} — {1}: the unit price differs from the existing line.',
  'دُمج البندان': 'Lines merged',
  '{0} — {1}: صار البند مطابقًا لبند موجود، فدُمجت الكميتان في سطر واحد ({2}).':
      '{0} — {1}: this line now matches an existing one, so both quantities merged into a single line ({2}).',
  'في الفاتورة: {0}': 'In invoice: {0}',
  'الصنف غير موجود في قائمة الأسعار — عدّل السعر يدويًّا':
      'Item not found in the price list — edit the price manually',
  'سعر «{0}» من قائمة الأسعار: {1}': 'Price of "{0}" from the price list: {1}',
  'الكمية يجب أن تكون بين {0} و{1}': 'Quantity must be between {0} and {1}',
  'سعر غير صالح — اكتب رقمًا موجبًا': 'Invalid price — enter a positive number',
  'بقع، تلف، قصّات… (اتركه فارغًا للحذف)':
      'Stains, damage, cuts… (leave empty to remove)',

  // ═══ الأصناف ═══
  'اسم اللبس': 'Item name',
  'الاسم بالإنجليزية (اختياري)': 'English name (optional)',
  'تعديل الصنف': 'Edit item',
  'لا توجد أصناف بعد': 'No items yet',
  'أضف أصنافاً من شاشة إضافة لبس': 'Add items from the add-item screen.',
  'غسيل وكوي عادي': 'Regular wash and iron',
  'غسيل وكوي مستعجل': 'Express wash and iron',
  'كوي عادي': 'Regular ironing',
  'كوي مستعجل': 'Express ironing',

  // ═══ الإعدادات ═══
  'حول النظام': 'About',
  'ترخيص النظام': 'System license',
  'معلومات النشاط التجاري': 'Business information',
  'الاسم · الهاتف · العنوان · الرقم الضريبي · السجل التجاري':
      'Name · phone · address · tax number · CR number',
  'الإصدار ومعلومات المطوّر': 'Version and developer info',
  'الطابعة الافتراضية · خطّ الطباعة · الطباعة عند البيع · حفظ PDF':
      'Default printer · print font · print on sale · save PDF',
  'الطباعة وإخراج الفاتورة': 'Printing and invoice output',
  'الفواتير والترقيم': 'Invoices and numbering',
  'معاينة الفاتورة · الترقيم · ما يظهر عليها':
      'Invoice preview · numbering · visible fields',
  'الاحتفاظ بالبيانات': 'Data retention',
  'مدة الاحتفاظ بالفواتير والحذف التلقائي': 'Invoice retention and auto-delete',
  'العمليات والمصنعية': 'Operations and processing',
  'تتبّع الغسيل · مصنعية العمال · نقطة البيع':
      'Laundry tracking · worker labor · point of sale',
  'الذمم والاشتراكات': 'Receivables and subscriptions',
  'الذمم والائتمان · الاشتراكات · الزبائن · نقاط الولاء':
      'Receivables and credit · subscriptions · customers · loyalty',
  'حالة الاشتراك · تاريخ الانتهاء · فحص الصلاحية':
      'Subscription status · expiry · validity check',
  'ضريبة القيمة المضافة · ضريبة المدخلات': 'VAT · input VAT',
  'إنشاء نسخة · قائمة النسخ · الاستعادة':
      'Create backup · backup list · restore',
  'مُفعَّل': 'Enabled',
  'معطَّل': 'Disabled',
  'نصّ': 'Text',
  'نصّ عربي': 'Arabic text',
  'إجمالي {0}': 'Total {0}',
  'أُلغي الاختيار — سيظهر حوار الطباعة في كل مرة.':
      'Selection cleared — the print dialog will appear every time.',
  'إلغاء الاختيار': 'Clear selection',
  'إلغاء التخصيص': 'Remove custom folder',
  'اختر تاريخ انتهاء اشتراك النظام':
      'Choose the system subscription expiry date',
  'اختيار الطابعة الافتراضية متاح على ويندوز (سطح المكتب) فقط.':
      'Choosing a default printer is available on Windows (desktop) only.',
  'اختيار المجلد': 'Choose folder',
  'اختيار المجلد متاح على ويندوز (سطح المكتب) فقط؛ على أندرويد تُحفظ ':
      'Choosing a folder is available on Windows (desktop) only; on Android copies are saved ',
  'اختيار المجلد متاح على ويندوز (سطح المكتب) فقط؛ على أندرويد تُحفظ '
          'النسخ داخل مجلد التطبيق.':
      'Choosing a folder is available on Windows (desktop) only; on Android copies are saved inside the app folder.',
  'اختياري — 15 رقمًا، يظهر على الفاتورة وQR الهيئة':
      'Optional — 15 digits, shown on the invoice and the authority QR',
  'اختياري — الصق رابط الخريطة': 'Optional — paste the map link',
  'اختياري — يظهر على الفاتورة عند تفعيل خياره':
      'Optional — shown on the invoice when its option is enabled',
  'اسم النشاط': 'Business name',
  'الإصدار {0}': 'Version {0}',
  'التاريخ: 2026-10-06 10:30 ص': 'Date: 2026-10-06 10:30 AM',
  'الخصم: 2.00': 'Discount: 2.00',
  'الرقم الضريبي (VAT)': 'Tax number (VAT)',
  'الرقم الضريبي: {0}': 'Tax number: {0}',
  'السجل التجاري': 'Commercial registration',
  'السجل التجاري: 1010000000': 'Commercial registration: 1010000000',
  'الطابعة': 'Printer',
  'العنوان الوطني المختصر': 'Short national address',
  'العنوان الوطني: 1234 الرياض': 'National address: 1234 Riyadh',
  'المتبقي: 0.00': 'Remaining: 0.00',
  'المختارة: {0}': 'Selected: {0}',
  'المدفوع: 8.00': 'Paid: 8.00',
  'المستحق: 8.00 ر.س': 'Due: 8.00 SAR',
  'بلا تاريخ': 'No date',
  'تاريخ الانتهاء: {0}': 'Expiry date: {0}',
  'تاريخ انتهاء الاشتراك: {0}': 'Subscription expiry date: {0}',
  'تحديث قائمة الطابعات': 'Refresh printer list',
  'تعذّر التحقق من صحة التاريخ': 'Could not verify the date',
  'تعيين تاريخ الانتهاء': 'Set expiry date',
  'تم إنشاء النسخة': 'Backup created',
  'تم اختيار «{0}» — ستُطبَع الفواتير عليها تلقائيًا.':
      '"{0}" selected — invoices will print on it automatically.',
  'تم الحفظ': 'Saved',
  'جارٍ التحقق…': 'Verifying…',
  'حفظ المعلومات': 'Save information',
  'حُفظت داخل التطبيق فقط': 'Saved inside the app only',
  'حُفظت في: {0}': 'Saved to: {0}',
  'رابط الموقع (Google Maps)': 'Location link (Google Maps)',
  'رقم الهاتف': 'Phone number',
  'رمز الاستلام: 1234': 'Pickup code: 1234',
  'سبب غير معروف': 'Unknown reason',
  'صدر بواسطة: مدير النظام': 'Issued by: System manager',
  'ضريبة القيمة المضافة 15%: 1.04': 'VAT 15%: 1.04',
  'على أندرويد يُفتح حوار الطباعة في كل مرة (سلوك النظام). وللطابعات ':
      'On Android the print dialog opens every time (system behavior). For ',
  'على أندرويد يُفتح حوار الطباعة في كل مرة (سلوك النظام). وللطابعات '
          'الحرارية عبر البلوتوث يُستخدم تطبيق وسيط مثل RawBT.':
      'On Android the print dialog opens every time (system behavior). For Bluetooth thermal printers, use a bridge app such as RawBT.',
  'غير محدود (بلا تاريخ انتهاء)': 'Unlimited (no expiry date)',
  'فتح مجلد الحفظ': 'Open save folder',
  'فشل في إنشاء النسخة': 'Failed to create backup',
  'لا يوجد تاريخ انتهاء': 'No expiry date',
  'لم تُختَر طابعة — سيظهر حوار الطباعة في كل مرة.':
      'No printer selected — the print dialog will appear every time.',
  'لم يُختَر مجلد بعد — يُستخدم المجلد الافتراضي داخل «المستندات».':
      'No folder chosen yet — the default folder under Documents is used.',
  'مجلد حفظ نسخ PDF': 'PDF copies folder',
  'مجلد مخصَّص (سيُنشأ عند أول حفظ).': 'Custom folder (created on first save).',
  'مجلد مخصَّص وموجود.': 'Custom folder exists.',
  'معاينة تمثيلية تتغير مع كل خيار إظهار — لا تُحفظ ولا تُطبع.':
      'A representative preview that changes with display options — not saved or printed.',
  'منتهٍ': 'Expired',
  'منتهٍ منذ {0} يوم': 'Expired {0} days ago',
  'نظام إدارة المغاسل الشامل — تصميم عصري وتجربة سلسة':
      'Comprehensive laundry management system — modern design and smooth experience',
  'يتبقى {0} يومًا': '{0} days remaining',
  'يتبقى يوم واحد': 'One day remaining',
  'ينتهي اليوم': 'Expires today',
  '— قميص ×1 = 10.00 —': '— Shirt ×1 = 10.00 —',
  ' — بلا دفعة': ' — no payment',
  'أوافق وأُكمل البيع': 'I agree and complete the sale',
  'أوافق وأُكمل الفاتورة': 'I agree and complete the invoice',
  'استهلك «{0}» {1}% من سقف اشتراكه. المتبقّي: {2} قطعة{3}.':
      '"{0}" used {1}% of the subscription limit. Remaining: {2} pieces{3}.',
  'التجاوز يُسجَّل في سجل التدقيق باسمك — تأكد أن هناك موافقة ':
      'The override is recorded in the audit log under your name — confirm ',
  'التجاوز يُسجَّل في سجل التدقيق باسمك — تأكد أن هناك موافقة '
          'من الإدارة قبل المتابعة.':
      'The override is recorded in the audit log under your name — confirm management approval before continuing.',
  'الحدّ الفعلي هو عدد القطع — هو ما استُنفد أولًا.':
      'The effective limit is pieces — that is what runs out first.',
  'الحلول: خفّض المبلغ الآجل، أو حصّل دفعة نقدية، ':
      'Options: lower the credit amount, collect a cash payment, ',
  'الحلول: خفّض المبلغ الآجل، أو حصّل دفعة نقدية، '
          'أو ارفع حدّ الائتمان من شاشة حساب الزبون، '
          'أو راجع مديرًا للتصديق.':
      'Options: lower the credit amount, collect a cash payment, raise the credit limit from the customer account, or ask a manager for approval.',
  'الحلول: سجّل تجديدًا للاشتراك من شاشة الاشتراكات ':
      'Options: record a subscription renewal in Subscriptions ',
  'الحلول: سجّل تجديدًا للاشتراك من شاشة الاشتراكات '
          '(سيمدّد التغطية ويفتح سقفًا جديدًا)، أو ارفع سقف '
          'الاستخدام بموافقة الإدارة، أو اختر طريقة دفع أخرى '
          'لهذه الفاتورة.':
      'Options: record a subscription renewal in Subscriptions (extends coverage and opens a new limit), raise the usage limit with management approval, or choose another payment method for this invoice.',
  'القطع': 'Pieces',
  'القيمة': 'Value',
  'تأكيد تجاوز سقف الاشتراك': 'Confirm subscription limit override',
  'تجاوز {0}': 'Over by {0}',
  'تطبيق': 'Apply',
  'قارب سقف الاشتراك': 'Approaching subscription limit',
  ' — بلغ سقفه': ' — limit reached',
  ' — مغطّى': ' — covered',
  ' — ملغى': ' — cancelled',
  ' — منتهي': ' — expired',
  '«{0}» اشتراكه مسجَّل ولم تُسجَّل له دفعة — التغطية تبدأ من أول دفعة':
      '"{0}" has a subscription but no recorded payment — coverage starts with the first payment',
  '«{0}» بلغ سقف استهلاكه — التجاوز يحتاج موافقة الإدارة أو تجديدًا':
      '"{0}" reached the usage limit — exceeding it needs management approval or renewal',
  'أدخل كود الخصم أولًا': 'Enter the discount code first',
  'إلغاء الخصم': 'Remove discount',
  'اختر الزبون (اختياري)': 'Choose customer (optional)',
  'اختر العميل الذي سيسدد لاحقاً': 'Choose the customer who will pay later',
  'اختر صاحب الاشتراك (تُعرض حالته)':
      'Choose the subscription holder (status shown)',
  'اختياري: اربط الفاتورة بزبون مسجّل ليظهر في كشف حسابه وواتساب':
      'Optional: link the invoice to a registered customer for their statement and WhatsApp',
  'اذهب لصفحة الزبائن → أضف زبوناً ثم عد لهذا الحوار':
      'Go to Customers → add a customer, then return to this dialog',
  'استهلك «{0}» سقف اشتراكه — جدّد الاشتراك أو ارفع السقف بموافقة ':
      '"{0}" used up the subscription limit — renew or raise the limit with management approval ',
  'استهلك «{0}» سقف اشتراكه — جدّد الاشتراك أو ارفع السقف بموافقة '
          'الإدارة ثم أعد المحاولة.':
      '"{0}" used up the subscription limit — renew or raise the limit with management approval, then try again.',
  'اشتراك «{0}» أُلغي بتسوية — لا تغطية سارية له. أنشئ اشتراكًا جديدًا ':
      '"{0}" subscription was cancelled by settlement — no active coverage. Create a new one ',
  'اشتراك «{0}» أُلغي بتسوية — لا تغطية سارية له. أنشئ اشتراكًا جديدًا '
          'أو اختر طريقة دفع أخرى.':
      '"{0}" subscription was cancelled by settlement — no active coverage. Create a new subscription or choose another payment method.',
  'اشتراك «{0}» مسجَّل ولم تُسجَّل له أي دفعة بعد — التغطية تبدأ من ':
      '"{0}" subscription is recorded with no payment yet — coverage starts with ',
  'اشتراك «{0}» مسجَّل ولم تُسجَّل له أي دفعة بعد — التغطية تبدأ من '
          'أول دفعة تُسجَّل من شاشة الاشتراكات الشهرية.':
      '"{0}" subscription is recorded with no payment yet — coverage starts with the first payment recorded in Monthly Subscriptions.',
  'اشتراك «{0}» ملغى بتسوية — لا تغطية سارية':
      '"{0}" subscription is cancelled by settlement — no active coverage',
  'الآجل يتطلب عميلاً محدداً من سجل الزبائن':
      'Credit requires a specific customer from the customer record',
  'الأقرب 5': 'Nearest 5',
  'الاشتراك الشهري يتطلب اختيار صاحب الاشتراك من القائمة':
      'Monthly subscription requires selecting the subscription holder from the list',
  'البدائل: اختر الدفع كاش أو شبكة، أو راجع مديرًا ':
      'Alternatives: choose cash or card, or ask a manager ',
  'البدائل: اختر الدفع كاش أو شبكة، أو راجع مديرًا '
          'ليُسجّل الفاتورة الآجلة.':
      'Alternatives: choose cash or card, or ask a manager to record the credit invoice.',
  'البيع الآجل غير مصرّح': 'Credit sale not permitted',
  'الزبون «{0}» ليس لديه اشتراك شهري بتغطية مدفوعة — سجّل دفعة له من ':
      'Customer "{0}" has no monthly subscription with paid coverage — record a payment from ',
  'الزبون «{0}» ليس لديه اشتراك شهري بتغطية مدفوعة — سجّل دفعة له من '
          'شاشة الاشتراكات أو اختر طريقة دفع أخرى.':
      'Customer "{0}" has no monthly subscription with paid coverage — record a payment in Subscriptions or choose another payment method.',
  'الزبون: {0} — رصيد موجب: {1} ر.س': 'Customer: {0} — credit balance: {1} SAR',
  'الفاتورة فارغة — أضف أصنافاً أولاً':
      'The invoice is empty — add items first',
  'الفاتورة مرتبطة بالزبون: {0}': 'Invoice linked to customer: {0}',
  'المبلغ المدفوع الآن:': 'Amount paid now:',
  'المتبقي: {0} ر.س': 'Remaining: {0} SAR',
  'انتهت تغطية «{0}» — جدّد الاشتراك ليمتدّ فورًا':
      'Coverage for "{0}" expired — renew the subscription to extend it immediately',
  'انتهت تغطية اشتراك «{0}» — جدّده من شاشة الاشتراكات ليمتدّ فورًا ':
      'Coverage for "{0}" expired — renew it in Subscriptions to extend it immediately ',
  'انتهت تغطية اشتراك «{0}» — جدّده من شاشة الاشتراكات ليمتدّ فورًا '
          'وتستطيع إصدار فاتورته.':
      'Coverage for "{0}" expired — renew it in Subscriptions to extend it immediately, then you can issue the invoice.',
  'بالضبط': 'Exact',
  'تأكيد الإصدار': 'Confirm issue',
  'تأكيد تجاوز حدّ الائتمان': 'Confirm credit limit override',
  'تجاوز حدّ الائتمان': 'Credit limit exceeded',
  'تجاوز سقف الاشتراك': 'Subscription limit exceeded',
  'تم سداد الإجمالي ✓': 'Total paid ✓',
  'تنبيه ائتماني': 'Credit warning',
  'تُحسم من تغطية اشتراك: {0}': 'Deducted from subscription coverage: {0}',
  'جاري تحميل الزبائن...': 'Loading customers...',
  'حسنًا': 'OK',
  'خصم {0} ر.س{1} — الإجمالي قبل الخصم {2} ر.س':
      'Discount {0} SAR{1} — total before discount {2} SAR',
  'دورك ({0}) لا يمنح صلاحية تطبيق الخصومات':
      'Your role ({0}) does not permit applying discounts',
  'دورك الحالي ({0}) لا يمنح صلاحية تسجيل ذمة على زبون.':
      'Your current role ({0}) does not permit recording credit for a customer.',
  'رصيد الزبون: {0} ر.س — سيُخصم من الفاتورة':
      'Customer balance: {0} SAR — will be deducted from the invoice',
  'سداد': 'Pay',
  'سيُسجل الدين على: {0}': 'Debt will be recorded against: {0}',
  'سيُسجل كذمة على الزبون': 'Will be recorded as customer credit',
  'فاتورة الاشتراك تُحسم من تغطية الزبون — اختر صاحب الاشتراك من القائمة':
      'Subscription invoices are deducted from coverage — choose the subscription holder',
  'فاتورة رقم #{0} — الإجمالي {1} ر.س': 'Invoice #{0} — total {1} SAR',
  'فتح حساب الزبون': 'Open customer account',
  'فتح وردية الآن': 'Open shift now',
  'كود الخصم (اختياري)': 'Discount code (optional)',
  'كود غير صالح': 'Invalid code',
  'لا يمكن إصدار أي فاتورة أو تسجيل بيع قبل فتح وردية جديدة.':
      'No invoice can be issued or sale recorded before opening a new shift.',
  'لا يمكن إصدار فاتورة اشتراك': 'Cannot issue subscription invoice',
  'لا يمكن تسجيل فاتورة آجلة دون اختيار عميل محدد من سجل الزبائن':
      'A credit invoice cannot be recorded without selecting a specific customer',
  'لا يوجد اشتراك نشط': 'No active subscription',
  'لا يوجد زبائن — أضفهم من صفحة الزبائن':
      'No customers — add them from the Customers page',
  'لا يوجد زبون له اشتراك شهري مسجَّل':
      'No customer has a recorded monthly subscription',
  'لا يوجد زبون له اشتراك شهري مسجّل — سجّل اشتراكًا من شاشة الاشتراكات الشهرية':
      'No customer has a recorded monthly subscription — create one in Monthly Subscriptions',
  'لا يوجد وردية مفتوحة': 'No open shift',
  'مثال: WASH10': 'e.g. WASH10',
  'مطلوب تحديد العميل': 'Customer selection required',
  'هذا الزبون ليس لديه اشتراك شهري بتغطية مدفوعة — ':
      'This customer has no monthly subscription with paid coverage — ',
  'هذا الزبون ليس لديه اشتراك شهري بتغطية مدفوعة — '
          'اختر طريقة دفع أخرى أو سجّل دفعة له من شاشة الاشتراكات':
      'This customer has no monthly subscription with paid coverage — choose another payment method or record a payment in Subscriptions',
  'ابحث في خيارات هذه الصفحة...': 'Search this page\'s options...',
  'الفوترة والترقيم': 'Invoicing and numbering',
  'ما يظهر على الفاتورة': 'Invoice display',
  'الطباعة بكل المقاسات': 'Printing in all sizes',
  'ضريبة المدخلات (المصروفات)': 'Input VAT (expenses)',
  'الذمم والائتمان': 'Receivables and credit',
  'المصنعية': 'Processing',
  'مصنعية العمال': 'Worker payroll',
  'نقاط الولاء': 'Loyalty points',
  'خيارات الترخيص': 'License options',
  'إعدادات النظام والنشاط التجاري': 'System and business settings',
  'النشاط والواجهة': 'Business and appearance',
  'الفواتير والطباعة': 'Invoices and printing',
  'الحسابات والتشغيل': 'Accounts and operations',
  'النظام والصيانة': 'System and maintenance',
  'حجم الخط في كل الشاشات': 'Font size across screens',
  'تصميم الفاتورة وكشف الحساب — كل عنصر: تفعيل ونصّ':
      'Invoice and statement design — enable and edit every element',
  'الترقيم لا يتراجع: لا يقلّ رقم الفاتورة الجديدة عن أعلى رقم مسجَّل.':
      'Numbering never goes backwards: a new invoice number is never lower than the highest recorded.',
  'اختصارات سريعة لإظهار/إخفاء حقول الفاتورة. للتحكّم الكامل — نصّ كل عنصر وتفعيله وتصميم كشف الحساب أيضًا — استخدم «قوالب الطباعة». ⚠️ بعد أول تعديل من هناك يصبح القالب هو المرجع، وهذه المفاتيح تزامنه ولا تُلغيه.':
      'Quick toggles for invoice fields. For full control — text, enablement and statement design — use "Print templates". After the first edit there, the template becomes the reference and these switches sync with it.',
  'A4 · A5 · A6 · حراري 80/58 مم · ملصقات. التفعيل لا يغيّر سلوك أي تثبيت قائم حتى تختار المقاس.':
      'A4 · A5 · A6 · thermal 80/58 mm · labels. Enabling does not change an existing setup until you choose the size.',
  'النسبة تُخزَّن وتُضبط من هنا، ولم تُضَف بعد إلى حساب الفاتورة.':
      'The rate is stored and configured here; it is not yet added to invoice totals.',
  'ضريبة المشتريات القابلة للخصم — تدخل في تقرير الإقرار الضريبي.':
      'Deductible purchase VAT — included in the tax return report.',
  'هذه القيم كانت تُقرأ مباشرةً؛ صارت هنا مصدرًا واحدًا يظهر ويُدقَّق.':
      'These values used to be read directly; now they have a single visible, auditable source.',
  'تحكم سلوك التغطية والسقوف والدفعات.':
      'Controls coverage, caps and payments.',
  'تتبّع الغسيل من الاستلام للتسليم: المخطط · العامل · المهلة · الملصقات.':
      'Track laundry from intake to delivery: board · worker · deadline · labels.',
  'أجر القطعة وحوافز الإنتاج وتقرير الإنتاجية.':
      'Piece rates, production incentives and productivity report.',
  'سلوك شاشة الكاشير: الطباعة التلقائية · التأكيد · طريقة الدفع الافتراضية.':
      'POS behavior: auto print · confirmation · default payment method.',
  'سياسات تسجيل الزبون الافتراضية.': 'Default customer registration policies.',
  'التعطيل يوقف احتساب النقاط وترقيات الشرائح تمامًا عند إصدار الفواتير.':
      'Disabling stops point accrual and tier upgrades entirely when invoicing.',
  'تنبيه: التقارير السنوية تعتمد على الفواتير المحفوظة. لا تُقلّل المدة ولا تُفعّل الحذف دون أخذ نسخة احتياطية.':
      'Warning: annual reports depend on saved invoices. Do not reduce retention or enable deletion without a backup.',
  'القيم تسري فورًا على فحص صلاحية النظام أثناء العمل.':
      'Values apply immediately to live license checks.',
  'التفصيل — {0}': 'Details — {0}',
  'الفترة المحددة': 'Selected period',
  'تُخصم من صافي الربح': 'Deducted from net profit',
  'طباعة التقرير': 'Print report',
  'مستحقة للهيئة — خارج الربح': 'Due to the authority — outside profit',
  'إضافة زبون': 'Add customer',
  'اسم الزبون': 'Customer name',
  'اكتب اسم الزبون أولاً': 'Enter the customer name first',
  'الرقم الأول': 'First phone',
  'الرقم الثاني': 'Second phone',
  'بلا رقم': 'No phone',
  'حذف الزبون؟': 'Delete customer?',
  'زبون جديد': 'New customer',
  'مسح': 'Clear',
  'لا توجد نتائج': 'No results',
  'الاسم أو رقم الجوال...': 'Name or phone number...',
  'البحث عن زبون': 'Find a customer',
  'ابحث عن زبون': 'Find a customer',
  'اكتب اسم الزبون أو رقم جواله — يعمل البحث بأي جزء من الرقم وبأي صيغة (مسافات أو أرقام عربية).':
      'Type the customer name or phone — any part of the number works in any format (spaces or Arabic digits).',
  'لم نجد زبونًا يطابق «{0}» — تحقق من الاسم أو رقم الجوال.':
      'No customer matches "{0}" — check the name or phone number.',
  '{0} ر.س': '{0} SAR',
  '{0} زبون عليهم ذمة قائمة · اضغط لعرض أعمار الديون':
      '{0} customers with outstanding debt · tap to view debt aging',
  'إجمالي الذمم: {0} ر.س': 'Total receivables: {0} SAR',
  'إدارة سجل الزبائن': 'Manage customer records',
  'ابحث عن زبون بالاسم أو الرقم...': 'Search customer by name or phone...',
  'الفواتير ({0})': 'Invoices ({0})',
  'المتبقي (ذمة)': 'Remaining (debt)',
  'المشتريات': 'Purchases',
  'حساب الزبون': 'Customer account',
  'دفعات الاشتراكات ({0})': 'Subscription payments ({0})',
  'دفعات الذمم ({0})': 'Debt payments ({0})',
  'دفعة اشتراك': 'Subscription payment',
  'رمز: {0}': 'Code: {0}',
  'كشف حساب الزبون': 'Customer statement',
  'كشف حساب — {0}': 'Statement — {0}',
  'لا توجد فواتير أو دفعات لهذا الزبون':
      'No invoices or payments for this customer',
  'مدفوع {0}': 'Paid {0}',
  'إرفاق صورة البقعة': 'Attach stain photo',
  'إضافة للفاتورة': 'Add to invoice',
  'إغلاق القائمة': 'Close menu',
  'اختر نوع الخدمة لإضافته للفاتورة': 'Choose a service to add to the invoice',
  'الإصدار {0}  •  ': 'Version {0}  •  ',
  'ترتيب الأصناف': 'Sort items',
  'تقليل': 'Decrease',
  'تم إرفاق الصورة ✓': 'Photo attached ✓',
  'حذف الصورة': 'Remove photo',
  'زيادة': 'Increase',
  'مجاناً': 'Free',
  'مرحباً، {0}': 'Welcome, {0}',
  'مستعجل {0}': 'Urgent {0}',
  'مطوّر النظام': 'System developer',
  'ملاحظة (بقع، تلف، قصّات…) اكتب "بدون" إن أردت':
      'Note (stains, damage, cuts…) type "none" if not applicable',
  'من {0} ر.س': 'From {0} SAR',
  'منذ: {0}': 'Since: {0}',
  'نظام إدارة المغاسل': 'Laundry management system',
  'نظام المغاسل': 'Laundry system',
  'اختر الخدمة و الكمية': 'Choose service and quantity',
  'اختر نوع الخدمة': 'Choose service type',
  'وردية مفتوحة الآن': 'Shift is open',
  'لا توجد وردية نشطة': 'No active shift',
  'فتح وردية': 'Open shift',
  'هل أنت متأكد من تسجيل الخروج من النظام؟':
      'Are you sure you want to log out?',
  'الإدارة': 'Management',
  'العمليات': 'Operations',
  'النظام': 'System',
  'إضافة لبس': 'Add item',
  'حذف وتعديل لبس': 'Edit and delete items',
  'الاشتراكات الشهرية': 'Monthly subscriptions',
  'لوحة الاشتراكات': 'Subscriptions dashboard',
  'صندوق اليوم': 'Daily cash',
  'سجل الورديات': 'Shift history',
  'الملف الشخصي': 'Profile',
  'إدارة المستخدمين': 'User management',
  'الأدوار والصلاحيات': 'Roles and permissions',
  'سجل التدقيق': 'Audit log',
  'تسجيل الخروج': 'Log out',
  '{0} بند': '{0} entries',
  'أدخل مبلغًا صحيحًا أكبر من صفر': 'Enter a valid amount greater than zero',
  'أضف مصروفًا ليُخصم من صافي الربح':
      'Add an expense to deduct it from net profit',
  'إجمالي مصروفات الفترة': 'Total expenses for the period',
  'البنود': 'Entries',
  'البيان (اختياري)': 'Description (optional)',
  'البيان بالإنجليزية (اختياري)': 'English description (optional)',
  'التصنيف': 'Category',
  'التوزيع حسب التصنيف': 'Breakdown by category',
  'المبلغ (ر.س)': 'Amount (SAR)',
  'المصروف غير النقدي يُخصم من الربح ولا يُخصم من درج النقد.':
      'A non-cash expense is deducted from profit, not from the cash drawer.',
  'تسوية دفاتر': 'Ledger adjustment',
  'تنبيه': 'Notice',
  'حذف المصروف؟': 'Delete expense?',
  'سيُحذف البند نهائيًا ويُعاد حساب الربح.':
      'The entry will be permanently deleted and profit recalculated.',
  'شبكة / تحويل': 'Card / transfer',
  'طريقة الدفع': 'Payment method',
  'غير نقدي:': 'Non-cash:',
  'لا توجد مصروفات في هذه الفترة': 'No expenses in this period',
  'مثال: September electricity bill': 'e.g. September electricity bill',
  'مثال: فاتورة كهرباء شهر 9': 'e.g. September electricity bill',
  'مصروف جديد': 'New expense',
  'منها نقدي:': 'Cash portion:',
  'نقدي (من الدرج)': 'Cash (from drawer)',
  'ابحث برقم الفاتورة أو اسم الزبون...':
      'Search by invoice number or customer name...',
  'جاري تحميل الفواتير...': 'Loading invoices...',

  'تفعيل لوحة المصنعية': 'Enable the processing board',
  'مخطط سير العمل': 'Workflow scheme',
  'إلزام تعيين عامل': 'Require worker assignment',
  'مهلة الإنجاز (ساعات)': 'Completion SLA (hours)',
  'انتقال تلقائي إلى «جاهز» (ساعات)': 'Auto-move to Ready (hours)',
  'إشعار الزبون بالواتساب': 'Notify the customer on WhatsApp',
  'طباعة ملصقات القطع': 'Print item labels',
  'عند التعطيل يُخفى تتبّع الحالات من الفاتورة ولوحة المصنعية.':
      'When off, status tracking is hidden from the invoice and processing board.',
  'قياسي (4 حالات) أو موسّع (6 حالات: غسيل · كوي · تغليف...).':
      'Standard (4 states) or extended (6: wash, iron, pack...).',
  'عند التفعيل لا تبدأ القطعة التنفيذ بلا عامل مسؤول.':
      'When on, an item cannot start processing without an assigned worker.',
  'بعد هذه المدة تُعلَّم الفاتورة كمتأخرة في لوحة المصنعية.':
      'After this period the invoice is flagged late on the processing board.',
  'صفر يعني بلا انتقال تلقائي (التحديث يدوي).':
      'Zero means no automatic transition (manual update).',
  'إظهار زر إشعار العميل عند جاهزية الغسيل.':
      'Show a notify-customer button when the laundry is ready.',
  'إتاحة طباعة ملصق لكل قطعة عند الاستلام.':
      'Allow printing a label per item at intake.',

  // ═══ مصنعية العمال ═══
  'تفعيل مصنعية العمال': 'Enable worker labor cost',
  'أجر القطعة': 'Labor cost per item',
  'إلزام تعيين عامل للاحتساب': 'Require a worker for costing',
  'حدّ حافز الإنتاج (قطعة/شهر)': 'Production incentive threshold (items/month)',
  'نسبة حافز الإنتاج': 'Production incentive rate',
  'احتساب تكلفة عمالة لكل قطعة على الفاتورة وتقرير الإنتاجية.':
      'Cost labor per item on the invoice and productivity report.',
  'قيمة مصنعية القطعة الواحدة للعامل.': 'Labor value per item for the worker.',
  'عند التفعيل لا تُحمَّل مصنعية على فاتورة بلا عامل مسؤول.':
      'When on, no labor cost is applied to an invoice without a worker.',
  'عدد القطع الشهري الذي يبدأ عنده صرف الحافز.':
      'Monthly item count at which the incentive starts.',
  'نسبة تُضاف على أجور المصنعية عند تجاوز الحدّ.':
      'Rate added to labor cost once the threshold is exceeded.',

  // ═══ الزبائن والولاء ═══
  'إلزام هاتف الزبون': 'Require customer phone',
  'شريحة الزبون الافتراضية': 'Default customer tier',
  'احتساب نقاط الولاء': 'Earn loyalty points',
  'نقاط الولاء لكل مبلغ': 'Loyalty points per amount',
  'جبر كسور النقاط لأعلى': 'Round points up',
  'عند التفعيل لا يُحفظ زبون بلا رقم هاتف.':
      'When on, a customer cannot be saved without a phone number.',
  'الشريحة الممنوحة للزبون الجديد.': 'Tier granted to a new customer.',
  'عند التفعيل تُقرَّب النقاط لأعلى بدل إسقاط الكسور.':
      'When on, points round up instead of being truncated.',

  // ═══ الاحتفاظ والترخيص ═══
  'حذف الفواتير القديمة تلقائيًا': 'Auto-delete old invoices',
  'مدة الاحتفاظ (أيام)': 'Retention period (days)',
  'تنبيه قبل انتهاء الترخيص (أيام)': 'License expiry warning (days)',
  'فاصل فحص الترخيص (ساعات)': 'License check interval (hours)',
  'يُعرض تحذير «يتبقى N يومًا» في آخر هذه المدة قبل الانتهاء.':
      'A “N days left” warning is shown during this period before expiry.',

  // ═══ الاشتراكات الشهرية ═══
  '0 = بلا حدود': '0 = Unlimited',
  '{0} ر.س — التغطية حتى {1}': '{0} SAR — covered until {1}',
  '{0} قطعة': '{0} pieces',
  '{0} قطعة — {1} ر.س': '{0} pieces — {1} SAR',
  'أدخل مبلغاً صحيحاً': 'Enter a valid amount',
  'أدخل مبلغاً صحيحاً أكبر من صفر': 'Enter a valid amount greater than zero',
  'أُعيد {0} ر.س {1} عن {2} يوم غير مُقدَّم.':
      'Refunded {0} SAR {1} for {2} unused days.',
  'إضافة الاشتراك': 'Add subscription',
  'إلغاء بتسوية': 'Cancel with settlement',
  'إلغاء بتسوية — {0}': 'Cancel with settlement — {0}',
  'إيراد الشهر المقطوع': 'Fixed monthly revenue',
  'اختر الزبون...': 'Select customer...',
  'استرداد نقدي': 'Cash refund',
  'استهلاك الدورة: {0} قطعة': 'Cycle usage: {0} pieces',
  'استهلاك الدورة: {0} قطعة / {1}': 'Cycle usage: {0} / {1} pieces',
  'استُهلك {0}% من السقف': '{0}% of the cap used',
  'استُهلك السقف': 'Cap reached',
  'اسم الزبون (من السجل)': 'Customer name (from record)',
  'اشتراك #{0} — {1} ر.س / {2} يوم': 'Subscription #{0} — {1} SAR / {2} days',
  'اشتراك جديد': 'New subscription',
  'اشتراكات تستحقّ التجديد خلال 7 أيام':
      'Subscriptions due for renewal within 7 days',
  'اشتراكات نشطة': 'Active subscriptions',
  'اضغط زر + لإضافة اشتراك لزبون محدد':
      'Tap + to add a subscription for a customer',
  'الأصناف: {0}': 'Items: {0}',
  'الاشتراك: {0} ر.س / {1} يوم — التغطية الحالية حتى {2}':
      'Subscription: {0} SAR / {1} days — current coverage until {2}',
  'الاشتراك: {0} ر.س / {1} يوم — يغطي حتى {2}':
      'Subscription: {0} SAR / {1} days — covered until {2}',
  'الاشتراك: {0} ر.س — {1} فاتورة هذا الشهر، قيمة غسيله الفعلية {2} ر.س (التغطية: {0} ر.س)':
      'Subscription: {0} SAR — {1} invoices this month, actual laundry value {2} SAR (coverage: {0} SAR)',
  'الحالي: {0} — {1}': 'Current: {0} — {1}',
  'السقف': 'Cap',
  'السقف مستهلك بالكامل — لن تُقبل فاتورة جديدة إلا بموافقة مدير أو تجديد':
      'Cap fully used — no new invoice will be accepted without manager approval or renewal',
  'السقف يحمي من اشتراك صغير يستهلك غسيلًا بلا حدّ. اتركه فارغًا أو صفرًا لإلغاء السقف. يُطبَّق أيّهما استُنفد أولًا.':
      'The cap protects against a small subscription consuming unlimited laundry. Leave it empty or zero to remove the cap. Whichever runs out first applies.',
  'المبلغ الشهري (ر.س)': 'Monthly amount (SAR)',
  'المدة بالأيام': 'Duration (days)',
  'بلا سقف استخدام — يُنصح بتحديد حدّ':
      'No usage cap — setting a limit is recommended',
  'بلا سقف قطع': 'No pieces cap',
  'بلا سقف قيمة': 'No value cap',
  'تأكيد الإلغاء': 'Confirm cancellation',
  'تراجع': 'Back',
  'تسجيل الدفعة': 'Record payment',
  'تسجيل دفعة': 'Record payment',
  'تسجيل دفعة — {0}': 'Record payment — {0}',
  'تعديل سقف الاستخدام قرار إداري — لا يملكه إلا مدير.':
      'Changing the usage cap is a managerial decision — only a manager can do it.',
  'تم الإلغاء': 'Cancelled',
  'تم التحديث': 'Updated',
  'تم تسجيل الدفعة': 'Payment recorded',
  'حفظ السقف': 'Save cap',
  'خدمة مُقدَّمة': 'Service delivered',
  'دراسة نهاية الشهر': 'Month-end study',
  'دراسة: {0} — {1}': 'Study: {0} — {1}',
  'رصيد لدى المحل (مُوصى به)': 'Store balance (recommended)',
  'رصيدًا لدى المحل': 'as store balance',
  'سداد قريب ({0} يوم)': 'Payment due soon ({0} days)',
  'سعر الاشتراك صفر — لا يمكن احتساب قيمة أيام للتسوية.':
      'Subscription price is zero — cannot calculate a settlement value.',
  'سقف الاستخدام — {0}': 'Usage cap — {0}',
  'سقف الاستخدام: {0} — {1}': 'Usage cap: {0} — {1}',
  'سقف القطع': 'Pieces cap',
  'سقف القطع (اختياري)': 'Pieces cap (optional)',
  'سقف القيمة (اختياري)': 'Value cap (optional)',
  'سقف القيمة (ر.س)': 'Value cap (SAR)',
  'صلاحية غير كافية': 'Insufficient permission',
  'طريقة التسوية': 'Settlement method',
  'علينا': 'Against us',
  'عُطِّل الاشتراك بلا استرداد.': 'Subscription disabled without refund.',
  'فواتير هذا الشهر: {0} بقيمة {1} ر.س (محفوظة داخلياً — تُطبع بدون أسعار)':
      'Invoices this month: {0} worth {1} SAR (stored internally — printed without prices)',
  'فواتير ودراسة': 'Invoices & study',
  'قطع الغسيل': 'Laundry pieces',
  'قطع الغسيل: {0} قطعة — مدفوع هذا الشهر: {1} ر.س':
      'Laundry pieces: {0} — paid this month: {1} SAR',
  'قيمة الأيام غير المُقدَّمة': 'Value of unused days',
  'قيمة غسيله': 'Laundry value',
  'لا توجد أيام مدفوعة متبقّية — الإلغاء تعطيل بسيط بلا استرداد.':
      'No paid days remain — cancellation is a simple disable with no refund.',
  'لا توجد اشتراكات': 'No subscriptions',
  'لا توجد اشتراكات نشطة': 'No active subscriptions',
  'لا توجد فواتير مرتبطة بهذا الاشتراك هذا الشهر':
      'No invoices linked to this subscription this month',
  'لا يوجد اشتراك يستحقّ التجديد خلال الأيام السبعة القادمة.':
      'No subscription is due for renewal in the next seven days.',
  'لم يُسدد بعد': 'Not paid yet',
  'مبلغ الدفعة (ر.س)': 'Payment amount (SAR)',
  'متأخر عن السداد': 'Overdue',
  'متابعة فواتير الاشتراكات واستحقاقاتها':
      'Track subscription invoices and dues',
  'متبقٍّ {0} يوم من أصل {1} — {2} ر.س/يوم. هذا المبلغ مقابل خدمة لن تُقدَّم، فلا يصحّ أن يبقى إيرادًا للمحل.':
      '{0} of {1} days remain — {2} SAR/day. This amount is for a service that will not be provided, so it must not remain revenue for the shop.',
  'مثال: 150': 'e.g. 150',
  'مثال: 50': 'e.g. 50',
  'محصَّل': 'Collected',
  'مدفوع': 'Paid',
  'مدفوع هذا الشهر': 'Paid this month',
  'مدفوع هذا الشهر: {0} ر.س': 'Paid this month: {0} SAR',
  'مستحقات متأخرة': 'Overdue dues',
  'مستحقّ التجديد': 'Due for renewal',
  'ملاحظة (اختياري)': 'Note (optional)',
  'ملغى': 'Cancelled',
  'نسبة لنا': 'In our favor',
  'نشط ({0} يوم)': 'Active ({0} days)',
  'نقدًا': 'in cash',
  'يبقى في الدرج كسلفة للزبون، ويُخصم تلقائيًا من فواتيره القادمة. لا يُخرج نقدية.':
      'Stays in the drawer as customer credit and is deducted automatically from future invoices. No cash leaves.',
  'يجب اختيار زبون من سجل الزبائن':
      'You must select a customer from the customer record',
  'يُخرج المبلغ من الدرج ويُسجَّل في المصروفات، فيظهر في إقفال الوردية.':
      'The amount leaves the drawer and is recorded as an expense, appearing in the shift close.',
  'ربع ({0})': 'Quarter ({0})',
  'نصف ({0})': 'Half ({0})',
  'ثلاثة أرباع ({0})': 'Three quarters ({0})',
  'كامل ({0})': 'Full ({0})',

  // ═══ لوحة الاشتراكات ═══
  'الالتزام المتبقّي': 'Remaining obligation',
  'الصافي': 'Net',
  'النقدية المقبوضة': 'Cash received',
  'تغيير الفترة': 'Change period',
  'تكلفة الخدمة': 'Cost of service',
  'ر.س / شهر': 'SAR / month',
  'فرق القبض عن الخدمة': 'Cash vs. service gap',
  'قيمة الخدمة المُقدَّمة': 'Value of service delivered',
  'لا توجد اشتراكات نشطة لتحليل ربحيتها':
      'No active subscriptions to analyze profitability',
  'لا يوجد اشتراك قارب سقفه — كل المشتركين داخل الحدود.':
      'No subscription is near its cap — all subscribers are within limits.',
  'لم يُسدد': 'Unpaid',
  'متأخر': 'Overdue',
  'مستهلك السقف': 'Cap reached',
  'مُحصَّل': 'Collected',

  // ═══ الصندوق والورديات ═══
  ' · مفتوحة الآن': ' · open now',
  'أمس — ': 'Yesterday — ',
  'إيداعات': 'Deposits',
  'إيداعات (فواتير كاش)': 'Deposits (cash invoices)',
  'استرداد — {0}': 'Refund — {0}',
  'استردادات اشتراكات نقدية': 'Cash subscription refunds',
  'اشتراك — {0}': 'Subscription — {0}',
  'الرصيد الختامي': 'Closing balance',
  'الصندوق': 'Cash register',
  'المعدود فعليًا ({0} وردية)': 'Actually counted ({0} shifts)',
  'الوردية الأحدث': 'Newest shift',
  'الوردية الأقدم': 'Oldest shift',
  'اليوم — ': 'Today — ',
  'بالتاريخ': 'By date',
  'بالوردية': 'By shift',
  'دفعات الاشتراكات': 'Subscription payments',
  'رصيد افتتاح وردية #{0}': 'Opening balance of shift #{0}',
  'رصيد الافتتاح': 'Opening balance',
  'سحوبات (مصروفات)': 'Withdrawals (expenses)',
  'سحوبات نقدية': 'Cash withdrawals',
  'سداد ديون الزبائن': 'Customer debt payments',
  'عرض بالتاريخ': 'By date',
  'عرض بالوردية': 'By shift',
  'غير محدد': 'Unspecified',
  'غير مسجل': 'Unregistered',
  'لا توجد وردية في هذا اليوم': 'No shift on this day',
  'لا توجد وردية محددة': 'No shift selected',
  'مصروفات غير نقدية': 'Non-cash expenses',
  'مفتوحة': 'Open',
  'منها اشتراكات': 'Of which subscriptions',
  'مُقفَلة': 'Closed',
  'ورديات أُقفلت بلا جرد': 'Shifts closed without stocktake',
  'وردية #{0}': 'Shift #{0}',

  // ═══ أعمار الديون ═══
  'ابحث باسم الزبون أو رقم الجوال…': 'Search by customer name or phone…',
  'المبلغ المستلَم': 'Amount received',
  'تحديث': 'Refresh',
  'دفعة سريعة': 'Quick payment',
  'سداد كامل': 'Pay in full',
  'كشف حساب (طباعة/إرسال)': 'Statement (print/send)',
  'لا زبون يطابق البحث': 'No customer matches the search',
  'مطالبة واتساب': 'WhatsApp reminder',

  // ═══ حساب الزبون ═══
  '{0}  ·  اشتراك #{1}{2}': '{0}  ·  subscription #{1}{2}',
  'أدخل مبلغ صحيح': 'Enter a valid amount',
  'الإجمالي: {0}': 'Total: {0}',
  'الاشتراك يُخصم من السقف عند كل غسلة — القطع أعلاه هي المُستهلكة فعلًا.':
      'The subscription is deducted from the cap on every wash — the pieces above are the actual usage.',
  'الحدّ الأقصى للدين': 'Maximum debt limit',
  'الذمة الحالية': 'Current balance',
  'الفواتير الآجلة ({0})': 'Credit invoices ({0})',
  'تعديل حدّ الدين': 'Edit debt limit',
  'حدّ الدين الآجل': 'Credit debt limit',
  'سجل الدفعات ({0})': 'Payment history ({0})',
  'كشف الحساب': 'Account statement',
  'لا توجد دفعات مسجلة': 'No payments recorded',
  'لا توجد فواتير آجلة': 'No credit invoices',
  'مدفوع: {0}  ·  متبقي: {1}': 'Paid: {0}  ·  Remaining: {1}',
  'ملاحظات (اختياري)': 'Notes (optional)',

  // ═══ مطابقة الأرصدة ═══
  'حركة رصيد': 'Balance entry',
  'دفتر الأستاذ': 'Ledger',
  'رجوع للقائمة': 'Back to list',
  'لا زبائن لهم ذمة أو رصيد قائم':
      'No customers with outstanding debt or balance',
  'مطابقة الأرصدة': 'Balance reconciliation',

  // ═══ كشف الحساب ═══
  'آخر ٣٠ يومًا': 'Last 30 days',
  'أحدّد البداية والنهاية': 'Choose start and end dates',
  'إرسال الكشف PDF (واتساب)': 'Send statement PDF (WhatsApp)',
  'إرسال ملخّص نصّي': 'Send text summary',
  'الشهر السابق كاملًا': 'The entire previous month',
  'الشهر الماضي': 'Last month',
  'الفترة': 'Period',
  'بلا تقييد تاريخي': 'No date restriction',
  'طباعة كشف الحساب': 'Print account statement',
  'عرض سريع على الشاشة': 'Quick on-screen view',
  'كل الفترة': 'All time',
  'ملخّص فوري بلا طباعة': 'Instant summary without printing',
  'من أول الشهر إلى اليوم': 'From the start of the month until today',
  'من اليوم رجوعًا': 'Counting back from today',
  'من تاريخ إلى تاريخ': 'From date to date',
  'تعذّر تجهيز كشف الحساب': 'Could not prepare the account statement',
  'تعذّر توليد ملف الكشف': 'Could not generate the statement file',
  'صورة': 'Photo',
  'صورة البقعة غير متوفرة': 'The stain photo is not available',

  // ═══ المسودات ═══
  '{0} — {1} ر.س': '{0} — {1} SAR',
  'احفظ الفاتورة الحالية للاستكمال لاحقاً':
      'Save the current invoice to continue later',
  'اختر مسودة سابقة وتابع العمل عليها':
      'Choose a previous draft and continue working on it',
  'استعادة مسودة محفوظة': 'Restore a saved draft',
  'استُعيدت المسودة — ستُحذف تلقائيًا بعد إصدار الفاتورة':
      'The draft was restored — it will be deleted automatically after the invoice is issued',
  'الفاتورة فارغة — لا يوجد ما يُحفظ': 'The invoice is empty — nothing to save',
  'المسودات المحفوظة': 'Saved drafts',
  'بدون زبون': 'No customer',
  'تعذر استعادة المسودة': 'Could not restore the draft',
  'تم الاستعادة': 'Restored',
  'حفظ المسودة الحالية': 'Save the current draft',
  'حُفظت المسودة بنجاح — يمكنك استعادتها لاحقاً':
      'The draft was saved successfully — you can restore it later',
  'لا توجد مسودات': 'No drafts',
  'لم تحفظ أي مسودات بعد': 'You have not saved any drafts yet',
  'مسودات': 'Drafts',

  // ═══ الأدوار والصلاحيات ═══
  'أدخل الاسم المعروض والاسم التقني.':
      'Enter the display name and the technical name.',
  'إعادة تسمية': 'Rename',
  'إعادة تسمية الدور': 'Rename role',
  'إنشاء': 'Create',
  'استعادة الافتراضي': 'Restore defaults',
  'الاسم التقني (لاتيني)': 'Technical name (Latin)',
  'الاسم المعروض': 'Display name',
  'الكتالوج': 'Catalog',
  'بدون — ابدأ فارغًا': 'None — start empty',
  'جذر': 'Root',
  'حذف الدور': 'Delete role',
  'دور جديد': 'New role',
  'لكل دور حزمة صلاحيات. أي تغيير هنا يسري فورًا على من يعمل بالدور، ويُسجَّل في سجل التدقيق.':
      'Each role has a permission bundle. Any change here applies immediately to everyone using the role and is recorded in the audit log.',
  'مثال: supervisor': 'Example: supervisor',
  'نسخ صلاحيات (اختياري)': 'Copy permissions (optional)',
  'نظامي': 'System',
  'الفواتير والبيع': 'Invoices and sales',
  'الصندوق والورديات': 'Cash and shifts',
  'الزبائن والذمم': 'Customers and debts',
  'الدفاتر والتقارير': 'Books and reports',
  'المصنعية والاشتراكات': 'Processing and subscriptions',
  'الأصناف والنظام': 'Items and system',
  'الحوكمة والتحكّم': 'Governance and control',
  'مدير النظام': 'System administrator',
  'مدير': 'Manager',
  'محاسب': 'Accountant',
  'مستخدم': 'User',
  'عامل': 'Worker',

  // ═══ سجل الورديات ═══
  'أُقفلت بلا جرد للدرج': 'Closed without a drawer count',
  'إجمالي الوردية': 'Shift total',
  'إعادة طباعة': 'Reprint',
  'الورديات المغلقة وملخصاتها المالية':
      'Closed shifts and their financial summaries',
  'بيانات الفاتورة غير مكتملة': 'Invoice data is incomplete',
  'جرد الدرج': 'Drawer count',
  'ستظهر هنا الورديات بعد إغلاقها من القائمة الجانبية':
      'Shifts will appear here after they are closed from the side menu',
  'طباعة الملخص': 'Print summary',
  'عرض فواتير الوردية': 'View shift invoices',
  'عميل نقدي': 'Cash customer',
  'فواتير الوردية': 'Shift invoices',
  'لا توجد فواتير في هذه الوردية': 'No invoices in this shift',
  'لا توجد ورديات سابقة': 'No previous shifts',

  // ═══ قوالب الطباعة ═══
  'أُعيد القالب إلى الافتراضي': 'The template was restored to its defaults',
  'إيقاف الكل': 'Disable all',
  'ابحث عن عنصر… (مثال: الشعار · الخصم · وقت البدء)':
      'Search for an item… (e.g. logo · discount · start time)',
  'استعادة': 'Restore',
  'استعادة نمط هذا العنصر': 'Restore this item\'s style',
  'الحجم': 'Size',
  'العرض': 'Width',
  'المعاينة تُظهر النصّ وحجمه ووزنه وعرضه تقريبًا (مصغَّرةً لتناسب الشاشة). المقاس النهائي يتبع مقاس الورق في صفحة الطباعة.':
      'The preview shows the text, size, weight, and width approximately (scaled down to fit the screen). The final size follows the paper size on the print page.',
  'الوزن': 'Weight',
  'تصميم الفاتورة وكشف الحساب وملخص الوردية — نصًّا ونمطًا':
      'Design the invoice, account statement, and shift summary — text and style',
  'تفعيل الكل': 'Enable all',
  'تمّ': 'Done',
  'طبّق على القسم': 'Apply to section',
  'قوالب الطباعة': 'Print templates',
  'كل العناصر معطَّلة — الورقة ستخرج فارغة.':
      'All items are disabled — the paper will come out blank.',
  'معاينة مباشرة': 'Live preview',
  'نمط القسم': 'Section style',

  // ═══ مطابقة الأرصدة (تفصيل) ═══
  '{0} حركة مسجّلة': '{0} recorded entries',
  '{0} زبون لهم ذمة أو رصيد — الأكثر فرقًا أولًا':
      '{0} customers with debt or balance — largest difference first',
  '؟': '?',
  'آمن تمامًا: لا يُحذف ولا يُعدَّل أي مبلغ في الفواتير، ولا يُمسّ الدفعات المسجّلة. العملية تُصحّح حقل الرصيد فقط.':
      'Completely safe: no invoice amount is deleted or changed, and recorded payments are untouched. Only the balance field is corrected.',
  'إصدار فاتورة آجلة': 'Issue a credit invoice',
  'إصلاح الآن': 'Repair now',
  'إصلاح الأرصدة يحتاج صلاحية «إصلاح أرصدة الزبائن»، راجع مدير النظام.':
      'Repairing balances requires the "Repair customer balances" permission; contact the system administrator.',
  'إصلاح كل الأرصدة ({0} زبون)': 'Repair all balances ({0} customers)',
  'اختر زبونًا': 'Choose a customer',
  'استخدام رصيد على فاتورة': 'Use balance on an invoice',
  'الدفعات المسجّلة. العملية تُصحّح حقل الرصيد فقط.':
      'recorded payments. The operation corrects only the balance field.',
  'الرصيد المخزَّن': 'Stored balance',
  'الرصيد المخزَّن لكل زبون يساوي ذمته المحتسبة من الفواتير. لا خلل في الكتابة.':
      'Each customer\'s stored balance equals their debt computed from invoices. There is no posting error.',
  'الرصيد بعدها: {0}': 'Balance after: {0}',
  'المخزَّن كمدين (balance)': 'Stored as debit (balance)',
  'المطابقة ودفتر الأستاذ': 'Reconciliation and ledger',
  'تأكيد إصلاح الأرصدة': 'Confirm balance repair',
  'تعذّر الإصلاح': 'Could not repair',
  'تمت المطابقة': 'Reconciliation complete',
  'جارٍ الإصلاح…': 'Repairing…',
  'حدث خطأ أثناء إصلاح الأرصدة، لم تُعدَّل بيانات.':
      'An error occurred while repairing balances; no data was changed.',
  'دين': 'Debt',
  'ذمة {0}': 'Debt {0}',
  'ذمة الفواتير': 'Invoice debt',
  'ذمة الفواتير (الحقيقة)': 'Invoice debt (actual)',
  'رصيد {0}': 'Balance {0}',
  'زبائن بأرصدة غير مطابقة': 'Customers with mismatched balances',
  'سداد عند التسليم': 'Payment on delivery',
  'سلف الزبائن': 'Customer credit',
  'سلفة': 'Credit',
  'سلفة {0}': 'Credit {0}',
  'سيُعاد اشتقاق رصيد {0} زبون من فواتيره الفعلية، فتصبح الأرصدة مطابقة للفواتير تمامًا.\n\nآمن تمامًا: لا يُحذف ولا يُعدَّل أي مبلغ في الفواتير، ولا يُمسّ الدفعات المسجّلة. العملية تُصحّح حقل الرصيد فقط.':
      'The balance of {0} customers will be re-derived from their actual invoices, making balances exactly match the invoices.\n\nCompletely safe: no invoice amount is deleted or changed, and recorded payments are untouched. Only the balance field is corrected.',
  'صُحّح رصيد {0} زبون — أصبح مطابقًا للفواتير':
      'Repaired the balance of {0} customers — now matching the invoices',
  'عليه دين {0}': 'Owes {0}',
  'فرق {0}': 'Difference {0}',
  'كل الأرصدة كانت سليمة، لا حاجة لتعديل':
      'All balances were correct; no change needed',
  'كل الأرصدة مطابقة': 'All balances match',
  'كل الزبائن': 'All customers',
  'لإعادة اشتقاقها من الفواتير.': 'to re-derive them from the invoices.',
  'لا تملك الصلاحية': 'You do not have permission',
  'لا حركات مسجّلة لهذا الزبون': 'No entries recorded for this customer',
  'لا خلل في الكتابة.': 'There is no posting error.',
  'لا ذمة': 'No debt',
  'لعرض سجل كل حركات رصيده زمنيًا — سبب كل تغيير ومقداره':
      'To view each balance movement chronologically — the reason and amount of each change',
  'له سلفة {0}': 'Has credit {0}',
  'متوازن': 'Balanced',
  'مخزَّن الرصيد يختلف عن الذمة الحقيقية من الفواتير':
      'Stored balance differs from the actual invoice debt',
  'مطابقة للفواتير تمامًا.\n\n': 'exactly matching the invoices.\n\n',
  'هذه أرصدة تخزينية تختلف عن مجموع الفواتير — استخدم زر الإصلاح لإعادة اشتقاقها من الفواتير.':
      'These stored balances differ from the invoice total — use the repair button to re-derive them from invoices.',
  'يوجد {0} رصيد غير مطابق': '{0} mismatched balances found',
  'يُسجَّل الدفتر تلقائيًا عند كل دفعة أو إصدار فاتورة آجلة':
      'The ledger is recorded automatically on every payment or credit invoice',
  'آمن تمامًا: لا يُحذف ولا يُعدَّل أي مبلغ في الفواتير، ولا يُمسّ ':
      'Completely safe: no invoice amount is deleted or changed, and ',
  'سيُعاد اشتقاق رصيد {0} زبون من فواتيره الفعلية، فتصبح الأرصدة ':
      'The balance of {0} customers will be re-derived from their actual invoices, making balances ',
  'الرصيد المخزَّن لكل زبون يساوي ذمته المحتسبة من الفواتير. ':
      'Each customer\'s stored balance equals their debt computed from invoices. ',
  'هذه أرصدة تخزينية تختلف عن مجموع الفواتير — استخدم زر الإصلاح ':
      'These stored balances differ from the invoice total — use the repair button ',

  // ═══ الصندوق (تفصيل) ═══
  'أبريل': 'April',
  'أغسطس': 'August',
  'أكتوبر': 'October',
  'اختر الوردية': 'Choose the shift',
  'استرداد كسلفة (ليست نقدية)': 'Refund as credit (not cash)',
  'استهلاك رصيد — {0}': 'Credit use — {0}',
  'الأحد': 'Sunday',
  'الأربعاء': 'Wednesday',
  'الإثنين': 'Monday',
  'الثلاثاء': 'Tuesday',
  'الجمعة': 'Friday',
  'الخميس': 'Thursday',
  'السبت': 'Saturday',
  'تجديد اشتراك': 'Subscription renewal',
  'دفعة يدوية': 'Manual payment',
  'ديسمبر': 'December',
  'رصيد افتتاح يوم العمل ({0} ورديات)':
      'Business day opening balance ({0} shifts)',
  'سبتمبر': 'September',
  'سداد دين — {0}': 'Debt payment — {0}',
  'فبراير': 'February',
  'فروق الجرد (زيادة)': 'Count differences (over)',
  'فروق الجرد (عجز)': 'Count differences (short)',
  'فروق الجرد (مطابقة)': 'Count differences (matched)',
  'لا توجد عمليات': 'No transactions',
  'لا توجد ورديات مسجّلة': 'No shifts recorded',
  'مارس': 'March',
  'مايو': 'May',
  'من الرصيد (ليست نقدية)': 'From balance (not cash)',
  'نوفمبر': 'November',
  'يناير': 'January',
  'يوليو': 'July',
  'يونيو': 'June',
  '{0} ريال': '{0} SAR',

  // ═══ الاشتراكات (تفصيل) ═══
  'لا يوجد اشتراك يستحقّ التجديد خلال الأيام السبعة ':
      'No subscription is due for renewal within the next seven ',
  'القادمة.': 'days.',
  '{0} ر.س — يغطي حتى {1}': '{0} SAR — covers until {1}',
  'بعد {0} يوم': 'In {0} days',
  'دراسة نهاية الشهر — {0}': 'End-of-month study — {0}',
  'الاشتراك: {0} ر.س — {1} فاتورة هذا الشهر، ':
      'Subscription: {0} SAR — {1} invoices this month, ',
  'قيمة غسيله الفعلية {2} ر.س ': 'actual laundry value {2} SAR ',
  '(التغطية: {0} ر.س)': '(coverage: {0} SAR)',
  '• {0} ({1}) × {2} = {3} ر.س': '• {0} ({1}) × {2} = {3} SAR',
  'إضافة اشتراك شهري': 'Add monthly subscription',
  '{0} / {1} ر.س': '{0} / {1} SAR',
  'السقف مستهلك بالكامل — لن تُقبل فاتورة جديدة إلا ':
      'The cap is fully used — no new invoice will be accepted except ',
  'بموافقة مدير أو تجديد': 'with manager approval or renewal',
  'فواتير هذا الشهر: {0} ': 'Invoices this month: {0} ',
  'بقيمة {1} ر.س ': 'worth {1} SAR ',
  '(محفوظة داخلياً — تُطبع بدون أسعار)':
      '(stored internally — printed without prices)',
  'السقف يحمي من اشتراك صغير يستهلك غسيلًا بلا حدّ. ':
      'The cap protects against a small subscription consuming unlimited laundry. ',
  'اتركه فارغًا أو صفرًا لإلغاء السقف. يُطبَّق أيّهما استُنفد أولًا.':
      'Leave it empty or zero to cancel the cap. Whichever is exhausted first applies.',
  'متبقٍّ {0} يوم من أصل {1} — ': '{0} days remaining out of {1} — ',
  '{2} ر.س/يوم. ': '{2} SAR/day. ',
  'هذا المبلغ مقابل خدمة لن تُقدَّم، فلا يصحّ أن يبقى ':
      'This amount is for a service that will not be provided, so it should not remain ',
  'إيرادًا للمحل.': 'revenue for the shop.',
  'يبقى في الدرج كسلفة للزبون، ويُخصم تلقائيًا من ':
      'It stays in the drawer as customer credit and is deducted automatically from ',
  'فواتيره القادمة. لا يُخرج نقدية.':
      'their future invoices. No cash leaves the drawer.',
  'يُخرج المبلغ من الدرج ويُسجَّل في المصروفات، ':
      'The amount leaves the drawer and is recorded as an expense, ',
  'فيظهر في إقفال الوردية.': 'so it appears in the shift closing.',
  'لا توجد أيام مدفوعة متبقّية — الإلغاء تعطيل ':
      'No paid days remain — cancellation is a simple ',
  'بسيط بلا استرداد.': 'deactivation with no refund.',
  'سعر الاشتراك صفر — لا يمكن احتساب قيمة أيام ':
      'Subscription price is zero — the value of days cannot be calculated ',
  'للتسوية.': 'for settlement.',
  'إلغاء من شاشة الاشتراكات': 'Cancellation from subscriptions screen',
  'الاشتراك: {0} ر.س / {1} يوم — ': 'Subscription: {0} SAR / {1} days — ',
  'التغطية الحالية حتى {2}': 'current coverage until {2}',

  // ═══ لوحة الاشتراكات (تفصيل) ═══
  'الربحية والالتزامات والإيراد المتكرّر':
      'Profitability, obligations, and recurring revenue',
  'المطابقة المحاسبية': 'Accounting reconciliation',
  'ما قُبض نقدًا مقابل ما قُدِّم من خدمة':
      'Cash collected versus service delivered',
  'حالة المحفظة': 'Portfolio status',
  'توزيع المشتركين على الحالات': 'Distribution of subscribers by status',
  'مراقبة السقف': 'Cap monitoring',
  'اشتراكات بلغت 80% من حدّها أو تجاوزته':
      'Subscriptions at or above 80% of their cap',
  'ربحية المشتركين': 'Subscriber profitability',
  'الأكثر خسارة أولًا — {0} ← {1}': 'Largest loss first — {0} ← {1}',
  'الإيراد الشهري المتكرّر (MRR)': 'Monthly recurring revenue (MRR)',
  'مُطبَّع على شهر 30 يومًا — الاشتراكات ذات المدد المختلفة مُوحَّدة ':
      'Normalized to a 30-day month — subscriptions of different durations are unified ',
  'لتصبح قابلة للجمع': 'so they can be summed',
  'مُطبَّع على شهر 30 يومًا — الاشتراكات ذات المدد المختلفة مُوحَّدة لتصبح قابلة للجمع':
      'Normalized to a 30-day month — subscriptions of different durations are unified so they can be summed',
  'التزام متبقٍّ': 'Remaining obligation',
  'خدمة لم تُقدَّم': 'Service not yet provided',
  'محصَّل هذا الشهر': 'Collected this month',
  'نقدية': 'Cash',
  'إيراد مُعترف به': 'Recognized revenue',
  'قبضنا أكثر مما قدّمنا ⇒ الرصيد خدمة غير مُقدَّمة، ':
      'We collected more than we provided ⇒ the balance is unprovided service, ',
  'وليس ربحًا خالصًا. سيُستنفد مع استمرار الغسيل.':
      'not pure profit. It will be consumed as laundry continues.',
  'قبضنا أكثر مما قدّمنا ⇒ الرصيد خدمة غير مُقدَّمة، وليس ربحًا خالصًا. سيُستنفد مع استمرار الغسيل.':
      'We collected more than we provided ⇒ the balance is unprovided service, not pure profit. It will be consumed as laundry continues.',
  'قدّمنا خدمة أكثر مما قبضنا ⇒ ذمم أو تجاوزات تستحق ':
      'We provided more service than we collected ⇒ receivables or overages requiring ',
  'المتابعة والتحصيل.': 'follow-up and collection.',
  'قدّمنا خدمة أكثر مما قبضنا ⇒ ذمم أو تجاوزات تستحق المتابعة والتحصيل.':
      'We provided more service than we collected ⇒ receivables or overages requiring follow-up and collection.',
  'إجمالي {0} اشتراك — القطع المُستهلكة هذا الشهر: {1}':
      'Total {0} subscriptions — pieces consumed this month: {1}',
  'القطع: {0} / {1}': 'Pieces: {0} / {1}',
  'القيمة: {0} / {1}': 'Value: {0} / {1}',
  'حتى {0}': 'Until {0}',
  'يحتاج تجديدًا أو رفع سقف قبل الفاتورة القادمة.':
      'Needs renewal or a cap increase before the next invoice.',
  'راقبه — يقترب من الحدّ.': 'Watch it — approaching the limit.',
  'خاسر': 'Loss-making',
  'هامش {0}%': 'Margin {0}%',
  'القطع: {0}': 'Pieces: {0}',
  'القيمة المستهلكة: {0}': 'Consumed value: {0}',
  'الاستهلاك من السعر: {0}%': 'Consumption of price: {0}%',
  'تكلفة الخدمة تتجاوز ما حُصِّل — هذا الاشتراك يُنزف. ':
      'Cost of service exceeds what was collected — this subscription is losing money. ',
  'الخيارات: رفع السعر، تقليص السقف، أو إنهاء الاشتراك.':
      'Options: raise the price, reduce the cap, or end the subscription.',
  'تكلفة الخدمة تتجاوز ما حُصِّل — هذا الاشتراك يُنزف. الخيارات: رفع السعر، تقليص السقف، أو إنهاء الاشتراك.':
      'Cost of service exceeds what was collected — this subscription is losing money. Options: raise the price, reduce the cap, or end the subscription.',

  // ═══ أعمار الديون (تفصيل) ═══
  'أعمار الديون': 'Debt aging',
  'لا توجد ذمم قائمة': 'No outstanding debts',
  'كل فواتير الزبائن مسدّدة بالكامل': 'All customer invoices are fully paid',
  'إجمالي الذمم القائمة': 'Total outstanding debts',
  '{0} زبون · {1} فاتورة': '{0} customers · {1} invoices',
  'أكبر تركيز: {0} ({1} ر.س — {2}%)':
      'Largest concentration: {0} ({1} SAR — {2}%)',
  'لا ديون متأخرة أكثر من 90 يومًا — لا حاجة لمخصص':
      'No debts overdue more than 90 days — no provision needed',
  'المخصص المقترح للديون المشكوك في تحصيلها':
      'Proposed provision for doubtful debts',
  'على المتأخر أكثر من 90 يومًا ({0} ر.س) بنسبة {1}% — سياسة تحفّظية قابلة للتعديل من إعداد «نسبة مخصص الديون».':
      'On amounts overdue more than 90 days ({0} SAR) at {1}% — a conservative policy adjustable from the "Debt provision rate" setting.',
  'أقدم {0} يوم': 'Oldest {0} days',
  'دلالة الفئات العمرية': 'Aging bucket legend',
  'ذمة حديثة — متابعة عادية': 'Recent debt — normal follow-up',
  'تأخر مبدئي — تذكير أول': 'Initial delay — first reminder',
  'تأخر مقلق — مطالبة جدّية': 'Concerning delay — serious claim',
  'مشكوك في تحصيله — يُكوَّن مخصص':
      'Doubtful collection — provision is created',
  'دفعة من {0}': 'Payment from {0}',
  'الذمة القائمة:': 'Outstanding debt:',
  'يُوزَّع المبلغ على الفواتير الأقدم أولًا، وأي فائض يصبح ':
      'The amount is allocated to the oldest invoices first, and any surplus becomes ',
  'رصيدًا دائنًا للزبون (سلفة).': 'customer credit (advance).',
  'يُوزَّع المبلغ على الفواتير الأقدم أولًا، وأي فائض يصبح رصيدًا دائنًا للزبون (سلفة).':
      'The amount is allocated to the oldest invoices first, and any surplus becomes customer credit (advance).',
  'سُجّلت دفعة {0} ر.س من {1}': 'Recorded a payment of {0} SAR from {1}',
  'تعذر تسجيل الدفعة — أعد المحاولة':
      'Could not record the payment — try again',
  '{0} فاتورة مفتوحة · أقدمها {1} يوم': '{0} open invoices · oldest {1} days',
  'تاريخ غير معروف': 'Unknown date',
  '{0} · منذ {1} يوم': '{0} · {1} days ago',
  'تمت العملية': 'Operation completed',
  'متوسط': 'Medium',
  'مرتفع': 'High',
  'مشكوك في تحصيله': 'Doubtful collection',

  // ═══ حساب الزبون (تفصيل) ═══
  'لا توجد بيانات': 'No data',
  'المتبقي: {0} ريال': 'Remaining: {0} SAR',
  'عليه دين': 'Owes debt',
  'له رصيد (سلفة)': 'Has credit (advance)',
  'الرصيد': 'Balance',
  'تجاوز حدّ الدين ({0} ر.س)': 'Exceeded credit limit ({0} SAR)',
  'حدّ الدين: {0} ر.س': 'Credit limit: {0} SAR',
  'إجمالي المشتريات: {0} ر.س': 'Total purchases: {0} SAR',
  '{0} نقطة': '{0} points',
  'استخدم الرصيد ({0}) لسداد الذمم': 'Use balance ({0}) to settle debts',
  'اتركه فارغًا أو صفرًا لإلغاء الحدّ':
      'Leave it empty or zero to cancel the limit',
  'حُدّد سقف الدين الآجل بمبلغ {0} ر.س': 'Credit limit set to {0} SAR',
  'أُلغي سقف الدين الآجل لهذا الزبون':
      'The credit limit was cancelled for this customer',
  'تعذر حفظ حدّ الائتمان — أعد المحاولة':
      'Could not save the credit limit — try again',
  '+{0} ريال': '+{0} SAR',
  'الأصناف التي أخذها': 'Items taken',
  'سجل الاشتراك الشهري': 'Monthly subscription history',
  '{0} قطعة · {1} ر.س': '{0} pieces · {1} SAR',
  '  ·  فاتورة #{0}': '  ·  Invoice #{0}',

  // ═══ الأدوار والصلاحيات (تفصيل) ═══
  '{0} صلاحية موزَّعة على {1} مجموعات':
      '{0} permissions distributed across {1} groups',
  '{0} صلاحية · {1} مستخدم': '{0} permissions · {1} users',
  'دور الجذر يملك كل صلاحيات الكتالوج ({0}) ولا يقبل التعديل — يضمن وجود سلطة عليا تُعيد ضبط النظام.':
      'The root role has all catalog permissions ({0}) and cannot be edited — it guarantees a supreme authority that can reset the system.',
  'سحب المجموعة': 'Revoke group',
  'منح المجموعة': 'Grant group',
  'مالي': 'Financial',
  'أمني': 'Security',
  'ستُستبدل حزمة «{0}» بالحزمة الافتراضية ({1} صلاحية).':
      'The bundle "{0}" will be replaced with the default bundle ({1} permissions).',
  'سيُحذف «{0}» بصلاحياته. لا يمكن التراجع.':
      '"{0}" and its permissions will be deleted. This cannot be undone.',
  'الاسم التقني «{0}» لا يتغيّر': 'The technical name "{0}" does not change',
  '{0} ({1} صلاحية)': '{0} ({1} permissions)',

  // ═══ سجل الورديات (تفصيل) ═══
  'وردية رقم {0}': 'Shift #{0}',
  'البداية': 'Start',
  'النهاية': 'End',
  'مطابق': 'Matched',
  'زيادة {0}': 'Over by {0}',
  'عجز {0}': 'Short by {0}',
  'المتوقع: {0}': 'Expected: {0}',
  'المعدود: {0}': 'Counted: {0}',
  'السبب: {0}': 'Reason: {0}',
  'الوردية رقم {0}': 'Shift #{0}',
  '{0} و {1} أصناف أخرى': '{0} and {1} other items',

  // ═══ قوالب الطباعة (تفصيل) ═══
  'تعذّر الحفظ': 'Could not save',
  'سيُعاد قالب «{0}» إلى نصوصه وتفعيلاته وأحجامه الأصلية، وتُفقد كل تعديلاتك عليه.':
      'The template "{0}" will be restored to its original texts, toggles, and sizes, and all your edits will be lost.',
  'الرياض – حي النخيل': 'Riyadh – Al Nakheel District',
  '{0}: محمد صادق': '{0}: Mohammed Sadiq',
  '{0}: بقعة زيت على الكم': '{0}: oil stain on the sleeve',
  'قميص (قطن)': 'Shirt (cotton)',
  '{0}: نقد': '{0}: cash',
  '{0}: من 2026-10-01 إلى 2026-10-24': '{0}: from 2026-10-01 to 2026-10-24',
  'عنوان قسم': 'Section title',
  'شكرًا لتعاملكم معنا': 'Thank you for your business',
  '«شعار النشاط»': '"Business logo"',
  '«رمز QR»': '"QR code"',
  '«صور القطع»': '"Item photos"',
  '«ملخّص الإجماليات»': '"Totals summary"',
  'نمط موحّد — {0}': 'Unified style — {0}',
  'طُبِّق النمط على {0} عنصرًا': 'Style applied to {0} items',
  'من معلومات النشاط': 'From business info',
  'فارغ ⇒ «{0}»': 'Empty ⇒ "{0}"',
  'جارٍ الحفظ…': 'Saving…',
  'تعديلات غير محفوظة بعد…': 'Unsaved changes…',
  'كل شيء محفوظ': 'Everything is saved',
  'محفوظ · آخر حفظ {0}': 'Saved · last saved {0}',
  'المعاينة تُظهر النصّ وحجمه ووزنه وعرضه تقريبيًا (مصغَّرةً لتناسب ':
      'The preview shows text, size, weight, and width approximately (scaled to fit ',
  'الشاشة). المقاس النهائي يتبع مقاس الورق في صفحة الطباعة.':
      'the screen). The final size follows the paper size on the print page.',
  'المعاينة تُظهر النصّ وحجمه ووزنه وعرضه تقريبيًا (مصغَّرةً لتناسب الشاشة). المقاس النهائي يتبع مقاس الورق في صفحة الطباعة.':
      'The preview shows text, size, weight, and width approximately (scaled to fit the screen). The final size follows the paper size on the print page.',
  '{0} ({1}) سيتم حذفه من الفاتورة.':
      '{0} ({1}) will be deleted from the invoice.',

  // ═══ إدارة المستخدمين (تفصيل) ═══
  'إضافة وتعديل وحذف المستخدمين': 'Add, edit, and delete users',
  'إضافة مستخدم جديد': 'Add new user',
  'لا يوجد مستخدمين': 'No users',
  'الاسم الكامل': 'Full name',
  'اسم المستخدم': 'Username',
  'كلمة المرور': 'Password',
  'الدور': 'Role',
  'أدخل جميع البيانات المطلوبة': 'Enter all required data',
  'تعديل المستخدم': 'Edit user',
  'كلمة المرور الجديدة (اتركها فارغة)': 'New password (leave empty to keep)',
  'نشط:': 'Active:',
  'أدخل البيانات المطلوبة': 'Enter the required data',
  'حذف المستخدم': 'Delete user',
  'هل أنت متأكد من حذف "{0}"؟': 'Are you sure you want to delete "{0}"?',

  // ═══ صلاحيات المستخدم (تفصيل) ═══
  'الدور: {0} · {1} صلاحية موروثة{2}':
      'Role: {0} · {1} inherited permissions{2}',
  ' · {0} تجاوز': ' · {0} overrides',
  'مسح الكل': 'Clear all',
  'موروث': 'Inherited',
  'ممنوح': 'Granted',
  'مسحوب': 'Revoked',
  '{0} متجاوز': '{0} overridden',
  'موروث — يتبع الدور': 'Inherited — follows the role',
  'ممنوح — فوق الدور': 'Granted — above the role',
  'مسحوب — دون الدور': 'Revoked — below the role',
  'مسح التجاوزات': 'Clear overrides',
  'سيُعاد «{0}» إلى حزمة دوره وحدها.':
      '"{0}" will be returned to their role bundle only.',

  // ═══ سجل الترخيص (تفصيل) ═══
  'سجل الترخيص': 'License log',
  'حالة الاشتراك وتغييرات تاريخ الانتهاء':
      'Subscription status and expiry date changes',
  'غير محدود': 'Unlimited',
  'مطابق للتاريخ المضمَّن في الكود': 'Matches the date embedded in code',
  'مُعيَّن يدويًا من داخل النظام': 'Set manually from within the system',
  'حالة الترخيص': 'License status',
  'بلا حد': 'No limit',
  'يومًا متبقيًا': 'days remaining',
  'سجل التغييرات': 'Change log',
  '{0} تطبيق كود': '{0} code applications',
  '{0} تجديد': '{0} renewals',
  'لا توجد تغييرات مسجّلة على الترخيص': 'No license changes recorded',
  'يُسجَّل هنا كل تطبيق لتاريخ الكود وكل تجديد أو تعديل يدوي، ':
      'Every application of the code date, renewal, or manual change is recorded here, ',
  'باسم من نفّذه ووقته.': 'with who performed it and when.',
  'يُسجَّل هنا كل تطبيق لتاريخ الكود وكل تجديد أو تعديل يدوي، باسم من نفّذه ووقته.':
      'Every application of the code date, renewal, or manual change is recorded here, with who performed it and when.',
  'تعذّر قراءة تفاصيل الحدث': 'Could not read event details',
  'تلقائي — عند تشغيل النظام': 'Automatic — at system startup',
  'غير معروف': 'Unknown',

  // ═══ تجديد الترخيص (تفصيل) ═══
  'بيانات مدير النظام غير صحيحة':
      'System administrator credentials are incorrect',
  'اختر تاريخ انتهاء الاشتراك': 'Choose the subscription expiry date',
  'تم التجديد': 'Renewed',
  'أصبح اشتراك النظام سارٍ حتى {0}':
      'The system subscription is now valid until {0}',
  'تجديد اشتراك النظام': 'Renew system subscription',
  'اختر تاريخ انتهاء الاشتراك الجديد.':
      'Choose the new subscription expiry date.',
  'أدخل بيانات مدير النظام (admin) للتجديد.':
      'Enter the system administrator (admin) credentials to renew.',
  'ينتهي في {0}': 'Expires on {0}',
  'تغيير': 'Change',
  'تجديد وتفعيل': 'Renew and activate',
  'تحقق من الهوية': 'Verify identity',

  // ═══ الترحيب (تفصيل) ═══
  'حدث خطأ أثناء الحفظ: {0}': 'An error occurred while saving: {0}',
  'مرحباً بك في نظام إدارة المغاسل': 'Welcome to the laundry management system',
  'أدخل معلومات نشاطك التجاري لتبدأ':
      'Enter your business information to get started',
  'اسم النشاط التجاري': 'Business name',
  'مثال: مغاسل النظارة': 'Example: Al Nadhara Laundry',
  'أدخل اسم النشاط': 'Enter the business name',
  'مثال: 05XXXXXXXX': 'Example: 05XXXXXXXX',
  'أدخل رقم الهاتف': 'Enter the phone number',
  'مثال: الرياض - حي اشبيليا': 'Example: Riyadh - Al Ishbiliya',
  'أدخل العنوان': 'Enter the address',
  'رابط الموقع على خرائط جوجل': 'Google Maps location link',
  'اختياري — الصق رابط Google Maps': 'Optional — paste a Google Maps link',
  'بدء الاستخدام': 'Get started',
  'يمكنك تعديل هذه المعلومات لاحقاً من الإعدادات':
      'You can edit this information later from Settings',

  // ═══ لوحة التحكم (تفصيل) ═══
  '{0} مبيعة': '{0} sales',
  'الأسبوع الماضي': 'Last week',
  'الأصناف الأكثر مبيعاً': 'Best-selling items',
  'الفواتير اليوم': 'Invoices today',
  'تحديث البيانات': 'Refresh data',
  'توقع مبيعات اليوم حتى الآن: {0} ر.س':
      'Today\'s sales forecast so far: {0} SAR',
  'ساعات الذروة (آخر 7 أيام)': 'Peak hours (last 7 days)',
  'صافي الربح': 'Net profit',
  'طرق الدفع اليوم': 'Payment methods today',
  'لا توجد بيانات بعد': 'No data yet',
  'مبيعات آخر 7 أيام': 'Sales for the last 7 days',
  'مبيعات الأمس': 'Yesterday\'s sales',
  'مبيعات اليوم': 'Today\'s sales',
  'متوسط الفاتورة': 'Average invoice',
  'ملخص أداء المغسلة اليوم': 'Today\'s laundry performance summary',

  // ═══ النسخ الاحتياطي (تفصيل) ═══
  'إنشاء واستعادة بيانات النظام': 'Create and restore system data',
  'النسخ الاحتياطي والاستعادة لمدير النظام (admin) وحده':
      'Backup and restore are for the system administrator (admin) only',
  'صيغة النسخة والمكان': 'Backup format and location',
  'الصيغة': 'Format',
  'ملف قاعدة بيانات SQLite خام بامتداد .db — يُفتح بأي أداة SQLite ويُستعاد مباشرة':
      'A raw SQLite database file with the .db extension — it opens in any SQLite tool and restores directly',
  'الحفظ': 'Saving',
  'كل نسخة تُحفظ مرتين: داخل التطبيق دائمًا، وفي المكان الذي تختاره من حوار الحفظ':
      'Every backup is saved twice: always inside the app, and in the location you choose in the save dialog',
  'مجلد النسخ': 'Backup folder',
  'آخر نسخة': 'Last backup',
  'آخر استعادة': 'Last restore',
  'إنشاء نسخة احتياطية': 'Create a backup',
  'تسميتها واختيار مكان حفظها': 'Name it and choose where to save it',
  'استعادة من ملف على الجهاز': 'Restore from a file on the device',
  'اختر أي ملف .db — مثل نسخة وصلت عبر واتساب':
      'Choose any .db file — such as a backup received via WhatsApp',
  'النسخ المحفوظة داخل التطبيق': 'Backups saved inside the app',
  'لا توجد نسخ محفوظة بعد': 'No backups saved yet',
  'قبل كل استعادة يأخذ النظام نسخة أمان تلقائية من بياناتك الحالية، ويرفض أي ملف ليس قاعدة بيانات سليمة. وبعد الاستعادة يلزم إعادة تشغيل النظام لتحميل البيانات الجديدة.':
      'Before each restore, the system automatically takes a safety backup of your current data and rejects any file that is not a valid database. After restoring, the system must be restarted to load the new data.',
  'أُخذت النسخة': 'Backup taken',
  'أُلغي اختيار المكان، وحُفظت النسخة داخل التطبيق: {0}':
      'Location selection was cancelled, and the backup was saved inside the app: {0}',
  'حُفظت في: {0} ({1})': 'Saved to: {0} ({1})',
  'تعذّر اختيار الملف': 'Could not select the file',
  'ملف غير صالح': 'Invalid file',
  'الملف ليس نسخة احتياطية صالحة': 'The file is not a valid backup',
  'فشلت الاستعادة': 'Restore failed',
  'تعذّر إكمال العملية: {0}': 'Could not complete the operation: {0}',
  'حذف النسخة؟': 'Delete the backup?',
  'تعذّر الحذف': 'Could not delete',
  'تم الحذف': 'Deleted',
  'حُذفت النسخة: {0}': 'Backup deleted: {0}',
  'اسم النسخة الاحتياطية': 'Backup name',
  'اسم الملف': 'File name',
  'يمكنك كتابة أي اسم — وستُطبَّع الأحرف الممنوعة':
      'You can enter any name — forbidden characters will be normalized',
  'الصيغة: ملف SQLite خام بامتداد .db':
      'Format: a raw SQLite file with the .db extension',
  'بعد الموافقة سيُفتح حوار لاختيار مكان الحفظ؛ وتبقى نسخة داخل التطبيق في كل الأحوال.':
      'After confirming, a dialog opens to choose the save location; a copy always remains inside the app.',
  'متابعة للحفظ': 'Continue to save',
  'تأكيد الاستعادة': 'Confirm restore',
  'ستستبدل بيانات النظام الحالية ببيانات هذه النسخة:':
      'The current system data will be replaced with the data from this backup:',
  'الملف': 'File',
  'عدد الفواتير': 'Invoice count',
  'عدد المستخدمين': 'User count',
  'أحدث فاتورة': 'Latest invoice',
  'سيأخذ النظام نسخة أمان من بياناتك الحالية قبل الاستبدال، ويعيدها تلقائيًا إن فشل الفحص.':
      'The system takes a safety backup of your current data before replacement and restores it automatically if validation fails.',
  'استعادة الآن': 'Restore now',
  'تمت الاستعادة': 'Restore complete',
  'نسخة الأمان': 'Safety backup',
  'قاعدة البيانات استُبدلت بالكامل، وكل الشاشات المفتوحة تحمل بيانات قديمة في الذاكرة. لذلك يُغلق التطبيق الآن — افتحه من جديد فتُقرأ البيانات المستعادة من أول لحظة.':
      'The database has been fully replaced, and all open screens still hold old data in memory. The app will close now — reopen it so the restored data is read from the start.',
  'إغلاق التطبيق الآن': 'Close the app now',

  // ═══ المصادقة (تفصيل) ═══
  'أدخل اسم المستخدم وكلمة المرور': 'Enter the username and password',
  'اسم المستخدم غير موجود': 'Username not found',
  'كلمة المرور غير صحيحة': 'Incorrect password',
  'اسم المستخدم أو كلمة المرور غير صحيحة': 'Incorrect username or password',

  // ═══ خيارات الإعدادات (تفصيل) ═══
  'أول رقم يُمنح لفاتورة جديدة. لا يقلّل الترقيم إن وُجدت فاتورة برقم أعلى.':
      'The first number assigned to a new invoice. Numbering is not lowered if a higher-numbered invoice exists.',
  'عند التفعيل لا تُصدر الفاتورة بلا زبون مُسجَّل — يفيد لمتابعة الذمم وإشعارات الجاهزية.':
      'When enabled, an invoice cannot be issued without a registered customer — useful for tracking receivables and ready notifications.',
  'عند التعطيل يُمنع تسجيل ذمة على أي زبون (كاش ودفع إلكتروني فقط).':
      'When disabled, credit cannot be recorded for any customer (cash and electronic payment only).',
  'طبع رمز الاستجابة السريعة. لا يُطبع فعلًا إلا عند تفعيل الضريبة ووجود رقم ضريبي للنشاط.':
      'Print the QR code. It is only printed when tax is enabled and the business has a tax number.',
  'بلا تقريب': 'No rounding',
  'أقرب 0.05': 'Nearest 0.05',
  'أقرب 0.25': 'Nearest 0.25',
  'أقرب ريال': 'Nearest riyal',
  'الخطّ المستخدم في طباعة كل المستندات. للحراري اختر خطًّا خفيفًا (IBM Plex خفيف · المراعي خفيف · المهنّد).':
      'The font used to print all documents. For thermal printing, choose a light font (IBM Plex Light · Almarai Light · Al Mohanad).',
  'المهنّد (الافتراضي)': 'Al Mohanad (default)',
  'IBM Plex — خفيف': 'IBM Plex — Light',
  'المراعي — خفيف': 'Almarai — Light',
  'نوتو سانس': 'Noto Sans',
  'نسخ نوتو': 'Noto Naskh',
  'تجوال': 'Tajawal',
  'المراعي': 'Almarai',
  'القاهرة': 'Cairo',
  'كوفي نوتو': 'Noto Kufi',
  'أميري': 'Amiri',
  'المقاس الافتراضي لطباعة الفاتورة. الحرارية 80/58 مم للطابعات الحرارية.':
      'The default invoice paper size. Thermal 80/58 mm is for thermal printers.',
  'حراري 80 مم': 'Thermal 80 mm',
  'حراري 58 مم': 'Thermal 58 mm',
  'ملصق 50×30 مم': 'Label 50×30 mm',
  'ملصق 40×30 مم': 'Label 40×30 mm',
  'بلا ملصقات': 'No labels',
  'عند التفعيل يُفتح حوار لاختيار المقاس (وكل المقاسات المسموحة) قبل كل طباعة بدل الالتزام بالمقاس الافتراضي.':
      'When enabled, a dialog opens to choose the size (and all allowed sizes) before each print instead of using the default size.',
  'عند التفعيل تُطبَع الفاتورة مباشرةً على الطابعة المختارة في قسم «الطابعة الافتراضية» بلا أي حوار طباعة. عند التعطيل يظهر حوار طباعة النظام في كل مرة.':
      'When enabled, the invoice prints directly on the printer selected in the “Default printer” section without any print dialog. When disabled, the system print dialog appears each time.',
  'عند التعطيل لا تُطبَع الفاتورة عند إتمام البيع إطلاقًا (نقطة بيع بلا ورق). أما الطباعة اليدوية من شاشات الفواتير والورديات فتبقى تعمل.':
      'When disabled, the invoice is not printed at all when a sale completes (paperless point of sale). Manual printing from invoice and shift screens still works.',
  'تُحفَظ نسخة PDF من الفاتورة فور إتمام البيع في المجلد المحدَّد بالأسفل. مستقلّ عن الطباعة: يمكن الجمع بينهما أو تشغيل أحدهما.':
      'A PDF copy of the invoice is saved as soon as the sale completes in the folder specified below. It is independent of printing: both can be combined or either can be enabled.',
  'المسار الكامل لمجلد الحفظ. يمكن كتابته هنا أو اختياره بالزر أدناه. فارغ = المجلد الافتراضي داخل «المستندات».':
      'The full save-folder path. You can type it here or choose it with the button below. Empty = the default folder inside “Documents”.',
  'المسار الكامل لمجلد الحفظ. يمكن كتابته هنا أو اختياره بالزر أدناه. فارغ = المجلد الافتراضي داخل «المستندات». وهو المجلد نفسه الذي تُحفظ فيه كشوف الحساب وملخصات الورديات، فكل ما يُخرجه النظام تجده في مكان واحد.':
      'The full save-folder path. You can type it here or choose it with the button below. Empty = the default folder inside “Documents”. It is the same folder used for account statements and shift summaries, so everything the system outputs sits in one place.',
  'المفتاح الأكبر: عند التفعيل تُحتسب الضريبة على كل فاتورة وتُخزَّن وتُطبع وتُخصم من الربح لأنها التزام لا إيراد. وعند التعطيل تُصفَّر في كل الوحدات ولا يُطبع QR ولا يُبنى أي إرسال للهيئة.':
      'The main switch: when enabled, tax is calculated on every invoice, stored, printed, and deducted from profit because it is a liability, not revenue. When disabled, it is zeroed across all modules, no QR is printed, and no submission to the authority is built.',
  'كنسبة عشرية: 0.15 = 15%. القيمة محصورة بين 0 و1. تُجمَّد النسبة في كل فاتورة عند إصدارها، فلا يُعيد تغييرها لاحقًا كتابة ضريبة فاتورة قديمة.':
      'As a decimal: 0.15 = 15%. The value is limited between 0 and 1. The rate is frozen on each invoice when issued, so changing it later does not rewrite an old invoice’s tax.',
  'التفعيل يعني أن السعر المعروض للزبون يحتوي الضريبة (تُستخرج منه). والتعطيل يعني أن الضريبة تُضاف فوق السعر عند الدفع.':
      'Enabling means the price shown to the customer includes tax (it is extracted from it). Disabling means tax is added on top of the price at payment.',
  'عند التعطيل تبقى فواتير الاشتراكات معفاة (لا ضريبة على مبلغ مُحصَّل سابقًا)، وعند التفعيل تُحتسب عليها ضريبة.':
      'When disabled, subscription invoices remain exempt (no tax on an amount already collected); when enabled, tax is calculated on them.',
  'أرقام تصنيفات مفصولة بفواصل (نسبة صفرية). اتركه فارغًا إن كان كل النشاط خاضعًا.':
      'Comma-separated category IDs (zero rate). Leave empty if the entire business is taxable.',
  'سطر «ضريبة محصّلة (التزام غير نقدي)» في تقرير الصندوق. لا تُحسب ضمن النقدية الداخلة.':
      'The “Collected tax (non-cash liability)” line in the cash report. It is not counted as cash inflow.',
  'المفتاح الذي يسمح بطباعة QR والتكامل الضريبي. لا يعني تفعيل الضريبة نفسه — بل جاهزية النشاط للربط بالهيئة.':
      'The switch that allows QR printing and tax integration. It does not mean tax itself is enabled — it means the business is ready to connect to the authority.',
  'ترميز حقول الهيئة الخمسة في QR. لا يُطبع إلا عند وجود رقم ضريبي وتفعيل الضريبة.':
      'Encode the authority’s five fields in the QR. It is only printed when a tax number exists and tax is enabled.',
  'بناء بنية UBL والتوقيع وحالة الفاتورة استعدادًا للربط الفعلي. التشغيل لا يفتح أي اتصال شبكة بحد ذاته.':
      'Build the UBL structure, signature, and invoice status in preparation for actual integration. Enabling it does not open any network connection by itself.',
  'نقدي (حسب التحصيل) أو استحقاق (حسب الإصدار). يحدّد نطاق تجميع ضريبة المخرجات في تقرير الإقرار.':
      'Cash (on collection) or accrual (on issue). It determines the scope of output-tax aggregation in the return report.',
  'استحقاق': 'Accrual',
  'نقدي': 'Cash',
  'عند التفعيل يُمنع البيع الآجل عند بلوغ الحدّ إلا بتجاوز مدير، وعند التعطيل يُكتفى بالتنبيه.':
      'When enabled, credit sales are blocked once the limit is reached unless a manager overrides; when disabled, a warning is sufficient.',
  'قياسي (4 حالات)': 'Standard (4 states)',
  'موسّع (6 حالات)': 'Extended (6 states)',
  'كاش': 'Cash',
  'شبكة': 'Card',
  'آجل': 'Credit',
  'الاسم: أ ← ي': 'Name: A → Z',
  'الاسم: ي ← أ': 'Name: Z → A',
  'بدون فرز': 'No sorting',
  'السعر: الأقل أولًا': 'Price: lowest first',
  'السعر: الأعلى أولًا': 'Price: highest first',
  'الأكثر مبيعًا': 'Best selling',
  'الأحدث إضافة': 'Newest added',
  'الأقدم': 'Oldest',
  'برونزي': 'Bronze',
  'فضي': 'Silver',
  'ذهبي': 'Gold',
  'كبار العملاء': 'VIP',
  'عند التعطيل لا تُضاف نقاط ولا تُرقّى شرائح الزبائن عند إصدار فاتورة.':
      'When disabled, no points are added and customer tiers are not upgraded when an invoice is issued.',
  'نقطة واحدة لكل هذا المبلغ من قيمة الفاتورة (10 = نقطة لكل 10 ر.س).':
      'One point per this amount of the invoice value (10 = one point per 10 SAR).',
  'عند التعطيل لا يُحذف أي سجل محاسبي تلقائيًا. وعند التفعيل تُحذف الفواتير الأقدم من مدة الاحتفاظ، ولا تُمسّ فواتير الديون والاشتراكات ولا فواتير السنة الجارية.':
      'When disabled, no accounting record is deleted automatically. When enabled, invoices older than the retention period are deleted; debt and subscription invoices and current-year invoices are untouched.',
  'أقل مدة مسموحة 400 يومًا: أي فاتورة من السنة الجارية لا تُحذف مهما كان عمرها، حمايةً للتقارير السنوية والشهرية.':
      'The minimum allowed period is 400 days: any invoice from the current year is not deleted regardless of its age, protecting annual and monthly reports.',
  'كل هذه المدة يُعاد فحص صلاحية النظام أثناء العمل (مع الفحص عند الإقلاع وعند العودة من الخلفية).':
      'Every this period, the system license is rechecked during work (along with checks at startup and when returning from the background).',

  // ═══ الورديات (تفصيل) ═══
  'لا تملك صلاحية': 'You do not have permission',
  'فتح الوردية يحتاج صلاحية «فتح وردية»، راجع مدير النظام.':
      'Opening a shift requires the “Open shift” permission; contact the system administrator.',
  'إغلاق الوردية يحتاج صلاحية «إغلاق وردية وجردها»، راجع مدير النظام.':
      'Closing a shift requires the “Close and reconcile shift” permission; contact the system administrator.',
  'يوجد وردية مفتوحة بالفعل.': 'A shift is already open.',
  'تم فتح الوردية بنجاح.': 'Shift opened successfully.',
  'تم إغلاق الوردية بنجاح.': 'Shift closed successfully.',
  'حدث خطأ أثناء فتح الوردية: {0}':
      'An error occurred while opening the shift: {0}',
  'حدث خطأ أثناء إغلاق الوردية: {0}':
      'An error occurred while closing the shift: {0}',
  'لا توجد وردية مفتوحة لإغلاقها.': 'There is no open shift to close.',
  'الدرج: لم يُجرَد': 'Drawer: not counted',
  'الدرج: مطابق': 'Drawer: matched',
  'الدرج: زيادة {0}': 'Drawer: over by {0}',
  'الدرج: عجز {0}': 'Drawer: short by {0}',
  'ملخص الوردية': 'Shift summary',
  'المقبوضات: {0}': 'Cash received: {0}',
  'الشبكة: {0}': 'Card: {0}',
  'عدد الفواتير: {0}': 'Invoice count: {0}',
  'السحوبات النقدية: {0}': 'Cash withdrawals: {0}',
  'المتوقع في الدرج: {0}': 'Expected in drawer: {0}',
  'فشل في تحميل الورديات السابقة.': 'Failed to load previous shifts.',
  'فشل في طباعة ملخص الوردية: {0}': 'Failed to print the shift summary: {0}',
  'جرد الدرج قبل الإقفال': 'Count the drawer before closing',
  'رصيد الافتتاح + المقبوضات': 'Opening balance + receipts',
  'المتوقع في الدرج': 'Expected in drawer',
  'المبلغ المعدود فعليًا': 'Amount actually counted',
  'مطابق تمامًا': 'Exact match',
  'زيادة {0} ر.س': 'Over by {0} SAR',
  'عجز {0} ر.س': 'Short by {0} SAR',
  'سبب الفرق (مطلوب)': 'Reason for difference (required)',
  'إقفال بلا جرد': 'Close without counting',
  'إقفال مع جرد': 'Close with count',
  'أدخل المبلغ المعدود أو أقفل بلا جرد':
      'Enter the counted amount or close without counting',
  'اذكر سبب الفرق قبل الإقفال':
      'State the reason for the difference before closing',

  // ═══ إدارة الأدوار (رسائل) ═══
  'مرفوض': 'Rejected',
  'دور «مدير النظام» جذر لا يُعدَّل — يملك كل الصلاحيات دائمًا.':
      'The “System Administrator” role is root and cannot be modified — it always has all permissions.',
  'دور «مدير النظام» يملك كل الصلاحيات أصلًا.':
      'The “System Administrator” role already has all permissions.',
  'صلاحية غير معروفة في الكتالوج: {0}':
      'Unknown permission in the catalog: {0}',
  'تعذّر تعديل الصلاحية: {0}': 'Could not modify the permission: {0}',
  'تعذّر تعديل المجموعة: {0}': 'Could not modify the group: {0}',
  'لا حزمة افتراضية معروفة للدور «{0}».':
      'No default bundle is known for the role “{0}”.',
  'أُعيدت حزمة «{0}» إلى الافتراضي.': 'The “{0}” bundle was reset to default.',
  'تعذّرت إعادة التعيين: {0}': 'Could not reset: {0}',
  'اسم الدور يجب أن يبدأ بحرف لاتيني ويحتوي حروفًا وأرقامًا وشرطة سفلية فقط (2–30 محرفًا).':
      'The role name must start with a Latin letter and contain only letters, numbers, and underscores (2–30 characters).',
  'أدخل اسمًا معروضًا للدور.': 'Enter a display name for the role.',
  'الاسم «admin» محجوز لدور الجذر.':
      'The name “admin” is reserved for the root role.',
  'يوجد دور بالاسم «{0}» بالفعل.': 'A role named “{0}” already exists.',
  'أُنشئ الدور «{0}».': 'Role “{0}” was created.',
  'تعذّر إنشاء الدور: {0}': 'Could not create the role: {0}',
  'لا يُعاد تسمية دور الجذر.': 'The root role cannot be renamed.',
  'أدخل اسمًا معروضًا.': 'Enter a display name.',
  'تعذّرت إعادة التسمية: {0}': 'Could not rename: {0}',
  'لا يُحذف دور الجذر.': 'The root role cannot be deleted.',
  '«{0}» دور نظامي لا يُحذف — يمكنك تعديل صلاحياته.':
      '“{0}” is a system role and cannot be deleted — you can edit its permissions.',
  'على «{0}» {1} مستخدم — انقلهم إلى دور آخر قبل الحذف.':
      '“{0}” has {1} users — move them to another role before deleting.',
  'لا يمكنك حذف الدور الذي تعمل به الآن.':
      'You cannot delete the role you are currently using.',
  'حُذف الدور «{0}».': 'Role “{0}” was deleted.',
  'تعذّر حذف الدور: {0}': 'Could not delete the role: {0}',
  'إدارة الأدوار صلاحية مقصورة على مدير النظام (roles.manage).':
      'Role management is restricted to the system administrator (roles.manage).',

  // ═══ الاشتراكات (خدمة) ═══
  'الاشتراك غير موجود': 'Subscription not found',
  'الاشتراك غير موجود في قاعدة البيانات':
      'Subscription not found in the database',
  'تعذّر الوصول إلى قاعدة البيانات': 'Could not access the database',
  'المبلغ يجب أن يكون أكبر من صفر': 'The amount must be greater than zero',
  'سعر الاشتراك صفر — لا يمكن احتساب أيام تغطية. حدِّث سعر الاشتراك أولًا.':
      'The subscription price is zero — coverage days cannot be calculated. Update the subscription price first.',
  'المبلغ أقل من أن يغطي يومًا واحدًا (أقل دفعة مقبولة: {0} ر.س).':
      'The amount is too small to cover a single day (minimum accepted payment: {0} SAR).',
  'تغيّرت تغطية الاشتراك أثناء تسجيل الدفعة (دفعة أخرى سُجّلت simultaneous). أعد المحاولة.':
      'The subscription coverage changed while recording the payment (another payment was recorded simultaneously). Try again.',
  'إلغاء اشتراك وتسويته': 'Cancel a subscription and settle it',
  'لا توجد دفعة مسجّلة لهذا الاشتراك — لا تغطية بعد. سجّل دفعة أولًا من شاشة الاشتراكات.':
      'No payment is recorded for this subscription — no coverage yet. Record a payment first from the subscriptions screen.',
  'انتهت تغطية الاشتراك ({0}) — جدّد الاشتراك أو اختر طريقة دفع أخرى.':
      'Subscription coverage ended ({0}) — renew the subscription or choose another payment method.',
  'تجاوز سقف الاشتراك بـ{0} (القطع: {1} — القيمة: {2}). صلاحيتك تسمح بالتجاوز — سيُسجَّل في التدقيق.':
      'Subscription cap exceeded by {0} (pieces: {1} — value: {2}). Your permission allows the override — it will be logged in the audit.',
  'هذه الفاتورة تتجاوز سقف الاشتراك بـ{0} (القطع: {1} — القيمة: {2}). الزبون يحتاج تجديدًا أو ترقية، ولا يملك صلاحية التجاوز إلا مدير.':
      'This invoice exceeds the subscription cap by {0} (pieces: {1} — value: {2}). The customer needs a renewal or upgrade; only a manager can override.',

  // ═══ تذكير الذمم (رسائل واتساب) ═══
  '🧺 *تنبيه ودّي من {0}*': '🧺 *A friendly notice from {0}*',
  '🧺 *تذكير بذمة قائمة — {0}*': '🧺 *Outstanding balance reminder — {0}*',
  '⚠️ *مطالبة بذمة متأخرة — {0}*': '⚠️ *Overdue balance claim — {0}*',
  '📋 *مطالبة رسمية بذمة متأخرة — {0}*':
      '📋 *Formal overdue balance claim — {0}*',
  'عزيزنا {0}،': 'Dear {0},',
  'نأمل أن تكون بخير. لديك مبلغ متبقٍ لم يُسدَّد بعد، ونودّ تذكيرك به ودّيًا:':
      'We hope you are well. You have a remaining unpaid amount, and we would like to kindly remind you of it:',
  'نود تذكيرك بأن لديك ذمة قائمة منذ {0} يومًا، ونأمل تسويتها في أقرب وقت:':
      'We would like to remind you that you have an outstanding balance for {0} days, and we hope you settle it as soon as possible:',
  'لديك ذمة متأخرة عن السداد منذ {0} يومًا. نرجو المبادرة بتسويتها وتجنّب أي إجراء لاحق:':
      'You have an overdue balance for {0} days. Please settle it promptly and avoid any further action:',
  'ذمتك القائمة لدينا تجاوزت {0} يومًا دون سداد، وهي مدة تتجاوز المدى المعتاد بشكل واضح. نطلب تسويتها فورًا أو التواصل معنا لترتيب السداد:':
      'Your outstanding balance has exceeded {0} days without payment, clearly beyond the usual period. We request immediate settlement or contact with us to arrange payment:',
  '💰 *إجمالي الذمة: {0} ر.س*': '💰 *Total balance: {0} SAR*',
  '📄 عدد الفواتير: {0}': '📄 Number of invoices: {0}',
  '*تفصيل المبالغ:*': '*Amount breakdown:*',
  'متأخرة {0} يومًا': 'overdue {0} days',
  'منذ {0} يوم': '{0} days ago',
  '• فاتورة #{0} — {1} ر.س ({2})': '• Invoice #{0} — {1} SAR ({2})',
  '... و{0} فاتورة أخرى': '... and {0} more invoices',
  '📞 للتواصل: {0}': '📞 Contact: {0}',
  'شكرًا لتعاونك — {0} 💙': 'Thank you for your cooperation — {0} 💙',
  'لا ذمة على هذا الزبون': 'This customer has no outstanding balance',
  'مطالبة {0}': 'Claim for {0}',
  'الرقم: {0}': 'Phone: {0}',
  'راجع الرسالة قبل الإرسال — يمكنك تعديل أي كلمة.':
      'Review the message before sending — you can edit any wording.',
  'نُسخت الرسالة — يمكنك لصقها في أي تطبيق':
      'The message was copied — you can paste it into any app',
  'نسخ': 'Copy',
  'إرسال عبر واتساب': 'Send via WhatsApp',
  'لا يوجد رقم لهذا الزبون': 'No phone number for this customer',
  'الزبون «{0}» غير مسجّل برقم جوال. أدخل الرقم ليُحفظ في سجله وتُرسل المطالبة.':
      'The customer “{0}” has no mobile number registered. Enter the number to save it in their record and send the claim.',
  'حفظ وإرسال': 'Save and send',
  'لم يُدخَل رقم — أُلغي الإرسال': 'No number was entered — sending cancelled',
  'تنبيه ودّي': 'Friendly notice',
  'تذكير': 'Reminder',
  'مطالبة': 'Claim',
  'مطالبة رسمية': 'Formal claim',

  // ═══ مشاركة الفاتورة (رسائل وواجهة) ═══
  '🧺 *فاتورة {0} #{1}*': '🧺 *Invoice from {0} #{1}*',
  '👤 الزبون: {0}': '👤 Customer: {0}',
  '... و{0} أصناف أخرى': '... and {0} more items',
  ' على حساب الاشتراك الشهري': ' On the monthly subscription account',
  '💰 الإجمالي: {0} ر.س': '💰 Total: {0} SAR',
  '💳 الدفع: {0} (مدفوع: {1})': '💳 Payment: {0} (paid: {1})',
  '⚠️ متبقي: {0} ر.س': '⚠️ Remaining: {0} SAR',
  '🔑 رمز استلام الغسيل: {0}': '🔑 Laundry pickup code: {0}',
  'شكراً لثقتكم — {0} 💙': 'Thank you for your trust — {0} 💙',
  'حُفظ رقم الزبون في سجله — يمكن إرسال الفاتورة الآن':
      'The customer phone was saved to their record — the invoice can be sent now',
  'تعذر حفظ رقم الزبون: {0}': 'Could not save the customer phone: {0}',
  'تعذر تجهيز ملف الفاتورة': 'Could not prepare the invoice file',
  'فاتورة': 'Invoice',
  'فاتورة {0} #{1}': 'Invoice from {0} #{1}',
  'حُفظت الفاتورة في: {0}': 'The invoice was saved to: {0}',
  'فشل مشاركة الفاتورة: {0}': 'Failed to share the invoice: {0}',
  'تعذر فتح واتساب': 'Could not open WhatsApp',
  'إرسال الفاتورة #{0}': 'Send invoice #{0}',
  'رقم الزبون: {0}': 'Customer phone: {0}',
  'إرسال ملف الفاتورة (PDF)': 'Send invoice file (PDF)',
  'تظهر قائمة المشاركة — اختر واتساب ثم الزبون':
      'The share menu appears — choose WhatsApp then the customer',
  'فتح محادثة الزبون على واتساب': 'Open the customer chat on WhatsApp',
  'رسالة ملخّص الفاتورة إلى الرقم {0} مباشرة':
      'An invoice summary message directly to {0}',
  'إرسال ملخّص نصي لأي جهة': 'Send a text summary to anyone',
  'لمشاركة الملخّص دون تحديد رقم':
      'Share the summary without specifying a number',
  'لا يوجد رقم واتساب لهذا الزبون': 'No WhatsApp number for this customer',
  'أدخل رقم الزبون ليُحفظ في سجله وتُرسل الفاتورة إليه.':
      'Enter the customer phone to save it in their record and send them the invoice.',
  'الزبون «{0}» غير مسجّل برقم — أدخل الرقم ليُحفظ في سجله.':
      'The customer “{0}” has no number registered — enter it to save it in their record.',
  'إرسال الملف فقط': 'Send the file only',
  'أدخل رقم الزبون أولاً': 'Enter the customer phone first',
  'حفظ الرقم وإرسال الفاتورة': 'Save the number and send the invoice',

  // ═══ النسخ الاحتياطي (خدمة) ═══
  '، ': ', ',
  'ملف النسخة الاحتياطية غير موجود': 'The backup file does not exist',
  'الملف فارغ أو أصغر من أن يكون قاعدة بيانات ({0})':
      'The file is empty or too small to be a database ({0})',
  'هذا ليس ملف قاعدة بيانات SQLite — تأكد أنك اخترت ملف نسخة احتياطية (‎.db‎)':
      'This is not a SQLite database file — make sure you selected a backup file (‎.db‎)',
  'تعذّر قراءة الملف: {0}': 'Could not read the file: {0}',
  'الملف تالف — فحص السلامة أفاد: {0}':
      'The file is corrupted — integrity check reported: {0}',
  'بلا نتيجة': 'no result',
  'الملف لا يحوي جداول هذا النظام (المفقود: {0}) — قد يكون قاعدة بيانات نظام آخر':
      'The file does not contain this system’s tables (missing: {0}) — it may be a database from another system',
  'هذه النسخة من إصدار أحدث من النظام (بنية {0} مقابل {1}) — حدّث التطبيق أولًا ثم أعد المحاولة':
      'This backup is from a newer version of the system (schema {0} vs {1}) — update the app first and try again',
  'تعذّر فتح الملف كقاعدة بيانات: {0}':
      'Could not open the file as a database: {0}',
  'لا تملك صلاحية النسخ الاحتياطي، راجع مدير النظام.':
      'You do not have permission to create backups; contact the system administrator.',
  'قاعدة البيانات غير موجودة': 'The database does not exist',
  'تعذّر إنشاء نسخة سليمة: {0}': 'Could not create a valid backup: {0}',
  'فشل في إنشاء النسخة الاحتياطية: {0}': 'Failed to create the backup: {0}',
  'حجم النسخة ({0}) أكبر من أن تُحفظ عبر منتقي الملفات على الجوال؛ احفظها داخل التطبيق ثم انسخها.':
      'The backup size ({0}) is too large to save via the mobile file picker; save it inside the app then copy it.',
  'حفظ النسخة الاحتياطية': 'Save backup',
  'لا تملك صلاحية استعادة النسخ الاحتياطية، راجع مدير النظام.':
      'You do not have permission to restore backups; contact the system administrator.',
  'هذا ملف قاعدة البيانات الحيّة نفسه، وليس نسخة احتياطية':
      'This is the live database file itself, not a backup',
  'ملف النسخة الاحتياطية غير صالح': 'The backup file is invalid',
  'تعذّر أخذ نسخة أمان سليمة من بياناتك الحالية، فأُوقفت الاستعادة لحمايتها ({0})':
      'Could not take a valid safety backup of your current data, so the restore was stopped to protect it ({0})',
  'فشل الرجوع التلقائي: {0}': 'Automatic rollback failed: {0}',
  'فشل فحص البيانات بعد الاستعادة ({0})':
      'Data check failed after restore ({0})',
  ' — وأُعيدت بياناتك السابقة كما كانت':
      ' — your previous data was restored as it was',
  ' — تعذّر الرجوع؛ استعد نسخة الأمان يدويًا':
      ' — rollback failed; restore the safety backup manually',
  'فشل في استعادة النسخة الاحتياطية: {0}': 'Failed to restore the backup: {0}',
  'لا يمكن حذف أحدث نسخة أمان — هي مسار الرجوع بعد أي استعادة خاطئة':
      'The latest safety backup cannot be deleted — it is the rollback path after any mistaken restore',
  'تعذّر حذف الملف: {0}': 'Could not delete the file: {0}',
  'اختر ملف النسخة الاحتياطية': 'Choose the backup file',
  'تعذّر حذف {0}: {1}': 'Could not delete {0}: {1}',
  'VACUUM INTO غير مدعوم على هذا الجهاز، نسخ مباشر: {0}':
      'VACUUM INTO is not supported on this device; using a direct copy: {0}',

  // ═══ خطوط الطباعة ═══
  'حراري وورق': 'Thermal and paper',
  'حراري': 'Thermal',
  'ورق': 'Paper',
  'زخرفي': 'Decorative',
  'مغاسل النظارة — فاتورة 1024': 'Al-Nadhara Laundry — Invoice 1024',
  'قيميص (غسيل) 3 × 10.00 = 30.00 ر.س': 'Thobe (wash) 3 × 10.00 = 30.00 SAR',
  'خفيف الحبر جدًا · أقل التصاقًا على الحراري · هو خطّ النظام الحالي':
      'Very light ink · least sticking on thermal · the current system font',
  'الأخفّ حبرًا · صُمّم للقراءة الصغيرة · الأنقى على 80 مم':
      'Lightest ink · designed for small reading · cleanest at 80 mm',
  'خفيف وواسع · ارتفاع سطر مريح · ممتاز للحراري':
      'Light and wide · comfortable line height · excellent for thermal',
  'هندسي تقني · أرقام لاتينية واضحة لا تلتبس':
      'Technical geometric · clear Latin digits with no ambiguity',
  'خطّ جوجل العالمي · أفضل توازن بين الخفّة والوضوح':
      'Google universal font · the best balance of lightness and clarity',
  'ناسخ عالمي · أوضح للعين · حبره أثقل قليلًا من سانس':
      'Universal Naskh · clearer to the eye · slightly heavier than Sans',
  'الأضيق عرضًا · يوفّر مساحة على 58 مم ويقلّل الأسطر':
      'Narrowest · saves space at 58 mm and reduces lines',
  'نظيف ومقروء · متوسّط الحبر': 'Clean and readable · medium ink',
  'متوسّط الثقل · جميل على الورق · يُلتحم على الحراري الضيق':
      'Medium weight · beautiful on paper · sticks on narrow thermal',
  'كوفي هندسي عريض · للعناوين والورق لا للحراري':
      'Bold geometric Kufi · for headings and paper, not thermal',
  'ناسخ كلاسيكي رسمي · ثقيل الحبر · للفواتير الورقية الفخمة':
      'Classic formal Naskh · heavy ink · for premium paper invoices',
  'تغيير الخطّ': 'Change font',
  'يحكم كل المستندات المطبوعة: الفاتورة · كشف الحساب · ملخّص الوردية.':
      'Applies to all printed documents: invoice · statement · shift summary.',
  'للطابعة الحرارية اختر خطًّا خفيف الحبر: «IBM Plex خفيف» أو «المراعي خفيف» أو «المهنّد». الخطوط الثقيلة تُلتحم على 8–10 نقاط.':
      'For a thermal printer, choose a light-ink font: “IBM Plex Light”, “Almarai Light”, or “Al-Mohanad”. Heavy fonts stick at 8–10 pt.',
  'طبّق': 'Apply',

  // ═══ ترتيب أصناف اللبس ═══
  'ترتيب الإدخال في القاعدة — الأسرع': 'Database insertion order — fastest',
  'أبجدي صاعد': 'Ascending alphabetical',
  'أبجدي نازل': 'Descending alphabetical',
  'الأرخص أولًا — سعر الغسيل والكوي العادي':
      'Cheapest first — normal wash and iron price',
  'الأغلى أولًا — سعر الغسيل والكوي العادي':
      'Most expensive first — normal wash and iron price',
  'مجموع القطع المباعة من كل صنف': 'Total pieces sold per item',
  'آخر ما أضفته أولًا': 'Last added first',
  'أول ما أضفته أولًا': 'First added first',

  // ═══ إدارة المستخدمين ═══
  'اسم المستخدم "{0}" مستخدم بالفعل': 'The username “{0}” is already in use',
  'تم إضافة المستخدم "{0}"': 'User “{0}” was added',
  'فشل في إضافة المستخدم: {0}': 'Failed to add the user: {0}',
  'تم تعديل المستخدم "{0}"': 'User “{0}” was updated',
  'فشل في تعديل المستخدم: {0}': 'Failed to update the user: {0}',
  'لا يمكنك حذف حسابك الخاص': 'You cannot delete your own account',
  'تم حذف المستخدم "{0}"': 'User “{0}” was deleted',
  'فشل في حذف المستخدم: {0}': 'Failed to delete the user: {0}',
  'تعديل صلاحيات المستخدم يحتاج صلاحية إدارة المستخدمين.':
      'Editing user permissions requires the manage-users permission.',
  'صلاحية غير معروفة: {0}': 'Unknown permission: {0}',
  'أُزيلت {0} تجاوزات فردية.': 'Cleared {0} individual overrides.',
  'تعذّر المسح: {0}': 'Could not clear: {0}',

  // ═══ المصروفات ═══
  'التصنيف مطلوب': 'Category is required',
  'تسجيل المصروفات': 'Record expenses',
  'تعديل المصروفات': 'Edit expenses',
  'حذف المصروفات': 'Delete expenses',
  'مواد ومستلزمات': 'Materials and supplies',
  'رواتب وأجور': 'Salaries and wages',
  'إيجار': 'Rent',
  'كهرباء وماء': 'Electricity and water',
  'صيانة وإصلاح': 'Maintenance and repair',
  'نقل وتوصيل': 'Transport and delivery',
  'دعاية وإعلان': 'Marketing and advertising',
  'رسوم حكومية': 'Government fees',
  'أخرى': 'Other',

  // ═══ الطباعة ═══
  'مستند': 'Document',
  'ملف الطباعة فارغ — لم يُرسَل شيء إلى الطابعة.':
      'The print file is empty — nothing was sent to the printer.',
  'PrinterService: تلقائي=مُفعَّل · الطابعة="{0}"':
      'PrinterService: auto=enabled · printer="{0}"',
  'لم تُختَر طابعة بعد — يُفتح حوار النظام.':
      'No printer has been selected yet — the system dialog will open.',
  'PrinterService: طابعات الجهاز={0}': 'PrinterService: device printers={0}',
  'الطابعة المختارة «{0}» غير موجودة على هذا الجهاز — يُفتح حوار النظام.':
      'The selected printer “{0}” is not present on this device — the system dialog will open.',
  'الطابعة «{0}» غير متصلة أو متوقفة أو موقوفة — يُفتح حوار النظام.':
      'The printer “{0}” is disconnected, paused, or stopped — the system dialog will open.',
  'PrinterService: الهدف="{0}" · التعريف="{1}" · متاحة={2}':
      'PrinterService: target="{0}" · driver="{1}" · available={2}',
  'PrinterService: فشلت المحاولتان — {0}':
      'PrinterService: both attempts failed — {0}',
  'PrinterService: الطباعة التلقائية معطّلة — حوار النظام.':
      'PrinterService: automatic printing is disabled — system dialog.',
  'PrinterService: المحاولة 1 (إعدادات التعريف) فشلت — {0}':
      'PrinterService: attempt 1 (driver settings) failed — {0}',
  'PrinterService: المحاولة 2 (مقاس المستند) فشلت — {0}':
      'PrinterService: attempt 2 (document size) failed — {0}',
  '{0} (تعريف الطابعة: «{1}» — تحقّق أنه يدعم طباعة الرسومات.)':
      '{0} (printer driver: “{1}” — verify it supports graphics printing.)',
  'تعذّرت الطباعة المباشرة.': 'Direct printing failed.',
  'لم تُكمل الطابعة المهمة.': 'The printer did not complete the job.',
  'لم تستجب الطابعة خلال ٨ ثوانٍ.':
      'The printer did not respond within 8 seconds.',
  'تعذّر الإرسال المباشر ({0}).': 'Direct sending failed ({0}).',
  'PrintFontService: تعذّر تحميل «{0}» ({1}): {2}':
      'PrintFontService: could not load “{0}” ({1}): {2}',

  // ═══ إصدار الفاتورة ═══
  'لا تغطية سارية': 'No active coverage',
  'استهلكت {0}% من سقف هذا الاشتراك. باقٍ {1} قطعة و{2} ر.س.':
      'You have used {0}% of this subscription’s cap. {1} pieces and {2} SAR remain.',
  'زبون مطلوب': 'Customer required',
  'إعدادات النظام تُلزم تحديد زبون قبل إصدار الفاتورة.':
      'System settings require selecting a customer before issuing an invoice.',
  'أقل من الحد الأدنى': 'Below the minimum',
  'الحد الأدنى للفاتورة {0} ر.س.': 'The minimum invoice amount is {0} SAR.',
  'رقم فاتورة مكرر': 'Duplicate invoice number',
  'الرقم #{0} مستخدم بالفعل — لم يتم إصدار أي فاتورة. أعد المحاولة للحصول على رقم جديد.':
      'Number #{0} is already in use — no invoice was issued. Try again to get a new number.',
  'فشل حفظ الفاتورة في قاعدة البيانات':
      'Failed to save the invoice in the database',
  'تم حفظ الفاتورة رقم #{0} وإصدارها': 'Invoice #{0} was saved and issued',
  'تعذر حفظ الفاتورة: {0}': 'Could not save the invoice: {0}',
  'حُفظت نسخة PDF': 'A PDF copy was saved',
  'تم تجهيز الفاتورة': 'The invoice is ready',

  // ═══ قوالب الطباعة (محرّر + مستندات) ═══
  '--- شكراً لكم ---': '--- Thank you ---',
  '--- هذا الكشف صادر آليًا من النظام ---':
      '--- This statement was generated automatically by the system ---',
  '«الأصناف التي أخذها» · «الفواتير» · «الدفعّات» …':
      '“Items taken” · “Invoices” · “Payments” …',
  'إجمالي المشتريات': 'Total purchases',
  'اتركه فارغًا لاستخدام الاسم المسجَّل.':
      'Leave it empty to use the registered name.',
  'اتركه فارغًا لاستخدام الاسم من «معلومات النشاط».':
      'Leave it empty to use the name from “Business info”.',
  'اتركه فارغًا لاستخدام العنوان المسجَّل.':
      'Leave it empty to use the registered address.',
  'اسم العميل': 'Customer name',
  'اسم القطعة ونوعها في قائمة الأصناف.':
      'The item name and type in the items list.',
  'اشتراك': 'Subscription',
  'الأساس الخاضع للضريبة': 'Taxable base',
  'الإجمالي قبل الخصم': 'Total before discount',
  'الإجماليات': 'Totals',
  'البادئة قبل «من … إلى …».': 'The prefix before “from … to …”.',
  'البادئة قبل إجمالي المدفوع بالشبكة.':
      'The prefix before the total paid by card.',
  'البادئة قبل إجمالي المدفوع نقدًا.':
      'The prefix before the total paid in cash.',
  'البادئة قبل اسم الزبون.': 'The prefix before the customer name.',
  'البادئة قبل اسم من أصدر الفاتورة.': 'The prefix before the issuer name.',
  'البادئة قبل التاريخ.': 'The prefix before the date.',
  'البادئة قبل الرقم.': 'The prefix before the number.',
  'البادئة قبل الرقم. الرقم نفسه من «معلومات النشاط».':
      'The prefix before the number. The number itself comes from “Business info”.',
  'البادئة قبل المبلغ المتبقي على الزبون.':
      'The prefix before the amount remaining on the customer.',
  'البادئة قبل المبلغ المدفوع.': 'The prefix before the paid amount.',
  'البادئة قبل تاريخ ووقت إغلاق الوردية.':
      'The prefix before the shift close date and time.',
  'البادئة قبل تاريخ ووقت الطباعة.':
      'The prefix before the print date and time.',
  'البادئة قبل تاريخ ووقت فتح الوردية.':
      'The prefix before the shift open date and time.',
  'البادئة قبل رقم الهاتف.': 'The prefix before the phone number.',
  'البادئة قبل رقم الوردية.': 'The prefix before the shift number.',
  'البادئة قبل رقم هاتف الزبون.':
      'The prefix before the customer phone number.',
  'البادئة قبل رمز استلام القطع.': 'The prefix before the pickup code.',
  'البادئة قبل صافي الرصيد.': 'The prefix before the net balance.',
  'البادئة قبل عدد القطع (يظهر إن كان أكبر من صفر).':
      'The prefix before the piece count (shown when greater than zero).',
  'البادئة قبل عدد فواتير الوردية.':
      'The prefix before the shift invoice count.',
  'البادئة قبل عدد قطع الاشتراك المستهلكة.':
      'The prefix before the consumed subscription pieces.',
  'البادئة قبل ما على الزبون.': 'The prefix before what the customer owes.',
  'البادئة قبل ما للزبون.': 'The prefix before what is due to the customer.',
  'البادئة قبل مبلغ الخصم.': 'The prefix before the discount amount.',
  'البادئة قبل مبلغ الضريبة (تُضاف النسبة آليًا).':
      'The prefix before the tax amount (the rate is added automatically).',
  'البادئة قبل مجموع المسدَّد.': 'The prefix before the total paid.',
  'البادئة قبل مجموع المشتريات.': 'The prefix before total purchases.',
  'التأريخ': 'Date',
  'التاريخ والوقت': 'Date and time',
  'التذييل': 'Footer',
  'الترويسة': 'Header',
  'الترويسة وقد تدفع ملخّص الكشف إلى صفحة ثانية.':
      'The header may push the statement summary to a second page.',
  'الخط أسفل الترويسة.': 'The line below the header.',
  'الخط الفاصل': 'Divider line',
  'الخط النصّي الفاصل بين الترويسة والأصناف.':
      'The text divider between the header and the items.',
  'الخط بين الترويسة والبيانات.':
      'The line between the header and the details.',
  'الدفع': 'Payment',
  'الدفعات المسجَّلة': 'Recorded payments',
  'الذمة المتبقية': 'Outstanding balance',
  'الذمة المتبقية (عليه)': 'Outstanding balance (owed)',
  'الرصيد الدائن': 'Credit balance',
  'الرصيد الدائن (له)': 'Credit balance (in his favor)',
  'الرقم الضريبي': 'Tax number',
  'السعر الإجمالي وسطر «السعر × العدد».':
      'The total price and the “price × quantity” line.',
  'الشريط الذي يظهر أسفل فاتورة الاشتراك بدل الإجماليات.':
      'The bar shown below a subscription invoice instead of totals.',
  'العنوان المقابل للمبلغ عند عدم وجود خصم.':
      'The label opposite the amount when there is no discount.',
  'العنوان المقابل للمبلغ عند وجود خصم.':
      'The label opposite the amount when there is a discount.',
  'العنوان الوطني': 'National address',
  'الكلمة التي تحلّ محلّ السعر في فاتورة الاشتراك.':
      'The word used instead of the price on a subscription invoice.',
  'الكلمة قبل قيمة القطع المستهلكة بين قوسين.':
      'The word before the consumed pieces value in parentheses.',
  'الكلمة قبل ملاحظة القطعة (مثل: ملاحظة).':
      'The word before the item note (e.g. Note).',
  'المبلغ الكبير أسفل الفاتورة.':
      'The large amount at the bottom of the invoice.',
  'المبلغ المستحق': 'Amount due',
  'المجموع': 'Total',
  'المستحق بعد الخصم': 'Due after discount',
  'المسدَّد': 'Paid',
  'الملخّص': 'Summary',
  'الملخّص (تدفّقات الفترة + الرصيد الحالي)':
      'Summary (period activity + current balance)',
  'بادئة ملاحظة البند': 'Item note prefix',
  'بطاقة الإجماليات أسفل الكشف (المشتريات · الذمة · الصافي).':
      'The totals card at the bottom of the statement (purchases · debt · net).',
  'بقيمة': 'worth',
  'تاريخ الطباعة': 'Print date',
  'تفاصيل المستند': 'Document details',
  'تنبيه الاشتراك': 'Subscription notice',
  'جدول استهلاك الاشتراك': 'Subscription usage table',
  'جدول الأصناف': 'Items table',
  'جدول الدفعات': 'Payments table',
  'جدول الفواتير': 'Invoices table',
  'رقم الإيصال': 'Receipt number',
  'رقم الوردية': 'Shift number',
  'رمز QR (زاتكا)': 'QR code (ZATCA)',
  'رمز الاستلام': 'Pickup code',
  'رمز العملة': 'Currency symbol',
  'سجل استهلاك الاشتراك (القطع المغسولة)':
      'Subscription usage log (washed pieces)',
  'سطر الخصم': 'Discount line',
  'سطر الصنف': 'Item line',
  'سطر الضريبة': 'Tax line',
  'سطر المبلغ قبل الضريبة.': 'The amount-before-tax line.',
  'سطر الهاتف': 'Phone line',
  'سطر يظهر فقط عند وجود خصم.': 'A line shown only when there is a discount.',
  'سعر وعدد الصنف': 'Item price and quantity',
  'شعار النشاط': 'Business logo',
  'صافي الموقف': 'Net position',
  'صدر بواسطة': 'Issued by',
  'صور البقع المرفقة ببنود الفاتورة.':
      'Stain photos attached to invoice lines.',
  'صور القطع': 'Item photos',
  'صورة الشعار أعلى الكشف. مُعطَّل افتراضيًا لأن إضافته تُطيل الترويسة وقد تدفع ملخّص الكشف إلى صفحة ثانية.':
      'The logo image at the top of the statement. Disabled by default because adding it lengthens the header and may push the statement summary to a second page.',
  'صورة الشعار أعلى المستند.': 'The logo image at the top of the document.',
  'ضريبة القيمة المضافة': 'VAT',
  'طُبع في': 'Printed on',
  'عادي': 'Normal',
  'عدد القطع': 'Piece count',
  'عريض': 'Bold',
  'عريض جدًا': 'Extra bold',
  'عناوين الأقسام': 'Section headings',
  'عنوان القسم + حجم خطّ خلاياه.':
      'The section title + the font size of its cells.',
  'عنوان المستند': 'Document title',
  'عنوان الملخّص': 'Summary title',
  'عنوان الملخّص (مقيَّد بفترة)': 'Summary title (period-bound)',
  'عنوان النشاط': 'Business title',
  'فاتورة ضريبية مبسطة': 'Simplified tax invoice',
  'فترة الكشف': 'Statement period',
  'قطع الاشتراكات': 'Subscription pieces',
  'قطع الاشتراكات المستهلكة': 'Consumed subscription pieces',
  'قيمة قطع الاشتراك': 'Subscription pieces value',
  'كشف حساب زبون': 'Customer statement',
  'مثل: فاتورة ضريبية مبسطة.': 'e.g. Simplified tax invoice.',
  'مثل: كشف حساب زبون.': 'e.g. Customer statement.',
  'مثل: ملخص الوردية.': 'e.g. Shift summary.',
  'مجموع الشبكة': 'Card total',
  'مجموع الكاش': 'Cash total',
  'مغطّى بالاشتراك الشهري – لا يُطلب مبلغ عند التسليم':
      'Covered by the monthly subscription — no amount is required at pickup',
  'ملخّص الإجماليات': 'Totals summary',
  'نسعد بتواصلكم عبر الأرقام:': 'We are happy to hear from you on:',
  'نصّ حرّ أسفل الفاتورة.': 'Free text at the bottom of the invoice.',
  'نصّ حرّ أسفل الكشف.': 'Free text at the bottom of the statement.',
  'نصّ حرّ أسفل الملخّص.': 'Free text at the bottom of the summary.',
  'نصّ يظهر قبل رقم الهاتف.': 'Text shown before the phone number.',
  'هاتف': 'Phone',
  'هاتف الزبون': 'Customer phone',
  'هاتف العميل': 'Customer phone',
  'وسم الاشتراك': 'Subscription badge',
  'وقت الانتهاء': 'End time',
  'وقت البدء': 'Start time',
  'يظهر بعد المبلغ المستحق.': 'Shown after the amount due.',
  'يظهر بعد كل مبلغ في الكشف.': 'Shown after every amount in the statement.',
  'يظهر بعد مبالغ الكاش والشبكة.': 'Shown after the cash and card amounts.',
  'يظهر فقط إن كان مسجَّلًا في معلومات النشاط.':
      'Shown only if it is registered in the business info.',
  'يظهر فوق إجماليات الكشف.': 'Shown above the statement totals.',
  'يُستخدم عندما يكون الكشف بين تاريخين.':
      'Used when the statement covers a date range.',
  'يُطبع فقط عند وجود رقم ضريبي.': 'Printed only when a tax number exists.',
  'رقم': 'No.',
  'العدد': 'Qty',
  'الطريقة': 'Method',
  'القيمة (ريال)': 'Value (SAR)',
  'الاشتراك': 'Subscription',
  '(له)': '(credit)',
  '(عليه)': '(debit)',

  // ═══════════════════════════════════════════════════════════════════════
  // الدفعة المكمّلة — الرسائل والواجهات المتبقّية
  // ═══════════════════════════════════════════════════════════════════════
  // المفاتيح هنا مكتوبة في **سطر واحد**؛ محرّك الترجمة يطوي المسافات عند
  // البحث، فنصّ مكتوب على عدّة أسطر في الكود يجد ترجمته.

  // ── رسائل العمليات (المتحكّمات) ──
  'تعذّر حفظ ترتيب الأصناف': 'Could not save the item order',
  'اكتب اسم اللبس أولاً': 'Enter the garment name first',
  'تكلفة القطعة لا يمكن أن تكون سالبة': 'Item cost cannot be negative',
  'تمت إضافة الصنف بنجاح': 'Item added successfully',
  'لم يتم تنفيذ العملية بنجاح!': 'The operation did not complete successfully!',
  'تعذر إضافة الصنف: {0}': 'Could not add the item: {0}',
  'تعذر تعديل الصنف: {0}': 'Could not update the item: {0}',
  'تم حذف الصنف بنجاح': 'Item deleted successfully',
  'تعذر حذف الصنف': 'Could not delete the item',
  'تعذر حذف الصنف: {0}': 'Could not delete the item: {0}',
  'تحديث الأصناف والخدمات': 'Refresh items and services',
  'جارٍ التحديث...': 'Refreshing...',
  'جارٍ الحذف...': 'Deleting...',
  'تم تنفيذ العملية بنجاح!': 'Operation completed successfully!',
  'تمت العملية بنجاح': 'Operation completed successfully',
  'اسم الزبون مطلوب': 'Customer name is required',
  'لا يمكن الحذف': 'Cannot delete',
  'تم حذف الزبون — سجل فواتيره محفوظ للتقارير':
      'Customer deleted - invoice history kept for reports',
  'تنبيه: رصيد غير مستخدم': 'Warning: unused credit',
  'حذف رغم ذلك': 'Delete anyway',
  'مفتوحة الآن': 'Open now',
  'أُقفلت {0}': 'Closed {0}',
  'وردية #{0} — {1} · {2}': 'Shift #{0} - {1} · {2}',
  'تم تسجيل المصروف': 'Expense recorded',
  'تعذّر تعديل المصروف': 'Could not update the expense',
  'تم تعديل المصروف': 'Expense updated',
  'تعذّر حذف المصروف': 'Could not delete the expense',
  'تم حذف المصروف': 'Expense deleted',
  'فشل في تحميل الفواتير': 'Failed to load invoices',
  'جاري تحميل المزيد من الفواتير...': 'Loading more invoices...',
  'تم تحميل كل الفواتير': 'All invoices loaded',
  'فشل في تحميل المزيد من الفواتير': 'Failed to load more invoices',
  '{0} يوم': '{0} days',
  '{0} ساعة': '{0} hours',
  '{0} دقيقة': '{0} minutes',
  'لحظات': 'moments',
  'المستخدم غير موجود': 'User not found',
  'كلمة المرور الحالية غير صحيحة': 'Current password is incorrect',
  'تم تغيير كلمة المرور بنجاح': 'Password changed successfully',
  'فشل في تغيير كلمة المرور: {0}': 'Failed to change the password: {0}',
  'المبلغ الشهري يجب أن يكون أكبر من صفر':
      'The monthly amount must be greater than zero',
  'معرّف الاشتراك غير صالح': 'Invalid subscription id',
  'اشتراك بلا دفعة — لا تغطية': 'Subscription without payment - no coverage',
  'انتهت التغطية منذ {0} يوم': 'Coverage ended {0} days ago',
  'استُهلك سقف الاستخدام': 'Usage limit reached',
  'بلغ {0}% من السقف': 'Reached {0}% of the limit',
  'تم تسجيل الدفعة — الذمة المتبقية {0} ر.س':
      'Payment recorded - remaining balance {0} SAR',
  'فشل في تسجيل الدفعة: {0}': 'Failed to record the payment: {0}',
  'أُلغي حدّ الدين الآجل': 'Credit limit removed',
  'حُدّد حدّ الدين الآجل بـ {0} ر.س': 'Credit limit set to {0} SAR',
  'لا يوجد رصيد': 'No balance available',
  'الزبون لا يملك سلفة قابلة للاستخدام': 'The customer has no usable credit',
  'استُخدم {0} ر.س من رصيد الزبون في سداد ذممه':
      'Used {0} SAR of the customer credit to settle debts',
  'تعذّر حفظ الكشف': 'Could not save the statement',
  'حُفظ الكشف في: {0}': 'Statement saved to: {0}',
  'فشل تصدير الكشف: {0}': 'Failed to export the statement: {0}',
  'كشف حساب: {0}': 'Account statement: {0}',
  'الفترة: {0}': 'Period: {0}',
  'كل الفترة (بلا تقييد)': 'All time (no limit)',
  'من {0} إلى {1}': 'From {0} to {1}',
  'من {0} حتى الآن': 'From {0} until now',
  'أقدم ذمة: {0}': 'Oldest debt: {0}',
  'إجمالي المشتريات: {0} ريال': 'Total purchases: {0} SAR',
  'المسدَّد: {0} ريال': 'Paid: {0} SAR',
  'الذمة المتبقية (عليه): {0} ريال': 'Remaining balance (owed): {0} SAR',
  'الرصيد الدائن (له): {0} ريال': 'Credit balance (in favour): {0} SAR',
  'صافي الموقف: {0} ريال {1}': 'Net position: {0} SAR {1}',
  'قطع الاشتراك المستهلكة: {0}': 'Subscription pieces used: {0}',
  'استهلاك رصيد سلفة': 'Credit balance used',
  'استرداد إلغاء اشتراك': 'Subscription cancellation refund',
  'تحصيل عند التسليم': 'Collect on delivery',
  'دفعة': 'Payment',

  // ── شاشة تسجيل الدخول ──
  'تسجيل الدخول إلى النظام': 'Sign in to the system',
  'أدخل اسم المستخدم': 'Enter the username',
  'أدخل كلمة المرور': 'Enter the password',
  'تسجيل الدخول': 'Sign in',
  'نظام إدارة المغاسل — الإصدار {0}': 'Laundry Management System - version {0}',
  'نظام إدارة المغاسل الذكي': 'Smart Laundry Management System',
  'نظام إدارة المغاسل الذكي — الإصدار {0}':
      'Smart Laundry Management System - version {0}',
  'مغاسل النظارة لغسيل الملابس': 'Al-Nazara Laundry for Garment Washing',
  'مغاسل النظارة — شكرًا لتعاملكم معنا':
      'Al-Nazara Laundry - thank you for your business',

  // ── الأصناف والأسعار ──
  'إضافة صنف لبس': 'Add garment',
  'أضف لبساً جديداً بأسعار خدماته':
      'Add a new garment with the prices of its services',
  'بيانات الصنف الجديد': 'New item details',
  'حدد اسم اللبس والأسعار لجميع الخدمات':
      'Set the garment name and the prices of all services',
  'سعر الغسيل مستعجل': 'Urgent wash price',
  'سعر الغسيل عادي': 'Normal wash price',
  'سعر الكوي مستعجل': 'Urgent iron price',
  'سعر الكوي عادي': 'Normal iron price',
  'تكلفة القطعة (مواد + تشغيل)': 'Item cost (materials + labour)',
  'حفظ الصنف': 'Save item',
  'تعديل بيانات الصنف': 'Edit item details',
  'عدّل الأسعار ثم احفظ التغييرات': 'Edit the prices then save the changes',
  'حفظ التعديل': 'Save changes',
  'حذف - تعديل صنف لبس': 'Delete / edit garment',
  'إدارة الأسعار والخدمات': 'Manage prices and services',
  'قائمة الأصناف والأسعار': 'Items and prices list',
  'حذف الصنف؟': 'Delete item?',
  'إضافة زبون جديد': 'Add a new customer',

  // ── الشاشة الرئيسية والفواتير ──
  'وردية مفتوحة': 'Open shift',
  'بحث عن زبون': 'Search for a customer',
  'الفواتير السابقة': 'Previous invoices',
  'القائمة الجانبية': 'Side menu',
  'فتح القائمة الجانبية': 'Open the side menu',
  'الأصناف والخدمات': 'Items and services',
  'ابحث عن صنف...': 'Search for an item...',
  'لا توجد وردية مفتوحة — افتح الوردية أولاً لإصدار الفواتير':
      'No open shift - open a shift first to issue invoices',
  'لا توجد أصناف': 'No items',
  'أضف الأصناف من قائمة الإضافة لبس': 'Add items from the "Add garment" menu',
  'الفاتورة فارغة': 'The invoice is empty',
  'الفاتورة فارغة بالفعل': 'The invoice is already empty',
  'اضغط على صنف من القائمة لإضافته': 'Tap an item in the list to add it',
  'إلغاء الفاتورة': 'Cancel invoice',
  'إلغاء الفاتورة؟': 'Cancel the invoice?',
  'سيتم حذف جميع البنود من الفاتورة':
      'All items will be removed from the invoice',
  'سجل جميع الفواتير المصدرة': 'A log of all issued invoices',
  'لا توجد فواتير متاحة': 'No invoices available',
  'ستظهر هنا الفواتير بعد إصدارها من الشاشة الرئيسية':
      'Invoices appear here once issued from the home screen',
  'لا توجد نتائج مطابقة': 'No matching results',
  'جرّب تغيير كلمة البحث أو الفلتر': 'Try a different search term or filter',
  'واتساب': 'WhatsApp',
  'هذه الفاتورة الآجلة': 'This credit invoice',
  'الذمة المتوقّعة': 'Expected balance',
  'حدّ الائتمان': 'Credit limit',
  'مبلغ التجاوز': 'Override amount',

  // ── الزبائن ──
  'لا يوجد زبائن': 'No customers',
  'اضغط زر + لإضافة زبون جديد': 'Tap + to add a new customer',
  'جرّب البحث باسم آخر أو برقم الجوال': 'Try another name or the mobile number',
  'عليه ذمة: {0} ر.س': 'Owes: {0} SAR',
  'له رصيد: {0} ر.س': 'Has credit: {0} SAR',
  'رصيد (سلفة)': 'Credit (advance)',
  'دفعات الذمم': 'Debt payments',
  '(التزام على المنشأة — ليست ديناً على الزبون)':
      '(A liability of the business - not a customer debt)',
  'من الرصيد': 'From credit',
  'التاريخ: {0} — {1}{2}': 'Date: {0} - {1}{2}',
  'تسجيل': 'Record',
  'هل أنت متأكد من حذف هذا الزبون؟\nلن تظهر بياناته في قائمة الزبائن.':
      'Are you sure you want to delete this customer?\nTheir details will no longer appear in the customer list.',
  'وبأي صيغة (مسافات أو أرقام عربية).':
      'in any format (with spaces or Arabic numerals).',
  'ابحث عن الزبون بالاسم أو رقم الجوال...':
      'Search for the customer by name or mobile number...',
  'جارٍ البحث عن الزبائن...': 'Searching for customers...',
  'لا يوجد زبون مطابق': 'No matching customer',
  'الزبائن المقترحون — اضغط للاختيار': 'Suggested customers - tap to select',
  'إضافة "{0}" كزبون جديد': 'Add "{0}" as a new customer',
  'اضغط هنا لإضافة الزبون بالاسم المكتوب':
      'Tap here to add the customer with the name you typed',
  'تمت الإضافة': 'Added',
  'أُضيف الزبون «{0}» وتم تعيينه في الفاتورة':
      'Customer "{0}" added and assigned to the invoice',

  // ── أكواد الخصم ──
  'أكواد الخصم': 'Discount codes',
  '{0} كود': '{0} codes',
  'كود جديد': 'New code',
  'كود خصم جديد': 'New discount code',
  'لا توجد أكواد خصم': 'No discount codes',
  'ثم أدخله في حوار الدفع ليُخصم من الفاتورة.':
      'Then enter it in the payment dialog to deduct it from the invoice.',
  'إنشاء كود': 'Create code',
  'والكود لا يُخصم أكثر من قيمة الفاتورة مهما كان مبلغه.':
      'The code never deducts more than the invoice value, whatever its amount.',
  'من {0} — بلا انتهاء': 'From {0} - no expiry',
  'استُخدم {0} — بلا حدّ': 'Used {0} - no limit',
  'استُخدم {0} / {1}': 'Used {0} / {1}',
  'تعطيل': 'Disable',
  'تفعيل': 'Enable',
  'أُنشئ كود الخصم': 'Discount code created',
  'حُدِّث كود الخصم': 'Discount code updated',
  'أدخل اسمًا للخصم': 'Enter a name for the discount',
  'أدخل كودًا — هو ما يُكتب في الكاشير':
      'Enter a code - this is what is typed at the till',
  'أدخل قيمة أكبر من صفر': 'Enter a value greater than zero',
  'النسبة لا تتجاوز 100%': 'The percentage cannot exceed 100%',
  'تاريخ الانتهاء قبل تاريخ البداية': 'End date is before the start date',
  'حدّ الاستخدام يجب أن يكون رقمًا أكبر من صفر':
      'Usage limit must be a number greater than zero',
  'تعديل كود الخصم': 'Edit discount code',
  'الاسم (وصف داخلي)': 'Name (internal description)',
  'مثال: خصم افتتاح الفرع': 'Example: branch opening discount',
  'الكود': 'Code',
  'نسبة %': 'Percentage %',
  'مبلغ ثابت': 'Fixed amount',
  'النسبة (%)': 'Percentage (%)',
  '10 = خصم 10%': '10 = 10% discount',
  '10 = خصم 10 ر.س': '10 = 10 SAR discount',
  'حدّ الاستخدام (اختياري)': 'Usage limit (optional)',
  'اتركه فارغًا لاستخدام بلا حدّ': 'Leave empty for unlimited use',
  'يبدأ': 'Starts',
  'ينتهي': 'Ends',
  'بلا انتهاء': 'No expiry',
  'المعطَّل يبقى محفوظًا لكنه لا يُطبَّق على أي فاتورة':
      'A disabled code is kept but never applied to any invoice',
  'إزالة': 'Remove',

  // ── طرق الدفع وحالات المصنعية (مفاتيح تخزين + تسمية عرض) ──
  'رصيد': 'Credit balance',
  'تم الاستلام': 'Received',
  'قيد التنفيذ': 'In progress',
  'جاهز للاستلام': 'Ready for pickup',
  'تم التسليم': 'Delivered',

  // ── التقارير ──
  'يومي': 'Daily',
  'أسبوعي': 'Weekly',
  'شهري': 'Monthly',
  'سنوي': 'Yearly',
  'المبيعات': 'Sales',
  'مساهم {0} − مصروفات {1}': 'Contributed {0} - expenses {1}',
  'بعد خصم تكلفة {0} ر.س': 'After deducting cost {0} SAR',
  'إيراد الاشتراكات': 'Subscription revenue',
  'ديون الزبائن': 'Customer debts',
  'أرصدة الزبائن (مدفوع زائد)': 'Customer credit (overpaid)',
  'تحليل ذمم الزبائن': 'Customer debt analysis',
  'أعمار الديون تكشف منذ متى الذمة، والمطابقة تكشف أي خلل في الأرصدة.':
      'Aging shows how old each debt is; reconciliation reveals any imbalance.',
  'توزيع الذمم على فئات تأخر': 'Debts by delay bucket',
  'المطابقة والدفتر': 'Reconciliation and ledger',
  'فحص الأرصدة وسجل الحركات': 'Balance check and movement log',
  'ميزة الطباعة قيد التطوير': 'Printing is under development',
  'اضغط لاختيار التاريخ': 'Tap to pick a date',
  'اختر يوماً لعرض تقريره التفصيلي': 'Pick a day to see its detailed report',
  'اضغط لاختيار الأسبوع': 'Tap to pick a week',
  'اختر الشهر': 'Pick a month',
  'اختر السنة': 'Pick a year',
  'الحساسة فقط': 'Sensitive only',
  'كل الأحداث': 'All events',
  'لا توجد أحداث في هذه الفترة': 'No events in this period',
  'الحدث': 'Event',
  'الجدول': 'Table',
  'السجل': 'Log',
  'القيم السابقة': 'Old values',
  'القيم الجديدة': 'New values',

  // ── الإعدادات ──
  'حالة الاشتراك · تاريخ الانتهاء · سجل التغييرات':
      'Subscription status · expiry date · change log',
  'أكواد الخصم: نسبة أو مبلغ · سريان · حدّ استخدام':
      'Discount codes: percentage or amount · validity · usage limit',
  'الطابعة الافتراضية · الطباعة عند البيع · حفظ PDF ومجلده':
      'Default printer · print on sale · save PDF and its folder',
  'تزامنه ولا تُلغيه.': 'keeps it in sync and never cancels it.',
  'تثبيت قائم حتى تختار المقاس.':
      'an existing setting until you pick the size.',
  'ولا تُفعّل الحذف دون أخذ نسخة احتياطية.':
      'and never enable deletion without taking a backup.',
  'الفاتورة» — بطاقة «الطابعة الافتراضية».':
      'the invoice" - the "Default printer" card.',
  'لا يوجد خيار مطابق للبحث.': 'No option matches the search.',
  'نسخة SQLite خام (‎.db‎) باسم ومكان تختارهما':
      'A raw SQLite copy (.db) with the name and place you choose',
  'إدارة النسخ والاستعادة': 'Manage backup and restore',
  'قائمة النسخ المحفوظة · استعادة من أي ملف على الجهاز':
      'Saved copies list · restore from any file on the device',
  'إدارة أكواد الخصم': 'Manage discount codes',
  'نسبة أو مبلغ ثابت · تاريخ سريان · حدّ استخدام':
      'Percentage or fixed amount · start date · usage limit',
  'معاينة الفاتورة': 'Invoice preview',
  'حالة الاشتراك والأيام المتبقية وسجل كل تغيير':
      'Subscription status, remaining days, and a log of every change',
  'التدقيق باسم محدّثه.': 'audit under the name of whoever updated it.',
  'مجلد الحفظ': 'Save folder',
  'رجعنا إلى المجلد الافتراضي.': 'Back to the default folder.',
  'تعذّر فتح المجلد': 'Could not open the folder',
  'إخراج الفاتورة (طباعة / PDF)': 'Invoice output (print / PDF)',
  'الطابعة الافتراضية': 'Default printer',
  'تعذّر سرد طابعات النظام على هذا الجهاز.':
      'Could not list the system printers on this device.',
  'ثم اضغط زر التحديث.': 'then press the refresh button.',
  'الافتراضية في النظام': 'the system default',
  'غير متصلة': 'Offline',
  'لا يمكن ترك هذا الحقل فارغا': 'This field cannot be left empty',

  // ── الملف الشخصي والترخيص ──
  'تغيير كلمة المرور': 'Change password',
  'كلمة المرور الحالية': 'Current password',
  'كلمة المرور الجديدة': 'New password',
  'تأكيد كلمة المرور الجديدة': 'Confirm new password',
  'حفظ كلمة المرور': 'Save password',
  'أدخل جميع كلمات المرور': 'Enter all passwords',
  'كلمة المرور الجديدة غير متطابقة': 'The new passwords do not match',
  'الحالية': 'Current',
  'جديدة': 'New',
  'تعذّر التحقق من صحة تاريخ الجهاز': 'Could not verify the device date',
  'انتهى اشتراك النظام': 'The system subscription has ended',
  'كمدير النظام لإعادة ضبط التحقق.':
      'as the system administrator to reset verification.',
  'للاستمرار في استخدام النظام، يلزم تجديد الاشتراك.':
      'To keep using the system, the subscription must be renewed.',
  'تجديد الاشتراك': 'Renew subscription',
  'تنبيه: اشتراك النظام': 'Notice: system subscription',
  'مدير النظام (admin).': 'the system administrator (admin).',
  'لاحقًا': 'Later',
  'تجديد الآن': 'Renew now',
  'اشتراك النظام: {0}': 'System subscription: {0}',
  'اشتراك النظام: {0} (حتى {1})': 'System subscription: {0} (until {1})',
  'تجديد': 'Renew',

  // ── بطاقة المطوّر ──
  'للشكاوى والاستفسار تواصل معنا عبر:':
      'For complaints and enquiries, contact us via:',
  'البريد الإلكتروني': 'Email',
  'عن النظام': 'About the system',
  'معلومات التواصل': 'Contact information',

  // ── أسماء الصلاحيات ──
  'إصدار فاتورة': 'Issue an invoice',
  'تطبيق خصم على فاتورة': 'Apply a discount to an invoice',
  'البيع الآجل (تسجيل ذمة)': 'Credit sale (record a debt)',
  'حفظ واسترجاع مسودة': 'Save and restore a draft',
  'طباعة الفاتورة': 'Print the invoice',
  'إعادة طباعة فاتورة سابقة': 'Reprint a previous invoice',
  'إشعار دائن / مرتجع': 'Credit note / return',
  'حذف فاتورة': 'Delete an invoice',
  'تعديل فاتورة صادرة': 'Edit an issued invoice',
  'إغلاق وردية وجردها': 'Close and count a shift',
  'عرض حركة الصندوق': 'View cash movements',
  'عرض الزبائن': 'View customers',
  'إضافة/تعديل زبون': 'Add / edit a customer',
  'حذف/إخفاء زبون': 'Delete / hide a customer',
  'تسجيل دفعة من زبون': 'Record a customer payment',
  'ضبط حدّ الائتمان': 'Set the credit limit',
  'عرض تقارير الديون': 'View debt reports',
  'إصلاح أرصدة الزبائن': 'Repair customer balances',
  'عرض لوحة التحكم': 'View the dashboard',
  'عرض التقارير': 'View reports',
  'عرض الأرباح والتكلفة': 'View profit and cost',
  'عرض إقرار الضريبة': 'View the VAT return',
  'عرض سجل التغييرات': 'View the change log',
  'تصدير البيانات': 'Export data',
  'عرض لوحة المصنعية': 'View the processing board',
  'تحديث حالة المصنعية': 'Update processing status',
  'إدارة الاشتراكات': 'Manage subscriptions',
  'إدارة الأصناف والأسعار': 'Manage items and prices',
  'إدارة إعدادات النظام': 'Manage system settings',
  'إدارة الترخيص': 'Manage the licence',
  'عرض المستخدمين': 'View users',
  'إدارة الأدوار والصلاحيات': 'Manage roles and permissions',
  'النسخ الاحتياطي والاستعادة': 'Backup and restore',
  'تنظيف البيانات القديمة': 'Clean up old data',

  // ═══ الأصناف الافتراضية (بيانات البذر) ═══
  // 🚨 لماذا تُسجَّل هنا مع أن `_insertDefaultClothing` يكتب `clothing_name_en`؟
  // لأن الصنف الذي أُنشئ **قبل** وجود العمود الإنجليزي قيمته `NULL` إلى الأبد،
  // و`L10n.localized` تسقط على القاموس حين يفرغ العمود. فبلا هذه المدخلات
  // يبقى الصنف عربيًّا في الواجهة الإنجليزية ولو بدّل المستخدم اللغة.
  'ثوب أبيض': 'White thobe',
  'ثوب ملون': 'Colored thobe',
  'ثوب صوف': 'Wool thobe',
  'غترة': 'Ghutra',
  'شماغ': 'Shemagh',
  'طاقية': 'Kufi cap',
  'فانيلة داخلية': 'Undershirt',
  'سروال قصير': 'Shorts',
  'سروال طويل': 'Trousers',
  'جوارب': 'Socks',
  'بدلة عسكرية': 'Military suit',
  'بدلة افرنجي': 'Western suit',
  'بدلة صوف': 'Wool suit',
  'بدلة سفاري': 'Safari suit',
  'بدلة رياضية': 'Sports suit',
  'بدلة باكستاني': 'Pakistani suit',
  'جاكيت': 'Jacket',
  'بنطلون': 'Pants',
  'بنطلون صوف': 'Wool pants',
  'قايش/قبعة': 'Belt / hat',
  'طماق': 'Leggings',
  'معطف/بالطو': 'Coat / overcoat',
  'قميص': 'Shirt',
  'بلوزة حرير': 'Silk blouse',
  'فستان': 'Dress',
  'فستان حرير': 'Silk dress',
  'فستان قطعتين': 'Two-piece dress',
  'تنورة': 'Skirt',
  'بشت/فروة': 'Bisht / fur',
  'قميص حرير': 'Silk shirt',
  'عباية': 'Abaya',
  'قميص نوم': 'Nightgown',
  'شرشف مزدوج': 'Double bedsheet',
  'كيس مخدة': 'Pillowcase',
  'شرشف مفرد': 'Single bedsheet',
  'روب حمام': 'Bathrobe',
  'بيجامة': 'Pajamas',
  'فانيلة صوف': 'Wool undershirt',
  'منشفة/منديل': 'Towel / napkin',
  'بطانية': 'Blanket',
  'مفرش': 'Bedspread',
  'ستائر': 'Curtains',
  'سجاد': 'Carpet',

  // ═══ الفئات الافتراضية (بيانات البذر) ═══
  'ملابس رجالية': "Men's clothing",
  'إكسسوارات رجالية': "Men's accessories",
  'ملابس داخلية': 'Underwear',
  'بِدَل': 'Suits',
  'قمصان وبنطلونات': 'Shirts and pants',
  'أكسسوارات': 'Accessories',
  'ملابس نسائية': "Women's clothing",
  'مفروشات': 'Furnishings',

  // وصف الفئات الافتراضية
  'ثوب، شماغ، غترة': 'Thobe, shemagh, ghutra',
  'شماغ، غترة، طاقية': 'Shemagh, ghutra, kufi cap',
  'فانيلة، سروال، جوارب': 'Undershirt, trousers, socks',
  'عسكرية، افرنجية، صوف': 'Military, Western, wool',
  'قميص، بنطلون، جاكيت': 'Shirt, pants, jacket',
  'قبعة، طماق': 'Hat, leggings',
  'فستان، بلوزة، عباية': 'Dress, blouse, abaya',
  'شرشف، مفرش، بطانية، ستائر': 'Bedsheet, bedspread, blanket, curtains',

  // ═══ بحث الأصناف ═══
  'لم نجد صنفاً يطابق البحث "{0}"': 'No item matches the search "{0}"',

  // ═══ حقوق المطوّر ═══
  // (بقية نصوص النوافذ — «نظام إدارة المغاسل» · «معلومات التواصل» · … —
  // مُترجمة سابقًا في مواضعها، فلا تُكرَّر هنا.)
  'مطوّر النظام — المهندس محمد صادق': 'System developer — Eng. Mohammed Sadeq',
  'برمجة وتطوير المهندس محمد صادق': 'Developed by Eng. Mohammed Sadeq',

  '«{0}» لديه اشتراك نشط بالفعل (#{1} بمبلغ {2}). أوقف الاشتراك القديم أولًا أو جدّد نفسه.':
      '"{0}" already has an active subscription (#{1} for {2}). Stop the old one first, or renew it.',
  'آخر 7 أيام': 'Last 7 days',
  'نسخة أمان تلقائية': 'Automatic safety backup',
  'نسخة عادية': 'Regular backup',
  'دفعة سريعة من تقرير الذمم': 'Quick payment from the debt report',
  'هذه السنة': 'This year',
  'فترة مخصّصة': 'Custom range',
  'تم تحديث الإعداد بنجاح': 'Setting updated successfully',
  'تعديل حدّ الائتمان': 'Credit limit changed',
  'منع تجاوز سقف اشتراك': 'Subscription cap overrun blocked',
  'تجاوز سقف اشتراك': 'Subscription cap overrun',
  'إلغاء اشتراك': 'Subscription cancelled',
  'إنشاء فاتورة': 'Invoice created',
  'استهلاك رصيد': 'Balance used',
  'حذف زبون': 'Customer deleted',
  'إقفال وردية': 'Shift closed',
  'إصلاح أرصدة': 'Balances repaired',
  'إضافة مستخدم': 'User added',
  'حذف مستخدم': 'User deleted',
  'الزبون غير موجود في السجل': 'Customer not found in the records',
  '0 - 30 يومًا': '0 - 30 days',
  '31 - 60 يومًا': '31 - 60 days',
  '61 - 90 يومًا': '61 - 90 days',
  'أكثر من 90 يومًا': 'Over 90 days',
  'منخفض': 'Low',
  'كود الخصم غير موجود': 'Discount code not found',
  'هذا الخصم بلا كود — لا يمكن استدعاؤه':
      'This discount has no code — it cannot be applied',
  'لا يوجد مبلغ لتطبيق الخصم عليه':
      'There is no amount to apply the discount to',
  'الخصم المحسوب صفر — تحقّق من قيمة الكود':
      'The computed discount is zero — check the code value',
  'تعذّر التحقق من كود الخصم': 'Could not verify the discount code',
  'فواتير': 'Invoices',
  'اختر مجلد حفظ فواتير PDF': 'Choose the folder for saved PDF invoices',
  'ملف الفاتورة فارغ — لم تُطبَع ولم تُحفظ نسخة.':
      'The invoice file is empty — nothing was printed and no copy was saved.',
  'تطبيق تاريخ الكود': 'Applied the date embedded in the code',
  'إلغاء التاريخ (غير محدود)': 'Date cleared (unlimited)',
  'تجديد / تعديل يدوي': 'Manual renewal / edit',
  'اشتراك شهري': 'Monthly subscription',
  'تعديل المصروف': 'Edit expense',
  'تسجيل المصروف': 'Record expense',
  'خدمة اشتراك مدفوعة مقدماً لم تُنفَّذ بعد (التزام على المنشأة — ليست ديناً على الزبون)':
      'A prepaid subscription service not yet delivered (a liability of the business — not a customer debt)',
  'استرداد اشتراك': 'Subscription refund',
  'وسداد {0}': 'and {0} paid',
  'أنشئ كودًا (نسبة أو مبلغًا) بصلاحية استخدام وتاريخ انتهاء، ثم أدخله في حوار الدفع ليُخصم من الفاتورة.':
      'Create a code (percentage or amount) with a usage right and an expiry date, then enter it in the payment dialog to deduct it from the invoice.',
  'الخصم يُطبَّق قبل الضريبة: تُحتسب ضريبة القيمة المضافة على الصافي بعد الخصم، فلا يدفع الزبون ضريبة مبلغ لم يشتره. والكود لا يُخصم أكثر من قيمة الفاتورة مهما كان مبلغه.':
      'The discount is applied before tax: VAT is computed on the net after the discount, so the customer never pays tax on an amount they did not buy. And the code never deducts more than the invoice total, whatever its value.',
  'تاريخ الجهاز يسبق آخر تشغيل مسجّل للنظام. اضبط تاريخ الجهاز بشكل صحيح، أو جدّد الاشتراك كمدير النظام لإعادة ضبط التحقق.':
      'The device date is earlier than the last recorded run of the system. Set the device date correctly, or renew the subscription as the system administrator to reset the check.',
  'خيارات إخراج الفاتورة (طباعة / PDF) في صفحة «الطباعة وإخراج الفاتورة» — بطاقة «الطابعة الافتراضية».':
      'Invoice output options (print / PDF) are on the "Printing and invoice output" page — the "Default printer" card.',
  'غياب التاريخ يعني نظامًا غير محدود. ويُسجَّل كل تغيير في سجل التدقيق باسم محدّثه.':
      'An empty date means an unlimited system. Every change is recorded in the audit log under the name of whoever made it.',
  'لا توجد طابعات مثبَّتة على الجهاز. أضِف طابعة من إعدادات ويندوز ثم اضغط زر التحديث.':
      'No printers are installed on this device. Add a printer from Windows settings, then press the refresh button.',
  'جدّد الاشتراك الآن لتفادي توقّف النظام. يتطلب التجديد بيانات مدير النظام (admin).':
      'Renew now to avoid the system stopping. Renewal requires the system administrator (admin) credentials.',
  'استرداد قيمة أيام غير مُقدَّمة': 'Refund for undelivered days',
  'استرداد عند الإلغاء': 'Refund on cancellation',
  'الوصول إلى «{0}» مقصور على من يملك الصلاحية.':
      'Access to "{0}" is restricted to those who hold the permission.',
  'لا تملك صلاحية «{0}»، راجع مدير النظام.':
      'You do not hold the "{0}" permission — contact the system administrator.',
  'ستُحفظ نسخ الفواتير في: {0}': 'Invoice copies will be saved in: {0}',
  'افتحه يدويًا: {0}': 'Open it manually: {0}',
  'تعذّر حفظ نسخة PDF: {0}': 'Could not save the PDF copy: {0}',
  'استرداد إلغاء اشتراك #{0}': 'Refund for cancelling subscription #{0}',
  '{0} — {1} يوم غير مُقدَّم': '{0} — {1} undelivered days',
  '{0} يوم غير مُقدَّم': '{0} undelivered days',
  'استهلاك رصيد سلفة على فاتورة #{0}': 'Advance balance used on invoice #{0}',
  'سداد عند تسليم الفاتورة #{0}': 'Payment on delivery of invoice #{0}',
  'استهلاك رصيد سلفة على الفاتورة #{0}': 'Advance balance used on invoice #{0}',
  'تنظيف تلقائي للفواتير': 'Automatic invoice cleanup',
  'أُزيلت {0} فاتورة قديمة بإجمالي {1}':
      'Removed {0} old invoices totalling {1}',
  'وفق سياسة الاحتفاظ بالفواتير.': 'according to the invoice retention policy.',
  'تم إلغاء الفاتورة وحذف جميع بنودها!':
      'The invoice was cancelled and all its items deleted!',
  'تعذر اختيار الصورة': 'Could not pick the image',
  'فاتورة سابقة': 'Previous invoice',
  'صافي الوردية': 'Shift net',
  'صافي اليوم': 'Day net',
  'أُصلح ملفّ الإعدادات': 'Settings file repaired',
  'كان ملفّ الإعدادات تالفًا — أثر إطفاء مفاجئ للجهاز — فأُعيد ضبطه':
      'The settings file was corrupted — the result of an abrupt power loss — and has been reset',
  'وأُبقيت نسخة من التالف جانبًا. سجّل الدخول مرة أخرى.':
      'A copy of the corrupted file was kept aside. Please sign in again.',
  'رقم هاتف النشاط': 'Business phone number',
  'الرياض-حي اشبيليا-طريق الصحابة':
      'Riyadh - Ashbiliya district - Al-Sahaba road',
  'رابط موقع النشاط على خرائط جوجل': 'Business location link on Google Maps',
  'الرقم الضريبي (VAT) — يظهر على الفاتورة الضريبية':
      'VAT number — shown on the tax invoice',
  'ويُرمَّز في QR الهيئة': 'and encoded in the authority QR',
  'السجل التجاري — يظهر على الفاتورة عند تفعيل خياره':
      'Commercial registration — shown on the invoice when its option is enabled',
  'العنوان الوطني المختصر — يظهر على الفاتورة عند تفعيله':
      'Short national address — shown on the invoice when enabled',
  'أخذ نسخة كاملة واستعادة نسخة. **الاستعادة تمحو القاعدة الحالية كاملةً** — أخطر عملية في النظام بلا منافس.':
      'Take a full backup and restore one. **Restore wipes the current database entirely** — the single most dangerous operation in the system.',
  'أعمار الديون وكشف الحساب ومتابعة الذمم.':
      'Debt ageing, account statements and receivables tracking.',
  'إخراج الفاتورة PDF وطباعتها أو مشاركتها.':
      'Export the invoice as PDF, print it or share it.',
  'إخراج بيانات النظام إلى ملف للتحليل خارجيًا.':
      'Export system data to a file for external analysis.',
  'إخفاء الزبون من القوائم. حذف ناعم (`is_active=0`) لا محو — يبقى أثر ذممه في الدفاتر.':
      'Hide the customer from lists. A soft delete (`is_active=0`), not an erasure — the trace of their debts stays in the books.',
  'إدخال كود خصم أو خصم يدوي قبل الدفع. **فُصل عن إصدار الفاتورة عمدًا**: الخصم يُنقص الإيراد مباشرةً، وهو أسهل طريق لتسريب المال (خصم وهمي مقابل نقد).':
      'Enter a discount code or a manual discount before payment. **Deliberately separated from issuing the invoice**: a discount reduces revenue directly and is the easiest route for leaking money (a fictitious discount in exchange for cash).',
  'إصدار إشعار دائن لتصحيح فاتورة صادرة **بلا حذفها** — الطريق المحاسبي الصحيح للتصحيح.':
      'Issue a credit note to correct an issued invoice **without deleting it** — the correct accounting route for a correction.',
  'إضافة صنف وتعديله وأسعاره الأربعة **وتكلفته**. تعديل `cost_price` يغيّر كل أرباح المستقبل، فهو صلاحية مالية مُقنَّعة بإدارة.':
      'Add an item, edit it, its four prices **and its cost**. Changing `cost_price` alters every future profit, so it is a financial permission disguised as administration.',
  'إضافة مستخدم وتعديله وتغيير كلمة مروره وتعطيله. يمسّ الأمن مباشرةً، فهو من أخطر صلاحيات النظام.':
      'Add a user, edit them, change their password and disable them. This touches security directly, making it one of the most dangerous permissions in the system.',
  'إضافة مصروف وتعديله وحذفه — قيد يخرج من الصندوق مباشرةً، فهو عمل مالي لا إداري.':
      'Add, edit and delete an expense — an entry that leaves the till directly, so it is financial work, not administrative.',
  'إظهار الربح الصافي والتكلفة في التقارير. **فُصلت عمدًا**: رقم الربح من أدقّ أسرار المنشأة، ومن يُدخل بيانات لا يلزم أن يرى هامشها.':
      'Show net profit and cost in reports. **Deliberately separated**: the profit figure is among the business\'s most sensitive secrets, and whoever enters data need not see its margin.',
  'إعادة اشتقاق حقل `customers.balance` من الفواتير. عملية تصحيحية تُعيد كتابة أرقام كل الزبائن دفعةً واحدة — أخطر من أي دفعة فردية ولهذا لا تُدمج مع «تسجيل دفعة».':
      'Re-derive the `customers.balance` field from invoices. A corrective operation that rewrites every customer\'s figure at once — more dangerous than any single payment, which is why it is not merged with "record payment".',
  'إغلاق الوردية وتسجيل النقد المعدود والفرق وسببه. **فُصلت عن الفتح عمدًا**: من يفتح الصندوق ليس بالضرورة من يُحاسَب على جرده — الفصل يمنع إغلاقًا يمحو فرقًا حرجه.':
      'Close the shift and record the counted cash, the difference and its reason. **Deliberately separated from opening**: whoever opens the till is not necessarily the one accountable for its count — the separation prevents a closing that erases a critical difference.',
  'إلغاء الاشتراك واحتساب الاسترداد (يخفض ذمة الزبون أولًا). **فُصل عن الإدارة عمدًا**: الإلغاء يُرجع مالًا ويُكتب حركة `cancel_refund`، فهو تصحيح لا إدارة روتينية.':
      'Cancel the subscription and compute the refund (it reduces the customer\'s balance first). **Deliberately separated from administration**: cancellation returns money and writes a `cancel_refund` entry, so it is a correction, not routine administration.',
  'إنشاء أكواد الخصم وتحديد نسبتها وسقف استخدامها وتعطيلها.':
      'Create discount codes, set their percentage and usage cap, and disable them.',
  'إنشاء اشتراك شهري وتسجيل دفعاته — اعتراف بإيراد مؤجَّل، فهو قيد محاسبي لا عمل تشغيلي.':
      'Create a monthly subscription and record its payments — a recognition of deferred revenue, so it is an accounting entry, not operational work.',
  'إنشاء فاتورة بيع جديدة وتحويلها إلى مدفوعة. هذا هو العمل الأساسي للصندوق، ولهذا يُمنح للكاشير ابتداءً.':
      'Create a new sales invoice and convert it to paid. This is the core work of the till, which is why it is granted to the cashier by default.',
  'استخراج ضريبة المخرجات والمدخلات الصافي المستحق.':
      'Extract output and input tax and the net amount due.',
  'التقارير اليومية والأسبوعية والشهرية والسنوية.':
      'Daily, weekly, monthly and yearly reports.',
  'السماح ببيع يتخطّى سقف الزبون المضبوط. **فُصلت عن ضبط الحدّ عمدًا**: الضبط سياسة، والتجاوز استثناء عليها — ولا يجوز أن يمنح الاثنان لشخص واحد بلا مبرر.':
      'Allow a sale that exceeds the customer\'s configured cap. **Deliberately separated from setting the limit**: setting is policy, overriding is an exception to it — and both must not be granted to one person without justification.',
  'بدء وردية جديدة وضبط رصيدها الافتتاحي. لا بيع بلا وردية مفتوحة، فهذه الصلاحية **بوابة العمل اليومي**.':
      'Start a new shift and set its opening balance. There is no selling without an open shift, so this permission is **the gateway to daily work**.',
  'تحديد سقف الدين المسموح لزبون معيّن.':
      'Set the allowed debt cap for a given customer.',
  'تسجيل الفاتورة كدين على الزبون بدل تحصيلها نقدًا. **فُصلت عمدًا**: منح الائتمان هو المخاطرة المالية الأكبر في المنشأة، ولا يجوز أن يُفعّله كل كاشير ضمن قدرته على البيع.':
      'Record the invoice as a debt on the customer instead of collecting it in cash. **Deliberately separated**: granting credit is the greatest financial risk in the business, and it must not be enabled for every cashier as part of their ability to sell.',
  'تسجيل زبون جديد وتعديل بياناته.':
      'Register a new customer and edit their details.',
  'تصفّح قائمة الزبائن وبياناتهم وأرصدتهم.':
      'Browse the customer list, their details and balances.',
  'تصفّح قائمة المستخدمين وأدوارهم وحالة حساباتهم.':
      'Browse the user list, their roles and account status.',
  'تعديل ما يملكه كل دور من صلاحيات. **فُصل عن إدارة المستخدمين عمدًا**: من يضيف مستخدمًا ليس بالضرورة من يُعيد رسم حدود النظام — وإلا صار كل مدير قادرًا على ترقية نفسه.':
      'Edit the permissions each role holds. **Deliberately separated from user management**: whoever adds a user is not necessarily the one who redraws the system\'s boundaries — otherwise every manager could promote themselves.',
  'تغيير بنود فاتورة صدرت أو مبلغها بعد إصدارها.':
      'Change the items or amount of an invoice after it has been issued.',
  'حذف الفواتير الأقدم من مدّة الاحتفاظ المضبوطة.':
      'Delete invoices older than the configured retention period.',
  'حفظ فاتورة غير مكتملة واسترجاعها لاحقًا.':
      'Save an incomplete invoice and retrieve it later.',
  'سجل التدقيق: من غيّر ماذا ومتى (أسعار، ذمم، إعدادات، أدوار).':
      'Audit log: who changed what and when (prices, receivables, settings, roles).',
  'شاشة النقد اليومي وحركات الوردية ومطابقتها.':
      'The daily cash screen, shift movements and their reconciliation.',
  'عرض تاريخ انتهاء الترخيص وتجديده.':
      'View the licence expiry date and renew it.',
  'فتح أرشيف الفواتير وطباعة نسخة جديدة. مستقلّة عن الطباعة عند البيع لأنها تفتح سجلات تاريخية لا فاتورة الحاضر.':
      'Open the invoice archive and print a new copy. Independent of printing at the point of sale because it opens historical records, not the invoice of the present.',
  'قبض نقدي يُخصَم من ذمة الزبون أولًا (FIFO) ثم يُقيَّد سلفةً للفائض. حركة نقدية تُغيّر الصندوق والذمة معًا.':
      'A cash receipt applied to the customer\'s balance first (FIFO) and then booked as an advance for the excess. A cash movement that changes both the till and the balance together.',
  'مؤشرات اليوم: المبيعات والذمم والمصنعية.':
      'Today\'s indicators: sales, receivables and processing.',
  'متابعة حالة الفواتير الواردة في خط الغسيل.':
      'Track the status of invoices on the laundry line.',
  'محو فاتورة من السجل نهائيًا. عملية تصحيحية خطِرة تُفسد أثرًا محاسبيًا وتُخِلّ بالصندوق — تُمنح للإدارة وحدها.':
      'Erase an invoice from the record permanently. A dangerous corrective operation that destroys an accounting trace and distorts the till — granted to management alone.',
  'معلومات النشاط والضريبة والترقيم والطباعة والأدوار — قلب تحكّم النظام، ولهذا لا يُمنح إلا لمن يُسائَل عن النظام كله.':
      'Business, tax, numbering, printing and roles information — the heart of system control, which is why it is granted only to whoever is accountable for the whole system.',
  'نقل الفاتورة بين مراحل الغسيل والكي والتسليم.':
      'Move the invoice between the washing, ironing and delivery stages.',
  'أندرويد': 'Android',
  'ويندوز (سطح المكتب)': 'Windows (desktop)',
  'لقطة مُستنتجة عند الترحيل': 'Snapshot inferred during migration',
  'الرقم الضريبي (VAT) — يظهر على الفاتورة الضريبية ويُرمَّز في QR الهيئة':
      'VAT number — shown on the tax invoice and encoded in the authority QR',
  'أُزيلت {0} فاتورة قديمة بإجمالي {1} وفق سياسة الاحتفاظ بالفواتير.':
      'Removed {0} old invoices totalling {1} per the invoice retention policy.',
  'فشل في تحديث الإعداد: {0}': 'Failed to update the setting: {0}',
  'كود «{0}» مستخدم بالفعل': 'Code "{0}" is already in use',
  '«{0}» سيتجاوز حدّ ائتمانه بمقدار {1} (الحد {2} — بعد البيع {3}). لا يملك صلاحية التجاوز إلا مدير.':
      '"{0}" would exceed their credit limit by {1} (limit {2} — after the sale {3}). Only a manager may override.',
  '«{0}» عليه ذمة قائمة {1}. لا حدّ ائتمان مضبوط له — يُنصح بتحديد حدّ.':
      '"{0}" has an outstanding balance of {1}. No credit limit is set for them — setting one is recommended.',
  'تجاوزُ حدّ الائتمان لـ«{0}» بمقدار {1} (الحد {2} — بعد البيع {3}). تسجيلك يسمح بالتجاوز.':
      'Credit limit overridden for "{0}" by {1} (limit {2} — after the sale {3}). Your permission allows the override.',
  'استُنفد كود «{0}» ({1}/{2})': 'Code "{0}" is used up ({1}/{2})',
  'انتهى كود «{0}» في {1}': 'Code "{0}" expired on {1}',
  'خصم {0}% — «{1}»': '{0}% discount — "{1}"',
  'خصم {0} — «{1}»': 'Discount {0} — "{1}"',
  'قيمة كود «{0}» غير صالحة': 'The value of code "{0}" is invalid',
  'كود «{0}» لم يبدأ بعد — يبدأ {1}':
      'Code "{0}" has not started yet — it starts {1}',
  'كود «{0}» معطَّل': 'Code "{0}" is disabled',
  'استرداد عند الإلغاء — {0} يوم غير مُقدَّم':
      'Refund on cancellation — {0} undelivered days',
  'استرداد قيمة أيام غير مُقدَّمة — {0} (اشتراك #{1}، {2} يوم)':
      'Refund for undelivered days — {0} (subscription #{1}, {2} days)',
  'طُبِّق تاريخ الترخيص المضمَّن في الكود: {0}':
      'Applied the licence date embedded in the code: {0}',
  'سيُعاد اشتقاق رصيد {0} زبون من فواتيره الفعلية، فتصبح الأرصدة مطابقة للفواتير تمامًا.\\n\\nآمن تمامًا: لا يُحذف ولا يُعدَّل أي مبلغ في الفواتير، ولا يُمسّ الدفعات المسجّلة. العملية تُصحّح حقل الرصيد فقط.':
      'The balance of {0} customers will be re-derived from their actual invoices, so the balances match the invoices exactly.\\n\\nCompletely safe: no amount in any invoice is deleted or changed, and recorded payments are untouched. The operation corrects the balance field only.',
  'كان ملفّ الإعدادات تالفًا — أثر إطفاء مفاجئ للجهاز — فأُعيد ضبطه وأُبقيت نسخة من التالف جانبًا. سجّل الدخول مرة أخرى.':
      'The settings file was corrupted — the trace of an abrupt power loss — so it was reset and a copy of the corrupted file was kept aside. Please sign in again.',
  'مغاسل النظارة': 'Al-Naddara Laundry',
  'ثوب أبيص': 'White thobe',
  'على هذا الزبون ذمة قائمة بقيمة {0} ر.س. سدّد الذمم أولًا ثم أعد المحاولة.':
      'This customer has an outstanding balance of {0} SAR. Settle the balance first, then try again.',
  'لهذا الزبون رصيد {0} ر.س لم يُستخدَم. إذا حذفته سيبقى الرصيد مسجَّلًا لكنه لن يظهر في القائمة. هل تريد المتابعة؟':
      'This customer has an unused balance of {0} SAR. If you delete them the balance stays recorded but no longer appears in the list. Do you want to continue?',
  'تم تسجيل {0} — بقي للزبون رصيد {1} ر.س كسلفة':
      'Recorded {0} — the customer has {1} SAR left as an advance',
  '🧺 {0}\nالسلام عليكم {1}،\nغسيلكم جاهز للاستلام 💯\n📌 فاتورة #{2}\n🔑 رمز الاستلام: {3}\nننتظركم — {4} {5}':
      '🧺 {0}\nHello {1},\nYour laundry is ready for pickup 💯\n📌 Invoice #{2}\n🔑 Pickup code: {3}\nSee you — {4} {5}',
  'رمز العملة المعروض في الواجهات والفواتير (مثال: ر.س). يُترجم الافتراضي إلى SAR في الوضع الإنجليزي، وأي رمز آخر يبقى كما تكتبه.':
      'The currency symbol shown across the interface and on invoices (e.g. SAR). The default is rendered as SAR in English mode; any other symbol you enter is kept as typed.',

  // ═══ المرتجعات وإشعارات الدائن (2026-10-30) ═══
  'إشعار دائن': 'Credit note',
  'مُرجعة': 'Returned',
  'تم الإرجاع': 'Returned',
  'تعذّر الإرجاع': 'Could not return the invoice',
  'إرجاع كامل': 'Full return',
  'إرجاع الفاتورة / إشعار دائن': 'Return invoice / credit note',
  'إرجاع الفاتورة #{0}': 'Return invoice #{0}',
  'تأكيد الإرجاع': 'Confirm return',
  'إجمالي الفاتورة': 'Invoice total',
  'طريقة ردّ المبلغ': 'Refund method',
  'رصيد للزبون (سلفة)': 'Customer credit (advance)',
  'نقدًا من الصندوق': 'Cash from the drawer',
  'لا تخرج نقدية من الدرج — يُخصم الرصيد من فواتيره القادمة.':
      'No cash leaves the drawer — the credit is deducted from their next invoices.',
  'يُخصم المبلغ من نقدية الوردية الحالية.':
      'The amount is deducted from the current shift cash.',
  'الفاتورة بلا زبون — لا حساب لتقييد الرصيد، فيُردّ المبلغ نقدًا من الصندوق.':
      'The invoice has no customer — there is no account to post credit to, so the amount is refunded in cash from the drawer.',
  'سبب الإرجاع (اختياري)': 'Return reason (optional)',
  'سيُنشأ إشعار دائن سالب ويُبرَّأ ما تبقّى على الفاتورة. الفاتورة الأصلية لا تُحذف ولا تُعدَّل.':
      'A negative credit note is created and the invoice remaining balance is cleared. The original invoice is neither deleted nor edited.',
  'لا تملك صلاحية إصدار إشعار دائن — راجع مدير النظام.':
      'You do not hold the “Issue credit note” permission — contact the system administrator.',
  'الفاتورة غير موجودة.': 'Invoice not found.',
  'هذا السجل إشعار دائن بذاته — لا يمكن إرجاعه.':
      'This record is itself a credit note — it cannot be returned.',
  'فاتورة اشتراك: صحّحها بإلغاء الاشتراك وتسويته، لا بإشعار دائن.':
      'Subscription invoice: correct it by cancelling and settling the subscription, not with a credit note.',
  'أُرجعت هذه الفاتورة مسبقًا.': 'This invoice has already been returned.',
  'مبلغ الفاتورة غير صالح للإرجاع.':
      'The invoice amount is not valid for a return.',
  'تعذّر الوصول إلى قاعدة البيانات.': 'Could not reach the database.',
  'تعذّر إصدار الإشعار: {0}': 'Could not issue the credit note: {0}',
  'أُصدر إشعار دائن #{0} — وأُعيد {1} نقدًا من الصندوق.':
      'Credit note #{0} issued — {1} refunded in cash from the drawer.',
  'أُصدر إشعار دائن #{0} — وأُضيف {1} رصيدًا للزبون.':
      'Credit note #{0} issued — {1} added to the customer credit.',

  // ═══ إنفاذ الصلاحيات (2026-10-30) ═══
  'إصدار الفواتير يحتاج صلاحية «إصدار فاتورة» — راجع مدير النظام.':
      'Issuing invoices requires the “Create invoice” permission — contact the system administrator.',
  'لا تملك صلاحية الطباعة — الفاتورة محفوظة، راجع مدير النظام.':
      'You do not hold the print permission — the invoice is saved; contact the system administrator.',
  'لا تملك صلاحية الطباعة — لم تُرسل ورقة المغسلة، راجع مدير النظام.':
      'You do not hold the print permission — the laundry slip was not sent; contact the system administrator.',
  'تجاوز سقف استخدام الاشتراك': 'Override subscription usage cap',
  'السماح بإصدار فاتورة تتجاوز سقف قطع/قيمة الاشتراك. **مفتاح مستقلّ عن إدارة الاشتراكات**: التجاوز يُنقص هامش الاشتراك فعليًّا، ومن يدير الاشتراكات لا يلزم أن يملك إسقاط سقفها.':
      'Allow an invoice that exceeds the subscription piece/value cap. A key independent of subscription management: overriding really reduces the subscription margin, and whoever manages subscriptions need not be allowed to lift its cap.',
  'إتاحة طباعة ملصق لكل قطعة عند الاستلام — **غير مفعّلة بعد**، والإعداد محفوظ للمرحلة القادمة.':
      'Allow printing one label per item on intake — **not enabled yet**; the setting is kept for the next phase.',
  'مقاس ملصق تتبّع قطع الغسيل — **لا تُطبع ملصقات بعد**، والإعداد محفوظ للمرحلة القادمة.':
      'The size of the garment tracking label — **labels are not printed yet**; the setting is kept for the next phase.',
  // ═══ لغة الطباعة (2026-10-30) ═══
  'لغة الطباعة': 'Print language',
  'لغة كل مستند يخرج من النظام: الفاتورة · كشف الحساب · ملخص الوردية · ورقة المغسلة. لا تتبع لغة النظام.':
      'The language of every document the system outputs: invoice · account statement · shift summary · laundry slip. It does not follow the interface language.',
  'لغة النظام الآن: {0} — تغييرها لا يغيّر لغة الطباعة.':
      'Interface language now: {0} — changing it does not change the print language.',
  'تُطبَّق اللغة عند كل طباعة — إعادة طباعة فاتورة قديمة تستخدم اللغة المختارة الآن.':
      'The language applies to every print — reprinting an old invoice uses the language selected now.',
  'معاينة تمثيلية بلغة الطباعة المختارة — تتغير مع كل خيار إظهار، ولا تُحفظ ولا تُطبع.':
      'A representative preview in the selected print language — it follows every visibility option and is neither saved nor printed.',
  // ═══ رمز QR لموقع النشاط (2026-10-30) ═══
  'رمز QR لموقع النشاط': 'Business location QR',
  'امسح الرمز للوصول إلى موقعنا': 'Scan the code to reach our location',
  'يُطبع أسفل الفاتورة ويفتح موقع النشاط على خرائط جوجل. يحتاج رابطًا في «معلومات النشاط ← رابط الموقع»، ولا يُطبع شيء إن كان الرابط فارغًا.':
      'Printed at the bottom of the invoice and opens the business location on Google Maps. It needs a link under “Business information → Location link”; nothing is printed when the link is empty.',
  'يُطبع أسفل الكشف ويفتح موقع النشاط على خرائط جوجل. يحتاج رابطًا في «معلومات النشاط ← رابط الموقع».':
      'Printed at the bottom of the statement and opens the business location on Google Maps. It needs a link under “Business information → Location link”.',
  'اختياري — يُطبع كرمز QR أسفل الفاتورة': 'Optional — printed as a QR code at the bottom of the invoice',
  'رابط الموقع لا يصلح لرمز QR — يُقبل رابط http/https أو إحداثيات مثل 24.7136,46.6753.':
      'The location link cannot be encoded as a QR — use an http/https link or coordinates such as 24.7136,46.6753.',
  // ═══ حفظ PDF من كل مسارات الإخراج (2026-10-30) ═══
  'حفظ PDF': 'Save PDF',
  'حفظ نسخة PDF': 'Save a PDF copy',
  'حفظ الكشف PDF': 'Save statement PDF',
  'حفظ الملخص PDF': 'Save summary PDF',
  'في مجلد حفظ المستندات — بلا طباعة':
      'In the documents folder — without printing',
  'فشل في حفظ ملخص الوردية: {0}': 'Failed to save the shift summary: {0}',
  // ═══ حالة رابط الموقع (2026-10-30) ═══
  'لا رمز QR — لم يُدخَل رابط موقع.':
      'No QR — no location link has been entered.',
  'لن يُطبع رمز QR: هذا ليس رابطًا. الصق رابطًا يبدأ بـ https:// أو إحداثيات مثل 24.7136,46.6753.':
      'No QR will be printed: this is not a link. Paste a link starting with https:// or coordinates such as 24.7136,46.6753.',
  'لن يُطبع رمز QR: الرابط بلا نطاق — يبدو رمز مشاركة فقط.':
      'No QR will be printed: the link has no domain — it looks like a share code only.',
  'سيُطبع رمز QR، لكن الرابط لا يبدو رابط خرائط جوجل — تأكّد أنه يفتح موقعك.':
      'A QR will be printed, but the link does not look like a Google Maps link — make sure it opens your location.',
  'سيُطبع رمز QR على الفاتورة وكشف الحساب، ويفتح موقعك على خرائط جوجل.':
      'A QR will be printed on the invoice and the account statement, opening your location on Google Maps.',
  'استخدام الصيغة الصحيحة: {0}': 'Use the correct form: {0}',
  'رمز QR للموقع': 'Location QR',
  'رابط الموقع بلا نطاق — لن يُطبع رمز QR. اضغط زرّ الإصلاح تحت الحقل، أو استخدم: {0}':
      'The location link has no domain — no QR will be printed. Press the repair button under the field, or use: {0}',
  'مقاسات الطباعة':
      'Print sizes',
  'عرض وارتفاع الشعار ورمز QR بالمليمتر — وتُحسب مساحتهما ونسبتهما من الورق، وتُقصّ القيم تلقائيًّا على مقاس الورق المختار.':
      'The logo and QR size in millimetres — their area and share of the paper are computed, and both are trimmed to the selected paper size.',
  'اجعل الشعار مربّعًا':
      'Make the logo square',
  'القيم الافتراضية':
      'Default values',
  'اكتب الرقم ثم اضغط Enter لتطبيقه.':
      'Type the number and press Enter to apply it.',
  'الشعار على الورق: {0} × {1} مم':
      'Logo on paper: {0} × {1} mm',
  'المساحة القصوى {0} مم² — {1}% من الورق':
      'Up to {0} mm² — {1}% of the paper',
  'رمز QR: {0} × {1} مم':
      'QR code: {0} × {1} mm',
  'لا يُطبع: لم يُسجَّل رابط موقع النشاط بعد.':
      'Not printed: no business location link has been saved yet.',
  'مجموع ارتفاعهما {0}% من ارتفاع الورق':
      'Together they take {0}% of the paper height',
  'النسبة كبيرة: الرأس والتذييل يأكلان أغلب الورقة. صغّر الشعار أو الرمز كي لا يتزاحم النصّ أو يُدفع إلى صفحة ثانية.':
      'That is too much: the header and footer are eating most of the page. Shrink the logo or the QR so the text is not crowded or pushed to a second page.',
  'الورق المختار: {0} — والمتاح للطباعة {1} مم عرضًا.':
      'Selected paper: {0} — {1} mm available for printing.',
  'الشعار سيُقصّ: طُلب أكبر من الورق ({0} مم عرضًا).':
      'The logo will be trimmed: it was set wider than the paper ({0} mm).',
  'سيُطبع {0} × {1} مم بدل المقاس المطلوب.':
      'It will print at {0} × {1} mm instead of the requested size.',
  'رمز QR سيُقصّ إلى {0} مم لأن الورق لا يتّسع أكثر.':
      'The QR will be trimmed to {0} mm because the paper cannot fit more.',
  'الأفضل اختيار مقاس أقلّ من ذلك صراحةً لتعرف ما سيُطبع.':
      'It is better to choose a smaller size explicitly so you know what will print.',
  'عرض الشعار (مم)':
      'Logo width (mm)',
  'عرض الشعار أعلى الفاتورة بالمليمتر. يُقصّ تلقائيًّا على عرض الورق إن تجاوزه.':
      'The logo width at the top of the invoice, in millimetres. It is trimmed to the paper width if it exceeds it.',
  'ارتفاع الشعار (مم)':
      'Logo height (mm)',
  'ارتفاع الشعار بالمليمتر. يُقيَّد بسقف الارتفاع كي لا يدفع أصناف الفاتورة إلى صفحة ثانية.':
      'The logo height in millimetres. It is capped so it cannot push the invoice items onto a second page.',
  'مقاس رمز QR للموقع (مم)':
      'Location QR size (mm)',
  'ضلع مربّع رمز الموقع أسفل الفاتورة بالمليمتر. الأكبر أسهل تصويرًا، ويُقصّ على عرض الورق.':
      'The side of the location QR square at the bottom of the invoice, in millimetres. Bigger is easier to scan, and it is trimmed to the paper width.',
  'لغة الطباعة · مقاسات الشعار ورمز QR · الطابعة الافتراضية · خطّ الطباعة · حفظ PDF':
      'Print language · Logo and QR sizes · Default printer · Print font · Save PDF',
};
