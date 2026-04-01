import 'package:expense_tracker/core/widgets/context_action_menu.dart';
import 'package:expense_tracker/core/theme/app_colors.dart';
import 'package:expense_tracker/core/utils/date_label_formatter.dart';
import 'package:expense_tracker/features/accounts/data/account_repository.dart';
import 'package:expense_tracker/features/accounts/domain/models/account.dart';
import 'package:expense_tracker/features/accounts/domain/services/balance_overview_service.dart';
import 'package:expense_tracker/features/categories/data/category_repository.dart';
import 'package:expense_tracker/features/categories/domain/models/category_item.dart';
import 'package:expense_tracker/features/settings/data/settings_repository.dart';
import 'package:expense_tracker/features/transactions/data/transaction_repository.dart';
import 'package:expense_tracker/features/transactions/domain/models/transaction_item.dart';
import 'package:expense_tracker/features/transactions/presentation/pages/add_transaction_page.dart';
import 'package:expense_tracker/features/transactions/presentation/pages/transaction_history_page.dart';
import 'package:expense_tracker/features/transactions/presentation/pages/transaction_detail_page.dart';
import 'package:expense_tracker/features/transactions/presentation/widgets/activity_summary_card.dart';
import 'package:expense_tracker/features/transactions/presentation/widgets/balance_card.dart';
import 'package:expense_tracker/features/transactions/presentation/widgets/transaction_group.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';

enum _TransactionListAction { edit, delete }

