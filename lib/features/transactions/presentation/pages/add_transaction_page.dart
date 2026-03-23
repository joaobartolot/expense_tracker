import 'package:expense_tracker/core/logging/scoped_log_printer.dart';
import 'package:expense_tracker/core/theme/app_colors.dart';
import 'package:expense_tracker/core/utils/currency_formatter.dart';
import 'package:expense_tracker/core/utils/supported_currencies.dart';
import 'package:expense_tracker/core/widgets/app_text_input.dart';
import 'package:expense_tracker/core/widgets/custom_dropdown_selector.dart';
import 'package:expense_tracker/core/widgets/primary_action_button.dart';
import 'package:expense_tracker/core/widgets/segmented_toggle_field.dart';
import 'package:expense_tracker/features/accounts/data/account_repository.dart';
import 'package:expense_tracker/features/accounts/domain/models/account.dart';
import 'package:expense_tracker/features/categories/data/category_repository.dart';
import 'package:expense_tracker/features/categories/domain/models/category_item.dart';
import 'package:expense_tracker/features/settings/data/settings_repository.dart';
import 'package:expense_tracker/features/transactions/data/exchange_rate_service.dart';
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
    required this.accountRepository,
    required this.settingsRepository,
    this.exchangeRateService = const ExchangeRateService(),
    this.initialTransaction,
  });

  final TransactionRepository repository;
  final CategoryRepository categoryRepository;
  final AccountRepository accountRepository;
  final SettingsRepository settingsRepository;
  final ExchangeRateService exchangeRateService;
  final TransactionItem? initialTransaction;

  @override
  State<AddTransactionPage> createState() => _AddTransactionPageState();
}

class _AddTransactionPageState extends State<AddTransactionPage> {
  late final TextEditingController _nameController;
  late final TextEditingController _amountController;

  TransactionType _type = TransactionType.expense;
  List<Account> _accounts = const [];
  List<CategoryItem> _categories = const [];
  Account? _selectedAccount;
  CategoryItem? _selectedCategory;
  String _selectedEntryCurrencyCode = 'EUR';
  bool _showsAdvancedFields = false;
  bool _didTrySubmit = false;
  bool _isSaving = false;
  bool _isFormattingAmount = false;
  bool _isFetchingExchangeRate = false;
  double? _exchangeRateValue;
  String? _exchangeRateErrorMessage;
  int _exchangeRateRequestToken = 0;

  bool get _isEditing => widget.initialTransaction != null;

  String get _defaultCurrencyCode =>
      widget.settingsRepository.getSettings().defaultCurrencyCode;

  DateTime get _conversionDate =>
      widget.initialTransaction?.date ?? DateTime.now();

