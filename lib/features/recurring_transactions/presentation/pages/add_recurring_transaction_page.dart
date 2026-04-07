import 'package:expense_tracker/app/state/app_state_provider.dart';
import 'package:expense_tracker/core/theme/app_colors.dart';
import 'package:expense_tracker/core/utils/currency_formatter.dart';
import 'package:expense_tracker/core/widgets/app_text_input.dart';
import 'package:expense_tracker/core/widgets/custom_dropdown_selector.dart';
import 'package:expense_tracker/core/widgets/day_of_month_picker_field.dart';
import 'package:expense_tracker/core/widgets/primary_action_button.dart';
import 'package:expense_tracker/core/widgets/segmented_toggle_field.dart';
import 'package:expense_tracker/features/accounts/domain/models/account.dart';
import 'package:expense_tracker/features/categories/domain/models/category_item.dart';
import 'package:expense_tracker/features/recurring_transactions/domain/models/recurring_transaction.dart';
import 'package:expense_tracker/features/transactions/domain/models/transaction_item.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AddRecurringTransactionPage extends ConsumerStatefulWidget {
  const AddRecurringTransactionPage({
    super.key,
    this.initialRecurringTransaction,
  });

  final RecurringTransaction? initialRecurringTransaction;

  @override
  ConsumerState<AddRecurringTransactionPage> createState() =>
      _AddRecurringTransactionPageState();
}

