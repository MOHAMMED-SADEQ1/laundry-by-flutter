import 'package:flutter/material.dart';

class CustomImg extends StatelessWidget {
  double size_img;
  CustomImg({super.key,required this.size_img});

  @override
  Widget build(BuildContext context) {
    return ImageIcon(AssetImage("assets/images/saudi_riyal.png"), size: size_img);
  }
}
