import 'package:expense_tracker/app/state/app_state_factory.dart';
import 'package:expense_tracker/app/state/app_state_snapshot.dart';
import 'package:expense_tracker/core/utils/currency_conversion_service.dart';
import 'package:expense_tracker/features/accounts/data/account_repository.dart';
import 'package:expense_tracker/features/accounts/domain/models/account.dart';
import 'package:expense_tracker/features/accounts/domain/services/balance_overview_service.dart';
import 'package:expense_tracker/features/accounts/domain/services/credit_card_overview_service.dart';
import 'package:expense_tracker/features/categories/domain/models/category_item.dart';
import 'package:expense_tracker/features/recurring_transactions/domain/models/recurring_transaction.dart';
import 'package:expense_tracker/features/recurring_transactions/domain/services/recurring_schedule_service.dart';
import 'package:expense_tracker/features/settings/domain/models/app_settings.dart';
import 'package:expense_tracker/features/settings/domain/models/app_theme_preference.dart';
import 'package:expense_tracker/features/transactions/domain/models/transaction_item.dart';
import 'package:expense_tracker/features/transactions/domain/services/transaction_aggregation_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

void main() {
  late _FakeCurrencyConversionService currencyConversionService;
  late AppStateFactory factory;

  setUp(() {
    currencyConversionService = _FakeCurrencyConversionService();
    factory = AppStateFactory(
      balanceOverviewService: BalanceOverviewService(
        accountRepository: _NoopAccountRepository(),
      ),
      creditCardOverviewService: const CreditCardOverviewService(),
      currencyConversionService: currencyConversionService,
      transactionAggregationService: const TransactionAggregationService(),
      recurringScheduleService: const RecurringScheduleService(),
    );
  });

  Future<AppStateSnapshot> buildLoadedSnapshot() {
    return factory.buildSnapshot(
      previous: AppStateSnapshot.initial(
        settings: _settings(),
      ).copyWith(hasLoaded: true),
      settings: _settings(),
      accounts: _accounts(),
      categories: _categories(),
      transactions: _transactions(),
      recurringTransactions: _recurringTransactions(),
      now: DateTime(2026, 4, 20),
    );
  }

  group('buildSnapshot', () {
    test(
      'uses the current period when the previous snapshot has not loaded',
      () async {
        final settings = _settings(financialCycleDay: 5);
        final previous = AppStateSnapshot.initial(settings: settings);
        final now = DateTime(2026, 4, 20);

        final snapshot = await factory.buildSnapshot(
          previous: previous,
          settings: settings,
          accounts: _accounts(),
          categories: _categories(),
          transactions: _transactions(),
          recurringTransactions: _recurringTransactions(),
          now: now,
        );

        expect(snapshot.selectedPeriod.start, DateTime(2026, 4, 5));
        expect(snapshot.selectedPeriod.end, DateTime(2026, 5, 5));
        expect(
          snapshot.periodTransactions.map((transaction) => transaction.id),
          ['tx-income', 'tx-expense', 'tx-transfer', 'tx-missing'],
        );
      },
    );

    test(
      'preserves the previously selected period when rebuilding a loaded snapshot',
      () async {
        final settings = _settings(financialCycleDay: 5);
        final previous = AppStateSnapshot.initial(settings: settings).copyWith(
          hasLoaded: true,
          selectedPeriod: SelectedPeriod.containing(
            date: DateTime(2026, 3, 20),
            financialCycleDay: 5,
          ),
        );

        final snapshot = await factory.buildSnapshot(
          previous: previous,
          settings: settings,
          accounts: _accounts(),
          categories: _categories(),
          transactions: _transactions(),
          recurringTransactions: _recurringTransactions(),
          now: DateTime(2026, 4, 20),
        );

        expect(snapshot.selectedPeriod.start, DateTime(2026, 3, 5));
        expect(snapshot.selectedPeriod.end, DateTime(2026, 4, 5));
        expect(
          snapshot.periodTransactions.map((transaction) => transaction.id),
          ['tx-old-expense'],
        );
      },
    );

    test(
      'reanchors the preserved selected period when the financial cycle day changes',
      () async {
        final previousSettings = _settings(financialCycleDay: 5);
        final previous = AppStateSnapshot.initial(settings: previousSettings)
            .copyWith(
              hasLoaded: true,
              selectedPeriod: SelectedPeriod.containing(
                date: DateTime(2026, 3, 20),
                financialCycleDay: 5,
              ),
            );
        final nextSettings = _settings(financialCycleDay: 10);

        final snapshot = await factory.buildSnapshot(
          previous: previous,
          settings: nextSettings,
          accounts: _accounts(),
          categories: _categories(),
          transactions: _transactions(),
          recurringTransactions: _recurringTransactions(),
          now: DateTime(2026, 4, 20),
        );

        expect(snapshot.selectedPeriod.start, DateTime(2026, 2, 10));
        expect(snapshot.selectedPeriod.end, DateTime(2026, 3, 10));
      },
    );

    test(
      'preserves account-selected periods and gives new accounts the current period',
      () async {
        final settings = _settings(financialCycleDay: 5);
        final previous = AppStateSnapshot.initial(settings: settings).copyWith(
          hasLoaded: true,
          accountSelectedPeriods: {
            'account-eur': SelectedPeriod.containing(
              date: DateTime(2026, 3, 20),
              financialCycleDay: 5,
            ),
          },
        );

        final snapshot = await factory.buildSnapshot(
          previous: previous,
          settings: settings,
          accounts: [
            ..._accounts(),
            _account(id: 'account-new', name: 'New account'),
          ],
          categories: _categories(),
          transactions: _transactions(),
          recurringTransactions: _recurringTransactions(),
          now: DateTime(2026, 4, 20),
        );

        expect(
          snapshot.accountSelectedPeriods['account-eur']?.start,
          DateTime(2026, 3, 5),
        );
        expect(
          snapshot.accountSelectedPeriods['account-new']?.start,
          DateTime(2026, 4, 5),
        );
      },
    );

    test(
      'computes the period summary from converted amounts and missing conversions',
      () async {
        final snapshot = await factory.buildSnapshot(
          previous: AppStateSnapshot.initial(settings: _settings()),
          settings: _settings(),
          accounts: _accounts(),
          categories: _categories(),
          transactions: _transactions(),
          recurringTransactions: _recurringTransactions(),
          now: DateTime(2026, 4, 20),
        );

        expect(snapshot.periodSummary.income, 100);
        expect(snapshot.periodSummary.expenses, 40);
        expect(snapshot.periodSummary.netMovement, 60);
        expect(snapshot.periodSummary.missingConversionCount, 1);
      },
    );

    test(
      'builds account overviews with sorted transactions and transfer summaries',
      () async {
        final snapshot = await factory.buildSnapshot(
          previous: AppStateSnapshot.initial(settings: _settings()),
          settings: _settings(),
          accounts: _accounts(),
          categories: _categories(),
          transactions: _transactions(),
          recurringTransactions: _recurringTransactions(),
          now: DateTime(2026, 4, 20),
        );

        final eurOverview = snapshot.accountOverviewFor('account-eur');
        final usdOverview = snapshot.accountOverviewFor('account-usd');

        expect(eurOverview, isNotNull);
        expect(
          eurOverview!.allTransactions.map((transaction) => transaction.id),
          [
            'tx-missing',
            'tx-transfer',
            'tx-expense',
            'tx-income',
            'tx-old-expense',
          ],
        );
        expect(
          eurOverview.periodTransactions.map((transaction) => transaction.id),
          ['tx-missing', 'tx-transfer', 'tx-expense', 'tx-income'],
        );
        expect(eurOverview.periodSummary.income, 100);
        expect(eurOverview.periodSummary.expenses, 65);
        expect(eurOverview.periodTransferSummary.outgoing, 30);
        expect(eurOverview.periodTransferSummary.incoming, 0);
        expect(eurOverview.periodTransferSummary.transferCount, 1);

        expect(usdOverview, isNotNull);
        expect(usdOverview!.periodTransferSummary.incoming, 50);
        expect(usdOverview.periodTransferSummary.outgoing, 0);
        expect(usdOverview.periodTransferSummary.transferCount, 1);
      },
    );

    test(
      'builds history transactions from the previous filter sort and search query',
      () async {
        final previous = AppStateSnapshot.initial(settings: _settings())
            .copyWith(
              hasLoaded: true,
              historyFilter: TransactionHistoryFilter.transfer,
              historySort: TransactionHistorySort.oldestFirst,
              historySearchQuery: 'trip',
            );

        final snapshot = await factory.buildSnapshot(
          previous: previous,
          settings: _settings(),
          accounts: _accounts(),
          categories: _categories(),
          transactions: _transactions(),
          recurringTransactions: _recurringTransactions(),
          now: DateTime(2026, 4, 20),
        );

        expect(
          snapshot.historyTransactions.map((transaction) => transaction.id),
          ['tx-transfer'],
        );
      },
    );

    test(
      'exposes the missing global balance conversion count from the balance overview',
      () async {
        final snapshot = await factory.buildSnapshot(
          previous: AppStateSnapshot.initial(settings: _settings()),
          settings: _settings(),
          accounts: _accounts(),
          categories: _categories(),
          transactions: _transactions(),
          recurringTransactions: _recurringTransactions(),
          now: DateTime(2026, 4, 20),
        );

        expect(snapshot.globalBalance, closeTo(265, 0.0001));
        expect(snapshot.missingGlobalBalanceConversionCount, 1);
      },
    );
  });

  group('rebuildDerivedState', () {
    test(
      'updates the selected period and recomputes period transactions and summary',
      () async {
        final current = await buildLoadedSnapshot();

        final rebuilt = factory.rebuildDerivedState(
          current,
          selectedPeriod: SelectedPeriod.containing(
            date: DateTime(2026, 3, 20),
            financialCycleDay: current.settings.financialCycleDay,
          ),
        );

        expect(rebuilt.selectedPeriod.start, DateTime(2026, 3, 5));
        expect(
          rebuilt.periodTransactions.map((transaction) => transaction.id),
          ['tx-old-expense'],
        );
        expect(rebuilt.periodSummary.income, 0);
        expect(rebuilt.periodSummary.expenses, 15);
      },
    );

    test(
      'updates account-selected periods and recomputes account overviews',
      () async {
        final current = await buildLoadedSnapshot();

        final rebuilt = factory.rebuildDerivedState(
          current,
          accountSelectedPeriods: {
            ...current.accountSelectedPeriods,
            'account-eur': SelectedPeriod.containing(
              date: DateTime(2026, 3, 20),
              financialCycleDay: current.settings.financialCycleDay,
            ),
          },
        );

        final eurOverview = rebuilt.accountOverviewFor('account-eur');
        expect(eurOverview, isNotNull);
        expect(
          eurOverview!.periodTransactions.map((transaction) => transaction.id),
          ['tx-old-expense'],
        );
        expect(eurOverview.periodSummary.expenses, 15);
      },
    );

    test(
      'updates history filter sort and search without changing base snapshot data',
      () async {
        final current = await buildLoadedSnapshot();

        final rebuilt = factory.rebuildDerivedState(
          current,
          historyFilter: TransactionHistoryFilter.expense,
          historySort: TransactionHistorySort.oldestFirst,
          historySearchQuery: 'food',
        );

        expect(
          rebuilt.historyTransactions.map((transaction) => transaction.id),
          ['tx-old-expense', 'tx-expense', 'tx-missing'],
        );
        expect(rebuilt.transactions, same(current.transactions));
        expect(rebuilt.accounts, same(current.accounts));
        expect(rebuilt.categories, same(current.categories));
      },
    );

    test(
      'preserves the current as-of date while rebuilding recurring overviews',
      () async {
        final current = await buildLoadedSnapshot();

        final rebuilt = factory.rebuildDerivedState(
          current,
          historySearchQuery: 'salary',
        );

        expect(rebuilt.asOfDate, current.asOfDate);
        expect(
          rebuilt.recurringTransactionOverviews.map(
            (overview) => overview.recurringTransaction.id,
          ),
          ['recurring-income', 'recurring-transfer'],
        );
      },
    );
  });
}

