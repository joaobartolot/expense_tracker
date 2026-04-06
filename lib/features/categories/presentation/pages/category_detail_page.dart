import 'package:expense_tracker/app/state/app_state_provider.dart';
import 'package:expense_tracker/core/theme/app_colors.dart';
import 'package:expense_tracker/core/utils/currency_formatter.dart';
import 'package:expense_tracker/features/categories/domain/models/category_item.dart';
import 'package:expense_tracker/features/categories/presentation/pages/add_category_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum _CategoryDeletionAction {
  deleteCategoryOnly,
  deleteCategoryAndTransactions,
}

class CategoryDetailPage extends ConsumerWidget {
  const CategoryDetailPage({super.key, required this.categoryId});

  final String categoryId;

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

    if (!context.mounted) {
      return;
    }

    Navigator.of(context).pop(true);
  }

  Future<void> _deleteCategory(
    BuildContext context,
    WidgetRef ref,
    CategoryItem category,
  ) async {
    final state = ref.read(appStateProvider);
    final linkedTransactions = state.transactionsForCategory(category.id);
    final deletionAction = await showDialog<_CategoryDeletionAction>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete category?'),
          content: Text(
            linkedTransactions.isEmpty
                ? 'This category will be removed from your list.'
                : 'This category has ${linkedTransactions.length} linked transaction${linkedTransactions.length == 1 ? '' : 's'}. Delete the category only if you also want to remove those transactions.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            if (linkedTransactions.isEmpty)
              FilledButton(
                onPressed: () => Navigator.of(
                  context,
                ).pop(_CategoryDeletionAction.deleteCategoryOnly),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.danger,
                  foregroundColor: AppColors.white,
                ),
                child: const Text('Delete'),
              )
            else
              FilledButton(
                onPressed: () => Navigator.of(
                  context,
                ).pop(_CategoryDeletionAction.deleteCategoryAndTransactions),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.danger,
                  foregroundColor: AppColors.white,
                ),
                child: const Text('Delete all'),
              ),
          ],
        );
      },
    );

    if (deletionAction == null || !context.mounted) {
      return;
    }

    if (deletionAction ==
        _CategoryDeletionAction.deleteCategoryAndTransactions) {
      await ref
          .read(appStateProvider.notifier)
          .deleteCategoryWithTransactions(category);
    } else {
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
        return;
      }
    }

    if (!context.mounted) {
      return;
    }

    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appStateProvider);
    final theme = Theme.of(context);
    final category = state.categoryById(categoryId);

    if (category == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Category details')),
        body: const Center(child: Text('This category no longer exists.')),
      );
    }

    final relatedTransactions = state.transactionsForCategory(category.id);
    final isIncome = category.type == CategoryType.income;
    final iconBackground = isIncome
        ? AppColors.incomeSurface
        : AppColors.expenseSurface;
    final iconColor = isIncome ? AppColors.income : AppColors.iconMuted;
    final convertedTotalAmount = state.totalForTransactions(
      relatedTransactions,
    );
    final missingConversionCount = state.missingConversionCountForTransactions(
      relatedTransactions,
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        title: const Text('Category details'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(32),
                gradient: const LinearGradient(
                  colors: [Color(0xFFFFFFFF), Color(0xFFF7FBF9)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border.all(color: AppColors.border),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x12000000),
                    blurRadius: 28,
                    offset: Offset(0, 14),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: iconBackground,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Icon(category.icon, color: iconColor, size: 28),
                      ),
                      const Spacer(),
                      _StatusBadge(
                        label: isIncome ? 'Income' : 'Expense',
                        textColor: iconColor,
                        backgroundColor: iconBackground,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text(
                    category.name,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    category.description,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '${relatedTransactions.length} linked transaction${relatedTransactions.length == 1 ? '' : 's'}',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            _SectionCard(
              title: 'Overview',
              child: Column(
                children: [
                  _DetailTile(
                    icon: Icons.swap_vert_rounded,
                    label: 'Type',
                    value: isIncome ? 'Income' : 'Expense',
                  ),
                  const SizedBox(height: 12),
                  _DetailTile(
                    icon: Icons.receipt_long_outlined,
                    label: 'Transactions',
                    value: relatedTransactions.length.toString(),
                  ),
                  const SizedBox(height: 12),
                  _DetailTile(
                    icon: Icons.savings_outlined,
                    label: missingConversionCount == 0
                        ? 'Total tracked'
                        : 'Total tracked (partial)',
                    value: formatCurrency(
                      convertedTotalAmount,
                      currencyCode: state.settings.defaultCurrencyCode,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _SectionCard(
              title: 'Recent activity',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (relatedTransactions.isEmpty)
                    Text(
                      'No transactions are using this category yet.',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    )
                  else
                    ...relatedTransactions
                        .take(5)
                        .map(
                          (transaction) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _RecentTransactionTile(
                              title: transaction.title,
                              amount: formatCurrency(
                                state.convertedAmountForTransaction(
                                      transaction.id,
                                    ) ??
                                    transaction.amount,
                                currencyCode:
                                    state.convertedAmountForTransaction(
                                          transaction.id,
                                        ) !=
                                        null
                                    ? state.settings.defaultCurrencyCode
                                    : transaction.currencyCode,
                              ),
                            ),
                          ),
                        ),
                  if (missingConversionCount > 0) ...[
                    const SizedBox(height: 12),
                    Text(
                      '$missingConversionCount transaction${missingConversionCount == 1 ? '' : 's'} excluded because exchange rates were unavailable.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _editCategory(context, ref, category),
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Edit'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => _deleteCategory(context, ref, category),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.danger,
                      foregroundColor: AppColors.white,
                    ),
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Delete'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _DetailTile extends StatelessWidget {
  const _DetailTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FBFA),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: AppColors.iconMuted, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentTransactionTile extends StatelessWidget {
  const _RecentTransactionTile({required this.title, required this.amount});

  final String title;
  final String amount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FBFA),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            amount,
            style: theme.textTheme.labelLarge?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({
    required this.label,
    required this.textColor,
    required this.backgroundColor,
  });

  final String label;
  final Color textColor;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelLarge?.copyWith(
          color: textColor,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
