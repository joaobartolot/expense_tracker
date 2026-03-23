import 'package:expense_tracker/core/theme/app_colors.dart';
import 'package:expense_tracker/core/widgets/context_action_menu.dart';
import 'package:expense_tracker/features/categories/data/category_repository.dart';
import 'package:expense_tracker/features/categories/domain/models/category_item.dart';
import 'package:expense_tracker/features/categories/presentation/pages/add_category_page.dart';
import 'package:expense_tracker/features/categories/presentation/pages/category_detail_page.dart';
import 'package:expense_tracker/features/categories/presentation/pages/category_type_summary_page.dart';
import 'package:expense_tracker/features/categories/presentation/widgets/category_section.dart';
import 'package:expense_tracker/features/transactions/data/transaction_repository.dart';
import 'package:expense_tracker/features/transactions/domain/models/transaction_item.dart';
import 'package:flutter/material.dart';

enum _CategoryListAction { edit, delete }

class CategoriesPage extends StatefulWidget {
  const CategoriesPage({
    super.key,
    required this.repository,
    required this.transactionRepository,
  });

  final CategoryRepository repository;
  final TransactionRepository transactionRepository;

  @override
  State<CategoriesPage> createState() => _CategoriesPageState();
}

class _CategoriesPageState extends State<CategoriesPage> {
  static const double _floatingNavClearance = 128;

  List<CategoryItem> _categories = const [];
  List<TransactionItem> _transactions = const [];

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    final categories = await widget.repository.getCategories();
    final transactions = await widget.transactionRepository.getTransactions();

    if (!mounted) {
      return;
    }

    setState(() {
      _categories = categories;
      _transactions = transactions;
    });
  }

  Future<void> _addCategory() async {
    final category = await Navigator.of(context).push<CategoryItem>(
      MaterialPageRoute(builder: (context) => const AddCategoryPage()),
    );

    if (category == null) {
      return;
    }

    await widget.repository.addCategory(category);
    if (!mounted) {
      return;
    }
    await _loadCategories();
  }

  Future<void> _openCategoryDetails(CategoryItem category) async {
    final shouldReload = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => CategoryDetailPage(
          category: category,
          categoryRepository: widget.repository,
          transactionRepository: widget.transactionRepository,
        ),
      ),
    );

    if (shouldReload == true) {
      await _loadCategories();
    }
  }

  Future<void> _openTypeSummary(CategoryType type) async {
    final categories = _categories
        .where((category) => category.type == type)
        .toList(growable: false);

    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (context) => CategoryTypeSummaryPage(
          type: type,
          categories: categories,
          transactions: _transactions,
        ),
      ),
    );
  }

  Future<void> _editCategory(CategoryItem category) async {
    final updatedCategory = await Navigator.of(context).push<CategoryItem>(
      MaterialPageRoute(
        builder: (context) => AddCategoryPage(initialCategory: category),
      ),
    );

    if (updatedCategory == null) {
      return;
    }

    await widget.repository.updateCategory(updatedCategory);
    await _loadCategories();
  }

  Future<void> _deleteCategory(CategoryItem category) async {
    final hasLinkedTransactions = _transactions.any(
      (transaction) => transaction.categoryId == category.id,
    );

    if (hasLinkedTransactions) {
      await showDialog<void>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('Category in use'),
            content: const Text(
              'Move or delete the related transactions before removing this category.',
            ),
            actions: [
              FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          );
        },
      );
      return;
    }

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

    if (didConfirm != true) {
      return;
    }

    await widget.repository.deleteCategory(category.id);
    await _loadCategories();
  }

  Future<void> _showCategoryActionMenu(
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

    if (!mounted) {
      return;
    }

    switch (selectedAction) {
      case _CategoryListAction.edit:
        await _editCategory(category);
        return;
      case _CategoryListAction.delete:
        await _deleteCategory(category);
        return;
      case null:
        return;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final expenseCategories = _categories
        .where((category) => category.type == CategoryType.expense)
        .toList();
    final incomeCategories = _categories
        .where((category) => category.type == CategoryType.income)
        .toList();

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
                onPressed: _addCategory,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Add'),
              ),
            ],
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
                    onTap: () => _openTypeSummary(CategoryType.expense),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _CategoryStat(
                    label: 'Income',
                    value: incomeCategories.length.toString(),
                    accentColor: AppColors.income,
                    backgroundColor: AppColors.incomeSurface,
                    onTap: () => _openTypeSummary(CategoryType.income),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          CategorySection(
            title: 'Expense',
            categories: expenseCategories,
            onCategoryTap: _openCategoryDetails,
            onCategoryLongPressStart: _showCategoryActionMenu,
          ),
          CategorySection(
            title: 'Income',
            categories: incomeCategories,
            onCategoryTap: _openCategoryDetails,
            onCategoryLongPressStart: _showCategoryActionMenu,
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
    this.onTap,
  });

  final String label;
  final String value;
  final Color accentColor;
  final Color backgroundColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
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
                  fontWeight: FontWeight.w700,
                  color: accentColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
