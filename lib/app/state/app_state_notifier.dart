import 'dart:async';

import 'package:expense_tracker/app/state/app_state_dependencies.dart';
import 'package:expense_tracker/app/state/app_state_exceptions.dart';
import 'package:expense_tracker/app/state/app_state_factory.dart';
import 'package:expense_tracker/app/state/app_state_snapshot.dart';
import 'package:expense_tracker/features/accounts/data/account_repository.dart';
import 'package:expense_tracker/features/accounts/domain/models/account.dart';
import 'package:expense_tracker/features/categories/data/category_repository.dart';
import 'package:expense_tracker/features/categories/domain/models/category_item.dart';
import 'package:expense_tracker/features/settings/data/settings_repository.dart';
import 'package:expense_tracker/features/transactions/data/transaction_repository.dart';
import 'package:expense_tracker/features/transactions/domain/models/transaction_item.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AppStateNotifier extends Notifier<AppStateSnapshot> {
  late final SettingsRepository _settingsRepository;
  late final AccountRepository _accountRepository;
  late final CategoryRepository _categoryRepository;
  late final TransactionRepository _transactionRepository;
  late final AppStateFactory _stateFactory;

  int _refreshToken = 0;
  bool _didBindStorageListeners = false;
  bool _didScheduleInitialRefresh = false;

  @override
  AppStateSnapshot build() {
    _settingsRepository = ref.read(settingsRepositoryProvider);
    _accountRepository = ref.read(accountRepositoryProvider);
    _categoryRepository = ref.read(categoryRepositoryProvider);
    _transactionRepository = ref.read(transactionRepositoryProvider);
    _stateFactory = AppStateFactory(
      balanceOverviewService: ref.read(balanceOverviewServiceProvider),
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
      Future<void>.microtask(refresh);
    }
    return initialState;
  }

  void _bindStorageListeners() {
    final settingsListener = _settingsRepository.listenable();
    final accountsListener = _accountRepository.listenable();
    final categoriesListener = _categoryRepository.listenable();
    final transactionsListener = _transactionRepository.listenable();

    void scheduleRefresh() {
      unawaited(refresh());
    }

    settingsListener.addListener(scheduleRefresh);
    accountsListener.addListener(scheduleRefresh);
    categoriesListener.addListener(scheduleRefresh);
    transactionsListener.addListener(scheduleRefresh);

    ref.onDispose(() {
      settingsListener.removeListener(scheduleRefresh);
      accountsListener.removeListener(scheduleRefresh);
      categoriesListener.removeListener(scheduleRefresh);
      transactionsListener.removeListener(scheduleRefresh);
    });
  }

  String createAccountId() => _accountRepository.createAccountId();

  String createTransactionId() => _transactionRepository.createTransactionId();

  Future<void> refresh() async {
    final refreshToken = ++_refreshToken;
    state = state.copyWith(isLoading: true, loadError: null);

    try {
      final results = await Future.wait<dynamic>([
        _accountRepository.getAccounts(),
        _categoryRepository.getCategories(),
        _transactionRepository.getTransactions(),
      ]);

      if (refreshToken != _refreshToken) {
        return;
      }

      final nextState = _stateFactory.buildSnapshot(
        previous: state,
        settings: _settingsRepository.getSettings(),
        accounts: results[0] as List<Account>,
        categories: results[1] as List<CategoryItem>,
        transactions: results[2] as List<TransactionItem>,
      );

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
    }
  }

  void updateSelectedPeriod(DateTime date) {
    state = _stateFactory.rebuildDerivedState(
      state,
      selectedPeriod: SelectedPeriod.monthContaining(date),
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
    if (state.hasLinkedTransactionsForAccount(account.id)) {
      throw LinkedEntityException(
        'Move or delete transactions from ${account.name} before removing the account.',
      );
    }

    await _accountRepository.deleteAccount(account.id);
  }

  Future<void> reorderAccounts(List<Account> accounts) {
    return _accountRepository.reorderAccounts(accounts);
  }

  Future<void> saveTransaction(
    TransactionItem transaction, {
    required bool isEditing,
  }) async {
    if (isEditing) {
      await _transactionRepository.updateTransaction(transaction);
      return;
    }

    await _transactionRepository.addTransaction(transaction);
  }

  Future<void> deleteTransaction(String transactionId) {
    return _transactionRepository.deleteTransaction(transactionId);
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
    if (state.hasLinkedTransactionsForCategory(category.id)) {
      throw const LinkedEntityException(
        'Move or delete the related transactions before removing this category.',
      );
    }

    await _categoryRepository.deleteCategory(category.id);
  }

  Future<void> updateSettings({
    required String displayName,
    required String defaultCurrencyCode,
  }) async {
    await _settingsRepository.updateDisplayName(displayName);
    await _settingsRepository.updateDefaultCurrencyCode(defaultCurrencyCode);
  }
}
