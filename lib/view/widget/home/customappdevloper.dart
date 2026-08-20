import 'package:laundry/controller/homecontroller.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class CustomAppDevloper extends StatelessWidget {
  const CustomAppDevloper({super.key});

  @override
  Widget build(BuildContext context) {
    final HomeController controllerfov = Get.put(HomeController());
    return TextButton(
      child: const Text(
        "......مطور النظام",
        style: TextStyle(fontFamily: "cairo", color: Colors.blue),
      ),
      onPressed: () {
        Get.defaultDialog(
          title: "مطور النظام",
          titleStyle: TextStyle(fontFamily: "cairo"),
          content: const SelectableText(
            "لشكاوي والاستفسار التواصل عبر التالي",
            textAlign: TextAlign.center,
            style: TextStyle(fontFamily: "cairo"),
          ),
          actions: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                IconButton(
                  onPressed: () {
                    controllerfov.emailLauncher();
                  },
                  icon: FaIcon(
                    FontAwesomeIcons.envelope,
                    color: Colors.amber,
                    size: 45,
                  ),
                ),
                IconButton(
                  onPressed: () {
                    controllerfov.whatsappLauncher();
                  },
                  icon: FaIcon(
                    FontAwesomeIcons.whatsapp,
                    color: Colors.green,
                    size: 45,
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}
