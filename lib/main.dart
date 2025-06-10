import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:laundry/controller/printInvoicecontroller.dart';
import 'package:laundry/core/services/invoicecounterservice.dart';
import 'package:laundry/routes.dart';

void main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  await InvoiceCounterService.loadInitialCounter();
  await PrintInvoiceController.initializeAssets();
  // await PrintInvoiceController;
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'laundry',
      debugShowCheckedModeBanner: false,
      getPages: routes,
      theme: ThemeData(primaryColor: Colors.blue),
    );
  }
}
