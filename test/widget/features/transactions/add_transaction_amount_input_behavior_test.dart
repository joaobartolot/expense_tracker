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
    categoryRepository = InMemoryCategoryRepository([_category()]);
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
          home: AmountInputTestHost(initialTransaction: initialTransaction),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('add transaction amount input behavior', () {
    testWidgets('create starts at 0.00', (tester) async {
      await pumpHost(tester);
      await _openAddTransactionPage(tester);

      expect(_amountText(tester), '0.00');
      expect(_amountCents(_amountText(tester)), 0);
    });

    testWidgets(
      'digit entry follows masked cents behavior from 0.00 to 0.01 to 0.12 to 1.23',
      (tester) async {
        await pumpHost(tester);
        await _openAddTransactionPage(tester);

        await _updateAmountValue(
          tester,
          const TextEditingValue(
            text: '1',
            selection: TextSelection.collapsed(offset: 1),
          ),
        );
        expect(_amountText(tester), '0.01');
        expect(_amountCents(_amountText(tester)), 1);

        await _updateAmountValue(
          tester,
          const TextEditingValue(
            text: '12',
            selection: TextSelection.collapsed(offset: 2),
          ),
        );
        expect(_amountText(tester), '0.12');
        expect(_amountCents(_amountText(tester)), 12);

        await _updateAmountValue(
          tester,
          const TextEditingValue(
            text: '123',
            selection: TextSelection.collapsed(offset: 3),
          ),
        );
        expect(_amountText(tester), '1.23');
        expect(_amountCents(_amountText(tester)), 123);
      },
    );

    testWidgets(
      'backspace reverses the mask from 1.23 to 0.12 to 0.01 to 0.00',
      (tester) async {
        await pumpHost(tester);
        await _openAddTransactionPage(tester);

        await _updateAmountValue(
          tester,
          const TextEditingValue(
            text: '123',
            selection: TextSelection.collapsed(offset: 3),
          ),
        );
        expect(_amountText(tester), '1.23');

        await _updateAmountValue(
          tester,
          const TextEditingValue(
            text: '12',
            selection: TextSelection.collapsed(offset: 2),
          ),
        );
        expect(_amountText(tester), '0.12');

        await _updateAmountValue(
          tester,
          const TextEditingValue(
            text: '1',
            selection: TextSelection.collapsed(offset: 1),
          ),
        );
        expect(_amountText(tester), '0.01');

        await _updateAmountValue(
          tester,
          const TextEditingValue(
            text: '',
            selection: TextSelection.collapsed(offset: 0),
          ),
        );
        expect(_amountText(tester), '0.00');
        expect(_amountCents(_amountText(tester)), 0);
      },
    );

    testWidgets(
      'cursor position does not affect the resulting masked monetary value',
      (tester) async {
        await pumpHost(tester);
        await _openAddTransactionPage(tester);

        await _updateAmountValue(
          tester,
          const TextEditingValue(
            text: '1234',
            selection: TextSelection.collapsed(offset: 0),
          ),
        );
        final valueWithStartCursor = _amountText(tester);

        await _updateAmountValue(
          tester,
          const TextEditingValue(
            text: '1234',
            selection: TextSelection.collapsed(offset: 2),
          ),
        );
        final valueWithMiddleCursor = _amountText(tester);

        await _updateAmountValue(
          tester,
          const TextEditingValue(
            text: '1234',
            selection: TextSelection.collapsed(offset: 4),
          ),
        );
        final valueWithEndCursor = _amountText(tester);

        expect(valueWithStartCursor, '12.34');
        expect(valueWithMiddleCursor, '12.34');
        expect(valueWithEndCursor, '12.34');
      },
    );

    testWidgets(
      'non digit input and decimal separator do not override the cents mask',
      (tester) async {
        await pumpHost(tester);
        await _openAddTransactionPage(tester);

        await _updateAmountValue(
          tester,
          const TextEditingValue(
            text: '1a2.3',
            selection: TextSelection.collapsed(offset: 5),
          ),
        );
        expect(_amountText(tester), '1.23');
        expect(_amountCents(_amountText(tester)), 123);

        await _updateAmountValue(
          tester,
          const TextEditingValue(
            text: '..4b5',
            selection: TextSelection.collapsed(offset: 5),
          ),
        );
        expect(_amountText(tester), '0.45');
        expect(_amountCents(_amountText(tester)), 45);
      },
    );

    testWidgets(
      'repeated typing and deleting remains stable deterministic and always monetary',
      (tester) async {
        await pumpHost(tester);
        await _openAddTransactionPage(tester);

        final values = <String>[];
        for (final rawText in [
          '1',
          '12',
          '123',
          '1234',
          '123',
          '12',
          '1',
          '',
        ]) {
          await _updateAmountValue(
            tester,
            TextEditingValue(
              text: rawText,
              selection: TextSelection.collapsed(offset: rawText.length),
            ),
          );
          values.add(_amountText(tester));
          expect(RegExp(r'^\d+\.\d{2}$').hasMatch(_amountText(tester)), isTrue);
        }

        expect(values, [
          '0.01',
          '0.12',
          '1.23',
          '12.34',
          '1.23',
          '0.12',
          '0.01',
          '0.00',
        ]);
      },
    );

    testWidgets('edit preloads the existing amount correctly', (tester) async {
      await pumpHost(tester, initialTransaction: _transaction(amount: 123));
      await _openAddTransactionPage(tester);

      expect(_amountText(tester), '123.00');
    });

    testWidgets(
      'continuing to type and delete in edit flow follows the same mask rules',
      (tester) async {
        await pumpHost(tester, initialTransaction: _transaction(amount: 123));
        await _openAddTransactionPage(tester);

        await _updateAmountValue(
          tester,
          const TextEditingValue(
            text: '1234',
            selection: TextSelection.collapsed(offset: 4),
          ),
        );
        expect(_amountText(tester), '12.34');

        await _updateAmountValue(
          tester,
          const TextEditingValue(
            text: '123',
            selection: TextSelection.collapsed(offset: 3),
          ),
        );
        expect(_amountText(tester), '1.23');
      },
    );
  });
}

