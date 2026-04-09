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
    accountRepository = InMemoryAccountRepository([
      _account(
        id: 'primary-account',
        name: 'Primary checking',
        currencyCode: 'EUR',
        isPrimary: true,
      ),
      _account(
        id: 'travel-account',
        name: 'Travel wallet',
        currencyCode: 'GBP',
      ),
    ]);
    categoryRepository = InMemoryCategoryRepository([_category()]);
    transactionRepository = InMemoryTransactionRepository();
    recurringTransactionRepository = InMemoryRecurringTransactionRepository();
    transactionBalanceService = RecordingTransactionBalanceService();
  });

  Future<void> pumpHost(
    WidgetTester tester, {
    TransactionItem? initialTransaction,
  }) async {
    await tester.binding.setSurfaceSize(const Size(430, 1400));
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
          home: AccountRequirementHost(initialTransaction: initialTransaction),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('add transaction account requirement', () {
    testWidgets(
      'create selects the preferred account by default and uses it when saving',
      (tester) async {
        await pumpHost(tester);
        await _openAddTransactionPage(tester);
        await _fillValidForm(tester);

        await _tapVisible(
          tester,
          find.widgetWithText(FilledButton, 'Save transaction'),
        );
        await tester.pumpAndSettle();

        expect(transactionBalanceService.saveCallCount, 1);
        expect(
          transactionBalanceService.saveInputs.single.accountId,
          'primary-account',
        );
        expect(transactionBalanceService.saveInputs.single.currencyCode, 'EUR');
      },
    );

    testWidgets(
      'create lets the user change the selected account and updates the transaction context',
      (tester) async {
        await pumpHost(tester);
        await _openAddTransactionPage(tester);
        await _selectAccount(
          tester,
          currentLabel: 'Primary checking',
          nextLabel: 'Travel wallet',
        );
        await _fillValidForm(tester);

        await _tapVisible(
          tester,
          find.widgetWithText(FilledButton, 'Save transaction'),
        );
        await tester.pumpAndSettle();

        expect(transactionBalanceService.saveCallCount, 1);
        expect(
          transactionBalanceService.saveInputs.single.accountId,
          'travel-account',
        );
        expect(transactionBalanceService.saveInputs.single.currencyCode, 'GBP');
      },
    );

    testWidgets(
      'edit preloads the existing transaction account instead of replacing it with the preferred one',
      (tester) async {
        final existingTransaction = _transaction(
          id: 'cafd3d07-d1dd-4363-8476-764d426e9e57',
          title: 'Dinner',
          amount: 1800,
          accountId: 'travel-account',
          currencyCode: 'GBP',
        );

        await pumpHost(tester, initialTransaction: existingTransaction);
        await _openAddTransactionPage(tester);
        await _enterTextVisible(
          tester,
          find.byType(TextField).first,
          'Dinner updated',
        );

        await _tapVisible(
          tester,
          find.widgetWithText(FilledButton, 'Save changes'),
        );
        await tester.pumpAndSettle();

        expect(transactionBalanceService.saveCallCount, 1);
        expect(
          transactionBalanceService.saveInputs.single.accountId,
          'travel-account',
        );
        expect(transactionBalanceService.saveInputs.single.currencyCode, 'GBP');
      },
    );

    testWidgets(
      'edit with a stale account reference does not silently fall back to another account',
      (tester) async {
        accountRepository = InMemoryAccountRepository([
          _account(
            id: 'primary-account',
            name: 'Primary checking',
            currencyCode: 'EUR',
            isPrimary: true,
          ),
        ]);
        final existingTransaction = _transaction(
          id: '8d11bfab-1b1e-4e69-bb40-0f6aa96164f0',
          accountId: 'missing-account',
        );

        await pumpHost(tester, initialTransaction: existingTransaction);
        await _openAddTransactionPage(tester);
        await _tapVisible(
          tester,
          find.widgetWithText(FilledButton, 'Save changes'),
        );
        await tester.pumpAndSettle();

        expect(find.text('Please choose an account.'), findsOneWidget);
        expect(transactionBalanceService.saveCallCount, 0);
      },
    );

    testWidgets('no accounts state is explicit and safe on create', (
      tester,
    ) async {
      accountRepository = InMemoryAccountRepository(const []);

      await pumpHost(tester);
      await _openAddTransactionPage(tester);

      expect(
        find.text(
          'You need at least one account before you can register a transaction.',
        ),
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
      expect(transactionBalanceService.saveCallCount, 0);
    });
  });
}

class AccountRequirementHost extends ConsumerWidget {
  const AccountRequirementHost({super.key, this.initialTransaction});

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

Future<void> _fillValidForm(WidgetTester tester) async {
  await _enterTextVisible(tester, find.byType(TextField).first, 'Lunch');
  await _enterTextVisible(tester, find.byType(TextField).at(1), '12.50');
  await _selectCategory(tester, 'Food');
}

Future<void> _selectCategory(WidgetTester tester, String categoryName) async {
  await _tapDropdownTrigger(tester, find.text('Choose a category'));
  await tester.pumpAndSettle();
  await _tapDropdownOption(tester, find.text(categoryName).last);
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

class RecordingTransactionBalanceService extends TransactionBalanceService {
  RecordingTransactionBalanceService()
    : super(
        currencyConversionService: MockCurrencyConversionService(),
        transactionRepository: InMemoryTransactionRepository(),
      );

  int saveCallCount = 0;
  final List<TransactionItem> saveInputs = [];
  final List<List<Account>> saveCurrentAccounts = [];

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
    saveCurrentAccounts.add(List<Account>.from(currentAccounts));
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
  String id = '64089b0a-dc74-4dfc-b122-0d49b5575a1a',
  String title = 'Lunch',
  double amount = 1250,
  String accountId = 'primary-account',
  String currencyCode = 'EUR',
}) {
  return TransactionItem(
    id: id,
    title: title,
    amount: amount,
    currencyCode: currencyCode,
    date: DateTime(2026, 4, 8),
    type: TransactionType.expense,
    accountId: accountId,
    categoryId: 'category-1',
  );
}
