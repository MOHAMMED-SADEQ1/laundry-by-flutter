import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:laundry/controller/invoicecontroller.dart';
import 'package:laundry/core/theme/app_colors.dart';

class CustomRemoveInvoce extends StatelessWidget {
  final InvoiceController invcontroller;
  const CustomRemoveInvoce({super.key, required this.invcontroller});

  @override
  Widget build(BuildContext context) {
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
                  'تنبيه',
                  'الفاتورة فارغة بالفعل',
                  snackPosition: SnackPosition.BOTTOM,
                  backgroundColor: AppColors.warning,
                  colorText: Colors.white,
                );
                return;
              }
              Get.defaultDialog(
                backgroundColor: Colors.white,
                title: 'إلغاء الفاتورة؟',
                titleStyle: const TextStyle(
                  fontFamily: 'cairo',
                  fontWeight: FontWeight.bold,
                  color: AppColors.danger,
                ),
                middleText: 'سيتم حذف جميع البنود من الفاتورة',
                middleTextStyle: const TextStyle(
                  fontFamily: 'cairo',
                  fontSize: 14,
                ),
                textConfirm: 'حذف',
                textCancel: 'إلغاء',
                confirmTextColor: Colors.white,
                buttonColor: AppColors.danger,
                cancelTextColor: AppColors.textSecondary,
                onConfirm: () {
                  invcontroller.deleteInvoice();
                },
              );
            },
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.delete_sweep, color: Colors.white, size: 20),
                SizedBox(width: 6),
                Text(
                  "إلغاء الفاتورة",
                  style: TextStyle(
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
