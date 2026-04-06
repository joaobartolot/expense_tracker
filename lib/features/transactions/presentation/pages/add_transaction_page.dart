import 'dart:async';

import 'package:expense_tracker/app/state/app_state_provider.dart';
import 'package:expense_tracker/core/logging/scoped_log_printer.dart';
import 'package:expense_tracker/core/theme/app_colors.dart';
import 'package:expense_tracker/core/utils/currency_formatter.dart';
import 'package:expense_tracker/core/utils/supported_currencies.dart';
import 'package:expense_tracker/core/widgets/app_text_input.dart';
import 'package:expense_tracker/core/widgets/custom_dropdown_selector.dart';
import 'package:expense_tracker/core/widgets/primary_action_button.dart';
import 'package:expense_tracker/core/widgets/segmented_toggle_field.dart';
import 'package:expense_tracker/features/accounts/domain/models/account.dart';
import 'package:expense_tracker/features/categories/domain/models/category_item.dart';
import 'package:expense_tracker/features/transactions/data/exchange_rate_service.dart';
import 'package:expense_tracker/features/transactions/domain/models/transaction_item.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';

final _logger = Logger(printer: ScopedLogPrinter('add_transaction_page'));

class AddTransactionPage extends ConsumerStatefulWidget {
  const AddTransactionPage({
    super.key,
    this.exchangeRateService = const ExchangeRateService(),
    this.initialTransaction,
    this.initialCreditCardAccount,
    this.startAsCreditCardPayment = false,
  });

  const AddTransactionPage.creditCardPayment({
    super.key,
    this.exchangeRateService = const ExchangeRateService(),
    this.initialTransaction,
    required Account creditCardAccount,
  }) : initialCreditCardAccount = creditCardAccount,
       startAsCreditCardPayment = true;

  final ExchangeRateService exchangeRateService;
  final TransactionItem? initialTransaction;
  final Account? initialCreditCardAccount;
  final bool startAsCreditCardPayment;

  @override
  ConsumerState<AddTransactionPage> createState() => _AddTransactionPageState();
}

class _AddTransactionPageState extends ConsumerState<AddTransactionPage> {
  late final TextEditingController _nameController;
  late final TextEditingController _amountController;

  TransactionType _type = TransactionType.expense;
  late DateTime _selectedDate;
  List<Account> _accounts = const [];
  List<CategoryItem> _categories = const [];
  Account? _selectedAccount;
  Account? _selectedSourceAccount;
  Account? _selectedDestinationAccount;
  CategoryItem? _selectedCategory;
  String _selectedEntryCurrencyCode = 'EUR';
  bool _showsAdvancedFields = false;
  bool _didTrySubmit = false;
  bool _isSaving = false;
  bool _isFormattingAmount = false;
  String _lastFormattedAmountText = '';
  bool _isFetchingExchangeRate = false;
  double? _exchangeRateValue;
  String? _exchangeRateErrorMessage;
  int _exchangeRateRequestToken = 0;
  Timer? _exchangeRateDebounceTimer;

  bool get _isEditing => widget.initialTransaction != null;

  bool get _isCreditCardPaymentFlow {
    if (_type != TransactionType.transfer) {
      return false;
    }

    return _selectedDestinationAccount?.isCreditCard ?? false;
  }

  bool get _isDestinationLockedToCreditCard =>
      widget.initialCreditCardAccount != null && _isCreditCardPaymentFlow;

  String get _defaultCurrencyCode =>
      ref.read(appStateProvider).settings.defaultCurrencyCode;

  String get _targetCurrencyCode {
    if (_type == TransactionType.transfer) {
      return _selectedSourceAccount?.currencyCode ?? _defaultCurrencyCode;
    }

    return _selectedAccount?.currencyCode ?? _defaultCurrencyCode;
  }

  DateTime get _conversionDate => _selectedDate;

