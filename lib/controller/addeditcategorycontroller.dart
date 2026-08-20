import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:laundry/sqldb.dart';

class AddCategoryController extends GetxController {
  TextEditingController neme = TextEditingController();
  TextEditingController washingprice = TextEditingController();
  TextEditingController urgentwashingprice = TextEditingController();
  TextEditingController ironingprice = TextEditingController();
  TextEditingController urgentironingprice = TextEditingController();

  writeData() async {
    SqlDB db = SqlDB();
    int response = await db.insertData(
      "INSERT INTO 'clothing' ('clothing_name','normal_washing_and_ironing_price','urgent_washing_and_ironing_price','normal_ironing_price','urgent_ironing_price') VALUES ('${neme.text}','${double.parse(washingprice.text)}','${double.parse(urgentwashingprice.text)}','${double.parse(ironingprice.text)}','${double.parse(urgentironingprice.text)}')",
    );
    if (response > 0) {
      neme.clear();
      washingprice.clear();
      urgentwashingprice.clear();
      ironingprice.clear();
      urgentironingprice.clear();
      Get.back();
      messageSuccessfully();
      update();
    } else {
      messagefailer();
    }
  }

  Future<List<Map<String, dynamic>>> readData() async {
    // sqfliteFfiInit();
    // databaseFactory = databaseFactoryFfi;
    SqlDB db = SqlDB();
    List<Map<String, dynamic>> response = await db.readData(
      'SELECT * FROM "clothing"',
    );
    // print(response);
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
      "DELETE FROM 'clothing' WHERE clothing_id = $id",
    );
    if (response == 1) {
      messageSuccessfully();
      update();
    } else {
      messagefailer();
      update();
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
