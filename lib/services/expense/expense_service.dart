import 'package:flutter/foundation.dart';
import 'package:laundry/sqldb.dart';
import 'package:laundry/services/security/session_manager.dart';

/// أصناف المصروفات التشغيلية المعتادة لمغسلة — تُستخدم في القوائم المنسدلة.
/// التصنيف نصّي حر (يمكن إضافة غيره)، لكن هذه القائمة تُسرّع الإدخال
/// وتضمن تجميعًا نظيفًا في التقارير.
class ExpenseCategory {
  static const String materials = 'مواد ومستلزمات';
  static const String salaries = 'رواتب وأجور';
  static const String rent = 'إيجار';
  static const String electricity = 'كهرباء وماء';
  static const String maintenance = 'صيانة وإصلاح';
  static const String transport = 'نقل وتوصيل';
  static const String marketing = 'دعاية وإعلان';
  static const String government = 'رسوم حكومية';
  static const String other = 'أخرى';

  static const List<String> all = [
    materials,
    salaries,
    rent,
    electricity,
    maintenance,
    transport,
    marketing,
    government,
    other,
  ];
}

/// مصروف واحد في الكشف
class ExpenseRow {
  final int? expenseId;
  final String category;
  final String description;
  final double amount;
  final String date;
  final String paymentMethod;
  final int? recordedBy;

  /// ضريبة المدخلات المحتواة في [amount] (إن كان المصروف خاضعًا).
  final double taxAmount;

  /// الأساس قبل الضريبة (= amount − taxAmount).
  final double taxBase;

  /// رقم فاتورة المورّد (اختياري — لأثر ضريبي).
  final String taxNumber;

  const ExpenseRow({
    this.expenseId,
    required this.category,
    this.description = '',
    required this.amount,
    required this.date,
    this.paymentMethod = 'كاش',
    this.recordedBy,
    this.taxAmount = 0,
    this.taxBase = 0,
    this.taxNumber = '',
  });

  bool get hasInputVat => taxAmount > 0.004;

  factory ExpenseRow.fromMap(Map<String, dynamic> m) => ExpenseRow(
    expenseId: m['expense_id'] as int?,
    category: '${m['category'] ?? ''}',
    description: '${m['description'] ?? ''}',
    amount: (m['amount'] ?? 0).toDouble(),
    date: '${m['date'] ?? ''}',
    paymentMethod: '${m['payment_method'] ?? 'كاش'}',
    recordedBy: m['recorded_by'] as int?,
    taxAmount: (m['tax_amount'] ?? 0).toDouble(),
    taxBase: (m['tax_base'] ?? 0).toDouble(),
    taxNumber: '${m['tax_number'] ?? ''}',
  );
}

/// ملخّص مصروفات فترة
class ExpenseSummary {
  final double total;
  final int count;
  final List<MapEntry<String, double>> byCategory;
  final double cashTotal;
  final double nonCashTotal;

  const ExpenseSummary({
    this.total = 0,
    this.count = 0,
    this.byCategory = const [],
    this.cashTotal = 0,
    this.nonCashTotal = 0,
  });
}

/// محرّك المصروفات التشغيلية — الطبقة الوحيدة للكتابة والقراءة.
///
/// **لماذا هذا الملف موجود:** جدول `expenses` كان موجودًا منذ البداية مع
/// صلاحية `canManageExpenses` معرّفة في `PermissionService`، لكن **لا توجد
/// أي شاشة تُدخل مصروفًا**. الكاتب الوحيد في التطبيق كله كان استرداد إلغاء
/// الاشتراك. معنى ذلك أن كل مصاريف التشغيل (رواتب، إيجار، كهرباء، مواد)
/// لم تكن تُسجَّل ولا تُخصم، والرقم المعروض كـ«صافي الربح» كان **ربحًا
/// مساهمًا** لا ربحًا فعليًا.
class ExpenseService {
  ExpenseService._();
  static final ExpenseService instance = ExpenseService._();

  final SqlDB _db = SqlDB();

  /// حدود الفترة بصيغة نصية متسقة (yyyy-MM-dd) — تُبنى في Dart بتوقيت محلي.
  static String dayKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  /// إضافة مصروف — يرفض المبالغ غير الموجبة.
  Future<bool> add({
    required String category,
    required double amount,
    String description = '',
    DateTime? date,
    String paymentMethod = 'كاش',
    double taxRate = 0,
    double? taxAmount,
    String taxNumber = '',
  }) async {
    if (category.trim().isEmpty) {
      throw Exception('التصنيف مطلوب');
    }
    if (amount <= 0) {
      throw Exception('المبلغ يجب أن يكون أكبر من صفر');
    }
    final when = date ?? DateTime.now();
    // ضريبة المدخلات: تُمرَّر مباشرةً أو تُستخرج من نسبة على مبلغ **شامل**.
    final vat = _resolveVat(amount, taxRate, taxAmount);
    await _db.safeInsert('expenses', {
      'category': category.trim(),
      'description': description.trim(),
      'amount': amount,
      'date': when.toIso8601String(),
      'payment_method': paymentMethod,
      'recorded_by': SessionManager.currentUserId,
      'tax_rate': vat.rate,
      'tax_amount': vat.tax,
      'tax_base': vat.base,
      'tax_number': taxNumber.trim(),
      // shift_id يُحقن مركزيًا في SqlDB.safeInsert («الوردية هي الصندوق»)
    });
    return true;
  }

