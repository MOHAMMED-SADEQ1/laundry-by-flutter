import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:laundry/config/constants.dart';
import 'package:laundry/services/database/backup_naming.dart';
import 'package:laundry/services/security/session_manager.dart';
import 'package:laundry/sqldb.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

/// وصف ملف نسخة احتياطية بعد فحصه قبل أي استعادة.
///
/// **لماذا:** الاستعادة تستبدل قاعدة البيانات كلها؛ فحص الملف أولًا هو الفرق
/// بين «اخترت الملف الخطأ» و«ضاعت بياناتك». لا يُستعاد ملف لم يُنتج
/// [valid] = true.
class BackupFileInfo {
  final bool valid;

  /// سبب الرفض بالعربية — يُعرض للمستخدم كما هو.
  final String? reason;

  final int sizeBytes;
  final String fileName;
  final int invoiceCount;
  final int userCount;
  final DateTime? lastInvoiceAt;
  final DateTime? modifiedAt;

  /// إصدار بنية قاعدة البيانات **المخزَّن في الملف** (`PRAGMA user_version`).
  ///
  /// يُقارن بإصدار التطبيق قبل أي استعادة: ملف من إصدار أحدث يُرفض، لأن فتحه
  /// يفشل في كل طلب بعد الاستعادة فيتوقف النظام كله.
  final int schemaVersion;

  const BackupFileInfo({
    required this.valid,
    this.reason,
    this.sizeBytes = 0,
    this.fileName = '',
    this.invoiceCount = 0,
    this.userCount = 0,
    this.lastInvoiceAt,
    this.modifiedAt,
    this.schemaVersion = 0,
  });

  static BackupFileInfo rejected(String reason, {int sizeBytes = 0}) =>
      BackupFileInfo(valid: false, reason: reason, sizeBytes: sizeBytes);
}

/// نتيجة إنشاء نسخة احتياطية.
class BackupResult {
  final bool success;

  /// ألغى المستخدم اختيار الوجهة لكن النسخة الداخلية أُخذت فعلًا.
  final bool cancelled;

  /// النسخة الدائمة داخل التطبيق (تظهر في القائمة دائمًا).
  final String? archivePath;

  /// الملف الذي اختار المستخدم حفظ النسخة فيه.
  final String? savedPath;

  final String? error;
  final int sizeBytes;

  const BackupResult({
    required this.success,
    this.cancelled = false,
    this.archivePath,
    this.savedPath,
    this.error,
    this.sizeBytes = 0,
  });

  static BackupResult failure(String error) =>
      BackupResult(success: false, error: error);
}

/// نتيجة الاستعادة.
class RestoreResult {
  final bool success;
  final String? error;
  final String? safetyPath;
  final BackupFileInfo? restoredFrom;

  /// فشل ما بعد النسخ فأُعيدت بيانات المستخدم السابقة (لا خسارة).
  final bool rolledBack;

  const RestoreResult({
    required this.success,
    this.error,
    this.safetyPath,
    this.restoredFrom,
    this.rolledBack = false,
  });

  static RestoreResult failure(String error, {bool rolledBack = false}) =>
      RestoreResult(success: false, error: error, rolledBack: rolledBack);
}

/// النسخ الاحتياطي والاستعادة.
///
/// **الصيغة:** ملف **SQLite خام بامتداد `.db`** — نسخة مطابقة لقاعدة بيانات
/// النظام، تُفتح بأي أداة SQLite وتُستعاد مباشرة (لا ZIP ولا JSON). هذا أبسط
/// شيء وأقلّه عرضة للأعطال، ولذلك بقي كما هو.
///
/// **المكان:** كل نسخة تُحفظ **مرتين**:
///  1. داخل التطبيق (`<documents>/laundry_backup/`) — تظهر في القائمة دائمًا،
///     ولا تضيع إن ألغى المستخدم حوار الحفظ أو لم يجد الملف لاحقًا.
///  2. حيث يختار المستخدم عبر منتقي الملفات (ذاكرة الجهاز، سطح المكتب...).
///
/// **اللقطة المتّسقة:** النسخة تُبنى بـ`VACUUM INTO` من قاعدة البيانات
/// المفتوحة (لا بنسخ الملف مباشرة)، فيخرج ملف نظيف بلا صفحات معلّقة في journal.
/// وإن كانت نسخة SQLite على الجهاز أقدم من دعم الأمر (ما قبل 3.27) يُسجَّل
/// السبب ويُعوَّض بنسخ مباشر بعد `wal_checkpoint`.
class BackupService {
  BackupService._();

