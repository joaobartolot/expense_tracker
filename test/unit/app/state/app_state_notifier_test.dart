import 'dart:async';

import 'package:expense_tracker/app/state/app_state_provider.dart';
import 'package:expense_tracker/app/state/app_state_snapshot.dart';
import 'package:expense_tracker/features/accounts/data/account_repository.dart';
import 'package:expense_tracker/features/accounts/domain/models/account.dart';
import 'package:expense_tracker/features/categories/data/category_repository.dart';
import 'package:expense_tracker/features/categories/domain/models/category_item.dart';
import 'package:expense_tracker/features/recurring_transactions/data/recurring_transaction_repository.dart';
import 'package:expense_tracker/features/recurring_transactions/domain/models/recurring_transaction.dart';
import 'package:expense_tracker/features/recurring_transactions/domain/services/recurring_transaction_execution_service.dart';
import 'package:expense_tracker/features/settings/data/settings_repository.dart';
import 'package:expense_tracker/features/settings/domain/models/app_settings.dart';
import 'package:expense_tracker/features/settings/domain/models/app_theme_preference.dart';
import 'package:expense_tracker/features/transactions/data/transaction_repository.dart';
import 'package:expense_tracker/features/transactions/domain/models/transaction_item.dart';
import 'package:expense_tracker/features/transactions/domain/services/transaction_balance_service.dart';
import 'package:expense_tracker/app/state/app_state_dependencies.dart';
import 'package:expense_tracker/core/utils/currency_conversion_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

