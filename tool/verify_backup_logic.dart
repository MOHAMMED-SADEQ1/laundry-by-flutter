// فحوص منطق النسخ الاحتياطي الخالص — بلا Flutter وبلا قاعدة بيانات.
//
// التشغيل:  dart run tool/verify_backup_logic.dart
//
// **لماذا:** كل خطأ هنا يُكلّف بيانات: اسم فيه نقطتان يُرفض على Windows،
// واسم مكرر يمحو نسخة قائمة، وملف ليس قاعدة بيانات يُستعاد فوق بيانات سليمة.
// لذلك يُختبر المنطق مباشرة لا عبر الواجهة.
// ignore_for_file: avoid_print

import 'dart:convert';

import 'package:laundry/services/database/backup_naming.dart';

int _pass = 0;
int _fail = 0;

void check(String label, bool ok, [String? detail]) {
  if (ok) {
    _pass++;
    print('  ✅ $label');
  } else {
    _fail++;
    print('  ❌ $label${detail == null ? '' : '  →  $detail'}');
  }
}

/// ترويسة SQLite صالحة بأي حجم صفحة.
///
/// [rawPageSizeField] هو القيمة **كما تُكتب في الملف**: 4096 تُكتب 4096،
/// أما 65536 فتُكتب `1` (اصطلاح SQLite للصيغة القديمة) لأن الحقل بايتان
/// ولا يسع 65536.
List<int> sqliteHeader({int rawPageSizeField = 4096}) {
  final head = <int>[];
  for (final code in BackupNaming.sqliteMagic.codeUnits) {
    head.add(code);
  }
  head.add(0); // المُصفِّر السادس عشر
  head.add((rawPageSizeField >> 8) & 0xFF);
  head.add(rawPageSizeField & 0xFF);
  // يكمل إلى 100 بايت (بقية الترويسة لا يعنينا في الفحص)
  while (head.length < 100) {
    head.add(0);
  }
  return head;
}

