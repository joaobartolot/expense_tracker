import 'package:expense_tracker/core/theme/app_colors.dart';
import 'package:expense_tracker/core/utils/currency_formatter.dart';
import 'package:expense_tracker/features/recurring_transactions/domain/models/recurring_transaction_overview.dart';
import 'package:flutter/material.dart';

class RecurringTransactionCard extends StatelessWidget {
  const RecurringTransactionCard({
    super.key,
    required this.overview,
    required this.onTap,
    required this.onLongPressStart,
    required this.onConfirm,
  });

  final RecurringTransactionOverview overview;
  final VoidCallback onTap;
  final GestureLongPressStartCallback onLongPressStart;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = AppColors.of(context);
    final recurringTransaction = overview.recurringTransaction;
    final nextDueLabel = switch (overview.nextDueDate) {
      final DateTime date => _formatDate(date),
      null => 'Paused',
    };

    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(28),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(28),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onLongPressStart: onLongPressStart,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      recurringTransaction.title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _amountLabel(
                        recurringTransaction.amount,
                        recurringTransaction.currencyCode,
                      ),
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: colors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _MetaChip(
                      icon: Icons.repeat_rounded,
                      label: recurringTransaction.frequencyLabel,
                      backgroundColor: colors.background,
                      foregroundColor: colors.textPrimary,
                    ),
                    _MetaChip(
                      icon: recurringTransaction.isAutomatic
                          ? Icons.bolt_rounded
                          : Icons.pending_actions_rounded,
                      label: recurringTransaction.executionModeLabel,
                      backgroundColor: colors.background,
                      foregroundColor: colors.textPrimary,
                    ),
                    _MetaChip(
                      icon: _statusIcon(overview.status),
                      label: _statusLabel(overview),
                      backgroundColor: _statusBackgroundColor(overview.status),
                      foregroundColor: _statusForegroundColor(overview.status),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Icon(
                      Icons.calendar_today_outlined,
                      size: 18,
                      color: colors.textSecondary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Next due: $nextDueLabel',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
                if (overview.pendingOccurrenceCount > 1) ...[
                  const SizedBox(height: 10),
                  Text(
                    '${overview.pendingOccurrenceCount} occurrences are waiting.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                ],
                if (recurringTransaction.isManual && overview.isDue) ...[
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: onConfirm,
                      icon: const Icon(Icons.check_circle_outline),
                      label: const Text('Create next transaction'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _amountLabel(double amount, String currencyCode) {
    return formatCurrency(amount, currencyCode: currencyCode);
  }

  String _statusLabel(RecurringTransactionOverview overview) {
    switch (overview.status) {
      case RecurringTransactionStatus.paused:
        return 'Paused';
      case RecurringTransactionStatus.overdue:
        return overview.recurringTransaction.isManual
            ? 'Overdue'
            : 'Auto overdue';
      case RecurringTransactionStatus.dueToday:
        return 'Due today';
      case RecurringTransactionStatus.dueSoon:
        return 'Due soon';
      case RecurringTransactionStatus.upcoming:
        return 'Upcoming';
    }
  }

  IconData _statusIcon(RecurringTransactionStatus status) {
    return switch (status) {
      RecurringTransactionStatus.paused => Icons.pause_circle_outline,
      RecurringTransactionStatus.overdue => Icons.error_outline,
      RecurringTransactionStatus.dueToday => Icons.event_available_outlined,
      RecurringTransactionStatus.dueSoon => Icons.schedule_outlined,
      RecurringTransactionStatus.upcoming => Icons.event_outlined,
    };
  }

  Color _statusBackgroundColor(RecurringTransactionStatus status) {
    return switch (status) {
      RecurringTransactionStatus.paused => AppColors.background,
      RecurringTransactionStatus.overdue => AppColors.expenseSurface,
      RecurringTransactionStatus.dueToday => AppColors.brand.withValues(
        alpha: 0.12,
      ),
      RecurringTransactionStatus.dueSoon => AppColors.brand.withValues(
        alpha: 0.08,
      ),
      RecurringTransactionStatus.upcoming => AppColors.background,
    };
  }

  Color _statusForegroundColor(RecurringTransactionStatus status) {
    return switch (status) {
      RecurringTransactionStatus.paused => AppColors.textSecondary,
      RecurringTransactionStatus.overdue => AppColors.dangerDark,
      RecurringTransactionStatus.dueToday => AppColors.brand,
      RecurringTransactionStatus.dueSoon => AppColors.brand,
      RecurringTransactionStatus.upcoming => AppColors.textSecondary,
    };
  }

  String _formatDate(DateTime date) {
    final month = switch (date.month) {
      1 => 'Jan',
      2 => 'Feb',
      3 => 'Mar',
      4 => 'Apr',
      5 => 'May',
      6 => 'Jun',
      7 => 'Jul',
      8 => 'Aug',
      9 => 'Sep',
      10 => 'Oct',
      11 => 'Nov',
      _ => 'Dec',
    };
    return '$month ${date.day}, ${date.year}';
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({
    required this.icon,
    required this.label,
    required this.backgroundColor,
    required this.foregroundColor,
  });

  final IconData icon;
  final String label;
  final Color backgroundColor;
  final Color foregroundColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: foregroundColor),
          const SizedBox(width: 6),
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: foregroundColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
