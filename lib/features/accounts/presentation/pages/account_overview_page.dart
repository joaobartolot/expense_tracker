import 'package:expense_tracker/app/state/app_state_provider.dart';
import 'package:expense_tracker/app/state/app_state_snapshot.dart';
import 'package:expense_tracker/core/theme/app_colors.dart';
import 'package:expense_tracker/core/utils/currency_formatter.dart';
import 'package:expense_tracker/core/utils/date_label_formatter.dart';
import 'package:expense_tracker/core/utils/financial_period.dart';
import 'package:expense_tracker/core/widgets/context_action_menu.dart';
import 'package:expense_tracker/core/widgets/highlight_summary_card.dart';
import 'package:expense_tracker/features/accounts/domain/models/account.dart';
import 'package:expense_tracker/features/accounts/domain/models/credit_card_account_state.dart';
import 'package:expense_tracker/features/accounts/presentation/pages/add_account_page.dart';
import 'package:expense_tracker/features/transactions/domain/models/transaction_item.dart';
import 'package:expense_tracker/features/transactions/presentation/pages/add_transaction_page.dart';
import 'package:expense_tracker/features/transactions/presentation/pages/transaction_detail_page.dart';
import 'package:expense_tracker/features/transactions/presentation/widgets/activity_summary_card.dart';
import 'package:expense_tracker/features/transactions/presentation/widgets/transaction_group.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum _AccountOverviewTransactionAction { edit, delete }

enum _AccountOverviewMenuAction { edit, addTransaction, transfer }

class AccountOverviewPage extends ConsumerWidget {
  const AccountOverviewPage({super.key, required this.accountId});

  final String accountId;

