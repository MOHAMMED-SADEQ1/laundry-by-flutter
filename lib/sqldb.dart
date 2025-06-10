// import 'package:flutter/material.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
// import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

// void main() {
//   // تهيئة FFI لاستخدام SQLite على Windows
//   sqfliteFfiInit();

//   // تعيين factory لاستخدام FFI
//   databaseFactory = databaseFactoryFfi;

//   runApp(MyApp());
// }

// class MyApp extends StatelessWidget {
//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       home: Scaffold(
//         appBar: AppBar(title: Text("SQLite in Flutter Windows")),
//         body: Center(child: Text("Database Initialization Example")),
//       ),
//     );
//   }
// }

// //////////////////------android----/////////////////////////////////////////////////
// class SqlDB {
//   static Database? _db;

//   Future<Database?> get dbGet async {
//     if (_db != null) {
//       return _db;
//     } else {
//       _db = await intialDB();
//       return _db;
//     }
//   }

//   intialDB() async {
//     String dataBasePath = await getDatabasesPath();
//     String path = join(dataBasePath, 'glasses_laundries.db');
//     Database mydb = await openDatabase(path, version: 3, onCreate: _onCreate);
//     return mydb;
//   }

//   _onCreate(Database db, int version) async {
//     await db.execute('''
//              CREATE TABLE IF NOT EXISTS "clothing" (
//             "clothing_id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
//         "clothing_name" TEXT,
//         "normal_washing_and_ironing_price" REAL,
//         "urgent_washing_and_ironing_price" REAL,
//         "normal_ironing_price" REAL,
//         "urgent_ironing_price" REAL

//                 )
//           ''');
//     await db.execute('''
//             CREATE TABLE IF NOT EXISTS "numbers" (
//             "numbers_id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
//         "customer_name" TEXT,
//         "number_1" TEXT,
//         "number_2" TEXT
//                 )
//           ''');
// await db.execute('''  CREATE TABLE IF NOT EXISTS "invoice" (
//             "invoices_id" INTEGER NOT NULL PRIMARY KEY,
//             "list_data" TEXT,
//             "map_data" TEXT
//                 )  ''');

//     print(
//       "------------------------------------Tables have been created----------",
//     );
//   }

//   // Future<List<Map<String, Object?>>> getData(String tableName) async {
//   //   Database? db = await this.dbGet;
//   //   return await db!.query(tableName);
//   // }

//   // Future<List<Flight>> getCategoryList(String table_name) async{
//   //   var cateMapList = await getData(table_name);
//   //   print(cateMapList);
//   //   return cateMapList.map((row) => Flight.fromMap(row)).toList();
//   // }

//   readData(String sql) async {
//     Database? mydb = await dbGet;
//     List<Map> response = await mydb!.rawQuery(sql);
//     return response;
//   }

//   insertData(String sql) async {
//     Database? mydb = await dbGet;
//     int response = await mydb!.rawInsert(sql);
//     return response;
//   }

//   updateData(String sql) async {
//     Database? mydb = await dbGet;
//     int response = await mydb!.rawUpdate(sql);
//     return response;
//   }

//   deleteData(String sql) async {
//     Database? mydb = await dbGet;
//     int response = await mydb!.rawDelete(sql);
//     return response;
//   }
// }
//////////////////////////////////////////////////////////////////////////////////

//////////////////////// - Windows -////////////////////////////////////////////////////////////////////////
class SqlDB {
  static Database? _db;

  SqlDB() {
    sqfliteFfiInit(); // تهيئة FFI
    databaseFactory = databaseFactoryFfi; // تعيين factory
  }

  Future<Database?> get dbGet async {
    if (_db != null) {
      return _db;
    } else {
      _db = await intialDB();
      return _db;
    }
  }

  Future<Database> intialDB() async {
    String dataBasePath = await getDatabasesPath();
    String path = join(dataBasePath, 'glasses_laundries.db');

    Database mydb = await databaseFactory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 2,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS "clothing" (
            "clothing_id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        "clothing_name" TEXT,
        "normal_washing_and_ironing_price" REAL,
        "urgent_washing_and_ironing_price" REAL,
        "normal_ironing_price" REAL,
        "urgent_ironing_price" REAL
 
                )
          ''');

          await db.execute('''
            CREATE TABLE IF NOT EXISTS "numbers" (
            "numbers_id" INTEGER NOT NULL PRIMARY KEY,
        "customer_name" TEXT,
        "number_1" TEXT,
        "number_2" TEXT
                )
          ''');
          await db.execute('''  
          CREATE TABLE IF NOT EXISTS "invoice" (
        "invoices_id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        "list_data" TEXT,
        "map_data" TEXT,
        "in_date" DATE DEFAULT CURRENT_DATE
        ) ''');
          print(
            "-------------------Tables have been created-------------------------------",
          );
        },
      ),
    );

    return mydb;
  }

  deleteInvoice() async {
    Database? mydb = await dbGet;
    await mydb!.execute('''
DELETE FROM "invoice" 
    WHERE JULIANDAY('now') - JULIANDAY("in_date") > 20
''');
  }

  readData(String sql) async {
    Database? mydb = await dbGet;
    List<Map> response = await mydb!.rawQuery(sql);
    return response;
  }

  insertData(String sql) async {
    Database? mydb = await dbGet;
    int response = await mydb!.rawInsert(sql);
    return response;
  }

  void deleteDB() async {
    // تهيئة FFI قبل تنفيذ أي عمليات
    // sqfliteFfiInit();
    // databaseFactory = databaseFactoryFfi;

    // الحصول على مسار قاعدة البيانات
    String dataBasePath = await getDatabasesPath();
    String path = join(dataBasePath, 'glasses_laundries.db');

    // حذف قاعدة البيانات
    await databaseFactory.deleteDatabase(path);

    print("Database deleted successfully!");
  }

  Future<String> printDatabasePath() async {
    String dataBasePath = await getDatabasesPath();
    String path = join(dataBasePath, 'glasses_laundries.db');

    print("Database path: $path");
    return path;
  }

  updateData(String sql) async {
    Database? mydb = await dbGet;
    int response = await mydb!.rawUpdate(sql);
    return response;
  }

  deleteData(String sql) async {
    Database? mydb = await dbGet;
    int response = await mydb!.rawDelete(sql);
    return response;
  }
}


/////////////////////////////////////////////////////////////////////////////////////////












// import 'package:sqflite/sqflite.dart';
// import 'package:path/path.dart';



// class SqlDB {
//   // String TABLE_FLIGHT_NAME = "national";
//   static Database? _db;

//   Future<Database?> get dbGet async {
//     if (_db != null) {
//       return _db;
//     } else {
//       _db = await intialDB();
//       return _db;
//     }
//   }



//   intialDB() async{
//     String dataBasePath = await getDatabasesPath();
//     String path = join(dataBasePath ,'national.db');
//     Database mydb = await openDatabase(path,version: 2, onCreate: _onCreate);
//     return mydb;
//   }


//   _onCreate(Database db, int version) async{
//     await db.execute('''
//               CREATE TABLE IF NOT EXISTS "denied" (
//                 "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
//                 "treatment" TEXT,
//                 "rejection_reason" TEXT,
//                 "manage" TEXT
//               )
//           ''');

//           print("------------------------------------Tables have been created----------");
//   }
// }

