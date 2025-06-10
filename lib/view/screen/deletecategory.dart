import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:laundry/controller/addeditcategorycontroller.dart';
import 'package:laundry/view/screen/editcategory.dart';
import 'package:laundry/view/widget/customtext.dart';

class CustomEditDeleteExpanded extends StatelessWidget {
  final Map<String, dynamic> data;
  const CustomEditDeleteExpanded({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final AddCategoryController controller = Get.put(AddCategoryController());
    return Expanded(
      child: Container(
        decoration: BoxDecoration(border: Border(right: BorderSide())),
        alignment: Alignment.center,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              tooltip: 'تعديل',
              onPressed: () {
                Get.to(() => EditCategory(data: data));
              },
              icon: Icon(Icons.edit, color: Colors.blue),
            ),
            IconButton(
              tooltip: 'حذف',
              onPressed: () {
                Get.defaultDialog(
                  backgroundColor: Colors.red,
                  titleStyle: TextStyle(
                    color: Colors.white,
                    fontFamily: 'cairo',
                  ),
                  title: "هل انت متأكد للحذف",
                  content: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      TextButton(
                        onPressed: () {
                          Get.back();
                          controller.messagefailer();
                        },
                        child: CustomText(fontSize: 16, text: "إلغاء"),
                      ),
                      TextButton(
                        onPressed: () {
                          Get.back();
                          controller.delete(data['clothing_id']);
                        },
                        child: CustomText(fontSize: 16, text: "موافق")
                      ),
                    ],
                  ),
                );
              },
              icon: Icon(Icons.delete, color: Colors.red),
            ),
          ],
        ),
      ),
    );
  }
}
