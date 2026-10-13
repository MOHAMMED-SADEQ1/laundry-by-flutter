import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:laundry/services/audit/audit_service.dart';

/// نطاقات زمنية جاهزة لسجل التدقيق
enum AuditRange { today, week, month, all }

extension AuditRangeX on AuditRange {
  String get label => switch (this) {
    AuditRange.today => 'اليوم',
    AuditRange.week => 'آخر 7 أيام',
    AuditRange.month => 'هذا الشهر',
    AuditRange.all => 'الكل',
  };

  (DateTime?, DateTime?) bounds() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return switch (this) {
      AuditRange.today => (today, today),
      AuditRange.week => (today.subtract(const Duration(days: 6)), today),
      AuditRange.month => (DateTime(now.year, now.month, 1), today),
      AuditRange.all => (null, null),
    };
  }
}

class AuditController extends GetxController {
  final AuditService _service = AuditService.instance;

  final RxList<AuditEntry> entries = <AuditEntry>[].obs;
  final RxList<String> availableActions = <String>[].obs;
  final RxBool isLoading = false.obs;

  final Rx<AuditRange> range = AuditRange.week.obs;
  final RxString actionFilter = ''.obs;
  /// إظهار الأحداث الحساسة وحدها (تجاوزات، حذف، إلغاءات)
  final RxBool sensitiveOnly = false.obs;

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> setRange(AuditRange r) async {
    range.value = r;
    await load();
  }

  Future<void> setActionFilter(String a) async {
    actionFilter.value = a;
    await load();
  }

  Future<void> toggleSensitiveOnly() async {
    sensitiveOnly.value = !sensitiveOnly.value;
    await load();
  }

  Future<void> load() async {
    isLoading.value = true;
    try {
      final (from, to) = range.value.bounds();
      final rows = await _service.list(
        from: from,
        to: to,
        action: actionFilter.value.isEmpty ? null : actionFilter.value,
      );
      entries.assignAll(
        sensitiveOnly.value ? rows.where((e) => e.isSensitive).toList() : rows,
      );
      if (availableActions.isEmpty) {
        availableActions.assignAll(await _service.distinctActions());
      }
    } catch (e) {
      debugPrint('AuditController.load error: $e');
    } finally {
      isLoading.value = false;
    }
  }
}
