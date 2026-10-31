import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:laundry/config/constants.dart';
import 'package:laundry/services/catalog/clothing_sort.dart';
import 'package:laundry/services/i18n/l10n.dart';
import 'package:laundry/services/settings/app_settings_service.dart';
import 'package:laundry/sqldb.dart';

/// أصناف اللبس: قراءة + إضافة + تحديث + حذف.
/// القائمة صارت حالة تفاعلية (RxList) بدل FutureBuilder في الواجهة،
/// حتى تنعكس الإضافة والتعديل والحذف فوراً في كل الشاشات بدون إعادة فتحها.
class AddCategoryController extends GetxController {
  TextEditingController neme = TextEditingController();

  /// الاسم الإنجليزي (اختياري). **الفراغ = يُعرض العربي** في الواجهة
  /// الإنجليزية، فلا يُجبَر المستخدم على ترجمة كتالوجه كله يوم التحديث.
  TextEditingController nameEn = TextEditingController();
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

  /// قائمة الأصناف النشطة — مشتركة بين شاشة إدارة الأصناف وشاشة البيع.
  /// كل صفّ يحمل الخدمات الأربع (غسيل/كوي · عادي/مستعجل) بأسعارها، فإعادة
  /// جلب الأصناف تُحدِّث «الأصناف والخدمات» معًا من استعلام واحد.
  final RxList<Map<String, dynamic>> clothing = <Map<String, dynamic>>[].obs;
  final RxBool isLoading = false.obs;

  /// صفوف قيد الحذف — يُعطَّل زرّها ويمنع تكرار الطلب أثناء تنفيذ الحذف.
  final RxSet<int> deletingIds = <int>{}.obs;

  /// رقم آخر جلب بدأ. نُطبّقه على الكتابة في القائمة كي لا يُطمِس جلب قديم
  /// نتيجةً أحدث منه (مثلاً: جلب بدأ قبل الإضافة وانتهى بعدها).
  int _loadToken = 0;

  /// الترتيب المعروض حاليًا — `Rx` لأن الواجهة تعرض اسمه وتتغيّر فورًا.
  /// القيمة المرجعية تبقى في `settings` (هذا انعكاس لها لا مصدر ثانٍ).
  final Rx<ClothingSort> sortMode = ClothingSort.byKey(null).obs;

  /// عدد أعمدة شبكة «الأصناف والخدمات» — صفر = تلقائي حسب عرض الشاشة.
  /// `Rx` لأن تغييره من زرّ الشاشة الرئيسية يجب أن يعيد بناء الشبكة فورًا.
  final RxInt gridColumns =
      AppSettingsService.instance.homeGridColumns.obs;

  @override
  void onInit() {
    super.onInit();
    loadClothing();
  }

  /// تحميل الأصناف من قاعدة البيانات إلى الحالة التفاعلية.
  ///
  /// **الفرز في القاعدة لا في الذاكرة** — انظر `services/catalog/clothing_sort.dart`
  /// لسبب ذلك (ترتيب الإدخال يضيع بعد أول فرز في الذاكرة، و«الأكثر مبيعًا»
  /// يحتاج تجميعًا لا يمكن في الواجهة).
  Future<void> loadClothing() async {
    // كل نداء يحمل رقمًا أحدث. عمليّة قراءة بدأت قبل كتابة (إضافة/تعديل/حذف)
    // قد تنتهي بعدها؛ لو كتبت نتيجتها في القائمة لأعادت عرض بيانات قديمة.
    // لذلك **آخر جلب بدأ هو وحده من يكتب**، والجلب الذي يلي الكتابة يفوز.
    final token = ++_loadToken;
    isLoading.value = true;
    // قراءة واحدة للنمط: تُعرض وتُستعلَم بها القاعدة، فلا يختلف الاثنان لو
    // تغيّر الإعداد بين السطرين.
    final current = sort;
    sortMode.value = current;
    try {
      final rows = await _db.readData(current.query);
      if (token == _loadToken) {
        clothing.assignAll(rows);
      }
    } catch (e) {
      debugPrint('loadClothing error: $e');
    } finally {
      if (token == _loadToken) {
        isLoading.value = false;
      }
    }
  }

  /// الترتيب الحالي — يُقرأ من الإعدادات في كل تحميل (مصدر واحد).
  ClothingSort get sort => AppSettingsService.instance.clothingSort;

