import 'package:expense_tracker/features/recurring_transactions/domain/models/recurring_transaction.dart';
import 'package:expense_tracker/features/recurring_transactions/domain/models/recurring_transaction_overview.dart';
import 'package:expense_tracker/features/recurring_transactions/domain/services/recurring_schedule_service.dart';
import 'package:expense_tracker/features/transactions/domain/models/transaction_item.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late RecurringScheduleService service;

  setUp(() {
    service = const RecurringScheduleService();
  });

  group('nextDueOccurrence', () {
    test('returns null when the recurring transaction is paused', () {
      final result = service.nextDueOccurrence(
        _expenseRecurring(isPaused: true),
        now: DateTime(2026, 4, 9, 12),
      );

      expect(result, isNull);
    });

    test('returns the first due occurrence when pending occurrences exist', () {
      final recurring = _expenseRecurring(
        startDate: DateTime(2026, 4, 5, 9),
        intervalUnit: RecurringIntervalUnit.day,
        frequencyPreset: RecurringFrequencyPreset.daily,
      );

      final result = service.nextDueOccurrence(
        recurring,
        now: DateTime(2026, 4, 9, 12),
      );

      expect(result, DateTime(2026, 4, 5, 9));
    });

    test(
      'returns the next future occurrence when nothing is currently due',
      () {
        final recurring = _expenseRecurring(
          startDate: DateTime(2026, 4, 12, 9),
          intervalUnit: RecurringIntervalUnit.day,
          frequencyPreset: RecurringFrequencyPreset.daily,
        );

        final result = service.nextDueOccurrence(
          recurring,
          now: DateTime(2026, 4, 9, 12),
        );

        expect(result, DateTime(2026, 4, 12, 9));
      },
    );

    test('respects lastProcessedOccurrenceDate and advances past it', () {
      final recurring = _expenseRecurring(
        startDate: DateTime(2026, 4, 5, 9),
        intervalUnit: RecurringIntervalUnit.day,
        frequencyPreset: RecurringFrequencyPreset.daily,
        lastProcessedOccurrenceDate: DateTime(2026, 4, 7, 18),
      );

      final result = service.nextDueOccurrence(
        recurring,
        now: DateTime(2026, 4, 9, 12),
      );

      expect(result, DateTime(2026, 4, 8, 9));
    });

    test(
      'returns the start date when it is due today and nothing was processed',
      () {
        final recurring = _expenseRecurring(
          startDate: DateTime(2026, 4, 9, 9),
          intervalUnit: RecurringIntervalUnit.day,
          frequencyPreset: RecurringFrequencyPreset.daily,
        );

        final result = service.nextDueOccurrence(
          recurring,
          now: DateTime(2026, 4, 9, 12),
        );

        expect(result, DateTime(2026, 4, 9, 9));
      },
    );
  });

  group('dueOccurrences', () {
    test('returns an empty list when paused', () {
      final result = service.dueOccurrences(
        _expenseRecurring(isPaused: true),
        now: DateTime(2026, 4, 9, 12),
      );

      expect(result, isEmpty);
    });

    test('returns all due occurrences from start date through now', () {
      final recurring = _expenseRecurring(
        startDate: DateTime(2026, 4, 5, 9),
        intervalUnit: RecurringIntervalUnit.day,
        frequencyPreset: RecurringFrequencyPreset.daily,
      );

      final result = service.dueOccurrences(
        recurring,
        now: DateTime(2026, 4, 9, 12),
      );

      expect(result, [
        DateTime(2026, 4, 5, 9),
        DateTime(2026, 4, 6, 9),
        DateTime(2026, 4, 7, 9),
        DateTime(2026, 4, 8, 9),
        DateTime(2026, 4, 9, 9),
      ]);
    });

    test('returns only occurrences after lastProcessedOccurrenceDate', () {
      final recurring = _expenseRecurring(
        startDate: DateTime(2026, 4, 5, 9),
        intervalUnit: RecurringIntervalUnit.day,
        frequencyPreset: RecurringFrequencyPreset.daily,
        lastProcessedOccurrenceDate: DateTime(2026, 4, 7, 23, 59),
      );

      final result = service.dueOccurrences(
        recurring,
        now: DateTime(2026, 4, 9, 12),
      );

      expect(result, [DateTime(2026, 4, 8, 9), DateTime(2026, 4, 9, 9)]);
    });

    test('honors the optional limit', () {
      final recurring = _expenseRecurring(
        startDate: DateTime(2026, 4, 5, 9),
        intervalUnit: RecurringIntervalUnit.day,
        frequencyPreset: RecurringFrequencyPreset.daily,
      );

      final result = service.dueOccurrences(
        recurring,
        now: DateTime(2026, 4, 9, 12),
        limit: 2,
      );

      expect(result, [DateTime(2026, 4, 5, 9), DateTime(2026, 4, 6, 9)]);
    });

    test(
      'returns an empty list when the next occurrence is still in the future',
      () {
        final recurring = _expenseRecurring(
          startDate: DateTime(2026, 4, 12, 9),
          intervalUnit: RecurringIntervalUnit.day,
          frequencyPreset: RecurringFrequencyPreset.daily,
        );

        final result = service.dueOccurrences(
          recurring,
          now: DateTime(2026, 4, 9, 12),
        );

        expect(result, isEmpty);
      },
    );

    test('treats the same calendar day as due regardless of time of day', () {
      final recurring = _expenseRecurring(
        startDate: DateTime(2026, 4, 9, 23, 30),
        intervalUnit: RecurringIntervalUnit.day,
        frequencyPreset: RecurringFrequencyPreset.daily,
      );

      final result = service.dueOccurrences(
        recurring,
        now: DateTime(2026, 4, 9, 8),
      );

      expect(result, [DateTime(2026, 4, 9, 23, 30)]);
    });

    test('supports custom every-N-days recurrence', () {
      final recurring = _expenseRecurring(
        startDate: DateTime(2026, 4, 1, 9),
        interval: 3,
        intervalUnit: RecurringIntervalUnit.day,
        frequencyPreset: RecurringFrequencyPreset.custom,
      );

      final result = service.dueOccurrences(
        recurring,
        now: DateTime(2026, 4, 10, 12),
      );

      expect(result, [
        DateTime(2026, 4, 1, 9),
        DateTime(2026, 4, 4, 9),
        DateTime(2026, 4, 7, 9),
        DateTime(2026, 4, 10, 9),
      ]);
    });

    test('supports custom every-N-weeks recurrence', () {
      final recurring = _expenseRecurring(
        startDate: DateTime(2026, 1, 1, 9),
        interval: 2,
        intervalUnit: RecurringIntervalUnit.week,
        frequencyPreset: RecurringFrequencyPreset.custom,
      );

      final result = service.dueOccurrences(
        recurring,
        now: DateTime(2026, 2, 12, 12),
      );

      expect(result, [
        DateTime(2026, 1, 1, 9),
        DateTime(2026, 1, 15, 9),
        DateTime(2026, 1, 29, 9),
        DateTime(2026, 2, 12, 9),
      ]);
    });

    test('preserves anchor-day semantics for monthly recurrence', () {
      final recurring = _expenseRecurring(
        startDate: DateTime(2026, 1, 31, 9),
        intervalUnit: RecurringIntervalUnit.month,
        frequencyPreset: RecurringFrequencyPreset.monthly,
      );

      final result = service.dueOccurrences(
        recurring,
        now: DateTime(2026, 5, 1, 12),
      );

      expect(result, [
        DateTime(2026, 1, 31, 9),
        DateTime(2026, 2, 28, 9),
        DateTime(2026, 3, 31, 9),
        DateTime(2026, 4, 30, 9),
      ]);
    });

    test('preserves anchor-day semantics for every-N-months recurrence', () {
      final recurring = _expenseRecurring(
        startDate: DateTime(2026, 1, 31, 9),
        interval: 2,
        intervalUnit: RecurringIntervalUnit.month,
        frequencyPreset: RecurringFrequencyPreset.custom,
      );

      final result = service.dueOccurrences(
        recurring,
        now: DateTime(2026, 8, 1, 12),
      );

      expect(result, [
        DateTime(2026, 1, 31, 9),
        DateTime(2026, 3, 31, 9),
        DateTime(2026, 5, 31, 9),
        DateTime(2026, 7, 31, 9),
      ]);
    });

    test('preserves anchor-month and day semantics for yearly recurrence', () {
      final recurring = _expenseRecurring(
        startDate: DateTime(2024, 2, 29, 9),
        intervalUnit: RecurringIntervalUnit.year,
        frequencyPreset: RecurringFrequencyPreset.yearly,
      );

      final result = service.dueOccurrences(
        recurring,
        now: DateTime(2028, 3, 1, 12),
      );

      expect(result, [
        DateTime(2024, 2, 29, 9),
        DateTime(2025, 2, 28, 9),
        DateTime(2026, 2, 28, 9),
        DateTime(2027, 2, 28, 9),
        DateTime(2028, 2, 29, 9),
      ]);
    });

    test(
      'preserves anchor-month and day semantics for every-N-years recurrence',
      () {
        final recurring = _expenseRecurring(
          startDate: DateTime(2024, 2, 29, 9),
          interval: 2,
          intervalUnit: RecurringIntervalUnit.year,
          frequencyPreset: RecurringFrequencyPreset.custom,
        );

        final result = service.dueOccurrences(
          recurring,
          now: DateTime(2032, 3, 1, 12),
        );

        expect(result, [
          DateTime(2024, 2, 29, 9),
          DateTime(2026, 2, 28, 9),
          DateTime(2028, 2, 29, 9),
          DateTime(2030, 2, 28, 9),
          DateTime(2032, 2, 29, 9),
        ]);
      },
    );
  });

  group('latestDueOccurrence', () {
    test('returns null when paused', () {
      final result = service.latestDueOccurrence(
        _expenseRecurring(isPaused: true),
        now: DateTime(2026, 4, 9, 12),
      );

      expect(result, isNull);
    });

    test('returns null when startDate is after now', () {
      final result = service.latestDueOccurrence(
        _expenseRecurring(
          startDate: DateTime(2026, 4, 10, 9),
          intervalUnit: RecurringIntervalUnit.day,
          frequencyPreset: RecurringFrequencyPreset.daily,
        ),
        now: DateTime(2026, 4, 9, 12),
      );

      expect(result, isNull);
    });

    test('returns the start date when now is on the start day', () {
      final result = service.latestDueOccurrence(
        _expenseRecurring(
          startDate: DateTime(2026, 4, 9, 23, 30),
          intervalUnit: RecurringIntervalUnit.day,
          frequencyPreset: RecurringFrequencyPreset.daily,
        ),
        now: DateTime(2026, 4, 9, 8),
      );

      expect(result, DateTime(2026, 4, 9, 23, 30));
    });

    test('returns the latest due daily occurrence on or before now', () {
      final result = service.latestDueOccurrence(
        _expenseRecurring(
          startDate: DateTime(2026, 4, 1, 9),
          intervalUnit: RecurringIntervalUnit.day,
          frequencyPreset: RecurringFrequencyPreset.daily,
        ),
        now: DateTime(2026, 4, 9, 12),
      );

      expect(result, DateTime(2026, 4, 9, 9));
    });

    test('returns the latest due weekly occurrence on or before now', () {
      final result = service.latestDueOccurrence(
        _expenseRecurring(
          startDate: DateTime(2026, 4, 1, 9),
          intervalUnit: RecurringIntervalUnit.week,
          frequencyPreset: RecurringFrequencyPreset.weekly,
        ),
        now: DateTime(2026, 4, 15, 12),
      );

      expect(result, DateTime(2026, 4, 15, 9));
    });

    test(
      'returns the latest due monthly occurrence with anchor-day fallback',
      () {
        final result = service.latestDueOccurrence(
          _expenseRecurring(
            startDate: DateTime(2026, 1, 31, 9),
            intervalUnit: RecurringIntervalUnit.month,
            frequencyPreset: RecurringFrequencyPreset.monthly,
          ),
          now: DateTime(2026, 4, 15, 12),
        );

        expect(result, DateTime(2026, 3, 31, 9));
      },
    );

    test(
      'returns the latest due yearly occurrence with leap-year fallback',
      () {
        final result = service.latestDueOccurrence(
          _expenseRecurring(
            startDate: DateTime(2024, 2, 29, 9),
            intervalUnit: RecurringIntervalUnit.year,
            frequencyPreset: RecurringFrequencyPreset.yearly,
          ),
          now: DateTime(2027, 7, 1, 12),
        );

        expect(result, DateTime(2027, 2, 28, 9));
      },
    );
  });

  group('buildOverview', () {
    test(
      'returns paused status with no next due date and no pending occurrences',
      () {
        final overview = service.buildOverview(
          _expenseRecurring(isPaused: true),
          now: DateTime(2026, 4, 9, 12),
        );

        expect(overview.status, RecurringTransactionStatus.paused);
        expect(overview.nextDueDate, isNull);
        expect(overview.pendingOccurrenceCount, 0);
        expect(overview.isDue, isFalse);
      },
    );

    test('returns overdue status when the next due date is before today', () {
      final overview = service.buildOverview(
        _expenseRecurring(
          startDate: DateTime(2026, 4, 5, 9),
          intervalUnit: RecurringIntervalUnit.month,
          frequencyPreset: RecurringFrequencyPreset.monthly,
        ),
        now: DateTime(2026, 4, 9, 12),
      );

      expect(overview.status, RecurringTransactionStatus.overdue);
      expect(overview.nextDueDate, DateTime(2026, 4, 5, 9));
      expect(overview.pendingOccurrenceCount, 1);
      expect(overview.isDue, isTrue);
    });

    test('returns dueToday status when the next due date is today', () {
      final overview = service.buildOverview(
        _expenseRecurring(
          startDate: DateTime(2026, 4, 9, 18),
          intervalUnit: RecurringIntervalUnit.month,
          frequencyPreset: RecurringFrequencyPreset.monthly,
        ),
        now: DateTime(2026, 4, 9, 8),
      );

      expect(overview.status, RecurringTransactionStatus.dueToday);
      expect(overview.nextDueDate, DateTime(2026, 4, 9, 18));
      expect(overview.pendingOccurrenceCount, 1);
      expect(overview.isDue, isTrue);
    });

    test(
      'returns dueSoon status when the next due date is within three days',
      () {
        final overview = service.buildOverview(
          _expenseRecurring(
            startDate: DateTime(2026, 4, 12, 9),
            intervalUnit: RecurringIntervalUnit.month,
            frequencyPreset: RecurringFrequencyPreset.monthly,
          ),
          now: DateTime(2026, 4, 9, 12),
        );

        expect(overview.status, RecurringTransactionStatus.dueSoon);
        expect(overview.nextDueDate, DateTime(2026, 4, 12, 9));
        expect(overview.pendingOccurrenceCount, 0);
        expect(overview.isDue, isFalse);
      },
    );

    test(
      'returns upcoming status when the next due date is more than three days away',
      () {
        final overview = service.buildOverview(
          _expenseRecurring(
            startDate: DateTime(2026, 4, 15, 9),
            intervalUnit: RecurringIntervalUnit.month,
            frequencyPreset: RecurringFrequencyPreset.monthly,
          ),
          now: DateTime(2026, 4, 9, 12),
        );

        expect(overview.status, RecurringTransactionStatus.upcoming);
        expect(overview.nextDueDate, DateTime(2026, 4, 15, 9));
        expect(overview.pendingOccurrenceCount, 0);
        expect(overview.isDue, isFalse);
      },
    );

    test('pending occurrence count matches due occurrences count', () {
      final recurring = _expenseRecurring(
        startDate: DateTime(2026, 4, 5, 9),
        intervalUnit: RecurringIntervalUnit.day,
        frequencyPreset: RecurringFrequencyPreset.daily,
        lastProcessedOccurrenceDate: DateTime(2026, 4, 6, 12),
      );

      final overview = service.buildOverview(
        recurring,
        now: DateTime(2026, 4, 9, 12),
      );

      expect(overview.pendingOccurrenceCount, 3);
      expect(overview.nextDueDate, DateTime(2026, 4, 7, 9));
      expect(overview.isDue, isTrue);
    });
  });
}

RecurringTransaction _expenseRecurring({
  DateTime? startDate,
  DateTime? lastProcessedOccurrenceDate,
  bool isPaused = false,
  int interval = 1,
  RecurringIntervalUnit intervalUnit = RecurringIntervalUnit.month,
  RecurringFrequencyPreset frequencyPreset = RecurringFrequencyPreset.monthly,
}) {
  return RecurringTransaction(
    id: 'recurring-rent',
    title: 'Rent',
    amount: 1200,
    currencyCode: 'EUR',
    startDate: startDate ?? DateTime(2026, 4, 1, 9),
    type: TransactionType.expense,
    executionMode: RecurringExecutionMode.manual,
    frequencyPreset: frequencyPreset,
    intervalUnit: intervalUnit,
    interval: interval,
    categoryId: 'category-housing',
    accountId: 'account-wallet',
    lastProcessedOccurrenceDate: lastProcessedOccurrenceDate,
    isPaused: isPaused,
  );
}
