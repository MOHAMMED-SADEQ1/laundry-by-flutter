import 'package:flutter/material.dart';
import 'package:laundry/view/widget/home/dialog.dart';

class CustomShowDialog extends StatelessWidget {
  Map<String, dynamic> data;
  CustomShowDialog({super.key, required this.data});
  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: () {
          dialog(data);
        },
        child: Center(
          child: Text(
            data['clothing_name'],
            style: TextStyle(
              fontFamily: 'cairo',
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}