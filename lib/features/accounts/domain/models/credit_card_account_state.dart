import 'package:expense_tracker/features/accounts/domain/models/account.dart';

enum CreditCardPaymentStatus { paid, upcoming, unpaid }

class CreditCardAccountState {
  const CreditCardAccountState({
    required this.accountId,
    required this.debt,
    required this.nextDueDate,
    required this.currentCycleStart,
    required this.currentCycleEnd,
    required this.status,
    required this.hasPaymentThisCycle,
    required this.paymentAmountThisCycle,
    required this.paymentTracking,
  });

  final String accountId;
  final double debt;
  final DateTime? nextDueDate;
  final DateTime? currentCycleStart;
  final DateTime? currentCycleEnd;
  final CreditCardPaymentStatus status;
  final bool hasPaymentThisCycle;
  final double paymentAmountThisCycle;
  final CreditCardPaymentTracking paymentTracking;

  bool get hasDebt => debt > 0.000001;
}
