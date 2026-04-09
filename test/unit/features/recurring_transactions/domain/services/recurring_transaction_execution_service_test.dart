import 'package:expense_tracker/features/accounts/domain/models/account.dart';
import 'package:expense_tracker/features/categories/domain/models/category_item.dart';
import 'package:expense_tracker/features/recurring_transactions/data/recurring_transaction_repository.dart';
import 'package:expense_tracker/features/recurring_transactions/domain/models/recurring_transaction.dart';
import 'package:expense_tracker/features/recurring_transactions/domain/services/recurring_schedule_service.dart';
import 'package:expense_tracker/features/recurring_transactions/domain/services/recurring_transaction_execution_service.dart';
import 'package:expense_tracker/features/transactions/domain/models/transaction_item.dart';
import 'package:expense_tracker/features/transactions/domain/services/transaction_balance_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

void main() {
  late _FakeRecurringTransactionRepository recurringTransactionRepository;
  late _FakeTransactionBalanceService transactionBalanceService;
  late RecurringTransactionExecutionService service;

  setUp(() {
    _generatedIdCounter = 0;
    recurringTransactionRepository = _FakeRecurringTransactionRepository();
    transactionBalanceService = _FakeTransactionBalanceService();
    service = RecurringTransactionExecutionService(
      recurringScheduleService: const RecurringScheduleService(),
      recurringTransactionRepository: recurringTransactionRepository,
      transactionBalanceService: transactionBalanceService,
    );
  });

  group('processAutomaticTransactions', () {
    test('skips paused and manual recurring transactions', () async {
      final didChange = await service.processAutomaticTransactions(
        recurringTransactions: [
          _expenseRecurring(
            id: 'paused-auto',
            startDate: DateTime(2026, 4, 1, 9),
            executionMode: RecurringExecutionMode.automatic,
            isPaused: true,
          ),
          _expenseRecurring(
            id: 'manual',
            startDate: DateTime(2026, 4, 1, 9),
            executionMode: RecurringExecutionMode.manual,
          ),
        ],
        currentAccounts: [_account()],
        now: DateTime(2026, 4, 9, 12),
        createTransactionId: _createTransactionId,
      );

      expect(didChange, isFalse);
      expect(transactionBalanceService.savedTransactions, isEmpty);
      expect(
        recurringTransactionRepository.updatedRecurringTransactions,
        isEmpty,
      );
    });

    test(
      'creates a due transaction for an automatic recurring transaction',
      () async {
        final didChange = await service.processAutomaticTransactions(
          recurringTransactions: [
            _expenseRecurring(
              id: 'salary',
              startDate: DateTime(2026, 4, 9, 9),
              executionMode: RecurringExecutionMode.automatic,
            ),
          ],
          currentAccounts: [_account()],
          now: DateTime(2026, 4, 9, 12),
          createTransactionId: _createTransactionId,
        );

        expect(didChange, isTrue);
        expect(transactionBalanceService.savedTransactions, hasLength(1));
        final call = transactionBalanceService.savedTransactions.single;
        expect(call.transaction.id, 'generated-1');
        expect(call.transaction.title, 'Recurring salary');
        expect(call.transaction.date, DateTime(2026, 4, 9, 9));
        expect(call.isEditing, isFalse);
        expect(call.currentAccounts.map((account) => account.id), [
          'account-wallet',
        ]);
        expect(
          recurringTransactionRepository
              .updatedRecurringTransactions
              .single
              .lastProcessedOccurrenceDate,
          DateTime(2026, 4, 9, 9),
        );
      },
    );

    test(
      'initial automatic execution creates only the latest due occurrence',
      () async {
        final didChange = await service.processAutomaticTransactions(
          recurringTransactions: [
            _expenseRecurring(
              id: 'rent',
              startDate: DateTime(2026, 1, 1, 9),
              intervalUnit: RecurringIntervalUnit.month,
              frequencyPreset: RecurringFrequencyPreset.monthly,
              executionMode: RecurringExecutionMode.automatic,
            ),
          ],
          currentAccounts: [_account()],
          now: DateTime(2026, 4, 9, 12),
          createTransactionId: _createTransactionId,
        );

        expect(didChange, isTrue);
        expect(transactionBalanceService.savedTransactions, hasLength(1));
        expect(
          transactionBalanceService.savedTransactions.single.transaction.date,
          DateTime(2026, 4, 1, 9),
        );
        expect(
          recurringTransactionRepository
              .updatedRecurringTransactions
              .single
              .lastProcessedOccurrenceDate,
          DateTime(2026, 4, 1, 9),
        );
      },
    );

    test(
      'creates multiple due occurrences after the last processed date',
      () async {
        final didChange = await service.processAutomaticTransactions(
          recurringTransactions: [
            _expenseRecurring(
              id: 'gym',
              startDate: DateTime(2026, 4, 5, 9),
              intervalUnit: RecurringIntervalUnit.day,
              frequencyPreset: RecurringFrequencyPreset.daily,
              executionMode: RecurringExecutionMode.automatic,
              lastProcessedOccurrenceDate: DateTime(2026, 4, 6, 18),
            ),
          ],
          currentAccounts: [_account()],
          now: DateTime(2026, 4, 9, 12),
          createTransactionId: _createTransactionId,
        );

        expect(didChange, isTrue);
        expect(
          transactionBalanceService.savedTransactions
              .map((call) => call.transaction.date)
              .toList(growable: false),
          [
            DateTime(2026, 4, 7, 9),
            DateTime(2026, 4, 8, 9),
            DateTime(2026, 4, 9, 9),
          ],
        );
        expect(
          recurringTransactionRepository
              .updatedRecurringTransactions
              .single
              .lastProcessedOccurrenceDate,
          DateTime(2026, 4, 9, 9),
        );
      },
    );

    test(
      'returns false when no automatic recurring transaction is due',
      () async {
        final didChange = await service.processAutomaticTransactions(
          recurringTransactions: [
            _expenseRecurring(
              id: 'future',
              startDate: DateTime(2026, 4, 12, 9),
              executionMode: RecurringExecutionMode.automatic,
            ),
          ],
          currentAccounts: [_account()],
          now: DateTime(2026, 4, 9, 12),
          createTransactionId: _createTransactionId,
        );

        expect(didChange, isFalse);
        expect(transactionBalanceService.savedTransactions, isEmpty);
        expect(
          recurringTransactionRepository.updatedRecurringTransactions,
          isEmpty,
        );
      },
    );

    test(
      'does not update the recurring transaction when transaction save fails',
      () async {
        transactionBalanceService.throwOnSaveIndex = 0;

        expect(
          () => service.processAutomaticTransactions(
            recurringTransactions: [
              _expenseRecurring(
                id: 'rent',
                startDate: DateTime(2026, 4, 9, 9),
                executionMode: RecurringExecutionMode.automatic,
              ),
            ],
            currentAccounts: [_account()],
            now: DateTime(2026, 4, 9, 12),
            createTransactionId: _createTransactionId,
          ),
          throwsA(isA<StateError>()),
        );
        expect(transactionBalanceService.savedTransactions, isEmpty);
        expect(
          recurringTransactionRepository.updatedRecurringTransactions,
          isEmpty,
        );
      },
    );

    test(
      'propagates recurring update failures after saving the generated transaction',
      () async {
        recurringTransactionRepository.throwOnUpdate = true;

        expect(
          () => service.processAutomaticTransactions(
            recurringTransactions: [
              _expenseRecurring(
                id: 'rent',
                startDate: DateTime(2026, 4, 9, 9),
                executionMode: RecurringExecutionMode.automatic,
              ),
            ],
            currentAccounts: [_account()],
            now: DateTime(2026, 4, 9, 12),
            createTransactionId: _createTransactionId,
          ),
          throwsA(isA<StateError>()),
        );
        expect(transactionBalanceService.savedTransactions, hasLength(1));
        expect(
          recurringTransactionRepository.updatedRecurringTransactions,
          isEmpty,
        );
      },
    );
  });

  group('confirmNextDueOccurrence', () {
    test('creates and confirms the next due occurrence', () async {
      final didConfirm = await service.confirmNextDueOccurrence(
        recurringTransaction: _expenseRecurring(
          id: 'manual-rent',
          startDate: DateTime(2026, 4, 5, 9),
          executionMode: RecurringExecutionMode.manual,
          intervalUnit: RecurringIntervalUnit.month,
          frequencyPreset: RecurringFrequencyPreset.monthly,
        ),
        currentAccounts: [_account()],
        now: DateTime(2026, 4, 9, 12),
        createTransactionId: _createTransactionId,
      );

      expect(didConfirm, isTrue);
      expect(transactionBalanceService.savedTransactions, hasLength(1));
      expect(
        transactionBalanceService.savedTransactions.single.transaction.date,
        DateTime(2026, 4, 5, 9),
      );
      expect(
        recurringTransactionRepository
            .updatedRecurringTransactions
            .single
            .lastProcessedOccurrenceDate,
        DateTime(2026, 4, 5, 9),
      );
    });

    test('returns false when the next occurrence is not yet due', () async {
      final didConfirm = await service.confirmNextDueOccurrence(
        recurringTransaction: _expenseRecurring(
          id: 'future-manual',
          startDate: DateTime(2026, 4, 12, 9),
          executionMode: RecurringExecutionMode.manual,
        ),
        currentAccounts: [_account()],
        now: DateTime(2026, 4, 9, 12),
        createTransactionId: _createTransactionId,
      );

      expect(didConfirm, isFalse);
      expect(transactionBalanceService.savedTransactions, isEmpty);
      expect(
        recurringTransactionRepository.updatedRecurringTransactions,
        isEmpty,
      );
    });
  });

  group('transfer guardrails', () {
    test(
      'marks generated transfers to credit cards as card payments',
      () async {
        final didChange = await service.processAutomaticTransactions(
          recurringTransactions: [
            _recurringTransfer(
              id: 'recurring-card-payment',
              destinationAccountId: 'account-card',
            ),
          ],
          currentAccounts: [_account(), _creditCardAccount()],
          now: DateTime(2026, 4, 9, 12),
          createTransactionId: _createTransactionId,
        );

        expect(didChange, isTrue);
        expect(transactionBalanceService.savedTransactions, hasLength(1));
        expect(
          transactionBalanceService
              .savedTransactions
              .single
              .transaction
              .transferKind,
          TransactionTransferKind.creditCardPayment,
        );
      },
    );
  });
}

