import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:laundry/controller/invoicecontroller.dart';


class ShowDialogController extends GetxController {
  int count = 1;
  // List<Map<String, dynamic>> invoice = [];
  Color normalwashingironing = Colors.white;
  Color urgentwashingironing = Colors.white;
  Color normalironing = Colors.white;
  Color urgentironing = Colors.white;
  String typerequest = "";
  final InvoiceController controllerinvoce = Get.put(InvoiceController());

  addTypeSelected(String type) {
    if (type == "normalwashingironing") {
      normalwashingironing = Colors.greenAccent;
      urgentwashingironing = Colors.white;
      normalironing = Colors.white;
      urgentironing = Colors.white;
    } else if (type == "urgentwashingironing") {
      normalwashingironing = Colors.white;
      urgentwashingironing = Colors.greenAccent;
      normalironing = Colors.white;
      urgentironing = Colors.white;
    } else if (type == "normalironing") {
      normalwashingironing = Colors.white;
      urgentwashingironing = Colors.white;
      normalironing = Colors.greenAccent;
      urgentironing = Colors.white;
    } else {
      normalwashingironing = Colors.white;
      urgentwashingironing = Colors.white;
      normalironing = Colors.white;
      urgentironing = Colors.greenAccent;
    }
    typerequest = type;
    update();
  }

  addWash(Map<String, dynamic> data) {
    if (typerequest == "normalwashingironing") {
      controllerinvoce.invoice.add({
        "vestments": data["clothing_name"],
        "content": "غسيل وكوي عادي",
        "count": count,
        "price": data["normal_washing_and_ironing_price"],
        "total_price": data["normal_washing_and_ironing_price"] * count,
      });
    } else if (typerequest == "urgentwashingironing") {
      controllerinvoce.invoice.add({
        "vestments": data["clothing_name"],
        "content": "غسيل وكوي مستعجل",
        "count": count,
        "price": data["urgent_washing_and_ironing_price"],
        "total_price": data["urgent_washing_and_ironing_price"] * count,
      });
    } else if (typerequest == "normalironing") {
      controllerinvoce.invoice.add({
        "vestments": data["clothing_name"],
        "content": "كوي عادي",
        "count": count,
        "price": data["normal_ironing_price"],
        "total_price": data["normal_ironing_price"] * count,
      });
    } else {
      controllerinvoce.invoice.add({
        "vestments": data["clothing_name"],
        "content": "كوي مستعجل",
        "count": count,
        "price": data["urgent_ironing_price"],
        "total_price": data["urgent_ironing_price"] * count,
      });
    }
    Get.back();
    controllerinvoce.update();
  }

  add() {
    count++;
    update();
  }

  remove() {
    if (count >= 2) {
      count--;
      update();
    }
  }

  @override
  void onInit() {
    super.onInit();
  }
}
