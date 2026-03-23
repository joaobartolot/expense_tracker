import 'package:expense_tracker/core/theme/app_colors.dart';
import 'package:expense_tracker/core/widgets/context_action_menu.dart';
import 'package:expense_tracker/features/accounts/data/account_repository.dart';
import 'package:expense_tracker/features/accounts/domain/models/account.dart';
import 'package:expense_tracker/features/accounts/presentation/pages/add_account_page.dart';
import 'package:expense_tracker/features/accounts/presentation/widgets/account_summary_card.dart';
import 'package:expense_tracker/features/accounts/presentation/widgets/account_tile.dart';
import 'package:expense_tracker/features/settings/data/settings_repository.dart';
import 'package:expense_tracker/features/transactions/data/transaction_repository.dart';
import 'package:expense_tracker/features/transactions/domain/models/transaction_item.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

class AccountsPage extends StatelessWidget {
  const AccountsPage({
    super.key,
    required this.repository,
    required this.transactionRepository,
    required this.settingsRepository,
  });

  final AccountRepository repository;
  final TransactionRepository transactionRepository;
  final SettingsRepository settingsRepository;

  Future<void> _openAddAccount(BuildContext context) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => AddAccountPage(
          repository: repository,
          settingsRepository: settingsRepository,
        ),
      ),
    );
  }

  Future<void> _openEditAccount(BuildContext context, Account account) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => AddAccountPage(
          repository: repository,
          settingsRepository: settingsRepository,
          initialAccount: account,
        ),
      ),
    );
  }

  Future<void> _deleteAccount(BuildContext context, Account account) async {
    final transactions = await transactionRepository.getTransactions();
    if (!context.mounted) {
      return;
    }

    final hasLinkedTransactions = transactions.any(
      (transaction) => transaction.accountId == account.id,
    );

    if (hasLinkedTransactions) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Move or delete transactions from ${account.name} before removing the account.',
          ),
        ),
      );
      return;
    }

    final didConfirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete account?'),
          content: Text(
            'The tracked balance for ${account.name} will be removed.',
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

    if (didConfirm != true) {
      return;
    }

    await repository.deleteAccount(account.id);
  }

  Future<void> _showAccountActionMenu(
    BuildContext context,
    Account account,
    LongPressStartDetails details,
  ) async {
    final selectedAction = await showContextActionMenu<AccountTileAction>(
      context: context,
      globalPosition: details.globalPosition,
      items: const [
        ContextActionMenuItem(
          value: AccountTileAction.edit,
          label: 'Edit',
          icon: Icons.edit_outlined,
        ),
        ContextActionMenuItem(
          value: AccountTileAction.delete,
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
      case AccountTileAction.edit:
        await _openEditAccount(context, account);
        return;
      case AccountTileAction.delete:
        await _deleteAccount(context, account);
        return;
      case null:
        return;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = AppColors.of(context);

    return SafeArea(
      child: ValueListenableBuilder<Box<dynamic>>(
        valueListenable: repository.listenable(),
        builder: (context, value, child) {
          return ValueListenableBuilder<Box<dynamic>>(
            valueListenable: transactionRepository.listenable(),
            builder: (context, transactionValue, child) {
              return FutureBuilder<
                ({List<Account> accounts, List<TransactionItem> transactions})
              >(
                future: _loadPageData(),
                builder: (context, snapshot) {
                  final accounts = snapshot.data?.accounts ?? const <Account>[];
                  final transactions =
                      snapshot.data?.transactions ?? const <TransactionItem>[];
                  final effectiveBalances = _effectiveBalances(
                    accounts: accounts,
                    transactions: transactions,
                  );
                  final totalBalance = effectiveBalances.values.fold<double>(
                    0,
                    (sum, balance) => sum + balance,
                  );

                  return ListView(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Accounts',
                                  style: theme.textTheme.headlineMedium
                                      ?.copyWith(
                                        fontWeight: FontWeight.w700,
                                        color: colors.textPrimary,
                                      ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Track balances across bank, cash, savings, and cards.',
                                  style: theme.textTheme.bodyLarge?.copyWith(
                                    color: colors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          FilledButton.icon(
                            onPressed: () => _openAddAccount(context),
                            icon: const Icon(Icons.add_rounded),
                            label: const Text('Add'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      AccountSummaryCard(
                        totalBalance: totalBalance,
                        accountCount: accounts.length,
                        currencyCode: settingsRepository
                            .getSettings()
                            .defaultCurrencyCode,
                      ),
                      const SizedBox(height: 28),
                      if (snapshot.connectionState == ConnectionState.waiting &&
                          accounts.isEmpty)
                        const Center(child: CircularProgressIndicator())
                      else if (accounts.isEmpty)
                        _EmptyAccountsState(
                          onCreatePressed: () {
                            _openAddAccount(context);
                          },
                        )
                      else
                        ...accounts.map(
                          (account) => Padding(
                            padding: const EdgeInsets.only(bottom: 14),
                            child: AccountTile(
                              account: account,
                              balance:
                                  effectiveBalances[account.id] ??
                                  account.balance,
                              onTap: () => _openEditAccount(context, account),
                              onLongPressStart: (details) =>
                                  _showAccountActionMenu(
                                    context,
                                    account,
                                    details,
                                  ),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Future<({List<Account> accounts, List<TransactionItem> transactions})>
  _loadPageData() async {
    final results = await Future.wait<dynamic>([
      repository.getAccounts(),
      transactionRepository.getTransactions(),
    ]);

    return (
      accounts: results[0] as List<Account>,
      transactions: results[1] as List<TransactionItem>,
    );
  }

  Map<String, double> _effectiveBalances({
    required List<Account> accounts,
    required List<TransactionItem> transactions,
  }) {
    final balances = {
      for (final account in accounts) account.id: account.balance,
    };

    for (final transaction in transactions) {
      final accountId = transaction.accountId;
      if (!balances.containsKey(accountId)) {
        continue;
      }

      balances[accountId] = balances[accountId]! + transaction.signedAmount;
    }

    return balances;
  }
}

class _EmptyAccountsState extends StatelessWidget {
  const _EmptyAccountsState({required this.onCreatePressed});

  final VoidCallback onCreatePressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = AppColors.of(context);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: colors.background,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(
              Icons.account_balance_wallet_outlined,
              color: colors.iconMuted,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'No tracked accounts yet',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Create your first balance source so future transactions and transfers have a home.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: colors.textSecondary,
            ),
          ),
          const SizedBox(height: 18),
          FilledButton(
            onPressed: onCreatePressed,
            child: const Text('Create account'),
          ),
        ],
      ),
    );
  }
}
