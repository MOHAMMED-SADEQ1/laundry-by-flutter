import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// إغلاق المسار الذي يملك [context] إن كان لا يزال المسار الأعلى.
///
/// **لماذا لا نستعمل `Get.back()`؟** لأن GetX 4.x يفحص الـsnackbar أولًا:
/// إن كانت هناك رسالة نجاح معروضة، يغلقها ويعود **دون** إغلاق الشاشة أو
/// الحوار. والsnackbar ليست مسارًا في المكدّس بل طبقة Overlay، لذلك إغلاق
/// المسار مباشرة آمن ومتوقّع.
///
/// الحماية `route.isCurrent` تمنع إغلاق الصفحة التي تحت الحوار لو أُغلق
/// الحوار مسبقًا (نقر مزدوج على «حفظ» مثلًا).
bool dismissRoute(BuildContext context, {Object? result}) {
  if (!context.mounted) return false;
  final route = ModalRoute.of(context);
  if (route == null || !route.isCurrent) return false;
  Navigator.of(context).pop(result);
  return true;
}

/// إغلاق حوار GetX المفتوح دون أن تبتلعه رسالة snackbar.
///
/// تُفيد المواضع التي لا يتيسّر فيها التقاط `BuildContext` الخاص بالحوار
/// (مثل `Get.defaultDialog` الذي يبني محتواه لاحقًا). الفحص
/// `Get.isDialogOpen` يجعل النقر المزدوج آمنًا: بعد الإغلاق الأول يصبح
/// `false` فلا يُغلق مسار الصفحة الذي تحته.
bool dismissOpenDialog() {
  if (Get.isDialogOpen != true) return false;
  Get.close(1);
  return true;
}
