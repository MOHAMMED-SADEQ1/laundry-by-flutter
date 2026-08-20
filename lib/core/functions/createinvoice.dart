// import 'dart:typed_data';

// import 'package:get/get.dart';
// import 'package:pdf/widgets.dart' as pw;

// Future<Uint8List> generateArabicPdf(pw.Font? arbicefont) async {
//     if (arbicefont == null) {
//       Get.snackbar(
//         'خطأ',
//         'الخط العربي غير محمل بعد. يرجى المحاولة مرة أخرى.',
//         snackPosition: SnackPosition.BOTTOM,
//       );
//       return Uint8List(0); // Return empty bytes if font isn't loaded
//     }
//     final pdf = pw.Document();
//     DateTime today = DateTime.now();
//     String formattedDate =
//         "${today.year}-${today.month}-${today.day} ${today.hour}:${today.minute}:${today.second}";
//     final ByteData logobytes = await rootBundle.load(
//       'assets/images/logo-wash.jpg',
//     );
//     final Uint8List logoimage = logobytes.buffer.asUint8List();
//     final ByteData riyalbytes = await rootBundle.load(
//       'assets/images/riyal.png',
//     );
//     final Uint8List riyalimage = riyalbytes.buffer.asUint8List();

//     pdf.addPage(
//       pw.MultiPage(
//         pageFormat: PdfPageFormat.a4,
//         build: (pw.Context context) {
//           return [
//             pw.Center(
//               child: pw.Column(
//                 crossAxisAlignment:
//                     pw.CrossAxisAlignment.end, // Align to right for RTL
//                 children: [
//                   pw.Center(
//                     child: pw.Image(
//                       pw.MemoryImage(logoimage),
//                       width: 220,
//                       height: 220,
//                     ),
//                   ),
//                   pw.Center(
//                     child: pw.Text(
//                       "مغاسل النظارة لغسيل الملابس",
//                       textDirection: pw.TextDirection.rtl,
//                       style: pw.TextStyle(
//                         font: arabicFont,
//                         fontSize: 35,
//                         fontWeight: pw.FontWeight.bold,
//                       ),
//                     ),
//                   ),
//                   pw.Center(
//                     child: pw.Text(
//                       "الرياص-حي اشبيليا-طريق الصحابة \n الرقم الضريبي:1010846518 \n مغاسل النظارة \n ترحب بكم",
//                       textDirection: pw.TextDirection.rtl,
//                       textAlign: pw.TextAlign.center,
//                       style: pw.TextStyle(
//                         font: arabicFont,
//                         fontSize: 20,
//                         fontWeight: pw.FontWeight.bold,
//                       ),
//                     ),
//                   ),
//                   pw.SizedBox(height: 10),
//                   pw.Divider(),
//                   pw.SizedBox(height: 10),
//                   pw.Center(
//                     child: pw.Text(
//                       "نسعد بتواصلكم عبر الارقام:",
//                       textDirection: pw.TextDirection.rtl,
//                       style: pw.TextStyle(
//                         font: arabicFont,
//                         fontSize: 20,
//                         fontWeight: pw.FontWeight.bold,
//                       ),
//                     ),
//                   ),
//                   pw.Center(
//                     child: pw.Text(
//                       "0566677465\n-----------------\n0577893387",
//                       textDirection: pw.TextDirection.rtl,
//                       style: pw.TextStyle(
//                         font: arabicFont,
//                         fontSize: 20,
//                         fontWeight: pw.FontWeight.bold,
//                       ),
//                     ),
//                   ),
//                   pw.SizedBox(height: 10),
//                   pw.Divider(),
//                   pw.Center(
//                     child: pw.Text(
//                       "فاتورة ضريبية مبسطة",
//                       textDirection: pw.TextDirection.rtl,
//                       style: pw.TextStyle(
//                         font: arabicFont,
//                         fontSize: 20,
//                         fontWeight: pw.FontWeight.bold,
//                       ),
//                     ),
//                   ),

