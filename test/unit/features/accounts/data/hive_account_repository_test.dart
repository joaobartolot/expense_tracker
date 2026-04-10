import 'dart:io';

import 'package:expense_tracker/core/storage/hive_storage.dart';
import 'package:expense_tracker/features/accounts/data/hive_account_repository.dart';
import 'package:expense_tracker/features/accounts/domain/models/account.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDirectory;
  late Box<dynamic> accountsBox;
  late HiveAccountRepository repository;

  setUp(() async {
    tempDirectory = await Directory.systemTemp.createTemp(
      'vero-hive-account-repository-test-',
    );
    Hive.init(tempDirectory.path);
    accountsBox = await Hive.openBox<dynamic>(HiveStorage.accountsBoxName);
    await accountsBox.put(HiveStorage.accountsKey, const []);
    repository = HiveAccountRepository();
  });

  tearDown(() async {
    await Hive.close();
    if (await tempDirectory.exists()) {
      await tempDirectory.delete(recursive: true);
    }
  });

  test('addAccount makes the first account primary', () async {
    await repository.addAccount(_account(id: 'account-1', name: 'Wallet'));

    final accounts = await repository.getAccounts();
    expect(accounts, hasLength(1));
    expect(accounts.single.isPrimary, isTrue);
  });

  test(
    'addAccount inserts later non-primary accounts after the primary',
    () async {
      await repository.addAccount(
        _account(id: 'account-primary', name: 'Main', isPrimary: true),
      );
      await repository.addAccount(_account(id: 'account-2', name: 'Savings'));

      final accounts = await repository.getAccounts();
      expect(accounts.map((account) => account.id), [
        'account-primary',
        'account-2',
      ]);
      expect(accounts.first.isPrimary, isTrue);
      expect(accounts.last.isPrimary, isFalse);
    },
  );

  test(
    'updateAccount replaces an existing account without duplicating it',
    () async {
      await _storeAccounts(accountsBox, [
        _account(id: 'account-1', name: 'Wallet', isPrimary: true),
      ]);

      await repository.updateAccount(
        _account(id: 'account-1', name: 'Updated wallet', isPrimary: true),
      );

      final accounts = await repository.getAccounts();
      expect(accounts, hasLength(1));
      expect(accounts.single.name, 'Updated wallet');
    },
  );

  test(
    'addAccount promotes a new primary and demotes the previous primary',
    () async {
      await _storeAccounts(accountsBox, [
        _account(id: 'account-1', name: 'Main', isPrimary: true),
        _account(id: 'account-2', name: 'Savings'),
      ]);

      await repository.addAccount(
        _account(id: 'account-3', name: 'Travel', isPrimary: true),
      );

      final accounts = await repository.getAccounts();
      expect(accounts.map((account) => account.id), [
        'account-3',
        'account-1',
        'account-2',
      ]);
      expect(
        accounts
            .where((account) => account.isPrimary)
            .map((account) => account.id),
        ['account-3'],
      );
    },
  );

  test('updateAccount ignores missing accounts', () async {
    await _storeAccounts(accountsBox, [
      _account(id: 'account-1', name: 'Wallet', isPrimary: true),
    ]);

    await repository.updateAccount(_account(id: 'missing', name: 'Missing'));

    final accounts = await repository.getAccounts();
    expect(accounts.map((account) => account.id), ['account-1']);
  });

  test(
    'updateAccount keeps the existing primary when another account is updated as primary',
    () async {
      await _storeAccounts(accountsBox, [
        _account(id: 'account-1', name: 'Main', isPrimary: true),
        _account(id: 'account-2', name: 'Travel'),
      ]);

      await repository.updateAccount(
        _account(id: 'account-2', name: 'Travel', isPrimary: true),
      );

      final accounts = await repository.getAccounts();
      expect(accounts.map((account) => account.id), ['account-1', 'account-2']);
      expect(
        accounts
            .where((account) => account.isPrimary)
            .map((account) => account.id),
        ['account-1'],
      );
    },
  );

  test('deleteAccount removes the matching account', () async {
    await _storeAccounts(accountsBox, [
      _account(id: 'account-1', name: 'Wallet', isPrimary: true),
      _account(id: 'account-2', name: 'Savings'),
    ]);

    await repository.deleteAccount('account-1');

    final accounts = await repository.getAccounts();
    expect(accounts.map((account) => account.id), ['account-2']);
  });

  test(
    'deleteAccount removes malformed duplicate primaries from the remaining list',
    () async {
      await accountsBox.put(HiveStorage.accountsKey, [
        _account(id: 'account-1', name: 'Wallet', isPrimary: true).toMap(),
        _account(id: 'account-2', name: 'Savings', isPrimary: true).toMap(),
        _account(id: 'account-3', name: 'Travel').toMap(),
      ]);

      await repository.deleteAccount('account-1');

      final accounts = await repository.getAccounts();
      expect(accounts.map((account) => account.id), ['account-2', 'account-3']);
      expect(
        accounts
            .where((account) => account.isPrimary)
            .map((account) => account.id),
        isEmpty,
      );
    },
  );

  test('createAccountId returns a UUID', () {
    expect(repository.createAccountId(), matches(_uuidPattern));
  });

  test('getAccounts skips malformed stored entries', () async {
    await accountsBox.put(HiveStorage.accountsKey, [
      _account(id: 'account-1', name: 'Wallet', isPrimary: true).toMap(),
      {
        'id': 'broken-account',
        'name': 123,
        'type': 'cash',
        'openingBalance': 0,
        'currencyCode': 'EUR',
      },
    ]);

    final accounts = await repository.getAccounts();

    expect(accounts.map((account) => account.id), ['account-1']);
  });
}

Future<void> _storeAccounts(Box<dynamic> box, List<Account> accounts) {
  return box.put(
    HiveStorage.accountsKey,
    accounts.map((account) => account.toMap()).toList(growable: false),
  );
}

Account _account({
  required String id,
  required String name,
  bool isPrimary = false,
}) {
  return Account(
    id: id,
    name: name,
    type: AccountType.cash,
    openingBalance: 0,
    currencyCode: 'EUR',
    isPrimary: isPrimary,
  );
}

final _uuidPattern = RegExp(
  r'^[0-9a-fA-F]{8}-'
  r'[0-9a-fA-F]{4}-'
  r'[0-9a-fA-F]{4}-'
  r'[0-9a-fA-F]{4}-'
  r'[0-9a-fA-F]{12}$',
);
