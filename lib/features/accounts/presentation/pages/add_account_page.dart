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
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';

final _logger = Logger(printer: ScopedLogPrinter('add_account_page'));

class AddAccountPage extends ConsumerStatefulWidget {
  const AddAccountPage({super.key, this.initialAccount});

  final Account? initialAccount;

  @override
  ConsumerState<AddAccountPage> createState() => _AddAccountPageState();
}

class _AddAccountPageState extends ConsumerState<AddAccountPage> {
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _balanceController;

  AccountType _selectedType = AccountType.bank;
  String _selectedCurrencyCode = 'EUR';
  CreditCardPaymentTracking _paymentTracking = CreditCardPaymentTracking.manual;
  int _creditCardDueDay = 1;
  bool _isPrimaryAccount = false;
  bool _didTrySubmit = false;
  bool _isSaving = false;
  bool _isFormattingBalance = false;

  bool get _isEditing => widget.initialAccount != null;

  @override
  void initState() {
    super.initState();
    final initialAccount = widget.initialAccount;
    _selectedType = initialAccount?.type ?? AccountType.bank;
    _selectedCurrencyCode =
        initialAccount?.currencyCode ??
        ref.read(appStateProvider).settings.defaultCurrencyCode;
    _isPrimaryAccount = initialAccount?.isPrimary ?? false;
    _paymentTracking =
        initialAccount?.paymentTracking ?? CreditCardPaymentTracking.manual;
    _creditCardDueDay = initialAccount?.creditCardDueDay ?? 1;
    _nameController = TextEditingController(text: initialAccount?.name ?? '');
    _descriptionController = TextEditingController(
      text: initialAccount?.description ?? '',
    );
    _balanceController = TextEditingController(
      text: (initialAccount?.balance ?? 0).toStringAsFixed(2),
    );
    _nameController.addListener(_handleFieldChange);
    _balanceController
      ..addListener(_handleFieldChange)
      ..addListener(_formatBalanceInput);
  }

  @override
  void dispose() {
    _nameController
      ..removeListener(_handleFieldChange)
      ..dispose();
    _descriptionController.dispose();
    _balanceController
      ..removeListener(_handleFieldChange)
      ..removeListener(_formatBalanceInput)
      ..dispose();
    super.dispose();
  }

  void _handleFieldChange() {
    if (!_didTrySubmit) {
      return;
    }

    setState(() {});
  }

  void _formatBalanceInput() {
    if (_isFormattingBalance) {
      return;
    }

    final input = _balanceController.text;
    final isNegative = input.contains('-');
    final digits = input.replaceAll(RegExp(r'[^0-9]'), '');
    final normalizedDigits = digits.isEmpty ? '0' : digits;
    final amount = (int.tryParse(normalizedDigits) ?? 0) / 100;
    final formatted = '${isNegative ? '-' : ''}${amount.toStringAsFixed(2)}';

    if (_balanceController.text == formatted) {
      return;
    }

    _isFormattingBalance = true;
    _balanceController.value = TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
    _isFormattingBalance = false;

    if (_didTrySubmit && mounted) {
      setState(() {});
    }
  }

  bool get _isCreditCard => _selectedType == AccountType.creditCard;

  double get _balanceValue => double.tryParse(_balanceController.text) ?? 0;

  String get _balancePrefix => '${currencySymbolFor(_selectedCurrencyCode)} ';

  String? get _nameError {
    if (!_didTrySubmit) {
      return null;
    }

    if (_nameController.text.trim().isEmpty) {
      return 'Please give this account a name.';
    }

    return null;
  }

  Future<void> _saveAccount() async {
    FocusScope.of(context).unfocus();

    setState(() {
      _didTrySubmit = true;
    });

    if (_nameError != null) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    Account? account;

    try {
      final initialAccount = widget.initialAccount;
      final appState = ref.read(appStateProvider.notifier);
      account = Account(
        id: initialAccount?.id ?? appState.createAccountId(),
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        type: _selectedType,
        balance: _balanceValue,
        currencyCode: _selectedCurrencyCode,
        isPrimary: _isPrimaryAccount,
        creditCardDueDay: _isCreditCard ? _creditCardDueDay : null,
        paymentTracking: _isCreditCard ? _paymentTracking : null,
      );

      await appState.saveAccount(account, isEditing: _isEditing);
    } catch (error, stackTrace) {
      _logger.e(
        'Failed to save account ${account?.id ?? 'unknown'}.',
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
          content: Text('Could not save the account. Please try again.'),
        ),
      );
      return;
    }

