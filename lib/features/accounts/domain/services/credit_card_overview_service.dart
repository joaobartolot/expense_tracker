import 'package:expense_tracker/features/accounts/domain/models/account.dart';
import 'package:expense_tracker/features/accounts/domain/models/credit_card_account_state.dart';
import 'package:expense_tracker/features/transactions/domain/models/transaction_item.dart';

class CreditCardOverviewService {
  const CreditCardOverviewService();

  Map<String, CreditCardAccountState> buildStates({
    required List<Account> accounts,
    required Map<String, double> effectiveBalances,
    required List<TransactionItem> transactions,
    required DateTime now,
  }) {
    final states = <String, CreditCardAccountState>{};

    for (final account in accounts) {
      if (!account.isCreditCard) {
        continue;
      }

      final dueDay = _sanitizeDueDay(account.creditCardDueDay);
      final currentBalance =
          effectiveBalances[account.id] ?? account.openingBalance;
      final debt = currentBalance >= 0 ? 0.0 : -currentBalance;
      final paymentTracking =
          account.paymentTracking ?? CreditCardPaymentTracking.manual;
      final currentDueDate = dueDay == null
          ? null
          : _dueDateForMonth(now, dueDay);
      final isPastCurrentDueDate = _dateOnly(
        now,
      ).isAfter(currentDueDate ?? _dateOnly(now));
      final nextDueDate = dueDay == null
          ? null
          : (isPastCurrentDueDate
                ? _dueDateForMonth(DateTime(now.year, now.month + 1), dueDay)
                : currentDueDate);
      final previousDueDate = dueDay == null
          ? null
          : (isPastCurrentDueDate
                ? currentDueDate
                : _dueDateForMonth(DateTime(now.year, now.month - 1), dueDay));
      final cycleStart = previousDueDate?.add(const Duration(days: 1));
      final cycleEnd = nextDueDate;
      final paymentAmountThisCycle = _paymentAmountThisCycle(
        accountId: account.id,
        transactions: transactions,
        cycleStart: cycleStart,
        cycleEnd: cycleEnd,
      );
      final hasPaymentThisCycle = paymentAmountThisCycle > 0.000001;

      states[account.id] = CreditCardAccountState(
        accountId: account.id,
        debt: debt,
        nextDueDate: nextDueDate,
        currentCycleStart: cycleStart,
        currentCycleEnd: cycleEnd,
        status: _resolveStatus(
          debt: debt,
          paymentTracking: paymentTracking,
          hasPaymentThisCycle: hasPaymentThisCycle,
          isPastCurrentDueDate: isPastCurrentDueDate,
        ),
        hasPaymentThisCycle: hasPaymentThisCycle,
        paymentAmountThisCycle: paymentAmountThisCycle,
        paymentTracking: paymentTracking,
      );
    }

    return states;
  }

  CreditCardPaymentStatus _resolveStatus({
    required double debt,
    required CreditCardPaymentTracking paymentTracking,
    required bool hasPaymentThisCycle,
    required bool isPastCurrentDueDate,
  }) {
    if (debt <= 0.000001) {
      return CreditCardPaymentStatus.paid;
    }

    if (paymentTracking == CreditCardPaymentTracking.manual &&
        hasPaymentThisCycle) {
      return CreditCardPaymentStatus.paid;
    }

    return isPastCurrentDueDate
        ? CreditCardPaymentStatus.unpaid
        : CreditCardPaymentStatus.upcoming;
  }

  double _paymentAmountThisCycle({
    required String accountId,
    required List<TransactionItem> transactions,
    required DateTime? cycleStart,
    required DateTime? cycleEnd,
  }) {
    return transactions
        .where((transaction) => transaction.isCreditCardPayment)
        .where((transaction) => transaction.destinationAccountId == accountId)
        .where((transaction) {
          if (cycleStart != null && transaction.date.isBefore(cycleStart)) {
            return false;
          }
          if (cycleEnd != null && transaction.date.isAfter(cycleEnd)) {
            return false;
          }
          return true;
        })
        .fold<double>(
          0,
          (sum, transaction) =>
              sum + (transaction.destinationAmount ?? transaction.amount),
        );
  }

  int? _sanitizeDueDay(int? dueDay) {
    if (dueDay == null) {
      return null;
    }

    return dueDay.clamp(1, 31);
  }

  DateTime _dueDateForMonth(DateTime anchor, int dueDay) {
    final year = anchor.year;
    final month = anchor.month;
    final lastDayOfMonth = DateTime(year, month + 1, 0).day;
    return DateTime(
      year,
      month,
      dueDay > lastDayOfMonth ? lastDayOfMonth : dueDay,
    );
  }

  DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);
}
