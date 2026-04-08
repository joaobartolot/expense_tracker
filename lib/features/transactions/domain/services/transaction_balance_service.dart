import 'package:expense_tracker/core/utils/currency_conversion_service.dart';
import 'package:expense_tracker/features/accounts/domain/models/account.dart';
import 'package:expense_tracker/features/categories/domain/models/category_item.dart';
import 'package:expense_tracker/features/transactions/data/transaction_repository.dart';
import 'package:expense_tracker/features/transactions/domain/models/transaction_item.dart';

class TransactionBalanceService {
  const TransactionBalanceService({
    required CurrencyConversionService currencyConversionService,
    required TransactionRepository transactionRepository,
  }) : _currencyConversionService = currencyConversionService,
       _transactionRepository = transactionRepository;

  final CurrencyConversionService _currencyConversionService;
  final TransactionRepository _transactionRepository;

  Future<void> saveTransaction(
    TransactionItem transaction, {
    required bool isEditing,
    TransactionItem? previousTransaction,
    required List<Account> currentAccounts,
    List<CategoryItem> currentCategories = const [],
  }) async {
    _validateTransactionInput(
      transaction,
      currentCategories: currentCategories,
    );
    final normalizedTransaction = await _normalizeTransaction(
      transaction,
      currentAccounts: currentAccounts,
    );
    if (isEditing) {
      await _transactionRepository.updateTransaction(normalizedTransaction);
      return;
    }

    await _transactionRepository.addTransaction(normalizedTransaction);
  }

  Future<void> deleteTransaction(
    String transactionId, {
    required TransactionItem? existingTransaction,
    required List<Account> currentAccounts,
  }) async {
    await _transactionRepository.deleteTransaction(transactionId);
  }

  Future<void> deleteTransactions(
    List<TransactionItem> transactions, {
    required List<Account> currentAccounts,
  }) async {
    for (final transaction in transactions) {
      await deleteTransaction(
        transaction.id,
        existingTransaction: transaction,
        currentAccounts: currentAccounts,
      );
    }
  }

  Future<TransactionItem> _normalizeTransaction(
    TransactionItem transaction, {
    required List<Account> currentAccounts,
  }) async {
    final accountsById = {
      for (final account in currentAccounts) account.id: account,
    };

    if (transaction.isTransfer) {
      final sourceAccount = accountsById[transaction.sourceAccountId];
      final destinationAccount = accountsById[transaction.destinationAccountId];
      if (sourceAccount == null || destinationAccount == null) {
        throw StateError('Could not resolve the transfer accounts.');
      }

      final sourceCurrencyCode = sourceAccount.currencyCode;
      final enteredCurrencyCode =
          transaction.foreignCurrencyCode ?? transaction.currencyCode;
      final enteredAmount = transaction.foreignAmount ?? transaction.amount;
      final sourceAmount = await _currencyConversionService.tryConvertAmount(
        amount: enteredAmount,
        fromCurrencyCode: enteredCurrencyCode,
        toCurrencyCode: sourceCurrencyCode,
        date: transaction.date,
      );
      if (sourceAmount == null) {
        throw StateError(
          'Could not convert the transfer into the source currency.',
        );
      }
      final roundedSourceAmount = _normalizeMoney(sourceAmount);
      if (roundedSourceAmount <= 0) {
        throw StateError('Transfer amount must be greater than zero.');
      }

      final destinationAmount = await _currencyConversionService
          .tryConvertAmount(
            amount: roundedSourceAmount,
            fromCurrencyCode: sourceCurrencyCode,
            toCurrencyCode: destinationAccount.currencyCode,
            date: transaction.date,
          );
      if (destinationAmount == null) {
        throw StateError(
          'Could not convert the transfer into the destination currency.',
        );
      }
      final roundedDestinationAmount = _normalizeMoney(destinationAmount);
      if (roundedDestinationAmount <= 0) {
        throw StateError(
          'Transfer destination amount must be greater than zero.',
        );
      }

      final transferRate = sourceCurrencyCode == destinationAccount.currencyCode
          ? 1.0
          : roundedDestinationAmount / roundedSourceAmount;

      return transaction.copyWith(
        amount: roundedSourceAmount,
        currencyCode: sourceCurrencyCode,
        destinationAmount: roundedDestinationAmount,
        destinationCurrencyCode: destinationAccount.currencyCode,
        exchangeRate: transferRate,
      );
    }

    final account = accountsById[transaction.accountId];
    if (account == null) {
      throw StateError('Could not resolve the transaction account.');
    }

    final targetCurrencyCode = account.currencyCode;
    final enteredCurrencyCode = _enteredCurrencyCodeFor(
      transaction,
      targetCurrencyCode: targetCurrencyCode,
    );
    final enteredAmount = _enteredAmountFor(
      transaction,
      targetCurrencyCode: targetCurrencyCode,
    );

    if (_isSameCurrency(enteredCurrencyCode, targetCurrencyCode)) {
      final normalizedAmount = _normalizeMoney(enteredAmount);
      if (normalizedAmount <= 0) {
        throw StateError('Transaction amount must be greater than zero.');
      }

      return transaction.copyWith(
        amount: normalizedAmount,
        currencyCode: targetCurrencyCode,
        clearForeignAmount: true,
        clearForeignCurrencyCode: true,
        clearExchangeRate: true,
      );
    }

    final normalizedAmount = await _currencyConversionService.tryConvertAmount(
      amount: enteredAmount,
      fromCurrencyCode: enteredCurrencyCode,
      toCurrencyCode: targetCurrencyCode,
      date: transaction.date,
    );

    if (normalizedAmount == null) {
      throw StateError(
        'Could not convert the transaction into the account currency.',
      );
    }

    final roundedNormalizedAmount = _normalizeMoney(normalizedAmount);
    if (roundedNormalizedAmount <= 0) {
      throw StateError('Transaction amount must be greater than zero.');
    }

    return transaction.copyWith(
      amount: roundedNormalizedAmount,
      currencyCode: targetCurrencyCode,
      foreignAmount: _normalizeMoney(enteredAmount),
      foreignCurrencyCode: enteredCurrencyCode,
      exchangeRate: roundedNormalizedAmount / enteredAmount,
    );
  }

