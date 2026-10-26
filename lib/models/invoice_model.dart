import 'dart:convert';

class InvoiceModel {
  final int? invoicesId;
  final int? shiftId;
  final String customerName;
  final String customerPhone;
  final double totalPrice;
  final double paidAmount;
  final String paymentMethod;
  final double remainingAmount;
  final DateTime invoiceDate;
  final List<Map<String, dynamic>> listData;
  final Map<String, dynamic> mapData;
  final double discountAmount;
  final double taxAmount;
  final String? discountCode;

  InvoiceModel({
    this.invoicesId,
    this.shiftId,
    this.customerName = '',
    this.customerPhone = '',
    this.totalPrice = 0.0,
    this.paidAmount = 0.0,
    this.paymentMethod = 'cash',
    this.remainingAmount = 0.0,
    DateTime? invoiceDate,
    this.listData = const [],
    this.mapData = const {},
    this.discountAmount = 0.0,
    this.taxAmount = 0.0,
    this.discountCode,
  }) : invoiceDate = invoiceDate ?? DateTime.now();

  factory InvoiceModel.fromMap(Map<String, dynamic> map) {
    return InvoiceModel(
      invoicesId: map['invoices_id'],
      shiftId: map['shift_id'],
      customerName: map['customer_name'] ?? '',
      customerPhone: map['customer_phone'] ?? '',
      totalPrice: (map['total_price'] ?? 0).toDouble(),
      paidAmount: (map['paid_amount'] ?? 0).toDouble(),
      paymentMethod: map['payment_method'] ?? 'cash',
      remainingAmount: (map['remaining_amount'] ?? 0).toDouble(),
      invoiceDate: DateTime.parse(map['invoice_date']),
      listData:
          map['list_data'] != null
              ? List<Map<String, dynamic>>.from(
                (map['list_data'] is String)
                    ? List<Map<String, dynamic>>.from(
                      (map['list_data'] as String).isNotEmpty
                          ? List<Map<String, dynamic>>.from(
                            (map['list_data'] as String).contains('[')
                                ? _parseJsonList(map['list_data'])
                                : [],
                          )
                          : [],
                    )
                    : map['list_data'],
              )
              : [],
      mapData:
          map['map_data'] != null
              ? Map<String, dynamic>.from(
                map['map_data'] is String
                    ? _parseJsonMap(map['map_data'])
                    : map['map_data'],
              )
              : {},
      discountAmount: (map['discount_amount'] ?? 0).toDouble(),
      taxAmount: (map['tax_amount'] ?? 0).toDouble(),
      discountCode: map['discount_code'],
    );
  }

  static dynamic _parseJsonList(String json) {
    try {
      return json.isNotEmpty
          ? List<Map<String, dynamic>>.from(
            (jsonDecode(json) as List).map((e) => Map<String, dynamic>.from(e)),
          )
          : [];
    } catch (e) {
      return [];
    }
  }

  static dynamic _parseJsonMap(String json) {
    try {
      return json.isNotEmpty ? Map<String, dynamic>.from(jsonDecode(json)) : {};
    } catch (e) {
      return {};
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'invoices_id': invoicesId,
      'shift_id': shiftId,
      'customer_name': customerName,
      'customer_phone': customerPhone,
      'total_price': totalPrice,
      'paid_amount': paidAmount,
      'payment_method': paymentMethod,
      'remaining_amount': remainingAmount,
      'invoice_date': invoiceDate.toIso8601String(),
      'list_data': jsonEncode(listData),
      'map_data': jsonEncode(mapData),
      'discount_amount': discountAmount,
      'tax_amount': taxAmount,
      'discount_code': discountCode,
    };
  }

  double get finalAmount => totalPrice - discountAmount + taxAmount;
}
