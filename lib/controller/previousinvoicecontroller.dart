import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:laundry/core/services/preparePDF.dart';
import 'package:laundry/sqldb.dart';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart'; // لإضافة تأخير عشوائي

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
      // print(data);
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
        SELECT * FROM invoice
        ORDER BY invoices_id DESC
        LIMIT $limit OFFSET $offset
      ''');
    } catch (e) {
      print('Error reading data: $e');
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
      // if (pdfBytes.isNotEmpty) {
      // await Printing.sharePdf(bytes: pdfBytes, filename: "invoice12345678.pdf");
      await Printing.layoutPdf(onLayout: (PdfPageFormat format) => pdfBytes);
      // controllerinvoice.deleteInvoice();
      // }
    } catch (e) {
      print('Error sharing PDF: $e');
      Get.snackbar('خطأ', '$e', snackPosition: SnackPosition.BOTTOM);
    }
  }
}