  static const String _folderName = 'laundry_backup';
  static const String _prefLastBackup = 'last_backup';
  static const String _prefLastBackupPath = 'last_backup_path';
  static const String _prefLastRestore = 'last_restore';
  static const String _prefLastExportDir = 'last_backup_export_dir';

  /// مسار آخر نسخة أمان — مفتاح منفصل عمدًا حتى لا يختلط بـ`last_backup_path`
  /// فلا يظن المستخدم أن «آخر نسخة» التي أخذها بنفسه هي نسخة الأمان.
  static const String _prefLastSafety = 'last_safety_backup_path';

  /// جداول لا بد من وجودها ليكون الملف نسخة من **هذا** النظام لا غيره.
  /// (`audit_log` مستثنى عمدًا: نسخة قديمة أُخذت قبل إضافته تبقى صالحة.)
  static const List<String> requiredTables = [
    'users',
    'settings',
    'invoices',
    'shifts',
  ];

  /// حد حجم النسخة التي تُمرَّر كـ`bytes` لمنتقي الملفات على الجوال.
  /// تجاوزه يعني تحميل القاعدة كاملة في الذاكرة ⇒ خطر نفاد ذاكرة.
  static const int _mobilePickerLimit = 200 * 1024 * 1024;

  // ──────────────────────────────────────────────
  // المسارات
  // ──────────────────────────────────────────────

  static Future<Directory> _archiveDir() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(
      '${docs.path}${Platform.pathSeparator}$_folderName',
    );
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  /// مجلد النسخ الداخلية — يُعرض للمستخدم ليعرف أين تُحفظ النسخ.
  static Future<String> archiveDirectoryPath() async =>
      (await _archiveDir()).path;

  static Future<Set<String>> _existingNames(Directory dir) async {
    if (!await dir.exists()) return {};
    final names = <String>{};
    await for (final entity in dir.list()) {
      if (entity is File) {
        names.add(entity.path.split(Platform.pathSeparator).last);
      }
    }
    return names;
  }

  /// ملفات الجانب التي تُنشئها SQLite بجانب القاعدة. وجودها مع ملف **مستبدَل**
  /// قد يُفسد القاعدة المستعادة (صفحات من قاعدة أخرى)، فتُحذف قبل أي نسخ.
  static Future<void> _deleteSidecars(String dbPath) async {
    for (final suffix in ['-wal', '-shm', '-journal']) {
      final f = File('$dbPath$suffix');
      try {
        if (await f.exists()) await f.delete();
      } catch (e) {
        debugPrint('تعذّر حذف $suffix: $e');
      }
    }
  }

  // ──────────────────────────────────────────────
  // اللقطة
  // ──────────────────────────────────────────────

  /// يكتب لقطة نظيفة من قاعدة البيانات الحيّة إلى [destination].
  static Future<void> _snapshotTo(
    String destination,
    String livePath,
  ) async {
    final out = File(destination);
    if (await out.exists()) await out.delete();

    final db = await SqlDB().dbGet;
    if (db != null && db.isOpen) {
      try {
        // VACUUM INTO يعطي ملفًا نظيفًا ومضغوطًا بلا صفحات معلّقة.
        await db.execute('VACUUM INTO ?', [destination]);
        if (await out.exists()) return;
      } catch (e) {
        debugPrint('VACUUM INTO غير مدعوم على هذا الجهاز، نسخ مباشر: $e');
      }
      try {
        await db.rawQuery('PRAGMA wal_checkpoint(FULL)');
      } catch (e) {
        debugPrint('wal_checkpoint failed: $e');
      }
    }

    final live = File(livePath);
    await live.copy(destination);
  }