void main() {
  late _FakeSettingsRepository settingsRepository;
  late _FakeAccountRepository accountRepository;
  late _FakeCategoryRepository categoryRepository;
  late _FakeTransactionRepository transactionRepository;
  late _FakeRecurringTransactionRepository recurringTransactionRepository;
  late _FakeTransactionBalanceService transactionBalanceService;
  late _FakeRecurringTransactionExecutionService
  recurringTransactionExecutionService;
  late _FakeCurrencyConversionService currencyConversionService;

  setUp(() {
    settingsRepository = _FakeSettingsRepository(_settings());
    accountRepository = _FakeAccountRepository();
    accountRepository.accounts = _accounts();
    categoryRepository = _FakeCategoryRepository();
    categoryRepository.categories = _categories();
    transactionRepository = _FakeTransactionRepository();
    transactionRepository.transactions = _transactions();
    recurringTransactionRepository = _FakeRecurringTransactionRepository();
    recurringTransactionRepository.recurringTransactions =
        _recurringTransactions();
    transactionBalanceService = _FakeTransactionBalanceService();
    recurringTransactionExecutionService =
        _FakeRecurringTransactionExecutionService();
    currencyConversionService = _FakeCurrencyConversionService();
  });

  ProviderContainer buildContainer() {
    return ProviderContainer(
      overrides: [
        settingsRepositoryProvider.overrideWithValue(settingsRepository),
        accountRepositoryProvider.overrideWithValue(accountRepository),
        categoryRepositoryProvider.overrideWithValue(categoryRepository),
        transactionRepositoryProvider.overrideWithValue(transactionRepository),
        recurringTransactionRepositoryProvider.overrideWithValue(
          recurringTransactionRepository,
        ),
        transactionBalanceServiceProvider.overrideWithValue(
          transactionBalanceService,
        ),
        recurringTransactionExecutionServiceProvider.overrideWithValue(
          recurringTransactionExecutionService,
        ),
        currencyConversionServiceProvider.overrideWithValue(
          currencyConversionService,
        ),
      ],
    );
  }

  ProviderContainer seedAndBuildContainer() {
    final container = buildContainer();
    unawaited(_settle());
    return container;
  }

  group('refresh', () {
    test(
      'initial build uses persisted settings and schedules a refresh',
      () async {
        accountRepository.accounts = _accounts();
        categoryRepository.categories = _categories();
        transactionRepository.transactions = _transactions();
        recurringTransactionRepository.recurringTransactions =
            _recurringTransactions();

        final container = buildContainer();
        addTearDown(container.dispose);

        final initial = container.read(appStateProvider);
        expect(initial.settings, settingsRepository.settings);
        expect(initial.hasLoaded, isFalse);
        expect(initial.isLoading, isTrue);

        await _settle();

        final state = container.read(appStateProvider);
        expect(state.hasLoaded, isTrue);
        expect(state.isLoading, isFalse);
        expect(state.loadError, isNull);
        expect(accountRepository.getAccountsCallCount, greaterThanOrEqualTo(1));
      },
    );

    test(
      'loads repositories, runs automatic recurring processing, and rebuilds the snapshot',
      () async {
        accountRepository.accounts = _accounts();
        categoryRepository.categories = _categories();
        transactionRepository.transactions = _transactions();
        recurringTransactionRepository.recurringTransactions =
            _recurringTransactions();
        recurringTransactionExecutionService.processReturnValue = true;
        transactionRepository.onGetTransactions = () {
          if (transactionRepository.getTransactionsCallCount == 1) {
            return _transactions();
          }
          return [..._transactions(), _createdTransaction()];
        };

        final container = buildContainer();
        addTearDown(container.dispose);
        container.read(appStateProvider);

        await _settle();

        final state = container.read(appStateProvider);
        expect(state.hasLoaded, isTrue);
        expect(
          recurringTransactionExecutionService.processCallCount,
          greaterThanOrEqualTo(1),
        );
        expect(transactionRepository.getTransactionsCallCount, 2);
        expect(
          state.transactions.map((transaction) => transaction.id),
          contains('created-after-recurring'),
        );
      },
    );

    test(
      'stores the refresh failure in loadError and clears the loading flag',
      () async {
        accountRepository.getAccountsError = StateError('accounts failed');

        final container = buildContainer();
        addTearDown(container.dispose);
        container.read(appStateProvider);

        await _settle();

        final state = container.read(appStateProvider);
        expect(state.hasLoaded, isTrue);
        expect(state.isLoading, isFalse);
        expect(state.loadError, isA<StateError>());
      },
    );

    test(
      'queues exactly one follow-up refresh while a refresh is already running',
      () async {
        final firstGetAccounts = Completer<List<Account>>();
        accountRepository.onGetAccounts = () => firstGetAccounts.future;
        categoryRepository.categories = _categories();
        transactionRepository.transactions = _transactions();
        recurringTransactionRepository.recurringTransactions =
            _recurringTransactions();

        final container = buildContainer();
        addTearDown(container.dispose);
        final notifier = container.read(appStateProvider.notifier);
        await _settle();

        await _settle();
        await notifier.refresh();
        await notifier.refresh();
        firstGetAccounts.complete(_accounts());
        accountRepository.onGetAccounts = () async => _accounts();

        await _settle();

        expect(accountRepository.getAccountsCallCount, 2);
      },
    );
  });

  group('delegation', () {
    test(
      'saveTransaction create forwards current accounts and categories',
      () async {
        final container = seedAndBuildContainer();
        addTearDown(container.dispose);
        final notifier = container.read(appStateProvider.notifier);
        await _settle();

        await notifier.saveTransaction(
          _transaction(id: 'new-transaction'),
          isEditing: false,
        );

        expect(transactionBalanceService.savedTransactions, hasLength(1));
        final call = transactionBalanceService.savedTransactions.single;
        expect(call.isEditing, isFalse);
        expect(call.previousTransaction, isNull);
        expect(call.currentAccounts.map((account) => account.id), [
          'account-eur',
          'account-usd',
        ]);
        expect(call.currentCategories.map((category) => category.id), [
          'income-category',
          'expense-category',
        ]);
      },
    );

    test(
      'saveTransaction edit resolves and forwards the previous transaction',
      () async {
        final container = seedAndBuildContainer();
        addTearDown(container.dispose);
        final notifier = container.read(appStateProvider.notifier);
        await _settle();

        await notifier.saveTransaction(
          _transaction(id: 'tx-expense', title: 'Updated groceries'),
          isEditing: true,
        );

        final call = transactionBalanceService.savedTransactions.single;
        expect(call.isEditing, isTrue);
        expect(call.previousTransaction?.id, 'tx-expense');
      },
    );

    test('saveAccount delegates create and edit to the repository', () async {
      final container = seedAndBuildContainer();
      addTearDown(container.dispose);
      final notifier = container.read(appStateProvider.notifier);
      await _settle();
      final account = _account(id: 'account-new', name: 'New account');

      await notifier.saveAccount(account, isEditing: false);
      await notifier.saveAccount(account, isEditing: true);

      expect(accountRepository.addedAccounts, [account]);
      expect(accountRepository.updatedAccounts, [account]);
    });

    test('saveCategory delegates create and edit to the repository', () async {
      final container = seedAndBuildContainer();
      addTearDown(container.dispose);
      final notifier = container.read(appStateProvider.notifier);
      await _settle();
      final category = _category(
        id: 'category-new',
        name: 'Health',
        type: CategoryType.expense,
      );

      await notifier.saveCategory(category, isEditing: false);
      await notifier.saveCategory(category, isEditing: true);

      expect(categoryRepository.addedCategories, [category]);
      expect(categoryRepository.updatedCategories, [category]);
    });

    test(
      'saveRecurringTransaction delegates create and edit to the repository',
      () async {
        final container = seedAndBuildContainer();
        addTearDown(container.dispose);
        final notifier = container.read(appStateProvider.notifier);
        await _settle();
        final recurring = _recurringIncome(id: 'recurring-new');

        await notifier.saveRecurringTransaction(recurring, isEditing: false);
        await notifier.saveRecurringTransaction(recurring, isEditing: true);

        expect(recurringTransactionRepository.addedRecurringTransactions, [
          recurring,
        ]);
        expect(recurringTransactionRepository.updatedRecurringTransactions, [
          recurring,
        ]);
      },
    );
  });

  group('linked-entity guards', () {
    test('deleteAccount rejects accounts with linked transactions', () async {
      final container = seedAndBuildContainer();
      addTearDown(container.dispose);
      final notifier = container.read(appStateProvider.notifier);
      await _settle();

      await expectLater(
        notifier.deleteAccount(_account(id: 'account-eur', name: 'Main')),
        throwsA(isA<LinkedEntityException>()),
      );

      expect(accountRepository.deletedAccountIds, isEmpty);
    });

    test(
      'deleteAccount rejects accounts with linked recurring transactions',
      () async {
        transactionRepository.transactions = const [];
        final container = seedAndBuildContainer();
        addTearDown(container.dispose);
        final notifier = container.read(appStateProvider.notifier);
        await _settle();

        await expectLater(
          notifier.deleteAccount(_account(id: 'account-usd', name: 'Travel')),
          throwsA(isA<LinkedEntityException>()),
        );

        expect(accountRepository.deletedAccountIds, isEmpty);
      },
    );

    test(
      'deleteAccountWithTransactions deletes linked transactions before deleting the account',
      () async {
        recurringTransactionRepository.recurringTransactions = const [];
        accountRepository.operationLog = transactionBalanceService.operationLog;
        final container = seedAndBuildContainer();
        addTearDown(container.dispose);
        final notifier = container.read(appStateProvider.notifier);
        await _settle();

        await notifier.deleteAccountWithTransactions(
          _account(id: 'account-eur', name: 'Main'),
        );

        expect(transactionBalanceService.deletedTransactionIds, [
          'tx-income',
          'tx-expense',
          'tx-transfer',
        ]);
        expect(accountRepository.deletedAccountIds, ['account-eur']);
        expect(transactionBalanceService.operationLog, [
          'deleteTransactions',
          'deleteAccount',
        ]);
      },
    );

    test(
      'deleteCategory rejects categories with linked transactions',
      () async {
        final container = seedAndBuildContainer();
        addTearDown(container.dispose);
        final notifier = container.read(appStateProvider.notifier);
        await _settle();

        await expectLater(
          notifier.deleteCategory(
            _category(
              id: 'expense-category',
              name: 'Food',
              type: CategoryType.expense,
            ),
          ),
          throwsA(isA<LinkedEntityException>()),
        );

        expect(categoryRepository.deletedCategoryIds, isEmpty);
      },
    );

    test(
      'deleteCategory rejects categories with linked recurring transactions',
      () async {
        transactionRepository.transactions = const [];
        final container = seedAndBuildContainer();
        addTearDown(container.dispose);
        final notifier = container.read(appStateProvider.notifier);
        await _settle();

        await expectLater(
          notifier.deleteCategory(
            _category(
              id: 'income-category',
              name: 'Salary',
              type: CategoryType.income,
            ),
          ),
          throwsA(isA<LinkedEntityException>()),
        );

        expect(categoryRepository.deletedCategoryIds, isEmpty);
      },
    );

    test(
      'deleteCategoryWithTransactions deletes linked transactions before deleting the category',
      () async {
        recurringTransactionRepository.recurringTransactions = [
          _recurringIncome(
            id: 'recurring-income',
            categoryId: 'income-category',
          ),
        ];
        categoryRepository.operationLog =
            transactionBalanceService.operationLog;
        final container = seedAndBuildContainer();
        addTearDown(container.dispose);
        final notifier = container.read(appStateProvider.notifier);
        await _settle();

        await notifier.deleteCategoryWithTransactions(
          _category(
            id: 'expense-category',
            name: 'Food',
            type: CategoryType.expense,
          ),
        );

        expect(transactionBalanceService.deletedTransactionIds, ['tx-expense']);
        expect(categoryRepository.deletedCategoryIds, ['expense-category']);
        expect(transactionBalanceService.operationLog, [
          'deleteTransactions',
          'deleteCategory',
        ]);
      },
    );

    test(
      'deleteCategoryWithTransactions rejects categories with linked recurring transactions',
      () async {
        final container = seedAndBuildContainer();
        addTearDown(container.dispose);
        final notifier = container.read(appStateProvider.notifier);
        await _settle();

        await expectLater(
          notifier.deleteCategoryWithTransactions(
            _category(
              id: 'income-category',
              name: 'Salary',
              type: CategoryType.income,
            ),
          ),
          throwsA(isA<LinkedEntityException>()),
        );

        expect(categoryRepository.deletedCategoryIds, isEmpty);
        expect(transactionBalanceService.deletedTransactionIds, isEmpty);
      },
    );
  });

  group('state updates and recurring confirmation', () {
    test(
      'updateSelectedPeriod and history controls rebuild derived state',
      () async {
        final container = seedAndBuildContainer();
        addTearDown(container.dispose);
        final notifier = container.read(appStateProvider.notifier);
        await _settle();

        notifier.updateSelectedPeriod(DateTime(2026, 3, 20));
        notifier.updateHistoryFilter(TransactionHistoryFilter.expense);
        notifier.updateHistorySort(TransactionHistorySort.oldestFirst);
        notifier.updateHistorySearchQuery('  food  ');

        final state = container.read(appStateProvider);
        expect(state.selectedPeriod.start, DateTime(2026, 3, 5));
        expect(state.historyFilter, TransactionHistoryFilter.expense);
        expect(state.historySort, TransactionHistorySort.oldestFirst);
        expect(state.historySearchQuery, 'food');
        expect(state.historyTransactions.map((transaction) => transaction.id), [
          'tx-expense',
        ]);
      },
    );

    test(
      'confirmRecurringTransaction forwards current accounts and the generated ID callback',
      () async {
        final container = seedAndBuildContainer();
        addTearDown(container.dispose);
        final notifier = container.read(appStateProvider.notifier);
        await _settle();

        await notifier.confirmRecurringTransaction('recurring-transfer');

        expect(
          recurringTransactionExecutionService.confirmedRecurringTransactionId,
          'recurring-transfer',
        );
        expect(recurringTransactionExecutionService.confirmCurrentAccountIds, [
          'account-eur',
          'account-usd',
        ]);
        expect(
          recurringTransactionExecutionService.generatedTransactionId,
          'generated-transaction-id',
        );
      },
    );
  });
}

