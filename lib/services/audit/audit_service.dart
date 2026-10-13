import 'package:flutter/foundation.dart';
import 'package:laundry/sqldb.dart';

/// صف واحد في سجل التدقيق (مع اسم المستخدم والوقت المرجعي)
class AuditEntry {
  final int logId;
  final int? userId;
  final String userName;
  final String action;
  final String tableName;
  final int? recordId;
  final String? oldValues;
  final String? newValues;
  final DateTime? timestamp;

  const AuditEntry({
    required this.logId,
    this.userId,
    this.userName = '',
    required this.action,
    required this.tableName,
    this.recordId,
    this.oldValues,
    this.newValues,
    this.timestamp,
  });

  factory AuditEntry.fromMap(Map<String, dynamic> m) => AuditEntry(
    logId: (m['log_id'] ?? 0) as int,
    userId: m['user_id'] as int?,
    userName: '${m['user_name'] ?? m['username'] ?? ''}',
    action: '${m['action'] ?? ''}',
    tableName: '${m['table_name'] ?? ''}',
    recordId: m['record_id'] as int?,
    oldValues: m['old_values']?.toString(),
    newValues: m['new_values']?.toString(),
    timestamp: DateTime.tryParse('${m['timestamp'] ?? ''}'),
  );

  /// عنوان عربي مقروء للحدث
  String get actionLabel {
    switch (action) {
      case 'credit_limit_override':
        return 'تجاوز حدّ الائتمان';
      case 'credit_limit_set':
        return 'تعديل حدّ الائتمان';
      case 'subscription_usage_blocked':
        return 'منع تجاوز سقف اشتراك';
      case 'subscription_usage_override':
        return 'تجاوز سقف اشتراك';
      case 'subscription_pay':
        return 'دفعة اشتراك';
      case 'subscription_cancel':
        return 'إلغاء اشتراك';
      case 'invoice_create':
        return 'إنشاء فاتورة';
      case 'invoice_credit_use':
        return 'استهلاك رصيد';
      case 'invoice_delete':
        return 'حذف فاتورة';
      case 'customer_delete':
        return 'حذف زبون';
      case 'shift_close':
        return 'إقفال وردية';
      case 'shift_open':
        return 'فتح وردية';
      case 'balance_repair':
        return 'إصلاح أرصدة';
      case 'user_create':
        return 'إضافة مستخدم';
      case 'user_delete':
        return 'حذف مستخدم';
      default:
        return action.replaceAll('_', ' ');
    }
  }

  /// جدول عربي مقروء
  String get tableLabel {
    switch (tableName) {
      case 'invoices':
        return 'الفواتير';
      case 'customers':
        return 'الزبائن';
      case 'subscriptions':
        return 'الاشتراكات';
      case 'expenses':
        return 'المصروفات';
      case 'clothing':
        return 'الأصناف';
      case 'shifts':
        return 'الورديات';
      case 'users':
        return 'المستخدمون';
      case 'settings':
        return 'الإعدادات';
      default:
        return tableName;
    }
  }

  /// هل الحدث يستحق التنبيه؟ (تجاوزات وتغييرات حساسة)
  bool get isSensitive {
    const sensitive = {
      'credit_limit_override',
      'credit_limit_set',
      'subscription_usage_override',
      'subscription_usage_blocked',
      'subscription_cancel',
      'invoice_delete',
      'customer_delete',
      'balance_repair',
      'user_delete',
      'user_create',
    };
    return sensitive.contains(action);
  }
}

/// محرّك سجل التدقيق — القراءة والفلترة.
///
/// **لماذا هذا الملف موجود:** `logAudit` كان يُستدعى في **24 موضعًا** في
/// التطبيق كله (تجاوزات الائتمان، تجاوزات سقف الاشتراك، الإلغاءات، تعديل
/// الأصناف، إغلاق الورديات…) بينما **لا يوجد أي استعلام واحد** على جدول
/// `audit_log`، ولا شاشة تعرضه. أي أن النظام كان يسجّل كل شيء ولا يُظهر
/// أي شيء — تدقيق نظري لا تدقيق فعلي.
class AuditService {
  AuditService._();
  static final AuditService instance = AuditService._();

  final SqlDB _db = SqlDB();

