import 'package:flutter/material.dart';
import 'package:laundry/view/widget/customtextblack.dart';

class CustomTextFormField extends StatelessWidget {
  TextEditingController valueinput = TextEditingController();
  String lable;
  TextInputType inputtype;
  CustomTextFormField({super.key,required this.valueinput,required this.lable,required this.inputtype});

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      keyboardType: inputtype,
      controller: valueinput,
      decoration: InputDecoration(
        label: Align(alignment: Alignment.center, child: CustomTextBlack(fontSize: 15, text: lable)),
        floatingLabelAlignment: FloatingLabelAlignment.center,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.rtl,
      validator: (value) {
        if (value!.isEmpty) {
          return 'لا يمكن ترك هذا الحقل فارغا';
        }
      },
    );
  }
}



class CustomExpanded extends StatelessWidget {
  final String lable;
  final int border;
  const CustomExpanded({super.key, required this.lable, required this.border});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        decoration: BoxDecoration(
          border: Border(right: border == 1 ? BorderSide() : BorderSide.none),
        ),
        alignment: Alignment.center,
        child: CustomTextBlack(fontSize: 17, text: lable)
      ),
    );
  }
}