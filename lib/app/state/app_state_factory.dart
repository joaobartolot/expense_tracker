import 'package:expense_tracker/app/state/app_state_snapshot.dart';
import 'package:expense_tracker/core/utils/currency_conversion_service.dart';
import 'package:expense_tracker/features/accounts/domain/models/account.dart';
import 'package:expense_tracker/features/accounts/domain/models/credit_card_account_state.dart';
import 'package:expense_tracker/features/accounts/domain/services/balance_overview_service.dart';
import 'package:expense_tracker/features/accounts/domain/services/credit_card_overview_service.dart';
import 'package:expense_tracker/features/categories/domain/models/category_item.dart';
import 'package:expense_tracker/features/recurring_transactions/domain/models/recurring_transaction.dart';
import 'package:expense_tracker/features/recurring_transactions/domain/models/recurring_transaction_overview.dart';
import 'package:expense_tracker/features/recurring_transactions/domain/services/recurring_schedule_service.dart';
import 'package:expense_tracker/features/settings/domain/models/app_settings.dart';
import 'package:expense_tracker/features/transactions/domain/models/transaction_item.dart';
import 'package:expense_tracker/features/transactions/domain/services/transaction_aggregation_service.dart';

class AppStateFactory {
  const AppStateFactory({
    required BalanceOverviewService balanceOverviewService,
    required CreditCardOverviewService creditCardOverviewService,
    required CurrencyConversionService currencyConversionService,
    required TransactionAggregationService transactionAggregationService,
    required RecurringScheduleService recurringScheduleService,
  }) : _balanceOverviewService = balanceOverviewService,
       _creditCardOverviewService = creditCardOverviewService,
       _currencyConversionService = currencyConversionService,
       _transactionAggregationService = transactionAggregationService,
       _recurringScheduleService = recurringScheduleService;

  final BalanceOverviewService _balanceOverviewService;
  final CreditCardOverviewService _creditCardOverviewService;
  final CurrencyConversionService _currencyConversionService;
  final TransactionAggregationService _transactionAggregationService;
  final RecurringScheduleService _recurringScheduleService;

