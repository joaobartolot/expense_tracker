import 'package:expense_tracker/features/categories/domain/models/category_item.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

abstract class CategoryRepository {
  Future<List<CategoryItem>> getCategories();
  ValueListenable<Box<dynamic>> listenable();
  Future<void> addCategory(CategoryItem category);
  Future<void> updateCategory(CategoryItem category);
  Future<void> deleteCategory(String categoryId);
}
