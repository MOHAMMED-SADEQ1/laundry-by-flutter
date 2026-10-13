import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:laundry/controller/addeditcategorycontroller.dart';
import 'package:laundry/core/theme/app_colors.dart';
import 'package:laundry/view/screen/deletecategory.dart';
import 'package:laundry/view/widget/customtextformfield.dart';

/// جدول الأصناف التفاعلي — يقرأ من الحالة التفاعلية في المتحكم،
/// فيتحدّث تلقائياً بعد أي إضافة أو تعديل أسعار أو حذف.
class CustomViewCategory extends StatelessWidget {
  const CustomViewCategory({super.key});

  @override
  Widget build(BuildContext context) {
    //نعيد تحميل الأصناف عند فتح الشاشة (مؤجّلاً لما بعد أول إطار حتى لا
    //نعدّل حالة تفاعلية أثناء البناء)، ثم تتحدّث تلقائياً بعد أي تعديل
    final controller = Get.put(AddCategoryController());
    if (controller.clothing.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        controller.loadClothing();
      });
    }

    return Obx(() {
      if (controller.isLoading.value && controller.clothing.isEmpty) {
        return const Center(child: CircularProgressIndicator(strokeWidth: 2.5));
      }
      final items = controller.clothing;
      if (items.isEmpty) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.inventory_2_outlined, size: 56, color: AppColors.border),
              const SizedBox(height: 10),
              Text(
                'لا توجد أصناف بعد',
                style: TextStyle(
                  fontFamily: 'cairo',
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'أضف أصنافاً من شاشة إضافة لبس',
                style: TextStyle(
                  fontFamily: 'cairo',
                  fontSize: 12,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
        );
      }
      return ListView.builder(
        itemCount: items.length,
        itemBuilder: (context, i) {
          final data = items[i];
          final isEven = i.isEven;
          return Container(
            decoration: BoxDecoration(
              color: isEven ? Colors.white : AppColors.surfaceSoft,
              border: Border(bottom: BorderSide(color: AppColors.border)),
            ),
            child: Row(
              children: [
                CustomEditDeleteExpanded(data: data),
                CustomExpanded(
                  lable: '${data['urgent_ironing_price'] ?? 0}',
                  border: 1,
                ),
                CustomExpanded(
                  lable: '${data['normal_ironing_price'] ?? 0}',
                  border: 1,
                ),
                CustomExpanded(
                  lable: '${data['urgent_washing_and_ironing_price'] ?? 0}',
                  border: 1,
                ),
                CustomExpanded(
                  lable: '${data['normal_washing_and_ironing_price'] ?? 0}',
                  border: 1,
                ),
                CustomExpanded(
                  lable: '${data['clothing_name'] ?? ''}',
                  border: 0,
                ),
              ],
            ),
          );
        },
      );
    });
  }
}
