import 'package:expense_tracker/core/navigation/app_navigator_key.dart';
import 'package:expense_tracker/core/theme/app_theme.dart';
import 'package:expense_tracker/app/state/app_state_provider.dart';
import 'package:expense_tracker/features/auth/presentation/pages/auth_gate.dart';
import 'package:expense_tracker/features/settings/domain/models/app_theme_preference.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ExpenseTrackerApp extends ConsumerWidget {
  const ExpenseTrackerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(
      appStateProvider.select(
        (state) => state.settings.themePreference.themeMode,
      ),
    );

    return MaterialApp(
      navigatorKey: appNavigatorKey,
      title: 'Vero',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      themeAnimationDuration: const Duration(milliseconds: 160),
      themeAnimationCurve: Curves.easeOutCubic,
      builder: (context, child) {
        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: const AuthGate(),
    );
  }
}
