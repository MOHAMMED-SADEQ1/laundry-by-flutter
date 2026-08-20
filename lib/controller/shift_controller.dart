import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:laundry/core/services/preparePDF.dart';
import 'package:laundry/sqldb.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ShiftController extends GetxController {
  final SqlDB _sqlDB = SqlDB();
  final RxBool isShiftActive = false.obs;
  final RxnInt activeShiftId = RxnInt();
  final RxString shiftStartTime = ''.obs;
  final RxString shiftStartTimeForQuery = ''.obs;

  final RxList<Map<String, dynamic>> closedShifts =
      <Map<String, dynamic>>[].obs;
  final RxBool isLoadingShifts = true.obs;

  @override
  void onInit() {
    super.onInit();
    checkActiveShift();
  }

  // التحقق من وجود وردية نشطة عند بدء التطبيق
  Future<void> checkActiveShift() async {
    final prefs = await SharedPreferences.getInstance();
    isShiftActive.value = prefs.getBool('is_shift_active') ?? false;
    if (isShiftActive.value) {
      activeShiftId.value = prefs.getInt('active_shift_id');
      shiftStartTimeForQuery.value =
          prefs.getString('shift_start_time_query') ?? '';
      shiftStartTime.value = prefs.getString('shift_start_time_display') ?? '';
    }
  }

  // بدء وردية جديدة
  Future<void> startShift() async {
    if (isShiftActive.value) {
      Get.snackbar('تنبيه', 'يوجد وردية مفتوحة بالفعل.');
      return;
    }

    try {
      String startTime = DateTime.now().toIso8601String();
      int shiftId = await _sqlDB.insertData(
        'INSERT INTO shifts (start_time) VALUES ("$startTime")',
      );

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('is_shift_active', true);
      await prefs.setInt('active_shift_id', shiftId);
      await prefs.setString('shift_start_time_query', startTime);
      await prefs.setString(
        'shift_start_time_display',
        DateFormat('yyyy-MM-dd hh:mm a').format(DateTime.parse(startTime)),
      );

      isShiftActive.value = true;
      activeShiftId.value = shiftId;
      shiftStartTimeForQuery.value = startTime;
      shiftStartTime.value = DateFormat(
        'yyyy-MM-dd hh:mm a',
      ).format(DateTime.parse(startTime));

      Get.snackbar(
        'نجاح',
        'تم فتح الوردية بنجاح.',
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    } catch (e) {
      Get.snackbar('خطأ', 'حدث خطأ أثناء فتح الوردية: $e');
    }
  }

  // إغلاق الوردية الحالية
  Future<void> closeShift() async {
    if (!isShiftActive.value || activeShiftId.value == null) {
      Get.snackbar('تنبيه', 'لا توجد وردية مفتوحة لإغلاقها.');
      return;
    }

    try {
      // 1. حساب ملخص الوردية
      final summaryList = await _sqlDB.readData('''
        SELECT
            SUM(CASE WHEN payment_method = 'كاش' THEN paid_amount ELSE 0 END) as total_cash,
            SUM(CASE WHEN payment_method = 'شبكة' THEN paid_amount ELSE 0 END) as total_network,
            COUNT(invoices_id) as invoice_count
        FROM invoices 
        WHERE shift_id = ${activeShiftId.value}
      ''');

      final summary =
          summaryList.isNotEmpty
              ? summaryList.first
              : {'total_cash': 0.0, 'total_network': 0.0, 'invoice_count': 0};
      final double totalCash =
          (summary['total_cash'] as num?)?.toDouble() ?? 0.0;
      final double totalNetwork =
          (summary['total_network'] as num?)?.toDouble() ?? 0.0;
      final int invoiceCount = (summary['invoice_count'] as num?)?.toInt() ?? 0;
      final String endTime = DateTime.now().toIso8601String();

      // 2. تحديث بيانات الوردية في قاعدة البيانات
      await _sqlDB.updateData('''
        UPDATE shifts 
        SET end_time = "$endTime", total_cash = $totalCash, total_network = $totalNetwork, invoice_count = $invoiceCount
        WHERE shift_id = ${activeShiftId.value}
      ''');

      // 3. تنظيف SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('is_shift_active');
      await prefs.remove('active_shift_id');
      await prefs.remove('shift_start_time_query');
      await prefs.remove('shift_start_time_display');

      // 4. تحديث الحالة في المتحكم
      final shiftDataForPrint = {
        'shift_id': activeShiftId.value,
        'start_time': shiftStartTimeForQuery.value,
        'end_time': endTime,
        'total_cash': totalCash,
        'total_network': totalNetwork,
        'invoice_count': invoiceCount,
      };

      isShiftActive.value = false;
      activeShiftId.value = null;
      shiftStartTime.value = '';
      shiftStartTimeForQuery.value = '';

      Get.snackbar(
        'نجاح',
        'تم إغلاق الوردية بنجاح.',
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );

      // 5. عرض خيار لطباعة الملخص
      Get.defaultDialog(
        title: "ملخص الوردية",
        middleText:
            "مجموع الكاش: $totalCash\nمجموع الشبكة: $totalNetwork\nعدد الفواتير: $invoiceCount",
        textConfirm: "طباعة",
        textCancel: "إغلاق",
        onConfirm: () {
          printShift(shiftDataForPrint);
          Get.back();
        },
      );
    } catch (e) {
      Get.snackbar('خطأ', 'حدث خطأ أثناء إغلاق الوردية: $e');
    }
  }

  // جلب الورديات المغلقة من قاعدة البيانات
  Future<void> fetchClosedShifts() async {
    try {
      isLoadingShifts.value = true;
      final data = await _sqlDB.readData(
        'SELECT * FROM shifts WHERE end_time IS NOT NULL ORDER BY shift_id DESC',
      );
      closedShifts.assignAll(data);
    } catch (e) {
      Get.snackbar('خطأ', 'فشل في تحميل الورديات السابقة.');
    } finally {
      isLoadingShifts.value = false;
    }
  }

  // طباعة ملخص الوردية
  Future<void> printShift(Map<String, dynamic> shiftData) async {
    try {
      final pdfBytes = await PreparePDF.generateShiftSummaryPdf(shiftData);
      await Printing.layoutPdf(onLayout: (PdfPageFormat format) => pdfBytes);
    } catch (e) {
      Get.snackbar('خطأ', 'فشل في طباعة ملخص الوردية: $e');
    }
  }

  // جلب فواتير وردية معينة
  Future<List<Map<String, dynamic>>> fetchShiftInvoices(int shiftId) async {
    try {
      return await _sqlDB.readData(
        'SELECT * FROM invoices WHERE shift_id = ? ORDER BY invoices_id DESC',
        [shiftId],
      );
    } catch (e) {
      debugPrint('Error fetching shift invoices: $e');
      return [];
    }
  }
}
