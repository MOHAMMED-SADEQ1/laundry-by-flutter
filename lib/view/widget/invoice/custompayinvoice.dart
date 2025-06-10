import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:laundry/controller/invoicecontroller.dart';
import 'package:laundry/controller/printInvoicecontroller.dart';
import 'package:laundry/core/services/invoicecounterservice.dart';
import 'package:laundry/view/widget/customtext.dart';

class CustomPayInvoice extends StatelessWidget {
  final InvoiceController invcontroller;
  const CustomPayInvoice({super.key,required this.invcontroller});

  @override
  Widget build(BuildContext context) {
    final PrintInvoiceController controllerprint = Get.put(PrintInvoiceController());
    return Expanded(
      child: ElevatedButton(
        style: ButtonStyle(
          backgroundColor: WidgetStatePropertyAll(Colors.green),
        ),
        onPressed: () {
          if (invcontroller.invoice.isNotEmpty) {
            Get.defaultDialog(
              backgroundColor: Colors.green,
              titleStyle: TextStyle(color: Colors.white, fontFamily: 'cairo'),
              title: "نوع الدفع",
              content: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  TextButton(
                    onPressed: () async {
                      Get.back();
                      await controllerprint.printPDF(
                        "كاش",
                        await InvoiceCounterService().findInvoiceNo(),
                      );
                    },
                    child: CustomText(fontSize: 20, text: "كاش"),
                  ),
                  TextButton(
                    onPressed: () async {
                      Get.back();
                      controllerprint.printPDF(
                        "بطاقة",
                        await InvoiceCounterService().findInvoiceNo(),
                      );
                    },
                    child: CustomText(fontSize: 20, text: "شبكة"),
                  ),
                ],
              ),
            );
          }
          // controllerprint.sharePdf();
        },
        child: CustomText(fontSize: 15, text: "سداد"),
      ),
    );
  }
}
