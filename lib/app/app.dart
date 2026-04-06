import 'package:expense_tracker/core/navigation/app_navigator_key.dart';
import 'package:expense_tracker/core/theme/app_theme.dart';
import 'package:expense_tracker/features/navigation/presentation/pages/app_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ExpenseTrackerApp extends ConsumerWidget {
  const ExpenseTrackerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
      home: const AppShell(),
    );
  }
}
