import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:laundry/controller/invoicecontroller.dart';
import 'package:laundry/core/theme/app_colors.dart';
import 'package:laundry/services/i18n/l10n.dart';
import 'package:laundry/services/invoice/invoice_lines.dart';
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
      "vestments_en": data["clothing_name_en"],
      "content": content,
      "count": count,
      "price": InvoiceLines.money(price),
      "total_price": InvoiceLines.money(InvoiceLines.money(price) * count),
    };
    if (note.trim().isNotEmpty) item["note"] = note.trim();
    if (photoPath.isNotEmpty) item["photo"] = photoPath;
    note = "";
    photoPath = "";
    photoPreview.value = '';
    count = 1;
    Get.back();
    // `addItem` تُضيف البند **أو تزيد كمية بند مطابق**، وتُزامن المجموع
    // دائمًا، فلا يُحفظ صفرًا. النتيجة تُعرَض للمستخدم حتى يعرف أن الضغط
    // لم يُهمَل وأن الكمية زادت لا أن سطرًا جديدًا أُضيف.
    _announce(controllerinvoce.addItem(item));
  }

  /// يُخبر المستخدم بما حدث فعلًا — **بلا فشل صامت**.
  ///
  /// أهمّها حالة الدمج: بلا رسالة يظنّ الكاشير أن الضغط لم يُسجَّل فيضغط
  /// مرّتين فتُضاف كمية زائدة. وحالات الفصل تُعلَن بسببه (ملاحظة/صورة/سعر)
  /// حتى لا يبدو الدمج معطوبًا.
  void _announce(LineAddResult result) {
    final name = localizedText(result.name, result.nameEn);
    final service = tr(result.service);
    switch (result.outcome) {
      case LineAddOutcome.added:
        return; // الإضافة العادية صامتة كالسابق — لا ضجيج بلا سبب
      case LineAddOutcome.merged:
        Get.snackbar(
          tr('زيادة الكمية'),
          trf('{0} — {1}: الكمية في الفاتورة صارت {2}', [
            name,
            service,
            '${result.quantity}',
          ]),
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: AppColors.success,
          colorText: Colors.white,
          duration: const Duration(seconds: 2),
          icon: const Icon(Icons.add_circle, color: Colors.white),
        );
      case LineAddOutcome.mergedByEdit:
        return; // التعديل يُبلّغ عنه حواره
      case LineAddOutcome.separateByNote:
        _separate(
          tr('أُضيف كبند منفصل'),
          trf('{0} — {1}: الملاحظة مختلفة عن البند الموجود، فبقيا سطرين.', [
            name,
            service,
          ]),
        );
      case LineAddOutcome.separateByPhoto:
        _separate(
          tr('أُضيف كبند منفصل'),
          trf('{0} — {1}: صورة البقعة مختلفة، فبقيا سطرين.', [name, service]),
        );
      case LineAddOutcome.separateByPrice:
        _separate(
          tr('أُضيف كبند منفصل'),
          trf('{0} — {1}: سعر الوحدة مختلف عن البند الموجود.', [name, service]),
        );
    }
  }

  void _separate(String title, String message) {
    Get.snackbar(
      title,
      message,
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: AppColors.warning,
      colorText: Colors.white,
      duration: const Duration(seconds: 4),
      icon: const Icon(Icons.info_outline, color: Colors.white),
    );
  }

  /// إضافة البند بالخدمة المختارة — التسمية والسعر من `ServiceKind` وحده.
  addWash(Map<String, dynamic> data) {
    final label = ServiceKind.keyToLabel[typerequest];
    if (label == null) return; // لا خدمة مختارة — الزرّ مخفي أصلًا في هذه الحالة
    _addToInvoice(data, label, data[ServiceKind.priceColumn(label)]);
  }

  /// كم قطعة من هذه الخدمة لهذا الصنف موجودة في الفاتورة الآن؟
  /// يُعرض في بطاقة الخدمة داخل الحوار («في الفاتورة: 3») قبل الضغط.
  int quantityInInvoice(Map<String, dynamic> data, String type) {
    final label = ServiceKind.keyToLabel[type];
    if (label == null) return 0;
    return InvoiceLines.quantityOfService(
      controllerinvoce.invoice,
      name: data['clothing_name'],
      service: label,
    );
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
