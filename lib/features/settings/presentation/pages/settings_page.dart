import 'package:expense_tracker/core/theme/app_colors.dart';
import 'package:expense_tracker/core/utils/supported_currencies.dart';
import 'package:expense_tracker/core/widgets/app_text_input.dart';
import 'package:expense_tracker/core/widgets/custom_dropdown_selector.dart';
import 'package:expense_tracker/core/widgets/primary_action_button.dart';
import 'package:expense_tracker/features/settings/data/settings_repository.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key, required this.repository});

  final SettingsRepository repository;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  static const double _floatingNavClearance = 128;

  late final TextEditingController _nameController;
  late String _selectedCurrencyCode;
  String? _nameErrorText;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final settings = widget.repository.getSettings();
    _nameController = TextEditingController(text: settings.displayName);
    _selectedCurrencyCode = settings.defaultCurrencyCode;
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

    await widget.repository.updateDisplayName(trimmedName);
    await widget.repository.updateDefaultCurrencyCode(_selectedCurrencyCode);

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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = AppColors.of(context);
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return SafeArea(
      child: ValueListenableBuilder<Box<dynamic>>(
        valueListenable: widget.repository.listenable(),
        builder: (context, value, child) {
          final settings = widget.repository.getSettings();
          final previewGreeting = settings.copyWith(
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

          return ListView(
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
                'Keep the app personal and set the default currency for new entries.',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: colors.textSecondary,
                ),
              ),
              const SizedBox(height: 24),
              _SettingsCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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
            ],
          );
        },
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
