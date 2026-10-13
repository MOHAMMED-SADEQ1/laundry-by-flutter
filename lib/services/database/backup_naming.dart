/// منطق تسمية النسخ الاحتياطية والتحقق من صلاحية ملفها.
///
/// **لماذا ملف منفصل:** هذا الجزء هو موضع الأخطاء الفعلي في النسخ الاحتياطي —
/// اسم فيه نقطتان يُرفض على Windows، واسم مكرر يمحو نسخة قائمة، وملف ليس
/// قاعدة بيانات يُستعاد فوق بيانات سليمة فيدمّرها. كل ذلك منطق حسابي خالص
/// (بلا Flutter وبلا قاعدة بيانات)، فُصل هنا ليُختبر بمشغّل Dart مباشر
/// (`dart run tool/verify_backup_logic.dart`) — نفس نهج `license_status`.
library;

class BackupNaming {
  BackupNaming._();

  /// امتداد النسخة الاحتياطية: ملف SQLite خام مطابق لملف قاعدة البيانات.
  static const String extension = 'db';

  /// بادئة اسم النسخة العادية.
  static const String prefix = 'laundry_pos';

  /// بادئة نسخة الأمان التي تُؤخذ **تلقائيًا قبل كل استعادة**.
  static const String safetyPrefix = 'pre_restore';

  /// ترويسة SQLite: أول 15 بايت + مُصفِّر. أي ملف بغيرها ليس قاعدة بيانات.
  static const String sqliteMagic = 'SQLite format 3';

  /// أحرف ممنوعة في أسماء الملفات (Windows يرفضها صراحةً، والقائمة تمثّل
  /// الاتحاد مع ما يمنعه Linux/macOS لتكون النسخة محمولة بين الأجهزة).
  static const String forbiddenChars = '\\/:*?"<>|';

  /// أسماء محجوزة على Windows: ملف بهذا الاسم لا يُنشأ مهما كان امتداده.
  static const Set<String> _reservedNames = {
    'con',
    'prn',
    'aux',
    'nul',
    'com1',
    'com2',
    'com3',
    'com4',
    'com5',
    'com6',
    'com7',
    'com8',
    'com9',
    'lpt1',
    'lpt2',
    'lpt3',
    'lpt4',
    'lpt5',
    'lpt6',
    'lpt7',
    'lpt8',
    'lpt9',
  };

  /// أحجام الصفحات الصحيحة في SQLite. (القيمة 1 تعني 65536 في الصيغة القديمة)
  static const Set<int> validPageSizes = {
    1,
    512,
    1024,
    2048,
    4096,
    8192,
    16384,
    32768,
    65536,
  };

  /// الاسم الافتراضي المقترح: `laundry_pos_2026-09-21_1430.db`.
  ///
  /// **لا نقطتان في الاسم:** `toIso8601String` ينتج `2026-09-21T14:30:00.000`
  /// وفيه `:` وهي محرفة بصريًا ومرفوضة على Windows. لذلك يُبنى الاسم يدويًا
  /// بجزء تاريخ وجزء وقت بلا فواصل زمنية، وهو أسهل للقراءة أيضًا.
  static String buildBackupFileName(DateTime when, {String? label}) {
    final d = when.toLocal();
    final date =
        '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
    final time =
        '${d.hour.toString().padLeft(2, '0')}'
        '${d.minute.toString().padLeft(2, '0')}';

    final base = '${prefix}_${date}_$time';
    final tag = (label ?? '').trim();
    if (tag.isEmpty) return '$base.$extension';
    return sanitizeBackupName('${base}_$tag');
  }

  /// اسم نسخة الأمان: `pre_restore_2026-09-21_1430.db`.
  static String buildSafetyFileName(DateTime when) {
    final d = when.toLocal();
    final date =
        '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
    final time =
        '${d.hour.toString().padLeft(2, '0')}'
        '${d.minute.toString().padLeft(2, '0')}'
        '${d.second.toString().padLeft(2, '0')}';
    return '${safetyPrefix}_${date}_$time.$extension';
  }

