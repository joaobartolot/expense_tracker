import 'dart:async';

import 'package:expense_tracker/app/state/app_state_dependencies.dart';
import 'package:expense_tracker/core/utils/currency_conversion_service.dart';
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
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

class DeleteTestEnvironment {
  DeleteTestEnvironment({
    List<Account>? accounts,
    List<CategoryItem>? categories,
    List<TransactionItem>? transactions,
    List<RecurringTransaction>? recurringTransactions,
    AppSettings settings = const AppSettings(
      displayName: '',
      themePreference: AppThemePreference.system,
      defaultCurrencyCode: 'EUR',
      financialCycleDay: 1,
    ),
    CurrencyConversionService? currencyConversionService,
    this.deleteError,
    this.skipDelete = false,
  }) : settingsRepository = TestSettingsRepository(settings),
       accountRepository = TestAccountRepository(accounts ?? [walletAccount()]),
       categoryRepository = TestCategoryRepository(
         categories ?? [foodCategory(), salaryCategory()],
       ),
       transactionRepository = TestTransactionRepository(
         transactions ?? const [],
       ),
       recurringTransactionRepository = TestRecurringTransactionRepository(
         recurringTransactions ?? const [],
       ),
       currencyConversionService =
           currencyConversionService ?? const TestCurrencyConversionService(),
       recurringTransactionExecutionService =
           const TestRecurringTransactionExecutionService();

  final Object? deleteError;
  final bool skipDelete;
  final TestSettingsRepository settingsRepository;
  final TestAccountRepository accountRepository;
  final TestCategoryRepository categoryRepository;
  final TestTransactionRepository transactionRepository;
  final TestRecurringTransactionRepository recurringTransactionRepository;
  final CurrencyConversionService currencyConversionService;
  final TestRecurringTransactionExecutionService
  recurringTransactionExecutionService;

  late final TestTransactionBalanceService transactionBalanceService =
      TestTransactionBalanceService(
        transactionRepository: transactionRepository,
        deleteError: deleteError,
        skipDelete: skipDelete,
      );

  Future<void> pumpApp(WidgetTester tester, {required Widget home}) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsRepositoryProvider.overrideWithValue(settingsRepository),
          accountRepositoryProvider.overrideWithValue(accountRepository),
          categoryRepositoryProvider.overrideWithValue(categoryRepository),
          transactionRepositoryProvider.overrideWithValue(
            transactionRepository,
          ),
          recurringTransactionRepositoryProvider.overrideWithValue(
            recurringTransactionRepository,
          ),
          transactionBalanceServiceProvider.overrideWithValue(
            transactionBalanceService,
          ),
          currencyConversionServiceProvider.overrideWithValue(
            currencyConversionService,
          ),
          recurringTransactionExecutionServiceProvider.overrideWithValue(
            recurringTransactionExecutionService,
          ),
        ],
        child: MaterialApp(home: home),
      ),
    );
    await tester.pumpAndSettle();
  }
}

class TestSettingsRepository implements SettingsRepository {
  TestSettingsRepository(this._settings);

  final TestBoxListenable _listenable = TestBoxListenable();
  AppSettings _settings;

  @override
  AppSettings getSettings() => _settings;

  @override
  ValueListenable<Box<dynamic>> listenable() => _listenable;

  @override
  Future<void> updateDefaultCurrencyCode(String code) async {
    _settings = _settings.copyWith(defaultCurrencyCode: code);
    _listenable.emitChange();
  }

  @override
  Future<void> updateDisplayName(String name) async {
    _settings = _settings.copyWith(displayName: name);
    _listenable.emitChange();
  }

  @override
  Future<void> updateFinancialCycleDay(int day) async {
    _settings = _settings.copyWith(financialCycleDay: day);
    _listenable.emitChange();
  }

  @override
  Future<void> updateThemePreference(AppThemePreference preference) async {
    _settings = _settings.copyWith(themePreference: preference);
    _listenable.emitChange();
  }
}

