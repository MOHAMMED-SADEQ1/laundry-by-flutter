import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:laundry/sqldb.dart';

/// أصناف اللبس: قراءة + إضافة + تحديث + حذف.
/// القائمة صارت حالة تفاعلية (RxList) بدل FutureBuilder في الواجهة،
/// حتى تنعكس الإضافة والتعديل والحذف فوراً في كل الشاشات بدون إعادة فتحها.
class AddCategoryController extends GetxController {
  TextEditingController neme = TextEditingController();
  TextEditingController washingprice = TextEditingController();
  TextEditingController urgentwashingprice = TextEditingController();
  TextEditingController ironingprice = TextEditingController();
  TextEditingController urgentironingprice = TextEditingController();

  /// تكلفة القطعة الواحدة (مواد + تشغيل) — **إلزامية لحساب الربح**.
  /// كانت هذا الحقل غائبًا تمامًا: `clothing.cost_price` كان يُقرأ في أربعة
  /// مواضع (تكلفة اليوم، تكلفة الفترة، تقارير الربح، ربحية المشتركين) ولا
  /// يُكتب في أي مكان، فكانت كل التكاليف **صفرًا** و«صافي الربح» = المبيعات.
  TextEditingController costprice = TextEditingController();

  final SqlDB _db = SqlDB();

  /// قائمة الأصناف النشطة — مشتركة بين شاشة إدارة الأصناف وشاشة البيع
  final RxList<Map<String, dynamic>> clothing = <Map<String, dynamic>>[].obs;
  final RxBool isLoading = false.obs;

  @override
  void onInit() {
    super.onInit();
    loadClothing();
  }

  /// تحميل الأصناف من قاعدة البيانات إلى الحالة التفاعلية
  Future<void> loadClothing() async {
    isLoading.value = true;
    try {
      final rows = await _db.readData(
        'SELECT * FROM "clothing" WHERE is_active = 1 ORDER BY clothing_name',
      );
      clothing.assignAll(rows);
    } catch (e) {
      debugPrint('loadClothing error: $e');
    } finally {
      isLoading.value = false;
    }
  }

  /// إنشاء صنف لبس جديد
  Future<bool> writeData() async {
    if (neme.text.trim().isEmpty) {
      messagefailer('اكتب اسم اللبس أولاً');
      return false;
    }
    try {
      final cost = double.tryParse(costprice.text.trim()) ?? 0;
      if (cost < 0) {
        messagefailer('تكلفة القطعة لا يمكن أن تكون سالبة');
        return false;
      }
      final response = await _db.safeInsert('clothing', {
        'clothing_name': neme.text.trim(),
        'normal_washing_and_ironing_price':
            double.tryParse(washingprice.text.trim()) ?? 0,
        'urgent_washing_and_ironing_price':
            double.tryParse(urgentwashingprice.text.trim()) ?? 0,
        'normal_ironing_price': double.tryParse(ironingprice.text.trim()) ?? 0,
        'urgent_ironing_price':
            double.tryParse(urgentironingprice.text.trim()) ?? 0,
        // التكلفة: بدونها تبقى كل تقارير الربح صفرًا (العمود كان ميتًا)
        'cost_price': cost,
      });
      if (response > 0) {
        neme.clear();
        washingprice.clear();
        urgentwashingprice.clear();
        ironingprice.clear();
        urgentironingprice.clear();
        costprice.clear();
        await loadClothing();
        messageSuccessfully('تمت إضافة الصنف بنجاح');
        return true;
      }
      messagefailer('لم يتم تنفيذ العملية بنجاح!');
      return false;
    } catch (e) {
      debugPrint('writeData error: $e');
      messagefailer('تعذر إضافة الصنف: $e');
      return false;
    }
  }

  /// الأصناف النشطة فقط — القائمة الكاملة تُستخدم في إدارة الأصناف.
  /// (كان `readData()` بلا أي فلتر وهو مصدر ثانٍ متناقض مع `loadClothing`.)
  Future<List<Map<String, dynamic>>> readData() async {
    return _db.readData(
      'SELECT * FROM "clothing" WHERE is_active = 1 ORDER BY clothing_name',
    );
  }

  /// حذف صنف — يُنفَّذ كحذف ناعم (is_active = 0) للحفاظ على تاريخ الفواتير
  Future<void> delete(int id) async {
    final response = await _db.updateData(
      'UPDATE "clothing" SET is_active = 0 WHERE clothing_id = ?',
      [id],
    );
    if (response > 0) {
      await loadClothing();
      messageSuccessfully('تم حذف الصنف بنجاح');
    } else {
      messagefailer('تعذر حذف الصنف');
    }
  }

  void messagefailer([String message = 'لم يتم تنفيذ العملية بنجاح!']) {
    Get.snackbar(
      'فشل العملية',
      message,
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: Colors.red,
      colorText: Colors.white,
      duration: const Duration(seconds: 3),
      icon: const Icon(Icons.close, color: Colors.white),
    );
  }

  void messageSuccessfully([String message = 'تم تنفيذ العملية بنجاح!']) {
    Get.snackbar(
      'نجاح العملية',
      message,
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: Colors.green,
      colorText: Colors.white,
      duration: const Duration(seconds: 2),
      icon: const Icon(Icons.check_circle, color: Colors.white),
    );
  }
}
