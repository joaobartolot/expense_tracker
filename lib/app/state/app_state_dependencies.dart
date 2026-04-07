import 'package:expense_tracker/core/utils/currency_conversion_service.dart';
import 'package:expense_tracker/features/accounts/data/account_repository.dart';
import 'package:expense_tracker/features/accounts/data/hive_account_repository.dart';
import 'package:expense_tracker/features/accounts/domain/services/balance_overview_service.dart';
import 'package:expense_tracker/features/accounts/domain/services/credit_card_overview_service.dart';
import 'package:expense_tracker/features/categories/data/category_repository.dart';
import 'package:expense_tracker/features/categories/data/hive_category_repository.dart';
import 'package:expense_tracker/features/settings/data/hive_settings_repository.dart';
import 'package:expense_tracker/features/settings/data/settings_repository.dart';
import 'package:expense_tracker/features/recurring_transactions/data/hive_recurring_transaction_repository.dart';
import 'package:expense_tracker/features/recurring_transactions/data/recurring_transaction_repository.dart';
import 'package:expense_tracker/features/recurring_transactions/domain/services/recurring_schedule_service.dart';
import 'package:expense_tracker/features/recurring_transactions/domain/services/recurring_transaction_execution_service.dart';
import 'package:expense_tracker/features/transactions/data/exchange_rate_service.dart';
import 'package:expense_tracker/features/transactions/data/hive_transaction_repository.dart';
import 'package:expense_tracker/features/transactions/data/transaction_repository.dart';
import 'package:expense_tracker/features/transactions/domain/services/transaction_aggregation_service.dart';
import 'package:expense_tracker/features/transactions/domain/services/transaction_balance_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  return HiveSettingsRepository();
});

final transactionRepositoryProvider = Provider<TransactionRepository>((ref) {
  return HiveTransactionRepository();
});

final recurringTransactionRepositoryProvider =
    Provider<RecurringTransactionRepository>((ref) {
      return HiveRecurringTransactionRepository();
    });

final categoryRepositoryProvider = Provider<CategoryRepository>((ref) {
  return HiveCategoryRepository();
});

final accountRepositoryProvider = Provider<AccountRepository>((ref) {
  return HiveAccountRepository();
});

final exchangeRateServiceProvider = Provider<ExchangeRateService>((ref) {
  return const ExchangeRateService();
});

final currencyConversionServiceProvider = Provider<CurrencyConversionService>((
  ref,
) {
  return CurrencyConversionService(
    exchangeRateService: ref.watch(exchangeRateServiceProvider),
  );
});

final balanceOverviewServiceProvider = Provider<BalanceOverviewService>((ref) {
  return BalanceOverviewService(
    accountRepository: ref.watch(accountRepositoryProvider),
  );
});

final creditCardOverviewServiceProvider = Provider<CreditCardOverviewService>((
  ref,
) {
  return const CreditCardOverviewService();
});

final transactionAggregationServiceProvider =
    Provider<TransactionAggregationService>((ref) {
      return const TransactionAggregationService();
    });

final recurringScheduleServiceProvider = Provider<RecurringScheduleService>((
  ref,
) {
  return const RecurringScheduleService();
});

final transactionBalanceServiceProvider = Provider<TransactionBalanceService>((
  ref,
) {
  return TransactionBalanceService(
    currencyConversionService: ref.watch(currencyConversionServiceProvider),
    transactionRepository: ref.watch(transactionRepositoryProvider),
  );
});

final recurringTransactionExecutionServiceProvider =
    Provider<RecurringTransactionExecutionService>((ref) {
      return RecurringTransactionExecutionService(
        recurringScheduleService: ref.watch(recurringScheduleServiceProvider),
        recurringTransactionRepository: ref.watch(
          recurringTransactionRepositoryProvider,
        ),
        transactionBalanceService: ref.watch(transactionBalanceServiceProvider),
      );
    });
