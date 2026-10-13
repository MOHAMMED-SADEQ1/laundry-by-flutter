import 'package:get/get.dart';
import 'package:laundry/core/constant/routes.dart';
import 'package:laundry/services/business_info_service.dart';
import 'package:laundry/services/security/session_manager.dart';
import 'package:laundry/view/widget/license/license_expiry_notice.dart';
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
    await Future.delayed(Duration(milliseconds: 1500));

    // تحميل معلومات النشاط التجاري
    await BusinessInfoService.instance.load();

    // التحقق من الإعداد الأولي
    final onboardingDone =
        await BusinessInfoService.instance.isOnboardingCompleted();
    if (!onboardingDone) {
      Get.offNamed(AppRoute.onboarding);
      return;
    }

    SharedPreferences prefs = await SharedPreferences.getInstance();
    final isLoggedIn = prefs.getBool("login") ?? false;

    if (isLoggedIn) {
      await SessionManager.restoreSession();
      Get.offNamed(AppRoute.homepage);
      // المسار الآخر للدخول: فتح التطبيق وجلسة محفوظة (بلا شاشة تسجيل دخول).
      // بدونه لا يرى العميل التنبيه إلا إذا سجّل خروجه ودخوله يدويًا.
      showLicenseExpiryNoticeIfDue();
    } else {
      Get.offNamed(AppRoute.login);
    }
  }
}
