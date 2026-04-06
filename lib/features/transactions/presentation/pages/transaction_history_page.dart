import 'package:expense_tracker/app/state/app_state_provider.dart';
import 'package:expense_tracker/app/state/app_state_snapshot.dart';
import 'package:expense_tracker/core/theme/app_colors.dart';
import 'package:expense_tracker/core/utils/date_label_formatter.dart';
import 'package:expense_tracker/core/widgets/context_action_menu.dart';
import 'package:expense_tracker/features/transactions/domain/models/transaction_item.dart';
import 'package:expense_tracker/features/transactions/presentation/pages/add_transaction_page.dart';
import 'package:expense_tracker/features/transactions/presentation/pages/transaction_detail_page.dart';
import 'package:expense_tracker/features/transactions/presentation/widgets/transaction_group.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum _HistoryTransactionAction { edit, delete }

class TransactionHistoryPage extends ConsumerStatefulWidget {
  const TransactionHistoryPage({super.key});

  @override
  ConsumerState<TransactionHistoryPage> createState() =>
      _TransactionHistoryPageState();
}

class _TransactionHistoryPageState
    extends ConsumerState<TransactionHistoryPage> {
  static const int _pageSize = 20;

  late final TextEditingController _searchController;
  late final ScrollController _scrollController;
  int _visibleCount = _pageSize;
  bool _isLoadingMore = false;
  bool _hasMoreAvailable = false;

  @override
  void initState() {
    super.initState();
    final initialQuery = ref.read(appStateProvider).historySearchQuery;
    _searchController = TextEditingController(text: initialQuery);
    _scrollController = ScrollController()..addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  Future<void> _openTransactionDetails(TransactionItem transaction) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) =>
            TransactionDetailPage(transactionId: transaction.id),
      ),
    );
  }

  Future<void> _editTransaction(TransactionItem transaction) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) =>
            AddTransactionPage(initialTransaction: transaction),
      ),
    );
  }

  Future<void> _deleteTransaction(TransactionItem transaction) async {
    final notifier = ref.read(appStateProvider.notifier);
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

    if (didConfirm != true) {
      return;
    }

    await notifier.deleteTransaction(transaction.id);
  }

  Future<void> _showTransactionActionMenu(
    TransactionItem transaction,
    LongPressStartDetails details,
  ) async {
    final selectedAction =
        await showContextActionMenu<_HistoryTransactionAction>(
          context: context,
          globalPosition: details.globalPosition,
          items: const [
            ContextActionMenuItem(
              value: _HistoryTransactionAction.edit,
              label: 'Edit',
              icon: Icons.edit_outlined,
            ),
            ContextActionMenuItem(
              value: _HistoryTransactionAction.delete,
              label: 'Delete',
              icon: Icons.delete_outline,
              foregroundColor: AppColors.dangerDark,
            ),
          ],
        );

    if (!mounted) {
      return;
    }

    switch (selectedAction) {
      case _HistoryTransactionAction.edit:
        await _editTransaction(transaction);
        return;
      case _HistoryTransactionAction.delete:
        await _deleteTransaction(transaction);
        return;
      case null:
        return;
    }
  }

  Future<void> _showSortPicker() async {
    final notifier = ref.read(appStateProvider.notifier);
    final currentSort = ref.read(appStateProvider).historySort;
    final selectedSort = await showModalBottomSheet<TransactionHistorySort>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.schedule_outlined),
                title: const Text('Newest first'),
                trailing: currentSort == TransactionHistorySort.newestFirst
                    ? const Icon(Icons.check_rounded)
                    : null,
                onTap: () => Navigator.of(
                  context,
                ).pop(TransactionHistorySort.newestFirst),
              ),
              ListTile(
                leading: const Icon(Icons.history_toggle_off_rounded),
                title: const Text('Oldest first'),
                trailing: currentSort == TransactionHistorySort.oldestFirst
                    ? const Icon(Icons.check_rounded)
                    : null,
                onTap: () => Navigator.of(
                  context,
                ).pop(TransactionHistorySort.oldestFirst),
              ),
            ],
          ),
        );
      },
    );

    if (selectedSort == null || !mounted) {
      return;
    }

    setState(() {
      _visibleCount = _pageSize;
    });
    notifier.updateHistorySort(selectedSort);
  }

  Future<void> _showFilterPicker() async {
    final notifier = ref.read(appStateProvider.notifier);
    final currentFilter = ref.read(appStateProvider).historyFilter;
    final selectedFilter = await showModalBottomSheet<TransactionHistoryFilter>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _FilterOptionTile(
                label: 'All transactions',
                icon: Icons.apps_rounded,
                isSelected: currentFilter == TransactionHistoryFilter.all,
                onTap: () =>
                    Navigator.of(context).pop(TransactionHistoryFilter.all),
              ),
              _FilterOptionTile(
                label: 'Income',
                icon: Icons.south_west_rounded,
                isSelected: currentFilter == TransactionHistoryFilter.income,
                onTap: () =>
                    Navigator.of(context).pop(TransactionHistoryFilter.income),
              ),
              _FilterOptionTile(
                label: 'Expenses',
                icon: Icons.north_east_rounded,
                isSelected: currentFilter == TransactionHistoryFilter.expense,
                onTap: () =>
                    Navigator.of(context).pop(TransactionHistoryFilter.expense),
              ),
              _FilterOptionTile(
                label: 'Transfers',
                icon: Icons.swap_horiz_rounded,
                isSelected: currentFilter == TransactionHistoryFilter.transfer,
                onTap: () => Navigator.of(
                  context,
                ).pop(TransactionHistoryFilter.transfer),
              ),
            ],
          ),
        );
      },
    );

    if (selectedFilter == null || !mounted) {
      return;
    }

    setState(() {
      _visibleCount = _pageSize;
    });
    notifier.updateHistoryFilter(selectedFilter);
  }

  void _onScroll() {
    if (!_hasMoreAvailable) {
      return;
    }

    final position = _scrollController.position;
    if (position.extentAfter > 480) {
      return;
    }

    _loadMore();
  }

  void _loadMore() {
    if (_isLoadingMore) {
      return;
    }

    setState(() {
      _isLoadingMore = true;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _visibleCount += _pageSize;
        _isLoadingMore = false;
      });
    });
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

  String _emptyLabel(AppStateSnapshot state) {
    if (state.historySearchQuery.isNotEmpty) {
      return 'No transactions match your search.';
    }

    return switch (state.historyFilter) {
      TransactionHistoryFilter.all => 'No transactions yet.',
      TransactionHistoryFilter.income =>
        'No income transactions match this filter.',
      TransactionHistoryFilter.expense =>
        'No expense transactions match this filter.',
      TransactionHistoryFilter.transfer =>
        'No transfer transactions match this filter.',
    };
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appStateProvider);
    final theme = Theme.of(context);
    final filteredTransactions = state.historyTransactions;
    final visibleTransactions = filteredTransactions
        .take(_visibleCount.clamp(0, filteredTransactions.length))
        .toList(growable: false);
    final groupedTransactions = _groupTransactions(visibleTransactions);
    final hasMore = visibleTransactions.length < filteredTransactions.length;
    _hasMoreAvailable = hasMore;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Transactions'),
        actions: [
          IconButton(
            onPressed: _showSortPicker,
            tooltip: 'Sort',
            icon: const Icon(Icons.swap_vert_rounded),
          ),
          IconButton(
            onPressed: _showFilterPicker,
            tooltip: 'Filter',
            icon: const Icon(Icons.filter_list_rounded),
          ),
        ],
      ),
      body: Builder(
        builder: (context) {
          if (!state.hasLoaded && state.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (groupedTransactions.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  _emptyLabel(state),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            );
          }

          return ListView(
            controller: _scrollController,
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
            children: [
              TextField(
                controller: _searchController,
                onChanged: (value) {
                  setState(() {
                    _visibleCount = _pageSize;
                  });
                  ref
                      .read(appStateProvider.notifier)
                      .updateHistorySearchQuery(value);
                },
                decoration: InputDecoration(
                  hintText: 'Search transactions',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: state.historySearchQuery.isEmpty
                      ? null
                      : IconButton(
                          onPressed: () {
                            _searchController.clear();
                            setState(() {
                              _visibleCount = _pageSize;
                            });
                            ref
                                .read(appStateProvider.notifier)
                                .updateHistorySearchQuery('');
                          },
                          icon: const Icon(Icons.close_rounded),
                        ),
                ),
              ),
              const SizedBox(height: 20),
              ...groupedTransactions.entries.map(
                (entry) => TransactionGroup(
                  label: entry.key,
                  transactions: entry.value,
                  categoryNameFor: (transaction) =>
                      transaction.type == TransactionType.transfer
                      ? 'Transfer'
                      : state.categoryById(transaction.categoryId)?.name ??
                            'Unknown category',
                  categoryIconFor: (transaction) =>
                      transaction.type == TransactionType.transfer
                      ? Icons.swap_horiz_rounded
                      : state.categoryById(transaction.categoryId)?.icon ??
                            Icons.sell_outlined,
                  accountNameFor: (transaction) =>
                      state
                          .accountById(
                            transaction.accountId ??
                                transaction.sourceAccountId,
                          )
                          ?.name ??
                      'Unknown account',
                  destinationAccountNameFor: (transaction) =>
                      state.accountById(transaction.destinationAccountId)?.name,
                  onTransactionTap: _openTransactionDetails,
                  onTransactionLongPressStart: _showTransactionActionMenu,
                ),
              ),
              if (_isLoadingMore)
                const Padding(
                  padding: EdgeInsets.only(top: 8, bottom: 12),
                  child: Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2.4),
                    ),
                  ),
                )
              else if (hasMore)
                const SizedBox(height: 24),
            ],
          );
        },
      ),
    );
  }
}

class _FilterOptionTile extends StatelessWidget {
  const _FilterOptionTile({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(label),
      trailing: isSelected ? const Icon(Icons.check_rounded) : null,
      onTap: onTap,
    );
  }
}
