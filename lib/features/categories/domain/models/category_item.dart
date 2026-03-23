import 'package:flutter/material.dart';

enum CategoryType { expense, income }

class CategoryItem {
  const CategoryItem({
    required this.id,
    required this.name,
    required this.description,
    required this.type,
    required this.icon,
  });

  final String id;
  final String name;
  final String description;
  final CategoryType type;
  final IconData icon;

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'type': type.name,
      'icon': _serializeIcon(icon),
    };
  }

  factory CategoryItem.fromMap(Map<dynamic, dynamic> map) {
    return CategoryItem(
      id: map['id'] as String? ?? '',
      name: map['name'] as String? ?? '',
      description: map['description'] as String? ?? '',
      type: CategoryType.values.byName(map['type'] as String? ?? 'expense'),
      icon: _deserializeIcon(map['icon'] as Map<dynamic, dynamic>?),
    );
  }

  static Map<String, Object?> _serializeIcon(IconData icon) {
    return {
      'codePoint': icon.codePoint,
      'fontFamily': icon.fontFamily,
      'fontPackage': icon.fontPackage,
      'matchTextDirection': icon.matchTextDirection,
    };
  }

  static IconData _deserializeIcon(Map<dynamic, dynamic>? map) {
    if (map == null) {
      return Icons.sell_outlined;
    }

    return IconData(
      map['codePoint'] as int? ?? Icons.sell_outlined.codePoint,
      fontFamily: map['fontFamily'] as String?,
      fontPackage: map['fontPackage'] as String?,
      matchTextDirection: map['matchTextDirection'] as bool? ?? false,
    );
  }
}
