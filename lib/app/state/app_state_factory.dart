import 'package:expense_tracker/app/state/app_state_snapshot.dart';
import 'package:expense_tracker/features/accounts/domain/models/account.dart';
import 'package:expense_tracker/features/accounts/domain/services/balance_overview_service.dart';
import 'package:expense_tracker/features/categories/domain/models/category_item.dart';
import 'package:expense_tracker/features/settings/domain/models/app_settings.dart';
import 'package:expense_tracker/features/transactions/domain/models/transaction_item.dart';

class AppStateFactory {
  const AppStateFactory({
    required BalanceOverviewService balanceOverviewService,
  }) : _balanceOverviewService = balanceOverviewService;

  final BalanceOverviewService _balanceOverviewService;

  AppStateSnapshot buildSnapshot({
    required AppStateSnapshot previous,
    required AppSettings settings,
    required List<Account> accounts,
    required List<CategoryItem> categories,
    required List<TransactionItem> transactions,
  }) {
    final accountsById = {for (final account in accounts) account.id: account};
    final categoriesById = {
      for (final category in categories) category.id: category,
    };
    final effectiveBalances = _balanceOverviewService
        .calculateEffectiveBalances(
          accounts: accounts,
          transactions: transactions,
        );
    final periodTransactions = transactions
        .where(
          (transaction) => previous.selectedPeriod.contains(transaction.date),
        )
        .toList(growable: false);

    return AppStateSnapshot(
      hasLoaded: previous.hasLoaded,
      isLoading: previous.isLoading,
      loadError: previous.loadError,
      settings: settings,
      accounts: accounts,
      categories: categories,
      transactions: transactions,
      accountsById: accountsById,
      categoriesById: categoriesById,
      effectiveBalances: effectiveBalances,
      globalBalance: _balanceOverviewService.calculateGlobalBalanceFromBalances(
        effectiveBalances,
      ),
      selectedPeriod: previous.selectedPeriod,
      periodTransactions: periodTransactions,
      periodSummary: _buildActivitySummary(periodTransactions),
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
    );
  }

  AppStateSnapshot rebuildDerivedState(
    AppStateSnapshot current, {
    SelectedPeriod? selectedPeriod,
    TransactionHistoryFilter? historyFilter,
    TransactionHistorySort? historySort,
    String? historySearchQuery,
  }) {
    final nextPeriod = selectedPeriod ?? current.selectedPeriod;
    final nextFilter = historyFilter ?? current.historyFilter;
    final nextSort = historySort ?? current.historySort;
    final nextQuery = historySearchQuery ?? current.historySearchQuery;
    final periodTransactions = current.transactions
        .where((transaction) => nextPeriod.contains(transaction.date))
        .toList(growable: false);

    return current.copyWith(
      selectedPeriod: nextPeriod,
      periodTransactions: periodTransactions,
      periodSummary: _buildActivitySummary(periodTransactions),
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
    );
  }

  ActivitySummary _buildActivitySummary(List<TransactionItem> transactions) {
    var income = 0.0;
    var expenses = 0.0;

    for (final transaction in transactions) {
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
          final account =
              accountsById[transaction.accountId ??
                  transaction.sourceAccountId];
          final destinationAccount =
              accountsById[transaction.destinationAccountId];
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
