import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:laundry/config/constants.dart';
import 'package:laundry/config/run_target.dart';
import 'package:laundry/services/security/security_service.dart';
import 'package:laundry/services/security/session_manager.dart';
// منطق خالص (بلا قاعدة بيانات) ⇒ لا دورة استيراد مع `app_settings_service`.
import 'package:laundry/services/settings/setting_option.dart';

/// نتيجة تنظيف الفواتير القديمة — تُعرَض للمستخدم بدل الحذف الصامت.
class InvoiceCleanupResult {
  final int count;
  final double totalAmount;

  const InvoiceCleanupResult({required this.count, required this.totalAmount});

  static const none = InvoiceCleanupResult(count: 0, totalAmount: 0);

  bool get hasChanges => count > 0;
}

class SqlDB {
  static Database? _db;

  /// بوابة صيانة: تُغلق أثناء **استبدال ملف قاعدة البيانات** (الاستعادة).
  ///
  /// **الخطر الذي تمنعه:** كانت الاستعادة تُغلق القاعدة ثم تنسخ فوق الملف،
  /// وفي تلك اللحظة كان أي طلب يمرّ على `dbGet` (مؤقت فحص الترخيص كل ساعة،
  /// تحديث لوحة التحكم، أي شاشة مفتوحة) **يعيد فتح الملف وهو في منتصف
  /// الاستبدال**. فيبقى اتصال حيّ على ملف قديم بينما الملف على القرص قد تغيّر
  /// ⇒ بيانات مختلطة أو قاعدة غير متسقة، وهي بالضبط حالة «تعطّل النظام» بعد
  /// الاستعادة. البوابة تُوقف كل هذه الطلبات حتى ينتهي الاستبدال، فلا يوجد
  /// اتصال حيّ واحد في لحظة النسخ.
  static Future<void>? _maintenance;

  static bool get isUnderMaintenance => _maintenance != null;

  /// يغلق البوابة ويُعيد دالة فتحها (تُنادى في `finally` دائمًا).
  static Future<void> Function() beginMaintenance() {
    final completer = Completer<void>();
    _maintenance = completer.future;
    return () async {
      if (!completer.isCompleted) completer.complete();
      _maintenance = null;
    };
  }

  Future<Database?> get dbGet async {
    // أثناء الصيانة: انتظر (لا تُفشل) ثم تابع على الملف الجديد.
    final gate = _maintenance;
    if (gate != null) await gate;
    if (_db != null) return _db;
    _db = await _initDB();
    return _db;
  }

  Future<Database> _initDB() async {
    // المسار يختلف بين ويندوز وأندرويد — والمنطق كله في
    // `lib/config/run_target.dart` حتى لا يتفرّق شرط `Platform` في المشروع.
    String dataBasePath = await AppPlatform.resolveDatabaseDirectory();
    String path = join(dataBasePath, AppConstants.dbName);
    Database mydb = await openDatabase(
      path,
      version: AppConstants.dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
    return mydb;
  }

  Future<void> _onCreate(Database db, int version) async {
    // ──────────────────────────────────────────────
    // 1. جدول المستخدمين (users)
    // ──────────────────────────────────────────────
    await db.execute('''
      CREATE TABLE IF NOT EXISTS "users" (
        "user_id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        "username" TEXT NOT NULL UNIQUE,
        "full_name" TEXT,
        "password_hash" TEXT NOT NULL,
        "role" TEXT NOT NULL DEFAULT 'cashier',
        "is_active" INTEGER NOT NULL DEFAULT 1,
        "created_at" TEXT NOT NULL
      )
    ''');

    // ──────────────────────────────────────────────
    // 2. جدول الأصناف (clothing) - مُوسّع
    // ──────────────────────────────────────────────
    await db.execute('''
      CREATE TABLE IF NOT EXISTS "clothing" (
        "clothing_id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        "clothing_name" TEXT NOT NULL,
        "normal_washing_and_ironing_price" REAL DEFAULT 0,
        "urgent_washing_and_ironing_price" REAL DEFAULT 0,
        "normal_ironing_price" REAL DEFAULT 0,
        "urgent_ironing_price" REAL DEFAULT 0,
        "category_id" INTEGER DEFAULT 0,
        "is_active" INTEGER DEFAULT 1
      )
    ''');

    // ──────────────────────────────────────────────
    // 3. جدول تصنيفات الأصناف (categories)
    // ──────────────────────────────────────────────
    await db.execute('''
      CREATE TABLE IF NOT EXISTS "categories" (
        "cat_id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        "name" TEXT NOT NULL,
        "description" TEXT,
        "is_active" INTEGER DEFAULT 1
      )
    ''');

    // ──────────────────────────────────────────────
    // 4. جدول الزبائن الموسّع (customers)
    // ──────────────────────────────────────────────
    await db.execute('''
      CREATE TABLE IF NOT EXISTS "customers" (
        "customer_id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        "customer_name" TEXT NOT NULL,
        "phone_1" TEXT,
        "phone_2" TEXT,
        "email" TEXT,
        "address" TEXT,
        "loyalty_points" INTEGER DEFAULT 0,
        "total_spent" REAL DEFAULT 0,
        "tier" TEXT DEFAULT 'bronze',
        "join_date" TEXT NOT NULL,
        "is_active" INTEGER DEFAULT 1,
        "notes" TEXT
      )
    ''');

    // ──────────────────────────────────────────────
    // 5. جدول الفواتير الموسّع (invoices)
    // ──────────────────────────────────────────────
    await db.execute('''
      CREATE TABLE IF NOT EXISTS "invoices" (
        "invoices_id" INTEGER NOT NULL PRIMARY KEY,
        "shift_id" INTEGER,
        "customer_id" INTEGER,
        "customer_name" TEXT,
        "customer_phone" TEXT,
        "total_price" REAL DEFAULT 0,
        "discount_amount" REAL DEFAULT 0,
        "tax_amount" REAL DEFAULT 0,
        "final_amount" REAL DEFAULT 0,
        "paid_amount" REAL DEFAULT 0,
        "payment_method" TEXT DEFAULT 'كاش',
        "remaining_amount" REAL DEFAULT 0,
        "discount_code" TEXT,
        "invoice_date" TEXT NOT NULL,
        "list_data" TEXT,
        "map_data" TEXT,
        "created_by" INTEGER
      )
    ''');

    // ──────────────────────────────────────────────
    // 6. جدول الورديات (shifts) - مُوسّع
    // ──────────────────────────────────────────────
    await db.execute('''
      CREATE TABLE IF NOT EXISTS "shifts" (
        "shift_id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        "start_time" TEXT NOT NULL,
        "end_time" TEXT,
        "total_cash" REAL DEFAULT 0,
        "total_network" REAL DEFAULT 0,
        "invoice_count" INTEGER DEFAULT 0,
        "opened_by" INTEGER,
        "notes" TEXT,
        "closed_by" INTEGER,
        "opening_balance" REAL DEFAULT 0,
        "counted_cash" REAL,
        "cash_difference" REAL,
        "difference_reason" TEXT,
        "stocktake_at" TEXT
      )
    ''');

    // ──────────────────────────────────────────────
    // 7. جدول المصروفات (expenses)
    // ──────────────────────────────────────────────
    await db.execute('''
      CREATE TABLE IF NOT EXISTS "expenses" (
        "expense_id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        "category" TEXT NOT NULL,
        "description" TEXT,
        "amount" REAL NOT NULL,
        "date" TEXT NOT NULL,
        "payment_method" TEXT DEFAULT 'كاش',
        "receipt_path" TEXT,
        "recorded_by" INTEGER,
        "shift_id" INTEGER
      )
    ''');

    // ملاحظة: جداول الموردين والمخزون والمشتريات أُزيلت عمدًا —
    // نظام المغاسل هذا لا يعتمد على موردين ولا مشتريات ولا جرد مخزون.
    // (يُصلح: كود ميّت + إرباك صيانة + جداول لا تُقرأ ولا تُكتب.)

    // ──────────────────────────────────────────────
    // 9. جدول الخصومات (discounts)
    // ──────────────────────────────────────────────
    await db.execute('''
      CREATE TABLE IF NOT EXISTS "discounts" (
        "discount_id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        "name" TEXT NOT NULL,
        "type" TEXT NOT NULL DEFAULT 'percentage',
        "value" REAL NOT NULL,
        "code" TEXT,
        "start_date" TEXT NOT NULL,
        "end_date" TEXT,
        "is_active" INTEGER DEFAULT 1,
        "max_uses" INTEGER,
        "current_uses" INTEGER DEFAULT 0
      )
    ''');

    // ──────────────────────────────────────────────
    // 12. جدول سجل التدقيق (audit_log)
    // ──────────────────────────────────────────────
    await db.execute('''
      CREATE TABLE IF NOT EXISTS "audit_log" (
        "log_id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        "user_id" INTEGER,
        "action" TEXT NOT NULL,
        "table_name" TEXT NOT NULL,
        "record_id" INTEGER,
        "old_values" TEXT,
        "new_values" TEXT,
        "timestamp" TEXT NOT NULL
      )
    ''');

    // ──────────────────────────────────────────────
    // 13. جدول الإعدادات (settings)
    // ──────────────────────────────────────────────
    await db.execute('''
      CREATE TABLE IF NOT EXISTS "settings" (
        "key" TEXT NOT NULL PRIMARY KEY,
        "value" TEXT,
        "description" TEXT
      )
    ''');

    // إنشاء الحسابات الافتراضية (مدير النظام · مدير · محاسب · مستخدم)
    await _seedDefaultUsers(db);

    // إدخال الإعدادات الافتراضية
    await _insertDefaultSettings(db);

    // ملاحظة: لا نستخدم Get.snackbar هنا — التنبيهات تحتاج Overlay مهيّأً
    // وهذا الكود يُنفَّذ قبل runApp() فيسقط التطبيق عند أول إنشاء للقاعدة.
    debugPrint('تم إنشاء قاعدة البيانات! تم إنشاء الجداول بنجاح');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 4) {
      // Migration from version 3 to 4
      try {
        // Create new tables
        await db.execute('''
          CREATE TABLE IF NOT EXISTS "users" (
            "user_id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
            "username" TEXT NOT NULL UNIQUE,
            "full_name" TEXT,
            "password_hash" TEXT NOT NULL,
            "role" TEXT NOT NULL DEFAULT 'cashier',
            "is_active" INTEGER NOT NULL DEFAULT 1,
            "created_at" TEXT NOT NULL
          )
        ''');

        await db.execute('''
          CREATE TABLE IF NOT EXISTS "categories" (
            "cat_id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
            "name" TEXT NOT NULL,
            "description" TEXT,
            "is_active" INTEGER DEFAULT 1
          )
        ''');

        await db.execute('''
          CREATE TABLE IF NOT EXISTS "customers" (
            "customer_id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
            "customer_name" TEXT NOT NULL,
            "phone_1" TEXT,
            "phone_2" TEXT,
            "email" TEXT,
            "address" TEXT,
            "loyalty_points" INTEGER DEFAULT 0,
            "total_spent" REAL DEFAULT 0,
            "tier" TEXT DEFAULT 'bronze',
            "join_date" TEXT NOT NULL,
            "is_active" INTEGER DEFAULT 1,
            "notes" TEXT
          )
        ''');

        await db.execute('''
          CREATE TABLE IF NOT EXISTS "expenses" (
            "expense_id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
            "category" TEXT NOT NULL,
            "description" TEXT,
            "amount" REAL NOT NULL,
            "date" TEXT NOT NULL,
            "payment_method" TEXT DEFAULT 'كاش',
            "receipt_path" TEXT,
            "recorded_by" INTEGER
          )
        ''');

        // جداول الموردين والمخزون والمشتريات أُزيلت — لا تُنشأ بعد الآن.

        await db.execute('''
          CREATE TABLE IF NOT EXISTS "discounts" (
            "discount_id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
            "name" TEXT NOT NULL,
            "type" TEXT NOT NULL DEFAULT 'percentage',
            "value" REAL NOT NULL,
            "code" TEXT,
            "start_date" TEXT NOT NULL,
            "end_date" TEXT,
            "is_active" INTEGER DEFAULT 1,
            "max_uses" INTEGER,
            "current_uses" INTEGER DEFAULT 0
          )
        ''');

        await db.execute('''
          CREATE TABLE IF NOT EXISTS "audit_log" (
            "log_id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
            "user_id" INTEGER,
            "action" TEXT NOT NULL,
            "table_name" TEXT NOT NULL,
            "record_id" INTEGER,
            "old_values" TEXT,
            "new_values" TEXT,
            "timestamp" TEXT NOT NULL
          )
        ''');

        await db.execute('''
          CREATE TABLE IF NOT EXISTS "settings" (
            "key" TEXT NOT NULL PRIMARY KEY,
            "value" TEXT,
            "description" TEXT
          )
        ''');

        // Add new columns to existing tables (ignore if column already exists)
        try {
          await db.execute(
            'ALTER TABLE "clothing" ADD COLUMN "category_id" INTEGER DEFAULT 0',
          );
        } catch (e) {
          // ignore: empty_catches
        }
        try {
          await db.execute(
            'ALTER TABLE "clothing" ADD COLUMN "is_active" INTEGER DEFAULT 1',
          );
        } catch (e) {
          // ignore: empty_catches
        }
        try {
          await db.execute(
            'ALTER TABLE "shifts" ADD COLUMN "opened_by" INTEGER',
          );
        } catch (e) {
          // ignore: empty_catches
        }
        try {
          await db.execute('ALTER TABLE "shifts" ADD COLUMN "notes" TEXT');
        } catch (e) {
          // ignore: empty_catches
        }

        // إنشاء الحسابات الافتراضية (غير مُتلِف — لا يمسّ حسابًا قائمًا)
        await _seedDefaultUsers(db);

        await _insertDefaultSettings(db);

        // لا Get.snackbar هنا: الترقية تحدث أثناء فتح القاعدة قبل runApp()
        debugPrint(
          'تم تحديث قاعدة البيانات! من الإصدار $oldVersion إلى $newVersion',
        );
      } catch (e) {
        debugPrint('Migration error: $e');
      }
    }
  }