//                   pw.Text(
//                     " رقم الإيصال: \n التأريخ: $formattedDate \n الموظف:مغاسل النظارة \n نقطة بيع POS فاتورة إلكترونية",
//                     textDirection: pw.TextDirection.rtl,
//                     style: pw.TextStyle(
//                       font: arabicFont,
//                       fontSize: 20,
//                       fontWeight: pw.FontWeight.bold,
//                     ),
//                   ),
//                   pw.Center(
//                     child: pw.Text(
//                       "-----------------------------------------------------------------------------",
//                       textDirection: pw.TextDirection.rtl,
//                       style: pw.TextStyle(
//                         font: arabicFont,
//                         fontSize: 20,
//                         fontWeight: pw.FontWeight.bold,
//                       ),
//                     ),
//                   ),
//                   pw.Directionality(
//                     textDirection: pw.TextDirection.rtl,
//                     child: pw.ListView.builder(
//                       itemCount: controllerinvoice.invoice.length,
//                       itemBuilder: (context, index) {
//                         return pw.Container(
//                           padding: pw.EdgeInsets.symmetric(vertical: 7),
//                           child: pw.Row(
//                             mainAxisAlignment:
//                                 pw.MainAxisAlignment.spaceBetween,
//                             children: [
//                               pw.Column(
//                                 crossAxisAlignment: pw.CrossAxisAlignment.start,
//                                 children: [
//                                   pw.Text(
//                                     "${controllerinvoice.invoice[index]['vestments']} (${controllerinvoice.invoice[index]['content']})",
//                                     textDirection: pw.TextDirection.rtl,
//                                     style: pw.TextStyle(
//                                       font: arabicFont,
//                                       fontSize: 20,
//                                       fontWeight: pw.FontWeight.bold,
//                                     ),
//                                   ),
//                                   pw.Wrap(
//                                     spacing: 5,
//                                     // alignment: pw.WrapAlignment.end,
//                                     // alignment: pw.WrapAlignment.end,
//                                     children: [
//                                       pw.Text(
//                                         "${controllerinvoice.invoice[index]['price']} x ${controllerinvoice.invoice[index]['count']}",
//                                         style: pw.TextStyle(
//                                           // font: arabicFont,
//                                           fontSize: 16,
//                                           fontWeight: pw.FontWeight.bold,
//                                         ),
//                                       ),
//                                       pw.Image(
//                                         pw.MemoryImage(riyalimage),
//                                         width: 16,
//                                         height: 16,
//                                       ),
//                                     ],
//                                   ),
//                                 ],
//                               ),
//                               pw.Wrap(
//                                 spacing: 5,
//                                 children: [
//                                   pw.Text(
//                                     "${controllerinvoice.invoice[index]['total_price']}",
//                                     style: pw.TextStyle(
//                                       fontSize: 16,
//                                       fontWeight: pw.FontWeight.bold,
//                                     ),
//                                   ),

//                                   pw.Image(
//                                     pw.MemoryImage(riyalimage),
//                                     width: 16,
//                                     height: 16,
//                                   ),
//                                 ],
//                               ),
//                             ],
//                           ),
//                         );
//                       },
//                     ),
//                   ),
//                   pw.Divider(),
//                   pw.Row(
//                     mainAxisAlignment:  pw.MainAxisAlignment.spaceBetween,
//                     children: [
//                       pw.Directionality(textDirection: pw.TextDirection.rtl, child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start,children: [
//                         pw.Wrap(
//                                 spacing: 5,
//                                 children: [
//                                   pw.Text(
//                                     controllerinvoice.sumatiom.toString(),
//                                     style: pw.TextStyle(
//                                       fontSize: 16,
//                                       fontWeight: pw.FontWeight.bold,
//                                     ),
//                                   ),

//                                   pw.Image(
//                                     pw.MemoryImage(riyalimage),
//                                     width: 16,
//                                     height: 16,
//                                   ),
//                                 ],
//                               ),
//                               pw.SizedBox(height: 20),
//                               pw.Wrap(
//                                 spacing: 5,
//                                 children: [
//                                   pw.Text(
//                                     controllerinvoice.sumatiom.toString(),
//                                     style: pw.TextStyle(
//                                       fontSize: 16,
//                                     ),
//                                   ),

//                                   pw.Image(
//                                     pw.MemoryImage(riyalimage),
//                                     width: 16,
//                                     height: 16,
//                                   ),
//                                 ],
//                               ),
//                       ])),
//                     pw.Directionality(textDirection: pw.TextDirection.rtl, child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start,children: [
//                         pw.Text("المجموع قبل الضريبة",style: pw.TextStyle(fontWeight: pw.FontWeight.bold,font: arabicFont,fontSize: 20)),
//                         pw.SizedBox(height: 10),
//                         pw.Text("مغاسل النضارة , %15",style: pw.TextStyle(font: arabicFont,fontSize: 16))
//                       ]))
//                     ]
//                   ),
//                   pw.Divider(),
//                   pw.Row(
//                     mainAxisAlignment:  pw.MainAxisAlignment.spaceBetween,
//                     children: [
//                       pw.Directionality(textDirection: pw.TextDirection.rtl, child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start,children: [
//                         pw.Wrap(
//                                 spacing: 5,
//                                 children: [
//                                   pw.Text(
//                                     controllerinvoice.sumatiom.toString(),
//                                     style: pw.TextStyle(
//                                       fontSize: 16,
//                                       fontWeight: pw.FontWeight.bold,
//                                     ),
//                                   ),

//                                   pw.Image(
//                                     pw.MemoryImage(riyalimage),
//                                     width: 16,
//                                     height: 16,
//                                   ),
//                                 ],
//                               ),
//                               pw.SizedBox(height: 20),
//                               pw.Wrap(
//                                 spacing: 5,
//                                 children: [
//                                   pw.Text(
//                                     controllerinvoice.sumatiom.toString(),
//                                     style: pw.TextStyle(
//                                       fontSize: 16,
//                                     ),
//                                   ),

//                                   pw.Image(
//                                     pw.MemoryImage(riyalimage),
//                                     width: 16,
//                                     height: 16,
//                                   ),
//                                 ],
//                               ),
//                       ])),
//                     pw.Directionality(textDirection: pw.TextDirection.rtl, child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start,children: [
//                         pw.Text("المجموع شامل الضريبة",style: pw.TextStyle(fontWeight: pw.FontWeight.bold,font: arabicFont,fontSize: 20)),
//                         pw.SizedBox(height: 10),
//                         pw.Text("",style: pw.TextStyle(font: arabicFont,fontSize: 12))
//                       ]))
//                     ]
//                   ),
//                 ],
//               ),
//             ),
//           ];
//         },
//       ),
//     );
//     return pdf.save();
//   }
