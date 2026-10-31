import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:laundry/services/i18n/l10n.dart';
import 'package:laundry/services/invoice/invoice_lines.dart';

// أنواع النتيجة تعيش في طبقة المنطق (`invoice_lines.dart`) لأن القرار
// محاسبي لا واجهي؛ تُعاد تصديرها هنا حتى لا يعرف المستدعي مكانها.
export 'package:laundry/services/invoice/invoice_lines.dart'
    show LineAddOutcome, LineAddResult;

class InvoiceController extends GetxController {
  List<Map<String, dynamic>> invoice = [];
  TextEditingController customername = TextEditingController();
  RxDouble summation = 0.0.obs;

  /// إجمالي الفاتورة كرقم — **دالة خالصة لا تُعدّل أي حالة**.
  ///
  /// كانت تُعيد `summation` بعد كتابته داخلها، فتُستدعى من داخل `Obx`
  /// (أي أثناء البناء) فتكتب في متغيّر تفاعلي → إعادة بناء متزامنة أثناء
  /// البناء (خطأ GetX مؤجَّل + وميض/قفزة في الرقم).
  double totalValue() {
    var total = 0.0;
    for (final item in invoice) {
      total += InvoiceLines.lineTotal(item);
    }
    return InvoiceLines.money(total);
  }

  /// عدد القطع في الفاتورة — يُستدعى من حوار الدفع لفحص سقف الاشتراك.
  int piecesCount() {
    var pieces = 0;
    for (final item in invoice) {
      pieces += InvoiceLines.quantityOf(item);
    }
    return pieces;
  }

  /// يُعيد حساب المجموع ويُحدّث الحالة التفاعلية. تُستدعى **بعد** تعديل
  /// البنود فقط (إضافة/حذف/تغيير كمية)، لا من داخل `Obx`.
  String calcSummation() {
    refreshSummation();
    return summation.value.toString();
  }

  /// يُزامن `summation` مع البنود الفعلية.
  ///
  /// **مهم محاسبيًا:** `summation` حقل مخزَّن (cache) وكان لا يُحدَّث أبدًا،
  /// فكانت الفواتير تُحفظ بـ`total_price = 0` و`final_amount = 0` وتُطبع
  /// بصفر رغم أن الشاشة تعرض المجموع الصحيح (لأنها تحسبه لحظيًا). كل تعديل
  /// على البنود يمرّ من هنا، وكل قارئ للمجموع يقرأ `totalValue()` مباشرة.
  void refreshSummation() {
    summation.value = totalValue();
  }

  /// إضافة بند إلى الفاتورة — **الطريقة الوحيدة** المسموح بها للإضافة.
  ///
  /// 🚨 القاعدة المحاسبية: **لا سطرين متطابقين في فاتورة واحدة.** البند
  /// المطابق (صنف + خدمة + سعر + ملاحظة + صورة) تزيد كميته فقط. أما ما
  /// يختلف في الملاحظة/الصورة/السعر فيبقى سطرًا مستقلًّا **بسبب مُعلَن**
  /// (`LineAddOutcome`) حتى لا يظنّ الكاشير أن الدمج تعطّل.
  ///
  /// القرار نفسه في `InvoiceLines.applyAdd` — هنا الحالة فقط.
  LineAddResult addItem(Map<String, dynamic> item) {
    final apply = InvoiceLines.applyAdd(invoice, item);
    _replaceItems(apply.items);
    return apply.result;
  }

  /// تعديل بند قائم (كمية/سعر/خدمة/ملاحظة).
  ///
  /// بعد التعديل يُفحص التكرار من جديد: لو صار البند مطابقًا لبند آخر
  /// (مثلًا غُيّرت خدمته إلى خدمة موجودة بنفس السعر) يُدمجان في سطر واحد
  /// وتُحذف النسخة الزائدة — وإلا بقيت الفاتورة تحمل سطرين متطابقين من
  /// طريق آخر. الحدّ لا يُخترق من الباب الخلفي.
  LineAddResult updateItem(int index, Map<String, dynamic> updated) {
    final apply = InvoiceLines.applyUpdate(invoice, index, updated);
    _replaceItems(apply.items);
    return apply.result;
  }

  /// زيادة كمية بند — الزرّ «+» في سطر الفاتورة (بلا حوار).
  void increaseQuantity(int index, [int by = 1]) {
    if (index < 0 || index >= invoice.length) return;
    invoice[index] = InvoiceLines.withQuantity(
      invoice[index],
      InvoiceLines.quantityOf(invoice[index]) + by,
    );
    refreshSummation();
    update();
  }

  /// إنقاص كمية بند — يتوقّف عند ١؛ الحذف له زرّه المستقلّ بتأكيد.
  void decreaseQuantity(int index, [int by = 1]) {
    if (index < 0 || index >= invoice.length) return;
    final next = InvoiceLines.quantityOf(invoice[index]) - by;
    if (next < InvoiceLines.minQuantity) return;
    invoice[index] = InvoiceLines.withQuantity(invoice[index], next);
    refreshSummation();
    update();
  }

  /// تعيين كمية صريحة (من حوار التعديل).
  void setQuantity(int index, int quantity) {
    if (index < 0 || index >= invoice.length) return;
    invoice[index] = InvoiceLines.withQuantity(invoice[index], quantity);
    refreshSummation();
    update();
  }

  void removeItem(int index) {
    if (index < 0 || index >= invoice.length) return;
    invoice.removeAt(index);
    refreshSummation();
    update();
  }

  /// استبدال بنود الفاتورة كاملةً (استعادة مسودة/فاتورة سابقة).
  ///
  /// **لا دمج هنا مقصود**: المستند المستعاد صورة عمّا حُفظ، ودمج أسطره
  /// يُعيد كتابة الماضي بدل استنساخه.
  void setItems(List<Map<String, dynamic>> items) {
    _replaceItems(items);
  }

  /// يستبدل محتوى القائمة **في مكانه** ثم يُزامن المجموع.
  ///
  /// الاستبدال في المكان (`clear` + `addAll`) لا بإسناد قائمة جديدة: كل من
  /// يحمل مرجع `invoice` (حوار الدفع، الطباعة، المسودات) يبقى على القائمة
  /// الحيّة، فلا يعمل على نسخة قديمة بعد أول تعديل.
  void _replaceItems(List<Map<String, dynamic>> items) {
    invoice
      ..clear()
      ..addAll(items);
    refreshSummation();
    update();
  }

  //  findInvoiceNo() async {
  //   int counter = 0;
  //   SharedPreferences prefs = await SharedPreferences.getInstance();
  //   counter = await prefs.getInt("counterinvoice")!;
  //   counter++;
  //   await prefs.setInt("counterinvoice", counter);
  //   return counter;
  // }

  /// إلغاء الفاتورة بالكامل: تفريغ البنود والاسم والتصفير، ثم رسالة نجاح.
  void deleteInvoice() {
    invoice.clear();
    refreshSummation();
    customername.clear();
    update();
    messageSuccessfully();
  }

  messageSuccessfully() {
    Get.snackbar(
      tr('نجاح العملية'), // العنوان
      tr('تم إلغاء الفاتورة وحذف جميع بنودها!'), // الرسالة
      snackPosition: SnackPosition.BOTTOM, // تحديد موقع الـ Snackbar
      backgroundColor: Colors.green, // لون الخلفية
      colorText: Colors.white, // لون النص
      duration: const Duration(seconds: 2), // مدة العرض
      icon: const Icon(Icons.check_circle, color: Colors.white), // أيقونة
    );
  }
}
