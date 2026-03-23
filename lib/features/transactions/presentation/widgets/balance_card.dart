import 'package:expense_tracker/core/utils/currency_formatter.dart';
import 'package:expense_tracker/core/widgets/highlight_summary_card.dart';
import 'package:flutter/material.dart';

class BalanceCard extends StatelessWidget {
  const BalanceCard({
    super.key,
    required this.balance,
    required this.currencyCode,
  });

  final double balance;
  final String currencyCode;

  @override
  Widget build(BuildContext context) {
    return HighlightSummaryCard(
      title: 'Current balance',
      value: formatCurrency(balance, currencyCode: currencyCode),
    );
  }
}
