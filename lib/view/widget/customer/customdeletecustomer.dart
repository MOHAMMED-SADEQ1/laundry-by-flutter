import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:laundry/controller/customersnumbercontroller.dart';
import 'package:laundry/core/theme/app_colors.dart';
import 'package:laundry/services/i18n/l10n.dart';
import 'package:laundry/services/permission/permission_catalog.dart';
import 'package:laundry/services/permission/permission_service.dart';
import 'package:laundry/view/widget/common/app_dialog.dart';

/// زر حذف الزبون — لا يظهر إلا لمن يملك `customer.delete`.
///
/// الحذف هنا **ناعم** (`is_active = 0`) لكنه يُخفي الزبون وذمّته من كل
/// القوائم، فخطرُه كخطر المحو؛ ولذلك حُرِس بمفتاحه الخاص لا بمفتاح
/// التعديل العام.
class CustomDeleteExpanded extends StatelessWidget {
  final int? id;
  const CustomDeleteExpanded({super.key, required this.id});

  @override
  Widget build(BuildContext context) {
    if (!PermissionService.can(PermissionKeys.customerDelete)) {
      return const SizedBox.shrink();
    }
    final CustomersNumberController controller = Get.put(
      CustomersNumberController(),
    );
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () async {
        final confirmed = await showConfirmDialog(
          title: tr('حذف الزبون؟'),
          message:
              tr("هل أنت متأكد من حذف هذا الزبون؟\nلن تظهر بياناته في قائمة الزبائن."),
          confirmText: tr('حذف'),
          color: AppColors.danger,
        );
        if (confirmed == true && id != null) {
          controller.delete(id!);
        }
      },
      child: Container(
        padding: const EdgeInsets.all(9),
        decoration: BoxDecoration(
          color: AppColors.danger.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.danger.withValues(alpha: 0.2)),
        ),
        child: const Icon(
          Icons.delete_outline,
          color: AppColors.danger,
          size: 21,
        ),
      ),
    );
  }
}
