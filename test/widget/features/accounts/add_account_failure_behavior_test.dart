import 'package:expense_tracker/features/accounts/domain/models/account.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'add_account_test_harness.dart';

void main() {
  group('add account failure behavior', () {
    testWidgets(
      'create failure shows feedback, stays on the page, and clears the busy state',
      (tester) async {
        await _configureSurface(tester);
        final environment = AddAccountTestEnvironment(
          addError: StateError('Storage failure'),
        );

        await environment.pumpHost(tester);
        await _openAddAccountPage(tester);
        await _enterTextVisible(
          tester,
          find.byType(TextField).first,
          'Travel fund',
        );

        await _tapVisible(
          tester,
          find.widgetWithText(FilledButton, 'Create account'),
        );
        await tester.pumpAndSettle();

        expect(find.text('Add account'), findsOneWidget);
        expect(find.text('Host home'), findsNothing);
        expect(
          find.text('Could not save the account. Please try again.'),
          findsOneWidget,
        );
        expect(
          find.widgetWithText(FilledButton, 'Create account'),
          findsOneWidget,
        );
        expect(find.text('Saving...'), findsNothing);
        expect(environment.accountRepository.accounts, isEmpty);
        expect(environment.accountRepository.addedAccounts, hasLength(1));
      },
    );

    testWidgets(
      'edit failure preserves the original account, stays in flow, and shows feedback',
      (tester) async {
        await _configureSurface(tester);
        final existingAccount = testAccount(
          id: 'account-existing',
          name: 'Original account',
          description: 'Original description',
          type: AccountType.bank,
          openingBalance: 10,
          currencyCode: 'EUR',
        );
        final environment = AddAccountTestEnvironment(
          accounts: [existingAccount],
          updateError: StateError('Update failure'),
        );

        await environment.pumpHost(tester, initialAccount: existingAccount);
        await _openAddAccountPage(tester);
        await _enterTextVisible(
          tester,
          find.byType(TextField).first,
          'Updated account',
        );

        await _tapVisible(
          tester,
          find.widgetWithText(FilledButton, 'Save changes'),
        );
        await tester.pumpAndSettle();

        expect(find.text('Edit account'), findsOneWidget);
        expect(find.text('Host home'), findsNothing);
        expect(
          find.text('Could not save the account. Please try again.'),
          findsOneWidget,
        );
        expect(environment.accountRepository.accounts, [existingAccount]);
        expect(environment.accountRepository.updatedAccounts, hasLength(1));
        expect(
          environment.accountRepository.updatedAccounts.single.id,
          existingAccount.id,
        );
        expect(
          environment.accountRepository.updatedAccounts.single.name,
          'Updated account',
        );
      },
    );
  });
}

Future<void> _openAddAccountPage(WidgetTester tester) async {
  await _tapVisible(
    tester,
    find.widgetWithText(FilledButton, 'Open add account'),
  );
  await tester.pumpAndSettle();
}

Future<void> _enterTextVisible(
  WidgetTester tester,
  Finder finder,
  String text,
) async {
  await tester.ensureVisible(finder);
  await tester.enterText(finder, text);
  await tester.pumpAndSettle();
}

Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.tap(finder);
}

Future<void> _configureSurface(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(800, 1200));
  addTearDown(() => tester.binding.setSurfaceSize(null));
}