Future<void> _settle([int times = 20]) async {
  for (var index = 0; index < times; index += 1) {
    await Future<void>.delayed(Duration.zero);
  }
}

class _FakeSettingsRepository implements SettingsRepository {
  _FakeSettingsRepository(this.settings);

  final ValueNotifier<Box<dynamic>> _listenable = ValueNotifier(_FakeBox());
  AppSettings settings;

  @override
  AppSettings getSettings() => settings;

  @override
  ValueListenable<Box<dynamic>> listenable() => _listenable;

  @override
  Future<void> updateDefaultCurrencyCode(String code) async {
    settings = settings.copyWith(defaultCurrencyCode: code);
  }

  @override
  Future<void> updateDisplayName(String name) async {
    settings = settings.copyWith(displayName: name);
  }

  @override
  Future<void> updateFinancialCycleDay(int day) async {
    settings = settings.copyWith(financialCycleDay: day);
  }

  @override
  Future<void> updateThemePreference(AppThemePreference preference) async {
    settings = settings.copyWith(themePreference: preference);
  }
}

class _FakeAccountRepository implements AccountRepository {
  final ValueNotifier<Box<dynamic>> _listenable = ValueNotifier(_FakeBox());
  List<Account> accounts = const [];
  int getAccountsCallCount = 0;
  Future<List<Account>> Function()? onGetAccounts;
  Object? getAccountsError;
  final List<Account> addedAccounts = [];
  final List<Account> updatedAccounts = [];
  final List<String> deletedAccountIds = [];
  List<String>? operationLog;

