import 'package:flutter/material.dart';
import 'package:laundry/services/i18n/l10n.dart';
import 'package:get/get.dart';
import 'package:laundry/controller/addeditcategorycontroller.dart';
import 'package:laundry/core/navigation/route_dismissal.dart';
import 'package:laundry/core/theme/app_colors.dart';
import 'package:laundry/view/widget/common/animation_wrappers.dart';
import 'package:laundry/view/widget/customappbar.dart';
import 'package:laundry/view/widget/customtextformfield.dart';

class AddCategory extends StatefulWidget {
  const AddCategory({super.key});

  @override
  State<AddCategory> createState() => _AddCategoryState();
}

class _AddCategoryState extends State<AddCategory> {
  final formstate = GlobalKey<FormState>();
  late final AddCategoryController controller;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    controller = Get.put(AddCategoryController());
  }

  Future<void> _save() async {
    if (_saving) return;
    if (!(formstate.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    final saved = await controller.writeData();
    if (!mounted) return;
    if (saved) {
      // الحفظ يعرض رسالة نجاح؛ `Get.back()` كان يغلقها ويترك الشاشة مفتوحة.
      dismissRoute(context);
    } else {
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppbar(
        title: tr("إضافة صنف لبس"),
        subtitle: tr('أضف لبساً جديداً بأسعار خدماته'),
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
                              Icons.checkroom,
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
                                  tr('بيانات الصنف الجديد'),
                                  style: TextStyle(
                                    fontFamily: 'cairo',
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                Text(
                                  tr('حدد اسم اللبس والأسعار لجميع الخدمات'),
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
                        valueinput: controller.neme,
                        lable: tr('اسم اللبس'),
                        inputtype: TextInputType.text,
                      ),
                      const SizedBox(height: 12),
                      // الاسم الإنجليزي — يظهر في الواجهة الإنجليزية فقط،
                      // وفراغه يعني عرض الاسم العربي (سقوط آمن).
                      CustomTextFormField(
                        key: const Key('item-name-en'),
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
                      // تكلفة القطعة الواحدة — أساس حساب الربح الفعلي.
                      // بدونها تبقى تكلفة كل الفواتير صفرًا و«صافي الربح»
                      // يساوي المبيعات.
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
                                      tr("حفظ الصنف"),
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
