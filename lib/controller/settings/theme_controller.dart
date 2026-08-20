import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:laundry/sqldb.dart';

/// يتحكم بحجم الخط العام للتطبيق (يُقرأ من قاعدة البيانات ويُطبق فوراً)
class ThemeController extends GetxController {
  static ThemeController get instance => Get.find<ThemeController>();

  final SqlDB _db = SqlDB();
  final RxDouble fontScale = 1.0.obs;

  static const double baseFontSize = 14;

  /// تحميل الإعداد المحفوظ عند بدء التشغيل
  Future<void> load() async {
    try {
      final size = double.tryParse(await _db.getSetting('font_size') ?? '');
      fontScale.value =
          ((size ?? baseFontSize) / baseFontSize).clamp(0.7, 1.8).toDouble();
    } catch (e) {
      debugPrint('ThemeController load error: $e');
    }
  }

  Future<void> setFontSize(double value) async {
    fontScale.value = (value / baseFontSize).clamp(0.7, 1.8).toDouble();
    try {
      await _db.updateSetting('font_size', value.toStringAsFixed(0));
    } catch (e) {
      debugPrint('setFontSize error: $e');
    }
  }
}
