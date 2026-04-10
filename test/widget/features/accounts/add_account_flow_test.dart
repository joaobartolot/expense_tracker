import 'package:expense_tracker/core/widgets/custom_dropdown_selector.dart';
import 'package:expense_tracker/features/accounts/domain/models/account.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'add_account_test_harness.dart';

void main() {
  late AddAccountTestEnvironment environment;

  setUp(() {
    environment = AddAccountTestEnvironment();
  });

  group('add account flow', () {
    testWidgets(
      'create trims inputs, uses the generated id, and pops true on success',
      (tester) async {
        await _configureSurface(tester);
        await environment.pumpHost(tester);
        await _openAddAccountPage(tester);

        await _enterTextVisible(
          tester,
          find.byType(TextField).first,
          '  Main checking  ',
        );
        await _enterTextVisible(
          tester,
          find.byType(TextField).at(1),
          '  Daily spending account  ',
        );
        await _updateBalanceValue(
          tester,
          const TextEditingValue(
            text: '12345',
            selection: TextSelection.collapsed(offset: 5),
          ),
        );
        await _tapVisible(tester, find.text('Main account'));

        await _tapVisible(
          tester,
          find.widgetWithText(FilledButton, 'Create account'),
        );
        await tester.pumpAndSettle();

        expect(environment.accountRepository.createAccountIdCallCount, 1);
        expect(environment.accountRepository.addedAccounts, hasLength(1));
        expect(
          environment.accountRepository.addedAccounts.single,
          isA<Account>()
              .having((account) => account.id, 'id', 'generated-account-id')
              .having((account) => account.name, 'name', 'Main checking')
              .having(
                (account) => account.description,
                'description',
                'Daily spending account',
              )
              .having((account) => account.type, 'type', AccountType.bank)
              .having(
                (account) => account.openingBalance,
                'openingBalance',
                123.45,
              )
              .having((account) => account.currencyCode, 'currencyCode', 'EUR')
              .having((account) => account.isPrimary, 'isPrimary', isTrue)
              .having(
                (account) => account.creditCardDueDay,
                'creditCardDueDay',
                isNull,
              )
              .having(
                (account) => account.paymentTracking,
                'paymentTracking',
                isNull,
              ),
        );
        expect(find.text('Host home'), findsOneWidget);
        expect(find.text('Last result: true'), findsOneWidget);
      },
    );

    testWidgets('empty-name submit shows validation and does not save', (
      tester,
    ) async {
      await _configureSurface(tester);
      await environment.pumpHost(tester);
      await _openAddAccountPage(tester);

      await _tapVisible(
        tester,
        find.widgetWithText(FilledButton, 'Create account'),
      );
      await tester.pumpAndSettle();

      expect(find.text('Please give this account a name.'), findsOneWidget);
      expect(environment.accountRepository.createAccountIdCallCount, 0);
      expect(environment.accountRepository.addedAccounts, isEmpty);
      expect(find.text('Add account'), findsOneWidget);
    });

    testWidgets(
      'credit-card create reveals card fields and saves due day and payment tracking',
      (tester) async {
        await _configureSurface(tester);
        await environment.pumpHost(tester);
        await _openAddAccountPage(tester);

        await _enterTextVisible(
          tester,
          find.byType(TextField).first,
          'Travel card',
        );
        await _selectDropdownOption<AccountType>(
          tester,
          'Account type',
          'Credit card',
        );
        await _tapVisible(tester, find.text('Day 1'));
        await tester.pumpAndSettle();
        await _tapVisible(tester, find.text('15'));
        await tester.pumpAndSettle();
        await _tapVisible(tester, find.widgetWithText(FilledButton, 'Confirm'));
        await tester.pumpAndSettle();
        await _tapVisible(tester, find.text('Auto'));
        await tester.pumpAndSettle();

        expect(find.text('Credit card details'), findsOneWidget);
        expect(find.text('Payment due day'), findsOneWidget);
        expect(find.text('Payment tracking'), findsOneWidget);

        await _tapVisible(
          tester,
          find.widgetWithText(FilledButton, 'Create account'),
        );
        await tester.pumpAndSettle();

        expect(
          environment.accountRepository.addedAccounts.single.creditCardDueDay,
          15,
        );
        expect(
          environment.accountRepository.addedAccounts.single.paymentTracking,
          CreditCardPaymentTracking.automatic,
        );
      },
    );

    testWidgets(
      'edit preloads the existing values, preserves the id, and can clear credit-card metadata by changing type',
      (tester) async {
        await _configureSurface(tester);
        final existingAccount = testAccount(
          id: 'account-card',
          name: 'Travel card',
          description: 'Old description',
          type: AccountType.creditCard,
          openingBalance: 42.5,
          currencyCode: 'USD',
          isPrimary: true,
          creditCardDueDay: 14,
          paymentTracking: CreditCardPaymentTracking.automatic,
        );
        environment = AddAccountTestEnvironment(accounts: [existingAccount]);

        await environment.pumpHost(tester, initialAccount: existingAccount);
        await _openAddAccountPage(tester);

        expect(find.text('Edit account'), findsOneWidget);
        expect(find.text('Update this opening balance'), findsOneWidget);
        expect(
          tester
              .widget<TextField>(find.byType(TextField).first)
              .controller!
              .text,
          'Travel card',
        );
        expect(
          tester
              .widget<TextField>(find.byType(TextField).at(1))
              .controller!
              .text,
          'Old description',
        );
        expect(_balanceText(tester), '42.50');
        expect(find.text('USD'), findsAtLeastNWidgets(1));
        expect(find.text('Day 14'), findsOneWidget);

        await _enterTextVisible(
          tester,
          find.byType(TextField).first,
          'Updated wallet',
        );
        await _selectDropdownOption<AccountType>(
          tester,
          'Account type',
          'Cash',
        );

        expect(find.text('Credit card details'), findsNothing);

        await _tapVisible(
          tester,
          find.widgetWithText(FilledButton, 'Save changes'),
        );
        await tester.pumpAndSettle();

        expect(environment.accountRepository.createAccountIdCallCount, 0);
        expect(environment.accountRepository.updatedAccounts, hasLength(1));
        expect(
          environment.accountRepository.updatedAccounts.single,
          isA<Account>()
              .having((account) => account.id, 'id', existingAccount.id)
              .having((account) => account.name, 'name', 'Updated wallet')
              .having((account) => account.type, 'type', AccountType.cash)
              .having(
                (account) => account.creditCardDueDay,
                'creditCardDueDay',
                isNull,
              )
              .having(
                (account) => account.paymentTracking,
                'paymentTracking',
                isNull,
              ),
        );
        expect(find.text('Last result: true'), findsOneWidget);
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

Future<void> _updateBalanceValue(
  WidgetTester tester,
  TextEditingValue value,
) async {
  _balanceField(tester).controller!.value = value;
  await tester.pumpAndSettle();
}

TextField _balanceField(WidgetTester tester) {
  return tester.widget<TextField>(find.byType(TextField).at(2));
}

String _balanceText(WidgetTester tester) {
  return _balanceField(tester).controller!.text;
}

Future<void> _selectDropdownOption<T>(
  WidgetTester tester,
  String label,
  String optionLabel,
) async {
  final selector = find.byWidgetPredicate(
    (widget) => widget is CustomDropdownSelector<T> && widget.label == label,
  );
  await _tapVisible(
    tester,
    find.descendant(of: selector, matching: find.byType(InkWell)).first,
  );
  await tester.pumpAndSettle();
  await _tapVisible(
    tester,
    find.descendant(of: selector, matching: find.text(optionLabel)).last,
  );
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
