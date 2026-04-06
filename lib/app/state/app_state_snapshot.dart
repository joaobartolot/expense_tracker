import 'package:expense_tracker/features/accounts/domain/models/account.dart';
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
  });

  const ActivitySummary.empty() : income = 0, expenses = 0, netMovement = 0;

  final double income;
  final double expenses;
  final double netMovement;
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
    required this.globalBalance,
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
      globalBalance: 0,
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
  final double globalBalance;
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
        accountsById[accountId]?.balance ??
        0;
  }

  List<TransactionItem> transactionsForCategory(String categoryId) {
    return transactions
        .where((transaction) => transaction.categoryId == categoryId)
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
    double? globalBalance,
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
      globalBalance: globalBalance ?? this.globalBalance,
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
