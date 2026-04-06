import 'package:expense_tracker/core/utils/currency_conversion_service.dart';
import 'package:expense_tracker/features/accounts/domain/models/account.dart';
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
  }) async {
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
        return transaction;
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

      final destinationAmount = await _currencyConversionService
          .tryConvertAmount(
            amount: sourceAmount,
            fromCurrencyCode: sourceCurrencyCode,
            toCurrencyCode: destinationAccount.currencyCode,
            date: transaction.date,
          );
      if (destinationAmount == null) {
        throw StateError(
          'Could not convert the transfer into the destination currency.',
        );
      }

      final transferRate = sourceCurrencyCode == destinationAccount.currencyCode
          ? 1.0
          : destinationAmount / sourceAmount;

      return transaction.copyWith(
        amount: sourceAmount,
        currencyCode: sourceCurrencyCode,
        destinationAmount: destinationAmount,
        destinationCurrencyCode: destinationAccount.currencyCode,
        exchangeRate: transferRate,
      );
    }

    final account = accountsById[transaction.accountId];
    if (account == null) {
      return transaction;
    }

    final targetCurrencyCode = account.currencyCode;
    final enteredCurrencyCode =
        transaction.foreignCurrencyCode ?? transaction.currencyCode;
    final enteredAmount = transaction.foreignAmount ?? transaction.amount;
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

    return transaction.copyWith(
      amount: normalizedAmount,
      currencyCode: targetCurrencyCode,
      exchangeRate: enteredCurrencyCode == targetCurrencyCode
          ? 1
          : normalizedAmount / enteredAmount,
      clearExchangeRate: enteredCurrencyCode == targetCurrencyCode,
    );
  }
}
