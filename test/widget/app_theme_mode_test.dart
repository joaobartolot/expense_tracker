import 'package:expense_tracker/app/app.dart';
import 'package:expense_tracker/app/state/app_state_dependencies.dart';
import 'package:expense_tracker/features/auth/domain/models/auth_user.dart';
import 'package:expense_tracker/features/auth/domain/repositories/auth_repository.dart';
import 'package:expense_tracker/features/auth/presentation/state/auth_controller.dart';
import 'package:expense_tracker/features/settings/domain/models/app_settings.dart';
import 'package:expense_tracker/features/settings/domain/models/app_theme_preference.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'features/transactions/delete_transaction_test_harness.dart';

void main() {
  testWidgets('uses the persisted themeMode from settings', (tester) async {
    final environment = DeleteTestEnvironment(
      settings: const AppSettings(
        displayName: '',
        themePreference: AppThemePreference.dark,
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
        child: const ExpenseTrackerApp(),
      ),
    );

    await tester.pump();

    final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(materialApp.themeMode, ThemeMode.dark);
  });
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
