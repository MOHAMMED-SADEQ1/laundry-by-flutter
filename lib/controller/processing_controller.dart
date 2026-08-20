import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
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
      final rows = await db.safeRead(
        'users',
        where: 'role = ? AND is_active = 1',
        whereArgs: ['worker'],
        orderBy: 'full_name COLLATE NOCASE ASC',
      );
      if (rows.isEmpty) {
        // لو ما في عمال مسجلون، نعرض كل المستخدمين
        final all = await db.safeRead(
          'users',
          orderBy: 'full_name COLLATE NOCASE ASC',
        );
        workers.assignAll(all);
      } else {
        workers.assignAll(rows);
      }
    } catch (e) {
      debugPrint('loadWorkers error: $e');
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
        return w['full_name']?.toString() ?? w['username']?.toString() ?? '';
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
        },
        where: 'invoices_id = ?',
        whereArgs: [invoiceId],
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

  /// تسليم فاتورة مع سداد المتبقي إن وجد (كاش)
  Future<void> deliver(int invoiceId, Map<String, dynamic> inv) async {
    final remaining = double.tryParse('${inv['remaining_amount'] ?? 0}') ?? 0;
    if (remaining > 0) {
      await db.safeUpdate(
        'invoices',
        {
          'paid_amount':
              (double.tryParse('${inv['paid_amount'] ?? 0}') ?? 0) + remaining,
          'remaining_amount': 0.0,
        },
        where: 'invoices_id = ?',
        whereArgs: [invoiceId],
      );
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
      await loadInvoices();
    } catch (e) {
      debugPrint('assignWorker error: $e');
    }
  }
}