class _FakeRecurringTransactionRepository
    implements RecurringTransactionRepository {
  final ValueNotifier<Box<dynamic>> _listenable = ValueNotifier(_FakeBox());
  final List<RecurringTransaction> updatedRecurringTransactions = [];
  bool throwOnUpdate = false;

  @override
  Future<void> addRecurringTransaction(
    RecurringTransaction recurringTransaction,
  ) async {}

  @override
  String createRecurringTransactionId() => 'generated-recurring-id';

  @override
  Future<void> deleteRecurringTransaction(
    String recurringTransactionId,
  ) async {}

  @override
  Future<List<RecurringTransaction>> getRecurringTransactions() async =>
      const [];

  @override
  ValueListenable<Box<dynamic>> listenable() => _listenable;

  @override
  Future<void> updateRecurringTransaction(
    RecurringTransaction recurringTransaction,
  ) async {
    if (throwOnUpdate) {
      throw StateError('Could not update recurring transaction.');
    }

    updatedRecurringTransactions.add(recurringTransaction);
  }
}

class _FakeTransactionBalanceService implements TransactionBalanceService {
  final List<_SaveTransactionCall> savedTransactions = [];
  int? throwOnSaveIndex;

  @override
  Future<void> deleteTransaction(
    String transactionId, {
    required TransactionItem? existingTransaction,
    required List<Account> currentAccounts,
  }) async {}

