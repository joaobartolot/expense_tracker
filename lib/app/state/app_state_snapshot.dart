import 'package:expense_tracker/features/accounts/domain/models/account.dart';
import 'package:expense_tracker/features/accounts/domain/models/credit_card_account_state.dart';
import 'package:expense_tracker/features/categories/domain/models/category_item.dart';
import 'package:expense_tracker/features/settings/domain/models/app_settings.dart';
import 'package:expense_tracker/features/transactions/domain/models/transaction_item.dart';

enum TransactionHistorySort { newestFirst, oldestFirst }

enum TransactionHistoryFilter { all, income, expense, transfer }

class SelectedPeriod {
  const SelectedPeriod({required this.start, required this.end});

  factory SelectedPeriod.monthContaining(DateTime date) {
    final normalized = DateTime(date.year, date.month);
    return SelectedPeriod(
      start: normalized,
      end: DateTime(normalized.year, normalized.month + 1),
    );
  }

  final DateTime start;
  final DateTime end;

  bool contains(DateTime value) {
    return !value.isBefore(start) && value.isBefore(end);
  }
}

class ActivitySummary {
  const ActivitySummary({
    required this.income,
    required this.expenses,
    required this.netMovement,
    required this.missingConversionCount,
  });

  const ActivitySummary.empty()
    : income = 0,
      expenses = 0,
      netMovement = 0,
      missingConversionCount = 0;

  final double income;
  final double expenses;
  final double netMovement;
  final int missingConversionCount;
}

class AppStateSnapshot {
  const AppStateSnapshot({
    required this.hasLoaded,
    required this.isLoading,
    required this.loadError,
    required this.settings,
    required this.accounts,
    required this.categories,
    required this.transactions,
    required this.accountsById,
    required this.categoriesById,
    required this.effectiveBalances,
    required this.convertedTransactionAmounts,
    required this.missingConvertedTransactionIds,
    required this.globalBalance,
    required this.missingGlobalBalanceConversionCount,
    required this.asOfDate,
    required this.creditCardStates,
    required this.selectedPeriod,
    required this.periodTransactions,
    required this.periodSummary,
    required this.historyFilter,
    required this.historySort,
    required this.historySearchQuery,
    required this.historyTransactions,
  });

  factory AppStateSnapshot.initial({required AppSettings settings}) {
    return AppStateSnapshot(
      hasLoaded: false,
      isLoading: true,
      loadError: null,
      settings: settings,
      accounts: const [],
      categories: const [],
      transactions: const [],
      accountsById: const {},
      categoriesById: const {},
      effectiveBalances: const {},
      convertedTransactionAmounts: const {},
      missingConvertedTransactionIds: const <String>{},
      globalBalance: 0,
      missingGlobalBalanceConversionCount: 0,
      asOfDate: DateTime.now(),
      creditCardStates: const {},
      selectedPeriod: SelectedPeriod.monthContaining(DateTime.now()),
      periodTransactions: const [],
      periodSummary: const ActivitySummary.empty(),
      historyFilter: TransactionHistoryFilter.all,
      historySort: TransactionHistorySort.newestFirst,
      historySearchQuery: '',
      historyTransactions: const [],
    );
  }

  final bool hasLoaded;
  final bool isLoading;
  final Object? loadError;
  final AppSettings settings;
  final List<Account> accounts;
  final List<CategoryItem> categories;
  final List<TransactionItem> transactions;
  final Map<String, Account> accountsById;
  final Map<String, CategoryItem> categoriesById;
  final Map<String, double> effectiveBalances;
  final Map<String, double> convertedTransactionAmounts;
  final Set<String> missingConvertedTransactionIds;
  final double globalBalance;
  final int missingGlobalBalanceConversionCount;
  final DateTime asOfDate;
  final Map<String, CreditCardAccountState> creditCardStates;
  final SelectedPeriod selectedPeriod;
  final List<TransactionItem> periodTransactions;
  final ActivitySummary periodSummary;
  final TransactionHistoryFilter historyFilter;
  final TransactionHistorySort historySort;
  final String historySearchQuery;
  final List<TransactionItem> historyTransactions;

  List<CategoryItem> get incomeCategories {
    return categories
        .where((category) => category.type == CategoryType.income)
        .toList(growable: false);
  }

  List<CategoryItem> get expenseCategories {
    return categories
        .where((category) => category.type == CategoryType.expense)
        .toList(growable: false);
  }

  Account? accountById(String? accountId) {
    if (accountId == null) {
      return null;
    }

    return accountsById[accountId];
  }

