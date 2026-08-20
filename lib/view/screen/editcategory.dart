import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:laundry/controller/editcategorycontroller.dart';
import 'package:laundry/core/theme/app_colors.dart';
import 'package:laundry/view/widget/common/animation_wrappers.dart';
import 'package:laundry/view/widget/customappbar.dart';
import 'package:laundry/view/widget/customtextformfield.dart';

class EditCategory extends StatelessWidget {
  final Map<String, dynamic> data;
  EditCategory({super.key, required this.data});
  GlobalKey<FormState> formstate = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final EditController controller = Get.put(EditController());
    controller.moveValues(data);
    return Scaffold(
      appBar: CustomAppbar(
        title: "تعديل الصنف",
        subtitle: '${data['clothing_name']}',
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(14),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: FadeInUp(
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: AppColors.softShadow(),
                  border: Border.all(color: AppColors.border),
                ),
                child: Form(
                  key: formstate,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              gradient: AppColors.primaryGradient,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.edit_outlined,
                              color: Colors.white,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'تعديل بيانات الصنف',
                                  style: TextStyle(
                                    fontFamily: 'cairo',
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                Text(
                                  'عدّل الأسعار ثم احفظ التغييرات',
                                  style: TextStyle(
                                    fontFamily: 'cairo',
                                    fontSize: 11,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 26),
                      CustomTextFormField(
                        valueinput: controller.name,
                        lable: "اسم اللبس",
                        inputtype: TextInputType.text,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: CustomTextFormField(
                              valueinput: controller.urgentwashingprice,
                              lable: 'سعر الغسيل مستعجل',
                              inputtype: TextInputType.number,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: CustomTextFormField(
                              valueinput: controller.washingprice,
                              lable: 'سعر الغسيل عادي',
                              inputtype: TextInputType.number,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: CustomTextFormField(
                              valueinput: controller.urgentironingprice,
                              lable: 'سعر الكوي مستعجل',
                              inputtype: TextInputType.number,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: CustomTextFormField(
                              valueinput: controller.ironingprice,
                              lable: 'سعر الكوي عادي',
                              inputtype: TextInputType.number,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Get.back(),
                              child: const Text(
                                "إلغاء",
                                style: TextStyle(
                                  fontFamily: 'cairo',
                                  fontSize: 15,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.success,
                              ),
                              onPressed: () {
                                if (formstate.currentState!.validate()) {
                                  controller.updateCategory(
                                    data['clothing_id'],
                                  );
                                }
                              },
                              child: const Text(
                                "حفظ التعديل",
                                style: TextStyle(
                                  fontFamily: 'cairo',
                                  fontSize: 15,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
