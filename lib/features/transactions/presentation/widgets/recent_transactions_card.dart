import 'package:expense_tracker/features/transactions/domain/models/transaction.dart';
import 'package:expense_tracker/features/transactions/presentation/widgets/transaction_amount.dart';
import 'package:flutter/material.dart';

class RecentTransactionsCard extends StatelessWidget {
  const RecentTransactionsCard({
    super.key,
    required this.transactions,
    required this.onDelete,
  });

  final List<Transaction> transactions;
  final Future<void> Function(String id) onDelete;

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
          final tx = transactions[index];
          final isExpense = tx.isExpense;

          return ListTile(
            onLongPress: () => onDelete(tx.id),
            leading: CircleAvatar(
              backgroundColor: (isExpense ? Colors.red : Colors.green)
                  .withValues(alpha: 0.12),
              child: Icon(
                isExpense ? Icons.remove_rounded : Icons.add_rounded,
                color: isExpense ? Colors.red : Colors.green,
              ),
            ),
            title: Text(tx.name, maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text(
              '${tx.category} • ${tx.date.toLocal().toString().split('.').first}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: TransactionAmount(
              amountCents: tx.amountCents,
              type: tx.type,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          );
        },
      ),
    );
  }
}
