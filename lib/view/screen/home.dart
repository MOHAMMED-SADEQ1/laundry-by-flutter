import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:laundry/controller/home_controller.dart';
import 'package:laundry/view/screen/invoice.dart';
import 'package:laundry/view/widget/home/customappbar.dart';
import 'package:laundry/view/widget/home/customdrawer.dart';
import 'package:laundry/view/widget/home/customshowdialog.dart';

class Home extends StatelessWidget {
  const Home({super.key});

  @override
  Widget build(BuildContext context) {
    GlobalKey<ScaffoldState> scaffoldKey = GlobalKey<ScaffoldState>();
    return Scaffold(
      key: scaffoldKey,
      appBar: CustomHomeAppBar(scaffoldKey: scaffoldKey),
      endDrawer: CustomDrawer(),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        child: Row(
          children: [
            Invoice(),
            GetBuilder<HomeControllerImp>(
              init: HomeControllerImp(),
              builder:
                  (controller) => Expanded(
                    flex: 5,
                    child: Container(
                      color: Colors.grey[300],
                      child: FutureBuilder(
                        future: controller.readData(),
                        builder: (
                          BuildContext context,
                          AsyncSnapshot snapshot,
                        ) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return Center(child: CircularProgressIndicator());
                          } else if (snapshot.hasError) {
                            return Center(
                              child: Text("حدث خطأ في جلب البيانات"),
                            );
                          } else if (snapshot.hasData) {
                            return Directionality(
                              textDirection: TextDirection.rtl,
                              child: GridView.builder(
                                gridDelegate:
                                    SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: 4,
                                      childAspectRatio: 2.0,
                                    ),
                                itemCount: snapshot.data.length,
                                itemBuilder: (context, index) {
                                  return CustomShowDialog(
                                    data: snapshot.data[index],
                                  );
                                },
                              ),
                            );
                          } else {
                            return Center(child: Text("لا توجد بيانات متاحة"));
                          }
                        },
                      ),
                    ),
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