class TestAccountRepository implements AccountRepository {
  TestAccountRepository(List<Account> accounts)
    : accounts = List<Account>.from(accounts);

  final TestBoxListenable _listenable = TestBoxListenable();
  final List<Account> accounts;

  @override
  Future<void> addAccount(Account account) async {
    accounts.add(account);
    _listenable.emitChange();
  }

  @override
  String createAccountId() => 'generated-account-id';

  @override
  Future<void> deleteAccount(String accountId) async {
    accounts.removeWhere((account) => account.id == accountId);
    _listenable.emitChange();
  }

  @override
  Future<List<Account>> getAccounts() async => List<Account>.from(accounts);

  @override
  ValueListenable<Box<dynamic>> listenable() => _listenable;

  @override
  Future<void> reorderAccounts(List<Account> nextAccounts) async {
    accounts
      ..clear()
      ..addAll(nextAccounts);
    _listenable.emitChange();
  }

  @override
  Future<void> updateAccount(Account account) async {
    final index = accounts.indexWhere((item) => item.id == account.id);
    if (index != -1) {
      accounts[index] = account;
      _listenable.emitChange();
    }
  }
}

class TestCategoryRepository implements CategoryRepository {
  TestCategoryRepository(List<CategoryItem> categories)
    : categories = List<CategoryItem>.from(categories);

  final TestBoxListenable _listenable = TestBoxListenable();
  final List<CategoryItem> categories;

  @override
  Future<void> addCategory(CategoryItem category) async {
    categories.add(category);
    _listenable.emitChange();
  }

  @override
  Future<void> deleteCategory(String categoryId) async {
    categories.removeWhere((category) => category.id == categoryId);
    _listenable.emitChange();
  }

  @override
  Future<List<CategoryItem>> getCategories() async {
    return List<CategoryItem>.from(categories);
  }

  @override
  ValueListenable<Box<dynamic>> listenable() => _listenable;

  @override
  Future<void> updateCategory(CategoryItem category) async {
    final index = categories.indexWhere((item) => item.id == category.id);
    if (index != -1) {
      categories[index] = category;
      _listenable.emitChange();
    }
  }
}

class TestTransactionRepository implements TransactionRepository {
  TestTransactionRepository(List<TransactionItem> transactions)
    : transactions = List<TransactionItem>.from(transactions);

  final TestBoxListenable _listenable = TestBoxListenable();
  final List<TransactionItem> transactions;

  @override
  Future<void> addTransaction(TransactionItem transaction) async {
    transactions.add(transaction);
    _listenable.emitChange();
  }

  @override
  String createTransactionId() => 'generated-transaction-id';

  @override
  Future<void> deleteTransaction(String transactionId) async {
    transactions.removeWhere((transaction) => transaction.id == transactionId);
    _listenable.emitChange();
  }

  @override
  Future<List<TransactionItem>> getTransactions() async {
    return List<TransactionItem>.from(transactions);
  }

  @override
  ValueListenable<Box<dynamic>> listenable() => _listenable;

  @override
  Future<void> updateTransaction(TransactionItem transaction) async {
    final index = transactions.indexWhere((item) => item.id == transaction.id);
    if (index != -1) {
      transactions[index] = transaction;
      _listenable.emitChange();
    }
  }
}