  Future<void> _openEditAccount(BuildContext context, Account account) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => AddAccountPage(initialAccount: account),
      ),
    );
  }

  Future<void> _openAddTransaction(
    BuildContext context,
    Account account,
  ) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => AddTransactionPage.forAccount(account: account),
      ),
    );
  }

  Future<void> _openTransfer(BuildContext context, Account account) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => AddTransactionPage.forAccount(account: account),
      ),
    );
  }

  Future<void> _openTransactionDetails(
    BuildContext context,
    TransactionItem transaction,
  ) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) =>
            TransactionDetailPage(transactionId: transaction.id),
      ),
    );
  }

  Future<void> _editTransaction(
    BuildContext context,
    TransactionItem transaction,
  ) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) =>
            AddTransactionPage(initialTransaction: transaction),
      ),
    );
  }

  Future<void> _deleteTransaction(
    BuildContext context,
    WidgetRef ref,
    TransactionItem transaction,
  ) async {
    final didConfirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete transaction?'),
          content: const Text(
            'This transaction will be removed from this account history.',
          ),
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

    await ref.read(appStateProvider.notifier).deleteTransaction(transaction.id);
  }

  Future<void> _showTransactionActionMenu(
    BuildContext context,
    WidgetRef ref,
    TransactionItem transaction,
    LongPressStartDetails details,
  ) async {
    final selectedAction =
        await showContextActionMenu<_AccountOverviewTransactionAction>(
          context: context,
          globalPosition: details.globalPosition,
          items: const [
            ContextActionMenuItem(
              value: _AccountOverviewTransactionAction.edit,
              label: 'Edit',
              icon: Icons.edit_outlined,
            ),
            ContextActionMenuItem(
              value: _AccountOverviewTransactionAction.delete,
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
      case _AccountOverviewTransactionAction.edit:
        await _editTransaction(context, transaction);
        return;
      case _AccountOverviewTransactionAction.delete:
        await _deleteTransaction(context, ref, transaction);
        return;
      case null:
        return;
    }
  }

  Future<void> _handleMenuAction(
    BuildContext context,
    Account account,
    _AccountOverviewMenuAction action,
  ) async {
    switch (action) {
      case _AccountOverviewMenuAction.edit:
        await _openEditAccount(context, account);
        return;
      case _AccountOverviewMenuAction.addTransaction:
        await _openAddTransaction(context, account);
        return;
      case _AccountOverviewMenuAction.transfer:
        await _openTransfer(context, account);
        return;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appStateProvider);
    final overview = state.accountOverviewFor(accountId);

    if (overview == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Account')),
        body: const Center(child: Text('This account is no longer available.')),
      );
    }

    final account = overview.account;
    final theme = Theme.of(context);
    final colors = AppColors.of(context);
    final periodLabel = FinancialPeriod(
      start: overview.selectedPeriod.start,
      end: overview.selectedPeriod.end,
      financialCycleDay: overview.selectedPeriod.financialCycleDay,
    ).formatRangeLabel();
    final groupedTransactions = _groupTransactions(overview.periodTransactions);
    final displayBalance = account.isCreditCard
        ? overview.creditCardState?.debt ?? 0
        : overview.balance;

    return Scaffold(
      appBar: AppBar(
        title: Text(account.name),
        actions: [
          PopupMenuButton<_AccountOverviewMenuAction>(
            onSelected: (action) => _handleMenuAction(context, account, action),
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: _AccountOverviewMenuAction.edit,
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.edit_outlined),
                  title: Text('Edit account'),
                ),
              ),
              PopupMenuItem(
                value: _AccountOverviewMenuAction.addTransaction,
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    account.isCreditCard
                        ? Icons.credit_card_rounded
                        : Icons.add_circle_outline_rounded,
                  ),
                  title: Text(
                    account.isCreditCard ? 'Add charge' : 'Add transaction',
                  ),
                ),
              ),
              PopupMenuItem(
                value: _AccountOverviewMenuAction.transfer,
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    account.isCreditCard
                        ? Icons.account_balance_wallet_outlined
                        : Icons.swap_horiz_rounded,
                  ),
                  title: Text(account.isCreditCard ? 'Pay card' : 'Transfer'),
                ),
              ),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            HighlightSummaryCard(
              title: account.isCreditCard ? 'Current debt' : 'Current balance',
              value: formatCurrency(
                displayBalance,
                currencyCode: account.currencyCode,
              ),
              subtitle: '${account.typeLabel} · ${account.currencyCode}',
              footer: _OverviewHeaderMeta(
                account: account,
                creditCardState: overview.creditCardState,
              ),
            ),
            const SizedBox(height: 24),
            _PeriodNavigator(
              label: periodLabel,
              onPrevious: () {
                ref
                    .read(appStateProvider.notifier)
                    .updateAccountSelectedPeriod(
                      account.id,
                      overview.selectedPeriod.start.subtract(
                        const Duration(days: 1),
                      ),
                    );
              },
              onNext: () {
                ref
                    .read(appStateProvider.notifier)
                    .updateAccountSelectedPeriod(
                      account.id,
                      overview.selectedPeriod.end,
                    );
              },
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ActivitySummaryCard(
                    title: 'Income',
                    amount: overview.periodSummary.income,
                    currencyCode: account.currencyCode,
                    accentColor: AppColors.income,
                    backgroundColor: AppColors.incomeSurface,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ActivitySummaryCard(
                    title: 'Expenses',
                    amount: overview.periodSummary.expenses,
                    currencyCode: account.currencyCode,
                    accentColor: AppColors.textPrimary,
                    backgroundColor: AppColors.expenseSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ActivitySummaryCard(
                    title: 'Net',
                    amount: overview.periodSummary.netMovement,
                    currencyCode: account.currencyCode,
                    accentColor: overview.periodSummary.netMovement >= 0
                        ? AppColors.income
                        : AppColors.dangerDark,
                    backgroundColor: Colors.white,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ActivitySummaryCard(
                    title: 'Transfers',
                    amount: overview.periodTransferSummary.netMovement,
                    currencyCode: account.currencyCode,
                    accentColor: overview.periodTransferSummary.netMovement >= 0
                        ? AppColors.brandDark
                        : AppColors.textPrimary,
                    backgroundColor: colors.surface,
                  ),
                ),
              ],
            ),
            if (account.isCreditCard) ...[
              const SizedBox(height: 12),
              _CreditCardOverviewCard(
                account: account,
                creditCardState: overview.creditCardState,
              ),
            ],
            const SizedBox(height: 28),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Activity',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: colors.textPrimary,
                    ),
                  ),
                ),
                if (overview.periodTransactions.isNotEmpty)
                  Text(
                    periodLabel,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            if (groupedTransactions.isEmpty)
              _AccountOverviewEmptyState(
                account: account,
                overview: overview,
                periodLabel: periodLabel,
                onAddTransactionPressed: () =>
                    _openAddTransaction(context, account),
                onTransferPressed: () => _openTransfer(context, account),
              )
            else
              ...groupedTransactions.entries.map(
                (entry) => TransactionGroup(
                  label: entry.key,
                  transactions: entry.value,
                  categoryNameFor: (transaction) => _categoryNameForTransaction(
                    state,
                    account.id,
                    transaction,
                  ),
                  categoryIconFor: (transaction) =>
                      _categoryIconForTransaction(state, transaction),
                  accountNameFor: (transaction) =>
                      state.accountById(transaction.primaryAccountId)?.name ??
                      'Unknown account',
                  destinationAccountNameFor: (transaction) =>
                      state.accountById(transaction.secondaryAccountId)?.name,
                  subtitleFor: (transaction) =>
                      _subtitleForTransaction(state, account.id, transaction),
                  showSignedTransferAmountFor: (transaction) =>
                      transaction.isTransfer,
                  displayAmountFor: (transaction) =>
                      _displayAmountForTransaction(account.id, transaction),
                  displayCurrencyCodeFor: (transaction) =>
                      _displayCurrencyCodeForTransaction(
                        account,
                        account.id,
                        transaction,
                      ),
                  onTransactionTap: (transaction) =>
                      _openTransactionDetails(context, transaction),
                  onTransactionLongPressStart: (transaction, details) =>
                      _showTransactionActionMenu(
                        context,
                        ref,
                        transaction,
                        details,
                      ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Map<String, List<TransactionItem>> _groupTransactions(
    List<TransactionItem> transactions,
  ) {
    final grouped = <String, List<TransactionItem>>{};

    for (final transaction in transactions) {
      final label = formatDateLabel(transaction.date);
      grouped.putIfAbsent(label, () => []).add(transaction);
    }

    return grouped;
  }

  String _categoryNameForTransaction(
    AppStateSnapshot state,
    String accountId,
    TransactionItem transaction,
  ) {
    if (transaction.isCreditCardPayment) {
      return transaction.destinationAccountId == accountId
          ? 'Card payment'
          : 'Payment sent';
    }

    if (transaction.type == TransactionType.transfer) {
      return transaction.destinationAccountId == accountId
          ? 'Transfer in'
          : 'Transfer out';
    }

    return state.categoryById(transaction.categoryId)?.name ??
        'Unknown category';
  }

  IconData _categoryIconForTransaction(
    AppStateSnapshot state,
    TransactionItem transaction,
  ) {
    if (transaction.isCreditCardPayment) {
      return Icons.credit_card_rounded;
    }

    if (transaction.type == TransactionType.transfer) {
      return Icons.swap_horiz_rounded;
    }

    return state.categoryById(transaction.categoryId)?.icon ??
        Icons.sell_outlined;
  }

  String _subtitleForTransaction(
    AppStateSnapshot state,
    String accountId,
    TransactionItem transaction,
  ) {
    if (transaction.type != TransactionType.transfer) {
      final category = state.categoryById(transaction.categoryId)?.name;
      return '${category ?? 'Transaction'} · ${state.accountById(accountId)?.name ?? 'Unknown account'}';
    }

    final sourceName =
        state.accountById(transaction.sourceAccountId)?.name ??
        'Unknown account';
    final destinationName =
        state.accountById(transaction.destinationAccountId)?.name ??
        'Unknown account';
    if (transaction.destinationAccountId == accountId) {
      return 'From $sourceName';
    }

    return 'To $destinationName';
  }

  double _displayAmountForTransaction(
    String accountId,
    TransactionItem transaction,
  ) {
    if (transaction.type == TransactionType.transfer) {
      if (transaction.destinationAccountId == accountId) {
        return transaction.destinationAmount ?? transaction.amount;
      }
      return -transaction.amount;
    }

    return transaction.type == TransactionType.income
        ? transaction.amount
        : -transaction.amount;
  }

  String _displayCurrencyCodeForTransaction(
    Account account,
    String accountId,
    TransactionItem transaction,
  ) {
    if (transaction.type == TransactionType.transfer &&
        transaction.destinationAccountId == accountId) {
      return transaction.destinationCurrencyCode ?? account.currencyCode;
    }

    return transaction.currencyCode;
  }
}

class _OverviewHeaderMeta extends StatelessWidget {
  const _OverviewHeaderMeta({
    required this.account,
    required this.creditCardState,
  });

  final Account account;
  final CreditCardAccountState? creditCardState;

  @override
  Widget build(BuildContext context) {
    final details = <String>[
      if (account.isPrimary) 'Main account',
      if (account.description.trim().isNotEmpty) account.description.trim(),
      if (creditCardState?.nextDueDate case final dueDate?)
        'Due ${MaterialLocalizations.of(context).formatShortDate(dueDate)}',
    ];

    if (details.isEmpty) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    return Text(
      details.join('  •  '),
      style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.whiteMuted),
    );
  }
}

class _PeriodNavigator extends StatelessWidget {
  const _PeriodNavigator({
    required this.label,
    required this.onPrevious,
    required this.onNext,
  });

  final String label;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: onPrevious,
            icon: const Icon(Icons.chevron_left_rounded),
          ),
          Expanded(
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: colors.textPrimary,
              ),
            ),
          ),
          IconButton(
            onPressed: onNext,
            icon: const Icon(Icons.chevron_right_rounded),
          ),
        ],
      ),
    );
  }
}

