import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/datasources/hive_transactions_datasource.dart';
import '../data/repositories/transactions_repository_impl.dart';
import '../domain/repositories/transactions_repository.dart';

final transactionsDataSourceProvider = Provider((ref) {
  return HiveTransactionsDataSource(); // assumes it internally opened boxes already
});

final transactionsRepositoryProvider = Provider<TransactionsRepository>((ref) {
  final ds = ref.watch(transactionsDataSourceProvider);
  return TransactionsRepositoryImpl(ds);
});
