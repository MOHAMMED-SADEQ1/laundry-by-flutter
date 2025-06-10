import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:laundry/controller/customersnumbercontroller.dart';
import 'package:laundry/view/widget/customtextbold.dart';
import 'package:laundry/view/widget/customtextformfield.dart';

class CustomAddCustomer extends StatelessWidget {
  const CustomAddCustomer({super.key});

  @override
  Widget build(BuildContext context) {
    final CustomersNumberController controller = Get.put(CustomersNumberController());
    return FloatingActionButton(
        backgroundColor: Colors.green,
        tooltip: 'إضافة رقم',
        child: Icon(Icons.add, color: Colors.white),
        onPressed: () {
          Get.defaultDialog(
            title: "إضافة رقم زبون",
            titleStyle: TextStyle(fontFamily: 'cairo'),
            content: Column(
              children: [
                CustomTextFormField(
                  valueinput: controller.neme,
                  lable: "اسم الزبون",
                  inputtype: TextInputType.text,
                ),
                Divider(),
                Row(
                  children: [
                    Expanded(
                      child: CustomTextFormField(
                        valueinput: controller.number2,
                        lable: "الرقم الثاني",
                        inputtype: TextInputType.text,
                      ),
                    ),
                    SizedBox(width: 5),
                    Expanded(
                      child: CustomTextFormField(
                        valueinput: controller.number1,
                        lable: "الرقم الأول",
                        inputtype: TextInputType.text,
                      ),
                    ),
                  ],
                ),
                Divider(),
                Divider(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.lightBlue,
                        ),
                        onPressed: () {
                          Get.back();
                        },
                        child: CustomTextBold(fontSize: 15, text: "إلغاء")
                      ),
                    ),
                    SizedBox(width: 5),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                        ),
                        onPressed: () {
                            controller.writeData();
                        },
                        child: CustomTextBold(fontSize: 15, text: "موافق")
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      );
  }
}