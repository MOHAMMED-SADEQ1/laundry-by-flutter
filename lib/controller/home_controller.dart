import 'package:get/get.dart';
import 'package:laundry/sqldb.dart';

abstract class HomeController extends GetxController {}

class HomeControllerImp extends HomeController {
  late String pathfile;

  Future<List<Map<String, dynamic>>> readData() async {
    SqlDB db = SqlDB();
    List<Map<String, dynamic>> response = await db.readData(
      'SELECT * FROM "clothing"',
    );
    // db.deleteDB();
    // db.deleteInvoice();
    return response;
  }

  @override
  void onInit() {
    super.onInit();
  }
}
