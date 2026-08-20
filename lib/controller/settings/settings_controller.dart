import 'package:get/get.dart';
import 'package:laundry/sqldb.dart';
import 'package:laundry/services/database/backup_service.dart';

class SettingsController extends GetxController {
  final SqlDB _db = SqlDB();

  var settings = <String, String>{}.obs;
  var backupInfo = <String, dynamic>{}.obs;
  var isLoading = false.obs;

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

  Future<void> updateSetting(String key, String value) async {
    try {
      await _db.safeUpdate(
        'settings',
        {'value': value},
        where: 'key = ?',
        whereArgs: [key],
      );
      settings[key] = value;
      Get.snackbar('نجاح', 'تم تحديث الإعداد بنجاح');
    } catch (e) {
      Get.snackbar('خطأ', 'فشل في تحديث الإعداد: $e');
    }
  }

  Future<bool> exportData() async {
    isLoading.value = true;
    try {
      final path = await BackupService.createBackup();
      return path != null;
    } finally {
      isLoading.value = false;
    }
  }

  Future<bool> importData(String backupPath) async {
    isLoading.value = true;
    try {
      final success = await BackupService.restoreBackup(backupPath);
      if (success) {
        await loadSettings();
      }
      return success;
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
