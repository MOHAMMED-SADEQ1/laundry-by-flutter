// حوار «كم نسخة تريد طباعتها؟» لإعادة الطباعة من سجل الفواتير.
//
// **لماذا لا يُغيّر الإعداد؟** `invoice_copies` يخصّ الطباعة التلقائية عند
// البيع. لو كتبت إعادةُ طباعة عرَضية فيه لتغيّر سلوك كل فاتورة تالية بلا أن
// يقصد المستخدم. فالاختيار هنا لهذه الطباعة وحدها، والافتراضي يبقى القيمة
// المحفوظة كي لا يُعاد الاختيار من الصفر في كل مرة.

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:laundry/core/navigation/route_dismissal.dart';
import 'package:laundry/core/theme/app_colors.dart';
import 'package:laundry/services/i18n/l10n.dart';
import 'package:laundry/services/settings/app_settings_service.dart';
import 'package:laundry/view/widget/common/app_dialog.dart';
import 'package:laundry/view/widget/invoice/invoice_copies_selector.dart';

/// حدّا عدد النسخ — يطابقان حدود إعداد `invoice_copies`.
const int kReprintCopiesMin = 1;
const int kReprintCopiesMax = 5;

/// يفتح حوار اختيار عدد نسخ إعادة الطباعة.
///
/// يرجع العدد المختار، أو `null` إن أُلغي الحوار. [initial] للاختبار؛ وغيابه
/// يعني «ابدأ من `invoice_copies` المحفوظ».
Future<int?> showInvoiceReprintCopiesDialog({int? initial}) {
  final configured =
      AppSettingsService.instance.isLoaded
          ? AppSettingsService.instance.invoiceCopies
          : kReprintCopiesMin;
  var value = (initial ?? configured)
      .clamp(kReprintCopiesMin, kReprintCopiesMax)
      .toInt();

  return Get.dialog<int>(
    Builder(
      // سياق الحوار نفسه: `dismissRoute` يغلق المسار مباشرة بدل `Get.back()`
      // الذي قد تبتلعه رسالة snackbar مفتوحة فيبقى الحوار معلّقًا.
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AppFormDialog(
          title: tr('طباعة الفاتورة'),
          icon: Icons.print_outlined,
          gradient: AppColors.primaryGradient,
          maxWidth: 400,
          actions: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => dismissRoute(dialogContext),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: AppColors.border),
                    foregroundColor: AppColors.textSecondary,
                  ),
                  child: Text(
                    tr('إلغاء'),
                    style: const TextStyle(
                      fontFamily: 'cairo',
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => dismissRoute(dialogContext, result: value),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                  child: Text(
                    tr('طباعة'),
                    style: const TextStyle(
                      fontFamily: 'cairo',
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ],
          ),
          child: InvoiceCopiesSelector(
            value: value,
            min: kReprintCopiesMin,
            max: kReprintCopiesMax,
            onChanged: (next) => setState(() => value = next),
          ),
        ),
      ),
    ),
  );
}
