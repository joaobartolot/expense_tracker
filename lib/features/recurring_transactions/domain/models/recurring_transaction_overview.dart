import 'package:expense_tracker/features/recurring_transactions/domain/models/recurring_transaction.dart';

enum RecurringTransactionStatus { paused, overdue, dueToday, dueSoon, upcoming }

class RecurringTransactionOverview {
  const RecurringTransactionOverview({
    required this.recurringTransaction,
    required this.nextDueDate,
    required this.pendingOccurrenceCount,
    required this.status,
  });

  final RecurringTransaction recurringTransaction;
  final DateTime? nextDueDate;
  final int pendingOccurrenceCount;
  final RecurringTransactionStatus status;

  bool get isDue => pendingOccurrenceCount > 0;
}
