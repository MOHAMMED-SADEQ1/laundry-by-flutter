class ShiftModel {
  final int? shiftId;
  final DateTime startTime;
  final DateTime? endTime;
  final double totalCash;
  final double totalNetwork;
  final int invoiceCount;
  final int? openedBy;

  ShiftModel({
    this.shiftId,
    DateTime? startTime,
    this.endTime,
    this.totalCash = 0.0,
    this.totalNetwork = 0.0,
    this.invoiceCount = 0,
    this.openedBy,
  }) : startTime = startTime ?? DateTime.now();

  factory ShiftModel.fromMap(Map<String, dynamic> map) {
    return ShiftModel(
      shiftId: map['shift_id'],
      startTime: DateTime.parse(map['start_time']),
      endTime: map['end_time'] != null ? DateTime.parse(map['end_time']) : null,
      totalCash: (map['total_cash'] ?? 0).toDouble(),
      totalNetwork: (map['total_network'] ?? 0).toDouble(),
      invoiceCount: map['invoice_count'] ?? 0,
      openedBy: map['opened_by'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'shift_id': shiftId,
      'start_time': startTime.toIso8601String(),
      'end_time': endTime?.toIso8601String(),
      'total_cash': totalCash,
      'total_network': totalNetwork,
      'invoice_count': invoiceCount,
      'opened_by': openedBy,
    };
  }

  double get totalRevenue => totalCash + totalNetwork;
  Duration? get duration => endTime?.difference(startTime);
}
