import 'package:expense_tracker/core/theme/app_colors.dart';
import 'package:expense_tracker/core/utils/currency_formatter.dart';
import 'package:expense_tracker/features/transactions/domain/models/transaction_item.dart';
import 'package:flutter/material.dart';

class TransactionTile extends StatelessWidget {
  const TransactionTile({
    super.key,
    required this.transaction,
    required this.displayAmount,
    required this.displayCurrencyCode,
    required this.categoryName,
    required this.categoryIcon,
    required this.accountName,
    this.subtitle,
    this.destinationAccountName,
    this.showSignedTransferAmount = false,
    this.onTap,
    this.onLongPressStart,
  });

  final TransactionItem transaction;
  final double displayAmount;
  final String displayCurrencyCode;
  final String categoryName;
  final IconData categoryIcon;
  final String accountName;
  final String? subtitle;
  final String? destinationAccountName;
  final bool showSignedTransferAmount;
  final VoidCallback? onTap;
  final GestureLongPressStartCallback? onLongPressStart;

  @override
  Widget build(BuildContext context) {
    final isIncome = transaction.type == TransactionType.income;
    final isTransfer = transaction.type == TransactionType.transfer;
    final isCreditCardPayment = transaction.isCreditCardPayment;
    final amountColor = isTransfer
        ? (showSignedTransferAmount && displayAmount < 0
              ? AppColors.textPrimary
              : AppColors.brandDark)
        : isIncome
        ? AppColors.income
        : AppColors.textPrimary;
    final amountPrefix = isTransfer
        ? (showSignedTransferAmount
              ? (displayAmount > 0 ? '+' : (displayAmount < 0 ? '-' : ''))
              : '')
        : (isIncome ? '+' : '-');
    final resolvedSubtitle =
        subtitle ??
        (isTransfer
            ? '$accountName -> ${destinationAccountName ?? 'Unknown account'}'
            : '$categoryName · $accountName');

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(22),
      child: GestureDetector(
        onLongPressStart: onLongPressStart,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(22),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: isTransfer
                        ? AppColors.background
                        : isIncome
                        ? AppColors.incomeSurface
                        : AppColors.expenseSurface,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    isCreditCardPayment
                        ? Icons.credit_card_rounded
                        : categoryIcon,
                    color: isTransfer
                        ? AppColors.brandDark
                        : isIncome
                        ? AppColors.income
                        : AppColors.iconMuted,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        transaction.title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        resolvedSubtitle,
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '$amountPrefix${formatCurrency(displayAmount.abs(), currencyCode: displayCurrencyCode)}',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: amountColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
