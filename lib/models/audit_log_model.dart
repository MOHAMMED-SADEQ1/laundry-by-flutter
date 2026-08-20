class AuditLogModel {
  final int? logId;
  final int? userId;
  final String action;
  final String tableName;
  final int? recordId;
  final String? oldValues;
  final String? newValues;
  final DateTime timestamp;

  AuditLogModel({
    this.logId,
    this.userId,
    required this.action,
    required this.tableName,
    this.recordId,
    this.oldValues,
    this.newValues,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  factory AuditLogModel.fromMap(Map<String, dynamic> map) {
    return AuditLogModel(
      logId: map['log_id'],
      userId: map['user_id'],
      action: map['action'] ?? '',
      tableName: map['table_name'] ?? '',
      recordId: map['record_id'],
      oldValues: map['old_values'],
      newValues: map['new_values'],
      timestamp: DateTime.parse(map['timestamp']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'log_id': logId,
      'user_id': userId,
      'action': action,
      'table_name': tableName,
      'record_id': recordId,
      'old_values': oldValues,
      'new_values': newValues,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}
