import 'package:flutter/material.dart';
import 'package:laundry/view/widget/customappbar.dart';
import 'package:laundry/view/widget/customtextformfield.dart';
import 'package:laundry/view/widget/home/customviewcaregory.dart';

class Category extends StatelessWidget {
  Category({super.key});
  GlobalKey<FormState> formstate = GlobalKey();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar:  CustomAppbar(title: "حذف-تعديل صنف لبس"),
      body: Column(
        children: [
          Container(
            child: Row(
              children: const [
                 CustomExpanded(lable: '', border: 1),
                CustomExpanded(lable: 'سعر الكوي مستعجل', border: 1),
                CustomExpanded(lable: 'سعر الكوي عادي', border: 1),
                CustomExpanded(lable: 'سعر الغسيل مستعجل', border: 1),
                CustomExpanded(lable: 'سعر الغسيل عادي', border: 1),
                CustomExpanded(lable: 'اسم اللبس', border: 0),
              ],
            ),
          ),
          Divider(thickness: 5),
          CustomViewCategory()
        ],
      ),
    );
  }
}
