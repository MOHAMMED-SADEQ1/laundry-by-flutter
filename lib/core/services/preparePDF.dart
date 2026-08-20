// ignore_for_file: file_names

import 'dart:io';
import 'package:flutter/services.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:intl/intl.dart';
import 'package:barcode/barcode.dart' as barcode;

class PreparePDF {
  static Future<Uint8List> generatePdfData(Map<String, dynamic> data) async {
    final pdf = pw.Document();

    // ─── تحميل صور البقع مسبقاً (غير متزامن داخل باني PDF) ───
    final items = data['invoiceItems'] as List;
    final photoBytes = <Uint8List?>[];
    for (final item in items) {
      Uint8List? bytes;
      final path = item['photo']?.toString() ?? '';
      if (path.isNotEmpty) {
        try {
          final f = File(path);
          if (await f.exists()) bytes = await f.readAsBytes();
        } catch (_) {
          bytes = null;
        }
      }
      photoBytes.add(bytes);
    }
    data['_photoBytes'] = photoBytes;

    final riyalIcon = pw.Image(
      pw.MemoryImage(data['riyalImage']),
      width: 18,
      height: 18,
    );

    final itemStyle = pw.TextStyle(
      font: data['arabicFont'],
      fontSize: 27,
      fontWeight: pw.FontWeight.bold,
    );

    final priceStyle = pw.TextStyle(
      fontSize: 24,
      font: data['arabicFont'],
      fontWeight: pw.FontWeight.bold,
    );

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        theme: pw.ThemeData.withFont(base: data['arabicFont']),
        build: (pw.Context context) {
          return [
            pw.Center(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Center(
                    child: pw.Image(
                      pw.MemoryImage(data['logoImage']),
                      width: 200,
                      height: 200,
                    ),
                  ),
                  pw.Center(
                    child: pw.Text(
                      "\nالرياص-حي اشبيليا-طريق الصحابة \n مغاسل النظارة \n ترحب بكم",
                      textDirection: pw.TextDirection.rtl,
                      textAlign: pw.TextAlign.center,
                      style: itemStyle,
                    ),
                  ),
                  pw.SizedBox(height: 10),
                  pw.Divider(),
                  pw.SizedBox(height: 10),
                  pw.Center(
                    child: pw.Text(
                      "نسعد بتواصلكم عبر الرقام:  0577893387",
                      textDirection: pw.TextDirection.rtl,
                      style: itemStyle,
                    ),
                  ),
                  pw.SizedBox(height: 10),
                  pw.Divider(),
                  pw.Center(
                    child: pw.Text(
                      "فاتورة ضريبية مبسطة",
                      textDirection: pw.TextDirection.rtl,
                      style: itemStyle,
                    ),
                  ),
                  // استخدام invoiceNumber هنا في تفاصيل الفاتورة
                  pw.Text(
                    " رقم الإيصال: ${data['invoiceNumber']}-1 \n التأريخ: ${data['date']} \n الموظف:مغاسل النظارة \n نقطة بيع POS فاتورة إلكترونية",
                    textDirection: pw.TextDirection.rtl,
                    style: itemStyle,
                  ),
                  data['customername'] == ""
                      ? pw.SizedBox()
                      : pw.Text(
                        "اسم العميل: ${data['customername']}",
                        textDirection: pw.TextDirection.rtl,
                        style: itemStyle,
                      ),
                  if (data['pickupCode'] != null &&
                      '${data['pickupCode']}'.isNotEmpty) ...[
                    pw.SizedBox(height: 12),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.center,
                      children: [
                        pw.Container(
                          padding: const pw.EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          decoration: pw.BoxDecoration(
                            border: pw.Border.all(
                              color: PdfColor.fromInt(0xFF2563EB),
                              width: 2,
                            ),
                            borderRadius: pw.BorderRadius.circular(10),
                          ),
                          child: pw.Column(
                            children: [
                              pw.Text(
                                "رمز استلام الغسيل",
                                textDirection: pw.TextDirection.rtl,
                                style: pw.TextStyle(
                                  fontSize: 22,
                                  font: data['arabicFont'],
                                  fontWeight: pw.FontWeight.bold,
                                  color: PdfColor.fromInt(0xFF2563EB),
                                ),
                              ),
                              pw.SizedBox(height: 4),
                              pw.Text(
                                "✂  ${data['pickupCode']}",
                                textDirection: pw.TextDirection.rtl,
                                style: pw.TextStyle(
                                  fontSize: 44,
                                  letterSpacing: 10,
                                  font: data['arabicFont'],
                                  fontWeight: pw.FontWeight.bold,
                                  color: PdfColor.fromInt(0xFF1E293B),
                                ),
                              ),
                            ],
                          ),
                        ),
                        pw.SizedBox(width: 14),
                        pw.Container(
                          padding: const pw.EdgeInsets.all(8),
                          decoration: pw.BoxDecoration(
                            border: pw.Border.all(
                              color: PdfColor.fromInt(0xFF94A3B8),
                              width: 1.5,
                            ),
                            borderRadius: pw.BorderRadius.circular(10),
                          ),
                          child: pw.BarcodeWidget(
                            barcode: barcode.Barcode.qrCode(),
                            data: 'MAGASIL ${data['pickupCode']}',
                            width: 120,
                            height: 120,
                          ),
                        ),
                      ],
                    ),
                  ],

                  pw.Center(
                    child: pw.Text(
                      "-----------------------------------------------------",
                      textDirection: pw.TextDirection.rtl,
                      style: itemStyle,
                    ),
                  ),
                  pw.Directionality(
                    textDirection: pw.TextDirection.rtl,
                    child: pw.ListView.builder(
                      itemCount: data['invoiceItems'].length,
                      itemBuilder: (context, index) {
                        final item = data['invoiceItems'][index];
                        return pw.Container(
                          padding: const pw.EdgeInsets.symmetric(vertical: 7),
                          child: pw.Row(
                            mainAxisAlignment:
                                pw.MainAxisAlignment.spaceBetween,
                            children: [
                              pw.Column(
                                crossAxisAlignment: pw.CrossAxisAlignment.start,
                                children: [
                                  pw.Text(
                                    "${item['vestments']} (${item['content']})",
                                    textDirection: pw.TextDirection.rtl,
                                    style: itemStyle,
                                  ),
                                  pw.Text(
                                    "${item['price']} x ${item['count']}",
                                    style: priceStyle,
                                  ),
                                  if (item['note'] != null &&
                                      '${item['note']}'.trim().isNotEmpty)
                                    pw.Text(
                                      "ملاحظة: ${item['note']}",
                                      textDirection: pw.TextDirection.rtl,
                                      style: pw.TextStyle(
                                        fontSize: 8,
                                        color: PdfColor.fromInt(0xFFB45309),
                                        font: data['arabicFont'],
                                        fontWeight: pw.FontWeight.bold,
                                      ),
                                    ),
                                  if (item['photo'] != null &&
                                      '${item['photo']}'.trim().isNotEmpty &&
                                      data['_photoBytes'] is List &&
                                      index <
                                          (data['_photoBytes'] as List)
                                              .length &&
                                      (data['_photoBytes'] as List)[index] !=
                                          null)
                                    pw.Container(
                                      margin: const pw.EdgeInsets.only(top: 4),
                                      child: pw.Image(
                                        pw.MemoryImage(
                                          (data['_photoBytes'] as List)[index]
                                              as Uint8List,
                                        ),
                                        width: 96,
                                        height: 96,
                                        fit: pw.BoxFit.cover,
                                      ),
                                    ),
                                ],
                              ),

                              pw.Padding(
                                padding: pw.EdgeInsets.only(left: 20),
                                child: pw.Text(
                                  "${item['total_price']}0",
                                  style: priceStyle,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  pw.Divider(),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Directionality(
                        textDirection: pw.TextDirection.rtl,
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Wrap(
                              spacing: 5,
                              children: [
                                pw.Text(
                                  "${data['summation']}0",
                                  style: priceStyle,
                                ),
                                riyalIcon,
                                pw.SizedBox(width: 20),
                              ],
                            ),
                            pw.SizedBox(height: 15),
                            pw.Wrap(
                              spacing: 5,
                              children: [
                                pw.Text(
                                  "${data['summation']}0",
                                  style: pw.TextStyle(
                                    fontSize: 16,
                                    font: data['arabicFont'],
                                  ),
                                ),
                                riyalIcon,
                                pw.SizedBox(width: 15),
                              ],
                            ),
                          ],
                        ),
                      ),
                      pw.Directionality(
                        textDirection: pw.TextDirection.rtl,
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text("المجموع شامل الضريبة", style: itemStyle),
                            pw.SizedBox(height: 10),
                            pw.Text(
                              data['payment'],
                              style: pw.TextStyle(
                                font: data['arabicFont'],
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ];
        },
      ),
    );

    return pdf.save();
  }

  static Future<Uint8List> generateShiftSummaryPdf(
    Map<String, dynamic> shiftData,
  ) async {
    final pdf = pw.Document();
    final font = pw.Font.ttf(
      await rootBundle.load("assets/fonts/Noto/AL-Mohanad.ttf"),
    );

    final String startTime = DateFormat(
      'yyyy-MM-dd hh:mm a',
    ).format(DateTime.parse(shiftData['start_time']));
    final String endTime = DateFormat(
      'yyyy-MM-dd hh:mm a',
    ).format(DateTime.parse(shiftData['end_time']));

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a6,
        theme: pw.ThemeData.withFont(base: font, bold: font),
        build: (pw.Context context) {
          return pw.Directionality(
            textDirection: pw.TextDirection.rtl,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Center(
                  child: pw.Text(
                    'ملخص الوردية',
                    style: pw.TextStyle(font: font, fontSize: 20),
                  ),
                ),
                pw.SizedBox(height: 20),
                _buildRow(
                  'رقم الوردية:',
                  shiftData['shift_id'].toString(),
                  font,
                ),
                pw.Divider(),
                _buildRow('وقت البدء:', startTime, font),
                _buildRow('وقت الإنتهاء:', endTime, font),
                pw.Divider(),
                _buildRow(
                  'عدد الفواتير:',
                  shiftData['invoice_count'].toString(),
                  font,
                ),
                _buildRow(
                  'مجموع الكاش:',
                  '${(shiftData['total_cash'] ?? 0.0).toStringAsFixed(2)} ريال',
                  font,
                ),
                _buildRow(
                  'مجموع الشبكة:',
                  '${(shiftData['total_network'] ?? 0.0).toStringAsFixed(2)} ريال',
                  font,
                ),
                pw.SizedBox(height: 40),
                pw.Center(
                  child: pw.Text(
                    '--- شكراً لكم ---',
                    style: pw.TextStyle(font: font),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
    return pdf.save();
  }

  static pw.Widget _buildRow(String title, String value, pw.Font font) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(title, style: pw.TextStyle(font: font)),
          pw.Text(value, style: pw.TextStyle(font: font)),
        ],
      ),
    );
  }
}
