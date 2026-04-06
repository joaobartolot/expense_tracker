import 'package:expense_tracker/core/theme/app_colors.dart';
import 'package:expense_tracker/core/utils/currency_formatter.dart';
import 'package:expense_tracker/features/accounts/domain/models/account.dart';
import 'package:expense_tracker/features/accounts/domain/models/credit_card_account_state.dart';
import 'package:flutter/material.dart';

enum AccountTileAction { edit, delete }

class AccountTile extends StatelessWidget {
  const AccountTile({
    super.key,
    required this.account,
    required this.balance,
    this.creditCardState,
    this.onCreditCardPaymentTap,
    this.onTap,
    this.onLongPressStart,
    this.leading,
    this.trailing,
  });

  final Account account;
  final double balance;
  final CreditCardAccountState? creditCardState;
  final VoidCallback? onCreditCardPaymentTap;
  final VoidCallback? onTap;
  final GestureLongPressStartCallback? onLongPressStart;
  final Widget? leading;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = AppColors.of(context);
    final displayAmount = account.isCreditCard
        ? creditCardState?.debt ?? 0
        : balance;
    final isNegative = !account.isCreditCard && balance < 0;

    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(28),
      child: GestureDetector(
        onLongPressStart: onLongPressStart,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(28),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (leading != null) ...[leading!, const SizedBox(width: 12)],
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: colors.background,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(account.icon, color: colors.iconMuted),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        account.name,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: colors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        account.typeLabel,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                      if (account.description.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          account.description,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colors.textSecondary,
                          ),
                        ),
                      ],
                      if (account.isCreditCard) ...[
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            if (creditCardState case final cardState?)
                              _StatusChip(status: cardState.status),
                            if (creditCardState?.nextDueDate
                                case final nextDue?)
                              _MetaChip(
                                label:
                                    'Due ${MaterialLocalizations.of(context).formatShortDate(nextDue)}',
                              ),
                            if (creditCardState?.paymentTracking
                                case final tracking)
                              _MetaChip(
                                label:
                                    tracking == CreditCardPaymentTracking.manual
                                    ? 'Manual tracking'
                                    : 'Auto tracking',
                              ),
                          ],
                        ),
                      ] else if (account.isPrimary) ...[
                        const SizedBox(height: 10),
                        const _MetaChip(label: 'Main account'),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      formatCurrency(
                        displayAmount,
                        currencyCode: account.currencyCode,
                      ),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: isNegative
                            ? AppColors.dangerDark
                            : colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      account.isCreditCard
                          ? 'Current debt'
                          : account.currencyCode,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                    if (account.isCreditCard &&
                        onCreditCardPaymentTap != null) ...[
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        onPressed: onCreditCardPaymentTap,
                        icon: const Icon(Icons.credit_card_rounded, size: 18),
                        label: const Text('Pay'),
                      ),
                    ],
                  ],
                ),
                if (trailing != null) ...[const SizedBox(width: 10), trailing!],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = AppColors.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: colors.border),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelMedium?.copyWith(
          color: colors.textSecondary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final CreditCardPaymentStatus status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = switch (status) {
      CreditCardPaymentStatus.paid => (
        background: const Color(0xFFE8F6EE),
        foreground: const Color(0xFF1C7C45),
      ),
      CreditCardPaymentStatus.upcoming => (
        background: const Color(0xFFFDF2E2),
        foreground: const Color(0xFF9A5B00),
      ),
      CreditCardPaymentStatus.unpaid => (
        background: const Color(0xFFFCE8E6),
        foreground: const Color(0xFFB3261E),
      ),
    };

    final label = switch (status) {
      CreditCardPaymentStatus.paid => 'Paid',
      CreditCardPaymentStatus.upcoming => 'Upcoming',
      CreditCardPaymentStatus.unpaid => 'Unpaid',
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: scheme.background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelMedium?.copyWith(
          color: scheme.foreground,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
