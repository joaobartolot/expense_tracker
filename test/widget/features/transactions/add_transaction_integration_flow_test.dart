import 'package:expense_tracker/app/state/app_state_dependencies.dart';
import 'package:expense_tracker/app/state/app_state_provider.dart';
import 'package:expense_tracker/features/accounts/data/account_repository.dart';
import 'package:expense_tracker/features/accounts/domain/models/account.dart';
import 'package:expense_tracker/features/categories/data/category_repository.dart';
import 'package:expense_tracker/features/categories/domain/models/category_item.dart';
import 'package:expense_tracker/features/recurring_transactions/data/recurring_transaction_repository.dart';
import 'package:expense_tracker/features/recurring_transactions/domain/models/recurring_transaction.dart';
import 'package:expense_tracker/features/settings/data/settings_repository.dart';
import 'package:expense_tracker/features/settings/domain/models/app_settings.dart';
import 'package:expense_tracker/features/settings/domain/models/app_theme_preference.dart';
import 'package:expense_tracker/features/transactions/data/exchange_rate_service.dart';
import 'package:expense_tracker/features/transactions/data/transaction_repository.dart';
import 'package:expense_tracker/features/transactions/domain/models/transaction_item.dart';
import 'package:expense_tracker/features/transactions/presentation/pages/add_transaction_page.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