class _FakeCurrencyConversionService implements CurrencyConversionService {
  _FakeCurrencyConversionService();

  @override
  Future<Map<String, double?>> latestRatesToCurrency({
    required Set<String> fromCurrencyCodes,
    required String toCurrencyCode,
    required DateTime date,
  }) async {
    final normalizedBase = toCurrencyCode.trim().toUpperCase();
    return {
      for (final currencyCode in fromCurrencyCodes)
        currencyCode.trim().toUpperCase(): switch (currencyCode
            .trim()
            .toUpperCase()) {
          'EUR' => 1,
          'USD' => 0.75,
          _ when currencyCode.trim().toUpperCase() == normalizedBase => 1,
          _ => null,
        },
    };
  }

  @override
  Future<double?> tryConvertAmount({
    required double amount,
    required String fromCurrencyCode,
    required String toCurrencyCode,
    required DateTime date,
  }) async {
    if (fromCurrencyCode.trim().toUpperCase() ==
        toCurrencyCode.trim().toUpperCase()) {
      return amount;
    }

    return null;
  }
}

class _NoopAccountRepository implements AccountRepository {
  final ValueNotifier<Box<dynamic>> _listenable = ValueNotifier(_FakeBox());

  @override
  Future<void> addAccount(Account account) async {}

