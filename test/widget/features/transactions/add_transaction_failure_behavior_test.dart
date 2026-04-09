import 'package:expense_tracker/app/state/app_state_dependencies.dart';
import 'package:expense_tracker/app/state/app_state_provider.dart';
import 'package:expense_tracker/core/utils/currency_conversion_service.dart';
import 'package:expense_tracker/features/accounts/data/account_repository.dart';
import 'package:expense_tracker/features/accounts/domain/models/account.dart';
import 'package:expense_tracker/features/categories/data/category_repository.dart';
import 'package:expense_tracker/features/categories/domain/models/category_item.dart';
import 'package:expense_tracker/features/recurring_transactions/data/recurring_transaction_repository.dart';
import 'package:expense_tracker/features/recurring_transactions/domain/models/recurring_transaction.dart';
import 'package:expense_tracker/features/settings/data/settings_repository.dart';
import 'package:expense_tracker/features/settings/domain/models/app_settings.dart';
import 'package:expense_tracker/features/settings/domain/models/app_theme_preference.dart';
import 'package:expense_tracker/features/transactions/data/transaction_repository.dart';
import 'package:expense_tracker/features/transactions/domain/models/transaction_item.dart';
import 'package:expense_tracker/features/transactions/domain/services/transaction_balance_service.dart';
import 'package:expense_tracker/features/transactions/presentation/pages/add_transaction_page.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:mocktail/mocktail.dart';

