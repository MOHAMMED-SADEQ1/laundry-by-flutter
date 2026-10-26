import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:laundry/controller/addeditcategorycontroller.dart';
import 'package:laundry/services/i18n/l10n.dart';
import 'package:laundry/sqldb.dart';

/// تعديل صنف لبس قائم.
///
/// **إصلاحان جوهريان:**
/// 1. كان يبني جملة SQL بـ string interpolation — أي اسم صنف يحتوي `'` كان
///    يكسر الجملة (ويفتح باب حقن). الآن معاملات `?` بالكامل.
/// 2. كان `double.parse(...)` يرمي استثناءً على حقل فارغ فيفشل التعديل بلا
///    رسالة مفهومة. الآن `tryParse` مع صفر افتراضي.
/// 3. كان **لا يُحدّث `cost_price`** — فتكلفة الصنف تبقى صفرًا إلى الأبد
///    وكل تقارير الربح وهمية. أُضيف الحقل إلى التعديل والإضافة معًا.
class EditController extends GetxController {
  TextEditingController name = TextEditingController();
  TextEditingController nameEn = TextEditingController();
  TextEditingController washingprice = TextEditingController();
  TextEditingController urgentwashingprice = TextEditingController();
  TextEditingController ironingprice = TextEditingController();
  TextEditingController urgentironingprice = TextEditingController();
  TextEditingController costprice = TextEditingController();

  /// التكلفة القديمة — تُحفظ لعرضها في سجل التدقيق عند التغيير
  double _oldCost = 0;

  moveValues(Map<String, dynamic> values) {
    name.text = values["clothing_name"];
    nameEn.text = '${values["clothing_name_en"] ?? ''}';
    washingprice.text = values["normal_washing_and_ironing_price"].toString();
    urgentwashingprice.text =
        values["urgent_washing_and_ironing_price"].toString();
    ironingprice.text = values["normal_ironing_price"].toString();
    urgentironingprice.text = values["urgent_ironing_price"].toString();
    _oldCost = double.tryParse('${values["cost_price"] ?? 0}') ?? 0;
    costprice.text = _oldCost == 0 ? '' : _oldCost.toString();
  }

  Future<bool> updateCategory(int id) async {
    if (name.text.trim().isEmpty) {
      messagefailer(tr('اكتب اسم اللبس أولاً'));
      return false;
    }
    SqlDB db = SqlDB();
    final newCost = double.tryParse(costprice.text.trim()) ?? 0;
    if (newCost < 0) {
      messagefailer(tr('تكلفة القطعة لا يمكن أن تكون سالبة'));
      return false;
    }
    try {
      int response = await db.updateData(
        'UPDATE "clothing" SET "clothing_name" = ?, "clothing_name_en" = ?, "normal_washing_and_ironing_price" = ?, "urgent_washing_and_ironing_price" = ?, "normal_ironing_price" = ?, "urgent_ironing_price" = ?, "cost_price" = ? WHERE "clothing_id" = ?',
        [
          name.text.trim(),
          nameEn.text.trim().isEmpty ? null : nameEn.text.trim(),
          double.tryParse(washingprice.text.trim()) ?? 0,
          double.tryParse(urgentwashingprice.text.trim()) ?? 0,
          double.tryParse(ironingprice.text.trim()) ?? 0,
          double.tryParse(urgentironingprice.text.trim()) ?? 0,
          newCost,
          id,
        ],
      );
      if (response == 0) {
        messagefailer(tr('لم يتم تنفيذ العملية بنجاح!'));
        return false;
      }
      // الإغلاق مسؤولية الواجهة: `Get.back()` هنا كان قد يغلق رسالة snackbar
      // سابقة ويترك شاشة التعديل مفتوحة. نحدّث القائمة المشتركة أولًا حتى يرى
      // المستخدم القيم الجديدة فور رجوعه.
      if (Get.isRegistered<AddCategoryController>()) {
        await Get.find<AddCategoryController>().loadClothing();
      }
      messageSuccessfully();
      return true;
    } catch (e) {
      debugPrint('updateCategory error: $e');
      messagefailer(trf('تعذر تعديل الصنف: {0}', [e]));
      return false;
    }
  }

  messagefailer([String? message]) {
    Get.snackbar(
      tr('فشل العملية'),
      message ?? tr('لم يتم تنفيذ العملية بنجاح!'),
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: Colors.red,
      colorText: Colors.white,
      duration: const Duration(seconds: 3),
      icon: const Icon(Icons.close, color: Colors.white),
    );
  }

  messageSuccessfully() {
    Get.snackbar(
      tr('نجاح العملية'),
      tr('تم تنفيذ العملية بنجاح!'),
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: Colors.green,
      colorText: Colors.white,
      duration: const Duration(seconds: 1),
      icon: const Icon(Icons.check_circle, color: Colors.white),
    );
  }
}
