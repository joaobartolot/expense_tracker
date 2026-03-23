import 'package:expense_tracker/core/navigation/app_navigator_key.dart';
import 'package:expense_tracker/core/theme/app_theme.dart';
import 'package:expense_tracker/features/categories/data/hive_category_repository.dart';
import 'package:expense_tracker/features/navigation/presentation/pages/app_shell.dart';
import 'package:expense_tracker/features/settings/data/hive_settings_repository.dart';
import 'package:expense_tracker/features/settings/domain/models/app_theme_preference.dart';
import 'package:expense_tracker/features/transactions/data/hive_transaction_repository.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

class ExpenseTrackerApp extends StatefulWidget {
  const ExpenseTrackerApp({super.key});

  @override
  State<ExpenseTrackerApp> createState() => _ExpenseTrackerAppState();
}

class _ExpenseTrackerAppState extends State<ExpenseTrackerApp> {
  late final HiveSettingsRepository _settingsRepository;
  late final HiveTransactionRepository _transactionRepository;
  late final HiveCategoryRepository _categoryRepository;

  @override
  void initState() {
    super.initState();
    _settingsRepository = HiveSettingsRepository();
    _transactionRepository = HiveTransactionRepository();
    _categoryRepository = HiveCategoryRepository();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Box<dynamic>>(
      valueListenable: _settingsRepository.listenable(),
      builder: (context, value, child) {
        final settings = _settingsRepository.getSettings();

        return MaterialApp(
          navigatorKey: appNavigatorKey,
          title: 'Expense Tracker',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: settings.themePreference.themeMode,
          builder: (context, child) {
            return GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
              child: child ?? const SizedBox.shrink(),
            );
          },
          home: AppShell(
            repository: _transactionRepository,
            categoryRepository: _categoryRepository,
            settingsRepository: _settingsRepository,
          ),
        );
      },
    );
  }
}
