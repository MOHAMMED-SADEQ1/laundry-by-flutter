import 'package:sqflite/sqflite.dart';

/// جسر **بلا دورة استيراد** بين `SqlDB` و`PermissionService`.
///
/// **المشكلة التي يحلّها:** خدمة الصلاحيات تحتاج اتصال القاعدة المفتوح
/// لتقرأ إسنادات الأدوار والتجاوزات — لكن `SqlDB` نفسه صار يحتاج
/// `PermissionService` (فحص `deleteOldInvoices`). فلو استورد أحدهما الآخر
/// لنشأت **دورة استيراد**؛ ودورة كهذه تجعل ترتيب التهيئة هشًّا ويكسر
/// القاعدة التي التزم بها المشروع في `setting_option.dart` (منطق خالص لا
/// يستورد طبقة القاعدة).
///
/// **الحل:** صندوق واحد يحمل مرجع الاتصال. `SqlDB` **يكتب** فيه (مالك
/// الاتصال)، و`PermissionService` **يقرأ** منه. فلا يعرف أحدهما الآخر.
///
/// **لافتح ضمني:** [connection] يعرض الموجود فقط؛ لا يفتح قاعدة ولا ينتظر
/// بوابة صيانة. فقراءة الصلاحيات في مسار الرسم بلا أثر جانبي — وإن لم
/// تكن القاعدة مفتوحة رجع `null` و`PermissionService.load` يبني من
/// الكتالوج الافتراضي.
class PermissionDbHandle {
  PermissionDbHandle._();

  static DatabaseExecutor? _connection;

  /// الاتصال المفتوح، أو `null`. **للقراءة فقط** من خدمة الصلاحيات.
  static DatabaseExecutor? get connection => _connection;

  /// يُحدّثه `SqlDB` عند فتح القاعدة أو إغلاقها.
  static void set(DatabaseExecutor? db) => _connection = db;

  /// يُفرّغه `SqlDB` عند إغلاق القاعدة (كي لا يبقى مرجع ميّت).
  static void clear() => _connection = null;
}