  @override
  Future<void> addAccount(Account account) async {
    addedAccounts.add(account);
  }

  @override
  String createAccountId() => 'generated-account-id';

  @override
  Future<void> deleteAccount(String accountId) async {
    operationLog?.add('deleteAccount');
    deletedAccountIds.add(accountId);
  }

  @override
  Future<List<Account>> getAccounts() async {
    getAccountsCallCount += 1;
    if (getAccountsError != null) {
      throw getAccountsError!;
    }
    if (onGetAccounts != null) {
      return onGetAccounts!();
    }

    return List<Account>.from(accounts);
  }

  @override
  ValueListenable<Box<dynamic>> listenable() => _listenable;

  @override
  Future<void> reorderAccounts(List<Account> accounts) async {}

  @override
  Future<void> updateAccount(Account account) async {
    updatedAccounts.add(account);
  }
}

class _FakeCategoryRepository implements CategoryRepository {
  final ValueNotifier<Box<dynamic>> _listenable = ValueNotifier(_FakeBox());
  List<CategoryItem> categories = const [];
  final List<CategoryItem> addedCategories = [];
  final List<CategoryItem> updatedCategories = [];
  final List<String> deletedCategoryIds = [];
  List<String>? operationLog;

  @override
  Future<void> addCategory(CategoryItem category) async {
    addedCategories.add(category);
  }

