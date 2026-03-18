import 'package:expense_tracker/features/home/data/transaction_repository.dart';
import 'package:expense_tracker/features/home/domain/models/transaction_item.dart';
import 'package:flutter/material.dart';

class InMemoryTransactionRepository implements TransactionRepository {
  InMemoryTransactionRepository({List<TransactionItem>? initialTransactions})
    : _transactions = initialTransactions ?? _buildInitialTransactions();

  final List<TransactionItem> _transactions;

  @override
  Future<List<TransactionItem>> getTransactions() async {
    return List.unmodifiable(_transactions);
  }

  @override
  Future<void> addTransaction(TransactionItem transaction) async {
    _transactions.insert(0, transaction);
  }

  static List<TransactionItem> _buildInitialTransactions() {
    return [
      TransactionItem(
        title: 'Salary',
        subtitle: 'Monthly income',
        amount: 2400.00,
        date: DateTime.now().subtract(const Duration(hours: 2)),
        type: TransactionType.income,
        icon: Icons.payments_outlined,
      ),
      TransactionItem(
        title: 'Groceries',
        subtitle: 'Local market',
        amount: 52.30,
        date: DateTime.now().subtract(const Duration(hours: 5)),
        type: TransactionType.expense,
        icon: Icons.shopping_bag_outlined,
      ),
      TransactionItem(
        title: 'Coffee',
        subtitle: 'Morning stop',
        amount: 3.80,
        date: DateTime.now().subtract(const Duration(days: 1, hours: 1)),
        type: TransactionType.expense,
        icon: Icons.local_cafe_outlined,
      ),
      TransactionItem(
        title: 'Netflix',
        subtitle: 'Subscription',
        amount: 11.99,
        date: DateTime.now().subtract(const Duration(days: 1, hours: 4)),
        type: TransactionType.expense,
        icon: Icons.play_circle_outline,
      ),
      TransactionItem(
        title: 'Dinner',
        subtitle: 'Italian restaurant',
        amount: 27.40,
        date: DateTime.now().subtract(const Duration(days: 3, hours: 2)),
        type: TransactionType.expense,
        icon: Icons.restaurant_outlined,
      ),
      TransactionItem(
        title: 'Refund',
        subtitle: 'Online order',
        amount: 18.00,
        date: DateTime.now().subtract(const Duration(days: 6)),
        type: TransactionType.income,
        icon: Icons.replay_circle_filled_outlined,
      ),
    ];
  }
}