  // ──────────────────────────────────────────────
  // فحص ملف النسخة قبل الاستعادة
  // ──────────────────────────────────────────────

  /// فحص شامل: ترويسة SQLite + سلامة البنية + وجود جداول النظام.
  ///
  /// ثلاثة حواجز لأن خطأ واحدًا هنا = بيانات ضائعة:
  ///  - الترويسة ترفض ZIP/JSON/نصًا/ملفًا فارغًا/مقتطعًا.
  ///  - تحليل الملف **قراءة فقط** (`singleInstance: false`) حتى لا يمسّ
  ///    قاعدة البيانات الحيّة ولا ينشئ ملفات جانب.
  ///  - `integrity_check` ووجود الجداول يرفضان قاعدة من نظام آخر.
  static Future<BackupFileInfo> inspectBackupFile(String path) async {
    final file = File(path);
    if (!await file.exists()) {
      return BackupFileInfo.rejected('ملف النسخة الاحتياطية غير موجود');
    }

    final stat = await file.stat();
    final size = stat.size;
    if (size < 512) {
      return BackupFileInfo.rejected(
        'الملف فارغ أو أصغر من أن يكون قاعدة بيانات (${BackupNaming.formatSize(size)})',
        sizeBytes: size,
      );
    }

    // 1) الترويسة
    RandomAccessFile? raf;
    try {
      raf = await file.open();
      final head = await raf.read(100);
      if (!BackupNaming.validateBackupHeader(head)) {
        return BackupFileInfo.rejected(
          'هذا ليس ملف قاعدة بيانات SQLite — تأكد أنك اخترت ملف نسخة احتياطية (‎.db‎)',
          sizeBytes: size,
        );
      }
    } catch (e) {
      return BackupFileInfo.rejected('تعذّر قراءة الملف: $e', sizeBytes: size);
    } finally {
      try {
        await raf?.close();
      } catch (_) {}
    }

    // 2) البنية الداخلية
    Database? probe;
    try {
      probe = await openDatabase(path, readOnly: true, singleInstance: false);

      final integrity = await probe.rawQuery('PRAGMA integrity_check');
      final verdict = integrity.isEmpty
          ? ''
          : '${integrity.first.values.first}'.toLowerCase();
      if (verdict != 'ok') {
        return BackupFileInfo.rejected(
          'الملف تالف — فحص السلامة أفاد: ${verdict.isEmpty ? 'بلا نتيجة' : verdict}',
          sizeBytes: size,
        );
      }

      final tableRows = await probe.rawQuery(
        "SELECT name FROM sqlite_master WHERE type = 'table'",
      );
      final tables = tableRows.map((r) => '${r['name']}').toSet();
      final missing = requiredTables
          .where((t) => !tables.contains(t))
          .toList();
      if (missing.isNotEmpty) {
        return BackupFileInfo.rejected(
          'الملف لا يحوي جداول هذا النظام (المفقود: ${missing.join('، ')}) '
          '— قد يكون قاعدة بيانات نظام آخر',
          sizeBytes: size,
        );
      }

      // 3) إصدار البنية — حارس يمنع استعادة ملف أحدث مما يفهمه التطبيق.
      final versionRows = await probe.rawQuery('PRAGMA user_version');
      final schemaVersion = versionRows.isEmpty
          ? 0
          : ((versionRows.first.values.first ?? 0) as num).toInt();
      if (schemaVersion > AppConstants.dbVersion) {
        return BackupFileInfo.rejected(
          'هذه النسخة من إصدار أحدث من النظام (بنية $schemaVersion مقابل '
          '$AppConstants.dbVersion) — حدّث التطبيق أولًا ثم أعد المحاولة',
          sizeBytes: size,
        );
      }

      final invoiceCount = await _count(probe, 'invoices');
      final userCount = await _count(probe, 'users');
      final lastRows = await probe.rawQuery(
        'SELECT MAX(invoice_date) AS m FROM invoices',
      );
      final lastRaw = lastRows.isEmpty ? null : lastRows.first['m'];

      return BackupFileInfo(
        valid: true,
        sizeBytes: size,
        fileName: path.split(Platform.pathSeparator).last,
        invoiceCount: invoiceCount,
        userCount: userCount,
        lastInvoiceAt: lastRaw == null
            ? null
            : DateTime.tryParse('$lastRaw'),
        modifiedAt: stat.modified,
        schemaVersion: schemaVersion,
      );
    } catch (e) {
      return BackupFileInfo.rejected(
        'تعذّر فتح الملف كقاعدة بيانات: $e',
        sizeBytes: size,
      );
    } finally {
      try {
        await probe?.close();
      } catch (_) {}
    }
  }

