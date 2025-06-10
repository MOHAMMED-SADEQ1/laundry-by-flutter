import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:laundry/controller/editcategorycontroller.dart';
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
      appBar: CustomAppbar(title: "تعديل الأصناف",),
      body: Padding(
        padding: const EdgeInsets.all(10.0),
        child: Form(
          key: formstate,
          child: ListView(
            children: [
              CustomTextFormField(
                valueinput: controller.name,
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
                        Get.back();
                      },
                      child: Text(
                        "إلغاء",
                        style: TextStyle(
                          color: Colors.white,
                          fontFamily: 'cairo',
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 5),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green, // تغيير لون الخلفية
                        padding: EdgeInsets.symmetric(
                          // horizontal: 20,
                          vertical: 10,
                        ),
                        textStyle: TextStyle(fontSize: 18),
                      ),

                      onPressed: () {
                        if (formstate.currentState!.validate()) {
                          controller.updateCategory(data['clothing_id']);
                        }
                      },
                      child: Text(
                        "تعديل",
                        style: TextStyle(
                          color: Colors.white,
                          fontFamily: 'cairo',
                          fontWeight: FontWeight.bold,
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
    );
  }
}
