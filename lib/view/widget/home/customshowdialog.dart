import 'package:flutter/material.dart';
import 'package:laundry/core/theme/app_colors.dart';
import 'package:laundry/view/widget/home/dialog.dart';

/// بطاقة صنف عصرية بتأثير hover ولمعة
class CustomShowDialog extends StatefulWidget {
  final Map<String, dynamic> data;
  const CustomShowDialog({super.key, required this.data});

  @override
  State<CustomShowDialog> createState() => _CustomShowDialogState();
}

class _CustomShowDialogState extends State<CustomShowDialog> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final name = widget.data['clothing_name'] ?? '';
    final price = widget.data['normal_washing_and_ironing_price'] ?? 0;
    final urgent =
        (widget.data['urgent_washing_and_ironing_price'] ?? 0).toDouble();
    final normal = (price ?? 0).toDouble();
    final hasUrgent = urgent > normal;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: () => dialog(widget.data),
        child: AnimatedScale(
          scale: _pressed ? 0.95 : (_hovered ? 1.03 : 1.0),
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            margin: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              gradient:
                  _hovered
                      ? AppColors.primaryGradient
                      : const LinearGradient(
                        colors: [Color(0xFFFFFFFF), Color(0xFFF0F7FF)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _hovered ? Colors.transparent : AppColors.border,
                width: 1.4,
              ),
              boxShadow: [
                if (_hovered)
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.35),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  )
                else
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color:
                              _hovered
                                  ? Colors.white.withValues(alpha: 0.2)
                                  : AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: Icon(
                          Icons.checkroom,
                          size: 16,
                          color: _hovered ? Colors.white : AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 7),
                      Flexible(
                        child: Text(
                          name,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'cairo',
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color:
                                _hovered ? Colors.white : AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'من $normal ر.س',
                        style: TextStyle(
                          fontFamily: 'cairo',
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: _hovered ? Colors.white70 : AppColors.success,
                        ),
                      ),
                      if (hasUrgent) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color:
                                _hovered
                                    ? Colors.white.withValues(alpha: 0.25)
                                    : AppColors.warning.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.bolt,
                                size: 11,
                                color:
                                    _hovered
                                        ? Colors.amber.shade200
                                        : AppColors.warning,
                              ),
                              const SizedBox(width: 2),
                              Text(
                                'مستعجل $urgent',
                                style: TextStyle(
                                  fontFamily: 'cairo',
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color:
                                      _hovered
                                          ? Colors.amber.shade200
                                          : AppColors.warning,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
