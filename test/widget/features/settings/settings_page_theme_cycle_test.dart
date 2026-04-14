import 'package:expense_tracker/app/state/app_state_dependencies.dart';
import 'package:expense_tracker/app/state/app_state_provider.dart';
import 'package:expense_tracker/core/theme/app_theme.dart';
import 'package:expense_tracker/features/auth/domain/models/auth_user.dart';
import 'package:expense_tracker/features/auth/domain/repositories/auth_repository.dart';
import 'package:expense_tracker/features/auth/presentation/state/auth_controller.dart';
import 'package:expense_tracker/features/settings/domain/models/app_settings.dart';
import 'package:expense_tracker/features/settings/domain/models/app_theme_preference.dart';
import 'package:expense_tracker/features/settings/presentation/pages/settings_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../transactions/delete_transaction_test_harness.dart';

void main() {
  testWidgets('switches from system to the opposite theme, then toggles', (
    tester,
  ) async {
    final environment = DeleteTestEnvironment(
      settings: const AppSettings(
        displayName: '',
        themePreference: AppThemePreference.system,
        defaultCurrencyCode: 'EUR',
        financialCycleDay: 1,
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsRepositoryProvider.overrideWithValue(
            environment.settingsRepository,
          ),
          accountRepositoryProvider.overrideWithValue(
            environment.accountRepository,
          ),
          categoryRepositoryProvider.overrideWithValue(
            environment.categoryRepository,
          ),
          transactionRepositoryProvider.overrideWithValue(
            environment.transactionRepository,
          ),
          recurringTransactionRepositoryProvider.overrideWithValue(
            environment.recurringTransactionRepository,
          ),
          transactionBalanceServiceProvider.overrideWithValue(
            environment.transactionBalanceService,
          ),
          currencyConversionServiceProvider.overrideWithValue(
            environment.currencyConversionService,
          ),
          recurringTransactionExecutionServiceProvider.overrideWithValue(
            environment.recurringTransactionExecutionService,
          ),
          authRepositoryProvider.overrideWithValue(_PendingAuthRepository()),
        ],
        child: const _SettingsThemeHost(),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Theme'), findsOneWidget);
    expect(find.byIcon(Icons.wb_sunny_rounded), findsOneWidget);

    await tester.tap(find.text('Theme'));
    await tester.pumpAndSettle();
    expect(
      environment.settingsRepository.getSettings().themePreference,
      AppThemePreference.dark,
    );
    expect(find.byIcon(Icons.nightlight_round), findsOneWidget);

    await tester.tap(find.text('Theme'));
    await tester.pumpAndSettle();
    expect(
      environment.settingsRepository.getSettings().themePreference,
      AppThemePreference.light,
    );
    expect(find.byIcon(Icons.wb_sunny_rounded), findsOneWidget);

    await tester.tap(find.text('Theme'));
    await tester.pumpAndSettle();
    expect(
      environment.settingsRepository.getSettings().themePreference,
      AppThemePreference.dark,
    );
    expect(find.byIcon(Icons.nightlight_round), findsOneWidget);
  });
}

class _SettingsThemeHost extends ConsumerWidget {
  const _SettingsThemeHost();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(
      appStateProvider.select(
        (state) => state.settings.themePreference.themeMode,
      ),
    );

    return MaterialApp(
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      home: const Scaffold(body: SettingsPage()),
    );
  }
}

class _PendingAuthRepository implements AuthRepository {
  @override
  AuthUser? get currentUser => null;

  @override
  Stream<AuthUser?> authStateChanges() => const Stream<AuthUser?>.empty();

  @override
  Future<AuthUser> signInWithGoogle() {
    throw UnimplementedError();
  }

  @override
  Future<void> signOut() {
    throw UnimplementedError();
  }
}
