import 'package:expense_tracker/features/home/domain/models/transaction_item.dart';

abstract class TransactionRepository {
  Future<List<TransactionItem>> getTransactions();
  Future<void> addTransaction(TransactionItem transaction);
}