  @override
  Future<void> deleteTransactions(
    List<TransactionItem> transactions, {
    required List<Account> currentAccounts,
  }) async {}

  @override
  Future<void> saveTransaction(
    TransactionItem transaction, {
    required bool isEditing,
    TransactionItem? previousTransaction,
    required List<Account> currentAccounts,
    List<CategoryItem> currentCategories = const [],
  }) async {
    if (throwOnSaveIndex == savedTransactions.length) {
      throw StateError('Could not save generated transaction.');
    }

    savedTransactions.add(
      _SaveTransactionCall(
        transaction: transaction,
        isEditing: isEditing,
        currentAccounts: List<Account>.from(currentAccounts),
      ),
    );
  }
}

class _SaveTransactionCall {
  const _SaveTransactionCall({
    required this.transaction,
    required this.isEditing,
    required this.currentAccounts,
  });

  final TransactionItem transaction;
  final bool isEditing;
  final List<Account> currentAccounts;
}

class _FakeBox extends Fake implements Box<dynamic> {}

RecurringTransaction _expenseRecurring({
  required String id,
  required DateTime startDate,
  required RecurringExecutionMode executionMode,
  DateTime? lastProcessedOccurrenceDate,
  bool isPaused = false,
  int interval = 1,
  RecurringIntervalUnit intervalUnit = RecurringIntervalUnit.month,
  RecurringFrequencyPreset frequencyPreset = RecurringFrequencyPreset.monthly,
}) {
  return RecurringTransaction(
    id: id,
    title: 'Recurring $id',
    amount: 120,
    currencyCode: 'EUR',
    startDate: startDate,
    type: TransactionType.expense,
    executionMode: executionMode,
    frequencyPreset: frequencyPreset,
    intervalUnit: intervalUnit,
    interval: interval,
    categoryId: 'category-housing',
    accountId: 'account-wallet',
    lastProcessedOccurrenceDate: lastProcessedOccurrenceDate,
    isPaused: isPaused,
  );
}

RecurringTransaction _recurringTransfer({
  required String id,
  required String destinationAccountId,
}) {
  return RecurringTransaction(
    id: id,
    title: 'Pay card',
    amount: 120,
    currencyCode: 'EUR',
    startDate: DateTime(2026, 4, 9, 9),
    type: TransactionType.transfer,
    executionMode: RecurringExecutionMode.automatic,
    frequencyPreset: RecurringFrequencyPreset.monthly,
    intervalUnit: RecurringIntervalUnit.month,
    sourceAccountId: 'account-wallet',
    destinationAccountId: destinationAccountId,
  );
}

Account _account() {
  return const Account(
    id: 'account-wallet',
    name: 'Wallet',
    type: AccountType.cash,
    openingBalance: 100,
    currencyCode: 'EUR',
    isPrimary: true,
  );
}

Account _creditCardAccount() {
  return const Account(
    id: 'account-card',
    name: 'Card',
    type: AccountType.creditCard,
    openingBalance: 0,
    currencyCode: 'EUR',
  );
}

String _createTransactionId() {
  _generatedIdCounter += 1;
  return 'generated-$_generatedIdCounter';
}

int _generatedIdCounter = 0;
