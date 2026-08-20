class SupplierModel {
  final int? supplierId;
  final String name;
  final String phone;
  final String address;
  final String email;
  final String notes;
  final bool isActive;

  SupplierModel({
    this.supplierId,
    required this.name,
    this.phone = '',
    this.address = '',
    this.email = '',
    this.notes = '',
    this.isActive = true,
  });

  factory SupplierModel.fromMap(Map<String, dynamic> map) {
    return SupplierModel(
      supplierId: map['supplier_id'],
      name: map['name'] ?? '',
      phone: map['phone'] ?? '',
      address: map['address'] ?? '',
      email: map['email'] ?? '',
      notes: map['notes'] ?? '',
      isActive: map['is_active'] == null ? true : map['is_active'] == 1,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'supplier_id': supplierId,
      'name': name,
      'phone': phone,
      'address': address,
      'email': email,
      'notes': notes,
      'is_active': isActive ? 1 : 0,
    };
  }
}
