import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:laundry/controller/previousinvoicecontroller.dart';
import 'package:laundry/controller/printInvoicecontroller.dart';
import 'package:laundry/view/widget/customappbar.dart';
import 'package:laundry/view/widget/customtextblack.dart';

class PreviousInvoice extends StatelessWidget {
  const PreviousInvoice({super.key});

  @override
  Widget build(BuildContext context) {
    final PreviousInvoiceController controller = Get.put(PreviousInvoiceController());

    return Scaffold(
      appBar: CustomAppbar(title: "الفواتير السابقة"),
      body: RefreshIndicator(
        onRefresh: controller.refreshData,
        child: Obx(() {
          if (controller.isLoading.value && controller.invoices.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  CustomTextBlack(fontSize: 17, text: "جاري تحميل الفواتير..."),
                ],
              ),
            );
          }

          if (controller.invoices.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.receipt_long, size: 50, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    "لا توجد فواتير متاحة",
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          return Directionality(
            textDirection: TextDirection.rtl,
            child: GridView.builder(
              controller: controller.scrollController,
              padding: const EdgeInsets.all(8),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                childAspectRatio: 0.8,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
              ),
              itemCount:
                  controller.invoices.length +
                  (controller.hasMore.value ? 1 : 0),
              itemBuilder: (context, index) {
                if (index >= controller.invoices.length) {
                  return Obx(
                    () => Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 8),
                        CustomTextBlack(
                          fontSize: 15,
                          text: controller.loadingMessage.value,
                        ),
                      ],
                    ),
                  );
                }
                final invoice = controller.invoices[index];
                List<Map<String, dynamic>> listdata =
                    List<Map<String, dynamic>>.from(
                      json.decode(invoice['list_data']),
                    );
                Map<String, dynamic> mapdata = jsonDecode(invoice['map_data']);
                // print(listdata);
                // print(mapdata);
                // print(invoice['map_data'].runtimeType);
                return Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            CustomTextBlack(
                              fontSize: 16,
                              text: "رقم الفاتورة: ${invoice['invoices_id']}-1",
                            ),
                            Icon(Icons.receipt, color: Colors.blue),
                          ],
                        ),
                        Divider(),
                        SizedBox(height: 8),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: CustomTextBlack(
                            fontSize: 15,
                            text: "تاريخ الفاتورة: ${mapdata['date']}",
                          ),
                        ),
                        if (mapdata['customername'] != "")
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: CustomTextBlack(
                              fontSize: 15,
                              text: "العميل: ${mapdata['customername']}",
                            ),
                          ),
                        Divider(),
                        listdata.length == 1
                            ? Row(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 4),
                                  child: CustomTextBlack(
                                    fontSize: 15,
                                    text:
                                        "${listdata[0]['vestments']}(${listdata[0]['content']}) \n ${listdata[0]['price']}x${listdata[0]['count']}",
                                  ),
                                ),
                              ],
                            )
                            : Expanded(
                              flex: 10,
                              child: ListView.builder(
                                itemCount: listdata.length,
                                itemBuilder:
                                    (context, index) => Padding(
                                      padding: const EdgeInsets.only(bottom: 4),
                                      child: CustomTextBlack(
                                        fontSize: 15,
                                        text:"${listdata[index]['vestments']}(${listdata[index]['content']}) \n ${listdata[index]['price']}x${listdata[index]['count']}",
                                      ),
                                    ),
                              ),
                            ),
                        Spacer(),
                        Divider(),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            IconButton(
                              tooltip: 'طباعة',
                              onPressed: () {
                                controller.printPDF({
                                  'payment': mapdata['payment'],
                                  'logoImage': PrintInvoiceController.logoImageBytes!,
                                  'riyalImage': PrintInvoiceController.riyalImageBytes!,
                                  'arabicFont': PrintInvoiceController.arabicFont!,
                                  'invoiceItems': listdata,
                                  'summation': mapdata['summation'],
                                  'invoiceNumber': invoice['invoices_id'],
                                  'customername': mapdata['customername'],
                                  'date' :mapdata['date'],
                                });
                              },
                              icon: Icon(Icons.print, color: Colors.blue),
                            ),
                            Text(
                              "الإجمالي: ${mapdata['summation']} ر.س -//- ${mapdata['payment']}",
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'cairo',
                                color: Colors.green,
                              ),
                            ),
                          ],
                        ),
                        // ),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        }),
      ),
    );
  }
}