class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    required this.repository,
    required this.categoryRepository,
    required this.settingsRepository,
    required this.accountRepository,
    required this.balanceOverviewService,
  });

  final TransactionRepository repository;
  final CategoryRepository categoryRepository;
  final SettingsRepository settingsRepository;
  final AccountRepository accountRepository;
  final BalanceOverviewService balanceOverviewService;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  static const double _floatingNavClearance = 128;

  Future<void> _addTransaction(List<Account> accounts) async {
    if (accounts.isEmpty) {
      _showAccountsRequiredMessage();
      return;
    }

    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => AddTransactionPage(
          repository: widget.repository,
          categoryRepository: widget.categoryRepository,
          accountRepository: widget.accountRepository,
          settingsRepository: widget.settingsRepository,
        ),
      ),
    );
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

  void _showAccountsRequiredMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Create an account before adding your first transaction.',
        ),
      ),
    );
  }

  Future<void> _showTransactionActionMenu(
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

    if (!mounted) {
      return;
    }

    switch (selectedAction) {
      case _TransactionListAction.edit:
        await _editTransaction(transaction);
        return;
      case _TransactionListAction.delete:
        await _deleteTransaction(transaction);
        return;
      case null:
        return;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return SafeArea(
      child: ValueListenableBuilder<Box<dynamic>>(
        valueListenable: widget.settingsRepository.listenable(),
        builder: (context, settingsValue, child) {
          final settings = widget.settingsRepository.getSettings();

          return ValueListenableBuilder<Box<dynamic>>(
            valueListenable: widget.accountRepository.listenable(),
            builder: (context, accountValue, child) {
              return ValueListenableBuilder<Box<dynamic>>(
                valueListenable: widget.repository.listenable(),
                builder: (context, transactionValue, child) {
                  return FutureBuilder<_HomePageData>(
                    future: _loadHomePageData(),
                    builder: (context, snapshot) {
                      final homeData =
                          snapshot.data ?? const _HomePageData.empty();
                      final currentPeriod = _currentMonthPeriod();
                      final periodTransactions = _transactionsInPeriod(
                        transactions: homeData.transactions,
                        period: currentPeriod,
                      );
                      final groupedTransactions = _groupTransactions(
                        periodTransactions,
                      );
                      final categoriesById = {
                        for (final category in homeData.categories)
                          category.id: category,
                      };
                      final accountsById = {
                        for (final account in homeData.accounts)
                          account.id: account,
                      };
                      final activitySummary = _buildActivitySummary(
                        periodTransactions,
                      );
                      final periodLabel = DateFormat(
                        'MMMM yyyy',
                      ).format(currentPeriod.start);

                      return ListView(
                        padding: EdgeInsets.fromLTRB(
                          20,
                          20,
                          20,
                          32 + _floatingNavClearance + bottomInset,
                        ),
                        children: [
                          Text(
                            settings.greeting,
                            style: theme.textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 20),
                          BalanceCard(
                            balance: homeData.globalBalance,
                            currencyCode: settings.defaultCurrencyCode,
                            subtitle: _balanceSubtitle(
                              homeData.accounts.length,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: ActivitySummaryCard(
                                  title: 'Income',
                                  amount: activitySummary.income,
                                  currencyCode: settings.defaultCurrencyCode,
                                  accentColor: AppColors.income,
                                  backgroundColor: AppColors.incomeSurface,
                                  subtitle: periodLabel,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ActivitySummaryCard(
                                  title: 'Expenses',
                                  amount: activitySummary.expenses,
                                  currencyCode: settings.defaultCurrencyCode,
                                  accentColor: AppColors.textPrimary,
                                  backgroundColor: AppColors.expenseSurface,
                                  subtitle: periodLabel,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          ActivitySummaryCard(
                            title: 'Net',
                            amount: activitySummary.netMovement,
                            currencyCode: settings.defaultCurrencyCode,
                            accentColor: activitySummary.netMovement >= 0
                                ? AppColors.income
                                : AppColors.dangerDark,
                            backgroundColor: Colors.white,
                            subtitle: 'For $periodLabel',
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
                                onTap: () => _addTransaction(homeData.accounts),
                                borderRadius: BorderRadius.circular(999),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                    vertical: 6,
                                  ),
                                  child: Icon(
                                    Icons.add,
                                    color: AppColors.brand,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          if (snapshot.connectionState ==
                                  ConnectionState.waiting &&
                              homeData.transactions.isEmpty &&
                              homeData.accounts.isEmpty)
                            const Center(child: CircularProgressIndicator())
                          else if (groupedTransactions.isEmpty)
                            _EmptyPeriodState(
                              hasAccounts: homeData.accounts.isNotEmpty,
                              periodLabel: periodLabel,
                            )
                          else
                            ...groupedTransactions.entries.map(
                              (entry) => TransactionGroup(
                                label: entry.key,
                                transactions: entry.value,
                                categoryNameFor: (transaction) =>
                                    transaction.type == TransactionType.transfer
                                    ? 'Transfer'
                                    : categoriesById[transaction.categoryId]
                                              ?.name ??
                                          'Unknown category',
                                categoryIconFor: (transaction) =>
                                    transaction.type == TransactionType.transfer
                                    ? Icons.swap_horiz_rounded
                                    : categoriesById[transaction.categoryId]
                                              ?.icon ??
                                          Icons.sell_outlined,
                                accountNameFor: (transaction) =>
                                    accountsById[transaction.accountId ??
                                            transaction.sourceAccountId]
                                        ?.name ??
                                    'Unknown account',
                                destinationAccountNameFor: (transaction) =>
                                    transaction.destinationAccountId == null
                                    ? null
                                    : accountsById[transaction
                                              .destinationAccountId]
                                          ?.name,
                                onTransactionTap: _openTransactionDetails,
                                onTransactionLongPressStart:
                                    _showTransactionActionMenu,
                              ),
                            ),
                          if (homeData.transactions.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Center(
                              child: TextButton(
                                onPressed: _openTransactionHistory,
                                child: const Text('View more'),
                              ),
                            ),
                          ],
                        ],
                      );
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Future<_HomePageData> _loadHomePageData() async {
    final results = await Future.wait<dynamic>([
      widget.repository.getTransactions(),
      widget.categoryRepository.getCategories(),
      widget.accountRepository.getAccounts(),
      widget.balanceOverviewService.getGlobalBalance(),
    ]);

    return _HomePageData(
      transactions: results[0] as List<TransactionItem>,
      categories: results[1] as List<CategoryItem>,
      accounts: results[2] as List<Account>,
      globalBalance: results[3] as double,
    );
  }

  _HomePeriod _currentMonthPeriod() {
    final now = DateTime.now();
    return _HomePeriod(
      start: DateTime(now.year, now.month),
      end: DateTime(now.year, now.month + 1),
    );
  }

  List<TransactionItem> _transactionsInPeriod({
    required List<TransactionItem> transactions,
    required _HomePeriod period,
  }) {
    return transactions
        .where((transaction) {
          return !transaction.date.isBefore(period.start) &&
              transaction.date.isBefore(period.end);
        })
        .toList(growable: false);
  }

  _HomeActivitySummary _buildActivitySummary(
    List<TransactionItem> transactions,
  ) {
    var income = 0.0;
    var expenses = 0.0;

    for (final transaction in transactions) {
      switch (transaction.type) {
        case TransactionType.income:
          income += transaction.amount;
          break;
        case TransactionType.expense:
          expenses += transaction.amount;
          break;
        case TransactionType.transfer:
          break;
      }
    }

    return _HomeActivitySummary(
      income: income,
      expenses: expenses,
      netMovement: income - expenses,
    );
  }

  String _balanceSubtitle(int accountCount) {
    if (accountCount == 0) {
      return 'Add an account to start tracking your balance.';
    }

    return 'Across $accountCount tracked account${accountCount == 1 ? '' : 's'}.';
  }

  Future<void> _openTransactionHistory() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (context) => TransactionHistoryPage(
          repository: widget.repository,
          categoryRepository: widget.categoryRepository,
          settingsRepository: widget.settingsRepository,
          accountRepository: widget.accountRepository,
        ),
      ),
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
}

class _HomePageData {
  const _HomePageData({
    required this.transactions,
    required this.categories,
    required this.accounts,
    required this.globalBalance,
  });

  const _HomePageData.empty()
    : transactions = const [],
      categories = const [],
      accounts = const [],
      globalBalance = 0;

  final List<TransactionItem> transactions;
  final List<CategoryItem> categories;
  final List<Account> accounts;
  final double globalBalance;
}

class _HomeActivitySummary {
  const _HomeActivitySummary({
    required this.income,
    required this.expenses,
    required this.netMovement,
  });

  final double income;
  final double expenses;
  final double netMovement;
}

class _HomePeriod {
  const _HomePeriod({required this.start, required this.end});

  final DateTime start;
  final DateTime end;
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
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Icon(
            Icons.receipt_long_outlined,
            color: AppColors.iconMuted,
            size: 32,
          ),
          const SizedBox(height: 16),
          Text(
            'No activity in $periodLabel',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          Text(
            hasAccounts
                ? 'Your overall balance still reflects all tracked accounts. Add transactions to build this period view.'
                : 'Create an account first, then add transactions to build your current-period view.',
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
