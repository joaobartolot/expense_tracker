import 'package:expense_tracker/app/state/app_state_provider.dart';
import 'package:expense_tracker/core/theme/app_colors.dart';
import 'package:expense_tracker/core/utils/currency_formatter.dart';
import 'package:expense_tracker/features/categories/domain/models/category_item.dart';
import 'package:expense_tracker/features/categories/presentation/pages/category_detail_page.dart';
import 'package:expense_tracker/features/transactions/domain/models/transaction_item.dart';
import 'package:expense_tracker/features/transactions/presentation/pages/add_transaction_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class TransactionDetailPage extends ConsumerWidget {
  const TransactionDetailPage({super.key, required this.transactionId});

  final String transactionId;

  Future<void> _editTransaction(
    BuildContext context,
    TransactionItem transaction,
  ) async {
    final didChange = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) =>
            AddTransactionPage(initialTransaction: transaction),
      ),
    );

    if (didChange != true || !context.mounted) {
      return;
    }

    Navigator.of(context).pop(true);
  }

  Future<void> _deleteTransaction(
    BuildContext context,
    WidgetRef ref,
    TransactionItem transaction,
  ) async {
    final didConfirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete transaction?'),
          content: const Text(
            'This transaction will be removed from your history.',
          ),
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

    await ref.read(appStateProvider.notifier).deleteTransaction(transaction.id);

    if (!context.mounted) {
      return;
    }

    Navigator.of(context).pop(true);
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appStateProvider);
    final transaction = state.transactions
        .where((item) => item.id == transactionId)
        .firstOrNull;

    if (transaction == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Transaction details')),
        body: const Center(child: Text('This transaction no longer exists.')),
      );
    }

    final theme = Theme.of(context);
    final category = state.categoryById(transaction.categoryId);
    final account = state.accountById(transaction.primaryAccountId);
    final sourceAccount = state.accountById(transaction.sourceAccountId);
    final destinationAccount = state.accountById(
      transaction.secondaryAccountId,
    );
    final isIncome = transaction.type == TransactionType.income;
    final isTransfer = transaction.type == TransactionType.transfer;
    final isCreditCardPayment = transaction.isCreditCardPayment;
    final amountColor = isTransfer
        ? AppColors.brandDark
        : isIncome
        ? AppColors.income
        : AppColors.textPrimary;
    final amountPrefix = isTransfer ? '' : (isIncome ? '+' : '-');
    final localizations = MaterialLocalizations.of(context);
    final fullDate = localizations.formatFullDate(transaction.date);
    final time = localizations.formatTimeOfDay(
      TimeOfDay.fromDateTime(transaction.date),
    );
    final shortDate = localizations.formatShortDate(transaction.date);
    final categoryName = category?.name ?? 'Unknown category';
    final accountName = account?.name ?? 'Unknown account';
    final sourceAccountName = sourceAccount?.name ?? 'Unknown account';
    final destinationAccountName =
        destinationAccount?.name ?? 'Unknown account';
    final categoryIcon = isCreditCardPayment
        ? Icons.credit_card_rounded
        : isTransfer
        ? Icons.swap_horiz_rounded
        : category?.icon ?? Icons.sell_outlined;
    final enteredCurrencyCode =
        transaction.foreignCurrencyCode ?? transaction.currencyCode;
    final enteredAmount = transaction.foreignAmount ?? transaction.amount;
    final iconBackground = isTransfer
        ? AppColors.background
        : isIncome
        ? AppColors.incomeSurface
        : AppColors.expenseSurface;
    final iconColor = isTransfer
        ? AppColors.brandDark
        : isIncome
        ? AppColors.income
        : AppColors.iconMuted;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        title: const Text('Transaction details'),
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
                        child: Icon(categoryIcon, color: iconColor, size: 28),
                      ),
                      const Spacer(),
                      _StatusBadge(
                        label: isTransfer
                            ? (isCreditCardPayment
                                  ? 'Card payment'
                                  : 'Transfer')
                            : isIncome
                            ? 'Income'
                            : 'Expense',
                        textColor: iconColor,
                        backgroundColor: iconBackground,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text(
                    transaction.title,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '$amountPrefix${formatCurrency(transaction.amount, currencyCode: transaction.currencyCode)}',
                    style: theme.textTheme.displaySmall?.copyWith(
                      color: amountColor,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.6,
                    ),
                  ),
                  if (transaction.hasForeignCurrency) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Entered as ${formatCurrency(enteredAmount, currencyCode: enteredCurrencyCode)}',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Converted to ${transaction.currencyCode} at ${transaction.exchangeRate?.toStringAsFixed(4) ?? 'n/a'}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),
            _SectionCard(
              title: 'Overview',
              child: Column(
                children: [
                  if (!isTransfer) ...[
                    _ActionDetailTile(
                      icon: categoryIcon,
                      label: 'Category',
                      value: categoryName,
                      onTap: category == null
                          ? null
                          : () => _openCategoryDetails(context, category),
                    ),
                    const SizedBox(height: 12),
                    _DetailTile(
                      icon: Icons.account_balance_wallet_outlined,
                      label: 'Account',
                      value: accountName,
                    ),
                  ] else ...[
                    _DetailTile(
                      icon: Icons.arrow_upward_rounded,
                      label: isCreditCardPayment ? 'Paid from' : 'From account',
                      value: sourceAccountName,
                    ),
                    const SizedBox(height: 12),
                    _DetailTile(
                      icon: isCreditCardPayment
                          ? Icons.credit_card_rounded
                          : Icons.arrow_downward_rounded,
                      label: isCreditCardPayment ? 'Credit card' : 'To account',
                      value: destinationAccountName,
                    ),
                  ],
                  const SizedBox(height: 12),
                  _DetailTile(
                    icon: Icons.event_outlined,
                    label: 'Date',
                    value: shortDate,
                  ),
                  const SizedBox(height: 12),
                  _DetailTile(
                    icon: Icons.schedule_outlined,
                    label: 'Time',
                    value: time,
                  ),
                  const SizedBox(height: 12),
                  _DetailTile(
                    icon: Icons.calendar_today_outlined,
                    label: 'Full date',
                    value: fullDate,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _editTransaction(context, transaction),
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Edit'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () =>
                        _deleteTransaction(context, ref, transaction),
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

class _ActionDetailTile extends StatelessWidget {
  const _ActionDetailTile({
    required this.icon,
    required this.label,
    required this.value,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final child = _DetailTile(icon: icon, label: label, value: value);
    if (onTap == null) {
      return child;
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: child,
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
