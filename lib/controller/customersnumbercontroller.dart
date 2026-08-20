import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:laundry/sqldb.dart';

class CustomersNumberController extends GetxController {
  TextEditingController neme = TextEditingController();
  TextEditingController number1 = TextEditingController();
  TextEditingController number2 = TextEditingController();

  writeData() async {
    if (neme.text.trim().isEmpty) {
      messagefailer();
      return;
    }
    SqlDB db = SqlDB();
    int response = await db.insertData(
      "INSERT INTO customers (customer_name, phone_1, phone_2, join_date) "
      "VALUES (?, ?, ?, ?)",
      [neme.text, number1.text, number2.text, DateTime.now().toIso8601String()],
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
      'SELECT * FROM customers WHERE is_active = 1 ORDER BY customer_name',
    );
    return response;
  }

  /// بحث فوري باقتراحات أسماء الزبائن حسب ما يُكتب
  Future<List<Map<String, dynamic>>> searchSuggestions(String query) async {
    if (query.trim().isEmpty) return [];
    SqlDB db = SqlDB();
    return db.safeRead(
      'customers',
      where: 'is_active = 1 AND customer_name LIKE ?',
      whereArgs: ['%${query.trim()}%'],
      orderBy: 'customer_name',
      limit: 6,
    );
  }

  messagefailer() {
    Get.snackbar(
      "فشل العملية",
      "لم يتم تنفيذ العملية بنجاح!",
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: Colors.red,
      colorText: Colors.white,
      duration: Duration(seconds: 3),
      icon: Icon(Icons.close, color: Colors.white),
    );
  }

  delete(int id) async {
    SqlDB db = SqlDB();
    int response = await db.updateData(
      "UPDATE customers SET is_active = 0 WHERE customer_id = ?",
      [id],
    );
    if (response == 1) {
      messageSuccessfully();
    } else {
      messagefailer();
    }
  }

  messageSuccessfully() {
    Get.snackbar(
      "نجاح العملية",
      "تم تنفيذ العملية بنجاح!",
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: Colors.green,
      colorText: Colors.white,
      duration: Duration(seconds: 1),
      icon: Icon(Icons.check_circle, color: Colors.white),
    );
  }
}
