import 'dart:async';

import 'package:expense_tracker/app/state/app_state_dependencies.dart';
import 'package:expense_tracker/app/state/app_state_exceptions.dart';
import 'package:expense_tracker/app/state/app_state_factory.dart';
import 'package:expense_tracker/app/state/app_state_snapshot.dart';
import 'package:expense_tracker/features/accounts/data/account_repository.dart';
import 'package:expense_tracker/features/accounts/domain/models/account.dart';
import 'package:expense_tracker/features/categories/data/category_repository.dart';
import 'package:expense_tracker/features/categories/domain/models/category_item.dart';
import 'package:expense_tracker/features/recurring_transactions/data/recurring_transaction_repository.dart';
import 'package:expense_tracker/features/recurring_transactions/domain/models/recurring_transaction.dart';
import 'package:expense_tracker/features/recurring_transactions/domain/services/recurring_transaction_execution_service.dart';
import 'package:expense_tracker/features/settings/data/settings_repository.dart';
import 'package:expense_tracker/features/transactions/data/transaction_repository.dart';
import 'package:expense_tracker/features/transactions/domain/models/transaction_item.dart';
import 'package:expense_tracker/features/transactions/domain/services/transaction_aggregation_service.dart';
import 'package:expense_tracker/features/transactions/domain/services/transaction_balance_service.dart';
import 'package:expense_tracker/core/utils/currency_conversion_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AppStateNotifier extends Notifier<AppStateSnapshot> {
  late final SettingsRepository _settingsRepository;
  late final AccountRepository _accountRepository;
  late final CategoryRepository _categoryRepository;
  late final TransactionRepository _transactionRepository;
  late final RecurringTransactionRepository _recurringTransactionRepository;
  late final TransactionBalanceService _transactionBalanceService;
  late final TransactionAggregationService _transactionAggregationService;
  late final RecurringTransactionExecutionService
  _recurringTransactionExecutionService;
  late final CurrencyConversionService _currencyConversionService;
  late final AppStateFactory _stateFactory;

  int _refreshToken = 0;
  bool _didBindStorageListeners = false;
  bool _didScheduleInitialRefresh = false;
  bool _isRefreshing = false;
  bool _refreshQueued = false;
  Timer? _dateRefreshTimer;

  @override
  AppStateSnapshot build() {
    _settingsRepository = ref.read(settingsRepositoryProvider);
    _accountRepository = ref.read(accountRepositoryProvider);
    _categoryRepository = ref.read(categoryRepositoryProvider);
    _transactionRepository = ref.read(transactionRepositoryProvider);
    _recurringTransactionRepository = ref.read(
      recurringTransactionRepositoryProvider,
    );
    _transactionBalanceService = ref.read(transactionBalanceServiceProvider);
    _transactionAggregationService = ref.read(
      transactionAggregationServiceProvider,
    );
    _recurringTransactionExecutionService = ref.read(
      recurringTransactionExecutionServiceProvider,
    );
    _currencyConversionService = ref.read(currencyConversionServiceProvider);
    _stateFactory = AppStateFactory(
      balanceOverviewService: ref.read(balanceOverviewServiceProvider),
      creditCardOverviewService: ref.read(creditCardOverviewServiceProvider),
      currencyConversionService: _currencyConversionService,
      transactionAggregationService: _transactionAggregationService,
      recurringScheduleService: ref.read(recurringScheduleServiceProvider),
    );

    if (!_didBindStorageListeners) {
      _bindStorageListeners();
      _didBindStorageListeners = true;
    }

    final initialState = AppStateSnapshot.initial(
      settings: _settingsRepository.getSettings(),
    );
    if (!_didScheduleInitialRefresh) {
      _didScheduleInitialRefresh = true;
      Future<void>.microtask(_requestRefresh);
    }
    return initialState;
  }

  void _bindStorageListeners() {
    final settingsListener = _settingsRepository.listenable();
    final accountsListener = _accountRepository.listenable();
    final categoriesListener = _categoryRepository.listenable();
    final transactionsListener = _transactionRepository.listenable();
    final recurringTransactionsListener = _recurringTransactionRepository
        .listenable();

    void scheduleRefresh() {
      _requestRefresh();
    }

    settingsListener.addListener(scheduleRefresh);
    accountsListener.addListener(scheduleRefresh);
    categoriesListener.addListener(scheduleRefresh);
    transactionsListener.addListener(scheduleRefresh);
    recurringTransactionsListener.addListener(scheduleRefresh);

    ref.onDispose(() {
      _dateRefreshTimer?.cancel();
      settingsListener.removeListener(scheduleRefresh);
      accountsListener.removeListener(scheduleRefresh);
      categoriesListener.removeListener(scheduleRefresh);
      transactionsListener.removeListener(scheduleRefresh);
      recurringTransactionsListener.removeListener(scheduleRefresh);
    });
  }

  String createAccountId() => _accountRepository.createAccountId();

  String createTransactionId() => _transactionRepository.createTransactionId();

  String createRecurringTransactionId() =>
      _recurringTransactionRepository.createRecurringTransactionId();

  void _requestRefresh() {
    if (_isRefreshing) {
      _refreshQueued = true;
      return;
    }

    unawaited(refresh());
  }

  Future<void> refresh() async {
    if (_isRefreshing) {
      _refreshQueued = true;
      return;
    }

    _isRefreshing = true;
    final refreshToken = ++_refreshToken;
    state = state.copyWith(isLoading: true, loadError: null);

    try {
      final results = await Future.wait<dynamic>([
        _accountRepository.getAccounts(),
        _categoryRepository.getCategories(),
        _transactionRepository.getTransactions(),
        _recurringTransactionRepository.getRecurringTransactions(),
      ]);

      if (refreshToken != _refreshToken) {
        return;
      }

      final accounts = results[0] as List<Account>;
      final categories = results[1] as List<CategoryItem>;
      var transactions = results[2] as List<TransactionItem>;
      var recurringTransactions = results[3] as List<RecurringTransaction>;

      final didApplyAutomaticRecurringTransactions =
          await _recurringTransactionExecutionService
              .processAutomaticTransactions(
                recurringTransactions: recurringTransactions,
                currentAccounts: accounts,
                now: DateTime.now(),
                createTransactionId: createTransactionId,
              );
      if (didApplyAutomaticRecurringTransactions) {
        transactions = await _transactionRepository.getTransactions();
        recurringTransactions = await _recurringTransactionRepository
            .getRecurringTransactions();
      }

      final nextState = await _stateFactory.buildSnapshot(
        previous: state,
        settings: _settingsRepository.getSettings(),
        accounts: accounts,
        categories: categories,
        transactions: transactions,
        recurringTransactions: recurringTransactions,
      );

      _scheduleDateRefresh(nextState.asOfDate);
      state = nextState.copyWith(
        hasLoaded: true,
        isLoading: false,
        loadError: null,
      );
    } catch (error) {
      if (refreshToken != _refreshToken) {
        return;
      }

      state = state.copyWith(
        hasLoaded: true,
        isLoading: false,
        loadError: error,
      );
    } finally {
      _isRefreshing = false;
      if (_refreshQueued) {
        _refreshQueued = false;
        _requestRefresh();
      }
    }
  }

  void updateSelectedPeriod(DateTime date) {
    state = _stateFactory.rebuildDerivedState(
      state,
      selectedPeriod: SelectedPeriod.containing(
        date: date,
        financialCycleDay: state.settings.financialCycleDay,
      ),
    );
  }

  void updateAccountSelectedPeriod(String accountId, DateTime date) {
    state = _stateFactory.rebuildDerivedState(
      state,
      accountSelectedPeriods: {
        ...state.accountSelectedPeriods,
        accountId: SelectedPeriod.containing(
          date: date,
          financialCycleDay: state.settings.financialCycleDay,
        ),
      },
    );
  }

  void updateHistoryFilter(TransactionHistoryFilter filter) {
    state = _stateFactory.rebuildDerivedState(state, historyFilter: filter);
  }

  void updateHistorySort(TransactionHistorySort sort) {
    state = _stateFactory.rebuildDerivedState(state, historySort: sort);
  }

  void updateHistorySearchQuery(String query) {
    state = _stateFactory.rebuildDerivedState(
      state,
      historySearchQuery: query.trim().toLowerCase(),
    );
  }

  Future<void> saveAccount(Account account, {required bool isEditing}) async {
    if (isEditing) {
      await _accountRepository.updateAccount(account);
      return;
    }

    await _accountRepository.addAccount(account);
  }

  Future<void> deleteAccount(Account account) async {
    if (state.hasLinkedTransactionsForAccount(account.id) ||
        state.hasLinkedRecurringTransactionsForAccount(account.id)) {
      throw LinkedEntityException(
        'Move or delete transactions and recurring items from ${account.name} before removing the account.',
      );
    }

    await _accountRepository.deleteAccount(account.id);
  }

  Future<void> deleteAccountWithTransactions(Account account) async {
    if (state.hasLinkedRecurringTransactionsForAccount(account.id)) {
      throw LinkedEntityException(
        'Move or delete recurring items from ${account.name} before removing the account.',
      );
    }

    final linkedTransactions = state.transactionsForAccount(account.id);
    await _transactionBalanceService.deleteTransactions(
      linkedTransactions,
      currentAccounts: state.accounts,
    );
    await _accountRepository.deleteAccount(account.id);
  }

  Future<void> reorderAccounts(List<Account> accounts) {
    return _accountRepository.reorderAccounts(accounts);
  }

  Future<void> saveTransaction(
    TransactionItem transaction, {
    required bool isEditing,
  }) async {
    await _transactionBalanceService.saveTransaction(
      transaction,
      isEditing: isEditing,
      previousTransaction: isEditing ? _transactionForId(transaction.id) : null,
      currentAccounts: state.accounts,
    );
  }

  Future<void> deleteTransaction(String transactionId) async {
    await _transactionBalanceService.deleteTransaction(
      transactionId,
      existingTransaction: _transactionForId(transactionId),
      currentAccounts: state.accounts,
    );
  }

  Future<void> saveCategory(
    CategoryItem category, {
    required bool isEditing,
  }) async {
    if (isEditing) {
      await _categoryRepository.updateCategory(category);
      return;
    }

    await _categoryRepository.addCategory(category);
  }

  Future<void> deleteCategory(CategoryItem category) async {
    if (state.hasLinkedTransactionsForCategory(category.id) ||
        state.hasLinkedRecurringTransactionsForCategory(category.id)) {
      throw const LinkedEntityException(
        'Move or delete the related transactions and recurring items before removing this category.',
      );
    }

    await _categoryRepository.deleteCategory(category.id);
  }

  Future<void> deleteCategoryWithTransactions(CategoryItem category) async {
    if (state.hasLinkedRecurringTransactionsForCategory(category.id)) {
      throw const LinkedEntityException(
        'Move or delete the related recurring items before removing this category.',
      );
    }

    final linkedTransactions = state.transactionsForCategory(category.id);
    await _transactionBalanceService.deleteTransactions(
      linkedTransactions,
      currentAccounts: state.accounts,
    );
    await _categoryRepository.deleteCategory(category.id);
  }

  Future<void> saveRecurringTransaction(
    RecurringTransaction recurringTransaction, {
    required bool isEditing,
  }) async {
    if (isEditing) {
      await _recurringTransactionRepository.updateRecurringTransaction(
        recurringTransaction,
      );
      return;
    }

    await _recurringTransactionRepository.addRecurringTransaction(
      recurringTransaction,
    );
  }

  Future<void> deleteRecurringTransaction(String recurringTransactionId) async {
    await _recurringTransactionRepository.deleteRecurringTransaction(
      recurringTransactionId,
    );
  }

  Future<void> setRecurringTransactionPaused(
    String recurringTransactionId, {
    required bool isPaused,
  }) async {
    final recurringTransaction = _recurringTransactionForId(
      recurringTransactionId,
    );
    await _recurringTransactionRepository.updateRecurringTransaction(
      recurringTransaction.copyWith(isPaused: isPaused),
    );
  }

  Future<void> confirmRecurringTransaction(
    String recurringTransactionId,
  ) async {
    final recurringTransaction = _recurringTransactionForId(
      recurringTransactionId,
    );
    await _recurringTransactionExecutionService.confirmNextDueOccurrence(
      recurringTransaction: recurringTransaction,
      currentAccounts: state.accounts,
      now: DateTime.now(),
      createTransactionId: createTransactionId,
    );
  }

  Future<void> updateSettings({
    required String displayName,
    required String defaultCurrencyCode,
  }) async {
    await _settingsRepository.updateDisplayName(displayName);
    await _settingsRepository.updateDefaultCurrencyCode(defaultCurrencyCode);
  }

  Future<void> updateFinancialCycleDay(int day) {
    return _settingsRepository.updateFinancialCycleDay(day);
  }

  TransactionItem? _transactionForId(String transactionId) {
    for (final transaction in state.transactions) {
      if (transaction.id == transactionId) {
        return transaction;
      }
    }

    return null;
  }

  RecurringTransaction _recurringTransactionForId(
    String recurringTransactionId,
  ) {
    final recurringTransaction = state.recurringTransactionById(
      recurringTransactionId,
    );
    if (recurringTransaction == null) {
      throw StateError(
        'Recurring transaction $recurringTransactionId is no longer available.',
      );
    }

    return recurringTransaction;
  }

  void _scheduleDateRefresh(DateTime from) {
    _dateRefreshTimer?.cancel();
    final nextMidnight = DateTime(from.year, from.month, from.day + 1);
    final delay = nextMidnight.difference(DateTime.now());
    _dateRefreshTimer = Timer(
      delay.isNegative ? Duration.zero : delay,
      _requestRefresh,
    );
  }
}
