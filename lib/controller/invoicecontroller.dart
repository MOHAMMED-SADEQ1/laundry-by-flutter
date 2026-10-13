import 'package:flutter/material.dart';
import 'package:get/get.dart';

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
      total += (item['total_price'] as num?)?.toDouble() ?? 0.0;
    }
    return total;
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

  /// إضافة بند إلى الفاتورة — الطريقة الوحيدة المسموح بها للإضافة،
  /// حتى يبقى المجموع متزامنًا دائمًا مع البنود.
  void addItem(Map<String, dynamic> item) {
    invoice.add(item);
    refreshSummation();
    update();
  }

  void removeItem(int index) {
    invoice.removeAt(index);
    refreshSummation();
    update();
  }

  /// استبدال بنود الفاتورة كاملةً (استعادة مسودة/فاتورة سابقة).
  void setItems(List<Map<String, dynamic>> items) {
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
      "نجاح العملية", // العنوان
      "تم إلغاء الفاتورة وحذف جميع بنودها!", // الرسالة
      snackPosition: SnackPosition.BOTTOM, // تحديد موقع الـ Snackbar
      backgroundColor: Colors.green, // لون الخلفية
      colorText: Colors.white, // لون النص
      duration: Duration(seconds: 2), // مدة العرض
      icon: Icon(Icons.check_circle, color: Colors.white), // أيقونة
    );
  }
}