  /// جلب السجل مع اسم المستخدم، بفلاتر اختيارية.
  Future<List<AuditEntry>> list({
    DateTime? from,
    DateTime? to,
    String? action,
    String? tableName,
    int limit = 300,
  }) async {
    try {
      final where = <String>[];
      final args = <Object?>[];

      // ⚠️ `DATE(عمود)` **بلا** `'localtime'` — انظر شرح القاعدة في أعلى [_listWithoutJoin].
      if (from != null) {
        where.add('DATE(a.timestamp) >= ?');
        args.add(_key(from));
      }
      if (to != null) {
        where.add('DATE(a.timestamp) <= ?');
        args.add(_key(to));
      }
      if (action != null && action.isNotEmpty) {
        where.add('a.action = ?');
        args.add(action);
      }
      if (tableName != null && tableName.isNotEmpty) {
        where.add('a.table_name = ?');
        args.add(tableName);
      }

      final sql = StringBuffer(
        'SELECT a.*, u.username AS user_name '
        'FROM audit_log a '
        'LEFT JOIN users u ON u.user_id = a.user_id ',
      );
      if (where.isNotEmpty) {
        sql.write('WHERE ${where.join(' AND ')} ');
      }
      sql.write('ORDER BY a.log_id DESC LIMIT ?');
      args.add(limit);

      final rows = await _db.readData(sql.toString(), args);
      return rows.map(AuditEntry.fromMap).toList();
    } catch (e) {
      // إن لم يوجد جدول users أو العمود، نرجع بلا ربط
      debugPrint('AuditService.list error: $e');
      return _listWithoutJoin(from: from, to: to, limit: limit);
    }
  }

  /// مسار احتياطي بلا ربط المستخدمين (لأي قاعدة غير مكتملة)
  ///
  /// ⚠️ **قاعدة الفلترة الزمنية (لا تُخالَف):** `DATE(عمود)` **بلا**
  /// `'localtime'`.
  ///
  /// **لماذا:** كل طوابع المشروع تُكتب **محلية**
  /// (`DateTime.now().toIso8601String()`، ولا `toUtc()` في أي موضع).
  /// وSQLite تفترض أن نص الطابع **UTC**، فإضافة `'localtime'` تُجري تحويلًا
  /// **ثانيًا** يزيح اليوم بمقدار إزاحة الجهاز — على UTC+3 تصير كل فاتورة أو
  /// حدث بعد **21:00 محليًا** منسوبًا لليوم التالي. (قياسه في
  /// `tool/verify_localtime_removal.py`.)
  ///
  /// أما `DATE('now', 'localtime')` فـ**صحيحة وواجبة البقاء**: `'now'` في
  /// SQLite وقت **UTC فعلًا**، فتحويله للمحلي هو الصواب، وبدونه تضيع آخر
  /// 3 ساعات من اليوم في توقيت UTC+3.
  Future<List<AuditEntry>> _listWithoutJoin({
    DateTime? from,
    DateTime? to,
    int limit = 300,
  }) async {
    try {
      final where = <String>[];
      final args = <Object?>[];
      if (from != null) {
        where.add('DATE(timestamp) >= ?');
        args.add(_key(from));
      }
      if (to != null) {
        where.add('DATE(timestamp) <= ?');
        args.add(_key(to));
      }
      final sql = StringBuffer('SELECT * FROM audit_log ');
      if (where.isNotEmpty) sql.write('WHERE ${where.join(' AND ')} ');
      sql.write('ORDER BY log_id DESC LIMIT ?');
      args.add(limit);
      final rows = await _db.readData(sql.toString(), args);
      return rows.map(AuditEntry.fromMap).toList();
    } catch (e) {
      debugPrint('AuditService fallback error: $e');
      return [];
    }
  }

  /// أنواع الأحداث الموجودة فعلًا في القاعدة — لبناء قائمة الفلتر ديناميكيًا
  /// بدون إظهار خيارات فارغة.
  Future<List<String>> distinctActions() async {
    try {
      final rows = await _db.readData(
        'SELECT DISTINCT action FROM audit_log ORDER BY action',
      );
      return rows.map((r) => '${r['action'] ?? ''}').where((s) => s.isNotEmpty).toList();
    } catch (_) {
      return [];
    }
  }

  /// عدد الأحداث الحساسة في نطاق — يُستخدم لعدّاد تنبيهي.
  Future<int> sensitiveCount({DateTime? from, DateTime? to}) async {
    try {
      const sensitive = [
        'credit_limit_override',
        'credit_limit_set',
        'subscription_usage_override',
        'subscription_usage_blocked',
        'subscription_cancel',
        'invoice_delete',
        'customer_delete',
        'balance_repair',
        'user_delete',
      ];
      final where = <String>[];
      final args = <Object?>[];
      if (from != null) {
        where.add('DATE(timestamp) >= ?');
        args.add(_key(from));
      }
      if (to != null) {
        where.add('DATE(timestamp) <= ?');
        args.add(_key(to));
      }
      final placeholders = List.filled(sensitive.length, '?').join(', ');
      where.add('action IN ($placeholders)');
      args.addAll(sensitive);

      final rows = await _db.readData(
        'SELECT COUNT(*) AS c FROM audit_log WHERE ${where.join(' AND ')}',
        args,
      );
      return (rows.first['c'] ?? 0) as int;
    } catch (e) {
      debugPrint('AuditService.sensitiveCount error: $e');
      return 0;
    }
  }

  static String _key(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}
