import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:laundry/controller/customersnumbercontroller.dart';
import 'package:laundry/core/theme/app_colors.dart';
import 'package:laundry/view/widget/common/app_dialog.dart';
import 'package:laundry/view/widget/customtextformfield.dart';

class CustomAddCustomer extends StatelessWidget {
  final VoidCallback? onAdded;
  const CustomAddCustomer({super.key, this.onAdded});

  @override
  Widget build(BuildContext context) {
    final CustomersNumberController controller = Get.put(
      CustomersNumberController(),
    );
    return FloatingActionButton.extended(
      backgroundColor: AppColors.primary,
      tooltip: 'إضافة زبون',
      icon: const Icon(Icons.person_add_alt_1),
      label: const Text(
        'زبون جديد',
        style: TextStyle(
          fontFamily: 'cairo',
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
      onPressed: () {
        Get.dialog(
          AppFormDialog(
            title: "إضافة زبون جديد",
            icon: Icons.person_add_alt_1,
            gradient: AppColors.primaryGradient,
            actions: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Get.back(),
                    child: const Text(
                      "إلغاء",
                      style: TextStyle(fontFamily: 'cairo', fontSize: 14),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                    ),
                    onPressed: () {
                      controller.writeData();
                      onAdded?.call();
                    },
                    child: const Text(
                      "حفظ",
                      style: TextStyle(fontFamily: 'cairo', fontSize: 14),
                    ),
                  ),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CustomTextFormField(
                  valueinput: controller.neme,
                  lable: "اسم الزبون",
                  inputtype: TextInputType.text,
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: CustomTextFormField(
                        valueinput: controller.number1,
                        lable: "الرقم الأول",
                        inputtype: TextInputType.phone,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: CustomTextFormField(
                        valueinput: controller.number2,
                        lable: "الرقم الثاني",
                        inputtype: TextInputType.phone,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
