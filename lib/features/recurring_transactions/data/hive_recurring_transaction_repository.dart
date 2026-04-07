import 'package:expense_tracker/core/logging/scoped_log_printer.dart';
import 'package:expense_tracker/core/storage/hive_storage.dart';
import 'package:expense_tracker/features/recurring_transactions/data/recurring_transaction_repository.dart';
import 'package:expense_tracker/features/recurring_transactions/domain/models/recurring_transaction.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:logger/logger.dart';
import 'package:uuid/uuid.dart';

final _logger = Logger(
  printer: ScopedLogPrinter('recurring_transactions_repository'),
);
const _uuid = Uuid();

class RecurringTransactionValidationException implements Exception {
  const RecurringTransactionValidationException(this.message);

  final String message;

  @override
  String toString() => 'RecurringTransactionValidationException: $message';
}

class HiveRecurringTransactionRepository
    implements RecurringTransactionRepository {
  HiveRecurringTransactionRepository()
    : _box = Hive.box(HiveStorage.recurringTransactionsBoxName);

  final Box<dynamic> _box;

  @override
  Future<List<RecurringTransaction>> getRecurringTransactions() async {
    try {
      return _readRecurringTransactions();
    } catch (error, stackTrace) {
      _logger.e(
        'Failed to read recurring transactions from Hive.',
        error: error,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  @override
  ValueListenable<Box<dynamic>> listenable() {
    return _box.listenable(keys: [HiveStorage.recurringTransactionsKey]);
  }

  @override
  Future<void> addRecurringTransaction(
    RecurringTransaction recurringTransaction,
  ) async {
    try {
      _validateRecurringTransaction(recurringTransaction);
      final recurringTransactions = _readRecurringTransactions()
        ..insert(0, recurringTransaction);
      await _saveRecurringTransactions(recurringTransactions);
      _logger.i('Saved recurring transaction ${recurringTransaction.id}.');
    } catch (error, stackTrace) {
      _logger.e(
        'Failed to add recurring transaction ${recurringTransaction.id}.',
        error: error,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  @override
  Future<void> updateRecurringTransaction(
    RecurringTransaction recurringTransaction,
  ) async {
    try {
      _validateRecurringTransaction(recurringTransaction);
      final recurringTransactions = _readRecurringTransactions();
      final index = recurringTransactions.indexWhere(
        (item) => item.id == recurringTransaction.id,
      );
      if (index == -1) {
        _logger.w(
          'Skipped update for missing recurring transaction ${recurringTransaction.id}.',
        );
        return;
      }

      recurringTransactions[index] = recurringTransaction;
      await _saveRecurringTransactions(recurringTransactions);
      _logger.i('Updated recurring transaction ${recurringTransaction.id}.');
    } catch (error, stackTrace) {
      _logger.e(
        'Failed to update recurring transaction ${recurringTransaction.id}.',
        error: error,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  @override
  Future<void> deleteRecurringTransaction(String recurringTransactionId) async {
    try {
      final recurringTransactions = _readRecurringTransactions()
        ..removeWhere(
          (transaction) => transaction.id == recurringTransactionId,
        );
      await _saveRecurringTransactions(recurringTransactions);
      _logger.i('Deleted recurring transaction $recurringTransactionId.');
    } catch (error, stackTrace) {
      _logger.e(
        'Failed to delete recurring transaction $recurringTransactionId.',
        error: error,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  @override
  String createRecurringTransactionId() {
    return _uuid.v4();
  }

  Future<void> _saveRecurringTransactions(
    List<RecurringTransaction> recurringTransactions,
  ) {
    return _box.put(
      HiveStorage.recurringTransactionsKey,
      recurringTransactions.map((item) => item.toMap()).toList(growable: false),
    );
  }

  List<RecurringTransaction> _readRecurringTransactions() {
    final storedTransactions =
        (_box.get(HiveStorage.recurringTransactionsKey) as List<dynamic>? ??
                const [])
            .cast<Map<dynamic, dynamic>>();

    final recurringTransactions = <RecurringTransaction>[];
    for (final map in storedTransactions) {
      try {
        recurringTransactions.add(RecurringTransaction.fromMap(map));
      } catch (error, stackTrace) {
        _logger.w(
          'Skipped invalid stored recurring transaction entry.',
          error: error,
          stackTrace: stackTrace,
        );
      }
    }

    return recurringTransactions;
  }

  void _validateRecurringTransaction(
    RecurringTransaction recurringTransaction,
  ) {
    if (recurringTransaction.title.trim().isEmpty) {
      throw const RecurringTransactionValidationException(
        'Recurring transaction title is required.',
      );
    }

    if (recurringTransaction.amount <= 0) {
      throw const RecurringTransactionValidationException(
        'Recurring transaction amount must be greater than zero.',
      );
    }

    if (recurringTransaction.isTransfer) {
      final sourceAccountId = recurringTransaction.sourceAccountId?.trim();
      final destinationAccountId = recurringTransaction.destinationAccountId
          ?.trim();

      if (!_hasValue(sourceAccountId) || !_hasValue(destinationAccountId)) {
        throw const RecurringTransactionValidationException(
          'Recurring transfers require a source and destination account.',
        );
      }

      if (sourceAccountId == destinationAccountId) {
        throw const RecurringTransactionValidationException(
          'Recurring transfers must use different source and destination accounts.',
        );
      }

      return;
    }

    if (!_hasValue(recurringTransaction.accountId) ||
        !_hasValue(recurringTransaction.categoryId)) {
      throw const RecurringTransactionValidationException(
        'Recurring income and expense entries require an account and category.',
      );
    }
  }

  bool _hasValue(String? value) => value != null && value.trim().isNotEmpty;
}
