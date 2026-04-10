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
      'vero-hive-transaction-repository-test-',
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

  group('addTransaction create flow', () {
    test('persists a valid expense transaction', () async {
      await _storeAccounts(accountsBox, [_account()]);
      await _storeCategories(categoriesBox, [
        _category(type: CategoryType.expense),
      ]);
      final transaction = _transaction();

      await repository.addTransaction(transaction);

      final storedTransactions = await repository.getTransactions();
      expect(storedTransactions, hasLength(1));

      final stored = storedTransactions.single;
      expect(stored.id, transaction.id);
      expect(stored.title, transaction.title);
      expect(stored.amount, transaction.amount);
      expect(stored.currencyCode, transaction.currencyCode);
      expect(stored.date, transaction.date);
      expect(stored.type, TransactionType.expense);
      expect(stored.accountId, transaction.accountId);
      expect(stored.categoryId, transaction.categoryId);

      final rawStored = _rawStoredTransactions(transactionsBox).single;
      expect(rawStored['amount'], closeTo(1250, 0.0001));
      expect(rawStored['amount'], isA<num>());
      expect(rawStored['currencyCode'], 'EUR');
    });

    test('persists a valid income transaction', () async {
      await _storeAccounts(accountsBox, [
        _account(id: 'account-income', currencyCode: 'EUR'),
      ]);
      await _storeCategories(categoriesBox, [
        _category(id: 'category-income', type: CategoryType.income),
      ]);
      final transaction = _transaction(
        id: 'd3f2d5db-0404-42b1-9364-cff7661ef20b',
        title: 'Salary',
        amount: 250000,
        type: TransactionType.income,
        accountId: 'account-income',
        categoryId: 'category-income',
      );

      await repository.addTransaction(transaction);

      final storedTransactions = await repository.getTransactions();
      expect(storedTransactions, hasLength(1));
      expect(storedTransactions.single.type, TransactionType.income);
      expect(storedTransactions.single.title, 'Salary');
      expect(storedTransactions.single.amount, 250000);
      expect(storedTransactions.single.currencyCode, 'EUR');
    });

    test('assigns a UUID when the create input does not provide one', () async {
      await _storeAccounts(accountsBox, [_account()]);
      await _storeCategories(categoriesBox, [
        _category(type: CategoryType.expense),
      ]);
      final transaction = _transaction(id: '');

      await repository.addTransaction(transaction);

      final storedTransactions = await repository.getTransactions();
      expect(storedTransactions, hasLength(1));
      expect(storedTransactions.single.id, matches(_uuidPattern));

      final rawStored = _rawStoredTransactions(transactionsBox).single;
      expect(rawStored['id'], matches(_uuidPattern));
    });

    test('preserves a provided UUID on create', () async {
      await _storeAccounts(accountsBox, [_account()]);
      await _storeCategories(categoriesBox, [
        _category(type: CategoryType.expense),
      ]);
      const providedId = '6de49546-89dd-406d-aa38-81fc78b1ab57';
      final transaction = _transaction(id: providedId);

      await repository.addTransaction(transaction);

      final storedTransactions = await repository.getTransactions();
      expect(storedTransactions.single.id, providedId);

      final rawStored = _rawStoredTransactions(transactionsBox).single;
      expect(rawStored['id'], providedId);
    });

    test('rejects blank-only names', () async {
      await _storeAccounts(accountsBox, [_account()]);
      await _storeCategories(categoriesBox, [
        _category(type: CategoryType.expense),
      ]);
      final transaction = _transaction(title: '   ');

      await expectLater(
        repository.addTransaction(transaction),
        throwsA(anything),
      );

      expect(await repository.getTransactions(), isEmpty);
      expect(_rawStoredTransactions(transactionsBox), isEmpty);
    });

    test('rejects zero amounts', () async {
      await _storeAccounts(accountsBox, [_account()]);
      await _storeCategories(categoriesBox, [
        _category(type: CategoryType.expense),
      ]);
      final transaction = _transaction(amount: 0);

      await expectLater(
        repository.addTransaction(transaction),
        throwsA(anything),
      );

      expect(await repository.getTransactions(), isEmpty);
      expect(_rawStoredTransactions(transactionsBox), isEmpty);
    });

    test('rejects negative amounts', () async {
      await _storeAccounts(accountsBox, [_account()]);
      await _storeCategories(categoriesBox, [
        _category(type: CategoryType.expense),
      ]);
      final transaction = _transaction(amount: -1);

      await expectLater(
        repository.addTransaction(transaction),
        throwsA(anything),
      );

      expect(await repository.getTransactions(), isEmpty);
      expect(_rawStoredTransactions(transactionsBox), isEmpty);
    });

    test('rejects a blank account id', () async {
      await _storeAccounts(accountsBox, [_account()]);
      await _storeCategories(categoriesBox, [
        _category(type: CategoryType.expense),
      ]);
      final transaction = _transaction(accountId: '   ');

      await expectLater(
        repository.addTransaction(transaction),
        throwsA(anything),
      );

      expect(await repository.getTransactions(), isEmpty);
      expect(_rawStoredTransactions(transactionsBox), isEmpty);
    });

    test('rejects an unresolved account id', () async {
      await _storeAccounts(accountsBox, [_account(id: 'account-existing')]);
      await _storeCategories(categoriesBox, [
        _category(type: CategoryType.expense),
      ]);
      final transaction = _transaction(accountId: 'account-missing');

      await expectLater(
        repository.addTransaction(transaction),
        throwsA(anything),
      );

      expect(await repository.getTransactions(), isEmpty);
      expect(_rawStoredTransactions(transactionsBox), isEmpty);
    });

    test('rejects a blank category id', () async {
      await _storeAccounts(accountsBox, [_account()]);
      await _storeCategories(categoriesBox, [
        _category(type: CategoryType.expense),
      ]);
      final transaction = _transaction(categoryId: '   ');

      await expectLater(
        repository.addTransaction(transaction),
        throwsA(anything),
      );

      expect(await repository.getTransactions(), isEmpty);
      expect(_rawStoredTransactions(transactionsBox), isEmpty);
    });

    test('rejects an unresolved category id', () async {
      await _storeAccounts(accountsBox, [_account()]);
      await _storeCategories(categoriesBox, [
        _category(id: 'category-existing', type: CategoryType.expense),
      ]);
      final transaction = _transaction(categoryId: 'category-missing');

      await expectLater(
        repository.addTransaction(transaction),
        throwsA(anything),
      );

      expect(await repository.getTransactions(), isEmpty);
      expect(_rawStoredTransactions(transactionsBox), isEmpty);
    });

    test('preserves decimal amounts for same-currency transactions', () async {
      await _storeAccounts(accountsBox, [_account(currencyCode: 'EUR')]);
      await _storeCategories(categoriesBox, [
        _category(type: CategoryType.expense),
      ]);
      final transaction = _transaction(amount: 1.23, currencyCode: 'EUR');

      await repository.addTransaction(transaction);

      final stored = (await repository.getTransactions()).single;
      final rawStored = _rawStoredTransactions(transactionsBox).single;
      expect(stored.amount, closeTo(1.23, 0.0001));
      expect(rawStored['amount'], closeTo(1.23, 0.0001));
    });

    test(
      'rejects unsupported types at the create boundary',
      () {
        fail(
          'Pending contract: the current repository boundary accepts only TransactionType enum values, so unsupported raw type input cannot be expressed yet.',
        );
      },
      skip:
          'Pending contract: unsupported type validation requires a broader create input than the current repository API exposes.',
    );

    test(
      'rejects missing dates at the create boundary',
      () {
        fail(
          'Pending contract: the current repository boundary requires a non-null DateTime, so missing date input cannot be expressed yet.',
        );
      },
      skip:
          'Pending contract: missing date validation requires a broader create input than the current repository API exposes.',
    );

    test(
      'stores same-currency transactions without foreign snapshot fields',
      () async {
        await _storeAccounts(accountsBox, [_account(currencyCode: 'EUR')]);
        await _storeCategories(categoriesBox, [
          _category(type: CategoryType.expense),
        ]);
        final transaction = _transaction(
          amount: 1234,
          currencyCode: 'EUR',
          foreignAmount: 1234,
          foreignCurrencyCode: 'EUR',
          exchangeRate: 1,
        );

        await repository.addTransaction(transaction);

        final rawStored = _rawStoredTransactions(transactionsBox).single;
        expect(rawStored['amount'], closeTo(1234, 0.0001));
        expect(rawStored['amount'], isA<num>());
        expect(rawStored['currencyCode'], 'EUR');
        expect(rawStored['foreignAmount'], isNull);
        expect(rawStored['foreignCurrencyCode'], isNull);
        expect(rawStored['exchangeRate'], isNull);
      },
    );

    test('converts foreign-currency transactions before persistence', () async {
      await _storeAccounts(accountsBox, [_account(currencyCode: 'EUR')]);
      await _storeCategories(categoriesBox, [
        _category(type: CategoryType.expense),
      ]);
      final transaction = _transaction(
        amount: 1000,
        currencyCode: 'USD',
        foreignAmount: 1000,
        foreignCurrencyCode: 'USD',
        exchangeRate: 0.8,
      );

      await repository.addTransaction(transaction);

      final rawStored = _rawStoredTransactions(transactionsBox).single;
      expect(rawStored['amount'], closeTo(800, 0.0001));
      expect(rawStored['amount'], isA<num>());
      expect(rawStored['currencyCode'], 'EUR');
      expect(rawStored['foreignAmount'], closeTo(1000, 0.0001));
      expect(rawStored['foreignAmount'], isA<num>());
      expect(rawStored['foreignCurrencyCode'], 'USD');
      expect(rawStored['exchangeRate'], 0.8);
    });

    test(
      'rejects foreign-currency creation when exchange rate is missing',
      () async {
        await _storeAccounts(accountsBox, [_account(currencyCode: 'EUR')]);
        await _storeCategories(categoriesBox, [
          _category(type: CategoryType.expense),
        ]);
        final transaction = _transaction(
          amount: 1000,
          currencyCode: 'USD',
          foreignAmount: 1000,
          foreignCurrencyCode: 'USD',
          exchangeRate: null,
        );

        await expectLater(
          repository.addTransaction(transaction),
          throwsA(anything),
        );

        expect(await repository.getTransactions(), isEmpty);
        expect(_rawStoredTransactions(transactionsBox), isEmpty);
      },
    );

    test('leaves storage unchanged when creation fails', () async {
      await _storeAccounts(accountsBox, [_account()]);
      await _storeCategories(categoriesBox, [
        _category(type: CategoryType.expense),
      ]);
      final existingTransaction = _transaction(
        id: '8c33011f-bd11-4421-9459-342e8987d3e6',
        title: 'Existing transaction',
      );
      await transactionsBox.put(HiveStorage.transactionsKey, [
        existingTransaction.toMap(),
      ]);
      final beforeFailure = jsonEncode(_rawStoredTransactions(transactionsBox));

      await expectLater(
        repository.addTransaction(_transaction(title: '   ')),
        throwsA(anything),
      );

      final afterFailure = jsonEncode(_rawStoredTransactions(transactionsBox));
      expect(afterFailure, beforeFailure);
      expect(await repository.getTransactions(), hasLength(1));
      expect(
        await repository.getTransactions().then((items) => items.single.title),
        'Existing transaction',
      );
    });
  });
}

final RegExp _uuidPattern = RegExp(
  r'^[0-9a-fA-F]{8}-'
  r'[0-9a-fA-F]{4}-'
  r'[0-9a-fA-F]{4}-'
  r'[0-9a-fA-F]{4}-'
  r'[0-9a-fA-F]{12}$',
);

Account _account({String id = 'account-1', String currencyCode = 'EUR'}) {
  return Account(
    id: id,
    name: 'Main account',
    type: AccountType.bank,
    openingBalance: 0,
    currencyCode: currencyCode,
  );
}

CategoryItem _category({String id = 'category-1', required CategoryType type}) {
  return CategoryItem(
    id: id,
    name: 'Category',
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

List<Map<dynamic, dynamic>> _rawStoredTransactions(Box<dynamic> box) {
  return (box.get(HiveStorage.transactionsKey) as List<dynamic>? ?? const [])
      .cast<Map<dynamic, dynamic>>();
}
