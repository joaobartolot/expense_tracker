import 'package:expense_tracker/core/theme/app_colors.dart';
import 'package:expense_tracker/core/utils/currency_formatter.dart';
import 'package:expense_tracker/core/widgets/highlight_summary_card.dart';
import 'package:flutter/material.dart';

class AccountSummaryCard extends StatelessWidget {
  const AccountSummaryCard({
    super.key,
    required this.totalBalance,
    required this.accountCount,
    required this.currencyCode,
  });

  final double totalBalance;
  final int accountCount;
  final String currencyCode;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return HighlightSummaryCard(
      title: 'Tracked balance',
      value: formatCurrency(totalBalance, currencyCode: currencyCode),
      subtitle: '$accountCount account${accountCount == 1 ? '' : 's'} tracked',
      footer: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.info_outline_rounded,
              color: AppColors.white,
              size: 18,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'These are tracked balances, not live bank connections.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppColors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
