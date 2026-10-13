import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:laundry/services/customer/customer_ledger_service.dart';
import 'package:laundry/services/security/session_manager.dart';
import 'package:laundry/sqldb.dart';

/// حالات فاتورة المصنعية
class ProcessingStatuses {
  static const String received = 'تم الاستلام';
  static const String inProgress = 'قيد التنفيذ';
  static const String ready = 'جاهز للاستلام';
  static const String delivered = 'تم التسليم';
}

class ProcessingController extends GetxController {
  final SqlDB db = SqlDB();
  final RxList<Map<String, dynamic>> invoices = <Map<String, dynamic>>[].obs;
  final RxList<Map<String, dynamic>> workers = <Map<String, dynamic>>[].obs;
  final RxBool isLoading = false.obs;
  final RxString tab = ProcessingStatuses.inProgress.obs;
  final RxString query = ''.obs;

  @override
  void onInit() {
    super.onInit();
    loadWorkers();
    loadInvoices();
  }

  Future<void> loadWorkers() async {
    try {
      // العمال أولاً (دور worker) ثم بقية المستخدمين النشطين — وكلهم صالحون
      // للتعيين في المصنعية. الترتيب بالأسماء مع احترام من بلا اسم كامل.
      final rows = await db.readData(
        'SELECT * FROM "users" WHERE is_active = 1 '
        "ORDER BY CASE WHEN role = 'worker' THEN 0 ELSE 1 END ASC, "
        "CASE WHEN full_name IS NULL OR TRIM(full_name) = '' THEN 1 ELSE 0 END ASC, "
        "COALESCE(NULLIF(TRIM(full_name), ''), username) COLLATE NOCASE ASC",
      );
      workers.assignAll(rows);
    } catch (e) {
      debugPrint('loadWorkers error: $e');
      workers.clear();
    }
  }

  Future<void> loadInvoices() async {
    isLoading.value = true;
    try {
      final rows = await db.safeRead(
        'invoices',
        where: 'status != ?',
        whereArgs: [ProcessingStatuses.delivered],
        orderBy: 'invoice_date DESC',
      );
      invoices.assignAll(rows);
    } catch (e) {
      debugPrint('loadInvoices error: $e');
    } finally {
      isLoading.value = false;
    }
  }

  List<Map<String, dynamic>> get visibleInvoices {
    final q = query.value.trim();
    return invoices.where((inv) {
      if (q.isEmpty) return true;
      final id = inv['invoices_id']?.toString() ?? '';
      final code = inv['pickup_code']?.toString() ?? '';
      final name = inv['customer_name']?.toString() ?? '';
      return id.contains(q) || code.contains(q) || name.contains(q);
    }).toList();
  }

  List<Map<String, dynamic>> get tabInvoices {
    return visibleInvoices.where((inv) {
      final status = inv['status']?.toString() ?? ProcessingStatuses.received;
      if (tab.value == 'unpicked') {
        return status == ProcessingStatuses.ready && _overdueDays(inv) >= 1;
      }
      if (tab.value == 'overdue') {
        return status != ProcessingStatuses.delivered && _overdueDays(inv) >= 3;
      }
      return status == tab.value;
    }).toList();
  }

  /// متوسط زمن إنجاز الطلبيات (بالدقائق) — من الاستلام حتى التسليم
  Future<String> computeAvgCompletion() async {
    try {
      final delivered = await db.safeRead(
        'invoices',
        where: 'status = ? AND status_updated_at IS NOT NULL',
        whereArgs: [ProcessingStatuses.delivered],
        orderBy: 'invoice_date DESC',
        limit: 50,
      );
      var totalMinutes = 0.0;
      var count = 0;
      for (final inv in delivered) {
        final received = DateTime.tryParse(
          inv['status_updated_at']?.toString() ?? '',
        );
        final created = DateTime.tryParse(
          inv['invoice_date']?.toString() ?? '',
        );
        if (received != null && created != null) {
          totalMinutes += received.difference(created).inMinutes;
          count++;
        }
      }
      if (count == 0) return '';
      final avg = totalMinutes / count;
      if (avg >= 1440) return '${(avg / 1440).toStringAsFixed(1)} يوم';
      if (avg >= 60) return '${(avg / 60).toStringAsFixed(0)} ساعة';
      return '${avg.toStringAsFixed(0)} دقيقة';
    } catch (_) {
      return '';
    }
  }

  int _overdueDays(Map<String, dynamic> inv) {
    final updated = inv['status_updated_at']?.toString();
    if (updated == null || updated.isEmpty) return 0;
    try {
      final t = DateTime.parse(updated);
      return DateTime.now().difference(t).inDays;
    } catch (_) {
      return 0;
    }
  }

  String workerName(dynamic assignedTo) {
    if (assignedTo == null) return '';
    for (final w in workers) {
      if ('${w['user_id']}' == '$assignedTo') {
        final full = w['full_name']?.toString().trim() ?? '';
        return full.isNotEmpty ? full : (w['username']?.toString() ?? '');
      }
    }
    return '';
  }