void main() {
  late InMemorySettingsRepository settingsRepository;
  late InMemoryAccountRepository accountRepository;
  late InMemoryCategoryRepository categoryRepository;
  late TrackingTransactionRepository transactionRepository;
  late InMemoryRecurringTransactionRepository recurringTransactionRepository;
  late FixedExchangeRateService exchangeRateService;

  setUp(() {
    settingsRepository = InMemorySettingsRepository(
      const AppSettings(
        displayName: '',
        themePreference: AppThemePreference.system,
        defaultCurrencyCode: 'EUR',
        financialCycleDay: 1,
      ),
    );
    accountRepository = InMemoryAccountRepository([
      _account(
        id: 'account-main',
        name: 'Main wallet',
        currencyCode: 'EUR',
        isPrimary: true,
      ),
      _account(id: 'account-cash', name: 'Cash', currencyCode: 'EUR'),
    ]);
    categoryRepository = InMemoryCategoryRepository([
      _category(id: 'expense-food', name: 'Food', type: CategoryType.expense),
      _category(
        id: 'expense-transport',
        name: 'Transport',
        type: CategoryType.expense,
      ),
      _category(id: 'income-salary', name: 'Salary', type: CategoryType.income),
    ]);
    transactionRepository = TrackingTransactionRepository();
    recurringTransactionRepository = InMemoryRecurringTransactionRepository();
    exchangeRateService = const FixedExchangeRateService({
      'USD:EUR': 0.8,
      'EUR:USD': 1.25,
    });
  });

  Future<void> pumpHost(
    WidgetTester tester, {
    TransactionItem? initialTransaction,
  }) async {
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
          exchangeRateServiceProvider.overrideWithValue(exchangeRateService),
        ],
        child: MaterialApp(
          home: IntegrationFlowHost(
            initialTransaction: initialTransaction,
            exchangeRateService: exchangeRateService,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('add transaction integration flow', () {
    testWidgets(
      'create flow preserves decimal amounts instead of rounding to whole units',
      (tester) async {
        await pumpHost(tester);
        await _openAddTransactionPage(tester);
        await _enterTextVisible(tester, find.byType(TextField).first, 'Coffee');
        await _enterTextVisible(tester, find.byType(TextField).at(1), '1.23');
        await _selectCategory(
          tester,
          triggerLabel: 'Choose a category',
          optionLabel: 'Food',
        );

        await _tapVisible(
          tester,
          find.widgetWithText(FilledButton, 'Save transaction'),
        );
        await tester.pumpAndSettle();

        expect(transactionRepository.transactions, hasLength(1));
        expect(
          transactionRepository.transactions.single.amount,
          closeTo(1.23, 0.0001),
        );
      },
    );

    testWidgets(
      'create flow persists a normalized transaction through app state and updates visible state',
      (tester) async {
        await pumpHost(tester);
        await _openAddTransactionPage(tester);
        await _enterTextVisible(tester, find.byType(TextField).first, 'Lunch');
        await _enterTextVisible(tester, find.byType(TextField).at(1), '12.50');
        await _selectCategory(
          tester,
          triggerLabel: 'Choose a category',
          optionLabel: 'Food',
        );
        await _toggleAdvancedFields(tester);
        await _selectEntryCurrency(tester, currentLabel: 'EUR · Euro');

        await _tapVisible(
          tester,
          find.widgetWithText(FilledButton, 'Save transaction'),
        );
        await tester.pumpAndSettle();

        expect(find.text('Host home'), findsOneWidget);
        expect(find.text('Visible transaction count: 1'), findsOneWidget);
        expect(
          find.textContaining('Visible transaction: Lunch'),
          findsOneWidget,
        );
        expect(transactionRepository.addCallCount, 1);
        expect(transactionRepository.updateCallCount, 0);
        expect(transactionRepository.transactions, hasLength(1));

        final persisted = transactionRepository.transactions.single;
        expect(persisted.id, 'generated-transaction-id');
        expect(persisted.title, 'Lunch');
        expect(persisted.type, TransactionType.expense);
        expect(persisted.accountId, 'account-main');
        expect(persisted.categoryId, 'expense-food');
        expect(persisted.currencyCode, 'EUR');
        expect(persisted.foreignCurrencyCode, 'USD');
        expect(persisted.foreignAmount, isNotNull);
        expect(persisted.exchangeRate, closeTo(0.8, 0.0001));
      },
    );

    testWidgets(
      'edit flow updates the existing transaction through app state without creating a duplicate',
      (tester) async {
        final existingTransaction = _transaction(
          id: 'existing-transaction-id',
          title: 'Old lunch',
          amount: 1250,
          accountId: 'account-main',
          categoryId: 'expense-food',
        );
        transactionRepository.transactions.add(existingTransaction);

        await pumpHost(tester, initialTransaction: existingTransaction);
        await tester.pumpAndSettle();
        await _openAddTransactionPage(tester);
        await _enterTextVisible(
          tester,
          find.byType(TextField).first,
          'Updated lunch',
        );
        await _selectAccount(
          tester,
          currentLabel: 'Main wallet',
          nextLabel: 'Cash',
        );
        await _selectCategory(
          tester,
          triggerLabel: 'Food',
          optionLabel: 'Transport',
        );

        await _tapVisible(
          tester,
          find.widgetWithText(FilledButton, 'Save changes'),
        );
        await tester.pumpAndSettle();

        expect(find.text('Host home'), findsOneWidget);
        expect(find.text('Visible transaction count: 1'), findsOneWidget);
        expect(
          find.textContaining('Visible transaction: Updated lunch'),
          findsOneWidget,
        );
        expect(transactionRepository.addCallCount, 0);
        expect(transactionRepository.updateCallCount, 1);
        expect(transactionRepository.transactions, hasLength(1));

        final persisted = transactionRepository.transactions.single;
        expect(persisted.id, existingTransaction.id);
        expect(persisted.title, 'Updated lunch');
        expect(persisted.accountId, 'account-cash');
        expect(persisted.categoryId, 'expense-transport');
      },
    );

    testWidgets(
      'validation failure blocks persistence through the full create flow',
      (tester) async {
        await pumpHost(tester);
        await _openAddTransactionPage(tester);
        await _enterTextVisible(tester, find.byType(TextField).at(1), '12.50');
        await _selectCategory(
          tester,
          triggerLabel: 'Choose a category',
          optionLabel: 'Food',
        );

        await _tapVisible(
          tester,
          find.widgetWithText(FilledButton, 'Save transaction'),
        );
        await tester.pumpAndSettle();

        expect(find.text('Add transaction'), findsOneWidget);
        expect(find.text('Host home'), findsNothing);
        expect(
          find.text('Please enter a name for the transaction.'),
          findsOneWidget,
        );
        expect(transactionRepository.addCallCount, 0);
        expect(transactionRepository.updateCallCount, 0);
        expect(transactionRepository.transactions, isEmpty);
      },
    );

    testWidgets(
      'stale edit account references are blocked through the full flow and leave persisted state unchanged',
      (tester) async {
        final existingTransaction = _transaction(
          id: 'stale-account-transaction',
          title: 'Existing lunch',
          amount: 1250,
          accountId: 'missing-account',
          categoryId: 'expense-food',
        );
        transactionRepository.transactions.add(existingTransaction);

        await pumpHost(tester, initialTransaction: existingTransaction);
        await _openAddTransactionPage(tester);
        await _tapVisible(
          tester,
          find.widgetWithText(FilledButton, 'Save changes'),
        );
        await tester.pumpAndSettle();

        expect(find.text('Edit transaction'), findsOneWidget);
        expect(find.text('Please choose an account.'), findsOneWidget);
        expect(transactionRepository.updateCallCount, 0);
        expect(transactionRepository.transactions, [existingTransaction]);
      },
    );

    testWidgets(
      'repository failure propagates through the full create flow without success state changes',
      (tester) async {
        transactionRepository.addError = StateError('Storage failure');

        await pumpHost(tester);
        await _openAddTransactionPage(tester);
        await _enterTextVisible(tester, find.byType(TextField).first, 'Lunch');
        await _enterTextVisible(tester, find.byType(TextField).at(1), '12.50');
        await _selectCategory(
          tester,
          triggerLabel: 'Choose a category',
          optionLabel: 'Food',
        );

        await _tapVisible(
          tester,
          find.widgetWithText(FilledButton, 'Save transaction'),
        );
        await tester.pumpAndSettle();

        expect(find.text('Add transaction'), findsOneWidget);
        expect(find.text('Host home'), findsNothing);
        expect(
          find.text('Could not save the transaction. Please try again.'),
          findsOneWidget,
        );
        expect(transactionRepository.addCallCount, 1);
        expect(transactionRepository.transactions, isEmpty);
      },
    );
  });
}

class IntegrationFlowHost extends ConsumerWidget {
  const IntegrationFlowHost({
    super.key,
    this.initialTransaction,
    required this.exchangeRateService,
  });

  final TransactionItem? initialTransaction;
  final ExchangeRateService exchangeRateService;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appStateProvider);

    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Host home'),
            Text('Visible transaction count: ${state.transactions.length}'),
            for (final transaction in state.transactions)
              Text(
                'Visible transaction: ${transaction.title} (${transaction.id})',
              ),
            FilledButton(
              onPressed: () {
                Navigator.of(context).push<void>(
                  MaterialPageRoute(
                    builder: (_) => initialTransaction == null
                        ? AddTransactionPage(
                            exchangeRateService: exchangeRateService,
                          )
                        : AddTransactionPage(
                            initialTransaction: initialTransaction,
                            exchangeRateService: exchangeRateService,
                          ),
                  ),
                );
              },
              child: const Text('Open add transaction'),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> _openAddTransactionPage(WidgetTester tester) async {
  await _tapVisible(
    tester,
    find.widgetWithText(FilledButton, 'Open add transaction'),
  );
  await tester.pumpAndSettle();
}

Future<void> _selectCategory(
  WidgetTester tester, {
  required String triggerLabel,
  required String optionLabel,
}) async {
  await _tapDropdownTrigger(tester, find.text(triggerLabel));
  await tester.pumpAndSettle();
  await _tapDropdownOption(tester, find.text(optionLabel).last);
  await tester.pumpAndSettle();
}

Future<void> _selectAccount(
  WidgetTester tester, {
  required String currentLabel,
  required String nextLabel,
}) async {
  final currentSelection = find.text(currentLabel);
  if (currentSelection.evaluate().isNotEmpty) {
    await _tapDropdownTrigger(tester, currentSelection.first);
  } else {
    await _tapDropdownTrigger(tester, find.text('Choose an account'));
  }
  await tester.pumpAndSettle();
  await _tapDropdownOption(tester, find.text(nextLabel).last);
  await tester.pumpAndSettle();
}

Future<void> _toggleAdvancedFields(WidgetTester tester) async {
  await _tapVisible(tester, find.text('Advanced'));
  await tester.pumpAndSettle();
}

Future<void> _selectEntryCurrency(
  WidgetTester tester, {
  required String currentLabel,
}) async {
  await _tapDropdownTrigger(tester, find.text(currentLabel));
  await tester.pumpAndSettle();
  await _tapDropdownOption(tester, find.text('USD · US Dollar').last);
  await tester.pumpAndSettle();
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pumpAndSettle();
}

Future<void> _tapDropdownTrigger(WidgetTester tester, Finder textFinder) async {
  final trigger = find.ancestor(of: textFinder, matching: find.byType(InkWell));
  await _tapVisible(tester, trigger.first);
}

Future<void> _tapDropdownOption(WidgetTester tester, Finder textFinder) async {
  final option = find.ancestor(of: textFinder, matching: find.byType(InkWell));
  await _tapVisible(tester, option.last);
}

Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  final scrollables = find.byType(Scrollable);
  if (scrollables.evaluate().isNotEmpty) {
    await tester.scrollUntilVisible(finder, 200, scrollable: scrollables.first);
  } else {
    await tester.ensureVisible(finder);
  }
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pump();
}

Future<void> _enterTextVisible(
  WidgetTester tester,
  Finder finder,
  String text,
) async {
  final scrollables = find.byType(Scrollable);
  if (scrollables.evaluate().isNotEmpty) {
    await tester.scrollUntilVisible(finder, 200, scrollable: scrollables.first);
  } else {
    await tester.ensureVisible(finder);
  }
  await tester.pumpAndSettle();
  await tester.enterText(finder, text);
  await tester.pumpAndSettle();
}

class InMemorySettingsRepository implements SettingsRepository {
  InMemorySettingsRepository(this._settings);

  final DummyBoxListenable _listenable = DummyBoxListenable();
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

class InMemoryAccountRepository implements AccountRepository {
  InMemoryAccountRepository(List<Account> accounts)
    : accounts = List<Account>.from(accounts);

  final DummyBoxListenable _listenable = DummyBoxListenable();
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
  Future<List<Account>> getAccounts() async {
    return List<Account>.from(accounts);
  }

  @override
  ValueListenable<Box<dynamic>> listenable() => _listenable;

  @override
  Future<void> reorderAccounts(List<Account> orderedAccounts) async {
    accounts
      ..clear()
      ..addAll(orderedAccounts);
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

class InMemoryCategoryRepository implements CategoryRepository {
  InMemoryCategoryRepository(List<CategoryItem> categories)
    : categories = List<CategoryItem>.from(categories);

  final DummyBoxListenable _listenable = DummyBoxListenable();
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

class TrackingTransactionRepository implements TransactionRepository {
  final DummyBoxListenable _listenable = DummyBoxListenable();
  final List<TransactionItem> transactions = [];

  int addCallCount = 0;
  int updateCallCount = 0;
  Object? addError;
  Object? updateError;

  @override
  Future<void> addTransaction(TransactionItem transaction) async {
    addCallCount += 1;
    final error = addError;
    if (error != null) {
      throw error;
    }

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
    updateCallCount += 1;
    final error = updateError;
    if (error != null) {
      throw error;
    }

    final index = transactions.indexWhere((item) => item.id == transaction.id);
    if (index == -1) {
      throw StateError('Transaction ${transaction.id} was not found.');
    }

    transactions[index] = transaction;
    _listenable.emitChange();
  }
}

class InMemoryRecurringTransactionRepository
    implements RecurringTransactionRepository {
  final DummyBoxListenable _listenable = DummyBoxListenable();
  final List<RecurringTransaction> recurringTransactions = [];

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

class DummyBoxListenable extends ChangeNotifier
    implements ValueListenable<Box<dynamic>> {
  void emitChange() {
    notifyListeners();
  }

  @override
  Box<dynamic> get value => throw UnimplementedError();
}

class FixedExchangeRateService extends ExchangeRateService {
  const FixedExchangeRateService(this._rates);

  final Map<String, double> _rates;

  @override
  Future<double> fetchExchangeRate({
    required String fromCurrencyCode,
    required String toCurrencyCode,
    required DateTime date,
  }) async {
    final normalizedFrom = fromCurrencyCode.trim().toUpperCase();
    final normalizedTo = toCurrencyCode.trim().toUpperCase();
    if (normalizedFrom == normalizedTo) {
      return 1;
    }

    final rate = _rates['$normalizedFrom:$normalizedTo'];
    if (rate == null) {
      throw const ExchangeRateLookupException('Missing test exchange rate.');
    }

    return rate;
  }
}

Account _account({
  required String id,
  required String name,
  required String currencyCode,
  bool isPrimary = false,
}) {
  return Account(
    id: id,
    name: name,
    type: AccountType.bank,
    openingBalance: 0,
    currencyCode: currencyCode,
    isPrimary: isPrimary,
  );
}

CategoryItem _category({
  required String id,
  required String name,
  required CategoryType type,
}) {
  return CategoryItem(
    id: id,
    name: name,
    description: '',
    type: type,
    icon: Icons.category_outlined,
  );
}

TransactionItem _transaction({
  required String id,
  required String title,
  required double amount,
  required String accountId,
  required String categoryId,
}) {
  return TransactionItem(
    id: id,
    title: title,
    amount: amount,
    currencyCode: 'EUR',
    date: DateTime(2026, 4, 8),
    type: TransactionType.expense,
    accountId: accountId,
    categoryId: categoryId,
  );
}