  @override
  Future<void> deleteCategory(String categoryId) async {
    operationLog?.add('deleteCategory');
    deletedCategoryIds.add(categoryId);
  }

  @override
  Future<List<CategoryItem>> getCategories() async {
    return List<CategoryItem>.from(categories);
  }

  @override
  ValueListenable<Box<dynamic>> listenable() => _listenable;

  @override
  Future<void> updateCategory(CategoryItem category) async {
    updatedCategories.add(category);
  }
}

class _FakeTransactionRepository implements TransactionRepository {
  final ValueNotifier<Box<dynamic>> _listenable = ValueNotifier(_FakeBox());
  List<TransactionItem> transactions = const [];
  int getTransactionsCallCount = 0;
  List<TransactionItem> Function()? onGetTransactions;

  @override
  Future<void> addTransaction(TransactionItem transaction) async {}

  @override
  String createTransactionId() => 'generated-transaction-id';

  @override
  Future<void> deleteTransaction(String transactionId) async {}

  @override
  Future<List<TransactionItem>> getTransactions() async {
    getTransactionsCallCount += 1;
    if (onGetTransactions != null) {
      return onGetTransactions!();
    }

    return List<TransactionItem>.from(transactions);
  }

  @override
  ValueListenable<Box<dynamic>> listenable() => _listenable;

  @override
  Future<void> updateTransaction(TransactionItem transaction) async {}
}

