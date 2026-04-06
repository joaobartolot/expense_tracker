import 'package:expense_tracker/app/state/app_state_provider.dart';
import 'package:expense_tracker/core/theme/app_colors.dart';
import 'package:expense_tracker/core/widgets/context_action_menu.dart';
import 'package:expense_tracker/features/categories/domain/models/category_item.dart';
import 'package:expense_tracker/features/categories/presentation/pages/add_category_page.dart';
import 'package:expense_tracker/features/categories/presentation/pages/category_detail_page.dart';
import 'package:expense_tracker/features/categories/presentation/pages/category_type_summary_page.dart';
import 'package:expense_tracker/features/categories/presentation/widgets/category_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum _CategoryListAction { edit, delete }

class CategoriesPage extends ConsumerWidget {
  const CategoriesPage({super.key});

  static const double _floatingNavClearance = 128;

  Future<void> _addCategory(BuildContext context, WidgetRef ref) async {
    final category = await Navigator.of(context).push<CategoryItem>(
      MaterialPageRoute(builder: (context) => const AddCategoryPage()),
    );

    if (category == null || !context.mounted) {
      return;
    }

    await ref
        .read(appStateProvider.notifier)
        .saveCategory(category, isEditing: false);
  }

  Future<void> _openCategoryDetails(
    BuildContext context,
    CategoryItem category,
  ) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => CategoryDetailPage(categoryId: category.id),
      ),
    );
  }

  Future<void> _openTypeSummary(BuildContext context, CategoryType type) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (context) => CategoryTypeSummaryPage(type: type),
      ),
    );
  }

  Future<void> _editCategory(
    BuildContext context,
    WidgetRef ref,
    CategoryItem category,
  ) async {
    final updatedCategory = await Navigator.of(context).push<CategoryItem>(
      MaterialPageRoute(
        builder: (context) => AddCategoryPage(initialCategory: category),
      ),
    );

    if (updatedCategory == null || !context.mounted) {
      return;
    }

    await ref
        .read(appStateProvider.notifier)
        .saveCategory(updatedCategory, isEditing: true);
  }

  Future<void> _deleteCategory(
    BuildContext context,
    WidgetRef ref,
    CategoryItem category,
  ) async {
    final didConfirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete category?'),
          content: const Text('This category will be removed from your list.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.danger,
                foregroundColor: AppColors.white,
              ),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (didConfirm != true || !context.mounted) {
      return;
    }

    try {
      await ref.read(appStateProvider.notifier).deleteCategory(category);
    } on LinkedEntityException catch (error) {
      if (!context.mounted) {
        return;
      }

      await showDialog<void>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('Category in use'),
            content: Text(error.message),
            actions: [
              FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          );
        },
      );
    }
  }

  Future<void> _showCategoryActionMenu(
    BuildContext context,
    WidgetRef ref,
    CategoryItem category,
    LongPressStartDetails details,
  ) async {
    final selectedAction = await showContextActionMenu<_CategoryListAction>(
      context: context,
      globalPosition: details.globalPosition,
      items: const [
        ContextActionMenuItem(
          value: _CategoryListAction.edit,
          label: 'Edit',
          icon: Icons.edit_outlined,
        ),
        ContextActionMenuItem(
          value: _CategoryListAction.delete,
          label: 'Delete',
          icon: Icons.delete_outline,
          foregroundColor: AppColors.dangerDark,
        ),
      ],
    );

    if (!context.mounted) {
      return;
    }

    switch (selectedAction) {
      case _CategoryListAction.edit:
        await _editCategory(context, ref, category);
        return;
      case _CategoryListAction.delete:
        await _deleteCategory(context, ref, category);
        return;
      case null:
        return;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appStateProvider);
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final expenseCategories = state.expenseCategories;
    final incomeCategories = state.incomeCategories;

    return SafeArea(
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          20,
          20,
          20,
          32 + _floatingNavClearance + bottomInset,
        ),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Categories',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w600,
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
                  ],
                ),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: () => _addCategory(context, ref),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Add'),
              ),
            ],
          ),
          const SizedBox(height: 24),
          if (!state.hasLoaded && state.isLoading)
            const Center(child: CircularProgressIndicator())
          else ...[
            Row(
              children: [
                Text(
                  'Expenses',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const Spacer(),
                if (expenseCategories.isNotEmpty)
                  TextButton(
                    onPressed: () =>
                        _openTypeSummary(context, CategoryType.expense),
                    child: const Text('Overview'),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (expenseCategories.isEmpty)
              const _EmptyCategoryGroup(label: 'No expense categories yet.')
            else
              CategorySection(
                title: '',
                categories: expenseCategories,
                onCategoryTap: (category) =>
                    _openCategoryDetails(context, category),
                onCategoryLongPressStart: (category, details) =>
                    _showCategoryActionMenu(context, ref, category, details),
              ),
            const SizedBox(height: 16),
            Row(
              children: [
                Text(
                  'Income',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const Spacer(),
                if (incomeCategories.isNotEmpty)
                  TextButton(
                    onPressed: () =>
                        _openTypeSummary(context, CategoryType.income),
                    child: const Text('Overview'),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (incomeCategories.isEmpty)
              const _EmptyCategoryGroup(label: 'No income categories yet.')
            else
              CategorySection(
                title: '',
                categories: incomeCategories,
                onCategoryTap: (category) =>
                    _openCategoryDetails(context, category),
                onCategoryLongPressStart: (category, details) =>
                    _showCategoryActionMenu(context, ref, category, details),
              ),
          ],
        ],
      ),
    );
  }
}

class _EmptyCategoryGroup extends StatelessWidget {
  const _EmptyCategoryGroup({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        label,
        style: theme.textTheme.bodyLarge?.copyWith(
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}
