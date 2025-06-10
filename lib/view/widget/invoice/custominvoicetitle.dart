import 'package:flutter/material.dart';

class CustomInvoiceTitle extends StatelessWidget {
  const CustomInvoiceTitle({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.blue,
        borderRadius: BorderRadius.all(Radius.circular(10)),
      ),
      padding: EdgeInsets.all(10),
      child: Text(
        "الفاتورة",
        style: TextStyle(
          fontFamily: 'Cairo',
          fontSize: 18,
          color: Colors.white,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}
