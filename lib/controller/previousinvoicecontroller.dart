import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:laundry/core/services/preparePDF.dart';
import 'package:laundry/sqldb.dart';
import 'dart:math';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/foundation.dart';

class PreviousInvoiceController extends GetxController {
  final invoices = <Map<String, dynamic>>[].obs;
  final isLoading = false.obs;
  final hasMore = true.obs;
  var page = 1;
  final int limit = 12;
  final ScrollController scrollController = ScrollController();
  final isRefreshing = false.obs;
  final loadingMessage = "جاري تحميل الفواتير...".obs;
  final Random random = Random();

  @override
  void onInit() {
    super.onInit();
    scrollController.addListener(_scrollListener);
    loadInitialData();
  }

  Future<void> loadInitialData() async {
    try {
      isLoading.value = true;
      final data = await readData(page: 1);
      // debugPrint('$data');
      invoices.assignAll(data);
      hasMore.value = data.length == limit;
    } catch (e) {
      Get.snackbar(
        'خطأ',
        'فشل في تحميل الفواتير',
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> loadMoreData() async {
    if (isLoading.value || !hasMore.value) return;

    try {
      isLoading.value = true;
      loadingMessage.value = "جاري تحميل المزيد من الفواتير...";

      await Future.delayed(Duration(milliseconds: 500));

      page++;
      final newData = await readData(page: page);

      if (newData.isEmpty) {
        hasMore.value = false;
        loadingMessage.value = "تم تحميل كل الفواتير";
        return;
      }

      invoices.addAll(newData);
      hasMore.value = newData.length == limit;
    } catch (e) {
      page--;
      Get.snackbar(
        'خطأ',
        'فشل في تحميل المزيد من الفواتير',
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      isLoading.value = false;
    }
  }

  void _scrollListener() {
    if (scrollController.position.pixels >=
        scrollController.position.maxScrollExtent - 200) {
      loadMoreData();
    }
  }

  Future<List<Map<String, dynamic>>> readData({required int page}) async {
    try {
      SqlDB db = SqlDB();
      final offset = (page - 1) * limit;

      return await db.readData('''
        SELECT * FROM invoices
        ORDER BY invoices_id DESC
        LIMIT $limit OFFSET $offset
      ''');
    } catch (e) {
      debugPrint('Error reading data: $e');
      return [];
    }
  }

  Future<void> refreshData() async {
    try {
      isRefreshing.value = true;
      page = 1;
      await loadInitialData();
    } finally {
      isRefreshing.value = false;
    }
  }

  @override
  void onClose() {
    scrollController.dispose();
    super.onClose();
  }

  Future<void> printPDF(Map<String, dynamic> data) async {
    try {
      final pdfBytes = await compute(PreparePDF.generatePdfData, data);
      if (pdfBytes.isNotEmpty) {
        // Save PDF to temporary file and open it
        final tempDir = await getTemporaryDirectory();
        final fileName = 'invoice_${data['invoiceNumber']}.pdf';
        final filePath = '${tempDir.path}/$fileName';
        final file = File(filePath);
        await file.writeAsBytes(pdfBytes);

        // Open the PDF file with default application
        if (Platform.isAndroid || Platform.isIOS) {
          // For mobile platforms, use printing package
          await Printing.layoutPdf(
            onLayout: (PdfPageFormat format) => pdfBytes,
          );
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
      }
    } catch (e) {
      debugPrint('Error sharing PDF: $e');
      Get.snackbar('خطأ', '$e', snackPosition: SnackPosition.BOTTOM);
    }
  }
}
