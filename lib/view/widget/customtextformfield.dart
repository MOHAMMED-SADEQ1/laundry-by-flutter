import 'package:flutter/material.dart';
import 'package:laundry/core/theme/app_colors.dart';
import 'package:laundry/services/i18n/l10n.dart';
import 'package:laundry/services/i18n/ui_direction.dart';

/// حقل إدخال موحد عصري
class CustomTextFormField extends StatelessWidget {
  TextEditingController valueinput = TextEditingController();
  String lable;
  TextInputType inputtype;
  final String? Function(String?)? validator;
  CustomTextFormField({
    super.key,
    required this.valueinput,
    required this.lable,
    required this.inputtype,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      keyboardType: inputtype,
      controller: valueinput,
      style: const TextStyle(fontFamily: 'cairo', fontSize: 14),
      decoration: InputDecoration(
        labelText: lable,
        labelStyle: const TextStyle(fontFamily: 'cairo', fontSize: 13),
        floatingLabelBehavior: FloatingLabelBehavior.always,
        hintStyle: TextStyle(
          fontFamily: 'cairo',
          fontSize: 12,
          color: AppColors.textMuted,
        ),
      ),
      textAlign: TextAlign.start,
      textDirection: appTextDirection,
      validator:
          validator ??
          (value) {
            if (value == null || value.isEmpty) {
              return tr('لا يمكن ترك هذا الحقل فارغا');
            }
            return null;
          },
    );
  }
}

/// خلية جدول موحّدة
class CustomExpanded extends StatelessWidget {
  final String lable;
  final int border;
  const CustomExpanded({super.key, required this.lable, required this.border});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            right:
                border == 1
                    ? BorderSide(color: AppColors.border)
                    : BorderSide.none,
          ),
        ),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Text(
          lable,
          textAlign: TextAlign.center,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontFamily: 'cairo',
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
      ),
    );
  }
}