  Future<AppStateSnapshot> buildSnapshot({
    required AppStateSnapshot previous,
    required AppSettings settings,
    required List<Account> accounts,
    required List<CategoryItem> categories,
    required List<TransactionItem> transactions,
    required List<RecurringTransaction> recurringTransactions,
    DateTime? now,
  }) async {
    final currentDate = now ?? DateTime.now();
    final selectedPeriod = _resolveSelectedPeriod(
      previous: previous,
      settings: settings,
      currentDate: currentDate,
    );
    final accountSelectedPeriods = _resolveAccountSelectedPeriods(
      previous: previous,
      settings: settings,
      accounts: accounts,
      currentDate: currentDate,
    );
    final accountsById = {for (final account in accounts) account.id: account};
    final categoriesById = {
      for (final category in categories) category.id: category,
    };
    final effectiveBalances = _balanceOverviewService
        .calculateEffectiveBalances(
          accounts: accounts,
          transactions: transactions,
        );
    final baseCurrencyCode = settings.defaultCurrencyCode;
    final currentRates = await _currencyConversionService.latestRatesToCurrency(
      fromCurrencyCodes: {
        baseCurrencyCode,
        ...accounts.map((account) => account.currencyCode),
        ...transactions.map((transaction) => transaction.currencyCode),
      },
      toCurrencyCode: baseCurrencyCode,
      date: currentDate,
    );
    final balanceOverview = await _balanceOverviewService
        .calculateBalanceOverview(
          accounts: accounts,
          effectiveBalances: effectiveBalances,
          baseCurrencyCode: baseCurrencyCode,
          currentRates: currentRates,
        );
    final transactionAggregation = await _transactionAggregationService
        .buildAggregation(
          transactions: transactions,
          baseCurrencyCode: baseCurrencyCode,
          currentRates: currentRates,
        );
    final periodTransactions = transactions
        .where((transaction) => selectedPeriod.contains(transaction.date))
        .toList(growable: false);
    final creditCardStates = _creditCardOverviewService.buildStates(
      accounts: accounts,
      effectiveBalances: effectiveBalances,
      transactions: transactions,
      now: currentDate,
    );
    final accountOverviews = _buildAccountOverviews(
      accounts: accounts,
      transactions: transactions,
      effectiveBalances: effectiveBalances,
      creditCardStates: creditCardStates,
      accountSelectedPeriods: accountSelectedPeriods,
    );
    final recurringTransactionOverviews = _buildRecurringTransactionOverviews(
      recurringTransactions,
      now: currentDate,
    );

    return AppStateSnapshot(
      hasLoaded: previous.hasLoaded,
      isLoading: previous.isLoading,
      loadError: previous.loadError,
      settings: settings,
      accounts: accounts,
      categories: categories,
      transactions: transactions,
      recurringTransactions: recurringTransactions,
      accountsById: accountsById,
      categoriesById: categoriesById,
      effectiveBalances: effectiveBalances,
      convertedTransactionAmounts: transactionAggregation.convertedAmounts,
      missingConvertedTransactionIds:
          transactionAggregation.missingTransactionIds,
      globalBalance: balanceOverview.totalBalance,
      missingGlobalBalanceConversionCount:
          balanceOverview.missingAccountIds.length,
      asOfDate: currentDate,
      creditCardStates: creditCardStates,
      selectedPeriod: selectedPeriod,
      periodTransactions: periodTransactions,
      periodSummary: _buildActivitySummary(
        periodTransactions,
        convertedTransactionAmounts: transactionAggregation.convertedAmounts,
        missingTransactionIds: transactionAggregation.missingTransactionIds,
      ),
      accountSelectedPeriods: accountSelectedPeriods,
      accountOverviews: accountOverviews,
      historyFilter: previous.historyFilter,
      historySort: previous.historySort,
      historySearchQuery: previous.historySearchQuery,
      historyTransactions: _buildHistoryTransactions(
        transactions: transactions,
        categoriesById: categoriesById,
        accountsById: accountsById,
        filter: previous.historyFilter,
        sort: previous.historySort,
        query: previous.historySearchQuery,
      ),
      recurringTransactionOverviews: recurringTransactionOverviews,
    );
  }

  AppStateSnapshot rebuildDerivedState(
    AppStateSnapshot current, {
    SelectedPeriod? selectedPeriod,
    Map<String, SelectedPeriod>? accountSelectedPeriods,
    TransactionHistoryFilter? historyFilter,
    TransactionHistorySort? historySort,
    String? historySearchQuery,
  }) {
    final nextPeriod = selectedPeriod ?? current.selectedPeriod;
    final nextAccountSelectedPeriods =
        accountSelectedPeriods ?? current.accountSelectedPeriods;
    final nextFilter = historyFilter ?? current.historyFilter;
    final nextSort = historySort ?? current.historySort;
    final nextQuery = historySearchQuery ?? current.historySearchQuery;
    final periodTransactions = current.transactions
        .where((transaction) => nextPeriod.contains(transaction.date))
        .toList(growable: false);

    return current.copyWith(
      selectedPeriod: nextPeriod,
      periodTransactions: periodTransactions,
      periodSummary: _buildActivitySummary(
        periodTransactions,
        convertedTransactionAmounts: current.convertedTransactionAmounts,
        missingTransactionIds: current.missingConvertedTransactionIds,
      ),
      accountSelectedPeriods: nextAccountSelectedPeriods,
      accountOverviews: _buildAccountOverviews(
        accounts: current.accounts,
        transactions: current.transactions,
        effectiveBalances: current.effectiveBalances,
        creditCardStates: current.creditCardStates,
        accountSelectedPeriods: nextAccountSelectedPeriods,
      ),
      historyFilter: nextFilter,
      historySort: nextSort,
      historySearchQuery: nextQuery,
      historyTransactions: _buildHistoryTransactions(
        transactions: current.transactions,
        categoriesById: current.categoriesById,
        accountsById: current.accountsById,
        filter: nextFilter,
        sort: nextSort,
        query: nextQuery,
      ),
      recurringTransactionOverviews: _buildRecurringTransactionOverviews(
        current.recurringTransactions,
        now: current.asOfDate,
      ),
    );
  }

