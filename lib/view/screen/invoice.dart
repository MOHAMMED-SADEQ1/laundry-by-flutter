import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:laundry/controller/invoicecontroller.dart';
import 'package:laundry/core/theme/app_colors.dart';
import 'package:laundry/view/widget/common/animation_wrappers.dart'
    show FadeInUp;
import 'package:laundry/view/widget/customimg.dart';
import 'package:laundry/view/widget/invoice/custominputname.dart';
import 'package:laundry/view/widget/invoice/custompayinvoice.dart';
import 'package:laundry/view/widget/invoice/customremoveinvoce.dart';
import 'package:laundry/view/widget/invoice/customviewinvoice.dart';
import 'package:laundry/view/widget/invoice/customdrafts.dart';
import 'package:laundry/services/i18n/ui_direction.dart';
import 'package:laundry/services/i18n/l10n.dart';

class Invoice extends StatelessWidget {
  const Invoice({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppColors.softShadow(),
      ),
      child: GetBuilder<InvoiceController>(
        init: InvoiceController(),
        builder:
            (controller) => Column(
              children: [
                // ─── رأس الفاتورة ───
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: AppColors.softShadow(blur: 10, y: 4),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.receipt_long, size: 20, color: Colors.white),
                      SizedBox(width: 8),
                      Text(
                        tr("الفاتورة"),
                        style: TextStyle(
                          fontFamily: 'cairo',
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                // ─── اسم الزبون ───
                CustomInputName(valueinput: controller.customername),
                // ─── بنود الفاتورة ───
                Expanded(
                  flex: 7,
                  child: Directionality(
                    textDirection: appTextDirection,
                    child:
                        controller.invoice.isEmpty
                            ? const _EmptyInvoice()
                            : ListView.builder(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              itemCount: controller.invoice.length,
                              itemBuilder: (context, index) {
                                return _InvoiceItemWrapped(
                                  index: index,
                                  controller: controller,
                                );
                              },
                            ),
                  ),
                ),
                const SizedBox(height: 4),
                const Divider(height: 1, thickness: 1),
                // ─── الإجمالي ───
                _TotalSection(controller: controller),
                const Divider(height: 1, thickness: 1),
                // ─── الأزرار ───
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      CustomPayInvoice(invcontroller: controller),
                      const SizedBox(width: 10),
                      CustomDrafts(invcontroller: controller),
                      const SizedBox(width: 10),
                      CustomRemoveInvoce(invcontroller: controller),
                    ],
                  ),
                ),
              ],
            ),
      ),
    );
  }
}

class _InvoiceItemWrapped extends StatelessWidget {
  final int index;
  final InvoiceController controller;
  const _InvoiceItemWrapped({required this.index, required this.controller});

  @override
  Widget build(BuildContext context) {
    return FadeInUp(
      delayMs: (index % 8) * 30,
      child: CustomViewInvoice(
        part: controller.invoice[index],
        controllerprint: controller,
        index: index,
      ),
    );
  }
}

class _EmptyInvoice extends StatelessWidget {
  const _EmptyInvoice();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.receipt_long, size: 52, color: AppColors.border),
          SizedBox(height: 10),
          Text(
            tr("الفاتورة فارغة"),
            style: TextStyle(
              fontFamily: 'cairo',
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppColors.textSecondary,
            ),
          ),
          SizedBox(height: 4),
          Text(
            tr("اضغط على صنف من القائمة لإضافته"),
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
}

class _TotalSection extends StatelessWidget {
  final InvoiceController controller;
  const _TotalSection({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(color: AppColors.surfaceSoft),
      child: Directionality(
        textDirection: appTextDirection,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(Icons.calculate, size: 19, color: AppColors.primary),
                SizedBox(width: 6),
                Text(
                  tr("الإجمالي"),
                  style: TextStyle(
                    fontFamily: 'cairo',
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            Obx(
              () => AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                transitionBuilder:
                    (child, anim) => ScaleTransition(scale: anim, child: child),
                child: Row(
                  key: ValueKey(controller.summation.value),
                  children: [
                    Text(
                      // عرض فقط — لا نكتب في `summation` من داخل `Obx`
                      controller.totalValue().toStringAsFixed(2),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                        fontFamily: 'cairo',
                      ),
                    ),
                    const SizedBox(width: 6),
                    const CustomImg(sizeImg: 18),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
