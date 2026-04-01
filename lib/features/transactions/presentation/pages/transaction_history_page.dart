import 'package:expense_tracker/core/theme/app_colors.dart';
import 'package:expense_tracker/core/utils/date_label_formatter.dart';
import 'package:expense_tracker/core/widgets/context_action_menu.dart';
import 'package:expense_tracker/features/accounts/data/account_repository.dart';
import 'package:expense_tracker/features/accounts/domain/models/account.dart';
import 'package:expense_tracker/features/categories/data/category_repository.dart';
import 'package:expense_tracker/features/categories/domain/models/category_item.dart';
import 'package:expense_tracker/features/settings/data/settings_repository.dart';
import 'package:expense_tracker/features/transactions/data/transaction_repository.dart';
import 'package:expense_tracker/features/transactions/domain/models/transaction_item.dart';
import 'package:expense_tracker/features/transactions/presentation/pages/add_transaction_page.dart';
import 'package:expense_tracker/features/transactions/presentation/pages/transaction_detail_page.dart';
import 'package:expense_tracker/features/transactions/presentation/widgets/transaction_group.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

enum _HistorySort { newestFirst, oldestFirst }

enum _HistoryFilter { all, income, expense, transfer }

enum _HistoryTransactionAction { edit, delete }

class TransactionHistoryPage extends StatefulWidget {
  const TransactionHistoryPage({
    super.key,
    required this.repository,
    required this.categoryRepository,
    required this.settingsRepository,
    required this.accountRepository,
  });

  final TransactionRepository repository;
  final CategoryRepository categoryRepository;
  final SettingsRepository settingsRepository;
  final AccountRepository accountRepository;

  @override
  State<TransactionHistoryPage> createState() => _TransactionHistoryPageState();
}

class _TransactionHistoryPageState extends State<TransactionHistoryPage> {
  static const int _pageSize = 20;

