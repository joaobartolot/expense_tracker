import 'package:expense_tracker/core/theme/app_colors.dart';
import 'package:expense_tracker/core/utils/date_label_formatter.dart';
import 'package:expense_tracker/features/home/data/transaction_repository.dart';
import 'package:expense_tracker/features/home/domain/models/transaction_item.dart';
import 'package:expense_tracker/features/home/presentation/widgets/balance_card.dart';
import 'package:expense_tracker/features/home/presentation/widgets/transaction_group.dart';
import 'package:flutter/material.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.repository});

  final TransactionRepository repository;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<TransactionItem> _transactions = const [];

  @override
  void initState() {
    super.initState();
    _loadTransactions();
  }

  Future<void> _loadTransactions() async {
    final transactions = await widget.repository.getTransactions();

    if (!mounted) {
      return;
    }

    setState(() {
      _transactions = transactions;
    });
  }

  Future<void> _addTransaction() async {
    await widget.repository.addTransaction(_buildMockTransaction());
    await _loadTransactions();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final groupedTransactions = _groupTransactions(_transactions);
    final balance = _transactions.fold<double>(
      0,
      (sum, transaction) => sum + transaction.signedAmount,
    );

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        children: [
          Text(
            'Hello',
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 20),
          BalanceCard(balance: balance),
          const SizedBox(height: 28),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Transactions',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              InkWell(
                onTap: _addTransaction,
                borderRadius: BorderRadius.circular(999),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 6,
                  ),
                  child: const Icon(Icons.add, color: AppColors.brand),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...groupedTransactions.entries.map(
            (entry) =>
                TransactionGroup(label: entry.key, transactions: entry.value),
          ),
        ],
      ),
    );
  }

  Map<String, List<TransactionItem>> _groupTransactions(
    List<TransactionItem> transactions,
  ) {
    final sortedTransactions = [...transactions]
      ..sort((a, b) => b.date.compareTo(a.date));
    final grouped = <String, List<TransactionItem>>{};

    for (final transaction in sortedTransactions) {
      final label = formatDateLabel(transaction.date);
      grouped.putIfAbsent(label, () => []).add(transaction);
    }

    return grouped;
  }

  TransactionItem _buildMockTransaction() {
    return TransactionItem(
      title: 'Sample expense',
      subtitle: 'Mock added transaction',
      amount: 14.50,
      date: DateTime.now(),
      type: TransactionType.expense,
      icon: Icons.receipt_long_outlined,
    );
  }
}
