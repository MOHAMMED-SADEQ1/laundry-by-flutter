import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:laundry/controller/invoicecontroller.dart';
import 'package:laundry/view/widget/customtext.dart';

class CustomRemoveInvoce extends StatelessWidget {
  final InvoiceController invcontroller;
  const CustomRemoveInvoce({super.key,required this.invcontroller});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: ElevatedButton(
        style: ButtonStyle(backgroundColor: WidgetStatePropertyAll(Colors.red)),
        onPressed: () {
          if (invcontroller.invoice.isNotEmpty) {
            Get.defaultDialog(
              backgroundColor: Colors.red,
              title: 'هل انت متأكد لحذف الفاتورة؟',
              titleStyle: TextStyle(fontFamily: 'cairo', color: Colors.white),
              content: Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () {
                        invcontroller.deleteInvoice();
                        Get.back();
                      },
                      child: CustomText(fontSize: 20, text: "موافق"),
                    ),
                  ),
                  Expanded(
                    child: TextButton(
                      onPressed: () {
                        Get.back();
                      },
                      child: CustomText(fontSize: 20, text: "إلغاء"),
                      
                    ),
                  ),
                ],
              ),
            );
          }
        },
        child: CustomText(fontSize: 15, text: "إلغاء الفاتورة"),
      ),
    );
  }
}