class TestRecurringTransactionRepository
    implements RecurringTransactionRepository {
  TestRecurringTransactionRepository(
    List<RecurringTransaction> recurringTransactions,
  ) : recurringTransactions = List<RecurringTransaction>.from(
        recurringTransactions,
      );

  final TestBoxListenable _listenable = TestBoxListenable();
  final List<RecurringTransaction> recurringTransactions;

  @override
  Future<void> addRecurringTransaction(
    RecurringTransaction recurringTransaction,
  ) async {
    recurringTransactions.add(recurringTransaction);
    _listenable.emitChange();
  }

  @override
  String createRecurringTransactionId() => 'generated-recurring-id';

  @override
  Future<void> deleteRecurringTransaction(String recurringTransactionId) async {
    recurringTransactions.removeWhere(
      (transaction) => transaction.id == recurringTransactionId,
    );
    _listenable.emitChange();
  }

  @override
  Future<List<RecurringTransaction>> getRecurringTransactions() async {
    return List<RecurringTransaction>.from(recurringTransactions);
  }

  @override
  ValueListenable<Box<dynamic>> listenable() => _listenable;

  @override
  Future<void> updateRecurringTransaction(
    RecurringTransaction recurringTransaction,
  ) async {
    final index = recurringTransactions.indexWhere(
      (item) => item.id == recurringTransaction.id,
    );
    if (index != -1) {
      recurringTransactions[index] = recurringTransaction;
      _listenable.emitChange();
    }
  }
}

class TestTransactionBalanceService implements TransactionBalanceService {
  TestTransactionBalanceService({
    required this.transactionRepository,
    this.deleteError,
    this.skipDelete = false,
  });

  final TestTransactionRepository transactionRepository;
  final Object? deleteError;
  final bool skipDelete;
  int deleteCallCount = 0;
  final List<String> deletedTransactionIds = [];

  @override
  Future<void> deleteTransaction(
    String transactionId, {
    required TransactionItem? existingTransaction,
    required List<Account> currentAccounts,
  }) async {
    deleteCallCount += 1;
    deletedTransactionIds.add(transactionId);

    final error = deleteError;
    if (error != null) {
      throw error;
    }

    if (skipDelete) {
      return;
    }

    await transactionRepository.deleteTransaction(transactionId);
  }

  @override
  Future<void> deleteTransactions(
    List<TransactionItem> transactions, {
    required List<Account> currentAccounts,
  }) async {
    for (final transaction in transactions) {
      await deleteTransaction(
        transaction.id,
        existingTransaction: transaction,
        currentAccounts: currentAccounts,
      );
    }
  }

  @override
  Future<void> saveTransaction(
    TransactionItem transaction, {
    required bool isEditing,
    TransactionItem? previousTransaction,
    required List<Account> currentAccounts,
    List<CategoryItem> currentCategories = const [],
  }) async {}
}

class TestRecurringTransactionExecutionService
    implements RecurringTransactionExecutionService {
  const TestRecurringTransactionExecutionService();

  @override
  Future<bool> confirmNextDueOccurrence({
    required RecurringTransaction recurringTransaction,
    required List<Account> currentAccounts,
    required DateTime now,
    required String Function() createTransactionId,
  }) async {
    return false;
  }

  @override
  Future<bool> processAutomaticTransactions({
    required List<RecurringTransaction> recurringTransactions,
    required List<Account> currentAccounts,
    required DateTime now,
    required String Function() createTransactionId,
  }) async {
    return false;
  }
}

class TestCurrencyConversionService implements CurrencyConversionService {
  const TestCurrencyConversionService();

  @override
  Future<Map<String, double?>> latestRatesToCurrency({
    required Set<String> fromCurrencyCodes,
    required String toCurrencyCode,
    required DateTime date,
  }) async {
    return {
      for (final currencyCode in fromCurrencyCodes)
        currencyCode.trim().toUpperCase(): 1,
    };
  }

  @override
  Future<double?> tryConvertAmount({
    required double amount,
    required String fromCurrencyCode,
    required String toCurrencyCode,
    required DateTime date,
  }) async {
    return amount;
  }
}

class TestBoxListenable extends ChangeNotifier
    implements ValueListenable<Box<dynamic>> {
  @override
  Box<dynamic> get value => throw UnimplementedError();

  void emitChange() => notifyListeners();
}

Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pump();
}

