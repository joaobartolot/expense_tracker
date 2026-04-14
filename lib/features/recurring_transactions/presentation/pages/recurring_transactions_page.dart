import 'package:expense_tracker/app/state/app_state_provider.dart';
import 'package:expense_tracker/core/theme/app_colors.dart';
import 'package:expense_tracker/core/widgets/context_action_menu.dart';
import 'package:expense_tracker/features/recurring_transactions/domain/models/recurring_transaction_overview.dart';
import 'package:expense_tracker/features/recurring_transactions/presentation/pages/add_recurring_transaction_page.dart';
import 'package:expense_tracker/features/recurring_transactions/presentation/widgets/recurring_transaction_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum _RecurringTransactionAction { pause, resume, delete }

class RecurringTransactionsPage extends ConsumerWidget {
  const RecurringTransactionsPage({super.key});

  Future<void> _openCreateFlow(BuildContext context) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => const AddRecurringTransactionPage(),
      ),
    );
  }

  Future<void> _openEditFlow(
    BuildContext context,
    String recurringTransactionId,
    WidgetRef ref,
  ) async {
    final recurringTransaction = ref
        .read(appStateProvider)
        .recurringTransactionById(recurringTransactionId);
    if (recurringTransaction == null) {
      return;
    }

    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => AddRecurringTransactionPage(
          initialRecurringTransaction: recurringTransaction,
        ),
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    String recurringTransactionId,
    String title,
  ) async {
    final didConfirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete recurring item?'),
          content: Text('$title will stop creating future transactions.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.danger,
                foregroundColor: AppColors.white,
              ),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (didConfirm != true || !context.mounted) {
      return;
    }

    await ref
        .read(appStateProvider.notifier)
        .deleteRecurringTransaction(recurringTransactionId);
  }

  Future<void> _showRecurringActionMenu(
    BuildContext context,
    WidgetRef ref,
    RecurringTransactionOverview overview,
    LongPressStartDetails details,
  ) async {
    final recurringTransaction = overview.recurringTransaction;
    final selectedAction =
        await showContextActionMenu<_RecurringTransactionAction>(
          context: context,
          globalPosition: details.globalPosition,
          items: [
            ContextActionMenuItem(
              value: recurringTransaction.isPaused
                  ? _RecurringTransactionAction.resume
                  : _RecurringTransactionAction.pause,
              label: recurringTransaction.isPaused ? 'Resume' : 'Pause',
              icon: recurringTransaction.isPaused
                  ? Icons.play_arrow_outlined
                  : Icons.pause_outlined,
            ),
            const ContextActionMenuItem(
              value: _RecurringTransactionAction.delete,
              label: 'Delete',
              icon: Icons.delete_outline,
              foregroundColor: AppColors.dangerDark,
            ),
          ],
        );

    if (!context.mounted) {
      return;
    }

    switch (selectedAction) {
      case _RecurringTransactionAction.pause:
        await ref
            .read(appStateProvider.notifier)
            .setRecurringTransactionPaused(
              recurringTransaction.id,
              isPaused: true,
            );
        return;
      case _RecurringTransactionAction.resume:
        await ref
            .read(appStateProvider.notifier)
            .setRecurringTransactionPaused(
              recurringTransaction.id,
              isPaused: false,
            );
        return;
      case _RecurringTransactionAction.delete:
        await _confirmDelete(
          context,
          ref,
          recurringTransaction.id,
          recurringTransaction.title,
        );
        return;
      case null:
        return;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appStateProvider);
    final theme = Theme.of(context);
    final colors = AppColors.of(context);
    final manualDueItems = state.recurringTransactionOverviews
        .where(
          (overview) =>
              overview.recurringTransaction.isManual && overview.isDue,
        )
        .toList(growable: false);
    final manualDueIds = manualDueItems
        .map((overview) => overview.recurringTransaction.id)
        .toSet();
    final remainingItems = state.recurringTransactionOverviews
        .where(
          (overview) =>
              !manualDueIds.contains(overview.recurringTransaction.id),
        )
        .toList(growable: false);

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 128),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  'Recurring',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: colors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: () => _openCreateFlow(context),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Add'),
              ),
            ],
          ),
          const SizedBox(height: 24),
          if (manualDueItems.isNotEmpty) ...[
            const SizedBox(height: 28),
            Text(
              'Needs confirmation',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            for (final overview in manualDueItems) ...[
              RecurringTransactionCard(
                overview: overview,
                onTap: () => _openEditFlow(
                  context,
                  overview.recurringTransaction.id,
                  ref,
                ),
                onLongPressStart: (details) =>
                    _showRecurringActionMenu(context, ref, overview, details),
                onConfirm: () => ref
                    .read(appStateProvider.notifier)
                    .confirmRecurringTransaction(
                      overview.recurringTransaction.id,
                    ),
              ),
              const SizedBox(height: 12),
            ],
          ],
          const SizedBox(height: 12),
          Text(
            'All recurring items',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          if (state.recurringTransactionOverviews.isEmpty)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(28),
              ),
              child: Text(
                'No recurring items yet.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colors.textSecondary,
                ),
              ),
            )
          else
            for (final overview in remainingItems) ...[
              RecurringTransactionCard(
                overview: overview,
                onTap: () => _openEditFlow(
                  context,
                  overview.recurringTransaction.id,
                  ref,
                ),
                onLongPressStart: (details) =>
                    _showRecurringActionMenu(context, ref, overview, details),
                onConfirm: () => ref
                    .read(appStateProvider.notifier)
                    .confirmRecurringTransaction(
                      overview.recurringTransaction.id,
                    ),
              ),
              const SizedBox(height: 12),
            ],
        ],
      ),
    );
  }
}
