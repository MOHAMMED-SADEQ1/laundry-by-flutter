import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:laundry/controller/invoicecontroller.dart';
import 'package:laundry/view/widget/customimg.dart';
import 'package:laundry/view/widget/invoice/custominputname.dart';
import 'package:laundry/view/widget/invoice/custominvoicetitle.dart';
import 'package:laundry/view/widget/invoice/custompayinvoice.dart';
import 'package:laundry/view/widget/invoice/customremoveinvoce.dart';
import 'package:laundry/view/widget/invoice/customviewinvoice.dart';

class Invoice extends StatelessWidget {
  const Invoice({super.key});
  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: 3,
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey),
          borderRadius: BorderRadius.all(Radius.circular(10)),
        ),
        child: GetBuilder<InvoiceController>(
          init: InvoiceController(),
          builder:
              (controller) => Column(
                children: [
                  const CustomInvoiceTitle(),
                  CustomInputName(valueinput: controller.custmername),
                  Expanded(
                    flex: 7,
                    child: Directionality(
                      textDirection: TextDirection.rtl,
                      child: ListView.builder(
                        itemCount: controller.invoice.length,
                        itemBuilder: (context, index) {
                          return CustomViewInvoice(
                            part: controller.invoice[index],
                            controllerprint: controller,
                            index: index,
                          );
                        },
                      ),
                    ),
                  ),
                  Divider(),
                  Directionality(
                    textDirection: TextDirection.rtl,
                    child: ListTile(
                      title: Text("الإجمالي",style: TextStyle(fontFamily:'cairo')),
                      trailing: Wrap(
                        spacing: 5,
                        children: [
                          Text(
                            controller.calcSumation(),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          CustomImg(size_img: 18)
                        ],
                      ),
                    ),
                  ),
                  Divider(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      SizedBox(width: 5),
                      CustomPayInvoice(invcontroller: controller),
                      SizedBox(width: 10),
                      CustomRemoveInvoce(invcontroller: controller),
                      SizedBox(width: 5),
                    ],
                  ),
                  SizedBox(height: 5),
                ],
              ),
        ),
      ),
    );
  }
}
