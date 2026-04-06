import 'package:intl/intl.dart';

class FinancialPeriod {
  const FinancialPeriod({
    required this.start,
    required this.end,
    required this.financialCycleDay,
  });

  factory FinancialPeriod.containing({
    required DateTime date,
    required int financialCycleDay,
  }) {
    final normalizedDate = _normalizeDate(date);
    final normalizedCycleDay = normalizeFinancialCycleDay(financialCycleDay);
    final start = _startForContainingDate(normalizedDate, normalizedCycleDay);

    return FinancialPeriod(
      start: start,
      end: nextPeriodStart(start, normalizedCycleDay),
      financialCycleDay: normalizedCycleDay,
    );
  }

  final DateTime start;
  final DateTime end;
  final int financialCycleDay;

  DateTime get inclusiveEnd => end.subtract(const Duration(days: 1));

  bool contains(DateTime value) {
    final normalizedValue = _normalizeDate(value);
    return !normalizedValue.isBefore(start) && normalizedValue.isBefore(end);
  }

  String formatRangeLabel() {
    final endDate = inclusiveEnd;
    final sameYear = start.year == endDate.year;
    final sameMonth = sameYear && start.month == endDate.month;

    if (sameMonth) {
      return '${DateFormat('d').format(start)}-${DateFormat('d MMM yyyy').format(endDate)}';
    }

    if (sameYear) {
      return '${DateFormat('d MMM').format(start)} - ${DateFormat('d MMM yyyy').format(endDate)}';
    }

    return '${DateFormat('d MMM yyyy').format(start)} - ${DateFormat('d MMM yyyy').format(endDate)}';
  }

  static DateTime nextPeriodStart(
    DateTime currentStart,
    int financialCycleDay,
  ) {
    final normalizedStart = _normalizeDate(currentStart);
    final nextMonth = DateTime(normalizedStart.year, normalizedStart.month + 1);
    final nextDay = effectiveDayForMonth(
      nextMonth.year,
      nextMonth.month,
      financialCycleDay,
    );
    return DateTime(nextMonth.year, nextMonth.month, nextDay);
  }

  static DateTime _startForContainingDate(DateTime date, int cycleDay) {
    final currentMonthStartDay = effectiveDayForMonth(
      date.year,
      date.month,
      cycleDay,
    );
    if (date.day >= currentMonthStartDay) {
      return DateTime(date.year, date.month, currentMonthStartDay);
    }

    final previousMonth = DateTime(date.year, date.month - 1);
    final previousMonthStartDay = effectiveDayForMonth(
      previousMonth.year,
      previousMonth.month,
      cycleDay,
    );
    return DateTime(
      previousMonth.year,
      previousMonth.month,
      previousMonthStartDay,
    );
  }

  static DateTime _normalizeDate(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }
}

int normalizeFinancialCycleDay(int value) {
  return value.clamp(1, 31);
}

int effectiveDayForMonth(int year, int month, int preferredDay) {
  final lastDayOfMonth = DateTime(year, month + 1, 0).day;
  return normalizeFinancialCycleDay(preferredDay).clamp(1, lastDayOfMonth);
}
