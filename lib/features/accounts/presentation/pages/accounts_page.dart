import 'package:expense_tracker/app/state/app_state_provider.dart';
import 'package:expense_tracker/core/theme/app_colors.dart';
import 'package:expense_tracker/core/widgets/context_action_menu.dart';
import 'package:expense_tracker/features/accounts/domain/models/account.dart';
import 'package:expense_tracker/features/accounts/presentation/pages/add_account_page.dart';
import 'package:expense_tracker/features/accounts/presentation/widgets/account_summary_card.dart';
import 'package:expense_tracker/features/accounts/presentation/widgets/account_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AccountsPage extends ConsumerStatefulWidget {
  const AccountsPage({super.key});

  static const double _floatingNavClearance = 128;

  @override
  ConsumerState<AccountsPage> createState() => _AccountsPageState();
}

class _AccountsPageState extends ConsumerState<AccountsPage> {
  bool _isOrganizing = false;

  Future<void> _openAddAccount(BuildContext context) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (context) => const AddAccountPage()),
    );
  }

  Future<void> _openEditAccount(BuildContext context, Account account) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => AddAccountPage(initialAccount: account),
      ),
    );
  }

  Future<void> _deleteAccount(BuildContext context, Account account) async {
    final appState = ref.read(appStateProvider.notifier);
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

    try {
      await appState.deleteAccount(account);
    } on LinkedEntityException catch (error) {
      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
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

  Future<void> _reorderAccounts(
    BuildContext context,
    List<Account> accounts,
    int oldIndex,
    int newIndex,
  ) async {
    final hasPinnedPrimary = accounts.isNotEmpty && accounts.first.isPrimary;
    if (hasPinnedPrimary && oldIndex == 0) {
      return;
    }

    final reorderedAccounts = [...accounts];
    if (newIndex > oldIndex) {
      newIndex -= 1;
    }
    if (hasPinnedPrimary && newIndex == 0) {
      newIndex = 1;
    }

    final movedAccount = reorderedAccounts.removeAt(oldIndex);
    reorderedAccounts.insert(newIndex, movedAccount);

    await ref
        .read(appStateProvider.notifier)
        .reorderAccounts(reorderedAccounts);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appStateProvider);
    final theme = Theme.of(context);
    final colors = AppColors.of(context);
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final accounts = state.accounts;

    return SafeArea(
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          20,
          20,
          20,
          32 + AccountsPage._floatingNavClearance + bottomInset,
        ),
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
                      style: theme.textTheme.headlineMedium?.copyWith(
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
              const SizedBox(width: 16),
              FilledButton.icon(
                onPressed: () => _openAddAccount(context),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Add'),
              ),
            ],
          ),
          const SizedBox(height: 24),
          AccountSummaryCard(
            totalBalance: state.globalBalance,
            accountCount: accounts.length,
            currencyCode: state.settings.defaultCurrencyCode,
          ),
          const SizedBox(height: 28),
          if (!state.hasLoaded && state.isLoading)
            const Center(child: CircularProgressIndicator())
          else if (accounts.isEmpty)
            _EmptyAccountsState(
              onCreatePressed: () {
                _openAddAccount(context);
              },
            )
          else ...[
            Row(
              children: [
                Text(
                  _isOrganizing ? 'Organizing accounts' : 'Your accounts',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: colors.textPrimary,
                  ),
                ),
                const Spacer(),
                if (accounts.length > 1)
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _isOrganizing = !_isOrganizing;
                      });
                    },
                    child: Text(_isOrganizing ? 'Done' : 'Organize'),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            _isOrganizing
                ? ReorderableListView.builder(
                    shrinkWrap: true,
                    buildDefaultDragHandles: false,
                    physics: const NeverScrollableScrollPhysics(),
                    proxyDecorator: (child, index, animation) {
                      return AnimatedBuilder(
                        animation: animation,
                        builder: (context, _) {
                          final elevation = Tween<double>(
                            begin: 0,
                            end: 10,
                          ).evaluate(animation);

                          return Material(
                            type: MaterialType.transparency,
                            elevation: elevation,
                            shadowColor: AppColors.shadow,
                            child: child,
                          );
                        },
                      );
                    },
                    itemCount: accounts.length,
                    onReorder: (oldIndex, newIndex) =>
                        _reorderAccounts(context, accounts, oldIndex, newIndex),
                    itemBuilder: (context, index) {
                      final account = accounts[index];
                      final canDrag = !account.isPrimary;
                      return Padding(
                        key: ValueKey(account.id),
                        padding: const EdgeInsets.only(bottom: 14),
                        child: AccountTile(
                          account: account,
                          balance: state.balanceForAccount(account.id),
                          leading: SizedBox(
                            width: 24,
                            child: canDrag
                                ? ReorderableDragStartListener(
                                    index: index,
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 2,
                                      ),
                                      child: Icon(
                                        Icons.drag_indicator_rounded,
                                        color: colors.iconMuted,
                                        size: 22,
                                      ),
                                    ),
                                  )
                                : Icon(
                                    Icons.push_pin_rounded,
                                    color: colors.iconMuted,
                                    size: 18,
                                  ),
                          ),
                        ),
                      );
                    },
                  )
                : Column(
                    children: accounts
                        .map(
                          (account) => Padding(
                            padding: const EdgeInsets.only(bottom: 14),
                            child: AccountTile(
                              account: account,
                              balance: state.balanceForAccount(account.id),
                              onTap: () => _openEditAccount(context, account),
                              onLongPressStart: (details) =>
                                  _showAccountActionMenu(
                                    context,
                                    account,
                                    details,
                                  ),
                            ),
                          ),
                        )
                        .toList(growable: false),
                  ),
          ],
        ],
      ),
    );
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