  @override
  void initState() {
    super.initState();
    final initialTransaction = widget.initialTransaction;
    final hasForeignCurrency = initialTransaction?.hasForeignCurrency ?? false;
    _selectedDate = initialTransaction?.date ?? DateTime.now();
    _showsAdvancedFields =
        hasForeignCurrency ||
        !_isSameCalendarDay(_selectedDate, DateTime.now());
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
    _lastFormattedAmountText = _amountController.text;
    _type = widget.startAsCreditCardPayment
        ? TransactionType.transfer
        : initialTransaction?.type ?? TransactionType.expense;
    _nameController.addListener(_handleFieldChange);
    _amountController
      ..addListener(_formatAmountInput)
      ..addListener(_handleAmountChanged);
    final state = ref.read(appStateProvider);
    _accounts = state.accounts;
    _categories = state.categories;
    _selectedAccount = _resolveSelectedAccount(_accounts);
    _selectedSourceAccount = _resolveSelectedSourceAccount(_accounts);
    _selectedDestinationAccount = _resolveSelectedDestinationAccount(_accounts);
    _selectedCategory = _resolveSelectedCategory(_categories);
    if (widget.startAsCreditCardPayment &&
        !_isEditing &&
        widget.initialCreditCardAccount != null &&
        _nameController.text.trim().isEmpty) {
      _nameController.text = '${widget.initialCreditCardAccount!.name} payment';
    }
    if (!hasForeignCurrency) {
      _selectedEntryCurrencyCode = _targetCurrencyCode;
      _exchangeRateValue = 1;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      _syncExchangeRateIfNeeded();
    });
  }

  bool _isSameCalendarDay(DateTime left, DateTime right) {
    return left.year == right.year &&
        left.month == right.month &&
        left.day == right.day;
  }

  DateTime _mergeDateWithExistingTime(DateTime date) {
    return DateTime(
      date.year,
      date.month,
      date.day,
      _selectedDate.hour,
      _selectedDate.minute,
      _selectedDate.second,
      _selectedDate.millisecond,
      _selectedDate.microsecond,
    );
  }

  @override
  void dispose() {
    _nameController
      ..removeListener(_handleFieldChange)
      ..dispose();
    _amountController
      ..removeListener(_formatAmountInput)
      ..removeListener(_handleAmountChanged)
      ..dispose();
    _exchangeRateDebounceTimer?.cancel();
    super.dispose();
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

  Account? _resolveSelectedSourceAccount(List<Account> accounts) {
    final availableAccounts = _availableSourceAccountsFrom(
      accounts,
      destinationAccountId: _resolveSelectedDestinationAccount(accounts)?.id,
      preferNonCreditCards:
          widget.startAsCreditCardPayment ||
          widget.initialTransaction?.isCreditCardPayment == true,
    );
    final selectedAccount =
        _selectedSourceAccount ??
        _accountById(accounts, widget.initialTransaction?.sourceAccountId);

    if (selectedAccount != null) {
      for (final account in availableAccounts) {
        if (account.id == selectedAccount.id) {
          return account;
        }
      }
    }

    return availableAccounts.firstOrNull;
  }

  Account? _resolveSelectedDestinationAccount(List<Account> accounts) {
    final initialCreditCardAccount = widget.initialCreditCardAccount;
    if (initialCreditCardAccount != null) {
      return _accountById(accounts, initialCreditCardAccount.id);
    }

    final selectedAccount =
        _selectedDestinationAccount ??
        _accountById(accounts, widget.initialTransaction?.destinationAccountId);

    if (selectedAccount != null) {
      return _accountById(accounts, selectedAccount.id);
    }

    final sourceAccountId = _selectedSourceAccount?.id;
    for (final account in accounts) {
      if (account.id != sourceAccountId) {
        return account;
      }
    }

    return null;
  }

  Account? _accountById(List<Account> accounts, String? accountId) {
    if (accountId == null) {
      return null;
    }

    for (final account in accounts) {
      if (account.id == accountId) {
        return account;
      }
    }

    return null;
  }

  Account? _firstDifferentAccount(
    String? excludedAccountId, {
    bool preferNonCreditCards = false,
  }) {
    final availableAccounts = _accounts
        .where((account) => account.id != excludedAccountId)
        .toList(growable: false);
    if (!preferNonCreditCards) {
      return availableAccounts.firstOrNull;
    }

    return availableAccounts
            .where((account) => !account.isCreditCard)
            .firstOrNull ??
        availableAccounts.firstOrNull;
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

  void _handleAmountChanged() {
    final currentAmountText = _amountController.text;
    if (_lastFormattedAmountText == currentAmountText) {
      return;
    }

    _lastFormattedAmountText = currentAmountText;

    if (!mounted) {
      return;
    }

    setState(() {});
  }

  List<CategoryItem> get _availableCategories =>
      _availableCategoriesFrom(_categories);

  List<Account> get _availableSourceAccounts {
    return _availableSourceAccountsFrom(
      _accounts,
      destinationAccountId: _selectedDestinationAccount?.id,
      preferNonCreditCards: _isCreditCardPaymentFlow,
    );
  }

  List<Account> get _availableDestinationAccounts {
    final sourceAccountId = _selectedSourceAccount?.id;
    if (sourceAccountId == null) {
      return _accounts;
    }

    return _accounts
        .where((account) => account.id != sourceAccountId)
        .toList(growable: false);
  }

  List<Account> _availableSourceAccountsFrom(
    List<Account> accounts, {
    required String? destinationAccountId,
    required bool preferNonCreditCards,
  }) {
    final availableAccounts = accounts
        .where((account) => account.id != destinationAccountId)
        .toList(growable: false);
    if (!preferNonCreditCards) {
      return availableAccounts;
    }

    final nonCreditCardAccounts = availableAccounts
        .where((account) => !account.isCreditCard)
        .toList(growable: false);
    return nonCreditCardAccounts.isEmpty
        ? availableAccounts
        : nonCreditCardAccounts;
  }

  List<CategoryItem> _availableCategoriesFrom(List<CategoryItem> categories) {
    if (_type == TransactionType.transfer) {
      return const [];
    }

    final expectedType = switch (_type) {
      TransactionType.income => CategoryType.income,
      TransactionType.expense => CategoryType.expense,
      TransactionType.transfer => CategoryType.expense,
    };

    return categories
        .where((category) => category.type == expectedType)
        .toList(growable: false);
  }

  bool get _usesForeignCurrency =>
      _showsAdvancedFields && _selectedEntryCurrencyCode != _targetCurrencyCode;

  double get _enteredAmountValue =>
      double.tryParse(_amountController.text) ?? 0;

  double get _convertedAmountValue => _usesForeignCurrency
      ? _enteredAmountValue * (_exchangeRateValue ?? 0)
      : _enteredAmountValue;

  String get _amountPrefix =>
      '${currencySymbolFor(_selectedEntryCurrencyCode)} ';

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
    if (_type == TransactionType.transfer) {
      return null;
    }

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
    if (_type == TransactionType.transfer) {
      return null;
    }

    if (!_didTrySubmit) {
      return null;
    }

    if (_selectedCategory == null) {
      return 'Please choose a category.';
    }

    return null;
  }

  String? get _sourceAccountError {
    if (_type != TransactionType.transfer || !_didTrySubmit) {
      return null;
    }

    if (_accounts.length < 2) {
      return 'Create at least two accounts before adding a transfer.';
    }

    if (_selectedSourceAccount == null) {
      return 'Please choose a source account.';
    }

    if (_selectedSourceAccount?.id == _selectedDestinationAccount?.id) {
      return 'Source and destination must be different.';
    }

    return null;
  }

  String? get _destinationAccountError {
    if (_type != TransactionType.transfer || !_didTrySubmit) {
      return null;
    }

    if (_accounts.length < 2) {
      return 'Create at least two accounts before adding a transfer.';
    }

    if (_selectedDestinationAccount == null) {
      return 'Please choose a destination account.';
    }

    if (_selectedSourceAccount?.id == _selectedDestinationAccount?.id) {
      return 'Source and destination must be different.';
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
        toCurrencyCode: _targetCurrencyCode,
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

  void _scheduleExchangeRateSync() {
    _exchangeRateDebounceTimer?.cancel();
    _exchangeRateDebounceTimer = Timer(
      const Duration(milliseconds: 350),
      _syncExchangeRateIfNeeded,
    );
  }

  void _setAdvancedFieldsVisible(bool value) {
    if (_showsAdvancedFields == value) {
      return;
    }

    setState(() {
      _showsAdvancedFields = value;
      if (!value) {
        _selectedEntryCurrencyCode = _targetCurrencyCode;
        _exchangeRateValue = 1;
        _exchangeRateErrorMessage = null;
      }
    });

    if (value) {
      _scheduleExchangeRateSync();
      return;
    }

    _exchangeRateDebounceTimer?.cancel();
    _syncExchangeRateIfNeeded();
  }

  void _updateEntryCurrency(String value) {
    if (_selectedEntryCurrencyCode == value) {
      return;
    }

    setState(() {
      _selectedEntryCurrencyCode = value;
      _exchangeRateValue = value == _targetCurrencyCode ? 1 : null;
      _exchangeRateErrorMessage = null;
    });

    _scheduleExchangeRateSync();
  }

  Future<void> _pickTransactionDate() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (pickedDate == null || !mounted) {
      return;
    }

    final nextDate = _mergeDateWithExistingTime(pickedDate);
    if (_isSameCalendarDay(nextDate, _selectedDate)) {
      return;
    }

    setState(() {
      _selectedDate = nextDate;
    });

    if (_usesForeignCurrency) {
      _scheduleExchangeRateSync();
    }
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
        _categoryError != null ||
        _sourceAccountError != null ||
        _destinationAccountError != null) {
      return;
    }

    final selectedAccount = _selectedAccount;
    final selectedSourceAccount = _selectedSourceAccount;
    final selectedDestinationAccount = _selectedDestinationAccount;
    final selectedCategory = _selectedCategory;
    if (_type == TransactionType.transfer) {
      if (selectedSourceAccount == null || selectedDestinationAccount == null) {
        return;
      }
    } else if (selectedAccount == null || selectedCategory == null) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    TransactionItem? transaction;

    try {
      final initialTransaction = widget.initialTransaction;
      final appState = ref.read(appStateProvider.notifier);
      transaction = TransactionItem(
        id: initialTransaction?.id ?? appState.createTransactionId(),
        title: _nameController.text.trim(),
        categoryId: _type == TransactionType.transfer
            ? null
            : selectedCategory!.id,
        accountId: _type == TransactionType.transfer
            ? null
            : selectedAccount!.id,
        amount: _convertedAmountValue,
        currencyCode: _targetCurrencyCode,
        date: _selectedDate,
        type: _type,
        sourceAccountId: _type == TransactionType.transfer
            ? selectedSourceAccount!.id
            : null,
        destinationAccountId: _type == TransactionType.transfer
            ? selectedDestinationAccount!.id
            : null,
        foreignAmount: _usesForeignCurrency ? _enteredAmountValue : null,
        foreignCurrencyCode: _usesForeignCurrency
            ? _selectedEntryCurrencyCode
            : null,
        exchangeRate: _usesForeignCurrency ? _exchangeRateValue : null,
        transferKind:
            _type == TransactionType.transfer &&
                selectedDestinationAccount?.isCreditCard == true
            ? TransactionTransferKind.creditCardPayment
            : null,
      );

      await appState.saveTransaction(transaction, isEditing: _isEditing);
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
      if (type == TransactionType.transfer) {
        _selectedSourceAccount ??= _selectedAccount ?? _accounts.firstOrNull;
        _selectedDestinationAccount ??= _firstDifferentAccount(
          _selectedSourceAccount?.id,
          preferNonCreditCards: false,
        );
      } else {
        _selectedAccount ??= _selectedSourceAccount ?? _accounts.firstOrNull;
      }
      _selectedEntryCurrencyCode = _targetCurrencyCode;
      _exchangeRateValue = 1;
      _exchangeRateErrorMessage = null;
    });
  }

  void _handleTargetCurrencyChanged() {
    if (!_showsAdvancedFields) {
      setState(() {
        _selectedEntryCurrencyCode = _targetCurrencyCode;
        _exchangeRateValue = 1;
        _exchangeRateErrorMessage = null;
      });
      return;
    }

    if (_selectedEntryCurrencyCode == _targetCurrencyCode) {
      setState(() {
        _exchangeRateValue = 1;
        _exchangeRateErrorMessage = null;
      });
      return;
    }

    _scheduleExchangeRateSync();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final availableCategories = _availableCategories;
    final showAccountSelector = _accounts.length > 1;
    final isTransfer = _type == TransactionType.transfer;
    final isCreditCardPayment = _isCreditCardPaymentFlow;
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
    final sourceAccountItems = _availableSourceAccounts
        .map(
          (account) => DropdownSelectorItem<Account>(
            value: account,
            label: account.name,
            subtitle: account.typeLabel,
            icon: account.icon,
          ),
        )
        .toList(growable: false);
    final destinationAccountItems = _availableDestinationAccounts
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
    final localizations = MaterialLocalizations.of(context);
    final selectedDateLabel = localizations.formatMediumDate(_selectedDate);
    final selectedDateHelper = _isSameCalendarDay(_selectedDate, DateTime.now())
        ? 'Today'
        : localizations.formatFullDate(_selectedDate);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        title: Text(
          isCreditCardPayment
              ? (_isEditing ? 'Edit card payment' : 'Add card payment')
              : (_isEditing ? 'Edit transaction' : 'Add transaction'),
        ),
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
                      isCreditCardPayment
                          ? (_isEditing
                                ? 'Update this card payment'
                                : 'Register a card payment')
                          : (_isEditing
                                ? 'Update this entry'
                                : 'Create a new entry'),
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
                        SegmentedToggleItem(
                          value: TransactionType.transfer,
                          label: 'Transfer',
                          icon: Icons.swap_horiz_rounded,
                        ),
                      ],
                      onChanged: _updateType,
                    ),
                    const SizedBox(height: 20),
                    AppTextInput(
                      label: 'Name',
                      controller: _nameController,
                      hintText: isCreditCardPayment
                          ? 'Payment name'
                          : 'Transaction name',
                      textCapitalization: TextCapitalization.words,
                      errorText: _nameError,
                    ),
                    const SizedBox(height: 16),
                    if (isTransfer && _accounts.length < 2) ...[
                      _TransferAccountsBanner(
                        hasAccounts: _accounts.isNotEmpty,
                      ),
                      const SizedBox(height: 16),
                    ],
                    if (!isTransfer && showAccountSelector) ...[
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
                          _handleTargetCurrencyChanged();
                        },
                      ),
                      const SizedBox(height: 16),
                    ] else if (!isTransfer && _accounts.length == 1) ...[
                      _SingleAccountBanner(account: _accounts.first),
                      const SizedBox(height: 16),
                    ],
                    if (isTransfer && _accounts.isNotEmpty) ...[
                      CustomDropdownSelector<Account>(
                        label: isCreditCardPayment
                            ? 'Pay from'
                            : 'From account',
                        hintText: 'Choose a source account',
                        value: _selectedSourceAccount,
                        items: sourceAccountItems,
                        errorText: _sourceAccountError,
                        onChanged: (account) {
                          setState(() {
                            _selectedSourceAccount = account;
                            if (_selectedDestinationAccount?.id == account.id) {
                              _selectedDestinationAccount =
                                  _firstDifferentAccount(
                                    account.id,
                                    preferNonCreditCards: false,
                                  );
                            }
                          });
                          _handleTargetCurrencyChanged();
                        },
                      ),
                      const SizedBox(height: 16),
                      if (_isDestinationLockedToCreditCard &&
                          _selectedDestinationAccount != null)
                        _SingleAccountBanner(
                          label: 'Credit card',
                          account: _selectedDestinationAccount!,
                        )
                      else
                        CustomDropdownSelector<Account>(
                          label: isCreditCardPayment
                              ? 'Credit card'
                              : 'To account',
                          hintText: isCreditCardPayment
                              ? 'Choose a credit card'
                              : 'Choose a destination account',
                          value: _selectedDestinationAccount,
                          items: destinationAccountItems,
                          errorText: _destinationAccountError,
                          onChanged: (account) {
                            setState(() {
                              _selectedDestinationAccount = account;
                              if (_selectedSourceAccount?.id == account.id) {
                                _selectedSourceAccount = _firstDifferentAccount(
                                  account.id,
                                  preferNonCreditCards: isCreditCardPayment,
                                );
                              }
                            });
                          },
                        ),
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
                    if (!isTransfer) ...[
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
                    ],
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
                      _AdvancedTransactionSection(
                        selectedDateLabel: selectedDateLabel,
                        selectedDateHelper: selectedDateHelper,
                        onSelectDate: _pickTransactionDate,
                        currencySection: isTransfer
                            ? null
                            : _AdvancedCurrencySection(
                                entryCurrencyCode: _selectedEntryCurrencyCode,
                                targetCurrencyCode: _targetCurrencyCode,
                                currencyItems: currencyItems,
                                convertedAmount: _convertedAmountValue,
                                enteredAmount: _enteredAmountValue,
                                isFetchingExchangeRate: _isFetchingExchangeRate,
                                hasResolvedExchangeRate:
                                    _exchangeRateValue != null,
                                exchangeRate: _exchangeRateValue,
                                exchangeRateError: _exchangeRateError,
                                onCurrencyChanged: _updateEntryCurrency,
                                onRetryExchangeRate: _syncExchangeRateIfNeeded,
                              ),
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
  const _SingleAccountBanner({required this.account, this.label = 'Account'});

  final Account account;
  final String label;

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
                  label,
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

class _TransferAccountsBanner extends StatelessWidget {
  const _TransferAccountsBanner({required this.hasAccounts});

  final bool hasAccounts;

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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.swap_horiz_rounded, color: AppColors.textPrimary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              hasAccounts
                  ? 'Transfers need two different accounts. Add another account to move money between them.'
                  : 'Create at least two accounts before recording a transfer.',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AdvancedTransactionSection extends StatelessWidget {
  const _AdvancedTransactionSection({
    required this.selectedDateLabel,
    required this.selectedDateHelper,
    required this.onSelectDate,
    this.currencySection,
  });

  final String selectedDateLabel;
  final String selectedDateHelper;
  final Future<void> Function() onSelectDate;
  final Widget? currencySection;

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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Advanced details',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Keep quick add fast and only adjust details when needed.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          _DateSelectorTile(
            label: selectedDateLabel,
            helper: selectedDateHelper,
            onPressed: onSelectDate,
          ),
          if (currencySection != null) ...[
            const SizedBox(height: 16),
            currencySection!,
          ],
        ],
      ),
    );
  }
}

