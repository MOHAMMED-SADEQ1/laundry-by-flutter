import 'package:get/get.dart';
import 'package:laundry/core/constant/routes.dart';
import 'package:laundry/view/screen/addcategory.dart';
import 'package:laundry/view/screen/category.dart';
import 'package:laundry/view/screen/customernumber.dart';
import 'package:laundry/view/screen/home.dart';
import 'package:laundry/view/screen/login.dart';
import 'package:laundry/view/screen/previousinvoice.dart';
import 'package:laundry/view/screen/spalesh.dart';
// import 'package:laundry/view/screen/viewpdf.dart';

List<GetPage<dynamic>>? routes = [
  GetPage(name: AppRoute.splash, page: () => SplashScreen()),
  GetPage(name: AppRoute.homepage, page: () => const Home()),
  GetPage(name: AppRoute.category, page: () => Category()),
  GetPage(name: AppRoute.addcategory, page: () => AddCategory()),
  GetPage(name: AppRoute.login, page: () => LoginScreen()),
  GetPage(name: AppRoute.customernumber, page: () => CustomerNumber()),
  GetPage(name: AppRoute.invoices, page: () => PreviousInvoice()),
  // GetPage(name: AppRoute.invoices, page: () => PaginatedListView()),
];
