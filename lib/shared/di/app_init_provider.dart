import 'package:expense_tracker/features/transactions/data/datasources/transactions_data_source.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers.dart';

final appInitProvider = FutureProvider<void>((ref) async {
  final TransactionsDataSource ds = ref.read(transactionsDataSourceProvider);
  await ds.init();
});
