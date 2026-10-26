/// **بيانات ورقة المغسلة** — منطق خالص (بلا Flutter ولا قاعدة بيانات).
///
/// ورقة المغسلة هي **نسخة المحل** التي تُرفق بكيس الغسيل ليعرف العامل ما
/// فيه. لذلك لا تحمل أي مبلغ: لا سعر بند، ولا خصمًا، ولا ضريبة، ولا QR
/// ضريبيًا، ولا طريقة دفع. ولأنها لا تحمل أرقامًا مالية فهي آمنة للطبع
/// بجانب فاتورة العميل على أية طابعة.
///
/// ## لماذا ملف منفصل عن مولّد PDF؟
/// لأن بناء البيانات (تطبيع أسماء الأصناف · جمع القطع · اختيار اللغة) يمكن
/// اختباره بـ`flutter test` بلا توليد PDF، ولأن المولّد يعمل أحيانًا داخل
/// `compute` حيث لا تُقرأ حالة [L10n] العامة — فاللغة تُختم هنا في الخيط
/// الرئيسي ثم تُنقل كبيانات أوّلية.
library;

import 'package:laundry/services/i18n/l10n.dart';
import 'package:laundry/services/i18n/translations_en.dart';

/// بند واحد في ورقة المغسلة — بلا سعر.
class LaundrySlipItem {
  const LaundrySlipItem({
    required this.name,
    this.service = '',
    this.qty = 0,
    this.note = '',
  });

  /// اسم الصنف بلغة المستند.
  final String name;

  /// نوع الخدمة (غسيل · كوي · غسيل وكوي …).
  final String service;

  /// عدد القطع.
  final int qty;

  /// ملاحظة العامل على البند (بقعة · كسر زر …).
  final String note;

  bool get isEmpty => name.trim().isEmpty;

  Map<String, dynamic> toMap() => <String, dynamic>{
    'name': name,
    'service': service,
    'qty': qty,
    'note': note,
  };
}

/// ورقة مغسلة كاملة — بيانات عرض فقط.
class LaundrySlipData {
  const LaundrySlipData({
    required this.invoiceNumber,
    required this.date,
    required this.customerName,
    required this.customerPhone,
    required this.pickupCode,
    required this.bizName,
    required this.bizPhone,
    required this.items,
    required this.paperSize,
    required this.isRtl,
  });

  /// رقم الفاتورة **المعروض** (بادئة + حشو) لا المعرّف الداخلي وحده.
  final String invoiceNumber;

  /// التاريخ والوقت كما ظهرا على فاتورة العميل.
  final String date;

  final String customerName;
  final String customerPhone;
  final String pickupCode;

  final String bizName;
  final String bizPhone;

  /// البنود — بلا أسعار.
  final List<LaundrySlipItem> items;

  /// رمز مقاس الورق **نفسه** المستخدم للفاتورة (`invoice_paper_size`).
  final String paperSize;

  final bool isRtl;

  /// مجموع القطع (لا مجموع مالي).
  int get totalPieces => items.fold<int>(0, (sum, item) => sum + item.qty);

  /// عدد الأسطر (الأصناف) لا القطع.
  int get itemsCount => items.length;

  /// هل الورقة بلا بنود؟ (تُطبع ترويسة + بيانات الفاتورة فقط).
  bool get isEmpty => items.isEmpty;

  /// يبني الورقة من بنود الفاتورة بأيٍّ من الشكلين:
  ///   • بنود شاشة البيع (`vestments` · `count` · `price` …).
  ///   • لقطة `invoice_items` (`item_name` · `qty` · `note` …).
  ///
  /// [isRtl] يُمرَّر صريحًا لأن البناء قد يحدث قبل الدخول إلى `compute`.
  factory LaundrySlipData.fromItems({
    required List<Map<String, dynamic>> items,
    required String invoiceNumber,
    required String date,
    required String customerName,
    String customerPhone = '',
    String pickupCode = '',
    String bizName = '',
    String bizPhone = '',
    required String paperSize,
    required bool isRtl,
  }) {
    final rows = <LaundrySlipItem>[];
    for (final raw in items) {
      final item = _normalize(raw, isRtl: isRtl);
      if (item.isEmpty) continue;
      rows.add(item);
    }
    return LaundrySlipData(
      invoiceNumber: invoiceNumber.trim(),
      date: date.trim(),
      customerName: customerName.trim(),
      customerPhone: customerPhone.trim(),
      pickupCode: pickupCode.trim(),
      bizName: bizName.trim(),
      bizPhone: bizPhone.trim(),
      items: List<LaundrySlipItem>.unmodifiable(rows),
      paperSize: paperSize,
      isRtl: isRtl,
    );
  }

  /// يحوّل الورقة إلى حمولة مولّد PDF (أنواع أوّلية فقط).
  ///
  /// 🚨 **لا مفاتيح مالية هنا إطلاقًا** — وهذا مقصود ومختبَر: الورقة لا
  /// تُسلَّم للعميل، ولا يجوز أن تتسرّب إليها الأسعار أو الخصم أو الضريبة.
  Map<String, dynamic> toMap() => <String, dynamic>{
    'invoiceNumber': invoiceNumber,
    'date': date,
    'customerName': customerName,
    'customerPhone': customerPhone,
    'pickupCode': pickupCode,
    'bizName': bizName,
    'bizPhone': bizPhone,
    'items': items.map((item) => item.toMap()).toList(growable: false),
    'totalPieces': totalPieces,
    'itemsCount': itemsCount,
    'paperSize': paperSize,
    'docLang': isRtl ? 'ar' : 'en',
    if (!isRtl) 'docEnglish': kEnglish,
  };

  static LaundrySlipItem _normalize(
    Map<String, dynamic> raw, {
    required bool isRtl,
  }) {
    // لقطة `invoice_items` تحمل `item_name`، وبنود السلة تحمل `vestments`.
    final snapshot = raw.containsKey('item_name') && !raw.containsKey('vestments');
    final nameKey = snapshot ? 'item_name' : 'vestments';

    final name = localized(raw, nameKey, english: !isRtl).trim();
    final service = localized(raw, 'content', english: !isRtl).trim();
    final note = localized(raw, 'note', english: !isRtl).trim();

    final qtyRaw = snapshot ? raw['qty'] : raw['count'];
    final qty =
        int.tryParse('${qtyRaw ?? ''}') ??
        (double.tryParse('${qtyRaw ?? ''}')?.round() ?? 0);

    return LaundrySlipItem(
      name: name,
      service: service,
      qty: qty < 0 ? 0 : qty,
      note: note,
    );
  }
}