  @override
  void initState() {
    super.initState();
    final initialTransaction = widget.initialTransaction;
    final hasForeignCurrency = initialTransaction?.hasForeignCurrency ?? false;
    _showsAdvancedFields = hasForeignCurrency;
    _selectedEntryCurrencyCode =
        initialTransaction?.foreignCurrencyCode ??
        initialTransaction?.currencyCode ??
        _defaultCurrencyCode;
    _exchangeRateValue = initialTransaction?.exchangeRate ?? 1;
    _nameController = TextEditingController(
      text: initialTransaction?.title ?? '',
    );
    _amountController = TextEditingController(
      text:
          ((hasForeignCurrency
                      ? initialTransaction?.foreignAmount
                      : initialTransaction?.amount) ??
                  0)
              .toStringAsFixed(2),
    );
    _type = initialTransaction?.type ?? TransactionType.expense;
    _nameController.addListener(_handleFieldChange);
    _amountController.addListener(_formatAmountInput);
    _loadData();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      _syncExchangeRateIfNeeded();
    });
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

  Future<void> _loadData() async {
    final accounts = await widget.accountRepository.getAccounts();
    final categories = await widget.categoryRepository.getCategories();

    if (!mounted) {
      return;
    }

    setState(() {
      _accounts = accounts;
      _categories = categories;
      _selectedAccount = _resolveSelectedAccount(accounts);
      _selectedCategory = _resolveSelectedCategory(categories);
    });
  }

  Account? _resolveSelectedAccount(List<Account> accounts) {
    final selectedAccount =
        _selectedAccount ?? _accountFromInitialTransaction(accounts);

    if (selectedAccount != null) {
      for (final account in accounts) {
        if (account.id == selectedAccount.id) {
          return account;
        }
      }
    }

    if (accounts.length == 1) {
      return accounts.first;
    }

    return null;
  }

  Account? _accountFromInitialTransaction(List<Account> accounts) {
    final initialTransaction = widget.initialTransaction;
    if (initialTransaction == null) {
      return null;
    }

    for (final account in accounts) {
      if (account.id == initialTransaction.accountId) {
        return account;
      }
    }

    return null;
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

  bool get _usesForeignCurrency =>
      _showsAdvancedFields &&
      _selectedEntryCurrencyCode != _defaultCurrencyCode;

  double get _enteredAmountValue =>
      double.tryParse(_amountController.text) ?? 0;

  double get _convertedAmountValue => _usesForeignCurrency
      ? _enteredAmountValue * (_exchangeRateValue ?? 0)
      : _enteredAmountValue;

  String get _amountPrefix =>
      '${currencySymbolFor(_showsAdvancedFields ? _selectedEntryCurrencyCode : _defaultCurrencyCode)} ';

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

    if (_enteredAmountValue <= 0) {
      return 'Please enter an amount greater than 0.00.';
    }

    return null;
  }

  String? get _exchangeRateError {
    if (!_usesForeignCurrency) {
      return null;
    }

    if (_exchangeRateErrorMessage case final message?) {
      return message;
    }

    if (_exchangeRateValue == null || _exchangeRateValue! <= 0) {
      return _didTrySubmit
          ? 'Could not load the exchange rate for this currency.'
          : null;
    }

    return null;
  }

  String? get _accountError {
    if (!_didTrySubmit) {
      return null;
    }

    if (_accounts.isEmpty) {
      return 'Create an account before adding a transaction.';
    }

    if (_selectedAccount == null) {
      return 'Please choose an account.';
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

  Future<void> _syncExchangeRateIfNeeded() async {
    final requestToken = ++_exchangeRateRequestToken;

    if (!_usesForeignCurrency) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isFetchingExchangeRate = false;
        _exchangeRateValue = 1;
        _exchangeRateErrorMessage = null;
      });
      return;
    }

    setState(() {
      _isFetchingExchangeRate = true;
      _exchangeRateErrorMessage = null;
    });

    try {
      final rate = await widget.exchangeRateService.fetchExchangeRate(
        fromCurrencyCode: _selectedEntryCurrencyCode,
        toCurrencyCode: _defaultCurrencyCode,
        date: _conversionDate,
      );

      if (!mounted || requestToken != _exchangeRateRequestToken) {
        return;
      }

      setState(() {
        _isFetchingExchangeRate = false;
        _exchangeRateValue = rate;
      });
    } on ExchangeRateLookupException catch (error) {
      if (!mounted || requestToken != _exchangeRateRequestToken) {
        return;
      }

      setState(() {
        _isFetchingExchangeRate = false;
        _exchangeRateValue = null;
        _exchangeRateErrorMessage = error.message;
      });
    } catch (error, stackTrace) {
      _logger.e(
        'Failed to fetch exchange rate.',
        error: error,
        stackTrace: stackTrace,
      );

      if (!mounted || requestToken != _exchangeRateRequestToken) {
        return;
      }

      setState(() {
        _isFetchingExchangeRate = false;
        _exchangeRateValue = null;
        _exchangeRateErrorMessage = 'Could not fetch the exchange rate.';
      });
    }
  }

  void _setAdvancedFieldsVisible(bool value) {
    if (_showsAdvancedFields == value) {
      return;
    }

    setState(() {
      _showsAdvancedFields = value;
      if (!value) {
        _selectedEntryCurrencyCode = _defaultCurrencyCode;
        _exchangeRateValue = 1;
        _exchangeRateErrorMessage = null;
      }
    });

    _syncExchangeRateIfNeeded();
  }

  void _updateEntryCurrency(String value) {
    if (_selectedEntryCurrencyCode == value) {
      return;
    }

    setState(() {
      _selectedEntryCurrencyCode = value;
      _exchangeRateValue = value == _defaultCurrencyCode ? 1 : null;
      _exchangeRateErrorMessage = null;
    });

    _syncExchangeRateIfNeeded();
  }

  Future<void> _saveTransaction() async {
    FocusScope.of(context).unfocus();

    setState(() {
      _didTrySubmit = true;
    });

    if (_nameError != null ||
        _amountError != null ||
        _exchangeRateError != null ||
        _isFetchingExchangeRate ||
        _accountError != null ||
        _categoryError != null) {
      return;
    }

    final selectedAccount = _selectedAccount;
    final selectedCategory = _selectedCategory;
    if (selectedAccount == null || selectedCategory == null) {
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
        accountId: selectedAccount.id,
        amount: _convertedAmountValue,
        currencyCode: _defaultCurrencyCode,
        date: initialTransaction?.date ?? DateTime.now(),
        type: _type,
        foreignAmount: _usesForeignCurrency ? _enteredAmountValue : null,
        foreignCurrencyCode: _usesForeignCurrency
            ? _selectedEntryCurrencyCode
            : null,
        exchangeRate: _usesForeignCurrency ? _exchangeRateValue : null,
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
    final showAccountSelector = _accounts.length > 1;
    final accountItems = _accounts
        .map(
          (account) => DropdownSelectorItem<Account>(
            value: account,
            label: account.name,
            subtitle: account.typeLabel,
            icon: account.icon,
          ),
        )
        .toList(growable: false);
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
    final currencyItems = supportedCurrencies
        .map(
          (currency) => DropdownSelectorItem<String>(
            value: currency.code,
            label: '${currency.code} · ${currency.name}',
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
                    const SizedBox(height: 24),
                    if (_accounts.isEmpty) ...[
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: AppColors.expenseSurface,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.account_balance_wallet_outlined,
                              color: AppColors.textPrimary,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'You need at least one account before you can register a transaction.',
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
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
                    if (showAccountSelector) ...[
                      CustomDropdownSelector<Account>(
                        label: 'Account',
                        hintText: 'Choose an account',
                        value: _selectedAccount,
                        items: accountItems,
                        errorText: _accountError,
                        onChanged: (account) {
                          setState(() {
                            _selectedAccount = account;
                          });
                        },
                      ),
                      const SizedBox(height: 16),
                    ] else if (_accounts.length == 1) ...[
                      _SingleAccountBanner(account: _accounts.first),
                      const SizedBox(height: 16),
                    ],
                    AppTextInput(
                      label: 'Amount',
                      controller: _amountController,
                      keyboardType: TextInputType.number,
                      hintText: '0.00',
                      errorText: _amountError,
                      prefixText: _amountPrefix,
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
                    const SizedBox(height: 16),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: OutlinedButton.icon(
                        onPressed: () =>
                            _setAdvancedFieldsVisible(!_showsAdvancedFields),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.textPrimary,
                          side: BorderSide(color: AppColors.border),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 14,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                        icon: Icon(
                          _showsAdvancedFields
                              ? Icons.tune_rounded
                              : Icons.tune_outlined,
                        ),
                        label: Text(
                          _showsAdvancedFields ? 'Hide advanced' : 'Advanced',
                        ),
                      ),
                    ),
                    if (_showsAdvancedFields) ...[
                      const SizedBox(height: 16),
                      _AdvancedCurrencySection(
                        entryCurrencyCode: _selectedEntryCurrencyCode,
                        defaultCurrencyCode: _defaultCurrencyCode,
                        currencyItems: currencyItems,
                        convertedAmount: _convertedAmountValue,
                        enteredAmount: _enteredAmountValue,
                        isFetchingExchangeRate: _isFetchingExchangeRate,
                        exchangeRate: _exchangeRateValue,
                        exchangeRateError: _exchangeRateError,
                        onCurrencyChanged: _updateEntryCurrency,
                        onRetryExchangeRate: _syncExchangeRateIfNeeded,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              PrimaryActionButton(
                label: _isEditing ? 'Save changes' : 'Save transaction',
                busyLabel: _isEditing ? 'Saving...' : 'Creating...',
                isBusy: _isSaving,
                onPressed: _accounts.isEmpty || _isFetchingExchangeRate
                    ? null
                    : _saveTransaction,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SingleAccountBanner extends StatelessWidget {
  const _SingleAccountBanner({required this.account});

  final Account account;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(account.icon, color: AppColors.iconMuted, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Account',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  account.name,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AdvancedCurrencySection extends StatelessWidget {
  const _AdvancedCurrencySection({
    required this.entryCurrencyCode,
    required this.defaultCurrencyCode,
    required this.currencyItems,
    required this.convertedAmount,
    required this.enteredAmount,
    required this.isFetchingExchangeRate,
    required this.exchangeRate,
    required this.exchangeRateError,
    required this.onCurrencyChanged,
    required this.onRetryExchangeRate,
  });

  final String entryCurrencyCode;
  final String defaultCurrencyCode;
  final List<DropdownSelectorItem<String>> currencyItems;
  final double convertedAmount;
  final double enteredAmount;
  final bool isFetchingExchangeRate;
  final double? exchangeRate;
  final String? exchangeRateError;
  final ValueChanged<String> onCurrencyChanged;
  final Future<void> Function() onRetryExchangeRate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final usesForeignCurrency = entryCurrencyCode != defaultCurrencyCode;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Advanced currency',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Use a different entry currency without changing your default currency.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          CustomDropdownSelector<String>(
            label: 'Entry currency',
            hintText: 'Choose a currency',
            items: currencyItems,
            value: entryCurrencyCode,
            onChanged: onCurrencyChanged,
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Saved in default currency',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 6),
                if (isFetchingExchangeRate) ...[
                  Row(
                    children: [
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Fetching the latest rate for this currency pair...',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ] else if (usesForeignCurrency &&
                    exchangeRateError != null) ...[
                  Text(
                    exchangeRateError!,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppColors.dangerDark,
                    ),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton(
                    onPressed: onRetryExchangeRate,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textPrimary,
                      side: BorderSide(color: AppColors.border),
                    ),
                    child: const Text('Retry rate lookup'),
                  ),
                ] else ...[
                  Text(
                    formatCurrency(
                      convertedAmount,
                      currencyCode: defaultCurrencyCode,
                    ),
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (usesForeignCurrency) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Entered as ${formatCurrency(enteredAmount, currencyCode: entryCurrencyCode)}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    if (exchangeRate != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Rate: 1 ${entryCurrencyCode.toUpperCase()} = ${formatCurrency(exchangeRate!, currencyCode: defaultCurrencyCode)}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ] else ...[
                    const SizedBox(height: 6),
                    Text(
                      'Entry and saved currency are the same.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
