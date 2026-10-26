import 'package:laundry/services/i18n/l10n.dart';

class DiscountModel {
  final int? discountId;
  final String name;
  final String nameEn;
  final String type; // 'percentage' or 'fixed'
  final double value;
  final DateTime startDate;
  final DateTime? endDate;
  final bool isActive;
  final int? maxUses;
  final int currentUses;
  final String? code;

  DiscountModel({
    this.discountId,
    required this.name,
    this.nameEn = '',
    required this.type,
    required this.value,
    DateTime? startDate,
    this.endDate,
    this.isActive = true,
    this.maxUses,
    this.currentUses = 0,
    this.code,
  }) : startDate = startDate ?? DateTime.now();

  factory DiscountModel.fromMap(Map<String, dynamic> map) {
    return DiscountModel(
      discountId: map['discount_id'],
      name: map['name'] ?? '',
      nameEn: map['name_en'] ?? '',
      type: map['type'] ?? 'percentage',
      value: (map['value'] ?? 0).toDouble(),
      startDate: DateTime.parse(map['start_date']),
      endDate: map['end_date'] != null ? DateTime.parse(map['end_date']) : null,
      isActive: map['is_active'] == null ? true : map['is_active'] == 1,
      maxUses: map['max_uses'],
      currentUses: map['current_uses'] ?? 0,
      code: map['code'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'discount_id': discountId,
      'name': name,
      'name_en': nameEn.trim().isEmpty ? null : nameEn.trim(),
      'type': type,
      'value': value,
      'start_date': startDate.toIso8601String(),
      'end_date': endDate?.toIso8601String(),
      'is_active': isActive ? 1 : 0,
      'max_uses': maxUses,
      'current_uses': currentUses,
      'code': code,
    };
  }

  String get displayName => L10n.pick(name, nameEn);

  bool get isExpired => endDate != null && DateTime.now().isAfter(endDate!);
  bool get isMaxedOut => maxUses != null && currentUses >= maxUses!;
  bool get isValid => isActive && !isExpired && !isMaxedOut;

  double calculateDiscount(double amount) {
    if (type == 'percentage') {
      return amount * (value / 100);
    } else {
      return value;
    }
  }
}
