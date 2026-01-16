import 'package:expense_tracker/config/routes.dart';
import 'package:expense_tracker/features/transactions/domain/enums/transaction_type.dart';
import 'package:expense_tracker/features/transactions/presentation/widgets/account_card.dart';
import 'package:expense_tracker/features/transactions/presentation/widgets/recent_transactions_card.dart';
import 'package:expense_tracker/features/transactions/presentation/widgets/stat_card.dart';
import 'package:expense_tracker/shared/di/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final txsAsync = ref.watch(transactionsStreamProvider);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.search_rounded),
          onPressed: () {}, // later
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none_rounded),
            onPressed: () {}, // later
          ),
        ],
      ),
      body: txsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: ${err.toString()}')),
        data: (txs) {
          final incomeCents = txs
              .where((t) => t.isIncome)
              .fold<int>(0, (sum, t) => sum + t.amountCents);

          final expenseCents = txs
              .where((t) => t.isExpense)
              .fold<int>(0, (sum, t) => sum + t.amountCents);

          final balanceCents = incomeCents - expenseCents;

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            children: [
              AccountCard(
                balanceCents: balanceCents,
                onAdd: () => context.push(Routes.addTransaction),
                onTransfer: () {}, // later
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Overview',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: StatCard(
                      title: 'Income',
                      amountCents: incomeCents,
                      icon: Icons.trending_up_rounded,
                      accent: Colors.green,
                      type: TransactionType.income,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: StatCard(
                      title: 'Expenses',
                      amountCents: expenseCents,
                      icon: Icons.trending_down_rounded,
                      accent: Colors.red,
                      type: TransactionType.expense,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Recent Transactions',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      // later: go to full list / month view
                    },
                    child: const Text('See all'),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              RecentTransactionsCard(
                transactions: txs,
                onDelete: (id) =>
                    ref.read(transactionsRepositoryProvider).deleteById(id),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push(Routes.addTransaction),
        child: const Icon(Icons.add),
      ),
    );
  }
}
