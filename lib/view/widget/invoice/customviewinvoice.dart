import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:laundry/controller/invoicecontroller.dart';
import 'package:laundry/view/widget/customimg.dart';
import 'package:laundry/view/widget/customtext.dart';

class CustomViewInvoice extends StatelessWidget {
  Map<String, dynamic> part;
  final int index;
  final InvoiceController controllerprint;
  CustomViewInvoice({
    super.key,
    required this.part,
    required this.controllerprint,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(width: 2, color: Colors.grey)),
      ),
      child: ListTile(
        title: Text(
          "${part['vestments']}(${part['content']})",
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, fontFamily: 'cairo'),
        ),
        subtitle: Wrap(
          spacing: 5,
          children: [
            Text(
              "${part['price']}x${part['count']}",
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        trailing: Wrap(
          spacing: 5,
          children: [
            Text(
              "${part['total_price']}",
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            CustomImg(size_img: 17)
            // ImageIcon(AssetImage("assets/images/saudi-riyal.png"), size: 17),
          ],
        ),
        onTap: () {
          Get.defaultDialog(
            backgroundColor: Colors.red,
            title: 'هل انت متأكد لحذف \n ${part['vestments']} (${part['content']}) من الفاتورة؟',
            titleStyle: TextStyle(fontFamily: 'cairo', color: Colors.white),
            content: Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () {
                      controllerprint.removeItem(index);
                    },
                    child: CustomText(fontSize: 20, text: "موافق")
                  ),
                ),
                Expanded(
                  child: TextButton(
                    onPressed: () {
                      Get.back();
                    },
                    child: CustomText(fontSize: 20, text: "إلغاء")
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
