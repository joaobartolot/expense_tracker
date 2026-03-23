import 'package:expense_tracker/core/theme/app_colors.dart';
import 'package:expense_tracker/core/widgets/app_text_input.dart';
import 'package:expense_tracker/core/widgets/custom_dropdown_selector.dart';
import 'package:expense_tracker/core/widgets/segmented_toggle_field.dart';
import 'package:expense_tracker/core/logging/scoped_log_printer.dart';
import 'package:expense_tracker/features/categories/data/category_repository.dart';
import 'package:expense_tracker/features/categories/domain/models/category_item.dart';
import 'package:expense_tracker/features/transactions/data/transaction_repository.dart';
import 'package:expense_tracker/features/transactions/domain/models/transaction_item.dart';
import 'package:flutter/material.dart';
import 'package:logger/logger.dart';

final _logger = Logger(printer: ScopedLogPrinter('add_transaction_page'));

class AddTransactionPage extends StatefulWidget {
  const AddTransactionPage({
    super.key,
    required this.repository,
    required this.categoryRepository,
    this.initialTransaction,
  });

  final TransactionRepository repository;
  final CategoryRepository categoryRepository;
  final TransactionItem? initialTransaction;

  @override
  State<AddTransactionPage> createState() => _AddTransactionPageState();
}

class _AddTransactionPageState extends State<AddTransactionPage> {
  late final TextEditingController _nameController;
  late final TextEditingController _amountController;

  TransactionType _type = TransactionType.expense;
  List<CategoryItem> _categories = const [];
  CategoryItem? _selectedCategory;
  bool _didTrySubmit = false;
  bool _isSaving = false;
  bool _isFormattingAmount = false;

  bool get _isEditing => widget.initialTransaction != null;

  @override
  void initState() {
    super.initState();
    final initialTransaction = widget.initialTransaction;
    _nameController = TextEditingController(
      text: initialTransaction?.title ?? '',
    );
    _amountController = TextEditingController(
      text: (initialTransaction?.amount ?? 0).toStringAsFixed(2),
    );
    _type = initialTransaction?.type ?? TransactionType.expense;
    _nameController.addListener(_handleFieldChange);
    _amountController.addListener(_formatAmountInput);
    _loadCategories();
  }

  @override
  void dispose() {
    _nameController
      ..removeListener(_handleFieldChange)
      ..dispose();
    _amountController
      ..removeListener(_formatAmountInput)
      ..dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    final categories = await widget.categoryRepository.getCategories();

    if (!mounted) {
      return;
    }

    setState(() {
      _categories = categories;
      _selectedCategory = _resolveSelectedCategory(categories);
    });
  }

  CategoryItem? _resolveSelectedCategory(List<CategoryItem> categories) {
    final selectedCategory =
        _selectedCategory ?? _categoryFromInitialTransaction(categories);
    final filteredCategories = _availableCategoriesFrom(categories);

    if (selectedCategory == null) {
      return null;
    }

    for (final category in filteredCategories) {
      if (category.id == selectedCategory.id) {
        return category;
      }
    }

    return null;
  }

  CategoryItem? _categoryFromInitialTransaction(List<CategoryItem> categories) {
    final initialTransaction = widget.initialTransaction;
    if (initialTransaction == null) {
      return null;
    }

    for (final category in categories) {
      if (category.id == initialTransaction.categoryId) {
        return category;
      }
    }

    return null;
  }

  void _handleFieldChange() {
    if (!_didTrySubmit) {
      return;
    }

    setState(() {});
  }

  void _formatAmountInput() {
    if (_isFormattingAmount) {
      return;
    }

    final digits = _amountController.text.replaceAll(RegExp(r'[^0-9]'), '');
    final normalizedDigits = digits.isEmpty ? '0' : digits;
    final amount = (int.tryParse(normalizedDigits) ?? 0) / 100;
    final formatted = amount.toStringAsFixed(2);

    if (_amountController.text == formatted) {
      return;
    }

    _isFormattingAmount = true;
    _amountController.value = TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
    _isFormattingAmount = false;

    if (_didTrySubmit && mounted) {
      setState(() {});
    }
  }

  List<CategoryItem> get _availableCategories =>
      _availableCategoriesFrom(_categories);

  List<CategoryItem> _availableCategoriesFrom(List<CategoryItem> categories) {
    final expectedType = switch (_type) {
      TransactionType.income => CategoryType.income,
      TransactionType.expense => CategoryType.expense,
    };

    return categories
        .where((category) => category.type == expectedType)
        .toList(growable: false);
  }

