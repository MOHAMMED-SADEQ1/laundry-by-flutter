import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:laundry/controller/customersnumbercontroller.dart';
import 'package:laundry/services/i18n/l10n.dart';
import 'package:laundry/core/theme/app_colors.dart';
import 'package:laundry/view/widget/common/app_dialog.dart';
import 'package:laundry/view/widget/customtextformfield.dart';

/// نافذة إضافة زبون — تُستدعى من زر «زبون جديد» ومن البحث عن زبون غير مسجّل.
/// [initialName] و[initialPhone] يُعبَّآن مسبقاً من نص البحث،
/// و[onAdded] يُنفَّذ بعد نجاح الحفظ مع (اسم الزبون، رقمه الأول).
Future<void> showAddCustomerDialog({
  String initialName = '',
  String initialPhone = '',
  void Function(String name, String phone)? onAdded,
}) {
  final CustomersNumberController controller =
      Get.isRegistered<CustomersNumberController>()
      ? Get.find<CustomersNumberController>()
      : Get.put(CustomersNumberController());

  // نعبّئ الحقول من نص البحث ثم نفرّغ ما لا يلزم حتى لا تبقى بيانات قديمة
  controller.neme.text = initialName.trim();
  controller.number1.text = initialPhone.trim();
  controller.number2.clear();

  return Get.dialog(
    AppFormDialog(
            title: tr("إضافة زبون جديد"),
            icon: Icons.person_add_alt_1,
            gradient: AppColors.primaryGradient,
            actions: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Get.back(),
                    child: Text(
                      tr('إلغاء'),
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
                    onPressed: () async {
                      // نلتقط القيم قبل الإغلاق لأن المتحكم يفرّغ الحقول بعد الحفظ
                      final name = controller.neme.text.trim();
                      final phone = controller.number1.text.trim();
                      if (name.isEmpty) {
                        controller.messagefailer(
                          tr('اكتب اسم الزبون أولاً'),
                        );
                        return;
                      }
                      // نغلق الحوار فوراً قبل أي عملية غير متزامنة فلا يبقى
                      // معلّقاً أبداً، ثم نحفظ ونعرض النتيجة في رسالة.
                      Get.back();
                      final saved = await controller.writeData();
                      if (saved) onAdded?.call(name, phone);
                    },
                    child: Text(
                      tr('حفظ'),
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
                  lable: tr('اسم الزبون'),
                  inputtype: TextInputType.text,
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: CustomTextFormField(
                        valueinput: controller.number1,
                        lable: tr('الرقم الأول'),
                        inputtype: TextInputType.phone,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: CustomTextFormField(
                        valueinput: controller.number2,
                        lable: tr('الرقم الثاني'),
                        inputtype: TextInputType.phone,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
  );
}

/// زر عائم لإضافة زبون (شاشة الزبائن)
class CustomAddCustomer extends StatelessWidget {
  final void Function(String name, String phone)? onAdded;
  const CustomAddCustomer({super.key, this.onAdded});

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.extended(
      backgroundColor: AppColors.primary,
      tooltip: tr('إضافة زبون'),
      icon: const Icon(Icons.person_add_alt_1),
      label: Text(
        tr('زبون جديد'),
        style: TextStyle(
          fontFamily: 'cairo',
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
      onPressed: () => showAddCustomerDialog(onAdded: onAdded),
    );
  }
}
