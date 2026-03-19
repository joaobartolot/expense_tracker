import 'package:expense_tracker/features/categories/data/category_repository.dart';
import 'package:expense_tracker/features/categories/domain/models/category_item.dart';
import 'package:flutter/material.dart';

class InMemoryCategoryRepository implements CategoryRepository {
  InMemoryCategoryRepository({List<CategoryItem>? initialCategories})
    : _categories = initialCategories ?? _buildInitialCategories();

  final List<CategoryItem> _categories;
  int _nextMockIndex = 0;

  @override
  Future<List<CategoryItem>> getCategories() async {
    return List.unmodifiable(_categories);
  }

  @override
  Future<void> addCategory(CategoryItem category) async {
    _categories.insert(0, category);
  }

  CategoryItem buildMockCategory() {
    final mockCategory =
        _mockCategories[_nextMockIndex % _mockCategories.length];
    _nextMockIndex++;
    return mockCategory;
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

  static const List<CategoryItem> _mockCategories = [
    CategoryItem(
      name: 'Utilities',
      description: 'Electricity, water, and internet',
      type: CategoryType.expense,
      icon: Icons.flash_on_outlined,
    ),
    CategoryItem(
      name: 'Health',
      description: 'Pharmacy and medical expenses',
      type: CategoryType.expense,
      icon: Icons.favorite_border,
    ),
    CategoryItem(
      name: 'Bonus',
      description: 'Performance and yearly bonuses',
      type: CategoryType.income,
      icon: Icons.workspace_premium_outlined,
    ),
    CategoryItem(
      name: 'Investments',
      description: 'Dividends and passive income',
      type: CategoryType.income,
      icon: Icons.trending_up_outlined,
    ),
  ];
}
