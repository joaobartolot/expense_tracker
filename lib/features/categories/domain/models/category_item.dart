import 'package:flutter/material.dart';

enum CategoryType { expense, income }

class CategoryItem {
  const CategoryItem({
    required this.name,
    required this.description,
    required this.type,
    required this.icon,
  });

  final String name;
  final String description;
  final CategoryType type;
  final IconData icon;
}
