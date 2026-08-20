import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:laundry/controller/invoicecontroller.dart';
import 'package:laundry/core/theme/app_colors.dart';
import 'package:path_provider/path_provider.dart';

class ShowDialogController extends GetxController {
  int count = 1;
  String note = "";
  // List<Map<String, dynamic>> invoice = [];
  Color normalwashingironing = Colors.white;
  Color urgentwashingironing = Colors.white;
  Color normalironing = Colors.white;
  Color urgentironing = Colors.white;
  String typerequest = "";
  final InvoiceController controllerinvoce = Get.put(InvoiceController());

  setNote(String value) {
    note = value;
    update();
  }

  String photoPath = "";
  final RxString photoPreview = ''.obs;

  /// اختيار صورة البقعة وحفظ نسخة دائمة في مجلد التطبيق
  Future<void> pickPhoto() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );
      if (result == null || result.files.isEmpty) return;
      final source = result.files.single.path;
      if (source == null || source.isEmpty) return;

      final dir = await getApplicationDocumentsDirectory();
      final stainsDir = Directory('${dir.path}/stain_photos');
      if (!await stainsDir.exists()) await stainsDir.create(recursive: true);
      final ext = source.split('.').last.toLowerCase();
      final dest =
          '${stainsDir.path}/stain_${DateTime.now().millisecondsSinceEpoch}.$ext';
      await File(source).copy(dest);

      photoPath = dest;
      photoPreview.value = dest;
      update();
    } catch (e) {
      debugPrint('pickPhoto error: $e');
      Get.snackbar(
        'خطأ',
        'تعذر اختيار الصورة',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppColors.danger,
        colorText: Colors.white,
      );
    }
  }

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

  _addToInvoice(Map<String, dynamic> data, String content, dynamic price) {
    final item = <String, dynamic>{
      "vestments": data["clothing_name"],
      "content": content,
      "count": count,
      "price": price,
      "total_price": price * count,
    };
    if (note.trim().isNotEmpty) item["note"] = note.trim();
    if (photoPath.isNotEmpty) item["photo"] = photoPath;
    controllerinvoce.invoice.add(item);
    note = "";
    photoPath = "";
    photoPreview.value = '';
    Get.back();
    controllerinvoce.update();
  }

  addWash(Map<String, dynamic> data) {
    if (typerequest == "normalwashingironing") {
      _addToInvoice(
        data,
        "غسيل وكوي عادي",
        data["normal_washing_and_ironing_price"],
      );
    } else if (typerequest == "urgentwashingironing") {
      _addToInvoice(
        data,
        "غسيل وكوي مستعجل",
        data["urgent_washing_and_ironing_price"],
      );
    } else if (typerequest == "normalironing") {
      _addToInvoice(data, "كوي عادي", data["normal_ironing_price"]);
    } else {
      _addToInvoice(data, "كوي مستعجل", data["urgent_ironing_price"]);
    }
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
}