  @override
  String createAccountId() => 'generated-account-id';

  @override
  Future<void> deleteAccount(String accountId) async {}

  @override
  Future<List<Account>> getAccounts() async => const [];

  @override
  ValueListenable<Box<dynamic>> listenable() => _listenable;

  @override
  Future<void> reorderAccounts(List<Account> accounts) async {}

  @override
  Future<void> updateAccount(Account account) async {}
}

class _FakeBox extends Fake implements Box<dynamic> {}

AppSettings _settings({
  int financialCycleDay = 5,
  String defaultCurrencyCode = 'EUR',
}) {
  return AppSettings(
    displayName: 'Vero',
    themePreference: AppThemePreference.system,
    defaultCurrencyCode: defaultCurrencyCode,
    financialCycleDay: financialCycleDay,
  );
}

List<Account> _accounts() {
  return [
    _account(
      id: 'account-eur',
      name: 'Main account',
      openingBalance: 200,
      currencyCode: 'EUR',
      description: 'Daily spending',
      isPrimary: true,
    ),
    _account(
      id: 'account-usd',
      name: 'Travel wallet',
      openingBalance: 50,
      currencyCode: 'USD',
      description: 'Trip savings',
    ),
    _account(
      id: 'account-jpy',
      name: 'JPY account',
      openingBalance: 1000,
      currencyCode: 'JPY',
      description: 'Unconverted balance',
    ),
  ];
}