class _FakeRecurringTransactionRepository
    implements RecurringTransactionRepository {
  final ValueNotifier<Box<dynamic>> _listenable = ValueNotifier(_FakeBox());
  List<RecurringTransaction> recurringTransactions = const [];
  final List<RecurringTransaction> addedRecurringTransactions = [];
  final List<RecurringTransaction> updatedRecurringTransactions = [];
  final List<String> deletedRecurringTransactionIds = [];
  int getRecurringTransactionsCallCount = 0;

  @override
  Future<void> addRecurringTransaction(
    RecurringTransaction recurringTransaction,
  ) async {
    addedRecurringTransactions.add(recurringTransaction);
  }

  @override
  String createRecurringTransactionId() => 'generated-recurring-id';

  @override
  Future<void> deleteRecurringTransaction(String recurringTransactionId) async {
    deletedRecurringTransactionIds.add(recurringTransactionId);
  }

  @override
  Future<List<RecurringTransaction>> getRecurringTransactions() async {
    getRecurringTransactionsCallCount += 1;
    return List<RecurringTransaction>.from(recurringTransactions);
  }

  @override
  ValueListenable<Box<dynamic>> listenable() => _listenable;

  @override
  Future<void> updateRecurringTransaction(
    RecurringTransaction recurringTransaction,
  ) async {
    updatedRecurringTransactions.add(recurringTransaction);
  }
}

class _FakeTransactionBalanceService implements TransactionBalanceService {
  final List<_SaveTransactionCall> savedTransactions = [];
  final List<String> deletedTransactionIds = [];
  final List<String> operationLog = [];

  @override
  Future<void> deleteTransaction(
    String transactionId, {
    required TransactionItem? existingTransaction,
    required List<Account> currentAccounts,
  }) async {
    deletedTransactionIds.add(transactionId);
  }

  @override
  Future<void> deleteTransactions(
    List<TransactionItem> transactions, {
    required List<Account> currentAccounts,
  }) async {
    operationLog.add('deleteTransactions');
    deletedTransactionIds.addAll(
      transactions.map((transaction) => transaction.id),
    );
  }

  @override
  Future<void> saveTransaction(
    TransactionItem transaction, {
    required bool isEditing,
    TransactionItem? previousTransaction,
    required List<Account> currentAccounts,
    List<CategoryItem> currentCategories = const [],
  }) async {
    savedTransactions.add(
      _SaveTransactionCall(
        transaction: transaction,
        isEditing: isEditing,
        previousTransaction: previousTransaction,
        currentAccounts: List<Account>.from(currentAccounts),
        currentCategories: List<CategoryItem>.from(currentCategories),
      ),
    );
  }
}

class _SaveTransactionCall {
  const _SaveTransactionCall({
    required this.transaction,
    required this.isEditing,
    required this.previousTransaction,
    required this.currentAccounts,
    required this.currentCategories,
  });

  final TransactionItem transaction;
  final bool isEditing;
  final TransactionItem? previousTransaction;
  final List<Account> currentAccounts;
  final List<CategoryItem> currentCategories;
}

class _FakeRecurringTransactionExecutionService
    implements RecurringTransactionExecutionService {
  bool processReturnValue = false;
  int processCallCount = 0;
  String? confirmedRecurringTransactionId;
  List<String> confirmCurrentAccountIds = const [];
  String? generatedTransactionId;

  @override
  Future<bool> confirmNextDueOccurrence({
    required RecurringTransaction recurringTransaction,
    required List<Account> currentAccounts,
    required DateTime now,
    required String Function() createTransactionId,
  }) async {
    confirmedRecurringTransactionId = recurringTransaction.id;
    confirmCurrentAccountIds = currentAccounts
        .map((account) => account.id)
        .toList(growable: false);
    generatedTransactionId = createTransactionId();
    return true;
  }

  @override
  Future<bool> processAutomaticTransactions({
    required List<RecurringTransaction> recurringTransactions,
    required List<Account> currentAccounts,
    required DateTime now,
    required String Function() createTransactionId,
  }) async {
    processCallCount += 1;
    return processReturnValue;
  }
}