  static Future<int> _count(Database db, String table) async {
    final rows = await db.rawQuery('SELECT COUNT(*) AS c FROM "$table"');
    if (rows.isEmpty) return 0;
    return ((rows.first['c'] ?? 0) as num).toInt();
  }

  // ──────────────────────────────────────────────
  // الإنشاء
  // ──────────────────────────────────────────────

  /// اسم مقترح للنسخة الجديدة: `laundry_pos_2026-09-21_1430.db`.
  static String suggestedFileName({String? label}) =>
      BackupNaming.buildBackupFileName(DateTime.now(), label: label);

  /// إنشاء نسخة احتياطية.
  ///
  /// [fileName] الاسم المطلوب (يُطبَّع ويُمنع تكراره تلقائيًا).
  /// [directoryPath] وجهة مباشرة بلا حوار (للاستخدام البرمجي/الاختبارات).
  /// [askDestination] عند `false` تُحفظ النسخة الداخلية فقط.
  static Future<BackupResult> createBackup({
    String? fileName,
    String? directoryPath,
    bool askDestination = true,
  }) async {
    Directory? tempDir;
    try {
      final db = SqlDB();
      final dbPath = await db.getDatabasePath();
      if (!await File(dbPath).exists()) {
        return BackupResult.failure('قاعدة البيانات غير موجودة');
      }

      // 1) لقطة متّسقة في مجلد مؤقت
      tempDir = await Directory.systemTemp.createTemp('laundry_backup_');
      final snapshot = '${tempDir.path}${Platform.pathSeparator}snapshot.db';
      await _snapshotTo(snapshot, dbPath);

      final snapInfo = await inspectBackupFile(snapshot);
      if (!snapInfo.valid) {
        return BackupResult.failure(
          'تعذّر إنشاء نسخة سليمة: ${snapInfo.reason ?? 'سبب غير معروف'}',
        );
      }
      final size = snapInfo.sizeBytes;

      // 2) النسخة الداخلية الدائمة (لا تفرغ القائمة أبدًا)
      final archiveDir = await _archiveDir();
      final desired = BackupNaming.sanitizeBackupName(
        (fileName ?? '').trim().isEmpty
            ? suggestedFileName()
            : fileName!.trim(),
      );
      final archiveName = BackupNaming.dedupeName(
        desired,
        await _existingNames(archiveDir),
      );
      final archivePath =
          '${archiveDir.path}${Platform.pathSeparator}$archiveName';
      await File(snapshot).copy(archivePath);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefLastBackup, DateTime.now().toIso8601String());
      await prefs.setString(_prefLastBackupPath, archivePath);

      // 3) الوجهة الخارجية التي يختارها المستخدم
      String? savedPath;
      bool cancelled = false;

      if (directoryPath != null && directoryPath.trim().isNotEmpty) {
        final dir = Directory(directoryPath.trim());
        if (!await dir.exists()) await dir.create(recursive: true);
        final targetName = BackupNaming.dedupeName(
          desired,
          await _existingNames(dir),
        );
        savedPath = '${dir.path}${Platform.pathSeparator}$targetName';
        await File(snapshot).copy(savedPath);
      } else if (askDestination) {
        final chosen = await _askDestination(desired, snapshot);
        if (chosen == null) {
          cancelled = true;
        } else {
          savedPath = _ensureExtension(chosen);
          // على سطح المكتب `saveFile` يعيد المسار فقط ولا يكتب؛ على الجوال
          // كتبه الـplugin من `bytes` بنفسه.
          if (!(Platform.isAndroid || Platform.isIOS)) {
            if (!BackupNaming.isSamePath(savedPath, snapshot)) {
              await File(snapshot).copy(savedPath);
            }
          }
        }
      }

      await _log(
        action: 'backup_create',
        newValues:
            '{"archive":"$archivePath","saved":"${savedPath ?? ''}","size":$size}',
      );

      return BackupResult(
        success: true,
        cancelled: cancelled,
        archivePath: archivePath,
        savedPath: savedPath,
        sizeBytes: size,
      );
    } catch (e) {
      return BackupResult.failure('فشل في إنشاء النسخة الاحتياطية: $e');
    } finally {
      // المجلد المؤقت يُنظَّف دائمًا حتى عند الفشل.
      try {
        if (tempDir != null && await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      } catch (_) {}
    }
  }

