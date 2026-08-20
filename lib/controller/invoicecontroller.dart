import 'package:flutter/material.dart';
import 'package:get/get.dart';

class InvoiceController extends GetxController {
  List<Map<String, dynamic>> invoice = [];
  TextEditingController customername = TextEditingController();
  RxDouble summation = 0.0.obs;

  String calcSummation() {
    summation.value = 0.00;
    for (int i = 0; i < invoice.length; i++) {
      summation.value = summation.value + invoice[i]["total_price"];
    }
    return summation.value.toString();
  }

  void removeItem(int index) {
    invoice.removeAt(index);
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

  deleteInvoice() {
    if (invoice.isNotEmpty) {
      invoice.clear();
      summation.value = 0.00;
      customername.clear();
      update();
    }
  }

  messageSuccessfully() {
    Get.snackbar(
      "نجاح العملية", // العنوان
      "تم حذف الفاتورة!", // الرسالة
      snackPosition: SnackPosition.BOTTOM, // تحديد موقع الـ Snackbar
      backgroundColor: Colors.green, // لون الخلفية
      colorText: Colors.white, // لون النص
      duration: Duration(seconds: 2), // مدة العرض
      icon: Icon(Icons.check_circle, color: Colors.white), // أيقونة
    );
  }
}
