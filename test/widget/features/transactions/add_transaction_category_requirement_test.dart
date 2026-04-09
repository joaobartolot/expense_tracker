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
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:mocktail/mocktail.dart';

void main() {
  late InMemorySettingsRepository settingsRepository;
  late InMemoryAccountRepository accountRepository;
  late InMemoryCategoryRepository categoryRepository;
  late InMemoryTransactionRepository transactionRepository;
  late InMemoryRecurringTransactionRepository recurringTransactionRepository;
  late RecordingTransactionBalanceService transactionBalanceService;

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
    categoryRepository = InMemoryCategoryRepository([
      _category(
        id: 'expense-category',
        name: 'Food',
        type: CategoryType.expense,
      ),
      _category(
        id: 'income-category',
        name: 'Salary',
        type: CategoryType.income,
      ),
    ]);
    transactionRepository = InMemoryTransactionRepository();
    recurringTransactionRepository = InMemoryRecurringTransactionRepository();
    transactionBalanceService = RecordingTransactionBalanceService();
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
          home: CategoryRequirementHost(initialTransaction: initialTransaction),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('add transaction category requirement', () {
    testWidgets('create requires a category before save', (tester) async {
      await pumpHost(tester);
      await _openAddTransactionPage(tester);
      await _enterTextVisible(tester, find.byType(TextField).first, 'Lunch');
      await _enterTextVisible(tester, find.byType(TextField).at(1), '12.50');

      await _tapVisible(
        tester,
        find.widgetWithText(FilledButton, 'Save transaction'),
      );
      await tester.pumpAndSettle();

      expect(find.text('Please choose a category.'), findsOneWidget);
      expect(transactionBalanceService.saveCallCount, 0);
    });

    testWidgets('edit requires a category before save', (tester) async {
      final existingTransaction = _transaction(
        id: 'b98f20e7-b6c9-4252-b40a-a4b5530d5e74',
        categoryId: 'expense-category',
      );

      await pumpHost(tester, initialTransaction: existingTransaction);
      await _openAddTransactionPage(tester);
      await _switchType(tester, 'Income');
      await _tapVisible(
        tester,
        find.widgetWithText(FilledButton, 'Save changes'),
      );
      await tester.pumpAndSettle();

      expect(find.text('Please choose a category.'), findsOneWidget);
      expect(transactionBalanceService.saveCallCount, 0);
    });

    testWidgets(
      'changing transaction type invalidates an incompatible category selection',
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
        await _switchType(tester, 'Income');

        await _tapVisible(
          tester,
          find.widgetWithText(FilledButton, 'Save transaction'),
        );
        await tester.pumpAndSettle();

        expect(find.text('Please choose a category.'), findsOneWidget);
        expect(transactionBalanceService.saveCallCount, 0);
      },
    );

    testWidgets(
      'edit preloads the existing category only when it remains valid',
      (tester) async {
        final existingTransaction = _transaction(
          id: '0229986f-7084-4dc4-ab7b-52050993c79e',
          categoryId: 'expense-category',
          type: TransactionType.expense,
        );

        await pumpHost(tester, initialTransaction: existingTransaction);
        await _openAddTransactionPage(tester);
        await _enterTextVisible(
          tester,
          find.byType(TextField).first,
          'Lunch updated',
        );
        await _tapVisible(
          tester,
          find.widgetWithText(FilledButton, 'Save changes'),
        );
        await tester.pumpAndSettle();

        expect(transactionBalanceService.saveCallCount, 1);
        expect(
          transactionBalanceService.saveInputs.single.categoryId,
          'expense-category',
        );
      },
    );

    testWidgets('edit does not preload a stale or invalid category selection', (
      tester,
    ) async {
      final existingTransaction = _transaction(
        id: '93f8f8f1-b326-4ce5-bf9f-07c05574d8ec',
        categoryId: 'missing-category',
        type: TransactionType.expense,
      );

      await pumpHost(tester, initialTransaction: existingTransaction);
      await _openAddTransactionPage(tester);
      await _tapVisible(
        tester,
        find.widgetWithText(FilledButton, 'Save changes'),
      );
      await tester.pumpAndSettle();

      expect(find.text('Please choose a category.'), findsOneWidget);
      expect(transactionBalanceService.saveCallCount, 0);
    });

    testWidgets(
      'when no valid categories exist for the selected type save is disabled and guidance is shown',
      (tester) async {
        categoryRepository = InMemoryCategoryRepository([
          _category(
            id: 'income-category',
            name: 'Salary',
            type: CategoryType.income,
          ),
        ]);

        await pumpHost(tester);
        await _openAddTransactionPage(tester);

        expect(find.text('No categories available'), findsOneWidget);
        expect(
          find.text('Create a category for this transaction type.'),
          findsOneWidget,
        );
        expect(
          tester
              .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'Save transaction'),
              )
              .onPressed,
          isNull,
        );
      },
    );
  });
}

class CategoryRequirementHost extends ConsumerWidget {
  const CategoryRequirementHost({super.key, this.initialTransaction});

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

Future<void> _switchType(WidgetTester tester, String label) async {
  await _tapVisible(tester, find.text(label));
  await tester.pumpAndSettle();
}

Future<void> _selectCategory(
  WidgetTester tester, {
  required String triggerLabel,
  required String optionLabel,
}) async {
  await _tapVisible(tester, find.text(triggerLabel));
  await tester.pumpAndSettle();
  await _tapVisible(tester, find.text(optionLabel).last);
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

class RecordingTransactionBalanceService extends TransactionBalanceService {
  RecordingTransactionBalanceService()
    : super(
        currencyConversionService: MockCurrencyConversionService(),
        transactionRepository: InMemoryTransactionRepository(),
      );

  int saveCallCount = 0;
  final List<TransactionItem> saveInputs = [];

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
    icon: Icons.sell_outlined,
  );
}

TransactionItem _transaction({
  String id = '5c1e6f11-072d-4fe3-b1df-8e3b5bcb57d6',
  String title = 'Lunch',
  double amount = 1250,
  String currencyCode = 'EUR',
  TransactionType type = TransactionType.expense,
  String categoryId = 'expense-category',
}) {
  return TransactionItem(
    id: id,
    title: title,
    amount: amount,
    currencyCode: currencyCode,
    date: DateTime(2026, 4, 8),
    type: type,
    accountId: 'account-1',
    categoryId: categoryId,
  );
}
