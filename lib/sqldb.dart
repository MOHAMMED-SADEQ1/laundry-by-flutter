import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:laundry/config/constants.dart';
import 'package:laundry/services/security/security_service.dart';

class SqlDB {
  static Database? _db;

  Future<Database?> get dbGet async {
    if (_db != null) return _db;
    _db = await _initDB();
    return _db;
  }

  Future<Database> _initDB() async {
    String dataBasePath = await getDatabasesPath();
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
        "notes" TEXT
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
        "recorded_by" INTEGER
      )
    ''');

    // ──────────────────────────────────────────────
    // 8. جدول المخزون (inventory)
    // ──────────────────────────────────────────────
    await db.execute('''
      CREATE TABLE IF NOT EXISTS "inventory" (
        "item_id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        "name" TEXT NOT NULL,
        "category_id" INTEGER DEFAULT 0,
        "quantity" REAL DEFAULT 0,
        "unit" TEXT DEFAULT 'قطعة',
        "min_stock" INTEGER DEFAULT 5,
        "cost_price" REAL DEFAULT 0,
        "supplier_id" INTEGER,
        "last_updated" TEXT NOT NULL,
        "is_active" INTEGER DEFAULT 1
      )
    ''');

    // ──────────────────────────────────────────────
    // 9. جدول الموردين (suppliers)
    // ──────────────────────────────────────────────
    await db.execute('''
      CREATE TABLE IF NOT EXISTS "suppliers" (
        "supplier_id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        "name" TEXT NOT NULL,
        "phone" TEXT,
        "address" TEXT,
        "email" TEXT,
        "notes" TEXT,
        "is_active" INTEGER DEFAULT 1
      )
    ''');

    // ──────────────────────────────────────────────
    // 10. جدول المشتريات (purchases)
    // ──────────────────────────────────────────────
    await db.execute('''
      CREATE TABLE IF NOT EXISTS "purchases" (
        "purchase_id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        "supplier_id" INTEGER,
        "supplier_name" TEXT,
        "items" TEXT,
        "total_amount" REAL DEFAULT 0,
        "paid_amount" REAL DEFAULT 0,
        "date" TEXT NOT NULL,
        "notes" TEXT,
        "recorded_by" INTEGER
      )
    ''');

    // ──────────────────────────────────────────────
    // 11. جدول الخصومات (discounts)
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

    // إنشاء المستخدم الافتراضي (admin)
    final salt = SecurityService.generateSalt();
    final passwordHash = SecurityService.hashPassword(
      AppConstants.defaultAdminPassword,
      salt: salt,
    );
    final now = DateTime.now().toIso8601String();

    await db.insert('users', {
      'username': AppConstants.defaultAdminUsername,
      'password_hash': passwordHash,
      'role': 'admin',
      'is_active': 1,
      'created_at': now,
    });

    // إدخال الإعدادات الافتراضية
    await _insertDefaultSettings(db);

    Get.snackbar(
      "تم إنشاء قاعدة البيانات!",
      "تم إنشاء 13 جدول بنجاح",
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: Colors.green,
      colorText: Colors.white,
      duration: Duration(seconds: 3),
      icon: Icon(Icons.check_circle, color: Colors.white),
    );
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

        await db.execute('''
          CREATE TABLE IF NOT EXISTS "inventory" (
            "item_id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
            "name" TEXT NOT NULL,
            "category_id" INTEGER DEFAULT 0,
            "quantity" REAL DEFAULT 0,
            "unit" TEXT DEFAULT 'قطعة',
            "min_stock" INTEGER DEFAULT 5,
            "cost_price" REAL DEFAULT 0,
            "supplier_id" INTEGER,
            "last_updated" TEXT NOT NULL,
            "is_active" INTEGER DEFAULT 1
          )
        ''');

        await db.execute('''
          CREATE TABLE IF NOT EXISTS "suppliers" (
            "supplier_id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
            "name" TEXT NOT NULL,
            "phone" TEXT,
            "address" TEXT,
            "email" TEXT,
            "notes" TEXT,
            "is_active" INTEGER DEFAULT 1
          )
        ''');

        await db.execute('''
          CREATE TABLE IF NOT EXISTS "purchases" (
            "purchase_id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
            "supplier_id" INTEGER,
            "supplier_name" TEXT,
            "items" TEXT,
            "total_amount" REAL DEFAULT 0,
            "paid_amount" REAL DEFAULT 0,
            "date" TEXT NOT NULL,
            "notes" TEXT,
            "recorded_by" INTEGER
          )
        ''');

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

        // Create default admin user
        final salt = SecurityService.generateSalt();
        final passwordHash = SecurityService.hashPassword(
          AppConstants.defaultAdminPassword,
          salt: salt,
        );
        await db.insert('users', {
          'username': AppConstants.defaultAdminUsername,
          'password_hash': passwordHash,
          'role': 'admin',
          'is_active': 1,
          'created_at': DateTime.now().toIso8601String(),
        });

        await _insertDefaultSettings(db);

        Get.snackbar(
          "تم تحديث قاعدة البيانات!",
          "تم التحديث من الإصدار $oldVersion إلى $newVersion",
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.blue,
          colorText: Colors.white,
          duration: Duration(seconds: 3),
          icon: Icon(Icons.system_update, color: Colors.white),
        );
      } catch (e) {
        debugPrint('Migration error: $e');
      }
    }
  }

  Future<void> _insertDefaultSettings(Database db) async {
    final settings = [
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
      {'key': 'tax_rate', 'value': '0.15', 'description': 'نسبة الضريبة'},
      {
        'key': 'loyalty_rate',
        'value': '10',
        'description': 'نقاط الولاء لكل 10 ريال',
      },
      {'key': 'currency', 'value': 'ر.س', 'description': 'العملة'},
      {
        'key': 'invoice_start',
        'value': '100',
        'description': 'بداية ترقيم الفواتير',
      },
    ];

    for (final setting in settings) {
      await db.insert('settings', setting);
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

  Future<int> safeInsert(String table, Map<String, dynamic> data) async {
    Database? mydb = await dbGet;
    return await mydb!.insert(
      table,
      data,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
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
  // Delete old invoices (> 60 days)
  // ──────────────────────────────────────────────

  Future<void> deleteOldInvoices() async {
    Database? mydb = await dbGet;
    await mydb!.rawDelete(
      'DELETE FROM "invoices" WHERE JULIANDAY(\'now\') - JULIANDAY(invoice_date) > ?',
      [AppConstants.invoiceAutoDeleteDays],
    );
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

  Future<String> getDatabasePath() async {
    String dataBasePath = await getDatabasesPath();
    return join(dataBasePath, AppConstants.dbName);
  }

  Future<void> closeDB() async {
    Database? mydb = await dbGet;
    if (mydb != null) {
      await mydb.close();
      _db = null;
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

    // اشتراكات الزبائن الشهرية
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
        "recorded_by" INTEGER
      )
    ''');
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
