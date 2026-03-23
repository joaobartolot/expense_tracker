import 'package:expense_tracker/features/transactions/domain/models/transaction_item.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

abstract class TransactionRepository {
  Future<List<TransactionItem>> getTransactions();
  ValueListenable<Box<dynamic>> listenable();
  Future<void> addTransaction(TransactionItem transaction);
  Future<void> updateTransaction(TransactionItem transaction);
  Future<void> deleteTransaction(String transactionId);
  String createTransactionId();
}
