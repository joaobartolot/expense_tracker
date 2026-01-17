import 'package:expense_tracker/features/transactions/domain/models/transaction.dart';
import 'package:expense_tracker/features/transactions/presentation/widgets/transaction_amount.dart';
import 'package:flutter/material.dart';

class RecentTransactionsCard extends StatelessWidget {
  const RecentTransactionsCard({
    super.key,
    required this.transactions,
    required this.onDelete,
    required this.onEdit,
    required this.onTap,
  });

  final List<Transaction> transactions;
  final Future<void> Function(String id) onDelete;
  final void Function(Transaction transaction) onEdit;
  final void Function(Transaction transaction) onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (transactions.isEmpty) {
      return Card(
        elevation: 0,
        color: cs.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: const Padding(
          padding: EdgeInsets.all(18),
          child: Center(child: Text('No transactions yet')),
        ),
      );
    }

    return Card(
      elevation: 0,
      color: cs.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: transactions.length.clamp(0, 8),
        separatorBuilder: (_, __) => Divider(
          height: 1,
          thickness: 1,
          color: cs.outlineVariant.withValues(alpha: 0.35),
        ),
        itemBuilder: (context, index) {
          final transaction = transactions[index];
          final isExpense = transaction.isExpense;

          return Dismissible(
            key: ValueKey(transaction.id),
            direction: DismissDirection.horizontal,
            confirmDismiss: (direction) async {
              if (direction == DismissDirection.startToEnd) {
                // Left to right - Edit
                onEdit(transaction);
                return false; // Don't dismiss
              } else {
                // Right to left - Delete
                return await _showDeleteDialog(context, transaction);
              }
            },
            onDismissed: (_) => onDelete(transaction.id),
            background: Container(
              color: Colors.blue,
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.only(left: 20),
              child: const Icon(Icons.edit, color: Colors.white),
            ),
            secondaryBackground: Container(
              color: Colors.red,
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 20),
              child: const Icon(Icons.delete, color: Colors.white),
            ),
            child: ListTile(
              onTap: () => onTap(transaction),
              leading: CircleAvatar(
                backgroundColor: (isExpense ? Colors.red : Colors.green)
                    .withValues(alpha: 0.12),
                child: Icon(
                  isExpense ? Icons.remove_rounded : Icons.add_rounded,
                  color: isExpense ? Colors.red : Colors.green,
                ),
              ),
              title: Text(
                transaction.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                '${transaction.category.displayName} • ${transaction.date.toLocal().toString().split(' ').first}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: TransactionAmount(
                amountCents: transaction.amountCents,
                type: transaction.type,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<bool> _showDeleteDialog(
    BuildContext context,
    Transaction transaction,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Transaction'),
        content: Text(
          'Are you sure you want to delete "${transaction.name}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }
}
