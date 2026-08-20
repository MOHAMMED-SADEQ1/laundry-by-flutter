class ClothingModel {
  final int? clothingId;
  final String clothingName;
  final double normalWashingAndIroningPrice;
  final double urgentWashingAndIroningPrice;
  final double normalIroningPrice;
  final double urgentIroningPrice;
  final int categoryId;
  final bool isActive;

  ClothingModel({
    this.clothingId,
    required this.clothingName,
    this.normalWashingAndIroningPrice = 0.0,
    this.urgentWashingAndIroningPrice = 0.0,
    this.normalIroningPrice = 0.0,
    this.urgentIroningPrice = 0.0,
    this.categoryId = 0,
    this.isActive = true,
  });

  factory ClothingModel.fromMap(Map<String, dynamic> map) {
    return ClothingModel(
      clothingId: map['clothing_id'],
      clothingName: map['clothing_name'] ?? '',
      normalWashingAndIroningPrice:
          (map['normal_washing_and_ironing_price'] ?? 0).toDouble(),
      urgentWashingAndIroningPrice:
          (map['urgent_washing_and_ironing_price'] ?? 0).toDouble(),
      normalIroningPrice: (map['normal_ironing_price'] ?? 0).toDouble(),
      urgentIroningPrice: (map['urgent_ironing_price'] ?? 0).toDouble(),
      categoryId: map['category_id'] ?? 0,
      isActive: map['is_active'] == null ? true : map['is_active'] == 1,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'clothing_id': clothingId,
      'clothing_name': clothingName,
      'normal_washing_and_ironing_price': normalWashingAndIroningPrice,
      'urgent_washing_and_ironing_price': urgentWashingAndIroningPrice,
      'normal_ironing_price': normalIroningPrice,
      'urgent_ironing_price': urgentIroningPrice,
      'category_id': categoryId,
      'is_active': isActive ? 1 : 0,
    };
  }

  double getPrice(String serviceType) {
    switch (serviceType) {
      case 'normalwashingironing':
        return normalWashingAndIroningPrice;
      case 'urgentwashingironing':
        return urgentWashingAndIroningPrice;
      case 'normalironing':
        return normalIroningPrice;
      case 'urgentironing':
        return urgentIroningPrice;
      default:
        return normalWashingAndIroningPrice;
    }
  }

  String getServiceName(String serviceType) {
    switch (serviceType) {
      case 'normalwashingironing':
        return 'غسيل وكوي عادي';
      case 'urgentwashingironing':
        return 'غسيل وكوي مستعجل';
      case 'normalironing':
        return 'كوي عادي';
      case 'urgentironing':
        return 'كوي مستعجل';
      default:
        return 'غسيل وكوي عادي';
    }
  }
}
