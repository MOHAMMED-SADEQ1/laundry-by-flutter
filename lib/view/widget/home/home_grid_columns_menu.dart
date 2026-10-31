// زرّ عدد أعمدة شبكة «الأصناف والخدمات» في الشاشة الرئيسية.
//
// **لماذا ودجة منفصلة:** لتُختبَر بلا بناء الشاشة كاملة (وردية · صلاحيات ·
// قاعدة بيانات)، وليلتزم الزرّ والقائمة والإعداد بسجلّ `SettingOptions`
// الواحد: أي خيار جديد يظهر هنا تلقائيًا بدل قائمة مكتوبة يدويًا.

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:laundry/controller/addeditcategorycontroller.dart';
import 'package:laundry/core/theme/app_colors.dart';
import 'package:laundry/services/i18n/l10n.dart';
import 'package:laundry/services/settings/setting_option.dart';

/// زرّ يعرض عدد الأعمدة الحالي ويفتح قائمة بالخيارات («تلقائي» · 2..6).
///
/// الاختيار يمرّ بـ[AddCategoryController.changeGridColumns] — أي **يُحفظ في
/// الإعدادات ثم يتحدّث `gridColumns`** فتُعاد بناء الشبكة فورًا.
class HomeGridColumnsMenu extends StatelessWidget {
  const HomeGridColumnsMenu({super.key});

  /// مفتاح قابل للاختبار.
  static const Key menuKey = Key('home-grid-columns-menu');

  /// مفتاح بند القيمة داخل القائمة (`grid-columns-auto` · `grid-columns-4` …).
  static Key itemKeyOf(String value) =>
      ValueKey<String>('grid-columns-$value');

  @override
  Widget build(BuildContext context) {
    // `Get.put` لا `Get.find` مثل `ClothingSortMenu`: قد يُبنى الزرّ قبل
    // تسجيل المتحكّم. لكن الفحص قبله يمنع بناء متحكّم جديد يُهمَل في كل
    // إعادة بناء (وهو ما يحدث لو نُودي `put(dependency)` على مسجَّل).
    final catController =
        Get.isRegistered<AddCategoryController>()
            ? Get.find<AddCategoryController>()
            : Get.put(AddCategoryController());
    final option = SettingOptions.homeGridColumns;

    return Obx(() {
      final current = catController.gridColumns.value;
      return PopupMenuButton<int>(
        key: menuKey,
        tooltip: tr('عدد الأعمدة'),
        position: PopupMenuPosition.under,
        onSelected: catController.changeGridColumns,
        itemBuilder:
            (context) => (option.choices ?? const <String>[])
                .map((value) {
                  final columns = value == 'auto' ? 0 : int.tryParse(value) ?? 0;
                  final active = columns == current;
                  return PopupMenuItem<int>(
                    key: itemKeyOf(value),
                    value: columns,
                    height: 42,
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
                        Text(
                          option.labelOfChoice(value),
                          style: TextStyle(
                            fontFamily: 'cairo',
                            fontSize: 12.5,
                            fontWeight:
                                active ? FontWeight.bold : FontWeight.w600,
                            color:
                                active
                                    ? AppColors.primary
                                    : AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  );
                })
                .toList(),
        child: Container(
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 9),
          decoration: BoxDecoration(
            color: AppColors.surfaceSoft,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.grid_view_rounded,
                size: 17,
                color: AppColors.primary,
              ),
              const SizedBox(width: 5),
              Text(
                current == 0 ? tr('تلقائي') : '$current',
                style: const TextStyle(
                  fontFamily: 'cairo',
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
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
