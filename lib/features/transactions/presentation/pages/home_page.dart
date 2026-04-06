import 'package:expense_tracker/app/state/app_state_provider.dart';
import 'package:expense_tracker/core/utils/financial_period.dart';
import 'package:expense_tracker/core/theme/app_colors.dart';
import 'package:expense_tracker/core/utils/date_label_formatter.dart';
import 'package:expense_tracker/core/widgets/context_action_menu.dart';
import 'package:expense_tracker/features/transactions/domain/models/transaction_item.dart';
import 'package:expense_tracker/features/transactions/presentation/pages/add_transaction_page.dart';
import 'package:expense_tracker/features/transactions/presentation/pages/transaction_detail_page.dart';
import 'package:expense_tracker/features/transactions/presentation/pages/transaction_history_page.dart';
import 'package:expense_tracker/features/transactions/presentation/widgets/activity_summary_card.dart';
import 'package:expense_tracker/features/transactions/presentation/widgets/balance_card.dart';
import 'package:expense_tracker/features/transactions/presentation/widgets/transaction_group.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum _TransactionListAction { edit, delete }

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  static const double _floatingNavClearance = 128;

  Future<void> _addTransaction(BuildContext context, bool hasAccounts) async {
    if (!hasAccounts) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Create an account before adding your first transaction.',
          ),
        ),
      );
      return;
    }

    await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (context) => const AddTransactionPage()),
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
            'This transaction will be removed from your history.',
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
    final selectedAction = await showContextActionMenu<_TransactionListAction>(
      context: context,
      globalPosition: details.globalPosition,
      items: const [
        ContextActionMenuItem(
          value: _TransactionListAction.edit,
          label: 'Edit',
          icon: Icons.edit_outlined,
        ),
        ContextActionMenuItem(
          value: _TransactionListAction.delete,
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
      case _TransactionListAction.edit:
        await _editTransaction(context, transaction);
        return;
      case _TransactionListAction.delete:
        await _deleteTransaction(context, ref, transaction);
        return;
      case null:
        return;
    }
  }

  Future<void> _openTransactionHistory(BuildContext context) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (context) => const TransactionHistoryPage()),
    );
  }

  Map<String, List<TransactionItem>> _groupTransactions(
    List<TransactionItem> transactions,
  ) {
    final sortedTransactions = [...transactions]
      ..sort((a, b) => b.date.compareTo(a.date));
    final grouped = <String, List<TransactionItem>>{};

    for (final transaction in sortedTransactions) {
      final label = formatDateLabel(transaction.date);
      grouped.putIfAbsent(label, () => []).add(transaction);
    }

    return grouped;
  }

  String _balanceSubtitle(String periodLabel, int missingConversionCount) {
    if (missingConversionCount > 0) {
      return '$periodLabel • $missingConversionCount excluded until exchange rates load.';
    }

    return periodLabel;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appStateProvider);
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final groupedTransactions = _groupTransactions(state.periodTransactions);
    final periodLabel = FinancialPeriod(
      start: state.selectedPeriod.start,
      end: state.selectedPeriod.end,
      financialCycleDay: state.selectedPeriod.financialCycleDay,
    ).formatRangeLabel();

    return SafeArea(
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          20,
          20,
          20,
          32 + _floatingNavClearance + bottomInset,
        ),
        children: [
          Text(
            state.settings.greeting,
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 20),
          BalanceCard(
            balance: state.globalBalance,
            currencyCode: state.settings.defaultCurrencyCode,
            title: 'Balance',
            subtitle: _balanceSubtitle(
              periodLabel,
              state.missingGlobalBalanceConversionCount,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ActivitySummaryCard(
                  title: 'Income',
                  amount: state.periodSummary.income,
                  currencyCode: state.settings.defaultCurrencyCode,
                  accentColor: AppColors.income,
                  backgroundColor: AppColors.incomeSurface,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ActivitySummaryCard(
                  title: 'Expenses',
                  amount: state.periodSummary.expenses,
                  currencyCode: state.settings.defaultCurrencyCode,
                  accentColor: AppColors.textPrimary,
                  backgroundColor: AppColors.expenseSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ActivitySummaryCard(
            title: 'Net',
            amount: state.periodSummary.netMovement,
            currencyCode: state.settings.defaultCurrencyCode,
            accentColor: state.periodSummary.netMovement >= 0
                ? AppColors.income
                : AppColors.dangerDark,
            backgroundColor: Colors.white,
          ),
          const SizedBox(height: 28),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'This month',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              InkWell(
                onTap: () =>
                    _addTransaction(context, state.accounts.isNotEmpty),
                borderRadius: BorderRadius.circular(999),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                  child: Icon(Icons.add, color: AppColors.brand),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (!state.hasLoaded && state.isLoading)
            const Center(child: CircularProgressIndicator())
          else if (groupedTransactions.isEmpty)
            _EmptyPeriodState(
              hasAccounts: state.accounts.isNotEmpty,
              periodLabel: periodLabel,
            )
          else
            ...groupedTransactions.entries.map(
              (entry) => TransactionGroup(
                label: entry.key,
                transactions: entry.value,
                displayAmountFor: (transaction) =>
                    state.convertedAmountForTransaction(transaction.id) ??
                    transaction.amount,
                displayCurrencyCodeFor: (transaction) =>
                    state.convertedAmountForTransaction(transaction.id) != null
                    ? state.settings.defaultCurrencyCode
                    : transaction.currencyCode,
                categoryNameFor: (transaction) =>
                    transaction.isCreditCardPayment
                    ? 'Card payment'
                    : transaction.type == TransactionType.transfer
                    ? 'Transfer'
                    : state.categoryById(transaction.categoryId)?.name ??
                          'Unknown category',
                categoryIconFor: (transaction) =>
                    transaction.isCreditCardPayment
                    ? Icons.credit_card_rounded
                    : transaction.type == TransactionType.transfer
                    ? Icons.swap_horiz_rounded
                    : state.categoryById(transaction.categoryId)?.icon ??
                          Icons.sell_outlined,
                accountNameFor: (transaction) =>
                    state.accountById(transaction.primaryAccountId)?.name ??
                    'Unknown account',
                destinationAccountNameFor: (transaction) =>
                    state.accountById(transaction.secondaryAccountId)?.name,
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
          if (state.transactions.isNotEmpty) ...[
            const SizedBox(height: 4),
            Center(
              child: TextButton(
                onPressed: () => _openTransactionHistory(context),
                child: const Text('View more'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _EmptyPeriodState extends StatelessWidget {
  const _EmptyPeriodState({
    required this.hasAccounts,
    required this.periodLabel,
  });

  final bool hasAccounts;
  final String periodLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(
              hasAccounts
                  ? Icons.insights_outlined
                  : Icons.account_balance_wallet_outlined,
              color: AppColors.iconMuted,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            hasAccounts
                ? 'Nothing recorded for $periodLabel yet'
                : 'Create an account to get started',
            textAlign: TextAlign.center,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            hasAccounts
                ? 'New transactions will show up here so you can quickly review this month.'
                : 'Once you add an account, your balance and latest activity will appear here.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
