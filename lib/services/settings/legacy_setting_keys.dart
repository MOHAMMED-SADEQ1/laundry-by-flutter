/// مفاتيح إعداد **ورثها النظام من جيل سابق** ولم يبقَ لها أي قارئ.
///
/// **كيف أُثبت أنها ميتة؟** بمسح كل `lib/` عن كل مفتاح كنصّ حرفي: صفر نتيجة
/// للخمسين جميعًا (الحرس: `tool/verify_legacy_settings.py`). وهي ليست في
/// `SettingOptions.all` أيضًا، فلا تظهر في أي شاشة — أي أنها صفوف في جدول
/// `settings` لا يقرأها كود ولا يعرضها إعداد.
///
/// **لماذا تُحذف؟** لأن بقاءها يُضلّل الصيانة: من يفتح جدول `settings` يرى
/// 164 مفتاحًا ويظنّ أن `inv_show_logo` ما زال يتحكّم في الفاتورة، بينما
/// التحكّم الفعلي في `SettingOptions` بمفاتيح `invoice_show_*`. وأي «إصلاح»
/// يُكتب على المفتاح القديم لن يظهر له أثر — وهو أسوأ أنواع العيوب.
///
/// **الحذف محروس ومسجَّل:** `SqlDB._cleanupLegacySettings` ينسخ قيمها إلى
/// `audit_log` قبل حذفها، ويُنفَّذ مرة واحدة (`settings_cleanup_v1`)، فلا
/// يفقد المستخدم أثرًا حتى لو أراد استرجاع قيمة قديمة.
///
/// ⚠️ **لا تُضِف مفتاحًا هنا إلا بعد التأكد أنه بلا قارئ.** إضافة مفتاح حيّ
/// تحذفه من القاعدة وتُفقد إعدادًا يعمل.
library;

class LegacySettingKeys {
  LegacySettingKeys._();

  /// المفاتيح الميتة — مقسّمة بتعليقات لتسهيل المراجعة.
  static const List<String> all = <String>[
    // ─── إعدادات فاتورة من الجيل الأول (`inv_*`) — استُبدلت بـ`invoice_show_*`
    'inv_footer_text',
    'inv_terms_text',
    'inv_show_address_note',
    'inv_show_biz_address',
    'inv_show_biz_name',
    'inv_show_breakdown',
    'inv_show_contact_line',
    'inv_show_cr_number',
    'inv_show_customer',
    'inv_show_customer_phone',
    'inv_show_date',
    'inv_show_doc_title',
    'inv_show_e_invoice',
    'inv_show_footer_note',
    'inv_show_issued_by',
    'inv_show_item_detail',
    'inv_show_item_note',
    'inv_show_item_photo',
    'inv_show_items',
    'inv_show_location_qr',
    'inv_show_logo',
    'inv_show_payable',
    'inv_show_payment_method',
    'inv_show_pickup_code',
    'inv_show_pos_label',
    'inv_show_prices',
    'inv_show_qr',
    'inv_show_receipt_no',
    'inv_show_tax_number',
    'inv_show_terms',

    // ─── إعدادات طباعة من الجيل الأول (`print_*`) — استُبدلت بخيارات الطباعة
    'print_auto_open',
    'print_compact',
    'print_font_scale',
    'print_margin_mm',
    'print_output_mode',
    'print_paper_size',
    'print_printer_name',
    'print_show_dividers',

    // ─── سياسات بيع/ائتمان نُقلت إلى خيارات أخرى أو أُلغيت
    'allow_manual_discount',
    'allow_partial_payment',
    'auto_consume_credit',
    'cash_rounding',
    'confirm_invoice_delete',
    'credit_limit_enabled',
    'manual_discount_max_percent',
    'require_customer_name',
    'require_customer_phone',
    'require_open_shift',
    'show_customer_balance',

    // ─── نسخ قديمة من مفاتيح ما زالت حيّة بمفتاح آخر
    'subscription_warn_percent',
  ];

  /// للاستعمال في استعلام `IN (…)` — رموز `?` بعدد المفاتيح.
  static String get placeholders => List.filled(all.length, '?').join(',');

  static bool contains(String key) => all.contains(key);
}
