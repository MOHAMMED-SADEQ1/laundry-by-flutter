import 'package:flutter/material.dart';
import 'package:get/get.dart';

class CustomAppbar extends StatelessWidget implements PreferredSizeWidget {
  String title;
   CustomAppbar({super.key,required this.title});

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.blue,
      leading: Container(),
      centerTitle: true,
      title: Text(
        title,
        style: TextStyle(
          fontSize: 25,
          fontFamily: "cairo",
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
      actions: [
        IconButton(
          tooltip: "رجوع",
          onPressed: () {
            Get.back();
          },
          icon: const Icon(Icons.arrow_forward, color: Colors.white, size: 35),
          // ),
        ),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
