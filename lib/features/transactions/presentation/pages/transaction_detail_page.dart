import 'package:expense_tracker/core/theme/app_colors.dart';
import 'package:expense_tracker/core/utils/currency_formatter.dart';
import 'package:expense_tracker/features/accounts/data/account_repository.dart';
import 'package:expense_tracker/features/accounts/domain/models/account.dart';
import 'package:expense_tracker/features/categories/data/category_repository.dart';
import 'package:expense_tracker/features/categories/domain/models/category_item.dart';
import 'package:expense_tracker/features/categories/presentation/pages/category_detail_page.dart';
import 'package:expense_tracker/features/settings/data/settings_repository.dart';
import 'package:expense_tracker/features/transactions/data/transaction_repository.dart';
import 'package:expense_tracker/features/transactions/domain/models/transaction_item.dart';
import 'package:expense_tracker/features/transactions/presentation/pages/add_transaction_page.dart';
import 'package:flutter/material.dart';

class TransactionDetailPage extends StatefulWidget {
  const TransactionDetailPage({
    super.key,
    required this.transaction,
    required this.repository,
    required this.categoryRepository,
    required this.accountRepository,
    required this.settingsRepository,
  });

  final TransactionItem transaction;
  final TransactionRepository repository;
  final CategoryRepository categoryRepository;
  final AccountRepository accountRepository;
  final SettingsRepository settingsRepository;

  @override
  State<TransactionDetailPage> createState() => _TransactionDetailPageState();
}

class _TransactionDetailPageState extends State<TransactionDetailPage> {
  List<CategoryItem> _categories = const [];
  List<Account> _accounts = const [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final accounts = await widget.accountRepository.getAccounts();
    final categories = await widget.categoryRepository.getCategories();

    if (!mounted) {
      return;
    }

    setState(() {
      _accounts = accounts;
      _categories = categories;
    });
  }