  void _validateTransactionInput(
    TransactionItem transaction, {
    required List<CategoryItem> currentCategories,
  }) {
    if (transaction.title.trim().isEmpty) {
      throw StateError('Transaction title is required.');
    }

    if (transaction.amount <= 0) {
      throw StateError('Transaction amount must be greater than zero.');
    }

    if (transaction.isTransfer) {
      return;
    }

    if (!_hasValue(transaction.accountId)) {
      throw StateError('Transaction account is required.');
    }

    if (!_hasValue(transaction.categoryId)) {
      throw StateError('Transaction category is required.');
    }

    final category = _categoryById(currentCategories, transaction.categoryId);
    if (category == null) {
      throw StateError('Transaction category is invalid.');
    }

    _validateCategoryType(category, type: transaction.type);
  }

  String _enteredCurrencyCodeFor(
    TransactionItem transaction, {
    required String targetCurrencyCode,
  }) {
    final foreignCurrencyCode = transaction.foreignCurrencyCode?.trim();
    final mainCurrencyCode = transaction.currencyCode.trim();
    final hasForeignAmount = transaction.foreignAmount != null;
    final hasExchangeRate = transaction.exchangeRate != null;

    final hasAnyForeignSnapshot =
        hasForeignAmount ||
        (foreignCurrencyCode != null && foreignCurrencyCode.isNotEmpty) ||
        hasExchangeRate;

    if (_isSameCurrency(mainCurrencyCode, targetCurrencyCode)) {
      if (!hasAnyForeignSnapshot) {
        return targetCurrencyCode;
      }

      if (foreignCurrencyCode == null || foreignCurrencyCode.isEmpty) {
        throw StateError('Foreign currency snapshot is incomplete.');
      }

      if (_isSameCurrency(foreignCurrencyCode, targetCurrencyCode)) {
        return targetCurrencyCode;
      }

      if (transaction.foreignAmount == null ||
          transaction.exchangeRate == null) {
        throw StateError('Foreign currency snapshot is incomplete.');
      }

      return foreignCurrencyCode;
    }

    if (transaction.foreignAmount == null ||
        foreignCurrencyCode == null ||
        foreignCurrencyCode.isEmpty ||
        transaction.exchangeRate == null) {
      throw StateError('Foreign currency snapshot is incomplete.');
    }

    if (!_isSameCurrency(foreignCurrencyCode, mainCurrencyCode)) {
      throw StateError('Foreign currency snapshot is inconsistent.');
    }

    return foreignCurrencyCode;
  }

  double _enteredAmountFor(
    TransactionItem transaction, {
    required String targetCurrencyCode,
  }) {
    final enteredCurrencyCode = _enteredCurrencyCodeFor(
      transaction,
      targetCurrencyCode: targetCurrencyCode,
    );

    if (_isSameCurrency(enteredCurrencyCode, targetCurrencyCode)) {
      return transaction.amount;
    }

    final foreignAmount = transaction.foreignAmount;
    if (foreignAmount == null) {
      throw StateError('Foreign currency snapshot is incomplete.');
    }

    return foreignAmount;
  }

  double _normalizeMoney(double value) => value.roundToDouble();

  bool _isSameCurrency(String left, String right) {
    return left.trim().toUpperCase() == right.trim().toUpperCase();
  }

  bool _hasValue(String? value) => value != null && value.trim().isNotEmpty;

  CategoryItem? _categoryById(
    List<CategoryItem> categories,
    String? categoryId,
  ) {
    if (!_hasValue(categoryId)) {
      return null;
    }

    for (final category in categories) {
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
      throw StateError('Transaction category does not match the type.');
    }
  }
}