class _CreditCardOverviewCard extends StatelessWidget {
  const _CreditCardOverviewCard({
    required this.account,
    required this.creditCardState,
  });

  final Account account;
  final CreditCardAccountState? creditCardState;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = AppColors.of(context);
    final statusLabel = switch (creditCardState?.status) {
      CreditCardPaymentStatus.paid => 'Paid this cycle',
      CreditCardPaymentStatus.unpaid => 'Payment overdue',
      CreditCardPaymentStatus.upcoming => 'Payment upcoming',
      null => 'Payment details unavailable',
    };
    final dueLabel = switch (creditCardState?.nextDueDate) {
      final dueDate? => MaterialLocalizations.of(
        context,
      ).formatMediumDate(dueDate),
      null => 'No due date set',
    };
    final paidThisCycle = creditCardState?.paymentAmountThisCycle ?? 0;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Credit card details',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            statusLabel,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: colors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Next due $dueLabel',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colors.textSecondary,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _OverviewChip(
                label:
                    'Paid this cycle ${formatCurrency(paidThisCycle, currencyCode: account.currencyCode)}',
              ),
              _OverviewChip(
                label: account.paymentTrackingLabel ?? 'Manual payments',
              ),
              if (creditCardState?.hasDebt == false)
                const _OverviewChip(label: 'No debt yet'),
            ],
          ),
        ],
      ),
    );
  }
}

