import 'package:expense_tracker/features/accounts/data/hive_account_repository.dart';
import 'package:expense_tracker/core/navigation/app_navigator_key.dart';
import 'package:expense_tracker/core/theme/app_theme.dart';
import 'package:expense_tracker/features/categories/data/hive_category_repository.dart';
import 'package:expense_tracker/features/navigation/presentation/pages/app_shell.dart';
import 'package:expense_tracker/features/settings/data/hive_settings_repository.dart';
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
  late final HiveAccountRepository _accountRepository;

  @override
  void initState() {
    super.initState();
    _settingsRepository = HiveSettingsRepository();
    _transactionRepository = HiveTransactionRepository();
    _categoryRepository = HiveCategoryRepository();
    _accountRepository = HiveAccountRepository();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Box<dynamic>>(
      valueListenable: _settingsRepository.listenable(),
      builder: (context, value, child) {
        return MaterialApp(
          navigatorKey: appNavigatorKey,
          title: 'Vero',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          // TODO: Read the persisted theme preference from settings instead of forcing light mode.
          // Keep dark palette defined in AppTheme for future re-enable.
          themeMode: ThemeMode.light,
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
            accountRepository: _accountRepository,
          ),
        );
      },
    );
  }
}
