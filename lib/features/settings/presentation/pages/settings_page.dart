import 'package:expense_tracker/app/state/app_state_provider.dart';
import 'package:expense_tracker/features/auth/presentation/state/auth_controller.dart';
import 'package:expense_tracker/core/theme/app_colors.dart';
import 'package:expense_tracker/core/utils/supported_currencies.dart';
import 'package:expense_tracker/core/widgets/app_text_input.dart';
import 'package:expense_tracker/core/widgets/custom_dropdown_selector.dart';
import 'package:expense_tracker/core/widgets/day_of_month_picker_field.dart';
import 'package:expense_tracker/core/widgets/primary_action_button.dart';
import 'package:expense_tracker/features/settings/domain/models/app_theme_preference.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  static const double _floatingNavClearance = 128;

  late final TextEditingController _nameController;
  late String _selectedCurrencyCode;
  late int _financialCycleDay;
  String? _nameErrorText;
  bool _isSaving = false;
  bool _isSavingMonthStart = false;

  AppThemePreference _nextThemePreference(
    AppThemePreference preference, {
    required bool isDarkTheme,
  }) {
    return switch (preference) {
      AppThemePreference.system =>
        isDarkTheme ? AppThemePreference.light : AppThemePreference.dark,
      AppThemePreference.light => AppThemePreference.dark,
      AppThemePreference.dark => AppThemePreference.light,
    };
  }

  @override
  void initState() {
    super.initState();
    final settings = ref.read(appStateProvider).settings;
    _nameController = TextEditingController(text: settings.displayName);
    _selectedCurrencyCode = settings.defaultCurrencyCode;
    _financialCycleDay = settings.financialCycleDay;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _saveSettings() async {
    final trimmedName = _nameController.text.trim();
    if (trimmedName.length > 24) {
      setState(() {
        _nameErrorText = 'Name should stay under 24 characters.';
      });
      return;
    }

    setState(() {
      _isSaving = true;
      _nameErrorText = null;
    });

    await ref
        .read(appStateProvider.notifier)
        .updateSettings(
          displayName: trimmedName,
          defaultCurrencyCode: _selectedCurrencyCode,
        );

    if (!mounted) {
      return;
    }

    setState(() {
      _isSaving = false;
      _nameController.value = TextEditingValue(
        text: trimmedName,
        selection: TextSelection.collapsed(offset: trimmedName.length),
      );
    });

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Settings updated.')));
  }

  Future<void> _updateFinancialCycleDay(int day) async {
    if (_financialCycleDay == day || _isSavingMonthStart) {
      return;
    }

    setState(() {
      _financialCycleDay = day;
      _isSavingMonthStart = true;
    });

    await ref.read(appStateProvider.notifier).updateFinancialCycleDay(day);

    if (!mounted) {
      return;
    }

    setState(() {
      _isSavingMonthStart = false;
    });
  }

  Future<void> _cycleThemePreference() async {
    final theme = Theme.of(context);
    final nextPreference = _nextThemePreference(
      ref.read(appStateProvider).settings.themePreference,
      isDarkTheme: theme.brightness == Brightness.dark,
    );

    await ref
        .read(appStateProvider.notifier)
        .updateThemePreference(nextPreference);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appStateProvider);
    final authState = ref.watch(authControllerProvider);
    final theme = Theme.of(context);
    final colors = AppColors.of(context);
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final isDarkTheme = theme.brightness == Brightness.dark;
    final previewGreeting = state.settings.copyWith(
      displayName: _nameController.text.trim(),
      defaultCurrencyCode: _selectedCurrencyCode,
    );
    final currencyItems = supportedCurrencies
        .map(
          (currency) => DropdownSelectorItem<String>(
            value: currency.code,
            label: '${currency.code} · ${currency.name}',
          ),
        )
        .toList(growable: false);

    return SafeArea(
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          20,
          20,
          20,
          32 + _floatingNavClearance + bottomInset,
        ),
        children: [
          Text(
            'Settings',
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Keep the app personal, choose the default currency, and decide when your month starts.',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: colors.textSecondary,
            ),
          ),
          const SizedBox(height: 24),
          _SettingsCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InkWell(
                  onTap: _cycleThemePreference,
                  borderRadius: BorderRadius.circular(16),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Theme',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: colors.textPrimary,
                            ),
                          ),
                        ),
                        Icon(
                          isDarkTheme
                              ? Icons.nightlight_round
                              : Icons.wb_sunny_rounded,
                          color: isDarkTheme
                              ? const Color(0xFF74A7FF)
                              : const Color(0xFFF2C94C),
                          size: 28,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Greeting',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  previewGreeting.greeting,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
                const SizedBox(height: 20),
                DayOfMonthPickerField(
                  label: 'Month start',
                  dialogTitle: 'Choose month start',
                  dialogDescription:
                      'Pick the day your month begins. Shorter months use the closest available date.',
                  value: _financialCycleDay,
                  valueLabel: 'Day $_financialCycleDay',
                  onChanged: _updateFinancialCycleDay,
                ),
                const SizedBox(height: 10),
                Text(
                  _isSavingMonthStart
                      ? 'Updating your month...'
                      : 'Your summaries and monthly totals update as soon as you change this.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
                const SizedBox(height: 20),
                AppTextInput(
                  label: 'Your name',
                  hintText: 'What should we call you?',
                  controller: _nameController,
                  errorText: _nameErrorText,
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: 18),
                CustomDropdownSelector<String>(
                  label: 'Default currency',
                  hintText: 'Choose a currency',
                  items: currencyItems,
                  value: _selectedCurrencyCode,
                  onChanged: (value) {
                    setState(() {
                      _selectedCurrencyCode = value;
                    });
                  },
                ),
                const SizedBox(height: 12),
                Text(
                  'This will be the starting currency for new accounts and advanced transaction entry, but you can still change it per item.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
                const SizedBox(height: 16),
                PrimaryActionButton(
                  label: 'Save settings',
                  busyLabel: 'Saving...',
                  isBusy: _isSaving,
                  onPressed: _saveSettings,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _SettingsCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Account',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  authState.user?.email ??
                      authState.user?.displayName ??
                      'Signed in',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Authentication is separate from your local budgeting data, so signing out will not remove your Hive data.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
                if (authState.errorMessage != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    authState.errorMessage!,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppColors.dangerDark,
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                PrimaryActionButton(
                  label: 'Log out',
                  busyLabel: 'Logging out...',
                  isBusy: authState.isBusy,
                  onPressed: () {
                    ref.read(authControllerProvider.notifier).signOut();
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: colors.border),
      ),
      child: child,
    );
  }
}