  /// زرع الحسابات الافتراضية للنظام.
  ///
  /// **التصميم:**
  /// - يُستدعى من `_onCreate` (أول إنشاء) ومن `runPendingMigrations`
  ///   (كل فتح للتطبيق)، فهو يغطّي القواعد الجديدة **والقائمة** معًا.
  /// - `ConflictAlgorithm.ignore` على `username` الفريد ⇒ **خامل التكرار**
  ///   (idempotent): لا يُنشئ نسخة ثانية، ولا يُعيد كتابة `password_hash`
  ///   لحساب قائم. هذا مقصود: لو غيّر المستخدم كلمة مرور `admin` ثم فُتح
  ///   التطبيق، لا يجوز أن تُستعاد الكلمة الافتراضية — وهذا ثقب أمني.
  /// - كل حساب يأخذ **salt عشوائيًا مستقلًا** (16 بايت من `Random.secure`)،
  ///   فلا يتطابق تجزئة حسابين ولو تساوت كلماتهما.
  ///
  /// الأدوار: `admin` (مدير النظام) · `manager` (مدير) ·
  /// `accountant` (محاسب) · `cashier` (كاشير/مستخدم).
  Future<void> _seedDefaultUsers(DatabaseExecutor db) async {
    final defaults = <Map<String, String>>[
      {
        'username': AppConstants.defaultAdminUsername,
        'password': AppConstants.defaultAdminPassword,
        'role': 'admin',
        'full_name': 'مدير النظام',
      },
      {
        'username': AppConstants.defaultManagerUsername,
        'password': AppConstants.defaultManagerPassword,
        'role': 'manager',
        'full_name': 'مدير',
      },
      {
        'username': AppConstants.defaultAccountantUsername,
        'password': AppConstants.defaultAccountantPassword,
        'role': 'accountant',
        'full_name': 'محاسب',
      },
      {
        'username': AppConstants.defaultUserUsername,
        'password': AppConstants.defaultUserPassword,
        'role': 'cashier',
        'full_name': 'مستخدم',
      },
    ];

    for (final acc in defaults) {
      try {
        final salt = SecurityService.generateSalt();
        await db.insert('users', {
          'username': acc['username'],
          'full_name': acc['full_name'],
          'password_hash': SecurityService.hashPassword(
            acc['password']!,
            salt: salt,
          ),
          'role': acc['role'],
          'is_active': 1,
          'created_at': DateTime.now().toIso8601String(),
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      } catch (e) {
        // حساب قائم (أو تعذّر الإدراج) — لا نُفشل فتح القاعدة بسببه.
        debugPrint('seed default user ${acc['username']} skipped: $e');
      }
    }
  }

  /// زرع الإعدادات الافتراضية.
  ///
  /// **التصميم:** معلومات النشاط محصورة هنا، وكل **خيارات النظام** (التي كانت
  /// ثوابت في `config/constants.dart`) تُشتق من السجل الواحد
  /// [SettingOptions.all] — فلا تُكرَّر قيمتها أو وصفها في موضعين.
  ///
  /// الزرع بـ`ConflictAlgorithm.ignore` **غير مُتلِف**: لا يدهس قيمة عدّلها
  /// المستخدم، ويعمل بأمان لو أُعيد تنفيذه (ترقية/تشغيل متكرر).
  Future<void> _insertDefaultSettings(Database db) async {
    final settings = <Map<String, Object?>>[
      {
        'key': 'business_name',
        'value': 'مغاسل النظارة',
        'description': 'اسم النشاط التجاري',
      },
      {
        'key': 'business_phone',
        'value': '0577893387',
        'description': 'رقم هاتف النشاط',
      },
      {
        'key': 'business_address',
        'value': 'الرياض-حي اشبيليا-طريق الصحابة',
        'description': 'عنوان النشاط',
      },
      {
        'key': 'business_location',
        'value': '',
        'description': 'رابط موقع النشاط على خرائط جوجل',
      },
      {
        'key': 'business_tax_number',
        'value': '',
        'description': 'الرقم الضريبي (VAT) — يظهر على الفاتورة الضريبية '
            'ويُرمَّز في QR الهيئة',
      },
      {
        'key': 'business_cr_number',
        'value': '',
        'description': 'السجل التجاري — يظهر على الفاتورة عند تفعيل خياره',
      },
      {
        'key': 'business_short_address',
        'value': '',
        'description': 'العنوان الوطني المختصر — يظهر على الفاتورة عند تفعيله',
      },
    ];

    // خيارات النظام (ترقيم الفواتير · الاحتفاظ بالبيانات · الولاء · الضريبة ·
    // الترخيص · العملة) — مصدرها السجل الواحد.
    for (final option in SettingOptions.all) {
      settings.add({
        'key': option.key,
        'value': option.defaultValue,
        'description': option.description,
      });
    }

    for (final setting in settings) {
      await db.insert(
        'settings',
        setting,
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
  }

  /// يضمن وجود مفاتيح خيارات النظام في قاعدة قائمة.
  ///
  /// **غير مُتلِف:** يكتب القيمة الافتراضية **فقط عند غياب المفتاح** — فلا
  /// يعيد ضبط أي قيمة عدّلها المستخدم. لازم لأن قواعد التثبيتات القائمة لا
  /// تمرّ بـ`_onCreate` عند إضافة خيار جديد.
  Future<void> _ensureDefaultSettings() async {
    for (final option in SettingOptions.all) {
      try {
        if (await getSetting(option.key) == null) {
          await updateSetting(option.key, option.defaultValue);
        }
      } catch (e) {
        debugPrint('default setting ${option.key} skipped: $e');
      }
    }
  }

  // ──────────────────────────────────────────────
  // CRUD Operations (Parameterized - Safe)
  // ──────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> readData(
    String sql, [
    List<dynamic>? args,
  ]) async {
    Database? mydb = await dbGet;
    List<Map<String, dynamic>> response = await mydb!.rawQuery(sql, args);
    return response;
  }

  Future<int> insertData(String sql, [List<dynamic>? args]) async {
    Database? mydb = await dbGet;
    int response = await mydb!.rawInsert(sql, args);
    return response;
  }

  Future<int> updateData(String sql, [List<dynamic>? args]) async {
    Database? mydb = await dbGet;
    int response = await mydb!.rawUpdate(sql, args);
    return response;
  }

  Future<int> deleteData(String sql, [List<dynamic>? args]) async {
    Database? mydb = await dbGet;
    int response = await mydb!.rawDelete(sql, args);
    return response;
  }

  // ──────────────────────────────────────────────
  // Safe CRUD Operations (using map - recommended)
  // ──────────────────────────────────────────────

  /// الجداول التي تُنسب تلقائيًا إلى الوردية المفتوحة عند الإدراج.
  ///
  /// **«الوردية هي الصندوق»**: أي حركة نقدية بلا `shift_id` تُظهر **عجزًا
  /// وهميًا** في الإقفال — خرج نقد من الدرج بلا عهدة. الحقن هنا **مركزي
  /// عن قصد** لأن مواضع الإدراج متفرقة (خمسة مواضع في أربعة ملفات)، فأي
  /// مسار جديد يفلت بسهولة. مرّر `shift_id` صراحةً في الخريطة لتجاوز الحقن.
  static const Set<String> shiftLinkedTables = {
    'expenses',
    'customer_payments',
    'subscription_payments',
  };

  Future<int> safeInsert(String table, Map<String, dynamic> data) async {
    Database? mydb = await dbGet;
    final payload = await _withShiftLink(table, data);
    return await mydb!.insert(
      table,
      payload,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// يحقن `shift_id` للوردية المفتوحة في جداول الحركات النقدية.
  ///
  /// لا يمسّ الصفوف التي مرّرت `shift_id` صراحةً (وإن كانت `null` صريحة).
  Future<Map<String, dynamic>> _withShiftLink(
    String table,
    Map<String, dynamic> data,
  ) async {
    if (!shiftLinkedTables.contains(table)) return data;
    if (data.containsKey('shift_id')) return data;
    try {
      final rows = await readData(
        'SELECT shift_id FROM shifts WHERE end_time IS NULL '
        'ORDER BY shift_id DESC LIMIT 1',
      );
      final id =
          rows.isEmpty ? null : (rows.first['shift_id'] as num?)?.toInt();
      return {...data, 'shift_id': id};
    } catch (e) {
      debugPrint('shift link injection skipped: $e');
      return data;
    }
  }

  /// عدد الصفوف المطابقة لشرط معيّن — يُستخدم لكشف تصادم المفاتيح
  Future<int> countRows(
    String table, {
    String? where,
    List<dynamic>? whereArgs,
  }) async {
    Database? mydb = await dbGet;
    final rows = await mydb!.query(
      table,
      columns: ['COUNT(*) AS total'],
      where: where,
      whereArgs: whereArgs,
    );
    if (rows.isEmpty) return 0;
    return (rows.first['total'] as num?)?.toInt() ?? 0;
  }

  Future<List<Map<String, dynamic>>> safeRead(
    String table, {
    String? where,
    List<dynamic>? whereArgs,
    String? orderBy,
    int? limit,
    int? offset,
  }) async {
    Database? mydb = await dbGet;
    return await mydb!.query(
      table,
      where: where,
      whereArgs: whereArgs,
      orderBy: orderBy,
      limit: limit,
      offset: offset,
    );
  }

  Future<int> safeUpdate(
    String table,
    Map<String, dynamic> data, {
    String? where,
    List<dynamic>? whereArgs,
  }) async {
    Database? mydb = await dbGet;
    return await mydb!.update(table, data, where: where, whereArgs: whereArgs);
  }

  Future<int> safeDelete(
    String table, {
    String? where,
    List<dynamic>? whereArgs,
  }) async {
    Database? mydb = await dbGet;
    return await mydb!.delete(table, where: where, whereArgs: whereArgs);
  }

  // ──────────────────────────────────────────────
  // حذف الفواتير القديمة — مع حماية تقارير السنة الجارية
  // ──────────────────────────────────────────────

  /// يحذف الفواتير الأقدم من مدة الاحتفاظ، ولا يمسّ أي فاتورة من السنة الحالية
  /// حتى تبقى التقارير السنوية والشهرية صحيحة.
  ///
  /// **إصلاح:** كان يعمل تلقائيًا وصامتًا عند كل فتح للتطبيق، فتختفي فواتير
  /// من التقارير بلا أي إشعار — وهو خطر محاسبي. الآن:
  /// 1. لا يحذف فاتورة عليها **دين متبقٍّ** (حماية للأرصدة والديون).
  /// 2. لا يحذف فاتورة مرتبطة باشتراك (سجلّ الاستهلاك يجب أن يبقى).
  /// 3. يُعيد [InvoiceCleanupResult] ليُعرَض للمستخدم كمصروف/إشعار.
  Future<InvoiceCleanupResult> deleteOldInvoices() async {
    final Database? mydb = await dbGet;
    if (mydb == null) return InvoiceCleanupResult.none;

    // الإعداد: الحذف التلقائي **معطَّل افتراضيًا**. لا يُفعَّل إلا بقيمة صريحة
    // ('1'/'true') — فغياب المفتاح (قاعدة قديمة، أو خطأ قراءة) يعني «لا تحذف»:
    // لا يجوز أن يُمسح سجل مالي بسبب قيمة ناقصة.
    try {
      final stored = await getSetting(
        SettingOptions.invoiceAutoDeleteEnabled.key,
      );
      final enabled =
          stored ?? SettingOptions.invoiceAutoDeleteEnabled.defaultValue;
      if (!isTruthy(enabled)) {
        return InvoiceCleanupResult.none;
      }
    } catch (e) {
      debugPrint('auto delete setting error: $e');
      return InvoiceCleanupResult.none;
    }

    // مدة الاحتفاظ: من الإعداد، وإلا القيمة الافتراضية، وإلا قيمة الكود.
    var retentionDays = AppConstants.invoiceAutoDeleteDays;
    try {
      final saved = int.tryParse(
        await getSetting(SettingOptions.invoiceRetentionDays.key) ??
            SettingOptions.invoiceRetentionDays.defaultValue,
      );
      if (saved != null && saved > 0) retentionDays = saved;
    } catch (e) {
      debugPrint('retention setting error: $e');
    }

    // حماية: لا حذف إلا لما هو أقدم من سنة ميلادية كاملة على الأقل،
    // حتى لا يمسّ الحذف أي فاتورة قد تدخل في مقارنات "السنة الماضية".
    final effectiveDays =
        retentionDays < AppConstants.invoiceRetentionMinDays
            ? AppConstants.invoiceRetentionMinDays
            : retentionDays;

    const where = '''
      JULIANDAY('now') - JULIANDAY(invoice_date) > ?
      AND strftime('%Y', invoice_date) < strftime('%Y', 'now', 'localtime')
      AND COALESCE(remaining_amount, 0) <= 0.009
      AND subscription_id IS NULL
    ''';

    List<Map<String, dynamic>> doomed = const [];
    try {
      doomed = await readData(
        'SELECT COUNT(*) AS c, COALESCE(SUM(final_amount), 0) AS t '
        'FROM "invoices" WHERE $where',
        [effectiveDays],
      );
    } catch (e) {
      debugPrint('cleanup preview error: $e');
    }

    final count = ((doomed.firstOrNull?['c'] ?? 0) as num).toInt();
    final total = ((doomed.firstOrNull?['t'] ?? 0) as num).toDouble();
    if (count == 0) return InvoiceCleanupResult.none;

    await mydb.rawDelete('DELETE FROM "invoices" WHERE $where', [
      effectiveDays,
    ]);

    await logAudit(
      userId: SessionManager.currentUserId,
      action: 'invoices_auto_deleted',
      tableName: 'invoices',
      newValues:
          '{"count":$count,"amount":$total,"retention_days":$effectiveDays}',
    );

    return InvoiceCleanupResult(count: count, totalAmount: total);
  }

  // ──────────────────────────────────────────────
  // Audit Log
  // ──────────────────────────────────────────────

  Future<void> logAudit({
    required int? userId,
    required String action,
    required String tableName,
    int? recordId,
    String? oldValues,
    String? newValues,
  }) async {
    await safeInsert('audit_log', {
      'user_id': userId,
      'action': action,
      'table_name': tableName,
      'record_id': recordId,
      'old_values': oldValues,
      'new_values': newValues,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  // ──────────────────────────────────────────────
  // Backup & Restore
  // ──────────────────────────────────────────────

  /// مسار ملف قاعدة البيانات الفعلي على هذا النظام.
  ///
  /// **حرج للنسخ الاحتياطي والاستعادة**: لو أعاد مسارًا مخالفًا للمسار
  /// الحقيقي، فالاستعادة ستستبدل ملفًا لا وجود له (أو لا تستبدل شيئًا)
  /// بينما التطبيق يقرأ من مكان آخر — أي «استعادة ناجحة» بلا أثر.
  /// لذا يمرّ من نفس المصدر الوحيد `AppPlatform`.
  Future<String> getDatabasePath() async {
    return AppPlatform.resolveDatabaseFile(AppConstants.dbName);
  }

  /// إغلاق القاعدة المفتوحة — **بلا مرور بالبوابة**.
  ///
  /// لو نادى `dbGet` هنا لانتظر نفسه إلى الأبد أثناء الاستعادة (البوابة تُفتح
  /// بعد انتهاء الاستبدال، والاستبدال ينتظر إغلاق القاعدة). وحذف «الفتح عند
  /// الإغلاق» سلوك صحيح: `closeDB` تُغلق ما هو مفتوح ولا تفتح شيئًا.
  Future<void> closeDB() async {
    final mydb = _db;
    _db = null;
    if (mydb != null) {
      try {
        await mydb.close();
      } catch (e) {
        debugPrint('closeDB: $e');
      }
    }
  }

  // ──────────────────────────────────────────────
  // Get Setting
  // ──────────────────────────────────────────────

  Future<String?> getSetting(String key) async {
    final result = await safeRead(
      'settings',
      where: 'key = ?',
      whereArgs: [key],
    );
    if (result.isNotEmpty) {
      return result.first['value']?.toString();
    }
    return null;
  }

  Future<void> updateSetting(String key, String value) async {
    final Database? mydb = await dbGet;
    await mydb!.insert('settings', {
      'key': key,
      'value': value,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // ──────────────────────────────────────────────
  // ترحيلات تدرجية آمنة (لا تُكسر عند تكرارها)
  // ──────────────────────────────────────────────

  Future<void> runPendingMigrations() async {
    final Database? mydb = await dbGet;
    if (mydb == null) return;

    // الاسم الكامل للمستخدم/العامل — يُستخدم في لوحة المصنعية وإدارة العمال
    await _tryAlter(mydb, 'ALTER TABLE "users" ADD COLUMN "full_name" TEXT');
    try {
      await mydb.rawUpdate(
        'UPDATE "users" SET full_name = username '
        'WHERE full_name IS NULL OR TRIM(full_name) = \'\'',
      );
    } catch (e) {
      debugPrint('users full_name backfill skipped: $e');
    }

    // ─── الحسابات الافتراضية ───
    // تُزرع هنا **وفي كل فتح للتطبيق** لا عند أول إنشاء فقط، لأن القواعد
    // القائمة (المُنشأة قبل هذه الميزة) لن تُعيد تنفيذ `_onCreate` أبدًا.
    // الزرع **غير مُتلِف**: `ConflictAlgorithm.ignore` على `username` الفريد
    // ⇒ الحساب القائم يُترك كما هو بكلمة مروره الحالية، فلا تُستعاد كلمة
    // مرور افتراضية على حساب غيّرها صاحبه (وهو ثقب أمني).
    // موضعه بعد `_tryAlter(full_name)` أعلاه حتى يكون العمود موجودًا.
    await _seedDefaultUsers(mydb);

    // ─── خيارات النظام: ضمان وجود مفاتيحها ───
    // كانت هنا عمليتان منفصلتان (`invoice_retention_days` و
    // `invoice_auto_delete_enabled`) — أُزيلتا وأُسند الزرع إلى
    // `_ensureDefaultSettings` أدناه، الذي يشتق **كل** الخيارات من السجل
    // الواحد `SettingOptions.all` (غير مُتلِف: لا يدهس قيمة عدّلها المستخدم).
    await _ensureDefaultSettings();

    // تكلفة القطعة (لحساب هامش الربح)
    await _tryAlter(
      mydb,
      'ALTER TABLE "clothing" ADD COLUMN "cost_price" REAL DEFAULT 0',
    );

    // مصنعية الفواتير: الحالة، آخر تحديث، العامل المسؤول
    await _tryAlter(
      mydb,
      'ALTER TABLE "invoices" ADD COLUMN "status" TEXT DEFAULT "تم الاستلام"',
    );
    await _tryAlter(
      mydb,
      'ALTER TABLE "invoices" ADD COLUMN "status_updated_at" TEXT',
    );
    await _tryAlter(
      mydb,
      'ALTER TABLE "invoices" ADD COLUMN "assigned_to" INTEGER',
    );
    await _tryAlter(
      mydb,
      'ALTER TABLE "invoices" ADD COLUMN "pickup_code" TEXT',
    );
    await _tryAlter(
      mydb,
      'ALTER TABLE "invoices" ADD COLUMN "customer_id" INTEGER',
    );
    // ربط فاتورة المشترك باشتراكه الشهري (لدراسة نهاية الشهر لكل شخص)
    await _tryAlter(
      mydb,
      'ALTER TABLE "invoices" ADD COLUMN "subscription_id" INTEGER',
    );

    // مسودات الفواتير — حفظ واستعادة فاتورة غير مكتملة
    await mydb.execute('''
      CREATE TABLE IF NOT EXISTS "invoice_drafts" (
        "draft_id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        "customer_name" TEXT,
        "items_json" TEXT NOT NULL,
        "total_price" REAL DEFAULT 0,
        "created_at" TEXT NOT NULL
      )
    ''');

    // اشتراكات الزبائن الشهرية — تُنشأ أولاً حتى تعمل إضافة الأعماق عليها
    await mydb.execute('''
      CREATE TABLE IF NOT EXISTS "subscriptions" (
        "subscription_id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        "customer_id" INTEGER,
        "customer_name" TEXT,
        "amount" REAL NOT NULL DEFAULT 0,
        "period_days" INTEGER NOT NULL DEFAULT 30,
        "start_date" TEXT NOT NULL,
        "last_billed_date" TEXT NOT NULL,
        "notes" TEXT,
        "is_active" INTEGER DEFAULT 1
      )
    ''');

    // مدفوعات الاشتراكات
    await mydb.execute('''
      CREATE TABLE IF NOT EXISTS "subscription_payments" (
        "payment_id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        "subscription_id" INTEGER,
        "amount" REAL NOT NULL,
        "paid_date" TEXT NOT NULL,
        "method" TEXT DEFAULT 'كاش',
        "recorded_by" INTEGER,
        "shift_id" INTEGER
      )
    ''');

    // ═══ أعمدة الاشتراكات المُوسَّعة (تُكرَّر هنا ليعمل التثبيت الجديد) ═══
    // نفس القائمة المُطبَّقة في runPendingMigrations — الاثنان متطابقان عن قصد
    // كي لا تختلف قاعدة بيانات جديدة عن قاعدة مُرقّاة.
    for (final sql in <String>[
      'ALTER TABLE "subscriptions" ADD COLUMN "paid_until_date" TEXT',
      'ALTER TABLE "subscriptions" ADD COLUMN "usage_limit_pieces" '
          'INTEGER DEFAULT 0',
      'ALTER TABLE "subscriptions" ADD COLUMN "usage_limit_value" '
          'REAL DEFAULT 0',
      'ALTER TABLE "subscriptions" ADD COLUMN "cycle_start_date" TEXT',
      'ALTER TABLE "subscriptions" ADD COLUMN "cancelled_at" TEXT',
      'ALTER TABLE "subscriptions" ADD COLUMN "cancel_refund" REAL DEFAULT 0',
      'ALTER TABLE "subscriptions" ADD COLUMN "cancelled_by" INTEGER',
      "ALTER TABLE \"subscriptions\" ADD COLUMN \"status\" "
          "TEXT DEFAULT 'pending'",
      'ALTER TABLE "subscription_payments" ADD COLUMN "notes" TEXT',
      'ALTER TABLE "subscription_payments" ADD COLUMN "source" '
          "TEXT DEFAULT 'manual'",
      'ALTER TABLE "subscription_payments" ADD COLUMN "covers_from" TEXT',
      'ALTER TABLE "subscription_payments" ADD COLUMN "covers_to" TEXT',
      'ALTER TABLE "invoices" ADD COLUMN "subscription_used_value" '
          'REAL DEFAULT 0',
      'ALTER TABLE "invoices" ADD COLUMN "subscription_used_pieces" '
          'INTEGER DEFAULT 0',
    ]) {
      await _tryAlter(mydb, sql);
    }

    // فهارس الاشتراكات — تُنشأ هنا أيضًا لقاعدة جديدة
    await mydb.execute(
      'CREATE INDEX IF NOT EXISTS "idx_invoices_subscription" '
      'ON "invoices" ("subscription_id", "invoice_date")',
    );
    await mydb.execute(
      'CREATE INDEX IF NOT EXISTS "idx_subpay_subscription" '
      'ON "subscription_payments" ("subscription_id", "paid_date")',
    );
    await mydb.execute(
      'CREATE INDEX IF NOT EXISTS "idx_subscriptions_active" '
      'ON "subscriptions" ("is_active", "customer_id")',
    );
    await mydb.execute(
      'CREATE INDEX IF NOT EXISTS "idx_subscriptions_due" '
      'ON "subscriptions" ("paid_until_date") WHERE "is_active" = 1',
    );

    // ممول حتى — تاريخ انتهاء التغطية المدفوعة للاشتراك (يدعم الدفعات الجزئية)
    await _tryAlter(
      mydb,
      'ALTER TABLE "subscriptions" ADD COLUMN "paid_until_date" TEXT',
    );

    // ملاحظات على دفعة الاشتراك
    await _tryAlter(
      mydb,
      'ALTER TABLE "subscription_payments" ADD COLUMN "notes" TEXT',
    );

    // ═══════════════════════════════════════════════════════════════════
    //  إصلاحات هندسية ومحاسبية لوحدة الاشتراكات (v6)
    // ═══════════════════════════════════════════════════════════════════

    // ─── 1. سقف الاستخدام: عدد القطع المغطّاة في كل دورة ───
    // 0 = بلا سقف على القطع. يحمي من اشتراك بـ50 ريال يستهلك 300 قطعة.
    await _tryAlter(
      mydb,
      'ALTER TABLE "subscriptions" ADD COLUMN "usage_limit_pieces" '
      'INTEGER DEFAULT 0',
    );

    // ─── 2. سقف الاستخدام: القيمة السوقية المغطّاة في كل دورة ───
    // 0 = بلا سقف على القيمة. أيّهما (القطع أو القيمة) يُستهلك أولاً يوقف.
    await _tryAlter(
      mydb,
      'ALTER TABLE "subscriptions" ADD COLUMN "usage_limit_value" '
      'REAL DEFAULT 0',
    );

    // ─── 3. نهاية آخر دورة مُقفَلة — أساس الترحيل و"التغطية المتاحة" ───
    // سابقًا كان `last_billed_date` يُكتب بقيمة `paid_until_date` (خطأ دلالي).
    // الآن: `paid_until_date` = آخر يوم مغطّى، و`last_billed_date` = بداية
    // الدورة الجارية. الفرق بينهما = الرصيد الزمني المتبقّي فعلًا.
    await _tryAlter(
      mydb,
      'ALTER TABLE "subscriptions" ADD COLUMN "cycle_start_date" TEXT',
    );

    // ─── 4. تسوية الإلغاء: تاريخ الإلغاء + المسترد + من نفّذه ───
    await _tryAlter(
      mydb,
      'ALTER TABLE "subscriptions" ADD COLUMN "cancelled_at" TEXT',
    );
    await _tryAlter(
      mydb,
      'ALTER TABLE "subscriptions" ADD COLUMN "cancel_refund" REAL DEFAULT 0',
    );
    await _tryAlter(
      mydb,
      'ALTER TABLE "subscriptions" ADD COLUMN "cancelled_by" INTEGER',
    );

    // ─── 5. مصدر دفعة الاشتراك — للتدقيق المطابقي مع الصندوق ───
    // manual (من شاشة الاشتراكات) | renewal (تجديد تلقائي)
    // | cancel_refund (استرداد عند الإلغاء)
    await _tryAlter(
      mydb,
      'ALTER TABLE "subscription_payments" ADD COLUMN "source" '
      "TEXT DEFAULT 'manual'",
    );

    // ─── 6. ربط الدفعة بالدورة التي مدّدتها — يمنع تداخل فترات التغطية ───
    await _tryAlter(
      mydb,
      'ALTER TABLE "subscription_payments" ADD COLUMN "covers_from" TEXT',
    );
    await _tryAlter(
      mydb,
      'ALTER TABLE "subscription_payments" ADD COLUMN "covers_to" TEXT',
    );

    // ─── 7. قيمة الاستهلاك الفعلي عند كل فاتورة (للاستهلاك والسقف) ───
    // تُخزَّن على الفاتورة لأن قيمة الغسيل وقت الإصدار هي المرجع المحاسبي،
    // لا سعر قائمة الأصناف اليوم (قد يتغيّر لاحقًا).
    await _tryAlter(
      mydb,
      'ALTER TABLE "invoices" ADD COLUMN "subscription_used_value" '
      'REAL DEFAULT 0',
    );
    await _tryAlter(
      mydb,
      'ALTER TABLE "invoices" ADD COLUMN "subscription_used_pieces" '
      'INTEGER DEFAULT 0',
    );

    // ─── 8. فهرس الإيراد المؤجَّل: استعلامات الرصيد الدفتري كانت مسحًا كاملًا ───
    await mydb.execute(
      'CREATE INDEX IF NOT EXISTS "idx_invoices_subscription" '
      'ON "invoices" ("subscription_id", "invoice_date")',
    );
    await mydb.execute(
      'CREATE INDEX IF NOT EXISTS "idx_subpay_subscription" '
      'ON "subscription_payments" ("subscription_id", "paid_date")',
    );
    await mydb.execute(
      'CREATE INDEX IF NOT EXISTS "idx_subscriptions_active" '
      'ON "subscriptions" ("is_active", "customer_id")',
    );
    // فهرس جزئي: الاشتراكات النشطة فقط — هو ما يُقرأ في كل شاشة تقريبًا
    await mydb.execute(
      'CREATE INDEX IF NOT EXISTS "idx_subscriptions_due" '
      'ON "subscriptions" ("paid_until_date") WHERE "is_active" = 1',
    );

    // ─── 9. استبدال التعريف المتناقض لحالة الاشتراك ───
    // كان `is_active = 1` وحده يعني "نشط"، بينما الشاشة تعرض "متأخر" لنفس
    // الصف. الآن الحالة مُشتقّة من التغطية والانتهاء، وهو المصدر الوحيد.
    await _tryAlter(
      mydb,
      'ALTER TABLE "subscriptions" ADD COLUMN "status" '
      "TEXT DEFAULT 'pending'",
    );

    // ─── 10. ترحيل: تصحيح `last_billed_date` الملوَّث بالدلالة الخاطئة ───
    //
    // **ترتيب حرج:** يجب أن يسبق تعبئة `cycle_start_date` (الخطوة 11).
    // لو تأخّر، لكان `cycle_start_date` قد صار مساويًا لـ`last_billed_date`
    // الملوَّث، فتصبح الإسناد قيمةً لنفسها — ترحيل بلا أثر.
    //
    // حالتان ملوَّثتان:
    //  (أ) `paid_until_date` موجود ويساوي `last_billed_date` — أثر الكتابة
    //      الجديدة الخاطئة (كان `pay()` يكتب الاثنين بنفس القيمة).
    //  (ب) `paid_until_date` = NULL و`last_billed_date` يحمل تاريخًا — كل
    //      الاشتراكات القديمة قبل وجود العمود. هذه هي الحالة الغالبة فعلًا،
    //      وهي التي كانت تفوت بالشرط الضيق السابق.
    // في الحالتين المرساة الصحيحة هي تاريخ التسجيل.
    try {
      await mydb.rawUpdate(
        'UPDATE "subscriptions" SET "last_billed_date" = '
        'COALESCE("start_date", "paid_until_date") '
        'WHERE ("paid_until_date" IS NOT NULL '
        '       AND "last_billed_date" = "paid_until_date") '
        '   OR ("paid_until_date" IS NULL '
        '       AND "last_billed_date" IS NOT NULL)',
      );
      debugPrint('subscription last_billed_date normalisation OK');
    } catch (e) {
      debugPrint('subscription last_billed_date normalisation skipped: $e');
    }

    // ─── 11. ترحيل: `cycle_start_date` = نهاية آخر دورة مُسدَّدة ───
    // المرساة الصحيحة هي `last_billed_date` (بعد تطهيره أعلاه)، وإلا فتاريخ
    // التسجيل. **لا** نستخدم `paid_until_date` — فذلك هو الخطأ الأصلي نفسه:
    // كان يجعل بداية الدورة = نهايتها، فيظهر الرصيد الزمني المتاح صفرًا.
    try {
      await mydb.rawUpdate(
        'UPDATE "subscriptions" SET "cycle_start_date" = '
        'COALESCE("last_billed_date", "start_date", "paid_until_date") '
        'WHERE "cycle_start_date" IS NULL',
      );
      debugPrint('subscription cycle_start_date backfill OK');
    } catch (e) {
      debugPrint('subscription cycle_start_date backfill skipped: $e');
    }

    // ─── 12. ترحيل: تصنيف الحالة الحالية لكل اشتراك نشط ───
    try {
      await mydb.rawUpdate(
        'UPDATE "subscriptions" SET "status" = CASE '
        "  WHEN \"paid_until_date\" IS NULL THEN 'pending' "
        // `'localtime'` تبقى على `'now'` لأنها في SQLite وقت **UTC فعلًا**،
        // وفي توقيت UTC+3 تكون DATE('now') بلا تحويل متأخرةً يومًا كاملًا بين
        // 00:00 و03:00 محليًا — فيُصنَّف اشتراك منتهٍ أمس بأنه 'active' خطأً.
        // أما `paid_until_date` فمخزَّن **محليًا**، فتطبيق `'localtime'` عليه
        // تحويل **مزدوج** يُزيحه يومًا فيبدو الاشتراك المنتهي نشِطًا يومًا
        // إضافيًا. القياس: `tool/verify_localtime_removal.py`.
        "  WHEN DATE(\"paid_until_date\") < DATE('now', 'localtime') THEN 'overdue' "
        "  ELSE 'active' END "
        'WHERE "is_active" = 1',
      );
      debugPrint('subscription status backfill OK');
    } catch (e) {
      debugPrint('subscription status backfill skipped: $e');
    }

    // ─── 13. سجل تغطية الاشتراكات — أثر تدقيقي لكل تمّديد/استهلاك/إلغاء ───
    // الجداول السابقة تحفظ *المدفوع* فقط. لا يوجد أي أثر لـ«ماذا استُهلك
    // من الغسيل» مقابل تلك الدفعة. هذا الجدول يسدّ الفجوة ويمكّن من
    // مطابقة الإيراد المُعترف به بالمصروف المستقبلي (deferred revenue).
    await mydb.execute('''
      CREATE TABLE IF NOT EXISTS "subscription_coverage_log" (
        "log_id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        "subscription_id" INTEGER NOT NULL,
        "customer_id" INTEGER,
        "event" TEXT NOT NULL,
        "amount" REAL DEFAULT 0,
        "pieces" INTEGER DEFAULT 0,
        "coverage_from" TEXT,
        "coverage_to" TEXT,
        "reference_id" INTEGER,
        "notes" TEXT,
        "created_at" TEXT NOT NULL,
        "created_by" INTEGER
      )
    ''');
    await mydb.execute(
      'CREATE INDEX IF NOT EXISTS "idx_coverage_log_sub" '
      'ON "subscription_coverage_log" ("subscription_id", "created_at")',
    );

    // ─── مؤشرات الاشتراكات: حالة أولية سليمة لقاعدة جديدة ───
    try {
      await mydb.rawUpdate(
        'UPDATE "subscriptions" SET "cycle_start_date" = "start_date" '
        'WHERE "cycle_start_date" IS NULL',
      );
    } catch (e) {
      debugPrint('fresh subscription cycle backfill skipped: $e');
    }

    // من أغلق الوردية
    await _tryAlter(
      mydb,
      'ALTER TABLE "shifts" ADD COLUMN "closed_by" INTEGER',
    );

    // من غيّر حالة الفاتورة
    await _tryAlter(
      mydb,
      'ALTER TABLE "invoices" ADD COLUMN "status_updated_by" INTEGER',
    );

    // رابط موقع النشاط على خرائط جوجل
    try {
      await mydb.insert('settings', {
        'key': 'business_location',
        'value': '',
        'description': 'رابط موقع النشاط على خرائط جوجل',
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    } catch (e) {
      debugPrint('business_location setting skipped (already applied): $e');
    }

    // الرقم الضريبي (VAT) — لقواعد قائمة أيضًا. **غير مُتلِف**: يُكتب فقط
    // عند غياب المفتاح، فلا يُمحى رقم أدخله المستخدم.
    try {
      await mydb.insert('settings', {
        'key': 'business_tax_number',
        'value': '',
        'description': 'الرقم الضريبي (VAT) — يظهر على الفاتورة الضريبية '
            'ويُرمَّز في QR الهيئة',
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    } catch (e) {
      debugPrint('business_tax_number setting skipped (already applied): $e');
    }

    // ─── إدارة حسابات الزبائن والديون ───
    await _tryAlter(
      mydb,
      'ALTER TABLE "customers" ADD COLUMN "balance" REAL DEFAULT 0',
    );

    await mydb.execute('''
      CREATE TABLE IF NOT EXISTS "customer_payments" (
        "payment_id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        "customer_id" INTEGER NOT NULL,
        "amount" REAL NOT NULL,
        "payment_method" TEXT DEFAULT 'كاش',
        "payment_date" TEXT NOT NULL,
        "notes" TEXT,
        "recorded_by" INTEGER,
        "source" TEXT DEFAULT 'manual',
        "shift_id" INTEGER
      )
    ''');

    // مصدر الدفعة: manual (من شاشة الحساب) | delivery (سداد عند تسليم المصنعية)
    // | credit_use (استهلاك سلفة). يمكّن من تدقيق مطابقة النقدية.
    await _tryAlter(
      mydb,
      'ALTER TABLE "customer_payments" ADD COLUMN "source" TEXT DEFAULT \'manual\'',
    );

    // رقم الفاتورة المرتبطة بالدفعة — يربط كل ريال دخل بالفاتورة التي سُدّدت
    await _tryAlter(
      mydb,
      'ALTER TABLE "customer_payments" ADD COLUMN "invoice_id" INTEGER',
    );

    // ─── حدّ الدين الآجل لكل زبون (0 = بلا حد) ───
    await _tryAlter(
      mydb,
      'ALTER TABLE "customers" ADD COLUMN "credit_limit" REAL DEFAULT 0',
    );

    // ─── فهارس الأداء: استعلامات كشف الحساب والذمم كانت مسحًا كاملًا ───
    await mydb.execute(
      'CREATE INDEX IF NOT EXISTS "idx_invoices_customer" '
      'ON "invoices" ("customer_id", "invoice_date")',
    );
    await mydb.execute(
      'CREATE INDEX IF NOT EXISTS "idx_invoices_due" '
      'ON "invoices" ("remaining_amount") WHERE "remaining_amount" > 0',
    );
    await mydb.execute(
      'CREATE INDEX IF NOT EXISTS "idx_invoices_date" ON "invoices" ("invoice_date")',
    );
    await mydb.execute(
      'CREATE INDEX IF NOT EXISTS "idx_customers_active" '
      'ON "customers" ("is_active", "customer_name")',
    );
    await mydb.execute(
      'CREATE INDEX IF NOT EXISTS "idx_custpay_customer" '
      'ON "customer_payments" ("customer_id", "payment_date")',
    );

    // ─── سجل تدقيق الذمم: حركة الرصيد الأخيرة لكل زبون ───
    await mydb.execute('''
      CREATE TABLE IF NOT EXISTS "customer_balance_log" (
        "log_id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        "customer_id" INTEGER NOT NULL,
        "change_amount" REAL NOT NULL,
        "balance_after" REAL NOT NULL,
        "reason" TEXT NOT NULL,
        "reference_id" INTEGER,
        "created_at" TEXT NOT NULL,
        "created_by" INTEGER
      )
    ''');
    await mydb.execute(
      'CREATE INDEX IF NOT EXISTS "idx_balance_log_customer" '
      'ON "customer_balance_log" ("customer_id", "created_at")',
    );

    // ─── إصلاح المجموع للفواتير المخزَّنة بصفر (خطأ محاسبي) ───
    // حقل المجموع في شاشة البيع لم يكن يُزامَن مع بنود الفاتورة، فحُفظت
    // فواتير بـ`total_price = 0` و`final_amount = 0` و`remaining_amount = 0`
    // رغم أن بنودها وأسعارها محفوظة في `list_data` — أي خسارة إيراد كامل في
    // التقارير والصندوق ومعظم الفواتير المطبوعة.
    // نعيد اشتقاق المجموع من البنود. الإصلاح **متكرر الآمان**: شرطه أن
    // المجموع المخزَّن صفر، فلا يمسّ أي فاتورة سليمة.
    try {
      final broken = await mydb.rawQuery(
        'SELECT invoices_id, paid_amount, subscription_id, list_data '
        'FROM "invoices" '
        'WHERE COALESCE(total_price, 0) = 0 AND COALESCE(final_amount, 0) = 0 '
        "  AND list_data IS NOT NULL AND TRIM(list_data) <> '' "
        "  AND TRIM(list_data) <> '[]'",
      );
      var repaired = 0;
      for (final row in broken) {
        final total = _itemsTotalFromJson(row['list_data']);
        if (total <= 0) continue;
        final paid = (row['paid_amount'] as num?)?.toDouble() ?? 0.0;
        final isSubscription =
            ((row['subscription_id'] as num?)?.toInt() ?? 0) > 0;
        await mydb.update(
          'invoices',
          {
            'total_price': total,
            'final_amount': total,
            // فاتورة الاشتراك مغطّاة مسبقًا: لا متبقي عليها
            'remaining_amount':
                isSubscription ? 0.0 : (total - paid > 0 ? total - paid : 0.0),
          },
          where: 'invoices_id = ?',
          whereArgs: [row['invoices_id']],
        );
        repaired++;
      }
      if (repaired > 0) {
        debugPrint('إصلاح مجموع $repaired فاتورة كانت مخزَّنة بصفر');
      }
    } catch (e) {
      debugPrint('invoice total repair skipped: $e');
    }

    // ─── إعادة مزامنة أرصدة الزبائن المختلّة من الفواتير (إصلاح تراكمي) ───
    // الأرصدة السابقة كانت تُصفَّر عند كل دفعة جزئية، فلا بد من إعادة اشتقاقها.
    try {
      await mydb.rawUpdate(
        'UPDATE "customers" SET "balance" = ('
        '  SELECT COALESCE(-SUM(i.remaining_amount), 0) FROM "invoices" i '
        '  WHERE i.customer_id = customers.customer_id '
        '    AND i.subscription_id IS NULL AND i.remaining_amount > 0'
        ') WHERE COALESCE("balance", 0) <= 0',
      );
      debugPrint('تمت إعادة مزامنة أرصدة الزبائن المدينين من الفواتير');
    } catch (e) {
      debugPrint('balance resync skipped: $e');
    }

    // ─── إعادة احتساب إجمالي مشتريات الزبائن (العمود كان مهمَلًا تمامًا) ───
    try {
      await mydb.rawUpdate(
        'UPDATE "customers" SET "total_spent" = ('
        '  SELECT COALESCE(SUM(i.final_amount), 0) FROM "invoices" i '
        '  WHERE i.customer_id = customers.customer_id'
        ')',
      );
      debugPrint('تمت إعادة احتساب إجمالي مشتريات الزبائن');
    } catch (e) {
      debugPrint('total_spent backfill skipped: $e');
    }

    // ─── إزالة جداول الموردين والمخزون والمشتريات ───
    //
    // نظام المغاسل لا يعتمد على موردين ولا مشتريات ولا جرد مخزون. هذه الجداول
    // كانت تُنشأ عند التهيئة الأولى ولا يُقرأ منها ولا يُكتب فيها أي صف في
    // التطبيق كله — كود ميّت يُربك الصيانة ويوحي بوجود وظائف غير موجودة.
    // تُحذف الآن من أي قاعدة قائمة. الحذف نهائي ومقصود: لا بيانات فيها أصلًا.
    for (final table in ['inventory', 'suppliers', 'purchases']) {
      try {
        await mydb.execute('DROP TABLE IF EXISTS "$table"');
        debugPrint('أُزيل جدول غير مستخدم: $table');
      } catch (e) {
        debugPrint('تعذّر إزالة الجدول $table: $e');
      }
    }

    // ══════════════════════════════════════════════════════════════
    // 🔗 ربط كل الحركات المالية بالوردية (الصندوق)
    // ══════════════════════════════════════════════════════════════
    //
    // **القاعدة المعمارية:** «الوردية هي الصندوق». كل حركة نقدية يجب أن
    // تُنسب إلى وردية، وإلا ظهر **عجز وهمي** في الإقفال: سحوبات ودفعات
    // حدثت في وقت الوردية لكنها غير منسوبة إليها.
    //
    // كانت هذه الجداول الثلاثة بلا `shift_id`، فيُربط بالوقت تخمينًا:
    // `datetime(x) >= datetime(shift_start)` — و**بلا حدّ أعلى**، فتُحتسب
    // دفعة حدثت *بعد* إقفال الوردية ضمنها. الربط الآن صريح بالمعرّف.
    for (final table in <String>[
      'expenses',
      'customer_payments',
      'subscription_payments',
    ]) {
      await _tryAlter(
        mydb,
        'ALTER TABLE "$table" ADD COLUMN "shift_id" INTEGER',
      );
    }

    // أعمدة الجرد والإقفال — هنا يُخزَّن الصندوق فعلًا، وهو الجزء **الوحيد
    // غير القابل للاشتقاق**: ما عُدَّ نقدًا فعليًا، وما الفرق، وما سببه.
    for (final sql in <String>[
      'ALTER TABLE "shifts" ADD COLUMN "opening_balance" REAL DEFAULT 0',
      'ALTER TABLE "shifts" ADD COLUMN "counted_cash" REAL',
      'ALTER TABLE "shifts" ADD COLUMN "cash_difference" REAL',
      'ALTER TABLE "shifts" ADD COLUMN "difference_reason" TEXT',
      'ALTER TABLE "shifts" ADD COLUMN "stocktake_at" TEXT',
    ]) {
      await _tryAlter(mydb, sql);
    }

    // ─── ترحيل تصحيحي لمرة واحدة: ربط الصفوف القديمة بورديتها ───
    // النافذة **محدودة الطرفين**: من فتح الوردية إلى إقفالها (أو بلا حدّ
    // أعلى إن كانت ما تزال مفتوحة). يُنفَّذ مرة واحدة ويُعلَّم بإعداد، فلا
    // يعيد كتابة روابط صحيحة لاحقًا.
    try {
      if (await getSetting('shift_link_backfill_v1') != '1') {
        var linked = 0;
        for (final entry in <List<String>>[
          ['expenses', 'date'],
          ['customer_payments', 'payment_date'],
          ['subscription_payments', 'paid_date'],
        ]) {
          final table = entry[0];
          final col = entry[1];
          final rows = await readData(
            'SELECT DISTINCT "$col" AS ts FROM "$table" '
            'WHERE shift_id IS NULL AND "$col" IS NOT NULL',
          );
          for (final r in rows) {
            final ts = r['ts']?.toString();
            if (ts == null || ts.isEmpty) continue;
            final match = await readData(
              'SELECT shift_id FROM shifts '
              'WHERE datetime(start_time) <= datetime(?) '
              '  AND (end_time IS NULL OR datetime(end_time) >= datetime(?)) '
              'ORDER BY shift_id ASC LIMIT 1',
              [ts, ts],
            );
            if (match.isEmpty) continue;
            await mydb.rawUpdate(
              'UPDATE "$table" SET shift_id = ? '
              'WHERE "$col" = ? AND shift_id IS NULL',
              [match.first['shift_id'], ts],
            );
            linked++;
          }
        }
        await updateSetting('shift_link_backfill_v1', '1');
        debugPrint('ربط $linked حركة قديمة بوردياتها');
      }
    } catch (e) {
      debugPrint('shift link backfill skipped: $e');
    }

    // ══════════════════════════════════════════════════════════════
    // 🏷️ جدول الخصومات (`discounts`) — ضمان الوجود
    // ══════════════════════════════════════════════════════════════
    //
    // الجدول معرَّف في `_onCreate` و`_onUpgrade` فقط، وليس هنا. أي قاعدة
    // أُنشئت بإصدار أقدم من إضافة الجدول ثم **لم** تمرّ بفرع `_onUpgrade`
    // المعنيّ (أو أُعيد بناؤها من نسخة احتياطية قديمة) تبقى **بلا الجدول**.
    //
    // والفشل صامت تمامًا: `DiscountService.check` يبتلع الاستثناء ويرجع
    // «تعذّر التحقق من كود الخصم»، و`all()` ترجع قائمة فارغة ⇒ شاشة
    // الخصومات تبدو «لا أكواد» لا «جدول مفقود». لذا يُضمن هنا صراحةً —
    // وهو نفس ما تفعله بقية الجداول في هذه الدالة (`IF NOT EXISTS` غير مُتلِف).
    await mydb.execute('''
      CREATE TABLE IF NOT EXISTS "discounts" (
        "discount_id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        "name" TEXT NOT NULL,
        "type" TEXT NOT NULL DEFAULT 'percentage',
        "value" REAL NOT NULL,
        "code" TEXT,
        "start_date" TEXT NOT NULL,
        "end_date" TEXT,
        "is_active" INTEGER DEFAULT 1,
        "max_uses" INTEGER,
        "current_uses" INTEGER DEFAULT 0
      )
    ''');

    // ══════════════════════════════════════════════════════════════
    // 🧾 بنود الفاتورة كلقطة محاسبية (`invoice_items`)
    // ══════════════════════════════════════════════════════════════
    //
    // **العيب الذي يُعالجه:** التكلفة كانت تُحسب بربط البنود **بالاسم** مع
    // جدول `clothing`:
    //
    //     ... json_each(i.list_data) j, clothing c
    //     WHERE json_extract(j.value,'$.vestments') = c.clothing_name
    //
    // وله عيبان صامتان:
    //   1. إعادة تسمية صنف ⇒ ينقطع الربط ⇒ التكلفة تصير **صفرًا** لكل
    //      فواتيره التاريخية ⇒ الربح ينتفخ بلا أي تحذير.
    //   2. `c.cost_price` هي **التكلفة الحالية** لا تكلفة يوم البيع ⇒ تعديل
    //      سعر التكلفة يُعيد كتابة أرباح الماضي كلها.
    //
    // الحل: لقطة تُكتب وقت الإصدار — الاسم والمعرّف وتكلفة الوحدة كما كانت
    // في تلك اللحظة. `list_data` يبقى مصدر **عرض** الفاتورة (ما رآه الزبون)،
    // و`invoice_items` مصدر **المحاسبة** (التكلفة والربح).
    await mydb.execute('''
      CREATE TABLE IF NOT EXISTS "invoice_items" (
        "item_id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        "invoice_id" INTEGER NOT NULL,
        "clothing_id" INTEGER,
        "item_name" TEXT NOT NULL,
        "content" TEXT,
        "qty" INTEGER DEFAULT 0,
        "unit_price" REAL DEFAULT 0,
        "unit_cost" REAL DEFAULT 0,
        "total_price" REAL DEFAULT 0,
        "total_cost" REAL DEFAULT 0,
        "note" TEXT,
        "created_at" TEXT
      )
    ''');
    await mydb.execute(
      'CREATE INDEX IF NOT EXISTS "idx_invoice_items_invoice" '
      'ON "invoice_items" ("invoice_id")',
    );
    await mydb.execute(
      'CREATE INDEX IF NOT EXISTS "idx_invoice_items_clothing" '
      'ON "invoice_items" ("clothing_id")',
    );
    await mydb.execute(
      'CREATE INDEX IF NOT EXISTS "idx_invoice_items_name" '
      'ON "invoice_items" ("item_name")',
    );

    // ─── لقطة الضريبة: النسبة وقت الإصدار والأساس الخاضع ───
    // تُخزَّن النسبة لا تُقرأ من الإعدادات عند العرض: تغيير النسبة لاحقًا
    // يجب ألا يُعيد كتابة ضريبة فاتورة صادرة.
    await _tryAlter(
      mydb,
      'ALTER TABLE "invoices" ADD COLUMN "tax_rate" REAL DEFAULT 0',
    );
    await _tryAlter(
      mydb,
      'ALTER TABLE "invoices" ADD COLUMN "tax_base" REAL DEFAULT 0',
    );

    // ─── المرحلة ١: توسيع الضريبة والترقيم والمرتجعات ───
    //
    // `invoice_number_text` رقم الفاتورة المعروض (بادئة + حشو) منفصلًا عن
    // المفتاح الأساسي الرقمي؛ و`rounded_amount` الإجمالي بعد التقريب؛
    // و`tax_exempt_amount` الجزء المعفى؛ وحقلَا زاتكا للجاهزية فقط.
    for (final sql in <String>[
      'ALTER TABLE "invoices" ADD COLUMN "invoice_number_text" TEXT',
      'ALTER TABLE "invoices" ADD COLUMN "rounded_amount" REAL DEFAULT 0',
      'ALTER TABLE "invoices" ADD COLUMN "tax_exempt_amount" REAL DEFAULT 0',
      'ALTER TABLE "invoices" ADD COLUMN "credit_note_of" INTEGER',
      'ALTER TABLE "invoices" ADD COLUMN "zatca_status" TEXT',
      'ALTER TABLE "invoices" ADD COLUMN "zatca_uuid" TEXT',
      // ضريبة على مستوى البند (تتيح الإعفاء والمنتجات الصفرية)
      'ALTER TABLE "invoice_items" ADD COLUMN "tax_rate" REAL DEFAULT 0',
      'ALTER TABLE "invoice_items" ADD COLUMN "tax_base" REAL DEFAULT 0',
      'ALTER TABLE "invoice_items" ADD COLUMN "tax_amount" REAL DEFAULT 0',
      // ضريبة المدخلات على المصروفات
      'ALTER TABLE "expenses" ADD COLUMN "tax_number" TEXT',
      'ALTER TABLE "expenses" ADD COLUMN "tax_rate" REAL DEFAULT 0',
      'ALTER TABLE "expenses" ADD COLUMN "tax_base" REAL DEFAULT 0',
      'ALTER TABLE "expenses" ADD COLUMN "tax_amount" REAL DEFAULT 0',
    ]) {
      await _tryAlter(mydb, sql);
    }

    // ─── إشعارات دائن / مرتجعات (لتصحيح فاتورة صادرة بلا حذفها) ───
    await mydb.execute('''
      CREATE TABLE IF NOT EXISTS "credit_notes" (
        "credit_id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        "invoice_id" INTEGER,
        "customer_id" INTEGER,
        "reason" TEXT,
        "subtotal" REAL DEFAULT 0,
        "tax_amount" REAL DEFAULT 0,
        "total" REAL DEFAULT 0,
        "restock_value" REAL DEFAULT 0,
        "created_by" INTEGER,
        "created_at" TEXT NOT NULL,
        "zatca_uuid" TEXT
      )
    ''');

    // فهارس الأداء المذكورة في الدين التقني (تقارير نطاقات التاريخ والبحث)
    await mydb.execute(
      'CREATE INDEX IF NOT EXISTS "idx_invoices_date" '
      'ON "invoices" ("invoice_date")',
    );
    await mydb.execute(
      'CREATE INDEX IF NOT EXISTS "idx_customers_name" '
      'ON "customers" ("customer_name")',
    );
    await mydb.execute(
      'CREATE INDEX IF NOT EXISTS "idx_credit_notes_invoice" '
      'ON "credit_notes" ("invoice_id")',
    );

    // ─── تعبئة اللقطة للفواتير القديمة (مرة واحدة، غير مُتلِفة) ───
    // شرطان يحميانها: (1) حارس إعداد يمنع تكرارها، (2) تخطّي أي فاتورة لها
    // بنود مسجَّلة بالفعل — فلا تُضاعف صفوفًا ولا تُعيد كتابة لقطة صحيحة.
    // التكلفة المنسوخة هنا هي **التكلفة الحالية** لأن تكلفة يوم البيع ضاعت
    // أصلًا؛ تُوسَم في `note` بأنها مُستنتجة كي لا تُخلط بلقطة حقيقية.
    try {
      if (await getSetting('invoice_items_backfill_v1') != '1') {
        final clothingRows = await mydb.rawQuery(
          'SELECT clothing_id, clothing_name, COALESCE(cost_price, 0) AS cost '
          'FROM "clothing"',
        );
        final byName = <String, Map<String, dynamic>>{};
        for (final c in clothingRows) {
          final key = '${c['clothing_name'] ?? ''}'.trim();
          if (key.isNotEmpty) byName[key] = c;
        }

        final invoices = await mydb.rawQuery(
          'SELECT invoices_id, list_data FROM "invoices" '
          "WHERE list_data IS NOT NULL AND TRIM(list_data) <> '' "
          "  AND TRIM(list_data) <> '[]'",
        );
        var inserted = 0;
        for (final inv in invoices) {
          final iid = (inv['invoices_id'] as num?)?.toInt();
          if (iid == null) continue;
          final already = await mydb.rawQuery(
            'SELECT COUNT(*) AS n FROM "invoice_items" WHERE invoice_id = ?',
            [iid],
          );
          if (((already.first['n'] as num?)?.toInt() ?? 0) > 0) continue;

          final rows = _itemRowsFromJson(inv['list_data'], byName);
          for (final row in rows) {
            row['invoice_id'] = iid;
            row['note'] = 'لقطة مُستنتجة عند الترحيل';
            await mydb.insert(
              'invoice_items',
              row,
              conflictAlgorithm: ConflictAlgorithm.ignore,
            );
            inserted++;
          }
        }
        await updateSetting('invoice_items_backfill_v1', '1');
        debugPrint('تعبئة $inserted بند في invoice_items من الفواتير القديمة');
      }
    } catch (e) {
      debugPrint('invoice_items backfill skipped: $e');
    }
  }

  /// يحوّل بنود `list_data` إلى صفوف جاهزة لجدول `invoice_items`.
  ///
  /// التكلفة تُقرأ من خريطة `clothingByName` (لقطة الترحيل) — تُترك صفرًا إن
  /// لم يُطابق الاسم، ولا يُختلق رقم.
  List<Map<String, Object?>> _itemRowsFromJson(
    dynamic raw,
    Map<String, Map<String, dynamic>> clothingByName,
  ) {
    final out = <Map<String, Object?>>[];
    if (raw == null) return out;
    try {
      final decoded = jsonDecode(raw.toString());
      if (decoded is! List) return out;
      for (final item in decoded) {
        if (item is! Map) continue;
        final name = '${item['vestments'] ?? ''}'.trim();
        if (name.isEmpty) continue;
        final qty = _numOf(item['count']).round();
        final price = _numOf(item['price']);
        final lineTotal = _numOf(item['total_price']);
        final total = lineTotal > 0 ? lineTotal : price * qty;
        final c = clothingByName[name];
        final cost = c == null ? 0.0 : _numOf(c['cost']);
        out.add({
          'clothing_id': c == null ? null : (c['clothing_id'] as num?)?.toInt(),
          'item_name': name,
          'content': '${item['content'] ?? ''}',
          'qty': qty,
          'unit_price': price,
          'unit_cost': cost,
          'total_price': total,
          'total_cost': double.parse((cost * qty).toStringAsFixed(2)),
          'note': '${item['note'] ?? ''}',
          'created_at': DateTime.now().toIso8601String(),
        });
      }
    } catch (_) {}
    return out;
  }

  /// تحويل آمن إلى `double` — يتحمّل `num` والنص والفارغ.
  double _numOf(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse('${value ?? ''}') ?? 0.0;
  }

  /// مجموع بنود الفاتورة من عمود `list_data` (JSON نصي).
  ///
  /// يُعتمد `total_price` المخزَّن لكل بند، وإن غاب يُحسب `price × count`.
  /// يعمل مع الأرقام المخزَّنة كـ`num` أو كنص، لأن قواعد بيانات قديمة خزّنت
  /// النوعين معًا.
  double _itemsTotalFromJson(dynamic raw) {
    if (raw == null) return 0.0;
    try {
      final decoded = jsonDecode(raw.toString());
      if (decoded is! List) return 0.0;
      var total = 0.0;
      for (final item in decoded) {
        if (item is! Map) continue;
        final lineTotal = item['total_price'];
        final parsedLine =
            lineTotal is num
                ? lineTotal.toDouble()
                : double.tryParse('${lineTotal ?? ''}') ?? 0.0;
        if (parsedLine > 0) {
          total += parsedLine;
          continue;
        }
        final count =
            item['count'] is num
                ? (item['count'] as num).toDouble()
                : double.tryParse('${item['count'] ?? 0}') ?? 0.0;
        final price =
            item['price'] is num
                ? (item['price'] as num).toDouble()
                : double.tryParse('${item['price'] ?? 0}') ?? 0.0;
        total += price * count;
      }
      // تنظيف ضوضاء الفاصلة العائمة (مثل 44.699999999999996)
      return double.parse(total.toStringAsFixed(2));
    } catch (_) {
      return 0.0;
    }
  }

  Future<void> _tryAlter(Database db, String sql) async {
    try {
      await db.execute(sql);
      debugPrint('Migration OK: $sql');
    } catch (e) {
      debugPrint(
        'Migration skipped (already applied): ${e.toString().split('\n').first}',
      );
    }
  }
}
