import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:laundry/sqldb.dart';

class EditController extends GetxController {
  TextEditingController name = TextEditingController();
  TextEditingController washingprice = TextEditingController();
  TextEditingController urgentwashingprice = TextEditingController();
  TextEditingController ironingprice = TextEditingController();
  TextEditingController urgentironingprice = TextEditingController();

  moveValues(Map<String, dynamic> values) {
    name.text = values["clothing_name"];
    washingprice.text = values["normal_washing_and_ironing_price"].toString();
    urgentwashingprice.text =
        values["urgent_washing_and_ironing_price"].toString();
    ironingprice.text = values["normal_ironing_price"].toString();
    urgentironingprice.text = values["urgent_ironing_price"].toString();
  }

  updateCategory(int id) async {
    SqlDB db = SqlDB();
    int response = await db.updateData(
      "UPDATE clothing SET clothing_name = '${name.text}' ,normal_washing_and_ironing_price = ${double.parse(washingprice.text)},urgent_washing_and_ironing_price = ${double.parse(urgentwashingprice.text)},normal_ironing_price = ${double.parse(ironingprice.text)},urgent_ironing_price = ${double.parse(urgentironingprice.text)} WHERE clothing_id = $id",
    );
    if (response == 0) {
      messagefailer();
    } else {
      Get.back();
      messageSuccessfully();
      // await Future.delayed(Duration(seconds: 2),(){});
      
    }
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
