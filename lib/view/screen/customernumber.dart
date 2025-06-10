import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:laundry/controller/customersnumbercontroller.dart';
import 'package:laundry/view/widget/customappbar.dart';
import 'package:laundry/view/widget/customer/customaddcustomer.dart';
import 'package:laundry/view/widget/customer/customdeletecustomer.dart';
import 'package:laundry/view/widget/customtextformfield.dart';

class CustomerNumber extends StatelessWidget {
  CustomerNumber({super.key});
  // GlobalKey<FormState> formstate = GlobalKey();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppbar(title: "الزبائن"),
      body: Column(
        children: [
          Container(
            child: Row(
              children: [
                CustomExpanded(lable: '', border: 1),
                CustomExpanded(lable: 'الرقم الثاني', border: 1),
                CustomExpanded(lable: 'الرقم الأول', border: 1),
                CustomExpanded(lable: 'اسم الزبون', border: 0),
              ],
            ),
          ),
          Divider(thickness: 5),
          Expanded(
            child: GetBuilder<CustomersNumberController>(
              init: CustomersNumberController(),
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
                          itemCount:
                              snapshot
                                  .data
                                  .length, // تعديل العدد ليعتمد على البيانات
                          itemBuilder: (context, i) {
                            return Card(
                              child: Row(
                                children: [
                                  CustomDeleteExpanded(
                                    id: snapshot.data[i]['numbers_id'],
                                  ),
                                  CustomExpanded(
                                    lable: snapshot.data[i]['number_2'],
                                    border: 1,
                                  ),
                                  CustomExpanded(
                                    lable: snapshot.data[i]['number_1'],
                                    border: 1,
                                  ),
                                  CustomExpanded(
                                    lable: snapshot.data[i]['customer_name'],
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
          ),
        ],
      ),
      floatingActionButton: CustomAddCustomer()
    );
  }
}