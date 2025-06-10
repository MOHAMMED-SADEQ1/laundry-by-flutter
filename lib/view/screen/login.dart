import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:laundry/controller/logincontroller.dart';
import 'package:laundry/view/widget/customtext.dart';
import 'package:laundry/view/widget/customtextbold.dart';

class LoginScreen extends StatelessWidget {
  final LoginController controller = Get.put(LoginController());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: Colors.blue,
        title: CustomText(fontSize: 15, text: "تسجيل الدخول")),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
             TextFormField(
              decoration: InputDecoration(
                label: Align(
                  alignment: Alignment.center,
                  child: CustomTextBold(fontSize: 15, text: "اسم المستخدم")
                ),
                floatingLabelAlignment: FloatingLabelAlignment.center,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              textAlign: TextAlign.center,
              textDirection: TextDirection.rtl,
              onChanged: (value) => controller.username.value = value,
            ),
            SizedBox(height: 12),
            TextFormField(
              decoration: InputDecoration(
                label: Align(
                  alignment: Alignment.center,
                  child: CustomTextBold(fontSize: 15, text: "كلمة المرور")
                ),
                floatingLabelAlignment: FloatingLabelAlignment.center,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              textAlign: TextAlign.center,
              textDirection: TextDirection.rtl,
              onChanged: (value) => controller.password.value = value,
            ),
            SizedBox(height: 20),
            Obx(
              () =>
                  controller.isLoading.value
                      ? CircularProgressIndicator()
                      : ElevatedButton(
                        style: ButtonStyle(backgroundColor: WidgetStatePropertyAll(Colors.green)),
                        onPressed: controller.login,
                        child: CustomText(fontSize: 15, text: "تسجيل الدخول")
                      ),
            ),
          ],
        ),
      ),
    );
  }
}
