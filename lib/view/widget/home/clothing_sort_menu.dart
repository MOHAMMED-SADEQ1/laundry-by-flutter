// زرّ ترتيب الأصناف في شاشة البيع — واجهة فقط، والمنطق في
// `services/catalog/clothing_sort.dart` (السجلّ) و
// `controller/addeditcategorycontroller.dart` (الحفظ وإعادة الجلب).
//
// **لماذا ودجة منفصلة:** لتُختبَر وحدها. الزرّ داخل `_ItemsArea` لا يمكن
// اختباره إلا ببناء الشاشة الرئيسية كاملة (وردية · صلاحيات · قاعدة بيانات).
// وهنا يُثبت الاختبار أن **كل** أنماط السجلّ تُعرض فعلًا — وهو العيب الصامت
// المتوقّع: سجلّ فيه ثمانية أنماط وقائمة تعرض ثلاثة.

import 'package:flutter/material.dart';
import 'package:laundry/services/i18n/l10n.dart';
import 'package:get/get.dart';
import 'package:laundry/controller/addeditcategorycontroller.dart';
import 'package:laundry/core/theme/app_colors.dart';
import 'package:laundry/services/catalog/clothing_sort.dart';

/// زرّ يعرض الترتيب الحالي، ويفتح قائمة بكل الأنماط.
///
/// الاختيار يمرّ بـ[AddCategoryController.changeSort] — أي **يُحفظ في
/// الإعدادات ثم يُعاد الجلب من القاعدة**. لا فرز في الذاكرة هنا.
class ClothingSortMenu extends StatelessWidget {
  const ClothingSortMenu({super.key});

  /// مفاتيح قابلة للاختبار.
  static const Key menuKey = Key('clothing-sort-menu');

  /// مفتاح بند النمط داخل القائمة (`sort-item-name_asc` …).
  static Key itemKeyOf(String sortKey) => ValueKey<String>('sort-item-$sortKey');

  @override
  Widget build(BuildContext context) {
    // `Get.put` لا `Get.find`: الزرّ يُبنى قبل شبكة الأصناف في الشجرة، فقد
    // لا يكون المتحكّم مسجَّلًا بعد. و`put` على مسجَّل يُعيد نفسه (GetX لا
    // يستبدل إلا إذا كان `isDirty`) فلا تُفقد القائمة.
    final catController = Get.put(AddCategoryController());
    return Obx(() {
      final current = catController.sortMode.value;
      return PopupMenuButton<ClothingSort>(
        key: menuKey,
        tooltip: tr('ترتيب الأصناف'),
        position: PopupMenuPosition.under,
        onSelected: (next) => catController.changeSort(next),
        itemBuilder:
            (context) =>
                ClothingSort.all.map((s) {
                  final active = s.key == current.key;
                  return PopupMenuItem<ClothingSort>(
                    key: itemKeyOf(s.key),
                    value: s,
                    height: 46,
                    child: Row(
                      children: [
                        Icon(
                          active
                              ? Icons.radio_button_checked
                              : Icons.radio_button_unchecked,
                          size: 16,
                          color:
                              active ? AppColors.primary : AppColors.textMuted,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                tr(s.label),
                                style: TextStyle(
                                  fontFamily: 'cairo',
                                  fontSize: 12.5,
                                  fontWeight:
                                      active
                                          ? FontWeight.bold
                                          : FontWeight.w600,
                                  color:
                                      active
                                          ? AppColors.primary
                                          : AppColors.textPrimary,
                                ),
                              ),
                              Text(
                                tr(s.description),
                                style: const TextStyle(
                                  fontFamily: 'cairo',
                                  fontSize: 10,
                                  color: AppColors.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
        child: Container(
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: AppColors.surfaceSoft,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.sort, size: 17, color: AppColors.primary),
              const SizedBox(width: 6),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 120),
                child: Text(
                  tr(current.label),
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'cairo',
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              const Icon(
                Icons.arrow_drop_down,
                size: 18,
                color: AppColors.textSecondary,
              ),
            ],
          ),
        ),
      );
    });
  }
}