void main() {
  late InMemorySettingsRepository settingsRepository;
  late InMemoryAccountRepository accountRepository;
  late InMemoryCategoryRepository categoryRepository;
  late InMemoryTransactionRepository transactionRepository;
  late InMemoryRecurringTransactionRepository recurringTransactionRepository;
  late ControlledTransactionBalanceService transactionBalanceService;

  setUpAll(() {
    registerFallbackValue(_transaction());
  });

  setUp(() {
    settingsRepository = InMemorySettingsRepository(
      const AppSettings(
        displayName: '',
        themePreference: AppThemePreference.system,
        defaultCurrencyCode: 'EUR',
        financialCycleDay: 1,
      ),
    );
    accountRepository = InMemoryAccountRepository([_account()]);
    categoryRepository = InMemoryCategoryRepository([_category()]);
    transactionRepository = InMemoryTransactionRepository();
    recurringTransactionRepository = InMemoryRecurringTransactionRepository();
    transactionBalanceService = ControlledTransactionBalanceService();
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
          transactionBalanceServiceProvider.overrideWithValue(
            transactionBalanceService,
          ),
        ],
        child: MaterialApp(
          home: FailureTestHost(initialTransaction: initialTransaction),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('add transaction failure behavior', () {
    testWidgets(
      'invalid create input stays on the page, shows validation feedback, and does not call save',
      (tester) async {
        await pumpHost(tester);
        await _openAddTransactionPage(tester);

        await _enterTextVisible(tester, find.byType(TextField).at(1), '12.50');
        await _selectCategory(tester, 'Food');

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
        expect(transactionBalanceService.saveCallCount, 0);
        expect(transactionRepository.transactions, isEmpty);
      },
    );

    testWidgets(
      'create failure shows feedback, stays in flow, and repeated attempts do not create duplicates',
      (tester) async {
        transactionBalanceService.saveError = StateError('Storage failure');

        await pumpHost(tester);
        await _openAddTransactionPage(tester);
        await _fillValidCreateForm(tester);

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
        expect(transactionRepository.transactions, isEmpty);

        await _tapVisible(
          tester,
          find.widgetWithText(FilledButton, 'Save transaction'),
        );
        await tester.pumpAndSettle();

        expect(transactionBalanceService.saveCallCount, 2);
        expect(transactionRepository.transactions, isEmpty);
      },
    );

    testWidgets(
      'create failure after valid-looking form state leaves persisted state unchanged and shows failure feedback',
      (tester) async {
        transactionBalanceService.saveError = StateError(
          'Could not resolve the category.',
        );

        await pumpHost(tester);
        await _openAddTransactionPage(tester);
        await _fillValidCreateForm(tester);

        await _tapVisible(
          tester,
          find.widgetWithText(FilledButton, 'Save transaction'),
        );
        await tester.pumpAndSettle();

        expect(find.text('Add transaction'), findsOneWidget);
        expect(
          find.text('Could not save the transaction. Please try again.'),
          findsOneWidget,
        );
        expect(transactionRepository.transactions, isEmpty);
      },
    );

    testWidgets(
      'edit failure preserves the original transaction, stays in flow, and shows failure feedback',
      (tester) async {
        final existingTransaction = _transaction(
          id: '4f87de11-b5b0-4f73-9f50-56865058b789',
          title: 'Original title',
          amount: 1250,
        );
        transactionRepository.transactions.add(existingTransaction);
        transactionBalanceService.saveError = StateError('Update failure');

        await pumpHost(tester, initialTransaction: existingTransaction);
        await _openAddTransactionPage(tester);

        await _enterTextVisible(
          tester,
          find.byType(TextField).first,
          'Updated title',
        );

        await _tapVisible(
          tester,
          find.widgetWithText(FilledButton, 'Save changes'),
        );
        await tester.pumpAndSettle();

        expect(find.text('Edit transaction'), findsOneWidget);
        expect(find.text('Host home'), findsNothing);
        expect(
          find.text('Could not save the transaction. Please try again.'),
          findsOneWidget,
        );
        expect(transactionRepository.transactions, hasLength(1));
        expect(
          transactionRepository.transactions.single.id,
          existingTransaction.id,
        );
        expect(
          transactionRepository.transactions.single.title,
          'Original title',
        );
        expect(
          transactionBalanceService.saveInputs.single.title,
          'Updated title',
        );
      },
    );
  });
}

class FailureTestHost extends ConsumerWidget {
  const FailureTestHost({super.key, this.initialTransaction});

  final TransactionItem? initialTransaction;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(appStateProvider);

    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Host home'),
            FilledButton(
              onPressed: () {
                Navigator.of(context).push<void>(
                  MaterialPageRoute(
                    builder: (_) => initialTransaction == null
                        ? const AddTransactionPage()
                        : AddTransactionPage(
                            initialTransaction: initialTransaction,
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

Future<void> _fillValidCreateForm(WidgetTester tester) async {
  await _enterTextVisible(tester, find.byType(TextField).first, 'Lunch');
  await _enterTextVisible(tester, find.byType(TextField).at(1), '12.50');
  await _selectCategory(tester, 'Food');
}

Future<void> _selectCategory(WidgetTester tester, String categoryName) async {
  await _tapVisible(tester, find.text('Choose a category'));
  await tester.pumpAndSettle();
  await _tapVisible(tester, find.text(categoryName).last);
  await tester.pumpAndSettle();
}

Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pump();
}

Future<void> _enterTextVisible(
  WidgetTester tester,
  Finder finder,
  String text,
) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.enterText(finder, text);
  await tester.pumpAndSettle();
}

class ControlledTransactionBalanceService extends TransactionBalanceService {
  ControlledTransactionBalanceService()
    : super(
        currencyConversionService: MockCurrencyConversionService(),
        transactionRepository: InMemoryTransactionRepository(),
      );

  int saveCallCount = 0;
  final List<TransactionItem> saveInputs = [];
  Object? saveError;

  @override
  Future<void> saveTransaction(
    TransactionItem transaction, {
    required bool isEditing,
    TransactionItem? previousTransaction,
    required List<Account> currentAccounts,
    List<CategoryItem> currentCategories = const [],
  }) async {
    saveCallCount += 1;
    saveInputs.add(transaction);

    final error = saveError;
    if (error != null) {
      throw error;
    }
  }
}

class MockCurrencyConversionService extends Mock
    implements CurrencyConversionService {}

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
  }

  @override
  Future<void> updateDisplayName(String name) async {
    _settings = _settings.copyWith(displayName: name);
  }

  @override
  Future<void> updateFinancialCycleDay(int day) async {
    _settings = _settings.copyWith(financialCycleDay: day);
  }

  @override
  Future<void> updateThemePreference(AppThemePreference preference) async {
    _settings = _settings.copyWith(themePreference: preference);
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
  }

  @override
  String createAccountId() => 'generated-account-id';

  @override
  Future<void> deleteAccount(String accountId) async {
    accounts.removeWhere((account) => account.id == accountId);
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
  }

  @override
  Future<void> updateAccount(Account account) async {
    final index = accounts.indexWhere((item) => item.id == account.id);
    if (index != -1) {
      accounts[index] = account;
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
  }

  @override
  Future<void> deleteCategory(String categoryId) async {
    categories.removeWhere((category) => category.id == categoryId);
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
    }
  }
}

class InMemoryTransactionRepository implements TransactionRepository {
  final DummyBoxListenable _listenable = DummyBoxListenable();
  final List<TransactionItem> transactions = [];

  @override
  Future<void> addTransaction(TransactionItem transaction) async {
    transactions.add(transaction);
  }

  @override
  String createTransactionId() => 'generated-transaction-id';

  @override
  Future<void> deleteTransaction(String transactionId) async {
    transactions.removeWhere((transaction) => transaction.id == transactionId);
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
    }
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
  }

  @override
  String createRecurringTransactionId() => 'generated-recurring-id';

  @override
  Future<void> deleteRecurringTransaction(String recurringTransactionId) async {
    recurringTransactions.removeWhere(
      (transaction) => transaction.id == recurringTransactionId,
    );
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
    }
  }
}

class DummyBoxListenable extends ChangeNotifier
    implements ValueListenable<Box<dynamic>> {
  @override
  Box<dynamic> get value => throw UnimplementedError();
}

Account _account() {
  return const Account(
    id: 'account-1',
    name: 'Wallet',
    type: AccountType.bank,
    openingBalance: 0,
    currencyCode: 'EUR',
  );
}

CategoryItem _category() {
  return const CategoryItem(
    id: 'category-1',
    name: 'Food',
    description: '',
    type: CategoryType.expense,
    icon: Icons.restaurant_outlined,
  );
}

TransactionItem _transaction({
  String id = '5aba8bf0-755b-4b94-bdfd-382f7c89808f',
  String title = 'Lunch',
  double amount = 1250,
  String currencyCode = 'EUR',
}) {
  return TransactionItem(
    id: id,
    title: title,
    amount: amount,
    currencyCode: currencyCode,
    date: DateTime(2026, 4, 8),
    type: TransactionType.expense,
    accountId: 'account-1',
    categoryId: 'category-1',
  );
}