class _FakeCurrencyConversionService implements CurrencyConversionService {
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

class _FakeBox extends Fake implements Box<dynamic> {}

AppSettings _settings() {
  return const AppSettings(
    displayName: 'Vero',
    themePreference: AppThemePreference.system,
    defaultCurrencyCode: 'EUR',
    financialCycleDay: 5,
  );
}

List<Account> _accounts() {
  return [
    _account(
      id: 'account-eur',
      name: 'Main',
      openingBalance: 200,
      isPrimary: true,
    ),
    _account(
      id: 'account-usd',
      name: 'Travel',
      openingBalance: 50,
      currencyCode: 'USD',
    ),
  ];
}

Account _account({
  required String id,
  required String name,
  double openingBalance = 0,
  String currencyCode = 'EUR',
  bool isPrimary = false,
}) {
  return Account(
    id: id,
    name: name,
    type: AccountType.bank,
    openingBalance: openingBalance,
    currencyCode: currencyCode,
    isPrimary: isPrimary,
  );
}

List<CategoryItem> _categories() {
  return [
    _category(id: 'income-category', name: 'Salary', type: CategoryType.income),
    _category(id: 'expense-category', name: 'Food', type: CategoryType.expense),
  ];
}

CategoryItem _category({
  required String id,
  required String name,
  required CategoryType type,
}) {
  return CategoryItem(
    id: id,
    name: name,
    description: '$name description',
    type: type,
    icon: Icons.category_outlined,
  );
}

List<TransactionItem> _transactions() {
  return [
    TransactionItem(
      id: 'tx-income',
      title: 'Salary payment',
      amount: 100,
      currencyCode: 'EUR',
      date: DateTime(2026, 4, 10),
      type: TransactionType.income,
      accountId: 'account-eur',
      categoryId: 'income-category',
    ),
    TransactionItem(
      id: 'tx-expense',
      title: 'Food run',
      amount: 40,
      currencyCode: 'EUR',
      date: DateTime(2026, 4, 12),
      type: TransactionType.expense,
      accountId: 'account-eur',
      categoryId: 'expense-category',
    ),
    TransactionItem(
      id: 'tx-transfer',
      title: 'Travel transfer',
      amount: 30,
      currencyCode: 'EUR',
      date: DateTime(2026, 4, 15),
      type: TransactionType.transfer,
      sourceAccountId: 'account-eur',
      destinationAccountId: 'account-usd',
      destinationAmount: 50,
      destinationCurrencyCode: 'USD',
    ),
  ];
}

TransactionItem _transaction({required String id, String title = 'Groceries'}) {
  return TransactionItem(
    id: id,
    title: title,
    amount: 20,
    currencyCode: 'EUR',
    date: DateTime(2026, 4, 20),
    type: TransactionType.expense,
    accountId: 'account-eur',
    categoryId: 'expense-category',
  );
}

TransactionItem _createdTransaction() {
  return TransactionItem(
    id: 'created-after-recurring',
    title: 'Recurring rent',
    amount: 60,
    currencyCode: 'EUR',
    date: DateTime(2026, 4, 21),
    type: TransactionType.expense,
    accountId: 'account-eur',
    categoryId: 'expense-category',
  );
}

List<RecurringTransaction> _recurringTransactions() {
  return [
    _recurringIncome(id: 'recurring-income', categoryId: 'income-category'),
    RecurringTransaction(
      id: 'recurring-transfer',
      title: 'Travel fund',
      amount: 25,
      currencyCode: 'EUR',
      startDate: DateTime(2026, 4, 10),
      type: TransactionType.transfer,
      sourceAccountId: 'account-eur',
      destinationAccountId: 'account-usd',
      executionMode: RecurringExecutionMode.manual,
      frequencyPreset: RecurringFrequencyPreset.monthly,
      intervalUnit: RecurringIntervalUnit.month,
    ),
  ];
}

RecurringTransaction _recurringIncome({
  required String id,
  String categoryId = 'income-category',
}) {
  return RecurringTransaction(
    id: id,
    title: 'Monthly salary',
    amount: 100,
    currencyCode: 'EUR',
    startDate: DateTime(2026, 4, 1),
    type: TransactionType.income,
    categoryId: categoryId,
    accountId: 'account-usd',
    executionMode: RecurringExecutionMode.manual,
    frequencyPreset: RecurringFrequencyPreset.monthly,
    intervalUnit: RecurringIntervalUnit.month,
  );
}
