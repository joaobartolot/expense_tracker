import 'package:expense_tracker/features/transactions/data/datasources/hive_transactions_datasource.dart';
import 'package:expense_tracker/features/transactions/data/datasources/transactions_data_source.dart';
import 'package:expense_tracker/features/transactions/data/repositories/transactions_repository_impl.dart';
import 'package:expense_tracker/features/transactions/domain/models/transaction.dart';
import 'package:expense_tracker/features/transactions/domain/repositories/transactions_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final transactionsDataSourceProvider = Provider<TransactionsDataSource>((ref) {
  return HiveTransactionsDataSource();
});

final transactionsRepositoryProvider = Provider<TransactionsRepository>((ref) {
  final ds = ref.watch(transactionsDataSourceProvider);
  return TransactionsRepositoryImpl(ds);
});

/// Live stream of all transactions (newest first).
final transactionsStreamProvider = StreamProvider<List<Transaction>>((ref) {
  final repo = ref.watch(transactionsRepositoryProvider);
  return repo.watchAll();
});
