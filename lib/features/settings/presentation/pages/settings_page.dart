import 'package:expense_tracker/core/theme/app_colors.dart';
import 'package:expense_tracker/core/widgets/app_text_input.dart';
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
  late final TextEditingController _nameController;
  String? _nameErrorText;
  bool _isSavingName = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.repository.getSettings().displayName,
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _saveName() async {
    final trimmedName = _nameController.text.trim();
    if (trimmedName.length > 24) {
      setState(() {
        _nameErrorText = 'Name should stay under 24 characters.';
      });
      return;
    }

    setState(() {
      _isSavingName = true;
      _nameErrorText = null;
    });

    await widget.repository.updateDisplayName(trimmedName);

    if (!mounted) {
      return;
    }

    setState(() {
      _isSavingName = false;
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

    return SafeArea(
      child: ValueListenableBuilder<Box<dynamic>>(
        valueListenable: widget.repository.listenable(),
        builder: (context, value, child) {
          final settings = widget.repository.getSettings();
          final previewGreeting = settings.copyWith(
            displayName: _nameController.text.trim(),
          );

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
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
                'Keep the app personal.',
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
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _isSavingName ? null : _saveName,
                        child: Text(_isSavingName ? 'Saving...' : 'Save name'),
                      ),
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
