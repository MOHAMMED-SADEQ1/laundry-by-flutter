import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:laundry/controller/addeditcategorycontroller.dart';
import 'package:laundry/core/theme/app_colors.dart';
import 'package:laundry/services/i18n/l10n.dart';
import 'package:laundry/view/screen/deletecategory.dart';
import 'package:laundry/view/widget/customtextformfield.dart';

/// جدول الأصناف التفاعلي — يقرأ من الحالة التفاعلية في المتحكم،
/// فيتحدّث تلقائياً بعد أي إضافة أو تعديل أسعار أو حذف.
///
/// **يعيد الجلب عند كل دخول** لا فقط عندما تكون القائمة فارغة: قد يكون
/// المستخدم عدّل الأصناف من شاشة أخرى، أو تكون القائمة محمَّلة في الذاكرة
/// من جلسة سابقة. الجلب عند الدخول يضمن أن ما يُعرض هو ما في القاعدة.
class CustomViewCategory extends StatefulWidget {
  const CustomViewCategory({super.key});

  @override
  State<CustomViewCategory> createState() => _CustomViewCategoryState();
}

class _CustomViewCategoryState extends State<CustomViewCategory>
    with WidgetsBindingObserver {
  late final AddCategoryController _controller;

  @override
  void initState() {
    super.initState();
    _controller = Get.put(AddCategoryController());
    WidgetsBinding.instance.addObserver(this);
    // مؤجّل لما بعد أول إطار حتى لا نعدّل حالة تفاعلية أثناء البناء.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _controller.loadClothing();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // العودة إلى التطبيق بعد تعديل خارجي/نسخ احتياطي ⇒ أعِد الجلب.
    if (state == AppLifecycleState.resumed && mounted) {
      _controller.loadClothing();
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;

    return Obx(() {
      if (controller.isLoading.value && controller.clothing.isEmpty) {
        return const Center(child: CircularProgressIndicator(strokeWidth: 2.5));
      }
      final items = controller.clothing;
      if (items.isEmpty) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.inventory_2_outlined,
                size: 56,
                color: AppColors.border,
              ),
              const SizedBox(height: 10),
              Text(
                tr('لا توجد أصناف بعد'),
                style: TextStyle(
                  fontFamily: 'cairo',
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                tr('أضف أصنافاً من شاشة إضافة لبس'),
                style: TextStyle(
                  fontFamily: 'cairo',
                  fontSize: 12,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
        );
      }
      return ListView.builder(
        itemCount: items.length,
        itemBuilder: (context, i) {
          final data = items[i];
          final isEven = i.isEven;
          return Container(
            decoration: BoxDecoration(
              color: isEven ? Colors.white : AppColors.surfaceSoft,
              border: Border(bottom: BorderSide(color: AppColors.border)),
            ),
            child: Row(
              children: [
                CustomEditDeleteExpanded(data: data),
                CustomExpanded(
                  lable: '${data['urgent_ironing_price'] ?? 0}',
                  border: 1,
                ),
                CustomExpanded(
                  lable: '${data['normal_ironing_price'] ?? 0}',
                  border: 1,
                ),
                CustomExpanded(
                  lable: '${data['urgent_washing_and_ironing_price'] ?? 0}',
                  border: 1,
                ),
                CustomExpanded(
                  lable: '${data['normal_washing_and_ironing_price'] ?? 0}',
                  border: 1,
                ),
                CustomExpanded(
                  lable: localized(data, 'clothing_name'),
                  border: 0,
                ),
              ],
            ),
          );
        },
      );
    });
  }
}
