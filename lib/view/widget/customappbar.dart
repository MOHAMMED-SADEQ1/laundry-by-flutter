import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:laundry/core/theme/app_colors.dart';
import 'package:laundry/services/i18n/l10n.dart';

/// شريط علوي موحد بشعار متدرج وقاعدة دائرية
class CustomAppbar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final String? subtitle;
  final Widget? actions;
  final bool showBack;
  const CustomAppbar({
    super.key,
    required this.title,
    this.subtitle,
    this.actions,
    this.showBack = true,
  });

  @override
  Widget build(BuildContext context) {
    return AppBar(
      flexibleSpace: Container(
        decoration: const BoxDecoration(gradient: AppColors.primaryGradient),
      ),
      leading:
          showBack
              ? Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Center(
                  child: Material(
                    color: Colors.white.withValues(alpha: 0.15),
                    shape: const CircleBorder(),
                    child: IconButton(
                      tooltip: tr("رجوع"),
                      onPressed: () => Get.back(),
                      icon: const Icon(
                        Icons.arrow_forward_rounded,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              )
              : null,
      leadingWidth: 60,
      centerTitle: true,
      title: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 19,
              fontFamily: 'cairo',
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (subtitle != null)
            Text(
              subtitle!,
              style: TextStyle(
                fontSize: 11,
                color: Colors.white.withValues(alpha: 0.8),
                fontFamily: 'cairo',
              ),
            ),
        ],
      ),
      actions: [if (actions != null) actions!, const SizedBox(width: 8)],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(64);
}