  List<RecurringTransactionOverview> _buildRecurringTransactionOverviews(
    List<RecurringTransaction> recurringTransactions, {
    required DateTime now,
  }) {
    final overviews = recurringTransactions
        .map(
          (transaction) =>
              _recurringScheduleService.buildOverview(transaction, now: now),
        )
        .toList(growable: false);

    final sortedOverviews = [...overviews]
      ..sort((left, right) {
        final leftDate = left.nextDueDate;
        final rightDate = right.nextDueDate;
        if (leftDate == null && rightDate == null) {
          return left.recurringTransaction.title.compareTo(
            right.recurringTransaction.title,
          );
        }
        if (leftDate == null) {
          return 1;
        }
        if (rightDate == null) {
          return -1;
        }

        final dateComparison = leftDate.compareTo(rightDate);
        if (dateComparison != 0) {
          return dateComparison;
        }

        return left.recurringTransaction.title.compareTo(
          right.recurringTransaction.title,
        );
      });

    return sortedOverviews;
  }

  Map<String, SelectedPeriod> _resolveAccountSelectedPeriods({
    required AppStateSnapshot previous,
    required AppSettings settings,
    required List<Account> accounts,
    required DateTime currentDate,
  }) {
    final currentPeriod = SelectedPeriod.containing(
      date: currentDate,
      financialCycleDay: settings.financialCycleDay,
    );
    final nextPeriods = <String, SelectedPeriod>{};

    for (final account in accounts) {
      final previousPeriod = previous.accountSelectedPeriods[account.id];
      nextPeriods[account.id] = previous.hasLoaded && previousPeriod != null
          ? SelectedPeriod.containing(
              date: previousPeriod.start,
              financialCycleDay: settings.financialCycleDay,
            )
          : currentPeriod;
    }

    return nextPeriods;
  }

  SelectedPeriod _resolveSelectedPeriod({
    required AppStateSnapshot previous,
    required AppSettings settings,
    required DateTime currentDate,
  }) {
    final currentPeriod = SelectedPeriod.containing(
      date: currentDate,
      financialCycleDay: settings.financialCycleDay,
    );
    if (!previous.hasLoaded) {
      return currentPeriod;
    }

    return SelectedPeriod.containing(
      date: previous.selectedPeriod.start,
      financialCycleDay: settings.financialCycleDay,
    );
  }

  ActivitySummary _buildActivitySummary(
    List<TransactionItem> transactions, {
    required Map<String, double> convertedTransactionAmounts,
    required Set<String> missingTransactionIds,
  }) {
    var income = 0.0;
    var expenses = 0.0;
    var missingConversionCount = 0;

    for (final transaction in transactions) {
      final amount = convertedTransactionAmounts[transaction.id];
      if (amount == null) {
        if (missingTransactionIds.contains(transaction.id)) {
          missingConversionCount += 1;
        }
        continue;
      }

      switch (transaction.type) {
        case TransactionType.income:
          income += amount;
          break;
        case TransactionType.expense:
          expenses += amount;
          break;
        case TransactionType.transfer:
          break;
      }
    }

    return ActivitySummary(
      income: income,
      expenses: expenses,
      netMovement: income - expenses,
      missingConversionCount: missingConversionCount,
    );
  }