class _AccountOverviewEmptyState extends StatelessWidget {
  const _AccountOverviewEmptyState({
    required this.account,
    required this.overview,
    required this.periodLabel,
    required this.onAddTransactionPressed,
    required this.onTransferPressed,
  });

  final Account account;
  final AccountOverview overview;
  final String periodLabel;
  final VoidCallback onAddTransactionPressed;
  final VoidCallback onTransferPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = AppColors.of(context);

    final (title, message) = switch ((
      overview.allTransactions.isEmpty,
      account.isCreditCard,
      overview.balance != 0,
    )) {
      (true, true, _) => (
        'No credit card activity yet',
        'Charges and payments for this card will show up here once you start using it.',
      ),
      (true, false, true) => (
        'Balance tracked, no activity yet',
        'This account already has a balance, but there are no transactions linked to it yet.',
      ),
      (true, false, false) => (
        'No activity yet',
        'Add a transaction or transfer to start building this account history.',
      ),
      (false, _, _) => (
        'Nothing in $periodLabel',
        'Try another financial period or add new activity for this account.',
      ),
    };

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: colors.background,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(account.icon, color: colors.iconMuted),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: colors.textSecondary,
            ),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            alignment: WrapAlignment.center,
            children: [
              OutlinedButton.icon(
                onPressed: onAddTransactionPressed,
                icon: const Icon(Icons.add_circle_outline_rounded),
                label: const Text('Add transaction'),
              ),
              FilledButton.tonalIcon(
                onPressed: onTransferPressed,
                icon: Icon(
                  account.isCreditCard
                      ? Icons.account_balance_wallet_outlined
                      : Icons.swap_horiz_rounded,
                ),
                label: Text(account.isCreditCard ? 'Pay card' : 'Transfer'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _OverviewChip extends StatelessWidget {
  const _OverviewChip({required this.label});

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
