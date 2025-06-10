import 'dart:typed_data';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';


class PreparePDF {
  static Future<Uint8List> generatePdfData(Map<String, dynamic> data) async {
    final pdf = pw.Document();

    final riyalIcon = pw.Image(
      pw.MemoryImage(data['riyalImage']),
      width: 16,
      height: 16,
    );

    final itemStyle = pw.TextStyle(
      font: data['arabicFont'],
      fontSize: 22,
      fontWeight: pw.FontWeight.bold,
    );

    final priceStyle = pw.TextStyle(
      fontSize: 16,
      fontWeight: pw.FontWeight.bold,
    );

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
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
                      "فاتورة مبسطة",
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

                  pw.Center(
                    child: pw.Text(
                      "-----------------------------------------------------------------",
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
                                  style: const pw.TextStyle(fontSize: 16),
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
}