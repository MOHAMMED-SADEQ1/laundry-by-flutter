import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:laundry/controller/addeditcategorycontroller.dart';
import 'package:laundry/core/theme/app_colors.dart';
import 'package:laundry/services/permission/permission_catalog.dart';
import 'package:laundry/services/permission/permission_service.dart';
import 'package:laundry/view/screen/editcategory.dart';
import 'package:laundry/view/widget/common/app_dialog.dart';
import 'package:laundry/services/i18n/l10n.dart';

/// أزرار تعديل وحذف داخل جدول الأصناف.
///
/// **الأزرار لا تُعرض لمن لا يملكها** والإنفاذ الحقيقي يبقى في المتحكّم —
/// الإخفاء هنا يمنع الضغط على ما سيُرفَض أصلًا، فلا يظنّ المستخدم أن الزر
/// «لا يعمل» بلا سبب.
class CustomEditDeleteExpanded extends StatelessWidget {
  final Map<String, dynamic> data;
  const CustomEditDeleteExpanded({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final AddCategoryController controller = Get.put(AddCategoryController());
    final canManage = PermissionService.can(PermissionKeys.categoryManage);
    if (!canManage) {
      // بلا صلاحية ⇒ لا أزرار إطلاقًا (بدل صفّ فارغ يلفت النظر).
      return const Expanded(flex: 2, child: SizedBox.shrink());
    }
    return Expanded(
      flex: 2,
      child: Container(
        decoration: BoxDecoration(
          border: Border(right: BorderSide(color: AppColors.border)),
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              tooltip: tr('تعديل'),
              onPressed: () {
                Get.to(() => EditCategory(data: data));
              },
              icon: const Icon(
                Icons.edit_outlined,
                color: AppColors.info,
                size: 21,
              ),
            ),
            Obx(() {
              final id = (data['clothing_id'] as num?)?.toInt();
              final deleting =
                  id != null && controller.deletingIds.contains(id);
              return IconButton(
                tooltip: deleting ? tr('جارٍ الحذف...') : tr('حذف'),
                // لا نفتح حوارًا ثانيًا ولا نكرّر الحذف أثناء تنفيذ الأول.
                onPressed:
                    (id == null || deleting)
                        ? null
                        : () async {
                          final confirmed = await showConfirmDialog(
                            title: tr("حذف الصنف؟"),
                            message: trf('هل أنت متأكد من حذف "{0}"؟', [
                              localized(data, 'clothing_name'),
                            ]),
                            confirmText: tr('حذف'),
                            color: AppColors.danger,
                          );
                          // ننتظر الحذف وإعادة الجلب قبل إنهاء المعالجة، فلا
                          // تبقى العملية معلّقة في الخلفية بعد إغلاق الحوار.
                          if (confirmed == true) {
                            await controller.delete(id);
                          }
                        },
                icon:
                    deleting
                        ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.danger,
                          ),
                        )
                        : const Icon(
                          Icons.delete_outline,
                          color: AppColors.danger,
                          size: 21,
                        ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
