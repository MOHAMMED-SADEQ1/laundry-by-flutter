import 'package:get/get.dart';
import 'package:laundry/core/constant/routes.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SplashController extends GetxController {
  RxDouble opacity = 0.0.obs;
  RxDouble scale = 0.5.obs;

  @override
  void onInit() {
    super.onInit();
    _startAnimation();
  }

  void _startAnimation() async {
    await Future.delayed(Duration(seconds: 1));
    opacity.value = 1.0;
    scale.value = 1.2;
    await Future.delayed(Duration(seconds: 3));

    SharedPreferences prefs = await SharedPreferences.getInstance();
    if (prefs.getBool("login") == null) {
      Get.offNamed(AppRoute.login);
    } else {
      Get.offNamed(AppRoute.homepage);
    } // الانتقال للصفحة الرئيسية
  }
}
