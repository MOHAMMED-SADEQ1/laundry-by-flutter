import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:laundry/controller/invoicecontroller.dart';
import 'package:laundry/core/theme/app_colors.dart';
import 'package:laundry/services/i18n/l10n.dart';
import 'package:laundry/view/widget/customimg.dart';

/// بند داخل الفاتورة — تصميم أنيق مع حذف عند الضغط
class CustomViewInvoice extends StatelessWidget {
  final Map<String, dynamic> part;
  final int index;
  final InvoiceController controllerprint;
  const CustomViewInvoice({
    super.key,
    required this.part,
    required this.controllerprint,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: index.isEven ? AppColors.surface : AppColors.surfaceSoft,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: ListTile(
        dense: true,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        leading: Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            gradient: AppColors.primaryGradient,
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.checkroom, size: 15, color: Colors.white),
        ),
        title: Text(
          '${localizedText('${part['vestments'] ?? ''}', '${part['vestments_en'] ?? ''}')} — ${tr('${part['content'] ?? ''}')}',
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.bold,
            fontFamily: 'cairo',
            color: AppColors.textPrimary,
          ),
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "${part['price']} ${tr('ر.س')} × ${part['count']}",
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
                fontFamily: 'cairo',
              ),
            ),
            if ((part['note'] != null && '${part['note']}'.trim().isNotEmpty) ||
                (part['photo'] != null && '${part['photo']}'.trim().isNotEmpty))
              Container(
                margin: const EdgeInsets.only(top: 3),
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.sticky_note_2_outlined,
                      size: 11,
                      color: AppColors.warning,
                    ),
                    const SizedBox(width: 3),
                    if (part['note'] != null &&
                        '${part['note']}'.trim().isNotEmpty)
                      Flexible(
                        child: Text(
                          localizedText('${part['note'] ?? ''}', '${part['note_en'] ?? ''}'),
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.warning,
                            fontFamily: 'cairo',
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    if ('${part['photo'] ?? ''}'.trim().isNotEmpty) ...[
                      const SizedBox(width: 5),
                      InkWell(
                        onTap: () => _showPhoto(part['photo']),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.photo_camera,
                              size: 11,
                              color: AppColors.info,
                            ),
                            const SizedBox(width: 2),
                            Text(
                              tr('صورة'),
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: AppColors.info,
                                fontFamily: 'cairo',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "${part['total_price']}",
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppColors.success,
                fontFamily: 'cairo',
              ),
            ),
            const SizedBox(width: 4),
            const CustomImg(sizeImg: 15),
            const SizedBox(width: 4),
            IconButton(
              tooltip: tr('حذف البند'),
              onPressed: () => _confirmDelete(),
              icon: const Icon(
                Icons.delete_outline,
                size: 18,
                color: AppColors.danger,
              ),
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
      ),
    );
  }

  void _showPhoto(String path) {
    final file = File(path);
    if (!file.existsSync()) {
      Get.snackbar(
        tr('تنبيه'),
        tr('صورة البقعة غير متوفرة'),
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppColors.warning,
        colorText: Colors.white,
      );
      return;
    }
    Get.dialog(
      Dialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.file(file, fit: BoxFit.contain, width: 340),
              ),
              TextButton(
                onPressed: () => Get.back(),
                child: Text(
                  tr('إغلاق'),
                  style: const TextStyle(fontFamily: 'cairo', fontSize: 14),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDelete() {
    Get.defaultDialog(
      backgroundColor: AppColors.surface,
      title: tr('حذف البند؟'),
      titleStyle: const TextStyle(
        fontFamily: 'cairo',
        fontWeight: FontWeight.bold,
        color: AppColors.danger,
      ),
      middleText: trf(
        '{0} ({1}) سيتم حذفه من الفاتورة.',
        [localized(part, 'vestments'), localized(part, 'content')],
      ),
      middleTextStyle: const TextStyle(fontFamily: 'cairo', fontSize: 14),
      textConfirm: tr('حذف'),
      textCancel: tr('إلغاء'),
      confirmTextColor: Colors.white,
      buttonColor: AppColors.danger,
      cancelTextColor: AppColors.textSecondary,
      onConfirm: () {
        Get.back();
        controllerprint.removeItem(index);
      },
    );
  }
}
