import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:laundry/controller/addeditcategorycontroller.dart';
import 'package:laundry/view/widget/customappbar.dart';
import 'package:laundry/view/widget/customtextbold.dart';
import 'package:laundry/view/widget/customtextformfield.dart';

class AddCategory extends StatelessWidget {
  AddCategory({super.key});
  GlobalKey<FormState> formstate = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final AddCategoryController controller = Get.put(
      AddCategoryController(),
    );
    return Scaffold(
      appBar: CustomAppbar(title:"إضافة صنف لبس"),
      body: Padding(
        padding: const EdgeInsets.all(10.0),
        child: Form(
          key: formstate,
          child: ListView(
            children: [
              CustomTextFormField(
                valueinput: controller.neme,
                lable: "اسم اللبس",
                inputtype: TextInputType.text,
              ),
              Divider(height: 10),
              SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: CustomTextFormField(
                      valueinput: controller.urgentwashingprice,
                      lable: 'سعر الغسيل مستعجل',
                      inputtype: TextInputType.number,
                    ),
                  ),
                  SizedBox(width: 5),
                  Expanded(
                    child: CustomTextFormField(
                      valueinput: controller.washingprice,
                      lable: 'سعر الغسيل عادي',
                      inputtype: TextInputType.number,
                    ),
                  ),
                ],
              ),
              Divider(height: 10),
              SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: CustomTextFormField(
                      valueinput: controller.urgentironingprice,
                      lable: 'سعر الكوي مستعجل',
                      inputtype: TextInputType.number,
                    ),
                  ),
                  SizedBox(width: 5),
                  Expanded(
                    child: CustomTextFormField(
                      valueinput: controller.ironingprice,
                      lable: 'سعر الكوي عادي',
                      inputtype: TextInputType.number,
                    ),
                  ),
                ],
              ),
              Divider(height: 10),
              SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.lightBlue,
                        padding: EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 10,
                        ),
                        textStyle: TextStyle(fontSize: 18),
                      ),
                      onPressed: () {
                        controller.messagefailer();
                      },
                      child: CustomTextBold(fontSize: 15, text: "إلغاء")
                    ),
                  ),
                  SizedBox(width: 5),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green, // تغيير لون الخلفية
                        padding: EdgeInsets.symmetric(
                          vertical: 10,
                        ),
                        textStyle: TextStyle(fontSize: 18),
                      ),
                      onPressed: () {
                        if (formstate.currentState!.validate()) {
                          controller.writeData();
                          controller.messageSuccessfully();
                        }
                      },
                      child: CustomTextBold(fontSize: 15, text: "موافق"),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}