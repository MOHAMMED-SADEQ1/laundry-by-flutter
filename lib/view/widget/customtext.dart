import 'package:flutter/material.dart';

class CustomText extends StatelessWidget {
  double fontSize;
  String text;
  CustomText({super.key, required this.fontSize,required this.text});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(fontFamily: 'cairo', color: Colors.white, fontSize: fontSize),
    );
  }
}
