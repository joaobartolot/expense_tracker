import 'package:expense_tracker/core/theme/app_colors.dart';
import 'package:expense_tracker/features/home/domain/models/transaction_item.dart';
import 'package:expense_tracker/features/home/presentation/widgets/transaction_tile.dart';
import 'package:flutter/material.dart';

class TransactionGroup extends StatelessWidget {
  const TransactionGroup({
    super.key,
    required this.label,
    required this.transactions,
  });

  final String label;
  final List<TransactionItem> transactions;

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
              child: TransactionTile(transaction: transaction),
            );
          }),
        ],
      ),
    );
  }
}