class AmountInputTestHost extends ConsumerWidget {
  const AmountInputTestHost({super.key, this.initialTransaction});

  final TransactionItem? initialTransaction;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(appStateProvider);

    return Scaffold(
      body: Center(
        child: FilledButton(
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
      ),
    );
  }
}

Future<void> _openAddTransactionPage(WidgetTester tester) async {
  await tester.tap(find.widgetWithText(FilledButton, 'Open add transaction'));
  await tester.pumpAndSettle();
}

Future<void> _updateAmountValue(
  WidgetTester tester,
  TextEditingValue value,
) async {
  await tester.tap(_amountFieldFinder);
  await tester.pumpAndSettle();
  tester.testTextInput.updateEditingValue(value);
  await tester.pumpAndSettle();
}

String _amountText(WidgetTester tester) {
  final textField = tester.widget<TextField>(_amountFieldFinder);
  return textField.controller!.text;
}

int _amountCents(String value) {
  final parts = value.split('.');
  return (int.parse(parts[0]) * 100) + int.parse(parts[1]);
}

Finder get _amountFieldFinder => find.byType(TextField).at(1);

class RecordingTransactionBalanceService extends TransactionBalanceService {
  RecordingTransactionBalanceService()
    : super(
        currencyConversionService: MockCurrencyConversionService(),
        transactionRepository: InMemoryTransactionRepository(),
      );

  @override
  Future<void> saveTransaction(
    TransactionItem transaction, {
    required bool isEditing,
    TransactionItem? previousTransaction,
    required List<Account> currentAccounts,
    List<CategoryItem> currentCategories = const [],
  }) async {}
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

  @override
  Future<void> addTransaction(TransactionItem transaction) async {}

  @override
  String createTransactionId() => 'generated-transaction-id';

  @override
  Future<void> deleteTransaction(String transactionId) async {}

  @override
  Future<List<TransactionItem>> getTransactions() async => const [];

  @override
  ValueListenable<Box<dynamic>> listenable() => _listenable;

  @override
  Future<void> updateTransaction(TransactionItem transaction) async {}
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
  String id = '082296bf-c4f8-4ec0-bf7c-761cc3d5df95',
  String title = 'Lunch',
  double amount = 1250,
}) {
  return TransactionItem(
    id: id,
    title: title,
    amount: amount,
    currencyCode: 'EUR',
    date: DateTime(2026, 4, 8),
    type: TransactionType.expense,
    accountId: 'account-1',
    categoryId: 'category-1',
  );
}
