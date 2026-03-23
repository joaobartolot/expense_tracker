import 'package:expense_tracker/core/theme/app_colors.dart';
import 'package:expense_tracker/features/categories/domain/models/category_item.dart';
import 'package:expense_tracker/features/categories/presentation/widgets/category_tile.dart';
import 'package:flutter/material.dart';

class CategorySection extends StatelessWidget {
  const CategorySection({
    super.key,
    required this.title,
    required this.subtitle,
    required this.categories,
  });

  final String title;
  final String subtitle;
  final List<CategoryItem> categories;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 14),
          ...categories.map(
            (category) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: CategoryTile(category: category),
            ),
          ),
        ],
      ),
    );
  }
}