  Future<void> _editTransaction() async {
    final didChange = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => AddTransactionPage(
          repository: widget.repository,
          categoryRepository: widget.categoryRepository,
          accountRepository: widget.accountRepository,
          settingsRepository: widget.settingsRepository,
          initialTransaction: widget.transaction,
        ),
      ),
    );

    if (didChange != true) {
      return;
    }

    if (!mounted) {
      return;
    }

    Navigator.of(context).pop(true);
  }

  Future<void> _deleteTransaction() async {
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

    await widget.repository.deleteTransaction(widget.transaction.id);

    if (!mounted) {
      return;
    }

    Navigator.of(context).pop(true);
  }

  Future<void> _openCategoryDetails(CategoryItem category) async {
    final shouldReload = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => CategoryDetailPage(
          category: category,
          categoryRepository: widget.categoryRepository,
          transactionRepository: widget.repository,
        ),
      ),
    );

    if (shouldReload == true) {
      await _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final transaction = widget.transaction;
    final category = _categories
        .where((item) => item.id == transaction.categoryId)
        .firstOrNull;
    final account = _accounts
        .where((item) => item.id == transaction.accountId)
        .firstOrNull;
    final sourceAccount = _accounts
        .where((item) => item.id == transaction.sourceAccountId)
        .firstOrNull;
    final destinationAccount = _accounts
        .where((item) => item.id == transaction.destinationAccountId)
        .firstOrNull;
    final isIncome = transaction.type == TransactionType.income;
    final isTransfer = transaction.type == TransactionType.transfer;
    final amountColor = isTransfer
        ? AppColors.brandDark
        : isIncome
        ? AppColors.income
        : AppColors.textPrimary;
    final amountPrefix = isTransfer ? '' : (isIncome ? '+' : '-');
    final localizations = MaterialLocalizations.of(context);
    final fullDate = localizations.formatFullDate(transaction.date);
    final time = localizations.formatTimeOfDay(
      TimeOfDay.fromDateTime(transaction.date),
    );
    final shortDate = localizations.formatShortDate(transaction.date);
    final categoryName = category?.name ?? 'Unknown category';
    final accountName = account?.name ?? 'Unknown account';
    final sourceAccountName = sourceAccount?.name ?? 'Unknown account';
    final destinationAccountName =
        destinationAccount?.name ?? 'Unknown account';
    final categoryIcon = isTransfer
        ? Icons.swap_horiz_rounded
        : category?.icon ?? Icons.sell_outlined;
    final defaultCurrencyCode = widget.settingsRepository
        .getSettings()
        .defaultCurrencyCode;
    final enteredCurrencyCode =
        transaction.foreignCurrencyCode ?? transaction.currencyCode;
    final enteredAmount = transaction.foreignAmount ?? transaction.amount;
    final iconBackground = isTransfer
        ? AppColors.background
        : isIncome
        ? AppColors.incomeSurface
        : AppColors.expenseSurface;
    final iconColor = isTransfer
        ? AppColors.brandDark
        : isIncome
        ? AppColors.income
        : AppColors.iconMuted;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        title: const Text('Transaction details'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(32),
                gradient: const LinearGradient(
                  colors: [Color(0xFFFFFFFF), Color(0xFFF7FBF9)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border.all(color: AppColors.border),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x12000000),
                    blurRadius: 28,
                    offset: Offset(0, 14),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: iconBackground,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Icon(categoryIcon, color: iconColor, size: 28),
                      ),
                      const Spacer(),
                      _StatusBadge(
                        label: isTransfer
                            ? 'Transfer'
                            : isIncome
                            ? 'Income'
                            : 'Expense',
                        textColor: iconColor,
                        backgroundColor: iconBackground,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text(
                    transaction.title,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '$amountPrefix${formatCurrency(transaction.amount, currencyCode: transaction.currencyCode)}',
                    style: theme.textTheme.displaySmall?.copyWith(
                      color: amountColor,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.6,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '$shortDate at $time',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            _SectionCard(
              title: 'Overview',
              child: Column(
                children: [
                  _DetailTile(
                    icon: Icons.account_balance_wallet_outlined,
                    label: isTransfer ? 'From account' : 'Account',
                    value: isTransfer ? sourceAccountName : accountName,
                  ),
                  const SizedBox(height: 12),
                  if (isTransfer) ...[
                    _DetailTile(
                      icon: Icons.account_balance_wallet_outlined,
                      label: 'To account',
                      value: destinationAccountName,
                    ),
                    const SizedBox(height: 12),
                  ] else ...[
                    _DetailTile(
                      icon: Icons.category_outlined,
                      label: 'Category',
                      value: categoryName,
                      onTap: category == null
                          ? null
                          : () => _openCategoryDetails(category),
                    ),
                    const SizedBox(height: 12),
                  ],
                  _DetailTile(
                    icon: Icons.euro_symbol_rounded,
                    label: transaction.hasForeignCurrency
                        ? 'Saved amount'
                        : 'Amount',
                    value: formatCurrency(
                      transaction.amount,
                      currencyCode: transaction.currencyCode,
                    ),
                  ),
                  if (transaction.hasForeignCurrency && !isTransfer) ...[
                    const SizedBox(height: 12),
                    _DetailTile(
                      icon: Icons.currency_exchange_rounded,
                      label: 'Entered amount',
                      value: formatCurrency(
                        enteredAmount,
                        currencyCode: enteredCurrencyCode,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _DetailTile(
                      icon: Icons.sync_alt_rounded,
                      label: 'Exchange rate',
                      value:
                          '1 ${enteredCurrencyCode.toUpperCase()} = ${formatCurrency(transaction.exchangeRate ?? 0, currencyCode: defaultCurrencyCode)}',
                    ),
                  ],
                  const SizedBox(height: 12),
                  _DetailTile(
                    icon: Icons.swap_vert_rounded,
                    label: 'Type',
                    value: isTransfer
                        ? 'Transfer'
                        : (isIncome ? 'Income' : 'Expense'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _SectionCard(
              title: 'When it happened',
              child: Column(
                children: [
                  _DetailTile(
                    icon: Icons.calendar_today_outlined,
                    label: 'Date',
                    value: fullDate,
                  ),
                  const SizedBox(height: 12),
                  _DetailTile(
                    icon: Icons.schedule_rounded,
                    label: 'Time',
                    value: time,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        decoration: const BoxDecoration(
          color: Color(0xCCF4F7F5),
          border: Border(top: BorderSide(color: Color(0xFFE2E8E4))),
        ),
        child: SafeArea(
          top: false,
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _deleteTransaction,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(56),
                    foregroundColor: AppColors.dangerDark,
                    side: const BorderSide(color: Color(0xFFF2B8B5)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(22),
                    ),
                  ),
                  child: const Text('Delete'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: FilledButton(
                  onPressed: _editTransaction,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.brand,
                    foregroundColor: AppColors.white,
                    minimumSize: const Size.fromHeight(56),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(22),
                    ),
                  ),
                  child: const Text('Edit transaction'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _DetailTile extends StatelessWidget {
  const _DetailTile({
    required this.icon,
    required this.label,
    required this.value,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final content = Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Icon(icon, size: 18, color: AppColors.brandDark),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        if (onTap != null) ...[
          const SizedBox(width: 12),
          Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
        ],
      ],
    );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: const Color(0xFFF9FBFA),
            borderRadius: BorderRadius.circular(20),
          ),
          child: content,
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({
    required this.label,
    required this.textColor,
    required this.backgroundColor,
  });

  final String label;
  final Color textColor;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelLarge?.copyWith(
          color: textColor,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
