import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:laundry/controller/showdialogcontroller.dart';
import 'package:laundry/core/theme/app_colors.dart';
import 'package:laundry/view/widget/common/animation_wrappers.dart';
import 'package:laundry/view/widget/common/common_widgets.dart';
import 'package:laundry/view/widget/customimg.dart';

/// حوار اختيار الخدمة والإضافة للفاتورة — تصميم عصري كامل
void dialog(Map<String, dynamic> data) {
  Get.defaultDialog(
    backgroundColor: Colors.white,
    title: "",
    titlePadding: EdgeInsets.zero,
    contentPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
    barrierDismissible: true,
    radius: 24,
    content: GetBuilder<ShowDialogController>(
      init: ShowDialogController(),
      builder:
          (controller) => Directionality(
            textDirection: TextDirection.rtl,
            child: SizedBox(
              width: 460,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ─── رأس الحوار ───
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    decoration: const BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(20),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.checkroom,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            "اختر الخدمة و الكمية",
                            style: TextStyle(
                              fontFamily: 'cairo',
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Get.back(),
                          icon: const Icon(Icons.close, color: Colors.white),
                          tooltip: 'إغلاق',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // ─── اسم الصنف ───
                  Text(
                    "${data['clothing_name']}",
                    style: TextStyle(
                      fontFamily: 'cairo',
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // ─── شبكة الخدمات 2×2 ───
                  Row(
                    children: [
                      _ServiceCard(
                        controller: controller,
                        type: "normalwashingironing",
                        label: "غسيل وكوي عادي",
                        price: data["normal_washing_and_ironing_price"],
                        color: AppColors.success,
                        icon: Icons.local_laundry_service,
                      ),
                      const SizedBox(width: 8),
                      _ServiceCard(
                        controller: controller,
                        type: "urgentwashingironing",
                        label: "غسيل وكوي مستعجل",
                        price: data["urgent_washing_and_ironing_price"],
                        color: AppColors.warning,
                        icon: Icons.bolt,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _ServiceCard(
                        controller: controller,
                        type: "normalironing",
                        label: "كوي عادي",
                        price: data["normal_ironing_price"],
                        color: AppColors.info,
                        icon: Icons.checkroom,
                      ),
                      const SizedBox(width: 8),
                      _ServiceCard(
                        controller: controller,
                        type: "urgentironing",
                        label: "كوي مستعجل",
                        price: data["urgent_ironing_price"],
                        color: AppColors.violet,
                        icon: Icons.local_fire_department,
                      ),
                    ],
                  ),
                  // ─── ملاحظة / بقع + صورة ───
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    transitionBuilder:
                        (child, anim) =>
                            FadeTransition(opacity: anim, child: child),
                    child:
                        controller.typerequest == ""
                            ? const SizedBox.shrink()
                            : TextField(
                              key: const ValueKey('note'),
                              onChanged: (v) => controller.setNote(v),
                              maxLength: 60,
                              decoration: InputDecoration(
                                hintText:
                                    'ملاحظة (بقع، تلف، قصّات…) اكتب "بدون" إن أردت',
                                counterText: '',
                                prefixIcon: const Icon(
                                  Icons.sticky_note_2_outlined,
                                  size: 19,
                                  color: AppColors.warning,
                                ),
                                filled: true,
                                fillColor: AppColors.surfaceSoft,
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(
                                  vertical: 10,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: AppColors.border,
                                  ),
                                ),
                              ),
                            ),
                  ),
                  const SizedBox(height: 8),
                  // ─── زر صورة البقعة ───
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    transitionBuilder:
                        (child, anim) =>
                            FadeTransition(opacity: anim, child: child),
                    child:
                        controller.typerequest == ""
                            ? const SizedBox.shrink()
                            : Obx(
                              () => Row(
                                key: const ValueKey('photo-row'),
                                children: [
                                  Expanded(
                                    child: InkWell(
                                      onTap: controller.pickPhoto,
                                      borderRadius: BorderRadius.circular(10),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 9,
                                        ),
                                        decoration: BoxDecoration(
                                          color:
                                              controller
                                                      .photoPreview
                                                      .value
                                                      .isEmpty
                                                  ? AppColors.surfaceSoft
                                                  : AppColors.success
                                                      .withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                          border: Border.all(
                                            color:
                                                controller
                                                        .photoPreview
                                                        .value
                                                        .isEmpty
                                                    ? AppColors.border
                                                    : AppColors.success,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              controller
                                                      .photoPreview
                                                      .value
                                                      .isEmpty
                                                  ? Icons.add_a_photo_outlined
                                                  : Icons.check_circle,
                                              size: 16,
                                              color:
                                                  controller
                                                          .photoPreview
                                                          .value
                                                          .isEmpty
                                                      ? AppColors.info
                                                      : AppColors.success,
                                            ),
                                            const SizedBox(width: 6),
                                            Flexible(
                                              child: Text(
                                                controller
                                                        .photoPreview
                                                        .value
                                                        .isEmpty
                                                    ? 'إرفاق صورة البقعة'
                                                    : 'تم إرفاق الصورة ✓',
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  fontFamily: 'cairo',
                                                  fontSize: 11.5,
                                                  fontWeight: FontWeight.bold,
                                                  color: AppColors.info,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  if (controller
                                      .photoPreview
                                      .value
                                      .isNotEmpty) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      width: 40,
                                      height: 40,
                                      clipBehavior: Clip.antiAlias,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: AppColors.border,
                                        ),
                                      ),
                                      child: Image.file(
                                        File(controller.photoPreview.value),
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    IconButton(
                                      tooltip: 'حذف الصورة',
                                      onPressed: () {
                                        controller.photoPath = "";
                                        controller.photoPreview.value = '';
                                        controller.update();
                                      },
                                      icon: const Icon(
                                        Icons.delete_outline,
                                        color: AppColors.danger,
                                        size: 19,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                  ),
                  const SizedBox(height: 10),

                  // ─── الكمية + زر الإضافة ───
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    transitionBuilder:
                        (child, anim) =>
                            FadeTransition(opacity: anim, child: child),
                    child:
                        controller.typerequest == ""
                            ? Container(
                              key: const ValueKey('hint'),
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceSoft,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.touch_app,
                                    size: 18,
                                    color: AppColors.textMuted,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    "اختر نوع الخدمة لإضافته للفاتورة",
                                    style: TextStyle(
                                      fontFamily: 'cairo',
                                      fontSize: 12,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            )
                            : Row(
                              key: const ValueKey('actions'),
                              children: [
                                // عداد الكمية
                                Container(
                                  decoration: BoxDecoration(
                                    color: AppColors.surfaceSoft,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(color: AppColors.border),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        onPressed: controller.remove,
                                        icon: const Icon(
                                          Icons.remove_circle_outline,
                                          color: AppColors.danger,
                                        ),
                                        iconSize: 24,
                                        tooltip: 'تقليل',
                                      ),
                                      Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            "الكمية",
                                            style: TextStyle(
                                              fontFamily: 'cairo',
                                              fontSize: 10,
                                              color: AppColors.textMuted,
                                            ),
                                          ),
                                          ScaleTap(
                                            onTap: () {},
                                            child: Text(
                                              "${controller.count}",
                                              style: const TextStyle(
                                                fontFamily: 'cairo',
                                                fontSize: 19,
                                                fontWeight: FontWeight.bold,
                                                color: AppColors.primary,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      IconButton(
                                        onPressed: controller.add,
                                        icon: const Icon(
                                          Icons.add_circle,
                                          color: AppColors.success,
                                        ),
                                        iconSize: 24,
                                        tooltip: 'زيادة',
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: GradientButton(
                                    label: "إضافة للفاتورة",
                                    icon: Icons.add_shopping_cart,
                                    gradient: AppColors.successGradient,
                                    onPressed: () => controller.addWash(data),
                                  ),
                                ),
                              ],
                            ),
                  ),
                ],
              ),
            ),
          ),
    ),
  );
}

class _ServiceCard extends StatelessWidget {
  final ShowDialogController controller;
  final String type;
  final String label;
  final dynamic price;
  final Color color;
  final IconData icon;

  const _ServiceCard({
    required this.controller,
    required this.type,
    required this.label,
    required this.price,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final selected = controller.typerequest == type;
    final double p = (price ?? 0).toDouble();

    return Expanded(
      child: GestureDetector(
        onTap: () => controller.addTypeSelected(type),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 6),
          decoration: BoxDecoration(
            gradient:
                selected
                    ? LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [color, color.withValues(alpha: 0.75)],
                    )
                    : null,
            color: selected ? null : AppColors.surfaceSoft,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? color : AppColors.border,
              width: selected ? 2 : 1,
            ),
            boxShadow:
                selected
                    ? [
                      BoxShadow(
                        color: color.withValues(alpha: 0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ]
                    : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedScale(
                scale: selected ? 1.15 : 1,
                duration: const Duration(milliseconds: 200),
                child: Icon(
                  icon,
                  size: 25,
                  color: selected ? Colors.white : color,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'cairo',
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: selected ? Colors.white : AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    p == 0 ? 'مجاناً' : '$p',
                    style: TextStyle(
                      fontFamily: 'cairo',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: selected ? Colors.white : color,
                    ),
                  ),
                  const SizedBox(width: 3),
                  if (selected)
                    const Icon(
                      Icons.check_circle,
                      size: 14,
                      color: Colors.white,
                    )
                  else
                    const CustomImg(sizeImg: 13),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
