import 'dart:convert';

class PurchaseModel {
  final int? purchaseId;
  final int? supplierId;
  final String supplierName;
  final List<Map<String, dynamic>> items;
  final double totalAmount;
  final double paidAmount;
  final DateTime date;
  final String? notes;
  final int? recordedBy;

  PurchaseModel({
    this.purchaseId,
    this.supplierId,
    this.supplierName = '',
    this.items = const [],
    this.totalAmount = 0.0,
    this.paidAmount = 0.0,
    DateTime? date,
    this.notes,
    this.recordedBy,
  }) : date = date ?? DateTime.now();

  factory PurchaseModel.fromMap(Map<String, dynamic> map) {
    return PurchaseModel(
      purchaseId: map['purchase_id'],
      supplierId: map['supplier_id'],
      supplierName: map['supplier_name'] ?? '',
      items:
          map['items'] != null
              ? List<Map<String, dynamic>>.from(
                (map['items'] is String)
                    ? List<Map<String, dynamic>>.from(
                      (map['items'] as String).isNotEmpty
                          ? List<Map<String, dynamic>>.from(
                            (map['items'] as String).contains('[')
                                ? (jsonDecode(map['items']) as List)
                                    .map((e) => Map<String, dynamic>.from(e))
                                    .toList()
                                : [],
                          )
                          : [],
                    )
                    : map['items'],
              )
              : [],
      totalAmount: (map['total_amount'] ?? 0).toDouble(),
      paidAmount: (map['paid_amount'] ?? 0).toDouble(),
      date: DateTime.parse(map['date']),
      notes: map['notes'],
      recordedBy: map['recorded_by'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'purchase_id': purchaseId,
      'supplier_id': supplierId,
      'supplier_name': supplierName,
      'items': jsonEncode(items),
      'total_amount': totalAmount,
      'paid_amount': paidAmount,
      'date': date.toIso8601String(),
      'notes': notes,
      'recorded_by': recordedBy,
    };
  }

  double get remainingAmount => totalAmount - paidAmount;
}
