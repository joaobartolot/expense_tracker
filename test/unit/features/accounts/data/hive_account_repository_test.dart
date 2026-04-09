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

  test('updateAccount ignores missing accounts', () async {
    await _storeAccounts(accountsBox, [
      _account(id: 'account-1', name: 'Wallet', isPrimary: true),
    ]);

    await repository.updateAccount(_account(id: 'missing', name: 'Missing'));

    final accounts = await repository.getAccounts();
    expect(accounts.map((account) => account.id), ['account-1']);
  });

  test('deleteAccount removes the matching account', () async {
    await _storeAccounts(accountsBox, [
      _account(id: 'account-1', name: 'Wallet', isPrimary: true),
      _account(id: 'account-2', name: 'Savings'),
    ]);

    await repository.deleteAccount('account-1');

    final accounts = await repository.getAccounts();
    expect(accounts.map((account) => account.id), ['account-2']);
  });

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
