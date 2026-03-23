import 'package:expense_tracker/core/logging/scoped_log_printer.dart';
import 'package:expense_tracker/core/storage/hive_storage.dart';
import 'package:expense_tracker/features/transactions/data/transaction_repository.dart';
import 'package:expense_tracker/features/transactions/domain/models/transaction_item.dart';
import 'package:hive/hive.dart';
import 'package:logger/logger.dart';
import 'package:uuid/uuid.dart';

final _logger = Logger(printer: ScopedLogPrinter('transactions_repository'));
const _uuid = Uuid();

class HiveTransactionRepository implements TransactionRepository {
  HiveTransactionRepository()
    : _box = Hive.box(HiveStorage.transactionsBoxName);

  final Box<dynamic> _box;

  @override
  Future<List<TransactionItem>> getTransactions() async {
    try {
      return _readTransactions();
    } catch (error, stackTrace) {
      _logger.e(
        'Failed to read transactions from Hive.',
        error: error,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  @override
  Future<void> addTransaction(TransactionItem transaction) async {
    try {
      final transactions = _readTransactions()..insert(0, transaction);
      await _saveTransactions(transactions);
      _logger.i('Saved transaction ${transaction.id}.');
    } catch (error, stackTrace) {
      _logger.e(
        'Failed to add transaction ${transaction.id}.',
        error: error,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  @override
  Future<void> updateTransaction(TransactionItem transaction) async {
    try {
      final transactions = _readTransactions();
      final index = transactions.indexWhere(
        (item) => item.id == transaction.id,
      );
      if (index == -1) {
        _logger.w('Skipped update for missing transaction ${transaction.id}.');
        return;
      }

      transactions[index] = transaction;
      await _saveTransactions(transactions);
      _logger.i('Updated transaction ${transaction.id}.');
    } catch (error, stackTrace) {
      _logger.e(
        'Failed to update transaction ${transaction.id}.',
        error: error,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  @override
  Future<void> deleteTransaction(String transactionId) async {
    try {
      final transactions = _readTransactions()
        ..removeWhere((transaction) => transaction.id == transactionId);
      await _saveTransactions(transactions);
      _logger.i('Deleted transaction $transactionId.');
    } catch (error, stackTrace) {
      _logger.e(
        'Failed to delete transaction $transactionId.',
        error: error,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  @override
  String createTransactionId() {
    return _uuid.v4();
  }

  Future<void> _saveTransactions(List<TransactionItem> transactions) {
    return _box.put(
      HiveStorage.transactionsKey,
      transactions.map((item) => item.toMap()).toList(growable: false),
    );
  }

  List<TransactionItem> _readTransactions() {
    final storedTransactions =
        (_box.get(HiveStorage.transactionsKey) as List<dynamic>? ?? const [])
            .cast<Map<dynamic, dynamic>>();

    return storedTransactions.map(TransactionItem.fromMap).toList();
  }
}
