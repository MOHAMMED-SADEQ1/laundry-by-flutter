import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:laundry/controller/showdialogcontroller.dart';
import 'package:laundry/view/widget/customimg.dart';

dialog(Map<String, dynamic> data) {
  Get.defaultDialog(
    backgroundColor: Colors.blue[100],
    title: "${data['clothing_name']}",
    titleStyle: TextStyle(
      fontFamily: 'cairo',
      fontSize: 16,
      fontWeight: FontWeight.bold,
    ),
    barrierDismissible: false,
    content: Expanded(
      child: GetBuilder<ShowDialogController>(
        init: ShowDialogController(),
        builder:
            (controller) => Column(
              children: [
                ListTile(
                  trailing: IconButton(
                    onPressed: () {
                      Get.back();
                    },
                    icon: Icon(Icons.close, color: Colors.red),
                  ),
                  leading:
                      controller.typerequest == ""
                          ? SizedBox()
                          : TextButton(
                            onPressed: () {
                              controller.addWash(data);
                            },
                            child: Text(
                              "موافق",
                              style: TextStyle(
                                fontFamily: 'cairo',
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),
                          ),
                ),
                Divider(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: Card(
                        color: controller.urgentwashingironing,
                        child: ListTile(
                          leading: CustomImg(size_img: 20),
                          title: Text(
                            "غسيل وكوي مستعجل:       ${data["urgent_washing_and_ironing_price"]}",
                            style: TextStyle(
                              fontFamily: 'cairo',
                              // fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          onTap: () {
                            controller.addTypeSelected("urgentwashingironing");
                            // controllerfunction.changeColor();
                          },
                        ),
                      ),
                    ),
                    Expanded(
                      child: Card(
                        color: controller.normalwashingironing,
                        child: ListTile(
                          leading: CustomImg(size_img: 20),
                          title: Text(
                            "غسيل وكوي عادي:       ${data["normal_washing_and_ironing_price"]}",
                            style: TextStyle(
                              fontFamily: 'cairo',
                              // fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.start,
                          ),
                          onTap: () {
                            controller.addTypeSelected("normalwashingironing");
                          },
                        ),
                      ),
                    ),
                  ],
                ),
                Divider(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: Card(
                        color: controller.urgentironing,
                        child: ListTile(
                          leading: CustomImg(size_img: 20),
                          title: Text(
                            "كوي مستعجل:       ${data["urgent_ironing_price"]}",
                            style: TextStyle(
                              fontFamily: 'cairo',
                              // fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          onTap: () {
                            controller.addTypeSelected("urgentironing");
                          },
                        ),
                      ),
                    ),
                    Expanded(
                      child: Card(
                        color: controller.normalironing,
                        child: ListTile(
                          leading: CustomImg(size_img: 20),
                          title: Text(
                            "كوي عادي:       ${data["normal_ironing_price"]}",
                            style: TextStyle(
                              fontFamily: 'cairo',
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          onTap: () {
                            controller.addTypeSelected("normalironing");
                          },
                        ),
                      ),
                    ),
                  ],
                ),
                Divider(height: 10),
                controller.typerequest == ""
                    ? SizedBox()
                    : ListTile(
                      leading: IconButton(
                        onPressed: () {
                          controller.add();
                        },
                        icon: Icon(Icons.add),
                      ),
                      subtitle: Text(
                        "الكمية",
                        style: TextStyle(
                          fontFamily: 'cairo',
                          // fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      title: Text(
                        controller.count.toString(),
                        style: TextStyle(
                          fontFamily: 'cairo',
                          // fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      trailing: IconButton(
                        onPressed: () {
                          controller.remove();
                        },
                        icon: Icon(Icons.remove),
                      ),
                    ),
                Divider(height: 10),
              ],
            ),
      ),
    ),
  );
}
