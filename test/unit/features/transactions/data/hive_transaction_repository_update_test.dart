import 'dart:convert';
import 'dart:io';

import 'package:expense_tracker/core/storage/hive_storage.dart';
import 'package:expense_tracker/features/accounts/domain/models/account.dart';
import 'package:expense_tracker/features/categories/domain/models/category_item.dart';
import 'package:expense_tracker/features/transactions/data/hive_transaction_repository.dart';
import 'package:expense_tracker/features/transactions/domain/models/transaction_item.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDirectory;
  late Box<dynamic> accountsBox;
  late Box<dynamic> categoriesBox;
  late Box<dynamic> transactionsBox;
  late HiveTransactionRepository repository;

  setUp(() async {
    tempDirectory = await Directory.systemTemp.createTemp(
      'vero-hive-transaction-repository-update-test-',
    );
    Hive.init(tempDirectory.path);

    accountsBox = await Hive.openBox<dynamic>(HiveStorage.accountsBoxName);
    categoriesBox = await Hive.openBox<dynamic>(HiveStorage.categoriesBoxName);
    transactionsBox = await Hive.openBox<dynamic>(
      HiveStorage.transactionsBoxName,
    );

    await accountsBox.put(HiveStorage.accountsKey, const []);
    await categoriesBox.put(HiveStorage.categoriesKey, const []);
    await transactionsBox.put(HiveStorage.transactionsKey, const []);

    repository = HiveTransactionRepository();
  });

  tearDown(() async {
    await Hive.close();
    if (await tempDirectory.exists()) {
      await tempDirectory.delete(recursive: true);
    }
  });

  group('updateTransaction edit flow', () {
    test(
      'updates an existing expense transaction and preserves its ID',
      () async {
        await _storeAccounts(accountsBox, [_account()]);
        await _storeCategories(categoriesBox, [
          _category(type: CategoryType.expense),
          _category(
            id: 'category-2',
            name: 'Dining',
            type: CategoryType.expense,
          ),
        ]);
        final existing = _transaction(
          id: '3bf4d68c-cce7-4ff3-a29a-5e30fc147fb6',
          title: 'Groceries',
          amount: 1250,
          date: DateTime(2026, 4, 8),
        );
        await _storeTransactions(transactionsBox, [existing]);
        final updated = _transaction(
          id: existing.id,
          title: 'Restaurant',
          amount: 1899,
          categoryId: 'category-2',
          date: DateTime(2026, 4, 10),
        );

        await repository.updateTransaction(updated);

        final storedTransactions = await repository.getTransactions();
        expect(storedTransactions, hasLength(1));
        final stored = storedTransactions.single;
        expect(stored.id, existing.id);
        expect(stored.title, 'Restaurant');
        expect(stored.amount, 1899);
        expect(stored.categoryId, 'category-2');
        expect(stored.date, DateTime(2026, 4, 10));

        final rawStored = _rawStoredTransactions(transactionsBox).single;
        expect(rawStored['id'], existing.id);
        expect(rawStored['amount'], closeTo(1899, 0.0001));
        expect(rawStored['amount'], isA<num>());
      },
    );

    test(
      'updates an existing income transaction without creating a duplicate',
      () async {
        await _storeAccounts(accountsBox, [_account()]);
        await _storeCategories(categoriesBox, [
          _category(
            id: 'category-income',
            name: 'Salary',
            type: CategoryType.income,
          ),
        ]);
        final existing = _transaction(
          id: '241ec197-68d7-4bb8-b986-730bc6c1b330',
          title: 'Salary',
          amount: 250000,
          type: TransactionType.income,
          categoryId: 'category-income',
        );
        await _storeTransactions(transactionsBox, [existing]);
        final updated = _transaction(
          id: existing.id,
          title: 'Salary April',
          amount: 255000,
          type: TransactionType.income,
          categoryId: 'category-income',
        );

        await repository.updateTransaction(updated);

        final storedTransactions = await repository.getTransactions();
        expect(storedTransactions, hasLength(1));
        expect(storedTransactions.single.id, existing.id);
        expect(storedTransactions.single.title, 'Salary April');
        expect(storedTransactions.single.amount, 255000);
      },
    );

    test('fails when update ID is missing', () async {
      await _storeAccounts(accountsBox, [_account()]);
      await _storeCategories(categoriesBox, [
        _category(type: CategoryType.expense),
      ]);
      final existing = _transaction();
      await _storeTransactions(transactionsBox, [existing]);
      final beforeUpdate = jsonEncode(_rawStoredTransactions(transactionsBox));
      final updated = _transaction(id: '', title: 'Changed');

      await expectLater(
        repository.updateTransaction(updated),
        throwsA(anything),
      );

      expect(jsonEncode(_rawStoredTransactions(transactionsBox)), beforeUpdate);
      expect(await repository.getTransactions(), [existing]);
    });

    test('fails when update target does not exist', () async {
      await _storeAccounts(accountsBox, [_account()]);
      await _storeCategories(categoriesBox, [
        _category(type: CategoryType.expense),
      ]);
      final existing = _transaction(id: 'existing-id');
      await _storeTransactions(transactionsBox, [existing]);
      final beforeUpdate = jsonEncode(_rawStoredTransactions(transactionsBox));
      final updated = _transaction(id: 'missing-id', title: 'Changed');

      await expectLater(
        repository.updateTransaction(updated),
        throwsA(anything),
      );

      expect(jsonEncode(_rawStoredTransactions(transactionsBox)), beforeUpdate);
      expect(await repository.getTransactions(), [existing]);
    });

    test('rejects an empty name on update', () async {
      await _storeAccounts(accountsBox, [_account()]);
      await _storeCategories(categoriesBox, [
        _category(type: CategoryType.expense),
      ]);
      final existing = _transaction();
      await _storeTransactions(transactionsBox, [existing]);

      await expectLater(
        repository.updateTransaction(existing.copyWith(title: '')),
        throwsA(anything),
      );

      expect(await repository.getTransactions(), [existing]);
    });

    test('rejects a blank-only name on update', () async {
      await _storeAccounts(accountsBox, [_account()]);
      await _storeCategories(categoriesBox, [
        _category(type: CategoryType.expense),
      ]);
      final existing = _transaction();
      await _storeTransactions(transactionsBox, [existing]);

      await expectLater(
        repository.updateTransaction(existing.copyWith(title: '   ')),
        throwsA(anything),
      );

      expect(await repository.getTransactions(), [existing]);
    });

    test('rejects a zero amount on update', () async {
      await _storeAccounts(accountsBox, [_account()]);
      await _storeCategories(categoriesBox, [
        _category(type: CategoryType.expense),
      ]);
      final existing = _transaction();
      await _storeTransactions(transactionsBox, [existing]);

      await expectLater(
        repository.updateTransaction(existing.copyWith(amount: 0)),
        throwsA(anything),
      );

      expect(await repository.getTransactions(), [existing]);
    });

    test('rejects a negative amount on update', () async {
      await _storeAccounts(accountsBox, [_account()]);
      await _storeCategories(categoriesBox, [
        _category(type: CategoryType.expense),
      ]);
      final existing = _transaction();
      await _storeTransactions(transactionsBox, [existing]);

      await expectLater(
        repository.updateTransaction(existing.copyWith(amount: -1)),
        throwsA(anything),
      );

      expect(await repository.getTransactions(), [existing]);
    });

    test('preserves decimal amounts on update', () async {
      await _storeAccounts(accountsBox, [_account()]);
      await _storeCategories(categoriesBox, [
        _category(type: CategoryType.expense),
      ]);
      final existing = _transaction(amount: 5.00);
      await _storeTransactions(transactionsBox, [existing]);

      await repository.updateTransaction(existing.copyWith(amount: 333.33));

      final stored = (await repository.getTransactions()).single;
      final rawStored = _rawStoredTransactions(transactionsBox).single;
      expect(stored.amount, closeTo(333.33, 0.0001));
      expect(rawStored['amount'], closeTo(333.33, 0.0001));
    });

    test('rejects a missing account on update', () async {
      await _storeAccounts(accountsBox, [_account()]);
      await _storeCategories(categoriesBox, [
        _category(type: CategoryType.expense),
      ]);
      final existing = _transaction();
      await _storeTransactions(transactionsBox, [existing]);
      final updated = _transaction(
        id: existing.id,
        title: 'Changed',
        accountId: '',
      );

      await expectLater(
        repository.updateTransaction(updated),
        throwsA(anything),
      );

      expect(await repository.getTransactions(), [existing]);
    });

    test('rejects an unresolved account on update', () async {
      await _storeAccounts(accountsBox, [_account(id: 'account-1')]);
      await _storeCategories(categoriesBox, [
        _category(type: CategoryType.expense),
      ]);
      final existing = _transaction();
      await _storeTransactions(transactionsBox, [existing]);
      final updated = _transaction(
        id: existing.id,
        title: 'Changed',
        accountId: 'missing-account',
      );

      await expectLater(
        repository.updateTransaction(updated),
        throwsA(anything),
      );

      expect(await repository.getTransactions(), [existing]);
    });

    test('rejects a missing category on update', () async {
      await _storeAccounts(accountsBox, [_account()]);
      await _storeCategories(categoriesBox, [
        _category(type: CategoryType.expense),
      ]);
      final existing = _transaction();
      await _storeTransactions(transactionsBox, [existing]);
      final updated = _transaction(
        id: existing.id,
        title: 'Changed',
        categoryId: '',
      );

      await expectLater(
        repository.updateTransaction(updated),
        throwsA(anything),
      );

      expect(await repository.getTransactions(), [existing]);
    });

    test('rejects an unresolved category on update', () async {
      await _storeAccounts(accountsBox, [_account()]);
      await _storeCategories(categoriesBox, [
        _category(id: 'category-1', type: CategoryType.expense),
      ]);
      final existing = _transaction();
      await _storeTransactions(transactionsBox, [existing]);
      final updated = _transaction(
        id: existing.id,
        title: 'Changed',
        categoryId: 'missing-category',
      );

      await expectLater(
        repository.updateTransaction(updated),
        throwsA(anything),
      );

      expect(await repository.getTransactions(), [existing]);
    });

    test(
      'rejects unsupported types at the update boundary',
      () {
        fail(
          'Pending contract: the current repository boundary accepts only TransactionType enum values, so unsupported raw type input cannot be expressed yet.',
        );
      },
      skip:
          'Pending contract: unsupported type validation requires a broader update input than the current repository API exposes.',
    );

    test(
      'rejects missing dates at the update boundary',
      () {
        fail(
          'Pending contract: the current repository boundary requires a non-null DateTime, so missing date input cannot be expressed yet.',
        );
      },
      skip:
          'Pending contract: missing date validation requires a broader update input than the current repository API exposes.',
    );

    test(
      'updates same-currency values without introducing foreign snapshot fields',
      () async {
        await _storeAccounts(accountsBox, [_account(currencyCode: 'EUR')]);
        await _storeCategories(categoriesBox, [
          _category(type: CategoryType.expense),
        ]);
        final existing = _transaction();
        await _storeTransactions(transactionsBox, [existing]);
        final updated = _transaction(
          id: existing.id,
          amount: 4321,
          currencyCode: 'EUR',
          foreignAmount: 4321,
          foreignCurrencyCode: 'EUR',
          exchangeRate: 1,
        );

        await repository.updateTransaction(updated);

        final rawStored = _rawStoredTransactions(transactionsBox).single;
        expect(rawStored['amount'], closeTo(4321, 0.0001));
        expect(rawStored['amount'], isA<num>());
        expect(rawStored['currencyCode'], 'EUR');
        expect(rawStored['foreignAmount'], isNull);
        expect(rawStored['foreignCurrencyCode'], isNull);
        expect(rawStored['exchangeRate'], isNull);
      },
    );

    test(
      'updates foreign-currency values with normalized amount and fresh snapshot',
      () async {
        await _storeAccounts(accountsBox, [_account(currencyCode: 'EUR')]);
        await _storeCategories(categoriesBox, [
          _category(type: CategoryType.expense),
        ]);
        final existing = _transaction(
          foreignAmount: 1500,
          foreignCurrencyCode: 'USD',
          exchangeRate: 0.75,
          amount: 1125,
        );
        await _storeTransactions(transactionsBox, [existing]);
        final updated = _transaction(
          id: existing.id,
          amount: 1000,
          currencyCode: 'USD',
          foreignAmount: 1000,
          foreignCurrencyCode: 'USD',
          exchangeRate: 0.8,
        );

        await repository.updateTransaction(updated);

        final rawStored = _rawStoredTransactions(transactionsBox).single;
        expect(rawStored['id'], existing.id);
        expect(rawStored['amount'], closeTo(800, 0.0001));
        expect(rawStored['amount'], isA<num>());
        expect(rawStored['currencyCode'], 'EUR');
        expect(rawStored['foreignAmount'], closeTo(1000, 0.0001));
        expect(rawStored['foreignCurrencyCode'], 'USD');
        expect(rawStored['exchangeRate'], 0.8);
      },
    );

    test(
      'replaces stale foreign snapshot data when update becomes same-currency',
      () async {
        await _storeAccounts(accountsBox, [_account(currencyCode: 'EUR')]);
        await _storeCategories(categoriesBox, [
          _category(type: CategoryType.expense),
        ]);
        final existing = _transaction(
          amount: 800,
          currencyCode: 'EUR',
          foreignAmount: 1000,
          foreignCurrencyCode: 'USD',
          exchangeRate: 0.8,
        );
        await _storeTransactions(transactionsBox, [existing]);
        final updated = _transaction(
          id: existing.id,
          amount: 1200,
          currencyCode: 'EUR',
        );

        await repository.updateTransaction(updated);

        final rawStored = _rawStoredTransactions(transactionsBox).single;
        expect(rawStored['amount'], 1200);
        expect(rawStored['currencyCode'], 'EUR');
        expect(rawStored['foreignAmount'], isNull);
        expect(rawStored['foreignCurrencyCode'], isNull);
        expect(rawStored['exchangeRate'], isNull);
      },
    );

    test('fails when update requires a missing exchange rate', () async {
      await _storeAccounts(accountsBox, [_account(currencyCode: 'EUR')]);
      await _storeCategories(categoriesBox, [
        _category(type: CategoryType.expense),
      ]);
      final existing = _transaction();
      await _storeTransactions(transactionsBox, [existing]);
      final beforeUpdate = jsonEncode(_rawStoredTransactions(transactionsBox));
      final updated = _transaction(
        id: existing.id,
        amount: 1000,
        currencyCode: 'USD',
        foreignAmount: 1000,
        foreignCurrencyCode: 'USD',
        exchangeRate: null,
      );

      await expectLater(
        repository.updateTransaction(updated),
        throwsA(anything),
      );

      expect(jsonEncode(_rawStoredTransactions(transactionsBox)), beforeUpdate);
    });

    test(
      'updates the account and normalizes into the new account currency',
      () async {
        await _storeAccounts(accountsBox, [
          _account(id: 'account-1', currencyCode: 'EUR'),
          _account(id: 'account-2', currencyCode: 'GBP'),
        ]);
        await _storeCategories(categoriesBox, [
          _category(type: CategoryType.expense),
        ]);
        final existing = _transaction(
          accountId: 'account-1',
          amount: 800,
          currencyCode: 'EUR',
        );
        await _storeTransactions(transactionsBox, [existing]);
        final updated = _transaction(
          id: existing.id,
          accountId: 'account-2',
          amount: 1000,
          currencyCode: 'USD',
          foreignAmount: 1000,
          foreignCurrencyCode: 'USD',
          exchangeRate: 0.79,
        );

        await repository.updateTransaction(updated);

        final stored = (await repository.getTransactions()).single;
        expect(stored.accountId, 'account-2');
        expect(stored.amount, 790);
        expect(stored.currencyCode, 'GBP');
        expect(stored.foreignAmount, 1000);
        expect(stored.foreignCurrencyCode, 'USD');
        expect(stored.exchangeRate, 0.79);
      },
    );

    test('updates the category and leaves unchanged fields intact', () async {
      await _storeAccounts(accountsBox, [_account()]);
      await _storeCategories(categoriesBox, [
        _category(
          id: 'category-1',
          name: 'Groceries',
          type: CategoryType.expense,
        ),
        _category(id: 'category-2', name: 'Dining', type: CategoryType.expense),
      ]);
      final existing = _transaction(
        id: '11ac6c87-166e-4602-8f43-6b1df69c4675',
        title: 'Dinner',
        amount: 4200,
        categoryId: 'category-1',
        date: DateTime(2026, 4, 9),
      );
      await _storeTransactions(transactionsBox, [existing]);
      final updated = _transaction(
        id: existing.id,
        title: existing.title,
        amount: existing.amount,
        accountId: existing.accountId!,
        categoryId: 'category-2',
        date: existing.date,
      );

      await repository.updateTransaction(updated);

      final stored = (await repository.getTransactions()).single;
      expect(stored.id, existing.id);
      expect(stored.title, existing.title);
      expect(stored.amount, existing.amount);
      expect(stored.accountId, existing.accountId);
      expect(stored.categoryId, 'category-2');
      expect(stored.date, existing.date);
    });
  });
}