  /// تطبيع اسم أدخله المستخدم إلى اسم ملف صالح.
  ///
  /// يتحمّل كل ما يمكن أن يُدخله إنسان: أحرف ممنوعة، مسافات، امتداد مكرر أو
  /// مفقود، اسم منتهٍ بنقطة (قانوني في Linux ومرفوض على Windows)، واسم فارغ
  /// (يعود إلى [fallback] أو إلى الاسم الافتراضي بالتاريخ الحالي).
  static String sanitizeBackupName(String raw, {String? fallback}) {
    var name = raw.trim();

    // نزع أي مسار ألصقه المستخدم بالخطأ: نريد الاسم وحده.
    final sep = name.lastIndexOf(RegExp(r'[\\/]'));
    if (sep >= 0) name = name.substring(sep + 1);

    // الأحرف الممنوعة ومحارف التحكم ⇒ `_`.
    final buffer = StringBuffer();
    for (final rune in name.runes) {
      final ch = String.fromCharCode(rune);
      if (rune < 32 || rune == 127 || forbiddenChars.contains(ch)) {
        buffer.write('_');
      } else {
        buffer.write(ch);
      }
    }
    name = buffer.toString();

    // مسافات متتالية أو شرطات سفلية متتالية ⇒ واحدة.
    name = name.replaceAll(RegExp(r'[\s_]+'), '_');
    // نقاط متتالية ⇒ واحدة، ونقطة/شرطة في الطرفين تُنزع.
    name = name.replaceAll(RegExp(r'\.{2,}'), '.');
    name = name.replaceAll(RegExp(r'^[._\s]+|[._\s]+$'), '');

    if (name.isEmpty) {
      final fb = (fallback ?? '').trim();
      if (fb.isNotEmpty && fb != raw) {
        return sanitizeBackupName(fb, fallback: fb);
      }
      return buildBackupFileName(DateTime.now());
    }

    // الامتداد: يُضاف إن غاب، ولا يتكرر إن وُجد (`.db.db`).
    final lower = name.toLowerCase();
    if (!lower.endsWith('.$extension')) {
      if (lower.endsWith('.')) {
        name = '$name$extension';
      } else {
        name = '$name.$extension';
      }
    }

    // الاسم المحجوز على Windows: نُزيحه بدل الرفض فتبقى التسمية الحرّة ممكنة.
    final stem = name.substring(0, name.length - extension.length - 1);
    if (_reservedNames.contains(stem.toLowerCase())) {
      name = '_$name';
    }

    if (name.length > 120) {
      final keep = name.substring(0, 120 - extension.length - 1);
      name = '${keep.substring(0, keep.length - 1)}.$extension';
    }

    return name;
  }

  /// منع الكتابة فوق نسخة قائمة: يُضاف `_2`، `_3`... قبل الامتداد.
  ///
  /// **المقارنة بحروف صغيرة:** Windows وmacOS لا يفرّقان بين `Backup.db` و
  /// `backup.db`، فمقارنة حسّاسة بحالة الأحرف كانت ستسمح بكتابة فوق نسخة
  /// قائمة على هذين النظامين بينما تمنعها على Linux — سلوك غير متّسق.
  static String dedupeName(String name, Set<String> existing) {
    final taken = existing.map((e) => e.toLowerCase()).toSet();
    if (!taken.contains(name.toLowerCase())) return name;

    final dot = name.lastIndexOf('.');
    final stem = dot > 0 ? name.substring(0, dot) : name;
    final ext = dot > 0 ? name.substring(dot) : '';

    var counter = 2;
    var candidate = '${stem}_$counter$ext';
    while (taken.contains(candidate.toLowerCase())) {
      counter++;
      candidate = '${stem}_$counter$ext';
    }
    return candidate;
  }

  /// هل الملف قاعدة بيانات SQLite سليمة؟
  ///
  /// يقرأ أول [headerLength] بايت ويفحص: الترويسة السحرية، ومُصفِّر البايت
  /// السادس عشر، وحجم الصفحة المسجَّل. هذا يرفض ZIP وJSON والنصوص والملفات
  /// الفارغة والمقتطعة — أي كل ما قد يُختار بالخطأ من متصفح الملفات.
  static bool validateBackupHeader(List<int> head) {
    const headerLength = 100;
    if (head.length < headerLength) return false;

    for (var i = 0; i < sqliteMagic.length; i++) {
      if (head[i] != sqliteMagic.codeUnitAt(i)) return false;
    }
    if (head[15] != 0) return false;

    final pageSize = (head[16] << 8) | head[17];
    return validPageSizes.contains(pageSize);
  }

  /// هل الاسم يبدو نسخة أمان أخذها النظام قبل الاستعادة؟
  static bool isSafetyBackupName(String fileName) {
    return fileName.toLowerCase().startsWith('${safetyPrefix}_');
  }

  /// هل هذا مسار ملف قاعدة البيانات الحيّ نفسه؟ (استعادته فوق نفسه عبثية)
  static bool isSamePath(String a, String b) {
    String norm(String p) => p.replaceAll('\\', '/').replaceAll(
      RegExp(r'/+'),
      '/',
    ).toLowerCase();
    return norm(a) == norm(b);
  }

  /// حجم مقروء للعرض: `12.4 KB` / `3.1 MB`.
  static String formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    final kb = bytes / 1024;
    if (kb < 1024) return '${kb.toStringAsFixed(1)} KB';
    final mb = kb / 1024;
    if (mb < 1024) return '${mb.toStringAsFixed(1)} MB';
    return '${(mb / 1024).toStringAsFixed(2)} GB';
  }
}
