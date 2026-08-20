import 'package:flutter/material.dart';

class CustomImg extends StatelessWidget {
  final double sizeImg;
  const CustomImg({super.key, required this.sizeImg});

  @override
  Widget build(BuildContext context) {
    return ImageIcon(
      AssetImage("assets/images/saudi_riyal.png"),
      size: sizeImg,
    );
  }
}
