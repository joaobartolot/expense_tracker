import 'package:expense_tracker/features/accounts/data/account_repository.dart';
import 'package:expense_tracker/features/accounts/data/hive_account_repository.dart';
import 'package:expense_tracker/features/accounts/domain/services/balance_overview_service.dart';
import 'package:expense_tracker/features/categories/data/category_repository.dart';
import 'package:expense_tracker/features/categories/data/hive_category_repository.dart';
import 'package:expense_tracker/features/settings/data/hive_settings_repository.dart';
import 'package:expense_tracker/features/settings/data/settings_repository.dart';
import 'package:expense_tracker/features/transactions/data/hive_transaction_repository.dart';
import 'package:expense_tracker/features/transactions/data/transaction_repository.dart';
import 'package:expense_tracker/features/transactions/domain/services/transaction_balance_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  return HiveSettingsRepository();
});

final transactionRepositoryProvider = Provider<TransactionRepository>((ref) {
  return HiveTransactionRepository();
});

final categoryRepositoryProvider = Provider<CategoryRepository>((ref) {
  return HiveCategoryRepository();
});

final accountRepositoryProvider = Provider<AccountRepository>((ref) {
  return HiveAccountRepository();
});

final balanceOverviewServiceProvider = Provider<BalanceOverviewService>((ref) {
  return BalanceOverviewService(
    accountRepository: ref.watch(accountRepositoryProvider),
  );
});

final transactionBalanceServiceProvider = Provider<TransactionBalanceService>((
  ref,
) {
  return TransactionBalanceService(
    accountRepository: ref.watch(accountRepositoryProvider),
    transactionRepository: ref.watch(transactionRepositoryProvider),
  );
});
