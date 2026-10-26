// متحكّم لغة النظام — يقرأ ويحفظ ويُطبّق فورًا على الشجرة كلها.
//
// النمط متعمَّد: نسخة من `ThemeController` (حجم الخط) لأنه نفس النوع من
// الإعدادات — قيمة واحدة تحكم كل الشاشات، مخزَّنة كمفتاح خام في `settings`
// (`language`) لا كخيار في `SettingOptions`.
//
// **لماذا `Get.forceAppUpdate()` بعد التبديل؟** لأن النصوص تُقرأ بـ`tr()`
// وقت البناء لا عبر `Obx`. تغيير اللغة لا يمسّ أي `Rx` تعتمد عليه الودجات،
// فبلا إعادة بناء الجذر تبقى الشاشة الحالية بلغتها القديمة حتى تُفتح من جديد.
// `forceAppUpdate` يعيد بناء الجذر فيُعاد تقييم كل `tr()` في الشجرة الظاهرة.

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:laundry/config/constants.dart';
import 'package:laundry/services/i18n/app_language.dart';
import 'package:laundry/services/i18n/l10n.dart';
import 'package:laundry/sqldb.dart';

class LocaleController extends GetxController {
  static LocaleController get instance => Get.find<LocaleController>();

  final SqlDB _db = SqlDB();

  /// الاختيار المخزَّن كما اختاره المستخدم (قد يكون `system`).
  final Rx<AppLanguage> choice = AppLanguage.defaultLanguage.obs;

  /// اللغة **الفعلية** بعد حسم `system` بلغة الجهاز.
  final Rx<AppLanguage> resolved = AppLanguage.defaultLanguage.obs;

  /// لغة الجهاز كما أبلغها النظام (`ar` · `en` …).
  String get deviceLanguageCode => PlatformDispatcher.instance.locale.languageCode;

  /// تحميل الاختيار المحفوظ وتطبيقه — يُستدعى في `main` قبل `runApp`.
  Future<void> load() async {
    var stored = AppLanguage.defaultLanguage;
    try {
      final raw = await _db.getSetting(AppConstants.settingLanguage);
      if (raw != null && raw.trim().isNotEmpty) {
        stored = AppLanguage.byCode(raw);
      }
    } catch (e) {
      debugPrint('LocaleController load error: $e');
    }
    choice.value = stored;
    _apply(stored);
  }

  /// تغيير اللغة: يُطبَّق فورًا ثم يُحفظ (والفشل في الحفظ لا يمنع التطبيق).
  Future<void> setLanguage(AppLanguage next) async {
    if (next == choice.value) return;
    choice.value = next;
    _apply(next);
    Get.forceAppUpdate();
    try {
      await _db.updateSetting(AppConstants.settingLanguage, next.code);
    } catch (e) {
      debugPrint('LocaleController save error: $e');
    }
  }

  /// يضبط الحالة الفعلية في [L10n] (الذي تقرأ منه كل الواجهة).
  void _apply(AppLanguage stored) {
    final device = deviceLanguageCode;
    final actual = stored.resolve(device);
    resolved.value = actual;
    L10n.setLanguage(actual, deviceCode: device);
  }
}
