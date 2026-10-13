import 'package:get/get.dart';
import 'package:laundry/config/constants.dart';
import 'package:laundry/services/database/backup_service.dart';
import 'package:laundry/services/license/system_license_service.dart';
import 'package:laundry/services/settings/app_settings_service.dart';
import 'package:laundry/services/settings/setting_option.dart';
import 'package:laundry/sqldb.dart';

class SettingsController extends GetxController {
  final SqlDB _db = SqlDB();

  var settings = <String, String>{}.obs;
  var backupInfo = <String, dynamic>{}.obs;
  var isLoading = false.obs;

  /// نصّ البحث في خيارات النظام — تصفية فورية بلا حفظ.
  var optionSearch = ''.obs;

  Future<void> loadSettings() async {
    isLoading.value = true;
    try {
      final data = await _db.safeRead('settings');
      for (final row in data) {
        settings[row['key'] ?? ''] = row['value']?.toString() ?? '';
      }
    } finally {
      isLoading.value = false;
    }
  }

  /// تحديث إعداد واحد.
  ///
  /// **خيارات النظام** ([SettingOptions]) تمرّ عبر [AppSettingsService]:
  /// تطبيع للقيمة حسب نوعها وحدودها + كتابة upsert + كاش + سجل تدقيق.
  /// وغيرها (معلومات النشاط) يُكتب مباشرة كما كان.
  Future<void> updateSetting(String key, String value) async {
    try {
      final String applied;
      if (SettingOptions.byKey(key) != null) {
        applied = await AppSettingsService.instance.set(key, value);
      } else {
        await _db.safeUpdate(
          'settings',
          {'value': value},
          where: 'key = ?',
          whereArgs: [key],
        );
        applied = value;
      }
      settings[key] = applied;
      _applyRuntimeEffects(key);
      Get.snackbar('نجاح', 'تم تحديث الإعداد بنجاح');
    } catch (e) {
      Get.snackbar('خطأ', 'فشل في تحديث الإعداد: $e');
    }
  }

  /// أثر فوري للتغيير في الخدمات التي تعمل بالخلفية.
  ///
  /// بلا هذا السطر تبقى القيمة الجديدة في القاعدة فقط ويظل النظام يعمل
  /// بالقديمة حتى إعادة التشغيل — وهو لبس مباشر للمستخدم.
  void _applyRuntimeEffects(String key) {
    if (!Get.isRegistered<SystemLicenseController>()) return;
    final license = Get.find<SystemLicenseController>();
    if (key == AppConstants.settingLicenseCheckHours) {
      // فاصل الفحص: يُعاد ضبط المؤقّت لا انتظار الدورة القادمة.
      license.applyIntervalFromSettings();
    } else if (key == AppConstants.settingLicenseWarnDays) {
      // عتبة التحذير: تُعاد التقييم فورًا لتظهر الحالة الجديدة.
      license.refreshNow();
    }
  }

  /// إنشاء نسخة احتياطية من الإعدادات مباشرة (بالاسم الافتراضي).
  ///
  /// الإدارة الكاملة (التسمية والاستعادة والقائمة) في شاشة `/backup`؛ وهذا
  /// اختصار للعملية الأكثر تكرارًا بلا مغادرة الصفحة.
  Future<BackupResult> exportData() async {
    isLoading.value = true;
    try {
      return await BackupService.createBackup();
    } finally {
      isLoading.value = false;
    }
  }

  /// استعادة نسخة من مسار محدَّد (تمرّ بالفحص ونسخة الأمان في الخدمة).
  Future<RestoreResult> importData(String backupPath) async {
    isLoading.value = true;
    try {
      final result = await BackupService.restoreBackup(backupPath);
      if (result.success) await loadSettings();
      return result;
    } finally {
      isLoading.value = false;
    }
  }

  Future<Map<String, dynamic>> getBackupInfo() async {
    try {
      final lastBackup = await BackupService.getLastBackupInfo();
      final backups = await BackupService.listBackups();

      final info = {
        'last_backup': lastBackup,
        'total_backups': backups.length,
        'backups': backups,
      };

      backupInfo.value = info;
      return info;
    } catch (e) {
      return {};
    }
  }
}
