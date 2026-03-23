import 'package:expense_tracker/features/categories/data/category_repository.dart';
import 'package:expense_tracker/features/categories/domain/models/category_item.dart';
import 'package:flutter/material.dart';

class InMemoryCategoryRepository implements CategoryRepository {
  InMemoryCategoryRepository({List<CategoryItem>? initialCategories})
    : _categories = initialCategories ?? _buildInitialCategories();

  final List<CategoryItem> _categories;

  @override
  Future<List<CategoryItem>> getCategories() async {
    return List.unmodifiable(_categories);
  }

  @override
  Future<void> addCategory(CategoryItem category) async {
    _categories.insert(0, category);
  }

  static List<CategoryItem> _buildInitialCategories() {
    return const [
      CategoryItem(
        name: 'Groceries',
        description: 'Food and supermarket runs',
        type: CategoryType.expense,
        icon: Icons.shopping_basket_outlined,
      ),
      CategoryItem(
        name: 'Transport',
        description: 'Fuel, metro, and rides',
        type: CategoryType.expense,
        icon: Icons.directions_car_outlined,
      ),
      CategoryItem(
        name: 'Dining',
        description: 'Restaurants and coffee stops',
        type: CategoryType.expense,
        icon: Icons.restaurant_outlined,
      ),
      CategoryItem(
        name: 'Salary',
        description: 'Primary monthly pay',
        type: CategoryType.income,
        icon: Icons.payments_outlined,
      ),
      CategoryItem(
        name: 'Freelance',
        description: 'Side work and consulting',
        type: CategoryType.income,
        icon: Icons.laptop_mac_outlined,
      ),
    ];
  }
}
