import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:laundry/controller/addeditcategorycontroller.dart';
import 'package:laundry/view/screen/deletecategory.dart';
import 'package:laundry/view/widget/customtextformfield.dart';

class CustomViewCategory extends StatelessWidget {
  const CustomViewCategory({super.key});

  @override
  Widget build(BuildContext context) {
    return Expanded(
            child: GetBuilder<AddCategoryController>(
              init: AddCategoryController(),
              builder:
                  (controller) => FutureBuilder(
                    future: controller.readData(),
                    builder: (BuildContext context, AsyncSnapshot snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return Center(child: CircularProgressIndicator());
                      } else if (snapshot.hasError) {
                        return Center(child: Text("حدث خطأ في جلب البيانات"));
                      } else if (snapshot.hasData) {
                        return ListView.builder(
                          itemCount: snapshot.data.length, // تعديل العدد ليعتمد على البيانات
                          itemBuilder: (context, i) {
                            return Card(
                              child: Row(
                                children: [
                                  CustomEditDeleteExpanded(
                                    data: snapshot.data[i],
                                  ),
                                  CustomExpanded(
                                    lable:
                                        snapshot.data[i]['urgent_ironing_price']
                                            .toString(),
                                    border: 1,
                                  ),
                                  CustomExpanded(
                                    lable: snapshot.data[i]['normal_ironing_price'].toString(),
                                    border: 1,
                                  ),
                                  CustomExpanded(
                                    lable:
                                        snapshot.data[i]['urgent_washing_and_ironing_price']
                                            .toString(),
                                    border: 1,
                                  ),
                                  CustomExpanded(
                                    lable:
                                        snapshot.data[i]['normal_washing_and_ironing_price']
                                            .toString(),
                                    border: 1,
                                  ),
                                  CustomExpanded(
                                    lable: snapshot.data[i]['clothing_name'],
                                    border: 0,
                                  ),
                                ],
                              ),
                            );
                          },
                        );
                      } else {
                        return Center(child: Text("لا توجد بيانات متاحة"));
                      }
                    },
                  ),
            ),
          );
  }
}