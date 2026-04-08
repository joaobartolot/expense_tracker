import 'package:expense_tracker/core/logging/scoped_log_printer.dart';
import 'package:expense_tracker/core/storage/hive_storage.dart';
import 'package:expense_tracker/features/accounts/domain/models/account.dart';
import 'package:expense_tracker/features/categories/domain/models/category_item.dart';
import 'package:expense_tracker/features/transactions/data/transaction_repository.dart';
import 'package:expense_tracker/features/transactions/domain/models/transaction_item.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:logger/logger.dart';
import 'package:uuid/uuid.dart';

final _logger = Logger(printer: ScopedLogPrinter('transactions_repository'));
const _uuid = Uuid();

class TransactionValidationException implements Exception {
  const TransactionValidationException(this.message);

  final String message;

  @override
  String toString() => 'TransactionValidationException: $message';
}

class HiveTransactionRepository implements TransactionRepository {
  HiveTransactionRepository()
    : _box = Hive.box(HiveStorage.transactionsBoxName),
      _accountsBox = Hive.box(HiveStorage.accountsBoxName),
      _categoriesBox = Hive.box(HiveStorage.categoriesBoxName);

  final Box<dynamic> _box;
  final Box<dynamic> _accountsBox;
  final Box<dynamic> _categoriesBox;

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
  ValueListenable<Box<dynamic>> listenable() {
    return _box.listenable(keys: [HiveStorage.transactionsKey]);
  }

