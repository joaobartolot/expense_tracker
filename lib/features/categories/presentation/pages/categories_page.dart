import 'package:expense_tracker/core/theme/app_colors.dart';
import 'package:expense_tracker/features/categories/data/category_repository.dart';
import 'package:expense_tracker/features/categories/data/in_memory_category_repository.dart';
import 'package:expense_tracker/features/categories/domain/models/category_item.dart';
import 'package:expense_tracker/features/categories/presentation/widgets/category_section.dart';
import 'package:flutter/material.dart';

class CategoriesPage extends StatefulWidget {
  const CategoriesPage({super.key, required this.repository});

  final CategoryRepository repository;

  @override
  State<CategoriesPage> createState() => _CategoriesPageState();
}

class _CategoriesPageState extends State<CategoriesPage> {
  List<CategoryItem> _categories = const [];

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    final categories = await widget.repository.getCategories();

    if (!mounted) {
      return;
    }

    setState(() {
      _categories = categories;
    });
  }

  Future<void> _addCategory() async {
    final repository = widget.repository;
    final category = switch (repository) {
      InMemoryCategoryRepository repo => repo.buildMockCategory(),
      _ => const CategoryItem(
        name: 'New category',
        description: 'Mock category',
        type: CategoryType.expense,
        icon: Icons.sell_outlined,
      ),
    };

    await widget.repository.addCategory(category);
    await _loadCategories();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final expenseCategories = _categories
        .where((category) => category.type == CategoryType.expense)
        .toList();
    final incomeCategories = _categories
        .where((category) => category.type == CategoryType.income)
        .toList();

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        children: [
          Text(
            'Categories',
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Organize expenses and income with simple buckets you can grow later.',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(28),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _CategoryStat(
                    label: 'Expenses',
                    value: expenseCategories.length.toString(),
                    accentColor: AppColors.iconMuted,
                    backgroundColor: AppColors.expenseSurface,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _CategoryStat(
                    label: 'Income',
                    value: incomeCategories.length.toString(),
                    accentColor: AppColors.income,
                    backgroundColor: AppColors.incomeSurface,
                  ),
                ),
                const SizedBox(width: 12),
                InkWell(
                  onTap: _addCategory,
                  borderRadius: BorderRadius.circular(20),
                  child: Ink(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.brand,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(Icons.add, color: AppColors.white),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          CategorySection(
            title: 'Expense categories',
            subtitle:
                'Everyday spending buckets for tracking where money goes.',
            categories: expenseCategories,
          ),
          CategorySection(
            title: 'Income categories',
            subtitle: 'Sources of money coming into your budget.',
            categories: incomeCategories,
          ),
        ],
      ),
    );
  }
}

class _CategoryStat extends StatelessWidget {
  const _CategoryStat({
    required this.label,
    required this.value,
    required this.accentColor,
    required this.backgroundColor,
  });

  final String label;
  final String value;
  final Color accentColor;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: accentColor,
            ),
          ),
        ],
      ),
    );
  }
}