  /// حوار «احفظ باسم» — الفرق بين الجوال وسطح المكتب في من يكتب الملف.
  static Future<String?> _askDestination(
    String suggestedName,
    String snapshot,
  ) async {
    final isMobile = Platform.isAndroid || Platform.isIOS;
    final prefs = await SharedPreferences.getInstance();
    final lastDir = prefs.getString(_prefLastExportDir);

    if (isMobile) {
      final size = await File(snapshot).length();
      if (size > _mobilePickerLimit) {
        throw Exception(
          'حجم النسخة (${BackupNaming.formatSize(size)}) أكبر من أن تُحفظ '
          'عبر منتقي الملفات على الجوال؛ احفظها داخل التطبيق ثم انسخها.',
        );
      }
      final bytes = await File(snapshot).readAsBytes();
      final path = await FilePicker.platform.saveFile(
        dialogTitle: 'حفظ النسخة الاحتياطية',
        fileName: suggestedName,
        bytes: bytes,
      );
      if (path != null) {
        final sep = path.lastIndexOf(Platform.pathSeparator);
        if (sep > 0) {
          await prefs.setString(_prefLastExportDir, path.substring(0, sep));
        }
      }
      return path;
    }

    final path = await FilePicker.platform.saveFile(
      dialogTitle: 'حفظ النسخة الاحتياطية',
      fileName: suggestedName,
      type: FileType.custom,
      allowedExtensions: [BackupNaming.extension],
      initialDirectory:
          (lastDir != null && lastDir.isNotEmpty && Directory(lastDir).existsSync())
          ? lastDir
          : null,
    );
    if (path != null) {
      final sep = path.lastIndexOf(Platform.pathSeparator);
      if (sep > 0) await prefs.setString(_prefLastExportDir, path.substring(0, sep));
    }
    return path;
  }

  /// يكمل الامتداد إن كتب المستخدم الاسم بلا `.db`.
  static String _ensureExtension(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.${BackupNaming.extension}')) return path;
    if (lower.endsWith('.')) return '$path${BackupNaming.extension}';
    return '$path.${BackupNaming.extension}';
  }

  // ──────────────────────────────────────────────
  // الاستعادة
  // ──────────────────────────────────────────────

