import 'package:expense_tracker/features/accounts/domain/models/account.dart';
import 'package:expense_tracker/features/recurring_transactions/data/recurring_transaction_repository.dart';
import 'package:expense_tracker/features/recurring_transactions/domain/models/recurring_transaction.dart';
import 'package:expense_tracker/features/recurring_transactions/domain/services/recurring_schedule_service.dart';
import 'package:expense_tracker/features/transactions/domain/models/transaction_item.dart';
import 'package:expense_tracker/features/transactions/domain/services/transaction_balance_service.dart';

class RecurringTransactionExecutionService {
  const RecurringTransactionExecutionService({
    required RecurringScheduleService recurringScheduleService,
    required RecurringTransactionRepository recurringTransactionRepository,
    required TransactionBalanceService transactionBalanceService,
  }) : _recurringScheduleService = recurringScheduleService,
       _recurringTransactionRepository = recurringTransactionRepository,
       _transactionBalanceService = transactionBalanceService;

  final RecurringScheduleService _recurringScheduleService;
  final RecurringTransactionRepository _recurringTransactionRepository;
  final TransactionBalanceService _transactionBalanceService;

  Future<bool> processAutomaticTransactions({
    required List<RecurringTransaction> recurringTransactions,
    required List<Account> currentAccounts,
    required DateTime now,
    required String Function() createTransactionId,
  }) async {
    var didChange = false;

    for (final recurringTransaction in recurringTransactions) {
      if (!recurringTransaction.isAutomatic || recurringTransaction.isPaused) {
        continue;
      }

      final dueOccurrences =
          recurringTransaction.lastProcessedOccurrenceDate == null
          ? _initialAutomaticDueOccurrences(recurringTransaction, now: now)
          : _recurringScheduleService.dueOccurrences(
              recurringTransaction,
              now: now,
            );
      if (dueOccurrences.isEmpty) {
        continue;
      }

      var updatedRecurringTransaction = recurringTransaction;
      for (final dueOccurrence in dueOccurrences) {
        await _transactionBalanceService.saveTransaction(
          _buildTransaction(
            recurringTransaction,
            occurrenceDate: dueOccurrence,
            transactionId: createTransactionId(),
            currentAccounts: currentAccounts,
          ),
          isEditing: false,
          currentAccounts: currentAccounts,
        );
        updatedRecurringTransaction = updatedRecurringTransaction.copyWith(
          lastProcessedOccurrenceDate: dueOccurrence,
        );
      }

      await _recurringTransactionRepository.updateRecurringTransaction(
        updatedRecurringTransaction,
      );
      didChange = true;
    }

    return didChange;
  }

  List<DateTime> _initialAutomaticDueOccurrences(
    RecurringTransaction recurringTransaction, {
    required DateTime now,
  }) {
    final latestDueOccurrence = _recurringScheduleService.latestDueOccurrence(
      recurringTransaction,
      now: now,
    );
    if (latestDueOccurrence == null) {
      return const [];
    }

    return [latestDueOccurrence];
  }

  Future<bool> confirmNextDueOccurrence({
    required RecurringTransaction recurringTransaction,
    required List<Account> currentAccounts,
    required DateTime now,
    required String Function() createTransactionId,
  }) async {
    final dueOccurrence = _recurringScheduleService.nextDueOccurrence(
      recurringTransaction,
      now: now,
    );
    if (dueOccurrence == null) {
      return false;
    }

    if (_startOfDay(dueOccurrence).isAfter(_startOfDay(now))) {
      return false;
    }

    await _transactionBalanceService.saveTransaction(
      _buildTransaction(
        recurringTransaction,
        occurrenceDate: dueOccurrence,
        transactionId: createTransactionId(),
        currentAccounts: currentAccounts,
      ),
      isEditing: false,
      currentAccounts: currentAccounts,
    );
    await _recurringTransactionRepository.updateRecurringTransaction(
      recurringTransaction.copyWith(lastProcessedOccurrenceDate: dueOccurrence),
    );
    return true;
  }

  TransactionItem _buildTransaction(
    RecurringTransaction recurringTransaction, {
    required DateTime occurrenceDate,
    required String transactionId,
    required List<Account> currentAccounts,
  }) {
    final destinationAccount = currentAccounts
        .where(
          (account) => account.id == recurringTransaction.destinationAccountId,
        )
        .firstOrNull;

    return TransactionItem(
      id: transactionId,
      title: recurringTransaction.title,
      categoryId: recurringTransaction.isTransfer
          ? null
          : recurringTransaction.categoryId,
      accountId: recurringTransaction.isTransfer
          ? null
          : recurringTransaction.accountId,
      amount: recurringTransaction.amount,
      currencyCode: recurringTransaction.currencyCode,
      date: occurrenceDate,
      type: recurringTransaction.type,
      sourceAccountId: recurringTransaction.isTransfer
          ? recurringTransaction.sourceAccountId
          : null,
      destinationAccountId: recurringTransaction.isTransfer
          ? recurringTransaction.destinationAccountId
          : null,
      transferKind:
          recurringTransaction.isTransfer &&
              destinationAccount?.isCreditCard == true
          ? TransactionTransferKind.creditCardPayment
          : null,
    );
  }

  DateTime _startOfDay(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }
}
