import 'package:expense_tracker/core/utils/financial_period.dart';
import 'package:expense_tracker/features/accounts/domain/models/account.dart';
import 'package:expense_tracker/features/accounts/domain/models/credit_card_account_state.dart';
import 'package:expense_tracker/features/categories/domain/models/category_item.dart';
import 'package:expense_tracker/features/recurring_transactions/domain/models/recurring_transaction.dart';
import 'package:expense_tracker/features/recurring_transactions/domain/models/recurring_transaction_overview.dart';
import 'package:expense_tracker/features/settings/domain/models/app_settings.dart';
import 'package:expense_tracker/features/transactions/domain/models/transaction_item.dart';

enum TransactionHistorySort { newestFirst, oldestFirst }

enum TransactionHistoryFilter { all, income, expense, transfer }

class SelectedPeriod {
  const SelectedPeriod({
    required this.start,
    required this.end,
    required this.financialCycleDay,
  });

  factory SelectedPeriod.containing({
    required DateTime date,
    required int financialCycleDay,
  }) {
    final period = FinancialPeriod.containing(
      date: date,
      financialCycleDay: financialCycleDay,
    );
    return SelectedPeriod(
      start: period.start,
      end: period.end,
      financialCycleDay: period.financialCycleDay,
    );
  }

  final DateTime start;
  final DateTime end;
  final int financialCycleDay;

  DateTime get inclusiveEnd => end.subtract(const Duration(days: 1));

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

class AccountTransferSummary {
  const AccountTransferSummary({
    required this.incoming,
    required this.outgoing,
    required this.netMovement,
    required this.transferCount,
  });

  const AccountTransferSummary.empty()
    : incoming = 0,
      outgoing = 0,
      netMovement = 0,
      transferCount = 0;

  final double incoming;
  final double outgoing;
  final double netMovement;
  final int transferCount;
}

class AccountOverview {
  const AccountOverview({
    required this.account,
    required this.balance,
    required this.creditCardState,
    required this.selectedPeriod,
    required this.periodSummary,
    required this.periodTransferSummary,
    required this.periodTransactions,
    required this.allTransactions,
  });

  final Account account;
  final double balance;
  final CreditCardAccountState? creditCardState;
  final SelectedPeriod selectedPeriod;
  final ActivitySummary periodSummary;
  final AccountTransferSummary periodTransferSummary;
  final List<TransactionItem> periodTransactions;
  final List<TransactionItem> allTransactions;
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
    required this.recurringTransactions,
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
    required this.accountSelectedPeriods,
    required this.accountOverviews,
    required this.historyFilter,
    required this.historySort,
    required this.historySearchQuery,
    required this.historyTransactions,
    required this.recurringTransactionOverviews,
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
      recurringTransactions: const [],
      accountsById: const {},
      categoriesById: const {},
      effectiveBalances: const {},
      convertedTransactionAmounts: const {},
      missingConvertedTransactionIds: const <String>{},
      globalBalance: 0,
      missingGlobalBalanceConversionCount: 0,
      asOfDate: DateTime.now(),
      creditCardStates: const {},
      selectedPeriod: SelectedPeriod.containing(
        date: DateTime.now(),
        financialCycleDay: settings.financialCycleDay,
      ),
      periodTransactions: const [],
      periodSummary: const ActivitySummary.empty(),
      accountSelectedPeriods: const {},
      accountOverviews: const {},
      historyFilter: TransactionHistoryFilter.all,
      historySort: TransactionHistorySort.newestFirst,
      historySearchQuery: '',
      historyTransactions: const [],
      recurringTransactionOverviews: const [],
    );
  }

  final bool hasLoaded;
  final bool isLoading;
  final Object? loadError;
  final AppSettings settings;
  final List<Account> accounts;
  final List<CategoryItem> categories;
  final List<TransactionItem> transactions;
  final List<RecurringTransaction> recurringTransactions;
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
  final Map<String, SelectedPeriod> accountSelectedPeriods;
  final Map<String, AccountOverview> accountOverviews;
  final TransactionHistoryFilter historyFilter;
  final TransactionHistorySort historySort;
  final String historySearchQuery;
  final List<TransactionItem> historyTransactions;
  final List<RecurringTransactionOverview> recurringTransactionOverviews;

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

  TransactionItem? transactionById(String transactionId) {
    for (final transaction in transactions) {
      if (transaction.id == transactionId) {
        return transaction;
      }
    }

    return null;
  }

  double balanceForAccount(String accountId) {
    return effectiveBalances[accountId] ??
        accountsById[accountId]?.openingBalance ??
        0;
  }

  CreditCardAccountState? creditCardStateForAccount(String accountId) {
    return creditCardStates[accountId];
  }

  SelectedPeriod selectedPeriodForAccount(String accountId) {
    return accountSelectedPeriods[accountId] ?? selectedPeriod;
  }

  AccountOverview? accountOverviewFor(String accountId) {
    return accountOverviews[accountId];
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

  bool hasLinkedRecurringTransactionsForAccount(String accountId) {
    return recurringTransactions.any(
      (transaction) =>
          transaction.accountId == accountId ||
          transaction.sourceAccountId == accountId ||
          transaction.destinationAccountId == accountId,
    );
  }

  bool hasLinkedTransactionsForCategory(String categoryId) {
    return transactions.any(
      (transaction) => transaction.categoryId == categoryId,
    );
  }

  bool hasLinkedRecurringTransactionsForCategory(String categoryId) {
    return recurringTransactions.any(
      (transaction) => transaction.categoryId == categoryId,
    );
  }

  RecurringTransaction? recurringTransactionById(
    String recurringTransactionId,
  ) {
    for (final recurringTransaction in recurringTransactions) {
      if (recurringTransaction.id == recurringTransactionId) {
        return recurringTransaction;
      }
    }

    return null;
  }

  AppStateSnapshot copyWith({
    bool? hasLoaded,
    bool? isLoading,
    Object? loadError = _sentinel,
    AppSettings? settings,
    List<Account>? accounts,
    List<CategoryItem>? categories,
    List<TransactionItem>? transactions,
    List<RecurringTransaction>? recurringTransactions,
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
    Map<String, SelectedPeriod>? accountSelectedPeriods,
    Map<String, AccountOverview>? accountOverviews,
    TransactionHistoryFilter? historyFilter,
    TransactionHistorySort? historySort,
    String? historySearchQuery,
    List<TransactionItem>? historyTransactions,
    List<RecurringTransactionOverview>? recurringTransactionOverviews,
  }) {
    return AppStateSnapshot(
      hasLoaded: hasLoaded ?? this.hasLoaded,
      isLoading: isLoading ?? this.isLoading,
      loadError: identical(loadError, _sentinel) ? this.loadError : loadError,
      settings: settings ?? this.settings,
      accounts: accounts ?? this.accounts,
      categories: categories ?? this.categories,
      transactions: transactions ?? this.transactions,
      recurringTransactions:
          recurringTransactions ?? this.recurringTransactions,
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
      accountSelectedPeriods:
          accountSelectedPeriods ?? this.accountSelectedPeriods,
      accountOverviews: accountOverviews ?? this.accountOverviews,
      historyFilter: historyFilter ?? this.historyFilter,
      historySort: historySort ?? this.historySort,
      historySearchQuery: historySearchQuery ?? this.historySearchQuery,
      historyTransactions: historyTransactions ?? this.historyTransactions,
      recurringTransactionOverviews:
          recurringTransactionOverviews ?? this.recurringTransactionOverviews,
    );
  }
}

const _sentinel = Object();
