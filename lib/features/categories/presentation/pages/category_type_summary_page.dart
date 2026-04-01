import 'package:expense_tracker/core/theme/app_colors.dart';
import 'package:expense_tracker/core/utils/currency_formatter.dart';
import 'package:expense_tracker/features/categories/domain/models/category_item.dart';
import 'package:expense_tracker/features/transactions/domain/models/transaction_item.dart';
import 'package:flutter/material.dart';

class CategoryTypeSummaryPage extends StatelessWidget {
  const CategoryTypeSummaryPage({
    super.key,
    required this.type,
    required this.categories,
    required this.transactions,
  });

  final CategoryType type;
  final List<CategoryItem> categories;
  final List<TransactionItem> transactions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isIncome = type == CategoryType.income;
    final title = isIncome ? 'Income overview' : 'Expense overview';
    final accentColor = isIncome ? AppColors.income : AppColors.iconMuted;
    final accentSurface = isIncome
        ? AppColors.incomeSurface
        : AppColors.expenseSurface;
    final filteredTransactions = transactions
        .where((transaction) => transaction.type == _toTransactionType(type))
        .toList(growable: false);
    final totalAmount = filteredTransactions.fold<double>(
      0,
      (sum, transaction) => sum + transaction.amount,
    );
    final averageAmount = filteredTransactions.isEmpty
        ? 0.0
        : totalAmount / filteredTransactions.length;
    final activeCategoryIds = filteredTransactions
        .map((transaction) => transaction.categoryId)
        .whereType<String>()
        .toSet();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        title: Text(title),
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
                          color: accentSurface,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Icon(
                          isIncome
                              ? Icons.arrow_downward_rounded
                              : Icons.arrow_upward_rounded,
                          color: accentColor,
                          size: 28,
                        ),
                      ),
                      const Spacer(),
                      _StatusBadge(
                        label: isIncome ? 'Income' : 'Expense',
                        textColor: accentColor,
                        backgroundColor: accentSurface,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text(
                    formatCurrency(totalAmount),
                    style: theme.textTheme.displaySmall?.copyWith(
                      color: accentColor,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.6,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    isIncome
                        ? 'Total money recorded from income transactions.'
                        : 'Total money recorded from expense transactions.',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            _SectionCard(
              title: 'Totals',
              child: Column(
                children: [
                  _DetailTile(
                    icon: Icons.category_outlined,
                    label: 'Categories',
                    value: categories.length.toString(),
                  ),
                  const SizedBox(height: 12),
                  _DetailTile(
                    icon: Icons.receipt_long_outlined,
                    label: 'Transactions',
                    value: filteredTransactions.length.toString(),
                  ),
                  const SizedBox(height: 12),
                  _DetailTile(
                    icon: Icons.equalizer_rounded,
                    label: 'Average amount',
                    value: formatCurrency(averageAmount),
                  ),
                  const SizedBox(height: 12),
                  _DetailTile(
                    icon: Icons.check_circle_outline_rounded,
                    label: 'Active categories',
                    value: activeCategoryIds.length.toString(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _SectionCard(
              title: isIncome ? 'Income categories' : 'Expense categories',
              child: categories.isEmpty
                  ? Text(
                      isIncome
                          ? 'No income categories yet.'
                          : 'No expense categories yet.',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    )
                  : Column(
                      children: categories
                          .map((category) {
                            final count = filteredTransactions
                                .where(
                                  (transaction) =>
                                      transaction.categoryId == category.id,
                                )
                                .length;

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _CategoryBreakdownTile(
                                category: category,
                                accentColor: accentColor,
                                backgroundColor: accentSurface,
                                transactionCount: count,
                              ),
                            );
                          })
                          .toList(growable: false),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  TransactionType _toTransactionType(CategoryType type) {
    return switch (type) {
      CategoryType.expense => TransactionType.expense,
      CategoryType.income => TransactionType.income,
    };
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
              color: AppColors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: Icon(icon, size: 18, color: AppColors.brandDark),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: theme.textTheme.bodyLarge?.copyWith(
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

class _CategoryBreakdownTile extends StatelessWidget {
  const _CategoryBreakdownTile({
    required this.category,
    required this.accentColor,
    required this.backgroundColor,
    required this.transactionCount,
  });

  final CategoryItem category;
  final Color accentColor;
  final Color backgroundColor;
  final int transactionCount;

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
              color: backgroundColor,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(category.icon, size: 18, color: accentColor),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  category.name,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  category.description,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '$transactionCount tx',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: accentColor,
              fontWeight: FontWeight.w700,
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
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
