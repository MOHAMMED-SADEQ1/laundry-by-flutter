class CategoryModel {
  final int? catId;
  final String name;
  final String description;
  final bool isActive;

  CategoryModel({
    this.catId,
    required this.name,
    this.description = '',
    this.isActive = true,
  });

  factory CategoryModel.fromMap(Map<String, dynamic> map) {
    return CategoryModel(
      catId: map['cat_id'],
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      isActive: map['is_active'] == null ? true : map['is_active'] == 1,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'cat_id': catId,
      'name': name,
      'description': description,
      'is_active': isActive ? 1 : 0,
    };
  }
}
