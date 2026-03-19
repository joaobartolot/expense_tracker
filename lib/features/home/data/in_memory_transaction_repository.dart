import 'package:expense_tracker/features/home/data/transaction_repository.dart';
import 'package:expense_tracker/features/home/domain/models/transaction_item.dart';
import 'package:flutter/material.dart';

class InMemoryTransactionRepository implements TransactionRepository {
  InMemoryTransactionRepository({List<TransactionItem>? initialTransactions})
    : _transactions = initialTransactions ?? _buildInitialTransactions();

  final List<TransactionItem> _transactions;
  int _nextId = 7;

  @override
  Future<List<TransactionItem>> getTransactions() async {
    return List.unmodifiable(_transactions);
  }

  @override
  Future<void> addTransaction(TransactionItem transaction) async {
    _transactions.insert(0, transaction);
  }

  @override
  Future<void> updateTransaction(TransactionItem transaction) async {
    final index = _transactions.indexWhere((item) => item.id == transaction.id);
    if (index == -1) {
      return;
    }

    _transactions[index] = transaction;
  }

  @override
  Future<void> deleteTransaction(String transactionId) async {
    _transactions.removeWhere((transaction) => transaction.id == transactionId);
  }

  @override
  String createTransactionId() {
    final id = 'transaction_${_nextId.toString().padLeft(4, '0')}';
    _nextId++;
    return id;
  }

  static List<TransactionItem> _buildInitialTransactions() {
    return [
      TransactionItem(
        id: 'transaction_0001',
        title: 'Salary',
        subtitle: 'Monthly income',
        amount: 2400.00,
        date: DateTime.now().subtract(const Duration(hours: 2)),
        type: TransactionType.income,
        icon: Icons.payments_outlined,
      ),
      TransactionItem(
        id: 'transaction_0002',
        title: 'Groceries',
        subtitle: 'Local market',
        amount: 52.30,
        date: DateTime.now().subtract(const Duration(hours: 5)),
        type: TransactionType.expense,
        icon: Icons.shopping_bag_outlined,
      ),
      TransactionItem(
        id: 'transaction_0003',
        title: 'Coffee',
        subtitle: 'Morning stop',
        amount: 3.80,
        date: DateTime.now().subtract(const Duration(days: 1, hours: 1)),
        type: TransactionType.expense,
        icon: Icons.local_cafe_outlined,
      ),
      TransactionItem(
        id: 'transaction_0004',
        title: 'Netflix',
        subtitle: 'Subscription',
        amount: 11.99,
        date: DateTime.now().subtract(const Duration(days: 1, hours: 4)),
        type: TransactionType.expense,
        icon: Icons.play_circle_outline,
      ),
      TransactionItem(
        id: 'transaction_0005',
        title: 'Dinner',
        subtitle: 'Italian restaurant',
        amount: 27.40,
        date: DateTime.now().subtract(const Duration(days: 3, hours: 2)),
        type: TransactionType.expense,
        icon: Icons.restaurant_outlined,
      ),
      TransactionItem(
        id: 'transaction_0006',
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
