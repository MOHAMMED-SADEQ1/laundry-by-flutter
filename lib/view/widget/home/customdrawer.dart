import 'package:flutter/material.dart';
import 'package:laundry/core/constant/routes.dart';
import 'package:laundry/view/widget/home/customcartroute.dart';

class CustomDrawer extends StatelessWidget {
  const CustomDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      elevation: 10,
      // backgroundColor: Colors.green[100],
      child: ListView(
        children: [
          DrawerHeader(child: Image.asset("assets/images/illustration.png")),
          CustomCardRoute(pagename: AppRoute.category, title: "حذف-تعديل لبس", icon: Icons.edit),
          CustomCardRoute(pagename: AppRoute.addcategory, title: "إضافة لبس", icon: Icons.add_card_rounded),
          CustomCardRoute(pagename: AppRoute.customernumber, title: "الزبائن", icon: Icons.contact_phone),
          CustomCardRoute(pagename: AppRoute.invoices, title: "الفواتير", icon: Icons.assignment),
        ],
      ),
    );
  }
}