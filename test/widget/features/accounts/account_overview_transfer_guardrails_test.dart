import 'package:expense_tracker/features/accounts/domain/models/account.dart';
import 'package:expense_tracker/features/accounts/presentation/pages/account_overview_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../transactions/delete_transaction_test_harness.dart';

void main() {
  group('account overview transfer guardrails', () {
    testWidgets('shows Transfer entry point for standard accounts', (
      tester,
    ) async {
      final environment = DeleteTestEnvironment(
        accounts: [walletAccount(), travelAccount()],
      );

      await environment.pumpApp(
        tester,
        home: const AccountOverviewPage(accountId: 'account-wallet'),
      );

      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();

      expect(find.text('Transfer'), findsOneWidget);
      expect(find.text('Add transaction'), findsOneWidget);
    });

    testWidgets('shows Pay card entry point for credit-card accounts', (
      tester,
    ) async {
      final environment = DeleteTestEnvironment(
        accounts: [walletAccount(), _creditCardAccount()],
      );

      await environment.pumpApp(
        tester,
        home: const AccountOverviewPage(accountId: 'account-card'),
      );

      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();

      expect(find.text('Pay card'), findsOneWidget);
      expect(find.text('Add charge'), findsOneWidget);
    });
  });
}

Account _creditCardAccount() {
  return const Account(
    id: 'account-card',
    name: 'Card',
    type: AccountType.creditCard,
    openingBalance: 0,
    currencyCode: 'EUR',
  );
}
