import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:laundry/controller/splashcontroller.dart';

class SplashScreen extends StatelessWidget {
  final SplashController controller = Get.put(SplashController());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // 🔹 خلفية متدرجة متحركة
          AnimatedContainer(
            duration: Duration(seconds: 3),
            curve: Curves.easeInOut,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color.fromARGB(255, 58, 108, 183),
                  Colors.blueAccent,
                  const Color.fromARGB(255, 64, 255, 239)
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          // 🔥 نص متحرك مع GetX
          Center(
            child: Obx(() => AnimatedOpacity(
              duration: Duration(seconds: 2),
              opacity: controller.opacity.value,
              child: AnimatedContainer(
                duration: Duration(seconds: 2),
                curve: Curves.easeInOut,
                transform: Matrix4.identity()..scale(controller.scale.value),
                child: Text("مغاسل النظارة",
                  style: TextStyle(fontSize: 50, color: Colors.white,fontFamily: 'DTHULUTH'),
                  textAlign: TextAlign.center,
                ),
              ),
            )),
          ),
        ],
      ),
    );
  }
}