Future<void> longPressVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.longPress(finder);
  await tester.pumpAndSettle();
}

Future<void> confirmDeleteDialog(WidgetTester tester) async {
  await tapVisible(
    tester,
    find.descendant(
      of: find.byType(AlertDialog),
      matching: find.text('Delete'),
    ),
  );
  await tester.pumpAndSettle();
}

Future<Object?> confirmDeleteDialogCapturingException(
  WidgetTester tester,
) async {
  return captureAsyncError(() async {
    await tapVisible(
      tester,
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Delete'),
      ),
    );
    await tester.pumpAndSettle();
  });
}

Future<void> cancelDeleteDialog(WidgetTester tester) async {
  await tapVisible(
    tester,
    find.descendant(
      of: find.byType(AlertDialog),
      matching: find.widgetWithText(TextButton, 'Cancel'),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> openContextDeleteAction(
  WidgetTester tester,
  String transactionTitle,
) async {
  await longPressVisible(tester, find.text(transactionTitle));
  await tapVisible(tester, find.text('Delete'));
  await tester.pumpAndSettle();
}

Finder listTileWithText(String text) {
  return find.ancestor(of: find.text(text), matching: find.byType(ListTile));
}

Future<Object?> captureAsyncError(Future<void> Function() action) async {
  Object? capturedError;

  await runZonedGuarded(
    () async {
      await action();
    },
    (error, stackTrace) {
      capturedError ??= error;
    },
  );

  return capturedError;
}

Future<void> selectHistoryExpenseFilter(WidgetTester tester) async {
  await tapVisible(tester, find.byTooltip('Filter'));
  await tester.pumpAndSettle();
  await tapVisible(tester, find.text('Expenses'));
  await tester.pumpAndSettle();
}

Future<void> selectHistoryOldestFirstSort(WidgetTester tester) async {
  await tapVisible(tester, find.byTooltip('Sort'));
  await tester.pumpAndSettle();
  await tapVisible(tester, find.text('Oldest first'));
  await tester.pumpAndSettle();
}

Future<void> enterHistorySearchQuery(WidgetTester tester, String query) async {
  final finder = find.byType(TextField);
  await tester.ensureVisible(finder);
  await tester.enterText(finder, query);
  await tester.pumpAndSettle();
}

Account walletAccount() {
  return const Account(
    id: 'account-wallet',
    name: 'Wallet',
    type: AccountType.bank,
    openingBalance: 0,
    currencyCode: 'EUR',
  );
}

Account travelAccount() {
  return const Account(
    id: 'account-travel',
    name: 'Travel',
    type: AccountType.bank,
    openingBalance: 0,
    currencyCode: 'EUR',
  );
}

CategoryItem foodCategory() {
  return const CategoryItem(
    id: 'category-food',
    name: 'Food',
    description: '',
    type: CategoryType.expense,
    icon: Icons.restaurant_outlined,
  );
}

CategoryItem salaryCategory() {
  return const CategoryItem(
    id: 'category-salary',
    name: 'Salary',
    description: '',
    type: CategoryType.income,
    icon: Icons.payments_outlined,
  );
}

TransactionItem expenseTransaction({
  required String id,
  required String title,
  required DateTime date,
  double amount = 12.5,
}) {
  return TransactionItem(
    id: id,
    title: title,
    amount: amount,
    currencyCode: 'EUR',
    date: date,
    type: TransactionType.expense,
    accountId: 'account-wallet',
    categoryId: 'category-food',
  );
}

TransactionItem incomeTransaction({
  required String id,
  required String title,
  required DateTime date,
  double amount = 1000,
}) {
  return TransactionItem(
    id: id,
    title: title,
    amount: amount,
    currencyCode: 'EUR',
    date: date,
    type: TransactionType.income,
    accountId: 'account-wallet',
    categoryId: 'category-salary',
  );
}

DateTime daysAgo(int days) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day - days, 12);
}
