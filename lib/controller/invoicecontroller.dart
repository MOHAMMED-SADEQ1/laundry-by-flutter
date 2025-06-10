import 'package:flutter/material.dart';
import 'package:get/get.dart';

class InvoiceController extends GetxController {
  List<Map<String, dynamic>> invoice = [];
  TextEditingController custmername = TextEditingController();
  double sumatiom = 0;

  String calcSumation() {
    sumatiom = 0.00;
    for (int i = 0; i < invoice.length; i++) {
      sumatiom = sumatiom + invoice[i]["total_price"];
    }
    return sumatiom.toString();
  }

  void removeItem(int index) {
    invoice.removeAt(index);
    Get.back();
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
      sumatiom = 0.00;
      custmername.clear();
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
