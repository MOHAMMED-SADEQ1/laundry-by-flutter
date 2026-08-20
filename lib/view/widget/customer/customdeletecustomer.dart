import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:laundry/controller/customersnumbercontroller.dart';
import 'package:laundry/core/theme/app_colors.dart';
import 'package:laundry/view/widget/common/app_dialog.dart';

class CustomDeleteExpanded extends StatelessWidget {
  final int? id;
  const CustomDeleteExpanded({super.key, required this.id});

  @override
  Widget build(BuildContext context) {
    final CustomersNumberController controller = Get.put(
      CustomersNumberController(),
    );
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () async {
        final confirmed = await showConfirmDialog(
          title: "حذف الزبون؟",
          message:
              "هل أنت متأكد من حذف هذا الزبون؟\nلن تظهر بياناته في قائمة الزبائن.",
          confirmText: 'حذف',
          color: AppColors.danger,
        );
        if (confirmed == true && id != null) {
          controller.delete(id!);
        }
      },
      child: Container(
        padding: const EdgeInsets.all(9),
        decoration: BoxDecoration(
          color: AppColors.danger.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.danger.withValues(alpha: 0.2)),
        ),
        child: const Icon(
          Icons.delete_outline,
          color: AppColors.danger,
          size: 21,
        ),
      ),
    );
  }
}