  /// تغيير الترتيب: يُحفظ في `settings` ثم **يُعاد الجلب من القاعدة**.
  ///
  /// إعادة الجلب إلزامية وليست ترفًا: الترتيب في `ORDER BY` لا في الذاكرة،
  /// فترتيب القائمة الحالية في الذاكرة لا يُغني عنه.
  Future<void> changeSort(ClothingSort next) async {
    if (next.key == sort.key) return;
    try {
      // الحفظ قبل الجلب: لو فشل الحفظ لا نعرض ترتيبًا لا يطابق الإعدادات.
      await AppSettingsService.instance.set(
        AppConstants.settingClothingSort,
        next.key,
      );
      await loadClothing();
    } catch (e) {
      debugPrint('changeSort error: $e');
      messagefailer(tr('تعذّر حفظ ترتيب الأصناف'));
    }
  }

  /// تغيير عدد أعمدة الشبكة من الشاشة الرئيسية.
  ///
  /// الحفظ **قبل** تحديث الحالة: لو فشل الحفظ لا نعرض عددًا لا يطابق الإعداد.
  /// لا إعادة جلب — الأعمدة تخطيط واجهة لا استعلام قاعدة.
  Future<void> changeGridColumns(int columns) async {
    final safe = columns <= 0 ? 0 : columns.clamp(2, 6).toInt();
    if (safe == gridColumns.value) return;
    try {
      await AppSettingsService.instance.set(
        AppConstants.settingHomeGridColumns,
        safe == 0 ? 'auto' : '$safe',
      );
      gridColumns.value = safe;
    } catch (e) {
      debugPrint('changeGridColumns error: $e');
      messagefailer(tr('تعذّر حفظ عدد الأعمدة'));
    }
  }

  /// إنشاء صنف لبس جديد
  Future<bool> writeData() async {
    if (neme.text.trim().isEmpty) {
      messagefailer(tr('اكتب اسم اللبس أولاً'));
      return false;
    }
    try {
      final cost = double.tryParse(costprice.text.trim()) ?? 0;
      if (cost < 0) {
        messagefailer(tr('تكلفة القطعة لا يمكن أن تكون سالبة'));
        return false;
      }
      final response = await _db.safeInsert('clothing', {
        'clothing_name': neme.text.trim(),
        // يُخزَّن `NULL` عند الفراغ لا `''`: الفرق مهم — `''` تعني «مترجم
        // إلى فراغ» و`NULL` تعني «لا ترجمة» فيسقط العرض للعربية.
        'clothing_name_en':
            nameEn.text.trim().isEmpty ? null : nameEn.text.trim(),
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
        nameEn.clear();
        washingprice.clear();
        urgentwashingprice.clear();
        ironingprice.clear();
        urgentironingprice.clear();
        costprice.clear();
        await loadClothing();
        messageSuccessfully(tr('تمت إضافة الصنف بنجاح'));
        return true;
      }
      messagefailer(tr('لم يتم تنفيذ العملية بنجاح!'));
      return false;
    } catch (e) {
      debugPrint('writeData error: $e');
      messagefailer(trf('تعذر إضافة الصنف: {0}', [e]));
      return false;
    }
  }

  /// الأصناف النشطة فقط — القائمة الكاملة تُستخدم في إدارة الأصناف.
  /// (كان `readData()` بلا أي فلتر وهو مصدر ثانٍ متناقض مع `loadClothing`.)
  /// يستخدم **الاستعلام نفسه** لا ترتيبًا ثانيًا مكتوبًا يدويًا.
  Future<List<Map<String, dynamic>>> readData() async {
    return _db.readData(sort.query);
  }

  /// حذف صنف — يُنفَّذ كحذف ناعم (is_active = 0) للحفاظ على تاريخ الفواتير.
  ///
  /// **يعيد `true` فقط بعد إعادة الجلب**، فينتظر المستدعي اكتمال تحديث
  /// القائمة قبل عرض أي نتيجة، ولا يبقى `Future` معلّقًا في الخلفية.
  Future<bool> delete(int id) async {
    if (deletingIds.contains(id)) return false;
    deletingIds.add(id);
    try {
      final response = await _db.updateData(
        'UPDATE "clothing" SET is_active = 0 WHERE clothing_id = ?',
        [id],
      );
      if (response > 0) {
        await loadClothing();
        messageSuccessfully(tr('تم حذف الصنف بنجاح'));
        return true;
      }
      messagefailer(tr('تعذر حذف الصنف'));
      return false;
    } catch (e) {
      debugPrint('delete clothing error: $e');
      messagefailer(trf('تعذر حذف الصنف: {0}', [e]));
      return false;
    } finally {
      deletingIds.remove(id);
    }
  }

  void messagefailer([String? message]) {
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

  void messageSuccessfully([String? message]) {
    Get.snackbar(
      tr('نجاح العملية'),
      message ?? tr('تم تنفيذ العملية بنجاح!'),
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: Colors.green,
      colorText: Colors.white,
      duration: const Duration(seconds: 2),
      icon: const Icon(Icons.check_circle, color: Colors.white),
    );
  }
}