class _AddRecurringTransactionPageState
    extends ConsumerState<AddRecurringTransactionPage> {
  late final TextEditingController _nameController;
  late final TextEditingController _amountController;
  late final TextEditingController _customIntervalController;

  TransactionType _type = TransactionType.expense;
  RecurringExecutionMode _executionMode = RecurringExecutionMode.manual;
  RecurringFrequencyPreset _frequencyPreset = RecurringFrequencyPreset.monthly;
  RecurringIntervalUnit _intervalUnit = RecurringIntervalUnit.month;
  late DateTime _selectedDate;
  List<Account> _accounts = const [];
  List<CategoryItem> _categories = const [];
  Account? _selectedAccount;
  Account? _selectedSourceAccount;
  Account? _selectedDestinationAccount;
  CategoryItem? _selectedCategory;
  bool _didTrySubmit = false;
  bool _isSaving = false;
  bool _isFormattingAmount = false;
  String _lastFormattedAmountText = '';
  bool _isPaused = false;

  bool get _isEditing => widget.initialRecurringTransaction != null;

  int get _resolvedInterval =>
      _frequencyPreset == RecurringFrequencyPreset.custom
      ? (int.tryParse(_customIntervalController.text) ?? 0)
      : 1;

  String get _currencyCode {
    if (_type == TransactionType.transfer) {
      return _selectedSourceAccount?.currencyCode ??
          ref.read(appStateProvider).settings.defaultCurrencyCode;
    }

    return _selectedAccount?.currencyCode ??
        ref.read(appStateProvider).settings.defaultCurrencyCode;
  }

  double get _amountValue => double.tryParse(_amountController.text) ?? 0;

  List<CategoryItem> get _availableCategories {
    if (_type == TransactionType.transfer) {
      return const [];
    }

    final expectedType = _type == TransactionType.income
        ? CategoryType.income
        : CategoryType.expense;

    return _categories
        .where((category) => category.type == expectedType)
        .toList(growable: false);
  }

  List<Account> get _availableSourceAccounts {
    return _accounts
        .where((account) => account.id != _selectedDestinationAccount?.id)
        .toList(growable: false);
  }

  List<Account> get _availableDestinationAccounts {
    return _accounts
        .where((account) => account.id != _selectedSourceAccount?.id)
        .toList(growable: false);
  }

  @override
  void initState() {
    super.initState();
    final initialRecurringTransaction = widget.initialRecurringTransaction;
    final state = ref.read(appStateProvider);
    _accounts = state.accounts;
    _categories = state.categories;
    _selectedDate = initialRecurringTransaction?.startDate ?? DateTime.now();
    _type = initialRecurringTransaction?.type ?? TransactionType.expense;
    _executionMode =
        initialRecurringTransaction?.executionMode ??
        RecurringExecutionMode.manual;
    _frequencyPreset =
        initialRecurringTransaction?.frequencyPreset ??
        RecurringFrequencyPreset.monthly;
    _intervalUnit =
        initialRecurringTransaction?.intervalUnit ??
        RecurringIntervalUnit.month;
    _isPaused = initialRecurringTransaction?.isPaused ?? false;
    _nameController = TextEditingController(
      text: initialRecurringTransaction?.title ?? '',
    );
    _amountController = TextEditingController(
      text: (initialRecurringTransaction?.amount ?? 0).toStringAsFixed(2),
    );
    _customIntervalController = TextEditingController(
      text: (initialRecurringTransaction?.interval ?? 1).toString(),
    );
    _lastFormattedAmountText = _amountController.text;
    _selectedAccount = _accountById(
      _accounts,
      initialRecurringTransaction?.accountId,
    );
    _selectedSourceAccount = _accountById(
      _accounts,
      initialRecurringTransaction?.sourceAccountId,
    );
    _selectedDestinationAccount = _accountById(
      _accounts,
      initialRecurringTransaction?.destinationAccountId,
    );
    _selectedCategory = _categoryById(
      _categories,
      initialRecurringTransaction?.categoryId,
    );
    if (_type == TransactionType.transfer) {
      _selectedSourceAccount ??= _accounts.firstOrNull;
      _selectedDestinationAccount ??= _accounts
          .where((account) => account.id != _selectedSourceAccount?.id)
          .firstOrNull;
    } else {
      _selectedAccount ??= _accounts.firstOrNull;
      _selectedCategory ??= _availableCategories.firstOrNull;
    }
    _nameController.addListener(_handleFieldChange);
    _amountController
      ..addListener(_formatAmountInput)
      ..addListener(_handleFieldChange);
    _customIntervalController.addListener(_handleFieldChange);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    _customIntervalController.dispose();
    super.dispose();
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

  CategoryItem? _categoryById(
    List<CategoryItem> categories,
    String? categoryId,
  ) {
    if (categoryId == null) {
      return null;
    }

    for (final category in categories) {
      if (category.id == categoryId) {
        return category;
      }
    }

    return null;
  }

  void _handleFieldChange() {
    if (_didTrySubmit && mounted) {
      setState(() {});
    }
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

    if (_lastFormattedAmountText != formatted) {
      _lastFormattedAmountText = formatted;
      _handleFieldChange();
    }
  }

  void _updateDueDay(int day) {
    final maxDay = DateTime(_selectedDate.year, _selectedDate.month + 1, 0).day;
    setState(() {
      _selectedDate = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        day.clamp(1, maxDay),
        _selectedDate.hour,
        _selectedDate.minute,
      );
    });
  }

  void _updateType(TransactionType type) {
    if (_type == type) {
      return;
    }

    setState(() {
      _type = type;
      _selectedCategory = null;
      if (type == TransactionType.transfer) {
        _selectedSourceAccount ??= _accounts.firstOrNull;
        _selectedDestinationAccount ??= _accounts
            .where((account) => account.id != _selectedSourceAccount?.id)
            .firstOrNull;
        _selectedAccount = null;
      } else {
        _selectedAccount ??= _selectedSourceAccount ?? _accounts.firstOrNull;
        _selectedSourceAccount = null;
        _selectedDestinationAccount = null;
      }
    });
  }

  void _updateFrequencyPreset(RecurringFrequencyPreset preset) {
    if (_frequencyPreset == preset) {
      return;
    }

    setState(() {
      _frequencyPreset = preset;
      switch (preset) {
        case RecurringFrequencyPreset.daily:
          _intervalUnit = RecurringIntervalUnit.day;
          _customIntervalController.text = '1';
          break;
        case RecurringFrequencyPreset.weekly:
          _intervalUnit = RecurringIntervalUnit.week;
          _customIntervalController.text = '1';
          break;
        case RecurringFrequencyPreset.monthly:
          _intervalUnit = RecurringIntervalUnit.month;
          _customIntervalController.text = '1';
          break;
        case RecurringFrequencyPreset.yearly:
          _intervalUnit = RecurringIntervalUnit.year;
          _customIntervalController.text = '1';
          break;
        case RecurringFrequencyPreset.custom:
          _customIntervalController.text =
              _customIntervalController.text.isEmpty
              ? '2'
              : _customIntervalController.text;
          break;
      }
    });
  }

  String? get _nameError {
    if (!_didTrySubmit || _nameController.text.trim().isNotEmpty) {
      return null;
    }

    return 'Please enter a name.';
  }

  String? get _amountError {
    if (!_didTrySubmit || _amountValue > 0) {
      return null;
    }

    return 'Please enter an amount greater than 0.00.';
  }

  String? get _categoryError {
    if (_type == TransactionType.transfer || !_didTrySubmit) {
      return null;
    }

    if (_selectedCategory == null) {
      return 'Choose a category.';
    }

    return null;
  }

  String? get _accountError {
    if (_type == TransactionType.transfer || !_didTrySubmit) {
      return null;
    }

    if (_selectedAccount == null) {
      return 'Choose an account.';
    }

    return null;
  }

  String? get _sourceAccountError {
    if (_type != TransactionType.transfer || !_didTrySubmit) {
      return null;
    }

    if (_accounts.length < 2) {
      return 'Create at least two accounts before creating a recurring transfer.';
    }

    if (_selectedSourceAccount == null) {
      return 'Choose a source account.';
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
      return 'Create at least two accounts before creating a recurring transfer.';
    }

    if (_selectedDestinationAccount == null) {
      return 'Choose a destination account.';
    }

    if (_selectedSourceAccount?.id == _selectedDestinationAccount?.id) {
      return 'Source and destination must be different.';
    }

    return null;
  }

  String? get _customIntervalError {
    if (_frequencyPreset != RecurringFrequencyPreset.custom || !_didTrySubmit) {
      return null;
    }

    if (_resolvedInterval <= 0) {
      return 'Enter a custom interval greater than zero.';
    }

    return null;
  }

  Future<void> _saveRecurringTransaction() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _didTrySubmit = true;
    });

    if (_nameError != null ||
        _amountError != null ||
        _categoryError != null ||
        _accountError != null ||
        _sourceAccountError != null ||
        _destinationAccountError != null ||
        _customIntervalError != null) {
      return;
    }

    final selectedAccount = _selectedAccount;
    final selectedCategory = _selectedCategory;
    final selectedSourceAccount = _selectedSourceAccount;
    final selectedDestinationAccount = _selectedDestinationAccount;
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

    try {
      final initialRecurringTransaction = widget.initialRecurringTransaction;
      final appState = ref.read(appStateProvider.notifier);
      final recurringTransaction = RecurringTransaction(
        id:
            initialRecurringTransaction?.id ??
            appState.createRecurringTransactionId(),
        title: _nameController.text.trim(),
        amount: _amountValue,
        currencyCode: _currencyCode,
        startDate: _selectedDate,
        type: _type,
        executionMode: _executionMode,
        frequencyPreset: _frequencyPreset,
        intervalUnit: _intervalUnit,
        interval: _resolvedInterval,
        categoryId: _type == TransactionType.transfer
            ? null
            : selectedCategory!.id,
        accountId: _type == TransactionType.transfer
            ? null
            : selectedAccount!.id,
        sourceAccountId: _type == TransactionType.transfer
            ? selectedSourceAccount!.id
            : null,
        destinationAccountId: _type == TransactionType.transfer
            ? selectedDestinationAccount!.id
            : null,
        lastProcessedOccurrenceDate:
            initialRecurringTransaction?.lastProcessedOccurrenceDate,
        isPaused: _isPaused,
      );

      await appState.saveRecurringTransaction(
        recurringTransaction,
        isEditing: _isEditing,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isEditing
                ? 'Could not save the recurring item.'
                : 'Could not create the recurring item.',
          ),
        ),
      );
      return;
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }

    if (!mounted) {
      return;
    }

    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = AppColors.of(context);
    final categoryItems = _availableCategories
        .map(
          (category) => DropdownSelectorItem<CategoryItem>(
            value: category,
            label: category.name,
            subtitle: category.description,
            icon: category.icon,
          ),
        )
        .toList(growable: false);
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

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit recurring' : 'New recurring'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            SegmentedToggleField<TransactionType>(
              label: 'Type',
              value: _type,
              items: const [
                SegmentedToggleItem(
                  value: TransactionType.expense,
                  label: 'Expense',
                  icon: Icons.south_west_rounded,
                ),
                SegmentedToggleItem(
                  value: TransactionType.income,
                  label: 'Income',
                  icon: Icons.north_east_rounded,
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
              hintText: 'Rent, salary, savings transfer...',
              controller: _nameController,
              errorText: _nameError,
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 20),
            AppTextInput(
              label: 'Amount',
              hintText: '0.00',
              controller: _amountController,
              errorText: _amountError,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              prefixText: '${currencySymbolFor(_currencyCode)} ',
            ),
            const SizedBox(height: 20),
            if (_type == TransactionType.transfer) ...[
              CustomDropdownSelector<Account>(
                label: 'Source account',
                hintText: 'Choose a source account',
                items: sourceAccountItems,
                value: _selectedSourceAccount,
                errorText: _sourceAccountError,
                onChanged: (account) {
                  setState(() {
                    _selectedSourceAccount = account;
                    if (_selectedDestinationAccount?.id == account.id) {
                      _selectedDestinationAccount =
                          _availableDestinationAccounts.firstOrNull;
                    }
                  });
                },
              ),
              const SizedBox(height: 20),
              CustomDropdownSelector<Account>(
                label: 'Destination account',
                hintText: 'Choose a destination account',
                items: destinationAccountItems,
                value: _selectedDestinationAccount,
                errorText: _destinationAccountError,
                onChanged: (account) {
                  setState(() {
                    _selectedDestinationAccount = account;
                    if (_selectedSourceAccount?.id == account.id) {
                      _selectedSourceAccount =
                          _availableSourceAccounts.firstOrNull;
                    }
                  });
                },
              ),
            ] else ...[
              CustomDropdownSelector<Account>(
                label: 'Account',
                hintText: 'Choose an account',
                items: accountItems,
                value: _selectedAccount,
                errorText: _accountError,
                onChanged: (account) {
                  setState(() {
                    _selectedAccount = account;
                  });
                },
              ),
              const SizedBox(height: 20),
              CustomDropdownSelector<CategoryItem>(
                label: 'Category',
                hintText: 'Choose a category',
                items: categoryItems,
                value: _selectedCategory,
                errorText: _categoryError,
                onChanged: (category) {
                  setState(() {
                    _selectedCategory = category;
                  });
                },
              ),
            ],
            const SizedBox(height: 24),
            SegmentedToggleField<RecurringExecutionMode>(
              label: 'Mode',
              value: _executionMode,
              items: const [
                SegmentedToggleItem(
                  value: RecurringExecutionMode.automatic,
                  label: 'Automatic',
                  icon: Icons.bolt_rounded,
                ),
                SegmentedToggleItem(
                  value: RecurringExecutionMode.manual,
                  label: 'Manual',
                  icon: Icons.pending_actions_rounded,
                ),
              ],
              onChanged: (mode) {
                setState(() {
                  _executionMode = mode;
                });
              },
            ),
            const SizedBox(height: 24),
            Text(
              'Frequency',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final preset in RecurringFrequencyPreset.values)
                  ChoiceChip(
                    label: Text(_frequencyLabelForPreset(preset)),
                    selected: _frequencyPreset == preset,
                    onSelected: (_) => _updateFrequencyPreset(preset),
                  ),
              ],
            ),
            if (_frequencyPreset == RecurringFrequencyPreset.custom) ...[
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: AppTextInput(
                      label: 'Every',
                      hintText: '2',
                      controller: _customIntervalController,
                      keyboardType: TextInputType.number,
                      errorText: _customIntervalError,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: CustomDropdownSelector<RecurringIntervalUnit>(
                      label: 'Unit',
                      hintText: 'Choose a unit',
                      items: RecurringIntervalUnit.values
                          .map(
                            (unit) => DropdownSelectorItem(
                              value: unit,
                              label: _intervalUnitLabel(unit),
                            ),
                          )
                          .toList(growable: false),
                      value: _intervalUnit,
                      onChanged: (unit) {
                        setState(() {
                          _intervalUnit = unit;
                        });
                      },
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'First due date',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  DayOfMonthPickerField(
                    label: 'Due day',
                    dialogTitle: 'Select due day',
                    dialogDescription:
                        'Pick the due day. Short months use their last valid day.',
                    value: _selectedDate.day,
                    valueLabel: 'Day ${_selectedDate.day}',
                    onChanged: _updateDueDay,
                  ),
                  const SizedBox(height: 14),
                  SwitchListTile.adaptive(
                    value: _isPaused,
                    onChanged: (value) {
                      setState(() {
                        _isPaused = value;
                      });
                    },
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Pause this recurring item'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            PrimaryActionButton(
              label: _isEditing
                  ? 'Save recurring item'
                  : 'Create recurring item',
              busyLabel: _isEditing ? 'Saving...' : 'Creating...',
              isBusy: _isSaving,
              onPressed: _isSaving ? null : _saveRecurringTransaction,
            ),
          ],
        ),
      ),
    );
  }

  String _frequencyLabelForPreset(RecurringFrequencyPreset preset) {
    return switch (preset) {
      RecurringFrequencyPreset.daily => 'Daily',
      RecurringFrequencyPreset.weekly => 'Weekly',
      RecurringFrequencyPreset.monthly => 'Monthly',
      RecurringFrequencyPreset.yearly => 'Yearly',
      RecurringFrequencyPreset.custom => 'Custom',
    };
  }

  String _intervalUnitLabel(RecurringIntervalUnit unit) {
    return switch (unit) {
      RecurringIntervalUnit.day => 'Days',
      RecurringIntervalUnit.week => 'Weeks',
      RecurringIntervalUnit.month => 'Months',
      RecurringIntervalUnit.year => 'Years',
    };
  }
}
