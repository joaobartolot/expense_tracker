import 'dart:math' as math;

import 'package:expense_tracker/features/recurring_transactions/domain/models/recurring_transaction.dart';
import 'package:expense_tracker/features/recurring_transactions/domain/models/recurring_transaction_overview.dart';

class RecurringScheduleService {
  const RecurringScheduleService();

  static const int _maxGeneratedOccurrences = 400;
  static const int _maxOccurrenceSearchIterations = 20000;

  DateTime? nextDueOccurrence(
    RecurringTransaction recurringTransaction, {
    required DateTime now,
  }) {
    if (recurringTransaction.isPaused) {
      return null;
    }

    final occurrences = dueOccurrences(
      recurringTransaction,
      now: now,
      limit: 1,
    );
    if (occurrences.isNotEmpty) {
      return occurrences.first;
    }

    return _firstOccurrenceAfter(
      recurringTransaction,
      after: recurringTransaction.lastProcessedOccurrenceDate,
    );
  }

  List<DateTime> dueOccurrences(
    RecurringTransaction recurringTransaction, {
    required DateTime now,
    int? limit,
  }) {
    if (recurringTransaction.isPaused) {
      return const [];
    }

    final dueOccurrences = <DateTime>[];
    final nowDate = _startOfDay(now);
    var occurrence = _firstOccurrenceAfter(
      recurringTransaction,
      after: recurringTransaction.lastProcessedOccurrenceDate,
    );

    while (occurrence != null &&
        !_startOfDay(occurrence).isAfter(nowDate) &&
        dueOccurrences.length < (limit ?? _maxGeneratedOccurrences)) {
      dueOccurrences.add(occurrence);
      occurrence = _advanceOccurrence(recurringTransaction, occurrence);
    }

    return dueOccurrences;
  }

  DateTime? latestDueOccurrence(
    RecurringTransaction recurringTransaction, {
    required DateTime now,
  }) {
    if (recurringTransaction.isPaused) {
      return null;
    }

    final nowDate = _startOfDay(now);
    var occurrence = recurringTransaction.startDate;
    DateTime? latestDueOccurrence;
    var guard = 0;

    while (!_startOfDay(occurrence).isAfter(nowDate) &&
        guard < _maxOccurrenceSearchIterations) {
      latestDueOccurrence = occurrence;
      occurrence = _advanceOccurrence(recurringTransaction, occurrence);
      guard += 1;
    }

    return latestDueOccurrence;
  }

  RecurringTransactionOverview buildOverview(
    RecurringTransaction recurringTransaction, {
    required DateTime now,
  }) {
    final pendingOccurrenceCount = dueOccurrences(
      recurringTransaction,
      now: now,
    ).length;
    final nextDueDate = nextDueOccurrence(recurringTransaction, now: now);
    final status = _resolveStatus(
      recurringTransaction,
      nextDueDate: nextDueDate,
      now: now,
    );

    return RecurringTransactionOverview(
      recurringTransaction: recurringTransaction,
      nextDueDate: nextDueDate,
      pendingOccurrenceCount: pendingOccurrenceCount,
      status: status,
    );
  }

  DateTime? _firstOccurrenceAfter(
    RecurringTransaction recurringTransaction, {
    required DateTime? after,
  }) {
    final threshold = after == null ? null : _startOfDay(after);
    var occurrence = recurringTransaction.startDate;
    var guard = 0;

    while (threshold != null &&
        !_startOfDay(occurrence).isAfter(threshold) &&
        guard < _maxGeneratedOccurrences) {
      occurrence = _advanceOccurrence(recurringTransaction, occurrence);
      guard += 1;
    }

    return guard >= _maxGeneratedOccurrences ? null : occurrence;
  }

  RecurringTransactionStatus _resolveStatus(
    RecurringTransaction recurringTransaction, {
    required DateTime? nextDueDate,
    required DateTime now,
  }) {
    if (recurringTransaction.isPaused) {
      return RecurringTransactionStatus.paused;
    }

    if (nextDueDate == null) {
      return RecurringTransactionStatus.upcoming;
    }

    final today = _startOfDay(now);
    final dueDate = _startOfDay(nextDueDate);
    final dayDelta = dueDate.difference(today).inDays;

    if (dayDelta < 0) {
      return RecurringTransactionStatus.overdue;
    }

    if (dayDelta == 0) {
      return RecurringTransactionStatus.dueToday;
    }

    if (dayDelta <= 3) {
      return RecurringTransactionStatus.dueSoon;
    }

    return RecurringTransactionStatus.upcoming;
  }

  DateTime _advanceOccurrence(
    RecurringTransaction recurringTransaction,
    DateTime current,
  ) {
    switch (recurringTransaction.intervalUnit) {
      case RecurringIntervalUnit.day:
        return current.add(Duration(days: recurringTransaction.interval));
      case RecurringIntervalUnit.week:
        return current.add(Duration(days: 7 * recurringTransaction.interval));
      case RecurringIntervalUnit.month:
        return _addMonths(
          current,
          recurringTransaction.interval,
          anchorDay: recurringTransaction.startDate.day,
        );
      case RecurringIntervalUnit.year:
        return _addYears(
          current,
          recurringTransaction.interval,
          anchorMonth: recurringTransaction.startDate.month,
          anchorDay: recurringTransaction.startDate.day,
        );
    }
  }

  DateTime _addMonths(DateTime current, int months, {required int anchorDay}) {
    final absoluteMonth = current.year * 12 + (current.month - 1) + months;
    final year = absoluteMonth ~/ 12;
    final month = absoluteMonth % 12 + 1;
    final day = math.min(anchorDay, _lastDayOfMonth(year, month));

    return DateTime(
      year,
      month,
      day,
      current.hour,
      current.minute,
      current.second,
      current.millisecond,
      current.microsecond,
    );
  }

  DateTime _addYears(
    DateTime current,
    int years, {
    required int anchorMonth,
    required int anchorDay,
  }) {
    final year = current.year + years;
    final day = math.min(anchorDay, _lastDayOfMonth(year, anchorMonth));

    return DateTime(
      year,
      anchorMonth,
      day,
      current.hour,
      current.minute,
      current.second,
      current.millisecond,
      current.microsecond,
    );
  }

  int _lastDayOfMonth(int year, int month) {
    return DateTime(year, month + 1, 0).day;
  }

  DateTime _startOfDay(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }
}
