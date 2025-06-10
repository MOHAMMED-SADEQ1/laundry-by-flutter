import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:get/get.dart';
import 'package:laundry/controller/invoicecontroller.dart';
import 'package:laundry/core/services/preparePDF.dart';
import 'package:laundry/sqldb.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:flutter/foundation.dart';

class PrintInvoiceController extends GetxController {
  static Uint8List? logoImageBytes;
  static Uint8List? riyalImageBytes;
  static pw.Font? arabicFont;
  SqlDB db = SqlDB();

  static Future<void> initializeAssets() async {
    try {
      await Future.wait([_loadPdfAssets(), _loadArabicFont()]);
    } catch (e) {
      print('Error initializing PDF assets: $e');
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

  final InvoiceController controllerinvoice = Get.put(InvoiceController());

  // تعديل الدالة لاستقبال البارامتر الجديد
  Future<Uint8List> generateArabicPdf(String payment, int invoiceNumber) async {
    if (arabicFont == null ||
        logoImageBytes == null ||
        riyalImageBytes == null) {
      await initializeAssets();
    }
    final today = DateTime.now();

    Map<String, dynamic> data = {
      'payment': payment,
      'logoImage': logoImageBytes!,
      'riyalImage': riyalImageBytes!,
      'arabicFont': arabicFont!,
      'invoiceItems': List.from(controllerinvoice.invoice),
      'summation': controllerinvoice.sumatiom,
      'invoiceNumber': invoiceNumber, // إضافة رقم الفاتورة إلى البيانات
      'customername': controllerinvoice.custmername.text,
      'date':
          "${today.year}-${today.month}-${today.day}  ${today.hour}:${today.minute}",
    };
    String datamaptstr = jsonEncode({
      'payment': payment,
      'summation': controllerinvoice.sumatiom,
      'customername': controllerinvoice.custmername.text,
      'date': "${today.year}-${today.month}-${today.day}  ${today.hour}:${today.minute}",
    });
    String dataliststr = jsonEncode(controllerinvoice.invoice);
     db.insertData("INSERT INTO 'invoice' (invoices_id,list_data, map_data) VALUES ($invoiceNumber,'$dataliststr','$datamaptstr')");

    datamaptstr = '';
    dataliststr = '';

    return await compute(PreparePDF.generatePdfData, data);
  }

  // تعديل دالة المشاركة لاستقبال البارامتر الجديد
  Future<void> printPDF(String payment, int invoiceNumber) async {
    try {
      final pdfBytes = await generateArabicPdf(payment, invoiceNumber);
      // if (pdfBytes.isNotEmpty) {
        // await Printing.sharePdf(
        //   bytes: pdfBytes,
        //   filename: "invoice_$invoiceNumber.pdf",
        // );
        await Printing.layoutPdf(onLayout: (PdfPageFormat format) => pdfBytes);
        controllerinvoice.deleteInvoice();
      // }
    } catch (e) {
      print('Error sharing PDF: $e');
      Get.snackbar('خطأ', '$e', snackPosition: SnackPosition.BOTTOM);
    }
  }
}