Account _account({
  required String id,
  required String name,
  double openingBalance = 0,
  String currencyCode = 'EUR',
  String description = '',
  bool isPrimary = false,
}) {
  return Account(
    id: id,
    name: name,
    type: AccountType.bank,
    openingBalance: openingBalance,
    currencyCode: currencyCode,
    description: description,
    isPrimary: isPrimary,
  );
}

List<CategoryItem> _categories() {
  return [
    _category(
      id: 'income-category',
      name: 'Salary',
      description: 'Monthly salary',
      type: CategoryType.income,
    ),
    _category(
      id: 'expense-category',
      name: 'Food',
      description: 'Food spending',
      type: CategoryType.expense,
    ),
  ];
}

CategoryItem _category({
  required String id,
  required String name,
  required String description,
  required CategoryType type,
}) {
  return CategoryItem(
    id: id,
    name: name,
    description: description,
    type: type,
    icon: Icons.category_outlined,
  );
}

List<TransactionItem> _transactions() {
  return [
    TransactionItem(
      id: 'tx-income',
      title: 'April salary',
      amount: 100,
      currencyCode: 'EUR',
      date: DateTime(2026, 4, 10),
      type: TransactionType.income,
      accountId: 'account-eur',
      categoryId: 'income-category',
    ),
    TransactionItem(
      id: 'tx-expense',
      title: 'Groceries',
      amount: 40,
      currencyCode: 'EUR',
      date: DateTime(2026, 4, 12),
      type: TransactionType.expense,
      accountId: 'account-eur',
      categoryId: 'expense-category',
    ),
    TransactionItem(
      id: 'tx-transfer',
      title: 'Travel top up',
      amount: 30,
      currencyCode: 'EUR',
      date: DateTime(2026, 4, 15),
      type: TransactionType.transfer,
      sourceAccountId: 'account-eur',
      destinationAccountId: 'account-usd',
      destinationAmount: 50,
      destinationCurrencyCode: 'USD',
    ),
    TransactionItem(
      id: 'tx-old-expense',
      title: 'Older groceries',
      amount: 15,
      currencyCode: 'EUR',
      date: DateTime(2026, 3, 10),
      type: TransactionType.expense,
      accountId: 'account-eur',
      categoryId: 'expense-category',
    ),
    TransactionItem(
      id: 'tx-missing',
      title: 'Tokyo lunch',
      amount: 25,
      currencyCode: 'JPY',
      date: DateTime(2026, 4, 18),
      type: TransactionType.expense,
      accountId: 'account-eur',
      categoryId: 'expense-category',
    ),
  ];
}

List<RecurringTransaction> _recurringTransactions() {
  return [
    RecurringTransaction(
      id: 'recurring-income',
      title: 'Monthly salary',
      amount: 100,
      currencyCode: 'EUR',
      startDate: DateTime(2026, 4, 1),
      type: TransactionType.income,
      categoryId: 'income-category',
      accountId: 'account-eur',
      executionMode: RecurringExecutionMode.manual,
      frequencyPreset: RecurringFrequencyPreset.monthly,
      intervalUnit: RecurringIntervalUnit.month,
    ),
    RecurringTransaction(
      id: 'recurring-transfer',
      title: 'Travel fund',
      amount: 20,
      currencyCode: 'EUR',
      startDate: DateTime(2026, 4, 19),
      type: TransactionType.transfer,
      sourceAccountId: 'account-eur',
      destinationAccountId: 'account-usd',
      executionMode: RecurringExecutionMode.manual,
      frequencyPreset: RecurringFrequencyPreset.daily,
      intervalUnit: RecurringIntervalUnit.day,
    ),
  ];
}
