import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:laundry/core/services/preparePDF.dart';
import 'package:laundry/core/theme/app_colors.dart';
import 'package:laundry/sqldb.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:laundry/services/business_info_service.dart';
import 'package:laundry/services/security/session_manager.dart';

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

  /// التحقق من وجود وردية نشطة — يقرأ من قاعدة البيانات
  /// الوردية مفتوحة إذا كان end_time IS NULL
  Future<void> checkActiveShift() async {
    try {
      final rows = await _sqlDB.readData(
        'SELECT * FROM shifts WHERE end_time IS NULL ORDER BY shift_id DESC LIMIT 1',
      );

      if (rows.isNotEmpty) {
        final shift = rows.first;
        final shiftId = shift['shift_id'] as int;
        final startTime = shift['start_time']?.toString() ?? '';

        isShiftActive.value = true;
        activeShiftId.value = shiftId;
        shiftStartTimeForQuery.value = startTime;

        if (startTime.isNotEmpty) {
          try {
            shiftStartTime.value = DateFormat('yyyy-MM-dd hh:mm a')
                .format(DateTime.parse(startTime));
          } catch (_) {
            shiftStartTime.value = startTime;
          }
        }
      } else {
        isShiftActive.value = false;
        activeShiftId.value = null;
        shiftStartTime.value = '';
        shiftStartTimeForQuery.value = '';
      }
    } catch (e) {
      debugPrint('checkActiveShift error: $e');
      isShiftActive.value = false;
      activeShiftId.value = null;
    }
  }

  /// بدء وردية جديدة
  Future<void> startShift() async {
    // أولاً: تأكد لا توجد وردية مفتوحة
    await checkActiveShift();
    if (isShiftActive.value) {
      Get.snackbar('تنبيه', 'يوجد وردية مفتوحة بالفعل.');
      return;
    }

    try {
      String startTime = DateTime.now().toIso8601String();
      final userId = SessionManager.currentUserId;
      int shiftId = await _sqlDB.safeInsert('shifts', {
        'start_time': startTime,
        'opened_by': userId,
      });

      await _sqlDB.logAudit(
        userId: userId,
        action: 'shift_open',
        tableName: 'shifts',
        recordId: shiftId,
        newValues: '{"start_time":"$startTime"}',
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

  /// إغلاق الوردية الحالية
  Future<void> closeShift() async {
    if (!isShiftActive.value || activeShiftId.value == null) {
      Get.snackbar('تنبيه', 'لا توجد وردية مفتوحة لإغلاقها.');
      return;
    }

    try {
      // 1. حساب ملخص الوردية — **كله مشتقّ من `shift_id`**
      //
      // **القاعدة المعمارية:** «الوردية هي الصندوق». كل حركة تُنسب بالمعرّف
      // لا بالوقت. وكان الربط الزمني هنا (`datetime(x) >= shift_start`)
      // **بلا حدّ أعلى**، فتُحتسب دفعة حدثت *بعد* إقفال الوردية ضمنها
      // ⇒ تضخيم الإيداع. والأخطر: **المصروفات كانت غائبة تمامًا** عن
      // الإقفال، فلا يُخصم ما خرج من الدرج ⇒ عجز وهمي يُحمَّل على الكاشير.
      final int shiftId = activeShiftId.value!;

      // 1.a الفواتير النقدية والشبكية
      final summaryList = await _sqlDB.readData(
        'SELECT SUM(CASE WHEN payment_method = ? THEN paid_amount ELSE 0 END) '
        '  as total_cash, '
        'SUM(CASE WHEN payment_method = ? THEN paid_amount ELSE 0 END) '
        '  as total_network, '
        'COUNT(invoices_id) as invoice_count '
        'FROM invoices WHERE shift_id = ? AND subscription_id IS NULL',
        ['كاش', 'شبكة', shiftId],
      );

      final summary = summaryList.isNotEmpty
          ? summaryList.first
          : {'total_cash': 0.0, 'total_network': 0.0, 'invoice_count': 0};
      var totalCash = (summary['total_cash'] as num?)?.toDouble() ?? 0.0;
      var totalNetwork = (summary['total_network'] as num?)?.toDouble() ?? 0.0;
      final int invoiceCount =
          (summary['invoice_count'] as num?)?.toInt() ?? 0;

      // ─── 1.b دفعات الاشتراكات — بالمعرّف لا بالنافذة الزمنية ───
      final subPays = await _sqlDB.readData(
        'SELECT '
        '  COALESCE(SUM(CASE WHEN method = ? THEN amount ELSE 0 END), 0) '
        '    as cash, '
        '  COALESCE(SUM(CASE WHEN method = ? THEN amount ELSE 0 END), 0) '
        '    as network '
        'FROM subscription_payments '
        'WHERE shift_id = ? '
        "  AND COALESCE(source, 'manual') != 'cancel_refund'",
        ['كاش', 'شبكة', shiftId],
      );
      if (subPays.isNotEmpty) {
        totalCash += (subPays.first['cash'] as num?)?.toDouble() ?? 0.0;
        totalNetwork += (subPays.first['network'] as num?)?.toDouble() ?? 0.0;
      }

      // ─── 1.c سداد ذمم الزبائن ───
      // نستثني `credit_use`: استهلاك سلفة تسوية لا نقدية.
      final debtPays = await _sqlDB.readData(
        'SELECT '
        '  COALESCE(SUM(CASE WHEN payment_method = ? THEN amount ELSE 0 END), '
        '    0) as cash, '
        '  COALESCE(SUM(CASE WHEN payment_method = ? THEN amount ELSE 0 END), '
        '    0) as network '
        'FROM customer_payments '
        'WHERE shift_id = ? '
        "  AND COALESCE(source, 'manual') != 'credit_use'",
        ['كاش', 'شبكة', shiftId],
      );
      if (debtPays.isNotEmpty) {
        totalCash += (debtPays.first['cash'] as num?)?.toDouble() ?? 0.0;
        totalNetwork += (debtPays.first['network'] as num?)?.toDouble() ?? 0.0;
      }

      // ─── 1.d خصم استردادات الاشتراكات **النقدية** فقط ───
      //
      // الاسترداد قد يكون رصيدًا دائنًا (`method = 'رصيد'`) وهو تسوية دفاتر
      // لا نقدية — لم تخرج من الدرج فلا يجوز خصمها، وإلا ظهر عجز وهمي.
      final refunds = await _sqlDB.readData(
        'SELECT COALESCE(SUM(amount), 0) as t FROM subscription_payments '
        'WHERE shift_id = ? '
        "  AND COALESCE(source, 'manual') = 'cancel_refund' "
        '  AND method != ?',
        [shiftId, 'رصيد'],
      );
      if (refunds.isNotEmpty) {
        totalCash -= (refunds.first['t'] as num?)?.toDouble() ?? 0.0;
      }

      // ─── 1.e المصروفات النقدية الخارجة من الدرج ───
      //
      // **كانت غائبة تمامًا عن الإقفال**: المصروف يخرج نقدًا من الدرج ولا
      // يُخصم، فيُقفل الكاشير على مبلغ أكبر من الموجود فعلًا ويُحمَّل الفرق
      // عليه بلا سبب. مصروف الشبكة/التسوية لا يخرج من الدرج فلا يُخصم.
      final expensesOut = await _sqlDB.readData(
        'SELECT COALESCE(SUM(amount), 0) as t FROM expenses '
        'WHERE shift_id = ? AND COALESCE(payment_method, ?) = ?',
        [shiftId, 'كاش', 'كاش'],
      );
      final double cashExpenses = expensesOut.isEmpty
          ? 0.0
          : (expensesOut.first['t'] as num?)?.toDouble() ?? 0.0;

      // ─── 1.f رصيد الافتتاح الفعلي + المتوقع في الدرج ───
      final openRows = await _sqlDB.readData(
        'SELECT COALESCE(opening_balance, 0) as ob FROM shifts '
        'WHERE shift_id = ?',
        [shiftId],
      );
      final double openingBalance = openRows.isEmpty
          ? 0.0
          : (openRows.first['ob'] as num?)?.toDouble() ?? 0.0;
      final double expectedCash = openingBalance + totalCash - cashExpenses;

      final String endTime = DateTime.now().toIso8601String();

      // ═══ 2. الجرد — هنا يُخزَّن الصندوق فعلًا ═══
      //
      // كل ما سبق **مشتقّ** من الحركات. أما ما عُدَّ نقدًا في الدرج، وما
      // الفرق، وما سببه — فهو **غير قابل للاشتقاق**، لذا يُسأل عنه صراحةً.
      final stocktake = await _askStocktake(expectedCash, cashExpenses);
      final double? countedCash = stocktake?['counted'] as double?;
      final String? differenceReason = stocktake?['reason'] as String?;
      final double? difference = countedCash == null
          ? null
          : countedCash - expectedCash;

      // 3. تحديث بيانات الوردية في قاعدة البيانات
      final userId = SessionManager.currentUserId;
      await _sqlDB.safeUpdate(
        'shifts',
        {
          'end_time': endTime,
          'total_cash': totalCash,
          'total_network': totalNetwork,
          'invoice_count': invoiceCount,
          'closed_by': userId,
          'counted_cash': countedCash,
          'cash_difference': difference,
          'difference_reason': differenceReason,
          'stocktake_at': DateTime.now().toIso8601String(),
        },
        where: 'shift_id = ?',
        whereArgs: [activeShiftId.value],
      );

      await _sqlDB.logAudit(
        userId: userId,
        action: 'shift_close',
        tableName: 'shifts',
        recordId: activeShiftId.value,
        newValues:
            '{"total_cash":$totalCash,"total_network":$totalNetwork,'
            '"invoice_count":$invoiceCount,'
            '"expected":$expectedCash,"counted":$countedCash,'
            '"difference":$difference}',
      );

      // 4. تحديث الحالة في المتحكم
      final shiftDataForPrint = {
        'shift_id': shiftId,
        'start_time': shiftStartTimeForQuery.value,
        'end_time': endTime,
        'total_cash': totalCash,
        'total_network': totalNetwork,
        'invoice_count': invoiceCount,
        'opening_balance': openingBalance,
        'cash_expenses': cashExpenses,
        'expected_cash': expectedCash,
        'counted_cash': countedCash,
        'cash_difference': difference,
        'difference_reason': differenceReason,
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

      // 5. عرض خيار لطباعة الملخص — مع نتيجة الجرد
      final diffText = countedCash == null
          ? 'الدرج: لم يُجرَد'
          : (difference ?? 0).abs() < 0.01
          ? 'الدرج: مطابق'
          : (difference ?? 0) > 0
          ? 'الدرج: زيادة ${(difference ?? 0).toStringAsFixed(2)}'
          : 'الدرج: عجز ${(difference ?? 0).abs().toStringAsFixed(2)}';

      Get.defaultDialog(
        title: 'ملخص الوردية',
        middleText:
            'المقبوضات: ${totalCash.toStringAsFixed(2)}\n'
            'الشبكة: ${totalNetwork.toStringAsFixed(2)}\n'
            'السحوبات النقدية: ${cashExpenses.toStringAsFixed(2)}\n'
            'المتوقع في الدرج: ${expectedCash.toStringAsFixed(2)}\n'
            'المعدود: ${countedCash?.toStringAsFixed(2) ?? '—'}\n'
            '$diffText\n'
            'عدد الفواتير: $invoiceCount',
        textConfirm: 'طباعة',
        textCancel: 'إغلاق',
        onConfirm: () {
          printShift(shiftDataForPrint);
          Get.back();
        },
      );
    } catch (e) {
      Get.snackbar('خطأ', 'حدث خطأ أثناء إغلاق الوردية: $e');
    }
  }

  /// جلب الورديات المغلقة من قاعدة البيانات
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

  /// طباعة ملخص الوردية
  Future<void> printShift(Map<String, dynamic> shiftData) async {
    try {
      shiftData['bizName'] = BusinessInfoService.instance.name;
      shiftData['bizPhone'] = BusinessInfoService.instance.phone;
      shiftData['bizAddress'] = BusinessInfoService.instance.address;
      final pdfBytes = await PreparePDF.generateShiftSummaryPdf(shiftData);
      await Printing.layoutPdf(onLayout: (PdfPageFormat format) => pdfBytes);
    } catch (e) {
      Get.snackbar('خطأ', 'فشل في طباعة ملخص الوردية: $e');
    }
  }

  /// حوار الجرد عند الإقفال: المبلغ المعدود فعليًا في الدرج + سبب الفرق.
  ///
  /// يُعيد `{'counted': double, 'reason': String?}` أو `null` إن أُقفل بلا
  /// جرد. والفرق بين `null` و`0` جوهري: `null` = **لم يُجرَد**، و`0` =
  /// **جُرِد وطابق**. خلطهما يمحو معلومة محاسبية حقيقية.
  Future<Map<String, dynamic>?> _askStocktake(
    double expected,
    double cashExpenses,
  ) async {
    final countedCtrl = TextEditingController(
      text: expected.toStringAsFixed(2),
    );
    final reasonCtrl = TextEditingController();

    return Get.dialog<Map<String, dynamic>>(
      StatefulBuilder(
        builder: (context, setState) {
          final counted = double.tryParse(countedCtrl.text.trim());
          final diff = counted == null ? null : counted - expected;
          final balanced = diff != null && diff.abs() < 0.01;
          return AlertDialog(
            title: const Text(
              'جرد الدرج قبل الإقفال',
              style: TextStyle(
                fontFamily: 'cairo',
                fontWeight: FontWeight.bold,
              ),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _stockRow('رصيد الافتتاح + المقبوضات', expected + cashExpenses),
                  _stockRow('سحوبات نقدية', -cashExpenses),
                  const Divider(),
                  _stockRow('المتوقع في الدرج', expected, bold: true),
                  const SizedBox(height: 12),
                  TextField(
                    controller: countedCtrl,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: 'cairo',
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'المبلغ المعدود فعليًا',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  if (diff != null) ...[
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: (balanced ? AppColors.success : AppColors.danger)
                            .withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        balanced
                            ? 'مطابق تمامًا'
                            : diff > 0
                            ? 'زيادة ${diff.toStringAsFixed(2)} ر.س'
                            : 'عجز ${diff.abs().toStringAsFixed(2)} ر.س',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'cairo',
                          fontWeight: FontWeight.bold,
                          color: balanced
                              ? AppColors.success
                              : AppColors.danger,
                        ),
                      ),
                    ),
                  ],
                  if (diff != null && !balanced) ...[
                    const SizedBox(height: 10),
                    TextField(
                      controller: reasonCtrl,
                      decoration: const InputDecoration(
                        labelText: 'سبب الفرق (مطلوب)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Get.back<Map<String, dynamic>>(),
                child: const Text('إقفال بلا جرد'),
              ),
              ElevatedButton(
                onPressed: () {
                  if (diff == null) {
                    Get.snackbar('تنبيه', 'أدخل المبلغ المعدود أو أقفل بلا جرد');
                    return;
                  }
                  if (!balanced && reasonCtrl.text.trim().isEmpty) {
                    Get.snackbar('تنبيه', 'اذكر سبب الفرق قبل الإقفال');
                    return;
                  }
                  Get.back<Map<String, dynamic>>(
                    result: {
                      'counted': counted,
                      'reason': reasonCtrl.text.trim().isEmpty
                          ? null
                          : reasonCtrl.text.trim(),
                    },
                  );
                },
                child: const Text('إقفال مع جرد'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _stockRow(String label, double value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(
              fontFamily: 'cairo',
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
          const Spacer(),
          Text(
            value.toStringAsFixed(2),
            style: TextStyle(
              fontFamily: 'cairo',
              fontSize: bold ? 15 : 13,
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  /// جلب فواتير وردية معينة
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
