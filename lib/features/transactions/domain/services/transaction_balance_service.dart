import 'package:expense_tracker/features/accounts/data/account_repository.dart';
import 'package:expense_tracker/features/accounts/domain/models/account.dart';
import 'package:expense_tracker/features/transactions/data/transaction_repository.dart';
import 'package:expense_tracker/features/transactions/domain/models/transaction_item.dart';

class TransactionBalanceService {
  const TransactionBalanceService({
    required AccountRepository accountRepository,
    required TransactionRepository transactionRepository,
  }) : _accountRepository = accountRepository,
       _transactionRepository = transactionRepository;

  final AccountRepository _accountRepository;
  final TransactionRepository _transactionRepository;

  Future<void> saveTransaction(
    TransactionItem transaction, {
    required bool isEditing,
    TransactionItem? previousTransaction,
    required List<Account> currentAccounts,
  }) async {
    final balanceChanges = calculateNetBalanceChanges(
      previous: previousTransaction,
      next: transaction,
    );

    await applyBalanceChanges(
      changes: balanceChanges,
      currentAccounts: currentAccounts,
    );

    try {
      if (isEditing) {
        await _transactionRepository.updateTransaction(transaction);
        return;
      }

      await _transactionRepository.addTransaction(transaction);
    } catch (_) {
      await applyBalanceChanges(
        changes: invertBalanceChanges(balanceChanges),
        currentAccounts: currentAccounts,
      );
      rethrow;
    }
  }

  Future<void> deleteTransaction(
    String transactionId, {
    required TransactionItem? existingTransaction,
    required List<Account> currentAccounts,
  }) async {
    final balanceChanges = invertBalanceChanges(
      existingTransaction?.balanceChanges ?? const {},
    );

    await applyBalanceChanges(
      changes: balanceChanges,
      currentAccounts: currentAccounts,
    );

    try {
      await _transactionRepository.deleteTransaction(transactionId);
    } catch (_) {
      await applyBalanceChanges(
        changes: invertBalanceChanges(balanceChanges),
        currentAccounts: currentAccounts,
      );
      rethrow;
    }
  }

  Map<String, double> calculateNetBalanceChanges({
    required TransactionItem? previous,
    required TransactionItem next,
  }) {
    final netChanges = <String, double>{};

    void merge(Map<String, double> changes, {required double multiplier}) {
      for (final entry in changes.entries) {
        netChanges.update(
          entry.key,
          (value) => value + (entry.value * multiplier),
          ifAbsent: () => entry.value * multiplier,
        );
      }
    }

    if (previous != null) {
      merge(previous.balanceChanges, multiplier: -1);
    }
    merge(next.balanceChanges, multiplier: 1);

    netChanges.removeWhere((_, value) => value == 0);
    return netChanges;
  }

  Map<String, double> invertBalanceChanges(Map<String, double> changes) {
    return {for (final entry in changes.entries) entry.key: -entry.value};
  }

  Future<void> applyBalanceChanges({
    required Map<String, double> changes,
    required List<Account> currentAccounts,
  }) async {
    if (changes.isEmpty) {
      return;
    }

    final accountsById = {
      for (final account in currentAccounts) account.id: account,
    };
    final originalAccounts = <String, Account>{};

    for (final entry in changes.entries) {
      final account = accountsById[entry.key];
      if (account == null) {
        throw StateError(
          'Cannot update balance for missing account ${entry.key}.',
        );
      }

      originalAccounts[entry.key] = account;
      accountsById[entry.key] = account.copyWith(
        balance: account.balance + entry.value,
      );
    }

    final updatedAccountIds = <String>[];

    try {
      for (final accountId in changes.keys) {
        await _accountRepository.updateAccount(accountsById[accountId]!);
        updatedAccountIds.add(accountId);
      }
    } catch (_) {
      for (final accountId in updatedAccountIds.reversed) {
        await _accountRepository.updateAccount(originalAccounts[accountId]!);
      }
      rethrow;
    }
  }
}