  _HistorySort _sort = _HistorySort.newestFirst;
  _HistoryFilter _filter = _HistoryFilter.all;
  late final TextEditingController _searchController;
  late final ScrollController _scrollController;
  String _searchQuery = '';
  int _visibleCount = _pageSize;
  bool _isLoadingMore = false;
  bool _hasMoreAvailable = false;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
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
        builder: (context) => TransactionDetailPage(
          transaction: transaction,
          repository: widget.repository,
          categoryRepository: widget.categoryRepository,
          accountRepository: widget.accountRepository,
          settingsRepository: widget.settingsRepository,
        ),
      ),
    );
  }

  Future<void> _editTransaction(TransactionItem transaction) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => AddTransactionPage(
          repository: widget.repository,
          categoryRepository: widget.categoryRepository,
          accountRepository: widget.accountRepository,
          settingsRepository: widget.settingsRepository,
          initialTransaction: transaction,
        ),
      ),
    );
  }

  Future<void> _deleteTransaction(TransactionItem transaction) async {
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

    await widget.repository.deleteTransaction(transaction.id);
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
    final selectedSort = await showModalBottomSheet<_HistorySort>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.schedule_outlined),
                title: const Text('Newest first'),
                trailing: _sort == _HistorySort.newestFirst
                    ? const Icon(Icons.check_rounded)
                    : null,
                onTap: () =>
                    Navigator.of(context).pop(_HistorySort.newestFirst),
              ),
              ListTile(
                leading: const Icon(Icons.history_toggle_off_rounded),
                title: const Text('Oldest first'),
                trailing: _sort == _HistorySort.oldestFirst
                    ? const Icon(Icons.check_rounded)
                    : null,
                onTap: () =>
                    Navigator.of(context).pop(_HistorySort.oldestFirst),
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
      _sort = selectedSort;
      _visibleCount = _pageSize;
    });
  }

  Future<void> _showFilterPicker() async {
    final selectedFilter = await showModalBottomSheet<_HistoryFilter>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _FilterOptionTile(
                label: 'All transactions',
                icon: Icons.apps_rounded,
                isSelected: _filter == _HistoryFilter.all,
                onTap: () => Navigator.of(context).pop(_HistoryFilter.all),
              ),
              _FilterOptionTile(
                label: 'Income',
                icon: Icons.south_west_rounded,
                isSelected: _filter == _HistoryFilter.income,
                onTap: () => Navigator.of(context).pop(_HistoryFilter.income),
              ),
              _FilterOptionTile(
                label: 'Expenses',
                icon: Icons.north_east_rounded,
                isSelected: _filter == _HistoryFilter.expense,
                onTap: () => Navigator.of(context).pop(_HistoryFilter.expense),
              ),
              _FilterOptionTile(
                label: 'Transfers',
                icon: Icons.swap_horiz_rounded,
                isSelected: _filter == _HistoryFilter.transfer,
                onTap: () => Navigator.of(context).pop(_HistoryFilter.transfer),
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
      _filter = selectedFilter;
      _visibleCount = _pageSize;
    });
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
      body: ValueListenableBuilder<Box<dynamic>>(
        valueListenable: widget.repository.listenable(),
        builder: (context, transactionValue, child) {
          return FutureBuilder<_TransactionHistoryData>(
            future: _loadPageData(),
            builder: (context, snapshot) {
              final pageData =
                  snapshot.data ?? const _TransactionHistoryData.empty();
              final categoriesById = {
                for (final category in pageData.categories)
                  category.id: category,
              };
              final accountsById = {
                for (final account in pageData.accounts) account.id: account,
              };
              final filteredTransactions = _applySortAndFilter(
                transactions: pageData.transactions,
                categoriesById: categoriesById,
                accountsById: accountsById,
              );
              final visibleTransactions = filteredTransactions
                  .take(_visibleCount.clamp(0, filteredTransactions.length))
                  .toList(growable: false);
              final groupedTransactions = _groupTransactions(
                visibleTransactions,
              );
              final hasMore =
                  visibleTransactions.length < filteredTransactions.length;
              _hasMoreAvailable = hasMore;

              if (snapshot.connectionState == ConnectionState.waiting &&
                  pageData.transactions.isEmpty) {
                return const Center(child: CircularProgressIndicator());
              }

              if (groupedTransactions.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      _emptyLabel,
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
                        _searchQuery = value.trim().toLowerCase();
                        _visibleCount = _pageSize;
                      });
                    },
                    decoration: InputDecoration(
                      hintText: 'Search transactions',
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: _searchQuery.isEmpty
                          ? null
                          : IconButton(
                              onPressed: () {
                                _searchController.clear();
                                setState(() {
                                  _searchQuery = '';
                                  _visibleCount = _pageSize;
                                });
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
                          : categoriesById[transaction.categoryId]?.name ??
                                'Unknown category',
                      categoryIconFor: (transaction) =>
                          transaction.type == TransactionType.transfer
                          ? Icons.swap_horiz_rounded
                          : categoriesById[transaction.categoryId]?.icon ??
                                Icons.sell_outlined,
                      accountNameFor: (transaction) =>
                          accountsById[transaction.accountId ??
                                  transaction.sourceAccountId]
                              ?.name ??
                          'Unknown account',
                      destinationAccountNameFor: (transaction) =>
                          transaction.destinationAccountId == null
                          ? null
                          : accountsById[transaction.destinationAccountId]
                                ?.name,
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
          );
        },
      ),
    );
  }

  Future<_TransactionHistoryData> _loadPageData() async {
    final results = await Future.wait<dynamic>([
      widget.repository.getTransactions(),
      widget.categoryRepository.getCategories(),
      widget.accountRepository.getAccounts(),
    ]);

    return _TransactionHistoryData(
      transactions: results[0] as List<TransactionItem>,
      categories: results[1] as List<CategoryItem>,
      accounts: results[2] as List<Account>,
    );
  }

  List<TransactionItem> _applySortAndFilter({
    required List<TransactionItem> transactions,
    required Map<String, CategoryItem> categoriesById,
    required Map<String, Account> accountsById,
  }) {
    final filtered = transactions
        .where((transaction) {
          final matchesFilter = switch (_filter) {
            _HistoryFilter.all => true,
            _HistoryFilter.income => transaction.type == TransactionType.income,
            _HistoryFilter.expense =>
              transaction.type == TransactionType.expense,
            _HistoryFilter.transfer =>
              transaction.type == TransactionType.transfer,
          };

          if (!matchesFilter) {
            return false;
          }

          if (_searchQuery.isEmpty) {
            return true;
          }

          final category = categoriesById[transaction.categoryId];
          final account =
              accountsById[transaction.accountId ??
                  transaction.sourceAccountId];
          final destinationAccount =
              accountsById[transaction.destinationAccountId];
          final searchableText = [
            transaction.title,
            category?.name,
            category?.description,
            account?.name,
            account?.description,
            destinationAccount?.name,
            destinationAccount?.description,
          ].whereType<String>().join(' ').toLowerCase();

          return searchableText.contains(_searchQuery);
        })
        .toList(growable: false);

    final sorted = [...filtered]
      ..sort((a, b) {
        final comparison = a.date.compareTo(b.date);
        return _sort == _HistorySort.oldestFirst ? comparison : -comparison;
      });

    return sorted;
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

  String get _emptyLabel {
    if (_searchQuery.isNotEmpty) {
      return 'No transactions match your search.';
    }

    return switch (_filter) {
      _HistoryFilter.all => 'No transactions yet.',
      _HistoryFilter.income => 'No income transactions match this filter.',
      _HistoryFilter.expense => 'No expense transactions match this filter.',
      _HistoryFilter.transfer => 'No transfer transactions match this filter.',
    };
  }
}

class _TransactionHistoryData {
  const _TransactionHistoryData({
    required this.transactions,
    required this.categories,
    required this.accounts,
  });

  const _TransactionHistoryData.empty()
    : transactions = const [],
      categories = const [],
      accounts = const [];

  final List<TransactionItem> transactions;
  final List<CategoryItem> categories;
  final List<Account> accounts;
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
