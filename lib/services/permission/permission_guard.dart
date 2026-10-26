import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:laundry/core/constant/routes.dart';
import 'package:laundry/services/i18n/l10n.dart';
import 'package:laundry/services/permission/permission_catalog.dart';
import 'package:laundry/services/permission/permission_service.dart';

/// بوابة صلاحيات على مستوى **المسار**.
///
/// **لماذا مسار لا واجهة فقط؟** كان إخفاء مدخل من القائمة يحمي المدخل من
/// نقر عابر، لكن `Get.toNamed(AppRoute.backup)` من أي سطر — أو من زر تركه
/// مبرمج قديم — يفتح الشاشة كاملةً. فالواجهة قيد **تجربة مستخدم** لا
/// **أمن**: من يستطيع فتح شاشة يحصل على كل أزرارها. هذه البوابة تسدّ الطريق
/// نفسه: `GetPage.middlewares` تُنادى **قبل** بناء الصفحة، فإن لا يملك
/// المستخدم الصلاحية تُحوَّل الوجهة بدل أن تُبنى.
///
/// **فلسفة الفحص:** المسار مسموح إن ملك المستخدم **أحد** مفاتيحه المرجوة
/// (`any`) — لأن المسار قد يخدم غرضين (مثل `/settings` لكل الإعدادات).
/// أما تحديد *ماذا يفعل داخلها* فمسؤولية الشاشة والخدمة.
///
/// **سلوك الفشل:**
///   - لم تُحمَّل الصلاحيات بعد (`!isLoaded`) ⇒ **اسمح** بالدخول ثم أعِد
///     التحميل — كي لا يجعل الإقلاع البطيء شاشة بيضاء. الشاشات نفسها
///     محمية بالأزرار، والتحميل يتم فورًا بعد الدخول.
///   - مُحمَّلة ولا يملك ⇒ حوّل إلى `/homepage` واعرض تنبيهًا.
class PermissionGuard extends GetMiddleware {
  /// مفاتيح مقبولة للمسار — النجاح بأحدها.
  final List<String> keys;

  /// نصّ بديل في التنبيه إن لم يُشتقّ من الكتالوج.
  final String? label;

  /// **بلا `const` عمدًا:** `GetMiddleware` في إصدار Get الحالي منشئه
  /// الافتراضي غير ثابت (يُهيّئ `priority` وإعدادات داخلية)، فلا يجوز أن
  /// يستدعي مُنشئ `const` مُنشئًا غير ثابت. الأثر العملي معدوم — الحرس
  /// يُبنى مرّة عند تعريف المسار لا في كل تنقّل.
  PermissionGuard(this.keys, {this.label});

  @override
  RouteSettings? redirect(String? route) {
    // صلاحيات غير محمَّلة ⇒ لا نحجب. الحرس الصارم يأتي من الأزرار
    // (`PermissionService.can` يرجع false) ومن طبقة الخدمة.
    if (!PermissionService.isLoaded) return null;

    if (keys.isEmpty) return null;
    if (PermissionService.any(keys)) return null;

    final what = label ??
        keys
            .map((k) => PermissionCatalog.find(k)?.label ?? k)
            .join(' / ');
    _notify(what);
    return const RouteSettings(name: AppRoute.homepage);
  }

  void _notify(String what) {
    // لا نستعمل Get.snackbar في الإقلاع (لا Overlay) — نتأكد من وجود واجهة.
    if (Get.context == null) return;
    Get.snackbar(
      tr('لا تملك صلاحية'),
      trf('الوصول إلى «{0}» مقصور على من يملك الصلاحية.', [what]),
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: const Color(0xFFDC2626),
      colorText: Colors.white,
      icon: const Icon(Icons.lock_outline, color: Colors.white),
    );
  }
}