  Map<String, AccountOverview> _buildAccountOverviews({
    required List<Account> accounts,
    required List<TransactionItem> transactions,
    required Map<String, double> effectiveBalances,
    required Map<String, CreditCardAccountState> creditCardStates,
    required Map<String, SelectedPeriod> accountSelectedPeriods,
  }) {
    final overviews = <String, AccountOverview>{};

    for (final account in accounts) {
      final selectedPeriod = accountSelectedPeriods[account.id];
      if (selectedPeriod == null) {
        continue;
      }

      final allTransactions = transactions
          .where(
            (transaction) => transaction.linkedAccountIds.contains(account.id),
          )
          .toList(growable: false);
      final sortedTransactions = [...allTransactions]
        ..sort((a, b) => b.date.compareTo(a.date));
      final periodTransactions = sortedTransactions
          .where((transaction) => selectedPeriod.contains(transaction.date))
          .toList(growable: false);

      overviews[account.id] = AccountOverview(
        account: account,
        balance: effectiveBalances[account.id] ?? account.openingBalance,
        creditCardState: creditCardStates[account.id],
        selectedPeriod: selectedPeriod,
        periodSummary: _buildAccountActivitySummary(
          accountId: account.id,
          transactions: periodTransactions,
        ),
        periodTransferSummary: _buildAccountTransferSummary(
          accountId: account.id,
          transactions: periodTransactions,
        ),
        periodTransactions: periodTransactions,
        allTransactions: sortedTransactions,
      );
    }

    return overviews;
  }

  ActivitySummary _buildAccountActivitySummary({
    required String accountId,
    required List<TransactionItem> transactions,
  }) {
    var income = 0.0;
    var expenses = 0.0;

    for (final transaction in transactions) {
      if (transaction.accountId != accountId) {
        continue;
      }

      switch (transaction.type) {
        case TransactionType.income:
          income += transaction.amount;
          break;
        case TransactionType.expense:
          expenses += transaction.amount;
          break;
        case TransactionType.transfer:
          break;
      }
    }

    return ActivitySummary(
      income: income,
      expenses: expenses,
      netMovement: income - expenses,
      missingConversionCount: 0,
    );
  }

  AccountTransferSummary _buildAccountTransferSummary({
    required String accountId,
    required List<TransactionItem> transactions,
  }) {
    var incoming = 0.0;
    var outgoing = 0.0;
    var transferCount = 0;

    for (final transaction in transactions) {
      if (!transaction.isTransfer) {
        continue;
      }

      final isOutgoing = transaction.sourceAccountId == accountId;
      final isIncoming = transaction.destinationAccountId == accountId;
      if (!isOutgoing && !isIncoming) {
        continue;
      }

      transferCount += 1;

      if (isOutgoing) {
        outgoing += transaction.amount;
      }
      if (isIncoming) {
        incoming += transaction.destinationAmount ?? transaction.amount;
      }
    }

    return AccountTransferSummary(
      incoming: incoming,
      outgoing: outgoing,
      netMovement: incoming - outgoing,
      transferCount: transferCount,
    );
  }

  List<TransactionItem> _buildHistoryTransactions({
    required List<TransactionItem> transactions,
    required Map<String, CategoryItem> categoriesById,
    required Map<String, Account> accountsById,
    required TransactionHistoryFilter filter,
    required TransactionHistorySort sort,
    required String query,
  }) {
    final filtered = transactions
        .where((transaction) {
          final matchesFilter = switch (filter) {
            TransactionHistoryFilter.all => true,
            TransactionHistoryFilter.income =>
              transaction.type == TransactionType.income,
            TransactionHistoryFilter.expense =>
              transaction.type == TransactionType.expense,
            TransactionHistoryFilter.transfer =>
              transaction.type == TransactionType.transfer,
          };

          if (!matchesFilter) {
            return false;
          }

          if (query.isEmpty) {
            return true;
          }

          final category = categoriesById[transaction.categoryId];
          final account = accountsById[transaction.primaryAccountId];
          final destinationAccount =
              accountsById[transaction.secondaryAccountId];
          final searchableText = [
            transaction.title,
            category?.name,
            category?.description,
            account?.name,
            account?.description,
            destinationAccount?.name,
            destinationAccount?.description,
          ].whereType<String>().join(' ').toLowerCase();

          return searchableText.contains(query);
        })
        .toList(growable: false);

    final sorted = [...filtered]
      ..sort((a, b) {
        final comparison = a.date.compareTo(b.date);
        return sort == TransactionHistorySort.oldestFirst
            ? comparison
            : -comparison;
      });

    return sorted;
  }
}
