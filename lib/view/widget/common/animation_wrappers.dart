import 'package:flutter/material.dart';
import 'package:laundry/core/theme/app_colors.dart';

/// دخول ناعم من الأسفل مع تلاشي — يضيف حيوية للشاشات
class FadeInUp extends StatelessWidget {
  final Widget child;
  final int delayMs;
  const FadeInUp({super.key, required this.child, this.delayMs = 0});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 500 + delayMs),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 18 * (1 - value)),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}

/// تكبير عند الضغط مع ارتداد — تفاعل لمسي عصري
class ScaleTap extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double pressedScale;
  const ScaleTap({
    super.key,
    required this.child,
    this.onTap,
    this.pressedScale = 0.96,
  });

  @override
  State<ScaleTap> createState() => _ScaleTapState();
}

class _ScaleTapState extends State<ScaleTap> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: () {
        setState(() => _pressed = false);
        widget.onTap?.call();
      },
      child: AnimatedScale(
        scale: _pressed ? widget.pressedScale : 1,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

/// عداد رقمي متحرك (تأثير عدّ)
class AnimatedCounter extends StatelessWidget {
  final double value;
  final int decimals;
  final TextStyle? style;
  const AnimatedCounter({
    super.key,
    required this.value,
    this.decimals = 0,
    this.style,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value),
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeOutCubic,
      builder: (context, v, _) {
        return Text(v.toStringAsFixed(decimals), style: style);
      },
    );
  }
}

/// شريط تقدم متحرك
class AnimatedBar extends StatelessWidget {
  final double value; // 0..1
  final Color color;
  final double height;
  const AnimatedBar({
    super.key,
    required this.value,
    required this.color,
    this.height = 8,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(height / 2),
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: value.clamp(0, 1)),
        duration: const Duration(milliseconds: 900),
        curve: Curves.easeOutCubic,
        builder: (context, v, _) {
          return LayoutBuilder(
            builder: (context, cons) {
              return Container(
                height: height,
                color: AppColors.border,
                alignment: Alignment.centerRight,
                child: Container(
                  width: cons.maxWidth * v,
                  height: height,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [color, color.withValues(alpha: 0.7)],
                    ),
                    borderRadius: BorderRadius.circular(height / 2),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
