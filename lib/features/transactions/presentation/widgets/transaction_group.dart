import 'package:expense_tracker/core/theme/app_colors.dart';
import 'package:expense_tracker/features/transactions/domain/models/transaction_item.dart';
import 'package:expense_tracker/features/transactions/presentation/widgets/transaction_tile.dart';
import 'package:flutter/material.dart';

class TransactionGroup extends StatelessWidget {
  const TransactionGroup({
    super.key,
    required this.label,
    required this.transactions,
    required this.categoryNameFor,
    required this.categoryIconFor,
    required this.accountNameFor,
    required this.destinationAccountNameFor,
    required this.onTransactionTap,
    required this.onTransactionLongPressStart,
  });

  final String label;
  final List<TransactionItem> transactions;
  final String Function(TransactionItem transaction) categoryNameFor;
  final IconData Function(TransactionItem transaction) categoryIconFor;
  final String Function(TransactionItem transaction) accountNameFor;
  final String? Function(TransactionItem transaction) destinationAccountNameFor;
  final ValueChanged<TransactionItem> onTransactionTap;
  final void Function(TransactionItem, LongPressStartDetails)
  onTransactionLongPressStart;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w400,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          ...transactions.map((transaction) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: TransactionTile(
                transaction: transaction,
                categoryName: categoryNameFor(transaction),
                categoryIcon: categoryIconFor(transaction),
                accountName: accountNameFor(transaction),
                destinationAccountName: destinationAccountNameFor(transaction),
                onTap: () => onTransactionTap(transaction),
                onLongPressStart: (details) =>
                    onTransactionLongPressStart(transaction, details),
              ),
            );
          }),
        ],
      ),
    );
  }
}
