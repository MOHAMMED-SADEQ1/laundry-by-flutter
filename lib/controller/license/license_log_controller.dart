import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:laundry/services/license/license_event.dart';
import 'package:laundry/services/license/license_log_service.dart';

/// متحكّم شاشة سجل الترخيص — قراءة أحداثه وعرضها.
///
/// القراءة فقط: هذا السجل **أثر تدقيقي**، ولا تُعدَّل صفوفه ولا تُحذف. وأي
/// تغيير جديد على الترخيص يُضاف من مساره (`license_seed` / `license_update`)
/// ثم يظهر هنا.
class LicenseLogController extends GetxController {
  final LicenseLogService _service = LicenseLogService.instance;

  final RxList<LicenseEvent> events = <LicenseEvent>[].obs;
  final RxBool isLoading = false.obs;

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load() async {
    isLoading.value = true;
    try {
      events.assignAll(await _service.list());
    } catch (e) {
      debugPrint('LicenseLogController.load error: $e');
    } finally {
      isLoading.value = false;
    }
  }

  /// عدد أحداث تطبيق تاريخ الكود — يُعرض في الملخص.
  int get seedCount => events.where((e) => e.isSeed).length;

  /// عدد التعديلات اليدوية (تجديد/إلغاء) — يُعرض في الملخص.
  int get manualCount => events.where((e) => e.isManual).length;
}
