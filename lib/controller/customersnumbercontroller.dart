import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:laundry/sqldb.dart';

class CustomersNumberController extends GetxController {
  TextEditingController neme = TextEditingController();
  TextEditingController number1 = TextEditingController();
  TextEditingController number2 = TextEditingController();
  @override
  void onInit() {
    // TODO: implement onInit
    super.onInit();
  }

  writeData() async {
    SqlDB db = SqlDB();
    int response = await db.insertData(
      "INSERT INTO 'numbers' ('customer_name','number_1','number_2') VALUES ('${neme.text}','${number1.text}','${number2.text}')",
    );
    if (response > 0) {
      neme.clear();
      number1.clear();
      number2.clear();
      Get.back();
      messageSuccessfully();
      update();
    } else {
      Get.back();
      messagefailer();
    }
  }

  Future<List<Map<String, dynamic>>> readData() async {
    SqlDB db = SqlDB();
    List<Map<String, dynamic>> response = await db.readData(
      'SELECT * FROM "numbers"',
    );
    print(response);
    return response;
  }

  messagefailer() {
    Get.snackbar(
      "فشل العملية", // العنوان
      "لم يتم تنفيذ العملية بنجاح!", // الرسالة
      snackPosition: SnackPosition.BOTTOM, // تحديد موقع الـ Snackbar
      backgroundColor: Colors.red, // لون الخلفية
      colorText: Colors.white, // لون النص
      duration: Duration(seconds: 3), // مدة العرض
      icon: Icon(Icons.close, color: Colors.white), // أيقونة
    );
  }

  delete(int id) async {
    SqlDB db = SqlDB();
    int response = await db.deleteData(
      "DELETE FROM 'numbers' WHERE numbers_id = $id",
    );
    if (response == 1) {
      messageSuccessfully();
    } else {
      messagefailer();
    }
  }

  messageSuccessfully() {
    Get.snackbar(
      "نجاح العملية", // العنوان
      "تم تنفيذ العملية بنجاح!", // الرسالة
      snackPosition: SnackPosition.BOTTOM, // تحديد موقع الـ Snackbar
      backgroundColor: Colors.green, // لون الخلفية
      colorText: Colors.white, // لون النص
      duration: Duration(seconds: 1), // مدة العرض
      icon: Icon(Icons.check_circle, color: Colors.white), // أيقونة
    );
  }
}
