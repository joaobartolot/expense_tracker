import 'dart:io';

import 'package:expense_tracker/core/storage/hive_storage.dart';
import 'package:expense_tracker/features/recurring_transactions/data/hive_recurring_transaction_repository.dart';
import 'package:expense_tracker/features/recurring_transactions/domain/models/recurring_transaction.dart';
import 'package:expense_tracker/features/transactions/domain/models/transaction_item.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDirectory;
  late Box<dynamic> recurringTransactionsBox;
  late HiveRecurringTransactionRepository repository;

  setUp(() async {
    tempDirectory = await Directory.systemTemp.createTemp(
      'vero-hive-recurring-transaction-repository-test-',
    );
    Hive.init(tempDirectory.path);
    recurringTransactionsBox = await Hive.openBox<dynamic>(
      HiveStorage.recurringTransactionsBoxName,
    );
    await recurringTransactionsBox.put(
      HiveStorage.recurringTransactionsKey,
      const [],
    );
    repository = HiveRecurringTransactionRepository();
  });

  tearDown(() async {
    await Hive.close();
    if (await tempDirectory.exists()) {
      await tempDirectory.delete(recursive: true);
    }
  });

  test('addRecurringTransaction persists a valid recurring expense', () async {
    final recurring = _recurringExpense(id: 'recurring-rent');

    await repository.addRecurringTransaction(recurring);

    final recurringTransactions = await repository.getRecurringTransactions();
    expect(recurringTransactions, hasLength(1));
    expect(recurringTransactions.single.id, recurring.id);
    expect(recurringTransactions.single.title, recurring.title);
    expect(recurringTransactions.single.amount, recurring.amount);
  });

  test(
    'updateRecurringTransaction replaces an existing recurring entry',
    () async {
      await _storeRecurringTransactions(recurringTransactionsBox, [
        _recurringExpense(id: 'recurring-rent'),
      ]);

      await repository.updateRecurringTransaction(
        _recurringExpense(id: 'recurring-rent', title: 'Updated rent'),
      );

      final recurringTransactions = await repository.getRecurringTransactions();
      expect(recurringTransactions.single.title, 'Updated rent');
    },
  );

  test('updateRecurringTransaction ignores missing entries', () async {
    await _storeRecurringTransactions(recurringTransactionsBox, [
      _recurringExpense(id: 'recurring-rent'),
    ]);

    await repository.updateRecurringTransaction(
      _recurringExpense(id: 'missing'),
    );

    final recurringTransactions = await repository.getRecurringTransactions();
    expect(recurringTransactions.map((item) => item.id), ['recurring-rent']);
  });

  test('deleteRecurringTransaction removes the matching entry', () async {
    await _storeRecurringTransactions(recurringTransactionsBox, [
      _recurringExpense(id: 'recurring-rent'),
      _recurringExpense(id: 'recurring-gym'),
    ]);

    await repository.deleteRecurringTransaction('recurring-rent');

    final recurringTransactions = await repository.getRecurringTransactions();
    expect(recurringTransactions.map((item) => item.id), ['recurring-gym']);
  });

  test('createRecurringTransactionId returns a UUID', () {
    expect(repository.createRecurringTransactionId(), matches(_uuidPattern));
  });

  test('addRecurringTransaction rejects blank titles', () async {
    await expectLater(
      repository.addRecurringTransaction(
        _recurringExpense(id: 'recurring-rent', title: '   '),
      ),
      throwsA(isA<RecurringTransactionValidationException>()),
    );
    expect(await repository.getRecurringTransactions(), isEmpty);
  });

  test('addRecurringTransaction rejects same-account transfers', () async {
    await expectLater(
      repository.addRecurringTransaction(
        RecurringTransaction(
          id: 'recurring-transfer',
          title: 'Move money',
          amount: 100,
          currencyCode: 'EUR',
          startDate: DateTime(2026, 4, 1, 9),
          type: TransactionType.transfer,
          executionMode: RecurringExecutionMode.manual,
          frequencyPreset: RecurringFrequencyPreset.monthly,
          intervalUnit: RecurringIntervalUnit.month,
          sourceAccountId: 'account-wallet',
          destinationAccountId: 'account-wallet',
        ),
      ),
      throwsA(isA<RecurringTransactionValidationException>()),
    );
    expect(await repository.getRecurringTransactions(), isEmpty);
  });

  test('getRecurringTransactions skips malformed stored entries', () async {
    await recurringTransactionsBox.put(HiveStorage.recurringTransactionsKey, [
      _recurringExpense(id: 'recurring-rent').toMap(),
      {
        'id': 'broken-recurring',
        'title': 123,
        'amount': 500,
        'currencyCode': 'EUR',
        'startDate': DateTime(2026, 4, 1, 9).toIso8601String(),
        'type': 'expense',
        'executionMode': 'manual',
        'frequencyPreset': 'monthly',
        'intervalUnit': 'month',
        'interval': 1,
        'categoryId': 'category-housing',
        'accountId': 'account-wallet',
      },
    ]);

    final recurringTransactions = await repository.getRecurringTransactions();

    expect(recurringTransactions.map((item) => item.id), ['recurring-rent']);
  });
}

Future<void> _storeRecurringTransactions(
  Box<dynamic> box,
  List<RecurringTransaction> recurringTransactions,
) {
  return box.put(
    HiveStorage.recurringTransactionsKey,
    recurringTransactions.map((item) => item.toMap()).toList(growable: false),
  );
}

RecurringTransaction _recurringExpense({
  required String id,
  String title = 'Rent',
}) {
  return RecurringTransaction(
    id: id,
    title: title,
    amount: 500,
    currencyCode: 'EUR',
    startDate: DateTime(2026, 4, 1, 9),
    type: TransactionType.expense,
    executionMode: RecurringExecutionMode.manual,
    frequencyPreset: RecurringFrequencyPreset.monthly,
    intervalUnit: RecurringIntervalUnit.month,
    categoryId: 'category-housing',
    accountId: 'account-wallet',
  );
}

final _uuidPattern = RegExp(
  r'^[0-9a-fA-F]{8}-'
  r'[0-9a-fA-F]{4}-'
  r'[0-9a-fA-F]{4}-'
  r'[0-9a-fA-F]{4}-'
  r'[0-9a-fA-F]{12}$',
);