    if (!mounted) {
      return;
    }

    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currencyItems = supportedCurrencies
        .map(
          (currency) => DropdownSelectorItem<String>(
            value: currency.code,
            label: currency.code,
          ),
        )
        .toList(growable: false);
    final accountTypeItems = AccountType.values
        .map(
          (type) => DropdownSelectorItem<AccountType>(
            value: type,
            label: switch (type) {
              AccountType.bank => 'Bank account',
              AccountType.cash => 'Cash',
              AccountType.savings => 'Savings',
              AccountType.creditCard => 'Credit card',
            },
            subtitle: switch (type) {
              AccountType.bank => 'Everyday balances and transfers',
              AccountType.cash => 'Physical wallet or petty cash',
              AccountType.savings => 'Longer-term goals and reserves',
              AccountType.creditCard => 'Track card spending and due payments',
            },
            icon: switch (type) {
              AccountType.bank => Icons.account_balance_outlined,
              AccountType.cash => Icons.payments_outlined,
              AccountType.savings => Icons.savings_outlined,
              AccountType.creditCard => Icons.credit_card_outlined,
            },
          ),
        )
        .toList(growable: false);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        title: Text(_isEditing ? 'Edit account' : 'Add account'),
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
                      _isEditing
                          ? 'Update this tracked balance'
                          : 'Create a tracked account',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 24),
                    AppTextInput(
                      label: 'Name',
                      hintText: 'Main checking, Wallet, Travel fund...',
                      controller: _nameController,
                      errorText: _nameError,
                      textCapitalization: TextCapitalization.words,
                    ),
                    const SizedBox(height: 18),
                    AppTextInput(
                      label: 'Description',
                      hintText: 'Optional notes about this balance',
                      controller: _descriptionController,
                      textCapitalization: TextCapitalization.sentences,
                    ),
                    const SizedBox(height: 18),
                    CustomDropdownSelector<AccountType>(
                      label: 'Account type',
                      hintText: 'Choose an account type',
                      items: accountTypeItems,
                      value: _selectedType,
                      onChanged: (value) {
                        setState(() {
                          _selectedType = value;
                        });
                      },
                    ),
                    const SizedBox(height: 18),
                    _PrimaryAccountToggle(
                      value: _isPrimaryAccount,
                      onChanged: (value) {
                        setState(() {
                          _isPrimaryAccount = value;
                        });
                      },
                    ),
                    const SizedBox(height: 18),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: CustomDropdownSelector<String>(
                            label: 'Currency',
                            hintText: 'Choose a currency',
                            items: currencyItems,
                            value: _selectedCurrencyCode,
                            onChanged: (value) {
                              setState(() {
                                _selectedCurrencyCode = value;
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: AppTextInput(
                            label: _isCreditCard
                                ? 'Current balance'
                                : 'Opening balance',
                            hintText: '0.00',
                            controller: _balanceController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                              signed: true,
                            ),
                            prefixText: _balancePrefix,
                          ),
                        ),
                      ],
                    ),
                    if (_isCreditCard) ...[
                      const SizedBox(height: 24),
                      Container(
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
                              'Credit card details',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 18),
                            _DueDayPicker(
                              value: _creditCardDueDay,
                              onChanged: (value) {
                                setState(() {
                                  _creditCardDueDay = value;
                                });
                              },
                            ),
                            const SizedBox(height: 18),
                            SegmentedToggleField<CreditCardPaymentTracking>(
                              label: 'Payment tracking',
                              value: _paymentTracking,
                              items: const [
                                SegmentedToggleItem(
                                  value: CreditCardPaymentTracking.manual,
                                  label: 'Manual',
                                  icon: Icons.pan_tool_alt_outlined,
                                ),
                                SegmentedToggleItem(
                                  value: CreditCardPaymentTracking.automatic,
                                  label: 'Auto',
                                  icon: Icons.auto_mode_outlined,
                                ),
                              ],
                              onChanged: (value) {
                                setState(() {
                                  _paymentTracking = value;
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    PrimaryActionButton(
                      label: _isEditing ? 'Save changes' : 'Create account',
                      busyLabel: 'Saving...',
                      isBusy: _isSaving,
                      onPressed: _saveAccount,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PrimaryAccountToggle extends StatelessWidget {
  const _PrimaryAccountToggle({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: () => onChanged(!value),
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.border, width: 1.4),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: value ? AppColors.brand : AppColors.background,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.star_rounded,
                  size: 20,
                  color: value ? AppColors.white : AppColors.iconMuted,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Main account',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Switch.adaptive(value: value, onChanged: onChanged),
            ],
          ),
        ),
      ),
    );
  }
}

class _DueDayPicker extends StatelessWidget {
  const _DueDayPicker({required this.value, required this.onChanged});

  final int value;
  final ValueChanged<int> onChanged;

  Future<void> _openPicker(BuildContext context) async {
    final selectedDay = await showDialog<int>(
      context: context,
      builder: (context) => _DueDayDialog(selectedDay: value),
    );

    if (selectedDay != null) {
      onChanged(selectedDay);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Payment due day',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 10),
        Material(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(24),
          child: InkWell(
            onTap: () => _openPicker(context),
            borderRadius: BorderRadius.circular(24),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.border, width: 1.4),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.calendar_month_outlined,
                      size: 18,
                      color: AppColors.iconMuted,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Day $value',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: AppColors.iconMuted,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _DueDayDialog extends StatefulWidget {
  const _DueDayDialog({required this.selectedDay});

  final int selectedDay;

  @override
  State<_DueDayDialog> createState() => _DueDayDialogState();
}

class _DueDayDialogState extends State<_DueDayDialog> {
  late int _pendingDay;

  @override
  void initState() {
    super.initState();
    _pendingDay = widget.selectedDay;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Select due day',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Choose the day of the month when this card payment is due.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 20),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: 31,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
              ),
              itemBuilder: (context, index) {
                final day = index + 1;
                final isSelected = day == _pendingDay;

                return InkWell(
                  onTap: () {
                    setState(() {
                      _pendingDay = day;
                    });
                  },
                  customBorder: const CircleBorder(),
                  child: Center(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.brand
                            : Colors.transparent,
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '$day',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: isSelected
                              ? AppColors.white
                              : AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(_pendingDay),
                  child: const Text('Confirm'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
