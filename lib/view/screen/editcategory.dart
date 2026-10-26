import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:laundry/controller/editcategorycontroller.dart';
import 'package:laundry/core/navigation/route_dismissal.dart';
import 'package:laundry/core/theme/app_colors.dart';
import 'package:laundry/services/i18n/l10n.dart';
import 'package:laundry/view/widget/common/animation_wrappers.dart';
import 'package:laundry/view/widget/customappbar.dart';
import 'package:laundry/view/widget/customtextformfield.dart';

class EditCategory extends StatefulWidget {
  final Map<String, dynamic> data;
  const EditCategory({super.key, required this.data});

  @override
  State<EditCategory> createState() => _EditCategoryState();
}

class _EditCategoryState extends State<EditCategory> {
  final formstate = GlobalKey<FormState>();
  late final EditController controller;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    controller = Get.put(EditController());
    controller.moveValues(widget.data);
  }

  Future<void> _save() async {
    if (_saving) return;
    if (!(formstate.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    final saved = await controller.updateCategory(widget.data['clothing_id']);
    if (!mounted) return;
    if (saved) {
      dismissRoute(context);
    } else {
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppbar(
        title: tr('تعديل الصنف'),
        subtitle: localized(widget.data, 'clothing_name'),
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
                                  tr('تعديل بيانات الصنف'),
                                  style: TextStyle(
                                    fontFamily: 'cairo',
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                Text(
                                  tr('عدّل الأسعار ثم احفظ التغييرات'),
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
                        lable: tr('اسم اللبس'),
                        inputtype: TextInputType.text,
                      ),
                      const SizedBox(height: 12),
                      // الاسم الإنجليزي — بدونه لا يستطيع المستخدم ترجمة
                      // صنف أُنشئ قبل دعم اللغتين، فيبقى عربيًّا إلى الأبد.
                      CustomTextFormField(
                        key: const Key('item-name-en-edit'),
                        valueinput: controller.nameEn,
                        lable: tr('الاسم بالإنجليزية (اختياري)'),
                        inputtype: TextInputType.text,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: CustomTextFormField(
                              valueinput: controller.urgentwashingprice,
                              lable: tr('سعر الغسيل مستعجل'),
                              inputtype: TextInputType.number,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: CustomTextFormField(
                              valueinput: controller.washingprice,
                              lable: tr('سعر الغسيل عادي'),
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
                              lable: tr('سعر الكوي مستعجل'),
                              inputtype: TextInputType.number,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: CustomTextFormField(
                              valueinput: controller.ironingprice,
                              lable: tr('سعر الكوي عادي'),
                              inputtype: TextInputType.number,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      // تكلفة القطعة — كانت غائبة من شاشة التعديل تمامًا،
                      // فبقي `cost_price` صفرًا لكل صنف وكل تقارير الربح وهمية.
                      CustomTextFormField(
                        valueinput: controller.costprice,
                        lable: 'تكلفة القطعة (مواد + تشغيل)',
                        inputtype: TextInputType.number,
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: _saving
                                  ? null
                                  : () => dismissRoute(context),
                              child: Text(
                                tr("إلغاء"),
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
                              onPressed: _saving ? null : _save,
                              child: _saving
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : Text(
                                      tr("حفظ التعديل"),
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
