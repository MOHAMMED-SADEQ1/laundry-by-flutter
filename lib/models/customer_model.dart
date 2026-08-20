class CustomerModel {
  final int? customerId;
  final String customerName;
  final String phone1;
  final String phone2;
  final String email;
  final String address;
  final int loyaltyPoints;
  final double totalSpent;
  final String tier;
  final DateTime joinDate;
  final bool isActive;
  final String notes;

  CustomerModel({
    this.customerId,
    required this.customerName,
    this.phone1 = '',
    this.phone2 = '',
    this.email = '',
    this.address = '',
    this.loyaltyPoints = 0,
    this.totalSpent = 0.0,
    this.tier = 'bronze',
    DateTime? joinDate,
    this.isActive = true,
    this.notes = '',
  }) : joinDate = joinDate ?? DateTime.now();

  factory CustomerModel.fromMap(Map<String, dynamic> map) {
    return CustomerModel(
      customerId: map['customer_id'],
      customerName: map['customer_name'] ?? '',
      phone1: map['phone_1'] ?? '',
      phone2: map['phone_2'] ?? '',
      email: map['email'] ?? '',
      address: map['address'] ?? '',
      loyaltyPoints: map['loyalty_points'] ?? 0,
      totalSpent: (map['total_spent'] ?? 0).toDouble(),
      tier: map['tier'] ?? 'bronze',
      joinDate: DateTime.parse(
        map['join_date'] ?? DateTime.now().toIso8601String(),
      ),
      isActive: map['is_active'] == null ? true : map['is_active'] == 1,
      notes: map['notes'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'customer_id': customerId,
      'customer_name': customerName,
      'phone_1': phone1,
      'phone_2': phone2,
      'email': email,
      'address': address,
      'loyalty_points': loyaltyPoints,
      'total_spent': totalSpent,
      'tier': tier,
      'join_date': joinDate.toIso8601String(),
      'is_active': isActive ? 1 : 0,
      'notes': notes,
    };
  }

  String get tierArabic {
    switch (tier) {
      case 'gold':
        return 'ذهبي';
      case 'silver':
        return 'فضي';
      case 'bronze':
      default:
        return 'برونزي';
    }
  }
}