  /// يفصل الضريبة عن مبلغ شامل: يُمرَّر مبلغ صريح، وإلا يُستخرج من النسبة.
  static ({double rate, double tax, double base}) _resolveVat(
    double gross,
    double rate,
    double? explicitTax,
  ) {
    if (explicitTax != null && explicitTax > 0) {
      final tax = double.parse(explicitTax.toStringAsFixed(2));
      return (
        rate: gross > 0 ? double.parse((tax / gross).toStringAsFixed(4)) : 0.0,
        tax: tax,
        base: double.parse((gross - tax).toStringAsFixed(2)),
      );
    }
    if (rate <= 0 || rate > 1) {
      return (rate: 0.0, tax: 0.0, base: gross);
    }
    final base = gross / (1 + rate);
    final tax = gross - base;
    return (
      rate: rate,
      tax: double.parse(tax.toStringAsFixed(2)),
      base: double.parse(base.toStringAsFixed(2)),
    );
  }

  /// تعديل مصروف قائم
  Future<bool> update({
    required int expenseId,
    required String category,
    required double amount,
    String description = '',
    DateTime? date,
    String paymentMethod = 'كاش',
  }) async {
    if (amount <= 0) throw Exception('المبلغ يجب أن يكون أكبر من صفر');
    final rows = await _db.safeUpdate(
      'expenses',
      {
        'category': category.trim(),
        'description': description.trim(),
        'amount': amount,
        if (date != null) 'date': date.toIso8601String(),
        'payment_method': paymentMethod,
      },
      where: 'expense_id = ?',
      whereArgs: [expenseId],
    );
    return rows > 0;
  }

  Future<bool> delete(int expenseId) async {
    final rows = await _db.safeDelete(
      'expenses',
      where: 'expense_id = ?',
      whereArgs: [expenseId],
    );
    return rows > 0;
  }

  /// مصروفات فترة [من, إلى] — التواريخ محلية ومُبنية في Dart.
  Future<List<ExpenseRow>> list({
    required DateTime from,
    required DateTime to,
    String? category,
  }) async {
    try {
      // `DATE(date)` **بلا** `'localtime'`: `expenses.date` مخزَّن محليًا
      // أصلًا، فإضافتها تحويل مزدوج يزيح مصاريف ما بعد 21:00 (UTC+3) لليوم
      // التالي. وملاحظة مهمة: `report_controller._expensesFor` يحسب مصروفات
      // الفترة بنفس العمود، فأي اختلاف هنا يجعل **شاشة المصروفات والتقرير
      // يخالفان بعضهما لنفس الشهر** — وهو ما يُصلحه هذا التغيير في الملفين معًا.
      final args = <Object?>[dayKey(from), dayKey(to)];
      var sql =
          'SELECT * FROM expenses '
          "WHERE DATE(date) >= ? AND DATE(date) <= ?";
      if (category != null && category.trim().isNotEmpty) {
        sql += ' AND category = ?';
        args.add(category.trim());
      }
      sql += " ORDER BY DATE(date) DESC, expense_id DESC";
      final rows = await _db.readData(sql, args);
      return rows.map(ExpenseRow.fromMap).toList();
    } catch (e) {
      debugPrint('ExpenseService.list error: $e');
      return [];
    }
  }

  /// ملخّص الفترة: الإجمالي + التوزيع على التصنيفات + النقدي مقابل غير النقدي.
  ///
  /// فصل النقدي مهم لمطابقة الدرج: مصروف بالشبكة أو بالرصيد لا يخرج من
  /// درج النقد، فلا يجوز أن يُخصم منه عند الإقفال.
  Future<ExpenseSummary> summary({
    required DateTime from,
    required DateTime to,
  }) async {
    try {
      final rows = await list(from: from, to: to);
      if (rows.isEmpty) return const ExpenseSummary();

      var total = 0.0;
      var cash = 0.0;
      final byCat = <String, double>{};
      for (final r in rows) {
        total += r.amount;
        byCat[r.category] = (byCat[r.category] ?? 0) + r.amount;
        if (r.paymentMethod == 'كاش') cash += r.amount;
      }
      final sorted = byCat.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      return ExpenseSummary(
        total: total,
        count: rows.length,
        byCategory: sorted,
        cashTotal: cash,
        nonCashTotal: total - cash,
      );
    } catch (e) {
      debugPrint('ExpenseService.summary error: $e');
      return const ExpenseSummary();
    }
  }

  /// إجمالي مصروفات الفترة — للاستخدام في حساب صافي الربح.
  Future<double> totalFor({required DateTime from, required DateTime to}) async {
    final s = await summary(from: from, to: to);
    return s.total;
  }

  /// **ضريبة المدخلات القابلة للخصم** على مصروفات فترة.
  ///
  /// تُجمع من عمود `tax_amount` مباشرةً (تجميع في القاعدة بلا تحميل صفوف)،
  /// وتُعاد صفرًا إن كان العمود غير موجود في قاعدة قديمة.
  Future<double> inputVatFor({
    required DateTime from,
    required DateTime to,
  }) async {
    try {
      final rows = await _db.readData(
        'SELECT COALESCE(SUM(COALESCE(tax_amount, 0)), 0) AS vat '
        'FROM expenses WHERE DATE(date) >= ? AND DATE(date) <= ?',
        [dayKey(from), dayKey(to)],
      );
      return (rows.firstOrNull?['vat'] as num?)?.toDouble() ?? 0;
    } catch (e) {
      debugPrint('ExpenseService.inputVatFor error: $e');
      return 0;
    }
  }
}