Account _account({
  String id = 'account-1',
  String name = 'Main account',
  String currencyCode = 'EUR',
}) {
  return Account(
    id: id,
    name: name,
    type: AccountType.bank,
    openingBalance: 0,
    currencyCode: currencyCode,
  );
}

CategoryItem _category({
  String id = 'category-1',
  String name = 'Category',
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
  String id = '1d3759eb-f3ae-43dd-a2ee-620ea227202f',
  String title = 'Groceries',
  double amount = 1250,
  String currencyCode = 'EUR',
  DateTime? date,
  TransactionType type = TransactionType.expense,
  String accountId = 'account-1',
  String categoryId = 'category-1',
  double? foreignAmount,
  String? foreignCurrencyCode,
  double? exchangeRate,
}) {
  return TransactionItem(
    id: id,
    title: title,
    amount: amount,
    currencyCode: currencyCode,
    date: date ?? DateTime(2026, 4, 8),
    type: type,
    accountId: accountId,
    categoryId: categoryId,
    foreignAmount: foreignAmount,
    foreignCurrencyCode: foreignCurrencyCode,
    exchangeRate: exchangeRate,
  );
}

Future<void> _storeAccounts(Box<dynamic> box, List<Account> accounts) async {
  await box.put(
    HiveStorage.accountsKey,
    accounts.map((account) => account.toMap()).toList(growable: false),
  );
}

Future<void> _storeCategories(
  Box<dynamic> box,
  List<CategoryItem> categories,
) async {
  await box.put(
    HiveStorage.categoriesKey,
    categories.map((category) => category.toMap()).toList(growable: false),
  );
}

Future<void> _storeTransactions(
  Box<dynamic> box,
  List<TransactionItem> transactions,
) async {
  await box.put(
    HiveStorage.transactionsKey,
    transactions
        .map((transaction) => transaction.toMap())
        .toList(growable: false),
  );
}

List<Map<dynamic, dynamic>> _rawStoredTransactions(Box<dynamic> box) {
  return (box.get(HiveStorage.transactionsKey) as List<dynamic>? ?? const [])
      .cast<Map<dynamic, dynamic>>();
}
