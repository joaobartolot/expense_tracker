// widget that takes a transaction amount and type (income or expense) and displays it with appropriate styling
import 'package:expense_tracker/features/transactions/domain/enums/transaction_type.dart';
import 'package:expense_tracker/shared/utils/currency_utils.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class TransactionAmount extends StatelessWidget {
  const TransactionAmount({
    super.key,
    required this.amountCents,
    required this.type,
    required this.style,
  });

  final int amountCents;
  final TransactionType type;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final amount = centsToEuros(amountCents);
    final formattedAmount = NumberFormat.currency(
      symbol: '€',
      decimalDigits: 2,
    ).format(amount);

    final text = amountCents == 0
        ? formattedAmount
        : (type == TransactionType.expense ? '- ' : '+ ') + formattedAmount;

    final color = type == TransactionType.income ? Colors.green : Colors.red;

    return Text(text, style: style.copyWith(color: color));
  }
}