  @override
  Future<void> addTransaction(TransactionItem transaction) async {
    try {
      final preparedTransaction = _prepareForCreate(transaction);
      final transactions = _readTransactions()..insert(0, preparedTransaction);
      await _saveTransactions(transactions);
      _logger.i('Saved transaction ${preparedTransaction.id}.');
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
      final preparedTransaction = _prepareForUpdate(transaction);
      final transactions = _readTransactions();
      final index = transactions.indexWhere(
        (item) => item.id == preparedTransaction.id,
      );
      if (index == -1) {
        throw TransactionValidationException(
          'Cannot update missing transaction ${preparedTransaction.id}.',
        );
      }

      transactions[index] = preparedTransaction;
      await _saveTransactions(transactions);
      _logger.i('Updated transaction ${preparedTransaction.id}.');
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
    _logger.d('Saving ${transactions.length} transactions to Hive.');
    return _box.put(
      HiveStorage.transactionsKey,
      transactions.map((item) => item.toMap()).toList(growable: false),
    );
  }

  List<TransactionItem> _readTransactions() {
    _logger.d('Reading transactions from Hive.');
    final storedTransactions =
        (_box.get(HiveStorage.transactionsKey) as List<dynamic>? ?? const [])
            .cast<Map<dynamic, dynamic>>();

    final transactions = <TransactionItem>[];
    for (final map in storedTransactions) {
      try {
        transactions.add(TransactionItem.fromMap(map));
      } catch (error, stackTrace) {
        _logger.w(
          'Skipped invalid stored transaction entry.',
          error: error,
          stackTrace: stackTrace,
        );
      }
    }

    return transactions;
  }

  TransactionItem _prepareForCreate(TransactionItem transaction) {
    final normalizedId = transaction.id.trim().isEmpty
        ? createTransactionId()
        : transaction.id;
    final transactionWithId = transaction.copyWith(id: normalizedId);
    return _prepareForPersistence(transactionWithId);
  }

  TransactionItem _prepareForUpdate(TransactionItem transaction) {
    if (transaction.id.trim().isEmpty) {
      throw const TransactionValidationException(
        'Transaction ID is required for updates.',
      );
    }

    return _prepareForPersistence(transaction);
  }

  TransactionItem _prepareForPersistence(TransactionItem transaction) {
    final normalizedTransaction = transaction.isTransfer
        ? transaction
        : _normalizeIncomeOrExpense(transaction);
    _validateTransaction(normalizedTransaction);
    return normalizedTransaction;
  }

  TransactionItem _normalizeIncomeOrExpense(TransactionItem transaction) {
    final account = _accountForId(transaction.accountId);
    if (account == null) {
      throw const TransactionValidationException(
        'Income and expense transactions require a valid account.',
      );
    }

    final category = _categoryForId(transaction.categoryId);
    if (category == null) {
      throw const TransactionValidationException(
        'Income and expense transactions require a valid category.',
      );
    }

    _validateCategoryType(category, type: transaction.type);

    final targetCurrencyCode = account.currencyCode.trim().toUpperCase();
    final mainCurrencyCode = transaction.currencyCode.trim().toUpperCase();
    final foreignCurrencyCode = transaction.foreignCurrencyCode?.trim();
    final hasForeignSnapshot =
        transaction.foreignAmount != null ||
        (foreignCurrencyCode != null && foreignCurrencyCode.isNotEmpty) ||
        transaction.exchangeRate != null;

    if (_isSameCurrency(mainCurrencyCode, targetCurrencyCode)) {
      if (!hasForeignSnapshot) {
        return transaction.copyWith(
          amount: _normalizeMoney(transaction.amount),
          currencyCode: targetCurrencyCode,
          clearForeignAmount: true,
          clearForeignCurrencyCode: true,
          clearExchangeRate: true,
        );
      }

      if (foreignCurrencyCode == null || foreignCurrencyCode.isEmpty) {
        throw const TransactionValidationException(
          'Foreign-currency transactions require a complete snapshot.',
        );
      }

      if (_isSameCurrency(foreignCurrencyCode, targetCurrencyCode)) {
        return transaction.copyWith(
          amount: _normalizeMoney(transaction.amount),
          currencyCode: targetCurrencyCode,
          clearForeignAmount: true,
          clearForeignCurrencyCode: true,
          clearExchangeRate: true,
        );
      }

      if (transaction.foreignAmount == null ||
          transaction.exchangeRate == null) {
        throw const TransactionValidationException(
          'Foreign-currency transactions require a complete snapshot.',
        );
      }

      return transaction.copyWith(
        amount: _normalizeMoney(transaction.amount),
        currencyCode: targetCurrencyCode,
        foreignAmount: _normalizeMoney(transaction.foreignAmount!),
        foreignCurrencyCode: foreignCurrencyCode.toUpperCase(),
      );
    }

    if (transaction.foreignAmount == null ||
        foreignCurrencyCode == null ||
        foreignCurrencyCode.isEmpty ||
        transaction.exchangeRate == null) {
      throw const TransactionValidationException(
        'Foreign-currency transactions require a complete snapshot.',
      );
    }

    if (!_isSameCurrency(foreignCurrencyCode, mainCurrencyCode)) {
      throw const TransactionValidationException(
        'Foreign-currency snapshot must match the entered currency.',
      );
    }

    final normalizedAmount = _normalizeMoney(
      transaction.foreignAmount! * transaction.exchangeRate!,
    );
    if (normalizedAmount <= 0) {
      throw const TransactionValidationException(
        'Transaction amount must be greater than zero.',
      );
    }

    return transaction.copyWith(
      amount: normalizedAmount,
      currencyCode: targetCurrencyCode,
      foreignAmount: _normalizeMoney(transaction.foreignAmount!),
      foreignCurrencyCode: foreignCurrencyCode.toUpperCase(),
    );
  }

  void _validateTransaction(TransactionItem transaction) {
    if (transaction.title.trim().isEmpty) {
      throw const TransactionValidationException(
        'Transaction title is required.',
      );
    }

    if (transaction.amount <= 0) {
      throw const TransactionValidationException(
        'Transaction amount must be greater than zero.',
      );
    }

    if (transaction.isTransfer) {
      final sourceAccountId = transaction.sourceAccountId?.trim();
      final destinationAccountId = transaction.destinationAccountId?.trim();

      if (!_hasValue(sourceAccountId) || !_hasValue(destinationAccountId)) {
        throw const TransactionValidationException(
          'Transfers require a source and destination account.',
        );
      }

      if (sourceAccountId == destinationAccountId) {
        throw const TransactionValidationException(
          'Transfers must use different source and destination accounts.',
        );
      }

      if (_hasValue(transaction.accountId) ||
          _hasValue(transaction.categoryId)) {
        throw const TransactionValidationException(
          'Transfers cannot keep income or expense account/category fields.',
        );
      }

      return;
    }

    if (!_hasValue(transaction.accountId) ||
        !_hasValue(transaction.categoryId)) {
      throw const TransactionValidationException(
        'Income and expense transactions require an account and category.',
      );
    }

    if (_hasValue(transaction.sourceAccountId) ||
        _hasValue(transaction.destinationAccountId)) {
      throw const TransactionValidationException(
        'Income and expense transactions cannot keep transfer account fields.',
      );
    }

    if (_accountForId(transaction.accountId) == null) {
      throw const TransactionValidationException(
        'Income and expense transactions require a valid account.',
      );
    }

    final category = _categoryForId(transaction.categoryId);
    if (category == null) {
      throw const TransactionValidationException(
        'Income and expense transactions require a valid category.',
      );
    }

    _validateCategoryType(category, type: transaction.type);
  }

  bool _hasValue(String? value) => value != null && value.trim().isNotEmpty;

  Account? _accountForId(String? accountId) {
    if (!_hasValue(accountId)) {
      return null;
    }

    final storedAccounts =
        (_accountsBox.get(HiveStorage.accountsKey) as List<dynamic>? ??
                const [])
            .cast<Map<dynamic, dynamic>>();
    for (final map in storedAccounts) {
      final account = Account.fromMap(map);
      if (account.id == accountId) {
        return account;
      }
    }

    return null;
  }

  CategoryItem? _categoryForId(String? categoryId) {
    if (!_hasValue(categoryId)) {
      return null;
    }

    final storedCategories =
        (_categoriesBox.get(HiveStorage.categoriesKey) as List<dynamic>? ??
                const [])
            .cast<Map<dynamic, dynamic>>();
    for (final map in storedCategories) {
      final category = CategoryItem.fromMap(map);
      if (category.id == categoryId) {
        return category;
      }
    }

    return null;
  }

  void _validateCategoryType(
    CategoryItem category, {
    required TransactionType type,
  }) {
    final expectedType = switch (type) {
      TransactionType.income => CategoryType.income,
      TransactionType.expense => CategoryType.expense,
      TransactionType.transfer => CategoryType.expense,
    };

    if (category.type != expectedType) {
      throw const TransactionValidationException(
        'Transaction category does not match the transaction type.',
      );
    }
  }

  double _normalizeMoney(double value) => value.roundToDouble();

  bool _isSameCurrency(String left, String right) {
    return left.trim().toUpperCase() == right.trim().toUpperCase();
  }
}
