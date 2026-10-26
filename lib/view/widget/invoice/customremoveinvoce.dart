import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:laundry/controller/invoicecontroller.dart';
import 'package:laundry/core/theme/app_colors.dart';
import 'package:laundry/services/i18n/l10n.dart';
import 'package:laundry/services/permission/permission_catalog.dart';
import 'package:laundry/services/permission/permission_service.dart';

/// زر «إلغاء الفاتورة».
///
/// **لماذا `invoice.draft` لا `invoice.delete`؟** لأن هذا الزر لا يمسّ
/// القاعدة إطلاقًا: `deleteInvoice` تُفرّغ السلة في الذاكرة فقط. المفتاح
/// `invoice.delete` محفوظ لمحو **فاتورة صادرة** بالفعل — وهو فعل مختلف
/// تمامًا في الخطر. لو حُرِس الزر به لَتُوِّج من لا يملك المحو بمنع تفريغ
/// سلّته، وهو تعطيل بلا مبرر.
class CustomRemoveInvoce extends StatelessWidget {
  final InvoiceController invcontroller;
  const CustomRemoveInvoce({super.key, required this.invcontroller});

  @override
  Widget build(BuildContext context) {
    if (!PermissionService.can(PermissionKeys.invoiceDraft)) {
      return const SizedBox.shrink();
    }
    return Expanded(
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          gradient: AppColors.dangerGradient,
          borderRadius: BorderRadius.circular(14),
          boxShadow: AppColors.softShadow(
            color: AppColors.danger.withValues(alpha: 0.3),
            blur: 10,
            y: 4,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () {
              if (invcontroller.invoice.isEmpty) {
                Get.snackbar(
                  tr('تنبيه'),
                  tr('الفاتورة فارغة بالفعل'),
                  snackPosition: SnackPosition.BOTTOM,
                  backgroundColor: AppColors.warning,
                  colorText: Colors.white,
                );
                return;
              }
              Get.defaultDialog(
                backgroundColor: Colors.white,
                title: tr('إلغاء الفاتورة؟'),
                titleStyle: const TextStyle(
                  fontFamily: 'cairo',
                  fontWeight: FontWeight.bold,
                  color: AppColors.danger,
                ),
                middleText: tr('سيتم حذف جميع البنود من الفاتورة'),
                middleTextStyle: const TextStyle(
                  fontFamily: 'cairo',
                  fontSize: 14,
                ),
                textConfirm: tr('حذف'),
                textCancel: tr('إلغاء'),
                confirmTextColor: Colors.white,
                buttonColor: AppColors.danger,
                cancelTextColor: AppColors.textSecondary,
                onConfirm: () {
                  // إغلاق حوار التأكيد أولاً — بدونه كان الحوار يبقى معلّقاً
                  // فوق الشاشة بعد الحذف.
                  Get.back();
                  invcontroller.deleteInvoice();
                },
              );
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.delete_sweep, color: Colors.white, size: 20),
                const SizedBox(width: 6),
                Text(
                  tr("إلغاء الفاتورة"),
                  style: const TextStyle(
                    fontFamily: 'cairo',
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