  /// استعادة نسخة **مع حماية كاملة**.
  ///
  /// الترتيب مقصود ولا يجوز تبديله:
  ///  1. فحص الملف ⇒ رفض بلا لمس أي بيانات.
  ///  2. نسخة أمان من بيانات الحالية **والتحقق من صحتها** قبل الاعتماد عليها.
  ///  3. إغلاق القاعدة و**بوابة صيانة** تمنع أي إعادة فتح، ثم حذف ملفات الجانب
  ///     والنسخ فوق القاعدة.
  ///  4. فحص ما بعد النسخ؛ فإن فشل ⇒ **رجوع تلقائي** من نسخة الأمان.
  ///
  /// الخطوة 4 هي التي تحوّل أخطر عملية في النظام من «لا رجعة» إلى محمية،
  /// والبوابة في الخطوة 3 هي التي تمنع «تعطّل النظام بعد الاستعادة».
  static Future<RestoreResult> restoreBackup(String backupPath) async {
    final db = SqlDB();

    try {
      final dbPath = await db.getDatabasePath();

      if (BackupNaming.isSamePath(backupPath, dbPath)) {
        return RestoreResult.failure(
          'هذا ملف قاعدة البيانات الحيّة نفسه، وليس نسخة احتياطية',
        );
      }

      // 1) فحص المصدر
      final source = await inspectBackupFile(backupPath);
      if (!source.valid) {
        return RestoreResult.failure(
          source.reason ?? 'ملف النسخة الاحتياطية غير صالح',
        );
      }

      // 2) نسخة أمان من الحالة الراهنة
      String? safetyPath;
      if (await File(dbPath).exists()) {
        final archiveDir = await _archiveDir();
        final safetyName = BackupNaming.dedupeName(
          BackupNaming.buildSafetyFileName(DateTime.now()),
          await _existingNames(archiveDir),
        );
        final candidate =
            '${archiveDir.path}${Platform.pathSeparator}$safetyName';
        await _snapshotTo(candidate, dbPath);

        final safetyInfo = await inspectBackupFile(candidate);
        if (!safetyInfo.valid) {
          try {
            await File(candidate).delete();
          } catch (_) {}
          return RestoreResult.failure(
            'تعذّر أخذ نسخة أمان سليمة من بياناتك الحالية، فأُوقفت الاستعادة '
            'لحمايتها (${safetyInfo.reason ?? 'سبب غير معروف'})',
          );
        }
        safetyPath = candidate;
      }

      // 3) الاستبدال — **داخل بوابة صيانة**: تُوقف كل طلب قاعدة بيانات
      // (مؤقت الترخيص، أي شاشة مفتوحة) فلا يبقى اتصال حيّ على الملف أثناء
      // نسخ فوقه، وهي اللحظة التي كانت تُسقط النظام بعد الاستعادة.
      final endMaintenance = SqlDB.beginMaintenance();
      var after = const BackupFileInfo(valid: false);
      try {
        await softlyClose();
        await _deleteSidecars(dbPath);
        await File(backupPath).copy(dbPath);

        // 4) فحص ما بعد النسخ + الرجوع عند الفشل
        after = await inspectBackupFile(dbPath);
        if (!after.valid) {
          var rolledBack = false;
          if (safetyPath != null) {
            try {
              await softlyClose();
              await _deleteSidecars(dbPath);
              await File(safetyPath).copy(dbPath);
              rolledBack = (await inspectBackupFile(dbPath)).valid;
            } catch (e) {
              debugPrint('فشل الرجوع التلقائي: $e');
            }
          }
          return RestoreResult.failure(
            'فشل فحص البيانات بعد الاستعادة (${after.reason ?? 'سبب غير معروف'})'
            '${rolledBack ? ' — وأُعيدت بياناتك السابقة كما كانت' : ' — تعذّر الرجوع؛ استعد نسخة الأمان يدويًا'}',
            rolledBack: rolledBack,
          );
        }
      } finally {
        // البوابة تُفتح في كل الحالات، ولا يُترك النظام مغلقًا أبدًا.
        await endMaintenance();
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefLastRestore, DateTime.now().toIso8601String());
      if (safetyPath != null) {
        await prefs.setString(_prefLastSafety, safetyPath);
      }

      final safetyForLog = safetyPath ?? '';
      await _log(
        action: 'backup_restore',
        newValues:
            '{"from":"$backupPath","invoices":${after.invoiceCount},'
            '"safety":"$safetyForLog"}',
      );

      return RestoreResult(
        success: true,
        safetyPath: safetyPath,
        restoredFrom: after,
      );
    } catch (e) {
      return RestoreResult.failure('فشل في استعادة النسخة الاحتياطية: $e');
    }
  }