  String timeInStatus(Map<String, dynamic> inv) {
    final updated = inv['status_updated_at']?.toString();
    if (updated == null || updated.isEmpty) return '';
    try {
      final t = DateTime.parse(updated);
      final d = DateTime.now().difference(t);
      if (d.inDays > 0) return '${d.inDays} يوم';
      if (d.inHours > 0) return '${d.inHours} ساعة';
      if (d.inMinutes > 0) return '${d.inMinutes} دقيقة';
      return 'لحظات';
    } catch (_) {
      return '';
    }
  }

  List<Map<String, dynamic>> itemsOf(Map<String, dynamic> inv) {
    final raw = inv['list_data'];
    if (raw == null || raw.toString().isEmpty) return [];
    try {
      return List<Map<String, dynamic>>.from(jsonDecode(raw.toString()));
    } catch (_) {
      return [];
    }
  }

  /// تحديث حالة فاتورة + وقتها
  Future<void> updateStatus(int invoiceId, String status) async {
    try {
      await db.safeUpdate(
        'invoices',
        {
          'status': status,
          'status_updated_at': DateTime.now().toIso8601String(),
          'status_updated_by': SessionManager.currentUserId,
        },
        where: 'invoices_id = ?',
        whereArgs: [invoiceId],
      );

      await db.logAudit(
        userId: SessionManager.currentUserId,
        action: 'invoice_status_change',
        tableName: 'invoices',
        recordId: invoiceId,
        newValues: '{"status":"$status"}',
      );

      await loadInvoices();
      Get.snackbar(
        'تم',
        status == ProcessingStatuses.delivered
            ? 'تم تسليم الفاتورة رقم #$invoiceId'
            : 'تم تحديث حالة الفاتورة رقم #$invoiceId إلى "$status"',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: const Color(0xFF16A34A),
        colorText: const Color(0xFFFFFFFF),
        duration: const Duration(seconds: 2),
      );
    } catch (e) {
      debugPrint('updateStatus error: $e');
    }
  }

  /// تسليم فاتورة مع سداد المتبقي إن وجد (كاش).
  ///
  /// **إصلاح محاسبي:** السداد يُقيَّد في `customer_payments` (دفتر الأستاذ)
  /// أيضًا — لا في `invoices` وحده. سابقًا كان المتبقي يُصفَّر بلا أي قيد،
  /// فتنقص مدفوعات النقدية بصندوق اليوم بمقدار كل سداد عند التسليم.
  Future<void> deliver(int invoiceId, Map<String, dynamic> inv) async {
    final remaining = double.tryParse('${inv['remaining_amount'] ?? 0}') ?? 0;
    final customerId = inv['customer_id'] as int?;
    final paidBefore =
        double.tryParse('${inv['paid_amount'] ?? 0}') ?? 0;

    if (remaining > 0) {
      final userId = SessionManager.currentUserId;
      final now = DateTime.now().toIso8601String();

      // 1. تحديث الفاتورة: تُسدَّد بالكامل
      await db.safeUpdate(
        'invoices',
        {
          'paid_amount': paidBefore + remaining,
          'remaining_amount': 0.0,
        },
        where: 'invoices_id = ?',
        whereArgs: [invoiceId],
      );

      // 2. قيد السداد في دفتر الدفعات — يُربط بالفاتورة والزبون
      if (customerId != null) {
        await db.safeInsert('customer_payments', {
          'customer_id': customerId,
          'amount': remaining,
          'payment_method': 'كاش',
          'payment_date': now,
          'notes': 'سداد عند تسليم الفاتورة #$invoiceId',
          'recorded_by': userId,
          'source': 'delivery',
          'invoice_id': invoiceId,
        });

        await db.safeInsert('customer_balance_log', {
          'customer_id': customerId,
          'change_amount': -remaining,
          'balance_after': 0,
          'reason': 'delivery_payment',
          'reference_id': invoiceId,
          'created_at': now,
          'created_by': userId,
        });
      }

      await db.logAudit(
        userId: userId,
        action: 'invoice_delivered_with_payment',
        tableName: 'invoices',
        recordId: invoiceId,
        newValues:
            '{"paid_added":$remaining,"source":"delivery"}',
      );

      // 3. أعِد اشتقاق رصيد الزبون من الفواتير (لا تخمين)
      if (customerId != null) {
        await CustomerLedgerService.instance.syncBalance(customerId);
      }
    }

    await updateStatus(invoiceId, ProcessingStatuses.delivered);
  }

  Future<void> assignWorker(int invoiceId, int? workerId) async {
    try {
      await db.safeUpdate(
        'invoices',
        {'assigned_to': workerId},
        where: 'invoices_id = ?',
        whereArgs: [invoiceId],
      );

      await db.logAudit(
        userId: SessionManager.currentUserId,
        action: 'invoice_assign_worker',
        tableName: 'invoices',
        recordId: invoiceId,
        newValues: '{"assigned_to":$workerId}',
      );

      await loadInvoices();
    } catch (e) {
      debugPrint('assignWorker error: $e');
    }
  }
}
