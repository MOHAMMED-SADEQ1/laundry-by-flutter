import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:laundry/controller/invoicecontroller.dart';
import 'package:laundry/core/theme/app_colors.dart';
import 'package:laundry/services/i18n/currency.dart';
import 'package:laundry/services/i18n/l10n.dart';
import 'package:laundry/services/invoice/invoice_lines.dart';
import 'package:laundry/view/widget/customimg.dart';
import 'package:laundry/view/widget/invoice/invoice_line_edit_dialog.dart';

/// بند داخل الفاتورة — **سطر واحد بثلاثة أفعال ظاهرة**:
/// تعديل الكمية بلا حوار (− / +)، تعديل البند كاملًا (سعر/خدمة/ملاحظة)، وحذفه.
///
/// كان السطر يعرض زرّ حذف فقط داخل `ListTile.trailing`، وكانت الزيادة تتطلّب
/// فتح حوار الصنف من جديد ثم اختيار الخدمة والكمية — أي ثلاث خطوات لتغيير
/// رقم. الآن الزيادة نقرة واحدة، والتعديل نقرة واحدة.
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

  int get _quantity => InvoiceLines.quantityOf(part);

  double get _price => InvoiceLines.priceOf(part);

  double get _total => InvoiceLines.lineTotal(part);

  String get _note => '${part['note'] ?? ''}'.trim();

  String get _photo => '${part['photo'] ?? ''}'.trim();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: index.isEven ? AppColors.surface : AppColors.surfaceSoft,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: Column(
        children: [
          // ─── السطر الأول: الصنف والخدمة والإجمالي ───
          InkWell(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            onTap: _openEdit,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: const Icon(
                      Icons.checkroom,
                      size: 14,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${localizedText('${part['vestments'] ?? ''}', '${part['vestments_en'] ?? ''}')} — ${tr('${part['content'] ?? ''}')}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'cairo',
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          // سعر الوحدة ظاهر دائمًا: الكاشير يسأله أمام الزبون
                          '${_trim(_price)} ${Currency.symbol} × $_quantity',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                            fontFamily: 'cairo',
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _trim(_total),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppColors.success,
                          fontFamily: 'cairo',
                        ),
                      ),
                      const CustomImg(sizeImg: 13),
                    ],
                  ),
                ],
              ),
            ),
          ),
          // ─── السطر الثاني: ملاحظة/صورة + الكمية + تعديل + حذف ───
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 4, 6),
            child: Row(
              children: [
                if (_note.isNotEmpty || _photo.isNotEmpty)
                  Flexible(child: _extras()),
                const Spacer(),
                _QuantityStepper(
                  quantity: _quantity,
                  onIncrease:
                      () => controllerprint.increaseQuantity(index),
                  onDecrease:
                      () => controllerprint.decreaseQuantity(index),
                ),
                const SizedBox(width: 4),
                _LineAction(
                  tooltip: tr('تعديل البند'),
                  icon: Icons.edit_outlined,
                  color: AppColors.primary,
                  onTap: _openEdit,
                ),
                _LineAction(
                  tooltip: tr('حذف البند'),
                  icon: Icons.delete_outline,
                  color: AppColors.danger,
                  onTap: _confirmDelete,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// شريحة الملاحظة/الصورة — تُعرض أسفل السطر لا داخل عنوانه.
  Widget _extras() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_note.isNotEmpty) ...[
            const Icon(
              Icons.sticky_note_2_outlined,
              size: 11,
              color: AppColors.warning,
            ),
            const SizedBox(width: 3),
          ],
          if (_note.isNotEmpty)
            Flexible(
              child: Text(
                localizedText(_note, part['note_en']?.toString()),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.warning,
                  fontFamily: 'cairo',
                ),
              ),
            ),
          if (_photo.isNotEmpty) ...[
            const SizedBox(width: 5),
            InkWell(
              onTap: () => _showPhoto(_photo),
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
    );
  }

  /// رقم بلا `.0` زائدة: `5` لا `5.0` — الفاتورة تُقرأ لا تُحلَّل.
  static String _trim(double value) {
    final text = value.toStringAsFixed(2);
    return text.endsWith('.00')
        ? text.substring(0, text.length - 3)
        : text.replaceAll(RegExp(r'0$'), '');
  }

  void _openEdit() {
    showInvoiceLineEditDialog(controller: controllerprint, index: index);
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

/// عدّاد كمية مصغّر داخل سطر الفاتورة.
class _QuantityStepper extends StatelessWidget {
  final int quantity;
  final VoidCallback onIncrease;
  final VoidCallback onDecrease;

  const _QuantityStepper({
    required this.quantity,
    required this.onIncrease,
    required this.onDecrease,
  });

  @override
  Widget build(BuildContext context) {
    final canDecrease = quantity > InvoiceLines.minQuantity;
    return Container(
      height: 34,
      decoration: BoxDecoration(
        color: AppColors.surfaceSoft,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StepButton(
            tooltip: tr('تقليل'),
            icon: Icons.remove,
            color: canDecrease ? AppColors.danger : AppColors.textMuted,
            onTap: canDecrease ? onDecrease : null,
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 24),
            child: Text(
              '$quantity',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'cairo',
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
          ),
          _StepButton(
            tooltip: tr('زيادة'),
            icon: Icons.add,
            color: AppColors.success,
            onTap: onIncrease,
          ),
        ],
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  const _StepButton({
    required this.tooltip,
    required this.icon,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        // 30×34: أقلّ من ذلك يصعب على شاشة لمس، والكاشير يعمل بإصبع لا بفأرة.
        child: SizedBox(
          width: 30,
          height: 34,
          child: Icon(icon, size: 16, color: color),
        ),
      ),
    );
  }
}

/// زرّ صغير (تعديل/حذف) بحجم لمس مريح.
class _LineAction extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _LineAction({
    required this.tooltip,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: SizedBox(
          width: 34,
          height: 34,
          child: Icon(icon, size: 18, color: color),
        ),
      ),
    );
  }
}
