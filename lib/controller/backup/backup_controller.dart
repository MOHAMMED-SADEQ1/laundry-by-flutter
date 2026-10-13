import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:laundry/services/database/backup_service.dart';

/// صف نسخة احتياطية كما تعرضه الشاشة.
///
/// يغلّف خريطة الخدمة في نوع واحد حتى لا تتكرر عمليات `as` والتحويلات
/// النصية داخل الواجهة.
class BackupEntry {
  final String path;
  final String name;
  final int sizeBytes;
  final String sizeLabel;
  final DateTime? modifiedAt;
  final bool isSafety;

  const BackupEntry({
    required this.path,
    required this.name,
    required this.sizeBytes,
    required this.sizeLabel,
    this.modifiedAt,
    this.isSafety = false,
  });

  factory BackupEntry.fromMap(Map<String, dynamic> m) {
    final raw = m['modified'];
    return BackupEntry(
      path: '${m['path'] ?? ''}',
      name: '${m['name'] ?? ''}',
      sizeBytes: ((m['size'] ?? 0) as num).toInt(),
      sizeLabel: '${m['size_label'] ?? m['size'] ?? ''}',
      modifiedAt: raw is DateTime ? raw : DateTime.tryParse('$raw'),
      isSafety: m['is_safety'] == true,
    );
  }

  /// «نسخة أمان» أخذها النظام تلقائيًا قبل استعادة — لا يحذفها المستخدم.
  String get kindLabel => isSafety ? 'نسخة أمان تلقائية' : 'نسخة عادية';
}

/// متحكّم شاشة النسخ الاحتياطي.
///
/// **لماذا متحكّم منفصل:** العمليات هنا **خطر على البيانات** (الاستعادة تستبدل
/// القاعدة كلها)، فيجب أن تكون كلها في مسار واحد يمرّ بالفحص ونسخة الأمان،
/// ولا يستدعيها أحد بلا المرور بها.
class BackupController extends GetxController {
  final RxList<BackupEntry> backups = <BackupEntry>[].obs;
  final RxBool isLoading = false.obs;
  final RxBool isBusy = false.obs;
  final RxString archiveDir = ''.obs;
  final RxString lastBackupLabel = ''.obs;
  final RxString lastRestoreLabel = ''.obs;

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load() async {
    isLoading.value = true;
    try {
      final rows = await BackupService.listBackups();
      backups.assignAll(rows.map(BackupEntry.fromMap));
      archiveDir.value = await BackupService.archiveDirectoryPath();

      final info = await BackupService.getLastBackupInfo();
      lastBackupLabel.value = _label(info?['date']);
      lastRestoreLabel.value = _label(info?['restore']);
    } catch (e) {
      debugPrint('BackupController.load: $e');
    } finally {
      isLoading.value = false;
    }
  }

  static String _label(dynamic raw) {
    if (raw == null) return '';
    final d = DateTime.tryParse('$raw');
    if (d == null) return '';
    final l = d.toLocal();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${l.year}-${two(l.month)}-${two(l.day)}  ${two(l.hour)}:${two(l.minute)}';
  }

  /// إنشاء نسخة (باسم مقترح ووجهة يختارها المستخدم).
  Future<BackupResult?> createNew({String? name}) async {
    if (isBusy.value) return null;
    isBusy.value = true;
    try {
      final result = await BackupService.createBackup(fileName: name);
      if (result.success) await load();
      return result;
    } finally {
      isBusy.value = false;
    }
  }

  /// استعادة من مسار محدَّد — تمرّ بالفحص ونسخة الأمان والرجوع التلقائي.
  Future<RestoreResult?> restore(String path) async {
    if (isBusy.value) return null;
    isBusy.value = true;
    try {
      final result = await BackupService.restoreBackup(path);
      if (result.success) await load();
      return result;
    } finally {
      isBusy.value = false;
    }
  }

  /// استعادة من ملف يختاره المستخدم من أي مكان على الجهاز.
  Future<String?> pickFile() => BackupService.pickBackupFile();

  Future<String?> delete(String path) async {
    final error = await BackupService.deleteBackup(path);
    if (error == null) await load();
    return error;
  }

  /// فحص ملف دون استعادة — لعرض ماذا سيُستعاد قبل التنفيذ.
  Future<BackupFileInfo> inspect(String path) =>
      BackupService.inspectBackupFile(path);
}
