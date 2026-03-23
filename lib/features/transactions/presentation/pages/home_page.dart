import 'package:expense_tracker/core/theme/app_colors.dart';
import 'package:expense_tracker/core/utils/date_label_formatter.dart';
import 'package:expense_tracker/features/categories/data/category_repository.dart';
import 'package:expense_tracker/features/categories/domain/models/category_item.dart';
import 'package:expense_tracker/features/settings/data/settings_repository.dart';
import 'package:expense_tracker/features/transactions/data/transaction_repository.dart';
import 'package:expense_tracker/features/transactions/domain/models/transaction_item.dart';
import 'package:expense_tracker/features/transactions/presentation/pages/add_transaction_page.dart';
import 'package:expense_tracker/features/transactions/presentation/pages/transaction_detail_page.dart';
import 'package:expense_tracker/features/transactions/presentation/widgets/balance_card.dart';
import 'package:expense_tracker/features/transactions/presentation/widgets/transaction_group.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

enum _TransactionListAction { edit, delete }

class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    required this.repository,
    required this.categoryRepository,
    required this.settingsRepository,
  });

  final TransactionRepository repository;
  final CategoryRepository categoryRepository;
  final SettingsRepository settingsRepository;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<TransactionItem> _transactions = const [];
  List<CategoryItem> _categories = const [];

  @override
  void initState() {
    super.initState();
    _loadTransactions();
  }

  Future<void> _loadTransactions() async {
    final transactions = await widget.repository.getTransactions();
    final categories = await widget.categoryRepository.getCategories();

    if (!mounted) {
      return;
    }

    setState(() {
      _transactions = transactions;
      _categories = categories;
    });
  }

  Future<void> _addTransaction() async {
    final shouldReload = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => AddTransactionPage(
          repository: widget.repository,
          categoryRepository: widget.categoryRepository,
        ),
      ),
    );

    if (shouldReload == true) {
      await _loadTransactions();
    }
  }

  Future<void> _openTransactionDetails(TransactionItem transaction) async {
    final shouldReload = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => TransactionDetailPage(
          transaction: transaction,
          repository: widget.repository,
          categoryRepository: widget.categoryRepository,
        ),
      ),
    );

    if (shouldReload == true) {
      await _loadTransactions();
    }
  }

  Future<void> _editTransaction(TransactionItem transaction) async {
    final shouldReload = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => AddTransactionPage(
          repository: widget.repository,
          categoryRepository: widget.categoryRepository,
          initialTransaction: transaction,
        ),
      ),
    );

    if (shouldReload == true) {
      await _loadTransactions();
    }
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
    await _loadTransactions();
  }

  Future<void> _showTransactionActionMenu(
    TransactionItem transaction,
    LongPressStartDetails details,
  ) async {
    final overlay =
        Overlay.of(context).context.findRenderObject()! as RenderBox;
    const horizontalPadding = 12.0;
    const verticalPadding = 12.0;
    const menuWidth = 152.0;
    const menuHeight = 88.0;
    const menuOffset = 8.0;

    final fingerPosition = details.globalPosition;
    final maxLeft = overlay.size.width - menuWidth - horizontalPadding;
    final maxTop = overlay.size.height - menuHeight - verticalPadding;

    final left = (fingerPosition.dx - (menuWidth / 2))
        .clamp(
          horizontalPadding,
          maxLeft < horizontalPadding ? horizontalPadding : maxLeft,
        )
        .toDouble();

    final prefersBelow =
        fingerPosition.dy + menuHeight + menuOffset <=
        overlay.size.height - verticalPadding;
    final rawTop = prefersBelow
        ? fingerPosition.dy + menuOffset
        : fingerPosition.dy - menuHeight - menuOffset;
    final top = rawTop
        .clamp(
          verticalPadding,
          maxTop < verticalPadding ? verticalPadding : maxTop,
        )
        .toDouble();

    final selectedAction = await showMenu<_TransactionListAction>(
      context: context,
      color: AppColors.surface,
      elevation: 10,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      position: RelativeRect.fromLTRB(
        left,
        top,
        overlay.size.width - left - menuWidth,
        overlay.size.height - top - menuHeight,
      ),
      items: [
        PopupMenuItem(
          value: _TransactionListAction.edit,
          height: 40,
          child: Row(
            children: [
              Icon(Icons.edit_outlined, size: 18, color: AppColors.textPrimary),
              SizedBox(width: 10),
              Text('Edit'),
            ],
          ),
        ),
        PopupMenuItem(
          value: _TransactionListAction.delete,
          height: 40,
          child: Row(
            children: [
              Icon(Icons.delete_outline, size: 18, color: AppColors.danger),
              SizedBox(width: 10),
              Text('Delete', style: TextStyle(color: AppColors.dangerDark)),
            ],
          ),
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
    final groupedTransactions = _groupTransactions(_transactions);
    final categoriesById = {
      for (final category in _categories) category.id: category,
    };
    final balance = _transactions.fold<double>(
      0,
      (sum, transaction) => sum + transaction.signedAmount,
    );

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        children: [
          ValueListenableBuilder<Box<dynamic>>(
            valueListenable: widget.settingsRepository.listenable(),
            builder: (context, value, child) {
              final greeting = widget.settingsRepository.getSettings().greeting;

              return Text(
                greeting,
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              );
            },
          ),
          const SizedBox(height: 20),
          BalanceCard(balance: balance),
          const SizedBox(height: 28),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Transactions',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              InkWell(
                onTap: _addTransaction,
                borderRadius: BorderRadius.circular(999),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 6,
                  ),
                  child: Icon(Icons.add, color: AppColors.brand),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...groupedTransactions.entries.map(
            (entry) => TransactionGroup(
              label: entry.key,
              transactions: entry.value,
              categoryNameFor: (transaction) =>
                  categoriesById[transaction.categoryId]?.name ??
                  'Unknown category',
              categoryIconFor: (transaction) =>
                  categoriesById[transaction.categoryId]?.icon ??
                  Icons.sell_outlined,
              onTransactionTap: _openTransactionDetails,
              onTransactionLongPressStart: _showTransactionActionMenu,
            ),
          ),
        ],
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
