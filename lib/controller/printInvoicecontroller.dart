// ignore_for_file: file_names

import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:get/get.dart';
import 'package:laundry/controller/shift_controller.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:laundry/controller/invoicecontroller.dart';
import 'package:laundry/core/services/preparePDF.dart';
import 'package:laundry/sqldb.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/foundation.dart';

class PrintInvoiceController extends GetxController {
  static Uint8List? logoImageBytes;
  static Uint8List? riyalImageBytes;
  static pw.Font? arabicFont;
  final SqlDB db = SqlDB();

  static Future<void> initializeAssets() async {
    try {
      await Future.wait([
        _loadPdfAssets(),
        _loadArabicFont(),
        initializeDateFormatting('ar', null),
      ]);
    } catch (e) {
      debugPrint('Error initializing PDF assets: $e');
    }
  }

  static Future<void> _loadPdfAssets() async {
    if (logoImageBytes == null) {
      final ByteData logobytes = await rootBundle.load(
        'assets/images/logo-wash.png',
      );
      logoImageBytes = logobytes.buffer.asUint8List();
    }
    if (riyalImageBytes == null) {
      final ByteData riyalbytes = await rootBundle.load(
        'assets/images/saudi_riyal.png',
      );
      riyalImageBytes = riyalbytes.buffer.asUint8List();
    }
  }

  static Future<void> _loadArabicFont() async {
    if (arabicFont == null) {
      final fontData = await rootBundle.load(
        "assets/fonts/Noto/AL-Mohanad.ttf",
      );
      arabicFont = pw.Font.ttf(fontData);
    }
  }

  final InvoiceController invcontroller = Get.find<InvoiceController>();

  // تعديل الدالة لاستقبال البارامتر الجديد
  Future<Uint8List> generateArabicPdf(
    String payment,
    int invoiceNumber, {
    String pickupCode = '',
  }) async {
    if (arabicFont == null ||
        logoImageBytes == null ||
        riyalImageBytes == null) {
      await initializeAssets();
    }
    await initializeDateFormatting('ar', null);
    final today = DateTime.now();
    // "${today.year}-${today.month}-${today.day}  ${today.hour}:${today.minute}";
    String formattedTime = DateFormat('hh:mm:ss a', 'ar').format(today);
    Map<String, dynamic> data = {
      'payment': payment,
      'logoImage': logoImageBytes!,
      'riyalImage': riyalImageBytes!,
      'arabicFont': arabicFont!,
      'invoiceItems': List.from(invcontroller.invoice),
      'summation': invcontroller.summation.value,
      'invoiceNumber': invoiceNumber, // إضافة رقم الفاتورة إلى البيانات
      'customername': invcontroller.customername.text,
      'pickupCode': pickupCode,
      'date': "${today.year}-${today.month}-${today.day}  $formattedTime",
    };

    return await compute(PreparePDF.generatePdfData, data);
  }

  // تعديل دالة المشاركة لاستقبال البارامتر الجديد
  Future<void> printPDF(
    String payment,
    int invoiceNumber, {
    double paid = -1,
    String? customerName,
    int? customerId,
    String? customerPhone,
  }) async {
    final ShiftController shiftController = Get.find<ShiftController>();

    final summation = invcontroller.summation.value;
    final name =
        (customerName ?? invcontroller.customername.text.trim()).trim();

    // جلب رقم هاتف العميل من السجل إن أمكن
    var phone = (customerPhone ?? '').trim();
    if ((customerId != null || phone.isEmpty) &&
        name.isNotEmpty &&
        customerId != null) {
      try {
        final rows = await db.safeRead(
          'customers',
          where: 'customer_id = ?',
          whereArgs: [customerId],
        );
        if (rows.isNotEmpty) {
          final p = rows.first['phone_1']?.toString() ?? '';
          if (p.isNotEmpty) phone = p;
        }
      } catch (_) {}
    }

    final invoiceDate = DateTime.now().toIso8601String();
    final listData = jsonEncode(invcontroller.invoice);
    final paidAmount = paid >= 0 ? paid : summation;
    final remainingAmount =
        (summation - paidAmount) > 0 ? summation - paidAmount : 0.0;
    // رمز استلام فريد 4 أرقام — متطابق لكل فاتورة دون تكرار للفواتير المتتالية
    final pickupCode = ((invoiceNumber * 7 + 3) % 10000).toString().padLeft(
      4,
      '0',
    );
    // إنشاء map_data وحفظه
    final mapData = jsonEncode({
      'payment': payment,
      'summation': summation,
      'customername': name,
      'date': DateFormat('yyyy-MM-dd hh:mm:ss a', 'ar').format(DateTime.now()),
    });

    try {
      // حفظ الفاتورة في قاعدة البيانات — إدراج آمن (parameterized)
      final saved = await db.safeInsert('invoices', {
        'invoices_id': invoiceNumber,
        'shift_id': shiftController.activeShiftId.value,
        'customer_name': name,
        'customer_phone': phone,
        'customer_id': customerId,
        'total_price': summation,
        'final_amount': summation,
        'paid_amount': paidAmount,
        'payment_method': payment,
        'remaining_amount': remainingAmount,
        'invoice_date': invoiceDate,
        'list_data': listData,
        'map_data': mapData,
        'pickup_code': pickupCode,
      });

      if (saved <= 0) {
        throw Exception('فشل حفظ الفاتورة في قاعدة البيانات');
      }

      Get.snackbar(
        'نجاح',
        'تم حفظ الفاتورة رقم #$invoiceNumber وإصدارها',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: const Color(0xFF16A34A),
        colorText: Colors.white,
        duration: const Duration(seconds: 2),
        icon: const Icon(Icons.check_circle, color: Colors.white),
      );
    } catch (e) {
      debugPrint('Error saving invoice: $e');
      Get.snackbar(
        'خطأ',
        'تعذر حفظ الفاتورة: $e',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: const Color(0xFFDC2626),
        colorText: Colors.white,
      );
      return;
    }

    try {
      final pdfBytes = await generateArabicPdf(
        payment,
        invoiceNumber,
        pickupCode: pickupCode,
      );

      // Save PDF to temporary file and open it
      final tempDir = await getTemporaryDirectory();
      final fileName = 'invoice_$invoiceNumber.pdf';
      final filePath = '${tempDir.path}/$fileName';
      final file = File(filePath);
      await file.writeAsBytes(pdfBytes);

      // Open the PDF file with default application
      if (Platform.isAndroid || Platform.isIOS) {
        // For mobile platforms, use printing package
        await Printing.layoutPdf(onLayout: (PdfPageFormat format) => pdfBytes);
      } else {
        // For desktop platforms, save and open file
        final uri = Uri.file(filePath);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri);
        } else {
          Get.snackbar(
            'خطأ',
            'لا يمكن فتح ملف PDF',
            snackPosition: SnackPosition.BOTTOM,
          );
        }
      }

      invcontroller.deleteInvoice();
    } catch (e) {
      debugPrint('Error sharing PDF: $e');
      Get.snackbar('خطأ', '$e', snackPosition: SnackPosition.BOTTOM);
    }
  }
}
