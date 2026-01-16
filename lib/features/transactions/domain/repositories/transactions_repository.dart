import 'package:expense_tracker/features/transactions/domain/models/transaction.dart';

abstract interface class TransactionsRepository {
  Future<void> init();

  Future<void> upsert(Transaction transaction);
  Future<void> deleteById(String id);
  Future<void> clear();

  Future<Transaction?> getById(String id);

  Future<List<Transaction>> listAll();

  Future<List<Transaction>> listByCategory(String category);

  Stream<List<Transaction>> watchAll();

  Stream<List<Transaction>> watchByMonth(DateTime month);
}