class _DateSelectorTile extends StatelessWidget {
  const _DateSelectorTile({
    required this.label,
    required this.helper,
    required this.onPressed,
  });

  final String label;
  final String helper;
  final Future<void> Function() onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  Icons.calendar_today_rounded,
                  color: AppColors.textPrimary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Date',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      label,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      helper,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}

class _AdvancedCurrencySection extends StatelessWidget {
  const _AdvancedCurrencySection({
    required this.entryCurrencyCode,
    required this.targetCurrencyCode,
    required this.currencyItems,
    required this.convertedAmount,
    required this.enteredAmount,
    required this.isFetchingExchangeRate,
    required this.hasResolvedExchangeRate,
    required this.exchangeRate,
    required this.exchangeRateError,
    required this.onCurrencyChanged,
    required this.onRetryExchangeRate,
  });

  final String entryCurrencyCode;
  final String targetCurrencyCode;
  final List<DropdownSelectorItem<String>> currencyItems;
  final double convertedAmount;
  final double enteredAmount;
  final bool isFetchingExchangeRate;
  final bool hasResolvedExchangeRate;
  final double? exchangeRate;
  final String? exchangeRateError;
  final ValueChanged<String> onCurrencyChanged;
  final Future<void> Function() onRetryExchangeRate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final usesForeignCurrency = entryCurrencyCode != targetCurrencyCode;
    final canShowConvertedAmount =
        !usesForeignCurrency || hasResolvedExchangeRate;

    return Column(
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
          'Use a different entry currency without changing the saved account currency.',
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
                'Saved in account currency',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 6),
              if (usesForeignCurrency && exchangeRateError != null) ...[
                if (canShowConvertedAmount) ...[
                  Text(
                    formatCurrency(
                      convertedAmount,
                      currencyCode: targetCurrencyCode,
                    ),
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                ],
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
              ] else if (!canShowConvertedAmount) ...[
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
              ] else ...[
                Text(
                  formatCurrency(
                    convertedAmount,
                    currencyCode: targetCurrencyCode,
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
                      'Rate: 1 ${entryCurrencyCode.toUpperCase()} = ${formatCurrency(exchangeRate!, currencyCode: targetCurrencyCode)}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                  if (isFetchingExchangeRate) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Refreshing exchange rate...',
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
    );
  }
}
