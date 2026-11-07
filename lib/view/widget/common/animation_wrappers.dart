import 'dart:async';

import 'package:flutter/material.dart';
import 'package:laundry/core/theme/app_colors.dart';

/// دخول ناعم من الأسفل مع تلاشي — يضيف حيوية للشاشات
///
/// ## لماذا أُعيدت كتابته (2026-11-07)
/// الإصدار السابق كان `StatelessWidget` حول `TweenAnimationBuilder`، ويعيد
/// بناء شجرته في **كل إطار** من مدّة الحركة، مع `Opacity` — و`Opacity` تفرض
/// **طبقة رسم منفصلة (saveLayer)** لكل عنصر. على شبكة أصناف فيها 30 بطاقة
/// يعني ذلك 30 طبقة تُعاد رسمًا في كل إطار على كرت رسوميات مدمج ⇒ استنزاف
/// GPU وخطر TDR (تجميد الشاشة).
///
/// الإصلاح:
///   • `AnimationController` يعمل **مرة واحدة عند الظهور** — لا يعيد البناء
///     عند إعادة بناء الأب (كان `TweenAnimationBuilder` يُعاد ضبطه).
///   • `FadeTransition` بدل `Opacity`: عندما تصل الشفافية إلى 1.0 يُرسم
///     الابن **مباشرة بلا طبقة** (سلوك `RenderAnimatedOpacity`).
///   • `RepaintBoundary`: تلاشي بطاقة لا يُعيد رسم الشبكة كلها.
class FadeInUp extends StatefulWidget {
  final Widget child;
  final int delayMs;
  const FadeInUp({super.key, required this.child, this.delayMs = 0});

  @override
  State<FadeInUp> createState() => _FadeInUpState();
}

class _FadeInUpState extends State<FadeInUp>
    with SingleTickerProviderStateMixin {
  /// سقف التأخير: تأخير أطول من ذلك يُبقي عناصر غير مرئية بلا داعٍ.
  static const int _maxDelayMs = 400;

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 320),
  );

  late final Animation<double> _opacity = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOut,
  );

  /// إزاحة رأسية صغيرة — 12 بكسل لا 18، أقل عملًا على GPU.
  late final Animation<Offset> _slide = Tween<Offset>(
    begin: const Offset(0, 0.06),
    end: Offset.zero,
  ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

  Timer? _delayTimer;

  @override
  void initState() {
    super.initState();
    final delay = widget.delayMs.clamp(0, _maxDelayMs);
    if (delay == 0) {
      _controller.forward();
    } else {
      // ⚠️ `Timer` قابل للإلغاء — `Future.delayed` يبقى حيًّا بعد `dispose`
      // فيرمي عند إطلاق الحركة على حالة مُزالة.
      _delayTimer = Timer(Duration(milliseconds: delay), () {
        if (mounted) _controller.forward();
      });
    }
  }

  @override
  void dispose() {
    _delayTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: FadeTransition(
        opacity: _opacity,
        child: SlideTransition(position: _slide, child: widget.child),
      ),
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
