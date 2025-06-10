
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:laundry/controller/customersnumbercontroller.dart';
import 'package:laundry/view/widget/customtext.dart';

class CustomDeleteExpanded extends StatelessWidget {
  final int id;
  const CustomDeleteExpanded({super.key, required this.id});

  @override
  Widget build(BuildContext context) {
    final CustomersNumberController controller = Get.put(CustomersNumberController());
    return Expanded(
      child: Container(
        decoration: BoxDecoration(border: Border(right: BorderSide())),
        alignment: Alignment.center,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
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
                        child: CustomText(fontSize: 15, text: "إلغاء")
                      ),
                      TextButton(
                        onPressed: () {
                          Get.back();
                          controller.update();
                        },
                        child: CustomText(fontSize: 15, text: "موافق"),
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