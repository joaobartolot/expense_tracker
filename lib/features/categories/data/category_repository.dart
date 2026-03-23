import 'package:expense_tracker/features/categories/domain/models/category_item.dart';

abstract class CategoryRepository {
  Future<List<CategoryItem>> getCategories();
  Future<void> addCategory(CategoryItem category);
  Future<void> updateCategory(CategoryItem category);
  Future<void> deleteCategory(String categoryId);
}