void main() {
  print('══ أسماء النسخ الاحتياطية ══');

  final stamp = DateTime(2026, 9, 21, 14, 30, 5);
  final def = BackupNaming.buildBackupFileName(stamp);
  check('الاسم الافتراضي مقروء', def == 'laundry_pos_2026-09-21_1430.db', def);
  check('لا نقطتان في الاسم (Windows)', !def.contains(':'), def);
  check('لا حرف T في الاسم', !def.contains('T'), def);
  check('الشهر واليوم مصفوفان', def.contains('-09-21'), def);
  check("الوقت بلا فاصل", def.contains('_1430'), def);

  check(
    'الاسم يحمل امتداد .db',
    BackupNaming.buildBackupFileName(stamp).endsWith('.db'),
  );

  final labeled = BackupNaming.buildBackupFileName(stamp, label: 'قبل الجرد');
  check('التسمية الحرّة تُلحق بالاسم', labeled.contains('قبل_الجرد'), labeled);
  check('التسمية الحرّة تحفظ الامتداد', labeled.endsWith('.db'), labeled);

  print('\n══ تطبيع الأسماء المدخلة ══');

  check(
    'نزع الأحرف الممنوعة غير الفاصلة',
    BackupNaming.sanitizeBackupName('a:b*c?d"e<f>g|h') == 'a_b_c_d_e_f_g_h.db',
    BackupNaming.sanitizeBackupName('a:b*c?d"e<f>g|h'),
  );
  check(
    'مزج الفواصل مع الأحرف الممنوعة: يبقى الاسم الأخير فقط',
    BackupNaming.sanitizeBackupName(r'a?b/c\\d') == 'd.db',
    BackupNaming.sanitizeBackupName(r'a?b/c\\d'),
  );
  check(
    'مسافات متتالية ⇒ شرطة سفلية واحدة',
    BackupNaming.sanitizeBackupName('نسخة   قبل    الجرد') ==
        'نسخة_قبل_الجرد.db',
    BackupNaming.sanitizeBackupName('نسخة   قبل    الجرد'),
  );
  check(
    'نزع المسار الملصوق',
    BackupNaming.sanitizeBackupName(r'C:\Users\x\my backup.db') ==
        'my_backup.db',
    BackupNaming.sanitizeBackupName(r'C:\Users\x\my backup.db'),
  );
  check(
    'إضافة الامتداد عند غيابه',
    BackupNaming.sanitizeBackupName('mybackup') == 'mybackup.db',
  );
  check(
    'عدم تكرار الامتداد',
    BackupNaming.sanitizeBackupName('mybackup.db') == 'mybackup.db',
  );
  check(
    'إصلاح الامتداد المبتور (منتهٍ بنقطة)',
    BackupNaming.sanitizeBackupName('mybackup.') == 'mybackup.db',
    BackupNaming.sanitizeBackupName('mybackup.'),
  );
  check(
    'نزع النقطة/الشرطة من الطرفين',
    BackupNaming.sanitizeBackupName('_.name._') == 'name.db',
    BackupNaming.sanitizeBackupName('_.name._'),
  );
  check(
    'النقاط المتتالية ⇒ واحدة',
    BackupNaming.sanitizeBackupName('a..b') == 'a.b.db',
    BackupNaming.sanitizeBackupName('a..b'),
  );
  check(
    'الاسم الفارغ ⇒ الافتراضي',
    BackupNaming.sanitizeBackupName('   ').startsWith('laundry_pos_'),
    BackupNaming.sanitizeBackupName('   '),
  );
  check(
    'الاسم الفارغ يستخدم البديل',
    BackupNaming.sanitizeBackupName('', fallback: 'backup') == 'backup.db',
  );
  check(
    'الاسم المحجوز على Windows يُزاح',
    BackupNaming.sanitizeBackupName('con') == '_con.db',
    BackupNaming.sanitizeBackupName('con'),
  );
  check(
    'اسم طويل جدًا يُقتطع مع حفظ الامتداد',
    () {
      final long = BackupNaming.sanitizeBackupName('x' * 400);
      return long.length <= 120 && long.endsWith('.db');
    }(),
  );

  print('\n══ منع الكتابة فوق نسخة قائمة ══');

  check(
    'اسم غير مأخوذ يبقى كما هو',
    BackupNaming.dedupeName('a.db', {'b.db'}) == 'a.db',
  );
  check(
    'اسم مأخوذ ⇒ _2',
    BackupNaming.dedupeName('a.db', {'a.db'}) == 'a_2.db',
    BackupNaming.dedupeName('a.db', {'a.db'}),
  );
  check(
    'مأخوذ مرتين ⇒ _3',
    BackupNaming.dedupeName('a.db', {'a.db', 'a_2.db'}) == 'a_3.db',
    BackupNaming.dedupeName('a.db', {'a.db', 'a_2.db'}),
  );
  check(
    'المقارنة لا تفرّق بحالة الأحرف (Windows/macOS)',
    BackupNaming.dedupeName('Backup.db', {'backup.Db'}) == 'Backup_2.db',
    BackupNaming.dedupeName('Backup.db', {'backup.Db'}),
  );

  print('\n══ نسخ الأمان ══');

  final safety = BackupNaming.buildSafetyFileName(stamp);
  check('بادئة نسخة الأمان', safety.startsWith('pre_restore_'), safety);
  check('لا نقطتان في اسم الأمان', !safety.contains(':'), safety);
  check('يُعرَف كنسخة أمان', BackupNaming.isSafetyBackupName(safety));
  check(
    'النسخة العادية ليست نسخة أمان',
    !BackupNaming.isSafetyBackupName(def),
  );
  check(
    'الاثنان بامتداد واحد',
    safety.endsWith('.db') && def.endsWith('.db'),
  );

  print('\n══ فحص ترويسة الملف ══');

  check(
    'ترويسة SQLite صالحة تُقبل',
    BackupNaming.validateBackupHeader(sqliteHeader()),
  );
  check(
    'حجم صفحة 512 يُقبل',
    BackupNaming.validateBackupHeader(sqliteHeader(rawPageSizeField: 512)),
  );
  check(
    'حجم صفحة 8192 يُقبل',
    BackupNaming.validateBackupHeader(sqliteHeader(rawPageSizeField: 8192)),
  );
  check(
    'حجم صفحة 65536 (مرمّز كـ1) يُقبل',
    BackupNaming.validateBackupHeader(sqliteHeader(rawPageSizeField: 1)),
  );
  check(
    'حجم صفحة غير صالح يُرفض',
    !BackupNaming.validateBackupHeader(sqliteHeader(rawPageSizeField: 999)),
  );
  check(
    'حجم صفحة 0 يُرفض',
    !BackupNaming.validateBackupHeader(sqliteHeader(rawPageSizeField: 0)),
  );

  // ملف ZIP (يبدأ بـ PK\x03\x04)
  final zip = <int>[0x50, 0x4B, 0x03, 0x04, ...List.filled(96, 0)];
  check('ملف ZIP يُرفض', !BackupNaming.validateBackupHeader(zip));

  // ملف JSON نصي
  final json = utf8.encode('{"invoices": 12, "note": "backup"}');
  final jsonPadded = <int>[...json, ...List.filled(100 - json.length, 32)];
  check('ملف JSON نصي يُرفض', !BackupNaming.validateBackupHeader(jsonPadded));

  // ملف نصي عادي
  final text = utf8.encode('hello world this is not a database at all');
  final textPadded = <int>[...text, ...List.filled(100 - text.length, 32)];
  check('ملف نصي يُرفض', !BackupNaming.validateBackupHeader(textPadded));

  check('ملف فارغ يُرفض', !BackupNaming.validateBackupHeader(<int>[]));
  check(
    'ملف مقتطع (أقل من 100 بايت) يُرفض',
    !BackupNaming.validateBackupHeader(
      sqliteHeader().sublist(0, 40),
    ),
  );
  check(
    'نص قريب من الترويسة لكن مغشوش يُرفض',
    () {
      final fake = sqliteHeader();
      fake[3] = 0x39; // 'SQI9...'
      return !BackupNaming.validateBackupHeader(fake);
    }(),
  );
  check(
    'بايت المُصفِّر السادس عشر إلزامي',
    () {
      final fake = sqliteHeader();
      fake[15] = 88;
      return !BackupNaming.validateBackupHeader(fake);
    }(),
  );

  print('\n══ مقارنة المسارات ══');

  check(
    'المسار نفسه (فاصل مختلف) يُكشف',
    BackupNaming.isSamePath(r'C:\a\b\laundry.db', 'C:/a/b/laundry.db'),
  );
  check(
    'المسار نفسه بحالة أحرف مختلفة يُكشف',
    BackupNaming.isSamePath('/data/Laundry.DB', '/data/laundry.db'),
  );
  check(
    'مساران مختلفان لا يتطابقان',
    !BackupNaming.isSamePath('/data/a.db', '/data/b.db'),
  );
  check(
    'المسار نفسه على أندرويد يُكشف',
    BackupNaming.isSamePath(
      '/data/data/x/databases/laundry_pos.db',
      '/data/data/x/databases/laundry_pos.db',
    ),
  );

  print('\n══ حجم مقروء ══');

  check('بايتات', BackupNaming.formatSize(900) == '900 B');
  check(
    'كيلوبايت',
    BackupNaming.formatSize(1024 * 3) == '3.0 KB',
    BackupNaming.formatSize(1024 * 3),
  );
  check(
    'ميغابايت',
    BackupNaming.formatSize(1024 * 1024 * 2) == '2.0 MB',
    BackupNaming.formatSize(1024 * 1024 * 2),
  );
  check(
    'جيجابايت',
    BackupNaming.formatSize(1024 * 1024 * 1024 * 3).endsWith('GB'),
  );

  print('\n════════════════════════════════════');
  print('النتيجة: $_pass نجحت · $_fail فشلت');
  if (_fail > 0) throw StateError('هناك فحوص فاشلة');
}
