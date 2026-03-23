import 'package:expense_tracker/core/logging/scoped_log_printer.dart';
import 'package:expense_tracker/core/storage/hive_storage.dart';
import 'package:expense_tracker/features/accounts/data/account_repository.dart';
import 'package:expense_tracker/features/accounts/domain/models/account.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:logger/logger.dart';
import 'package:uuid/uuid.dart';

final _logger = Logger(printer: ScopedLogPrinter('accounts_repository'));
const _uuid = Uuid();

class HiveAccountRepository implements AccountRepository {
  Box<dynamic> get _box => Hive.box(HiveStorage.accountsBoxName);

  @override
  Future<List<Account>> getAccounts() async {
    try {
      return _readAccounts();
    } catch (error, stackTrace) {
      _logger.e(
        'Failed to read accounts from Hive.',
        error: error,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  @override
  ValueListenable<Box<dynamic>> listenable() {
    return _box.listenable(keys: [HiveStorage.accountsKey]);
  }

  @override
  Future<void> addAccount(Account account) async {
    try {
      final accounts = _readAccounts();
      final shouldBePrimary = account.isPrimary || accounts.isEmpty;
      final accountToSave = account.copyWith(isPrimary: shouldBePrimary);

      if (shouldBePrimary) {
        accounts.insert(0, accountToSave);
      } else {
        final primaryIndex = accounts.indexWhere((item) => item.isPrimary);
        final insertIndex = primaryIndex == -1 ? 0 : primaryIndex + 1;
        accounts.insert(insertIndex, accountToSave);
      }

      await _saveAccounts(_normalizeAccounts(accounts));
      _logger.i('Saved account ${account.id}.');
    } catch (error, stackTrace) {
      _logger.e(
        'Failed to add account ${account.id}.',
        error: error,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  @override
  Future<void> updateAccount(Account account) async {
    try {
      final accounts = _readAccounts();
      final index = accounts.indexWhere((item) => item.id == account.id);
      if (index == -1) {
        _logger.w('Skipped update for missing account ${account.id}.');
        return;
      }

      accounts[index] = account;
      await _saveAccounts(_normalizeAccounts(accounts));
      _logger.i('Updated account ${account.id}.');
    } catch (error, stackTrace) {
      _logger.e(
        'Failed to update account ${account.id}.',
        error: error,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  @override
  Future<void> deleteAccount(String accountId) async {
    try {
      final accounts = _readAccounts()
        ..removeWhere((account) => account.id == accountId);
      await _saveAccounts(_normalizeAccounts(accounts));
      _logger.i('Deleted account $accountId.');
    } catch (error, stackTrace) {
      _logger.e(
        'Failed to delete account $accountId.',
        error: error,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  @override
  Future<void> reorderAccounts(List<Account> accounts) async {
    try {
      await _saveAccounts(_normalizeAccounts(accounts));
      _logger.i('Reordered ${accounts.length} accounts.');
    } catch (error, stackTrace) {
      _logger.e(
        'Failed to reorder accounts.',
        error: error,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  @override
  String createAccountId() {
    return _uuid.v4();
  }

  Future<void> _saveAccounts(List<Account> accounts) {
    return _box.put(
      HiveStorage.accountsKey,
      accounts.map((item) => item.toMap()).toList(growable: false),
    );
  }

  List<Account> _readAccounts() {
    final storedAccounts =
        (_box.get(HiveStorage.accountsKey) as List<dynamic>? ?? const [])
            .cast<Map<dynamic, dynamic>>();

    return _normalizeAccounts(storedAccounts.map(Account.fromMap).toList());
  }

  List<Account> _normalizeAccounts(List<Account> accounts) {
    if (accounts.isEmpty) {
      return accounts;
    }

    final primaryIndex = accounts.indexWhere((account) => account.isPrimary);
    if (primaryIndex == -1) {
      return List<Account>.from(accounts);
    }

    final primaryAccount = accounts[primaryIndex].copyWith(isPrimary: true);
    final otherAccounts = [
      for (var index = 0; index < accounts.length; index++)
        if (index != primaryIndex) accounts[index].copyWith(isPrimary: false),
    ];

    return [primaryAccount, ...otherAccounts];
  }
}
