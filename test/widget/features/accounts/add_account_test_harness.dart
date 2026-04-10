import 'package:expense_tracker/app/state/app_state_dependencies.dart';
import 'package:expense_tracker/app/state/app_state_provider.dart';
import 'package:expense_tracker/features/accounts/data/account_repository.dart';
import 'package:expense_tracker/features/accounts/domain/models/account.dart';
import 'package:expense_tracker/features/accounts/presentation/pages/add_account_page.dart';
import 'package:expense_tracker/features/categories/data/category_repository.dart';
import 'package:expense_tracker/features/categories/domain/models/category_item.dart';
import 'package:expense_tracker/features/recurring_transactions/data/recurring_transaction_repository.dart';
import 'package:expense_tracker/features/recurring_transactions/domain/models/recurring_transaction.dart';
import 'package:expense_tracker/features/settings/data/settings_repository.dart';
import 'package:expense_tracker/features/settings/domain/models/app_settings.dart';
import 'package:expense_tracker/features/settings/domain/models/app_theme_preference.dart';
import 'package:expense_tracker/features/transactions/data/transaction_repository.dart';
import 'package:expense_tracker/features/transactions/domain/models/transaction_item.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

class AddAccountTestEnvironment {
  AddAccountTestEnvironment({
    List<Account>? accounts,
    AppSettings settings = const AppSettings(
      displayName: '',
      themePreference: AppThemePreference.system,
      defaultCurrencyCode: 'EUR',
      financialCycleDay: 1,
    ),
    this.addError,
    this.updateError,
  }) : settingsRepository = InMemorySettingsRepository(settings),
       accountRepository = RecordingAccountRepository(accounts ?? const []),
       categoryRepository = InMemoryCategoryRepository(const []),
       transactionRepository = InMemoryTransactionRepository(),
       recurringTransactionRepository =
           InMemoryRecurringTransactionRepository();

  final Object? addError;
  final Object? updateError;
  final InMemorySettingsRepository settingsRepository;
  final RecordingAccountRepository accountRepository;
  final InMemoryCategoryRepository categoryRepository;
  final InMemoryTransactionRepository transactionRepository;
  final InMemoryRecurringTransactionRepository recurringTransactionRepository;

  Future<void> pumpHost(WidgetTester tester, {Account? initialAccount}) async {
    accountRepository.addError = addError;
    accountRepository.updateError = updateError;

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
        ],
        child: MaterialApp(
          home: AddAccountTestHost(initialAccount: initialAccount),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }
}

class AddAccountTestHost extends ConsumerStatefulWidget {
  const AddAccountTestHost({super.key, this.initialAccount});

  final Account? initialAccount;

  @override
  ConsumerState<AddAccountTestHost> createState() => _AddAccountTestHostState();
}

class _AddAccountTestHostState extends ConsumerState<AddAccountTestHost> {
  bool? _lastResult;

  @override
  Widget build(BuildContext context) {
    ref.watch(appStateProvider);

    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Host home'),
            Text('Last result: ${_lastResult ?? 'null'}'),
            FilledButton(
              onPressed: () async {
                final result = await Navigator.of(context).push<bool>(
                  MaterialPageRoute(
                    builder: (_) =>
                        AddAccountPage(initialAccount: widget.initialAccount),
                  ),
                );
                if (!mounted) {
                  return;
                }
                setState(() {
                  _lastResult = result;
                });
              },
              child: const Text('Open add account'),
            ),
          ],
        ),
      ),
    );
  }
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

class RecordingAccountRepository implements AccountRepository {
  RecordingAccountRepository(List<Account> accounts)
    : accounts = List<Account>.from(accounts);

  final DummyBoxListenable _listenable = DummyBoxListenable();
  final List<Account> accounts;
  final List<Account> addedAccounts = [];
  final List<Account> updatedAccounts = [];
  int createAccountIdCallCount = 0;
  Object? addError;
  Object? updateError;

  @override
  Future<void> addAccount(Account account) async {
    addedAccounts.add(account);
    if (addError != null) {
      throw addError!;
    }
    accounts.add(account);
  }

  @override
  String createAccountId() {
    createAccountIdCallCount += 1;
    return 'generated-account-id';
  }

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
    updatedAccounts.add(account);
    if (updateError != null) {
      throw updateError!;
    }

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

Account testAccount({
  String id = 'account-1',
  String name = 'Wallet',
  AccountType type = AccountType.bank,
  double openingBalance = 0,
  String currencyCode = 'EUR',
  bool isPrimary = false,
  String description = '',
  int? creditCardDueDay,
  CreditCardPaymentTracking? paymentTracking,
}) {
  return Account(
    id: id,
    name: name,
    type: type,
    openingBalance: openingBalance,
    currencyCode: currencyCode,
    isPrimary: isPrimary,
    description: description,
    creditCardDueDay: creditCardDueDay,
    paymentTracking: paymentTracking,
  );
}
