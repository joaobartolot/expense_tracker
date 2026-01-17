import 'package:expense_tracker/shared/utils/currency_utils.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AccountCard extends StatelessWidget {
  const AccountCard({
    super.key,
    required this.balanceCents,
    required this.onAdd,
    required this.onTransfer,
  });

  final int balanceCents;
  final VoidCallback onAdd;
  final VoidCallback onTransfer;

  String _formatMoney(int cents) {
    final euros = centsToEuros(cents);
    return NumberFormat.currency(symbol: '€ ', decimalDigits: 2).format(euros);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    final isNegative = balanceCents < 0;

    return Card(
      elevation: 0,
      color: cs.primaryContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Main Account',
                    style: text.labelLarge?.copyWith(
                      color: cs.onPrimaryContainer.withValues(alpha: 0.85),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Icon(
                  Icons.visibility_off_outlined,
                  color: cs.onPrimaryContainer.withValues(alpha: 0.75),
                  size: 20,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Text(
                    _formatMoney(balanceCents),
                    style: text.headlineMedium?.copyWith(
                      color: cs.onPrimaryContainer,
                      fontWeight: FontWeight.w800,
                      height: 1.0,
                    ),
                  ),
                ),
                if (isNegative)
                  Text(
                    'Negative',
                    style: text.labelMedium?.copyWith(
                      color: cs.onPrimaryContainer.withValues(alpha: 0.8),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _PillButton(
                    icon: Icons.add_rounded,
                    label: 'Add',
                    onPressed: onAdd,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _PillButton(
                    icon: Icons.swap_horiz_rounded,
                    label: 'Transfer',
                    onPressed: onTransfer,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PillButton extends StatelessWidget {
  const _PillButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return FilledButton.tonalIcon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: FilledButton.styleFrom(
        backgroundColor: cs.surface.withValues(alpha: 0.18),
        foregroundColor: cs.onPrimaryContainer,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      ),
    );
  }
}
