import 'package:flutter/material.dart';
import 'package:get/get.dart';

class CustomCardRoute extends StatelessWidget {
  String pagename;
  String title;
  IconData icon;
  CustomCardRoute({
    super.key,
    required this.pagename,
    required this.title,
    required this.icon,
  });
  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 8,
      shadowColor: Colors.blue,
      margin: const EdgeInsets.symmetric(vertical: 7, horizontal: 5),
      child: ListTile(
        leading: Icon(icon),
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 20,
            fontFamily: "cairo",
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.end,
        ),
        onTap: () {
          Get.back();
          Get.toNamed(pagename);
        },
      ),
    );
  }
}
