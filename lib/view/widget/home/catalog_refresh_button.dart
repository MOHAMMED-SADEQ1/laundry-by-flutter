import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:laundry/controller/addeditcategorycontroller.dart';
import 'package:laundry/services/i18n/l10n.dart';

/// زرّ إعادة جلب الأصناف والخدمات من قاعدة البيانات.
///
/// **لماذا ودجة منفصلة؟** لأن زرّ التحديث يجب أن يوجد في أكثر من شاشة
/// (الرئيسية وإدارة الأصناف) ويجب أن يمنع النقر المزدوج أثناء الجلب. وجوده
/// في مكان واحد يضمن أن كل نسخة تتصرف بالطريقة نفسها.
class CatalogRefreshButton extends StatelessWidget {
  /// لون الأيقونة — أبيض على أشرطة التطبيق الملوّنة.
  final Color color;

  const CatalogRefreshButton({super.key, this.color = Colors.white});

  /// مفتاح قابل للاختبار.
  static const Key buttonKey = Key('catalog-refresh-button');

  @override
  Widget build(BuildContext context) {
    // `Get.put` لا `Get.find`: قد يُبنى الزرّ قبل شبكة الأصناف، و`put` على
    // متحكّم مسجَّل يُعيد نفسه فلا تُفقد القائمة المشتركة.
    final controller = Get.put(AddCategoryController());
    return Obx(() {
      final loading = controller.isLoading.value;
      return IconButton(
        key: buttonKey,
        tooltip: loading ? tr('جارٍ التحديث...') : tr('تحديث الأصناف والخدمات'),
        // الزرّ معطّل أثناء الجلب: لا طلبات متزامنة ولا وميض للقائمة.
        onPressed: loading ? null : controller.loadClothing,
        icon: _RefreshIcon(
          spinning: loading,
          color: loading ? color.withValues(alpha: 0.55) : color,
        ),
      );
    });
  }
}

/// أيقونة السهمين الدائرين — تدور ما دام الجلب جاريًا وتتوقف بعده.
class _RefreshIcon extends StatefulWidget {
  final bool spinning;
  final Color color;

  const _RefreshIcon({required this.spinning, required this.color});

  @override
  State<_RefreshIcon> createState() => _RefreshIconState();
}

class _RefreshIconState extends State<_RefreshIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _rotation = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 850),
  );

  @override
  void initState() {
    super.initState();
    if (widget.spinning) _rotation.repeat();
  }

  @override
  void didUpdateWidget(covariant _RefreshIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.spinning == oldWidget.spinning) return;
    if (widget.spinning) {
      _rotation.repeat();
    } else {
      _rotation.stop();
      _rotation.value = 0;
    }
  }

  @override
  void dispose() {
    _rotation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RotationTransition(
      turns: _rotation,
      child: Icon(Icons.refresh_rounded, color: widget.color),
    );
  }
}
