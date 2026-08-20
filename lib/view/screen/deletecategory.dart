import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:laundry/controller/addeditcategorycontroller.dart';
import 'package:laundry/core/theme/app_colors.dart';
import 'package:laundry/view/screen/editcategory.dart';
import 'package:laundry/view/widget/common/app_dialog.dart';

/// أزرار تعديل وحذف داخل جدول الأصناف
class CustomEditDeleteExpanded extends StatelessWidget {
  final Map<String, dynamic> data;
  const CustomEditDeleteExpanded({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final AddCategoryController controller = Get.put(AddCategoryController());
    return Expanded(
      flex: 2,
      child: Container(
        decoration: BoxDecoration(
          border: Border(right: BorderSide(color: AppColors.border)),
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              tooltip: 'تعديل',
              onPressed: () {
                Get.to(() => EditCategory(data: data));
              },
              icon: const Icon(
                Icons.edit_outlined,
                color: AppColors.info,
                size: 21,
              ),
            ),
            IconButton(
              tooltip: 'حذف',
              onPressed: () async {
                final confirmed = await showConfirmDialog(
                  title: "حذف الصنف؟",
                  message:
                      "هل أنت متأكد من حذف \"${data['clothing_name']}\" نهائياً؟",
                  confirmText: 'حذف',
                  color: AppColors.danger,
                );
                if (confirmed == true) {
                  controller.delete(data['clothing_id']);
                }
              },
              icon: const Icon(
                Icons.delete_outline,
                color: AppColors.danger,
                size: 21,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
