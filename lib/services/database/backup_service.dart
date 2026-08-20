import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';
import 'package:laundry/sqldb.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';

class BackupService {
  static Future<String?> createBackup() async {
    try {
      final db = SqlDB();
      final dbPath = await db.getDatabasePath();
      final dbFile = File(dbPath);

      if (!await dbFile.exists()) {
        Get.snackbar(
          'خطأ',
          'قاعدة البيانات غير موجودة',
          snackPosition: SnackPosition.BOTTOM,
        );
        return null;
      }

      final backupDir = await getApplicationDocumentsDirectory();
      final backupPath = '${backupDir.path}/laundry_backup';
      final dir = Directory(backupPath);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }

      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
      final backupFile = File('$backupPath/laundry_pos_$timestamp.db');
      await dbFile.copy(backupFile.path);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('last_backup', DateTime.now().toIso8601String());
      await prefs.setString('last_backup_path', backupFile.path);

      Get.snackbar(
        'نجاح',
        'تم إنشاء النسخة الاحتياطية بنجاح',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.green,
        colorText: Colors.white,
        icon: Icon(Icons.check_circle, color: Colors.white),
      );
      return backupFile.path;
    } catch (e) {
      Get.snackbar(
        'خطأ',
        'فشل في إنشاء النسخة الاحتياطية: $e',
        snackPosition: SnackPosition.BOTTOM,
      );
      return null;
    }
  }

  static Future<bool> restoreBackup(String backupPath) async {
    try {
      final backupFile = File(backupPath);
      if (!await backupFile.exists()) {
        Get.snackbar(
          'خطأ',
          'ملف النسخة الاحتياطية غير موجود',
          snackPosition: SnackPosition.BOTTOM,
        );
        return false;
      }

      final db = SqlDB();
      final dbPath = await db.getDatabasePath();
      await db.closeDB();
      await backupFile.copy(dbPath);

      Get.snackbar(
        'نجاح',
        'تم استعادة النسخة الاحتياطية بنجاح',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.green,
        colorText: Colors.white,
        icon: Icon(Icons.check_circle, color: Colors.white),
      );
      return true;
    } catch (e) {
      Get.snackbar(
        'خطأ',
        'فشل في استعادة النسخة الاحتياطية: $e',
        snackPosition: SnackPosition.BOTTOM,
      );
      return false;
    }
  }

  static Future<List<Map<String, dynamic>>> listBackups() async {
    try {
      final backupDir = await getApplicationDocumentsDirectory();
      final backupPath = '${backupDir.path}/laundry_backup';
      final dir = Directory(backupPath);

      if (!await dir.exists()) return [];

      final files =
          await dir.list().where((f) => f.path.endsWith('.db')).toList();
      final backups = <Map<String, dynamic>>[];

      for (final file in files) {
        final stat = await file.stat();
        backups.add({
          'path': file.path,
          'name': file.path.split(Platform.pathSeparator).last,
          'size': stat.size,
          'modified': stat.modified,
        });
      }

      backups.sort(
        (a, b) =>
            (b['modified'] as DateTime).compareTo(a['modified'] as DateTime),
      );
      return backups;
    } catch (e) {
      return [];
    }
  }

  static Future<bool> deleteBackup(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  static Future<Map<String, dynamic>?> getLastBackupInfo() async {
    final prefs = await SharedPreferences.getInstance();
    final lastBackup = prefs.getString('last_backup');
    final lastPath = prefs.getString('last_backup_path');
    if (lastBackup == null) return null;
    return {'date': lastBackup, 'path': lastPath};
  }
}
