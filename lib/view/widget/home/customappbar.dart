import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:laundry/view/screen/home.dart';
import 'package:laundry/view/widget/customtextbold.dart';

class CustomHomeAppBar extends StatelessWidget implements PreferredSizeWidget {
  final GlobalKey<ScaffoldState> scaffoldKey;

  const CustomHomeAppBar({required this.scaffoldKey, super.key});
  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.blue,
      leading: Row(
        children: [
          IconButton(
            tooltip: "تحديث الصفحة",
            onPressed: () => Get.offAll(const Home()),
            icon: const Icon(Icons.refresh, size: 30),
            color: Colors.white,
          ),
        ],
      ),
      centerTitle: true,
      title: CustomTextBold(fontSize: 25, text: 'مغاسل النظارة لغسيل الملابس'),
      actions: [
        IconButton(
          tooltip: "فتح القائمة الجانبية",
          onPressed: () {
            scaffoldKey.currentState!.openEndDrawer();
          },
          icon: const Icon(Icons.dehaze, color: Colors.white, size: 30),
          // ),
        ),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(70);
}
