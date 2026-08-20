import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:laundry/controller/addeditcategorycontroller.dart';
import 'package:laundry/core/theme/app_colors.dart';
import 'package:laundry/view/screen/deletecategory.dart';
import 'package:laundry/view/widget/customtextformfield.dart';

class CustomViewCategory extends StatelessWidget {
  const CustomViewCategory({super.key});

  @override
  Widget build(BuildContext context) {
    return GetBuilder<AddCategoryController>(
      init: AddCategoryController(),
      builder:
          (controller) => FutureBuilder(
            future: controller.readData(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                );
              }
              if (snapshot.hasError) {
                return const Center(
                  child: Text(
                    "حدث خطأ في جلب البيانات",
                    style: TextStyle(
                      fontFamily: 'cairo',
                      color: AppColors.danger,
                    ),
                  ),
                );
              }
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.inventory_2_outlined,
                        size: 56,
                        color: AppColors.border,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        "لا توجد أصناف بعد",
                        style: TextStyle(
                          fontFamily: 'cairo',
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "أضف أصنافاً من شاشة إضافة لبس",
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
                itemCount: snapshot.data!.length,
                itemBuilder: (context, i) {
                  final data = snapshot.data![i];
                  final isEven = i.isEven;
                  return Container(
                    decoration: BoxDecoration(
                      color: isEven ? Colors.white : AppColors.surfaceSoft,
                      border: Border(
                        bottom: BorderSide(color: AppColors.border),
                      ),
                    ),
                    child: Row(
                      children: [
                        CustomEditDeleteExpanded(data: data),
                        CustomExpanded(
                          lable: data['urgent_ironing_price'].toString(),
                          border: 1,
                        ),
                        CustomExpanded(
                          lable: data['normal_ironing_price'].toString(),
                          border: 1,
                        ),
                        CustomExpanded(
                          lable:
                              data['urgent_washing_and_ironing_price']
                                  .toString(),
                          border: 1,
                        ),
                        CustomExpanded(
                          lable:
                              data['normal_washing_and_ironing_price']
                                  .toString(),
                          border: 1,
                        ),
                        CustomExpanded(lable: data['clothing_name'], border: 0),
                      ],
                    ),
                  );
                },
              );
            },
          ),
    );
  }
}