  double get _amountValue => double.tryParse(_amountController.text) ?? 0;

  String? get _nameError {
    if (!_didTrySubmit) {
      return null;
    }

    if (_nameController.text.trim().isEmpty) {
      return 'Please enter a name for the transaction.';
    }

    return null;
  }

  String? get _amountError {
    if (!_didTrySubmit) {
      return null;
    }

    if (_amountValue <= 0) {
      return 'Please enter an amount greater than 0.00.';
    }

    return null;
  }

  String? get _categoryError {
    if (!_didTrySubmit) {
      return null;
    }

    if (_selectedCategory == null) {
      return 'Please choose a category.';
    }

    return null;
  }

  Future<void> _saveTransaction() async {
    FocusScope.of(context).unfocus();

    setState(() {
      _didTrySubmit = true;
    });

    if (_nameError != null || _amountError != null || _categoryError != null) {
      return;
    }

    final selectedCategory = _selectedCategory;
    if (selectedCategory == null) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    TransactionItem? transaction;

    try {
      final initialTransaction = widget.initialTransaction;
      transaction = TransactionItem(
        id: initialTransaction?.id ?? widget.repository.createTransactionId(),
        title: _nameController.text.trim(),
        categoryId: selectedCategory.id,
        amount: _amountValue,
        date: initialTransaction?.date ?? DateTime.now(),
        type: _type,
      );

      if (_isEditing) {
        await widget.repository.updateTransaction(transaction);
      } else {
        await widget.repository.addTransaction(transaction);
      }
    } catch (error, stackTrace) {
      _logger.e(
        'Failed to save transaction ${transaction?.id ?? 'unknown'}.',
        error: error,
        stackTrace: stackTrace,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _isSaving = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not save the transaction. Please try again.'),
        ),
      );
      return;
    }

    if (!mounted) {
      return;
    }

    Navigator.of(context).pop(true);
  }

  void _updateType(TransactionType type) {
    if (_type == type) {
      return;
    }

    setState(() {
      _type = type;
      _selectedCategory = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final availableCategories = _availableCategories;
    final categoryItems = availableCategories
        .map(
          (category) => DropdownSelectorItem<CategoryItem>(
            value: category,
            label: category.name,
            subtitle: category.description,
            icon: category.icon,
          ),
        )
        .toList(growable: false);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        title: Text(_isEditing ? 'Edit transaction' : 'Add transaction'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(32),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _isEditing ? 'Update this entry' : 'Create a new entry',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _isEditing
                          ? 'Adjust the details below to keep this transaction accurate.'
                          : 'Pick the type, give it a clear name, and assign it to the right category.',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 24),
                    SegmentedToggleField<TransactionType>(
                      label: 'Type',
                      value: _type,
                      items: const [
                        SegmentedToggleItem(
                          value: TransactionType.expense,
                          label: 'Expense',
                          icon: Icons.arrow_upward_rounded,
                        ),
                        SegmentedToggleItem(
                          value: TransactionType.income,
                          label: 'Income',
                          icon: Icons.arrow_downward_rounded,
                        ),
                      ],
                      onChanged: _updateType,
                    ),
                    const SizedBox(height: 20),
                    AppTextInput(
                      label: 'Name',
                      controller: _nameController,
                      hintText: 'Transaction name',
                      textCapitalization: TextCapitalization.words,
                      errorText: _nameError,
                    ),
                    const SizedBox(height: 16),
                    AppTextInput(
                      label: 'Amount',
                      controller: _amountController,
                      keyboardType: TextInputType.number,
                      hintText: '0.00',
                      errorText: _amountError,
                      prefixText: '\$ ',
                    ),
                    const SizedBox(height: 16),
                    CustomDropdownSelector<CategoryItem>(
                      label: 'Category',
                      hintText: availableCategories.isEmpty
                          ? 'No categories available'
                          : 'Choose a category',
                      value: _selectedCategory,
                      items: categoryItems,
                      errorText: _categoryError,
                      onChanged: (category) {
                        setState(() {
                          _selectedCategory = category;
                        });
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _isSaving ? null : _saveTransaction,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.brand,
                    foregroundColor: AppColors.white,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                  child: Text(
                    _isSaving
                        ? (_isEditing ? 'Saving...' : 'Creating...')
                        : (_isEditing ? 'Save changes' : 'Save transaction'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