  /// إغلاق القاعدة بلطف: قد تكون مغلقة أصلًا (بعد نسخ ملف فوقها) فلا يُعدّ
  /// ذلك خطأً يُسقط العملية.
  static Future<void> softlyClose() async {
    try {
      await SqlDB().closeDB();
    } catch (e) {
      debugPrint('closeDB: $e');
    }
  }

  // ──────────────────────────────────────────────
  // القائمة والصيانة
  // ──────────────────────────────────────────────

  /// كل النسخ الداخلية، الأحدث أولًا، مع وسم نسخ الأمان.
  static Future<List<Map<String, dynamic>>> listBackups() async {
    try {
      final dir = await _archiveDir();
      final files = await dir
          .list()
          .where((f) => f is File && f.path.endsWith('.${BackupNaming.extension}'))
          .toList();

      final backups = <Map<String, dynamic>>[];
      for (final file in files) {
        final stat = await file.stat();
        final name = file.path.split(Platform.pathSeparator).last;
        backups.add({
          'path': file.path,
          'name': name,
          'size': stat.size,
          'size_label': BackupNaming.formatSize(stat.size),
          'modified': stat.modified,
          'is_safety': BackupNaming.isSafetyBackupName(name),
        });
      }

      backups.sort(
        (a, b) =>
            (b['modified'] as DateTime).compareTo(a['modified'] as DateTime),
      );
      return backups;
    } catch (e) {
      debugPrint('listBackups: $e');
      return [];
    }
  }

  /// حذف نسخة. **يُمنع** حذف أحدث نسخة أمان: هي شبكة الرجوع الوحيدة بعد
  /// استعادة خاطئة، فيجب أن تبقى حتى تُستبدل بأحدث منها.
  static Future<String?> deleteBackup(String path) async {
    try {
      final all = await listBackups();
      final safety = all.where((b) => b['is_safety'] == true).toList();
      if (safety.isNotEmpty && safety.first['path'] == path) {
        return 'لا يمكن حذف أحدث نسخة أمان — هي مسار الرجوع بعد أي استعادة خاطئة';
      }

      final file = File(path);
      if (await file.exists()) await file.delete();
      return null;
    } catch (e) {
      return 'تعذّر حذف الملف: $e';
    }
  }

  static Future<Map<String, dynamic>?> getLastBackupInfo() async {
    final prefs = await SharedPreferences.getInstance();
    final lastBackup = prefs.getString(_prefLastBackup);
    if (lastBackup == null) return null;
    return {
      'date': lastBackup,
      'path': prefs.getString(_prefLastBackupPath),
      'restore': prefs.getString(_prefLastRestore),
      'safety': prefs.getString(_prefLastSafety),
    };
  }

  /// منتقي ملف استعادة من أي مكان على الجهاز (نسخة وصلت عبر واتساب مثلًا).
  static Future<String?> pickBackupFile() async {
    // **بلا فلترة امتدادات عمدًا:** منتقي أندرويد يخفي الملفات التي لا تطابق
    // الفلتر، ونسخة وصلت عبر واتساب قد تُسمّى `.bin` فتصبح غير مرئية أصلًا.
    // والحارس الحقيقي هو محتوى الملف (`inspectBackupFile`)، لا اسمه — فهو
    // يرفض أي ملف ليس قاعدة سليمة من هذا النظام برسالة عربية واضحة.
    final result = await FilePicker.platform.pickFiles(
      dialogTitle: 'اختر ملف النسخة الاحتياطية',
      type: FileType.any,
      allowMultiple: false,
    );
    if (result == null || result.files.isEmpty) return null;
    return result.files.single.path;
  }

  static Future<void> _log({
    required String action,
    String? oldValues,
    String? newValues,
  }) async {
    try {
      await SqlDB().logAudit(
        userId: SessionManager.currentUserId,
        action: action,
        tableName: 'database',
        oldValues: oldValues,
        newValues: newValues,
      );
    } catch (e) {
      // سجل التدقيق أثر لا يُسقط العملية: نسخة قديمة قد لا تحوي الجدول.
      debugPrint('audit ($action): $e');
    }
  }
}
