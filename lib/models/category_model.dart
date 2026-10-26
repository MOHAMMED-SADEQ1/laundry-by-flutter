import 'package:laundry/services/i18n/l10n.dart';

class CategoryModel {
  final int? catId;
  final String name;
  final String nameEn;
  final String description;
  final String descriptionEn;
  final bool isActive;

  CategoryModel({
    this.catId,
    required this.name,
    this.nameEn = '',
    this.description = '',
    this.descriptionEn = '',
    this.isActive = true,
  });

  factory CategoryModel.fromMap(Map<String, dynamic> map) {
    return CategoryModel(
      catId: map['cat_id'],
      name: map['name'] ?? '',
      nameEn: map['name_en'] ?? '',
      description: map['description'] ?? '',
      descriptionEn: map['description_en'] ?? '',
      isActive: map['is_active'] == null ? true : map['is_active'] == 1,
    );
  }

  String get displayName => L10n.pick(name, nameEn);

  String get displayDescription => L10n.pick(description, descriptionEn);

  Map<String, dynamic> toMap() {
    return {
      'cat_id': catId,
      'name': name,
      'name_en': nameEn.trim().isEmpty ? null : nameEn.trim(),
      'description': description,
      'description_en':
          descriptionEn.trim().isEmpty ? null : descriptionEn.trim(),
      'is_active': isActive ? 1 : 0,
    };
  }
}
