import 'package:expense_tracker/features/transactions/domain/models/transaction_item.dart';

abstract class TransactionRepository {
  Future<List<TransactionItem>> getTransactions();
  Future<void> addTransaction(TransactionItem transaction);
  Future<void> updateTransaction(TransactionItem transaction);
  Future<void> deleteTransaction(String transactionId);
  String createTransactionId();
}
