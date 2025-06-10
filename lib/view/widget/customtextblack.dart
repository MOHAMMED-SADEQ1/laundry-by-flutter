import 'package:flutter/material.dart';

class CustomTextBlack extends StatelessWidget {
  double fontSize;
  String text;
  CustomTextBlack({super.key, required this.fontSize,required this.text});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(fontFamily: 'cairo', fontSize: fontSize),
    );
  }
}
