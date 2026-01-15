import 'package:expense_tracker/features/transactions/data/models/transaction_hive_model.dart';

abstract interface class TransactionsDataSource {
  Future<void> init();

  Future<void> upsert(TransactionHiveModel transaction);
  Future<void> deleteById(String id);
  Future<void> clear();

  Future<TransactionHiveModel?> getById(String id);

  Future<List<TransactionHiveModel>> listAll();

  Future<List<TransactionHiveModel>> listByCategory(String category);

  Stream<List<TransactionHiveModel>> watchAll();
}