  CategoryItem? categoryById(String? categoryId) {
    if (categoryId == null) {
      return null;
    }

    return categoriesById[categoryId];
  }

  double balanceForAccount(String accountId) {
    return effectiveBalances[accountId] ??
        accountsById[accountId]?.openingBalance ??
        0;
  }

  CreditCardAccountState? creditCardStateForAccount(String accountId) {
    return creditCardStates[accountId];
  }

  double? convertedAmountForTransaction(String transactionId) {
    return convertedTransactionAmounts[transactionId];
  }

  double totalForTransactions(Iterable<TransactionItem> transactions) {
    var total = 0.0;

    for (final transaction in transactions) {
      final convertedAmount = convertedAmountForTransaction(transaction.id);
      if (convertedAmount == null) {
        continue;
      }
      total += convertedAmount;
    }

    return total;
  }

  int missingConversionCountForTransactions(
    Iterable<TransactionItem> transactions,
  ) {
    var count = 0;

    for (final transaction in transactions) {
      if (missingConvertedTransactionIds.contains(transaction.id)) {
        count += 1;
      }
    }

    return count;
  }

  List<TransactionItem> transactionsForCategory(String categoryId) {
    return transactions
        .where((transaction) => transaction.categoryId == categoryId)
        .toList(growable: false);
  }

  List<TransactionItem> transactionsForAccount(String accountId) {
    return transactions
        .where(
          (transaction) => transaction.linkedAccountIds.contains(accountId),
        )
        .toList(growable: false);
  }

  bool hasLinkedTransactionsForAccount(String accountId) {
    return transactions.any(
      (transaction) => transaction.linkedAccountIds.contains(accountId),
    );
  }

  bool hasLinkedTransactionsForCategory(String categoryId) {
    return transactions.any(
      (transaction) => transaction.categoryId == categoryId,
    );
  }

  AppStateSnapshot copyWith({
    bool? hasLoaded,
    bool? isLoading,
    Object? loadError = _sentinel,
    AppSettings? settings,
    List<Account>? accounts,
    List<CategoryItem>? categories,
    List<TransactionItem>? transactions,
    Map<String, Account>? accountsById,
    Map<String, CategoryItem>? categoriesById,
    Map<String, double>? effectiveBalances,
    Map<String, double>? convertedTransactionAmounts,
    Set<String>? missingConvertedTransactionIds,
    double? globalBalance,
    int? missingGlobalBalanceConversionCount,
    DateTime? asOfDate,
    Map<String, CreditCardAccountState>? creditCardStates,
    SelectedPeriod? selectedPeriod,
    List<TransactionItem>? periodTransactions,
    ActivitySummary? periodSummary,
    TransactionHistoryFilter? historyFilter,
    TransactionHistorySort? historySort,
    String? historySearchQuery,
    List<TransactionItem>? historyTransactions,
  }) {
    return AppStateSnapshot(
      hasLoaded: hasLoaded ?? this.hasLoaded,
      isLoading: isLoading ?? this.isLoading,
      loadError: identical(loadError, _sentinel) ? this.loadError : loadError,
      settings: settings ?? this.settings,
      accounts: accounts ?? this.accounts,
      categories: categories ?? this.categories,
      transactions: transactions ?? this.transactions,
      accountsById: accountsById ?? this.accountsById,
      categoriesById: categoriesById ?? this.categoriesById,
      effectiveBalances: effectiveBalances ?? this.effectiveBalances,
      convertedTransactionAmounts:
          convertedTransactionAmounts ?? this.convertedTransactionAmounts,
      missingConvertedTransactionIds:
          missingConvertedTransactionIds ?? this.missingConvertedTransactionIds,
      globalBalance: globalBalance ?? this.globalBalance,
      missingGlobalBalanceConversionCount:
          missingGlobalBalanceConversionCount ??
          this.missingGlobalBalanceConversionCount,
      asOfDate: asOfDate ?? this.asOfDate,
      creditCardStates: creditCardStates ?? this.creditCardStates,
      selectedPeriod: selectedPeriod ?? this.selectedPeriod,
      periodTransactions: periodTransactions ?? this.periodTransactions,
      periodSummary: periodSummary ?? this.periodSummary,
      historyFilter: historyFilter ?? this.historyFilter,
      historySort: historySort ?? this.historySort,
      historySearchQuery: historySearchQuery ?? this.historySearchQuery,
      historyTransactions: historyTransactions ?? this.historyTransactions,
    );
  }
}

const _sentinel = Object();
