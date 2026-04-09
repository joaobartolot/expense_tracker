import 'package:expense_tracker/features/accounts/domain/models/account.dart';
import 'package:expense_tracker/features/categories/presentation/pages/category_detail_page.dart';
import 'package:expense_tracker/features/transactions/domain/models/transaction_item.dart';
import 'package:expense_tracker/features/transactions/presentation/pages/add_transaction_page.dart';
import 'package:expense_tracker/features/transactions/presentation/pages/home_page.dart';
import 'package:expense_tracker/features/transactions/presentation/pages/transaction_detail_page.dart';
import 'package:expense_tracker/features/transactions/presentation/widgets/transaction_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'delete_transaction_test_harness.dart';

void main() {
  group('transaction detail browsing behavior', () {
    testWidgets(
      'shows missing transaction fallback when transaction cannot be resolved',
      (tester) async {
        final environment = DeleteTestEnvironment();

        await environment.pumpApp(
          tester,
          home: const TransactionDetailPage(
            transactionId: 'missing-transaction',
          ),
        );

        expect(find.text('Transaction details'), findsOneWidget);
        expect(find.text('This transaction no longer exists.'), findsOneWidget);
        expect(find.text('Edit'), findsNothing);
        expect(find.text('Delete'), findsNothing);
      },
    );

    testWidgets(
      'shows expense detail header and overview for expense transaction',
      (tester) async {
        final environment = DeleteTestEnvironment(
          transactions: [
            expenseTransaction(
              id: 'tx-coffee',
              title: 'Coffee',
              date: daysAgo(0),
              amount: 12.5,
            ),
          ],
        );

        await environment.pumpApp(
          tester,
          home: const Scaffold(body: HomePage()),
        );
        await openTransactionDetailsFromHome(tester, 'Coffee');

        expect(find.text('Expense'), findsOneWidget);
        expect(find.text('Coffee'), findsOneWidget);
        expect(find.text('Category'), findsOneWidget);
        expect(find.text('Food'), findsOneWidget);
        expect(find.text('Account'), findsOneWidget);
        expect(find.text('Wallet'), findsOneWidget);
        expect(find.text('Overview'), findsOneWidget);
      },
    );

    testWidgets(
      'shows income detail header and overview for income transaction',
      (tester) async {
        final environment = DeleteTestEnvironment(
          transactions: [
            incomeTransaction(
              id: 'tx-salary',
              title: 'Salary',
              date: daysAgo(0),
              amount: 1000,
            ),
          ],
        );

        await environment.pumpApp(
          tester,
          home: const Scaffold(body: HomePage()),
        );
        await openTransactionDetailsFromHome(tester, 'Salary');

        expect(find.text('Income'), findsOneWidget);
        expect(find.text('Salary'), findsNWidgets(2));
        expect(find.text('+€1,000.00'), findsOneWidget);
        expect(find.text('Category'), findsOneWidget);
        expect(find.text('Account'), findsOneWidget);
        expect(find.text('Wallet'), findsOneWidget);
      },
    );

    testWidgets(
      'shows transfer detail header and from to accounts for transfer transaction',
      (tester) async {
        final environment = DeleteTestEnvironment(
          accounts: [walletAccount(), travelAccount()],
          transactions: [
            transferTransaction(
              id: 'tx-transfer',
              title: 'Trip fund',
              date: daysAgo(0),
            ),
          ],
        );

        await environment.pumpApp(
          tester,
          home: const Scaffold(body: HomePage()),
        );
        await openTransactionDetailsFromHome(tester, 'Trip fund');

        expect(find.text('Transfer'), findsWidgets);
        expect(find.text('Trip fund'), findsOneWidget);
        expect(find.text('From account'), findsOneWidget);
        expect(find.text('Wallet'), findsOneWidget);
        expect(find.text('To account'), findsOneWidget);
        expect(find.text('Travel'), findsOneWidget);
        expect(find.text('Category'), findsNothing);
      },
    );

    testWidgets(
      'shows entered and converted amount copy when transaction has foreign currency',
      (tester) async {
        final environment = DeleteTestEnvironment(
          transactions: [foreignExpenseTransaction()],
        );

        await environment.pumpApp(
          tester,
          home: const Scaffold(body: HomePage()),
        );
        await openTransactionDetailsFromHome(tester, 'Museum tickets');

        expect(find.text('Entered as \$20.00'), findsOneWidget);
        expect(find.text('Converted to EUR at 0.9200'), findsOneWidget);
      },
    );

    testWidgets(
      'shows card payment labels when transfer is credit card payment',
      (tester) async {
        final environment = DeleteTestEnvironment(
          accounts: [walletAccount(), creditCardAccount()],
          transactions: [
            creditCardPaymentTransaction(
              id: 'tx-card-payment',
              title: 'Card bill',
              date: daysAgo(0),
            ),
          ],
        );

        await environment.pumpApp(
          tester,
          home: const Scaffold(body: HomePage()),
        );
        await openTransactionDetailsFromHome(tester, 'Card bill');

        expect(find.text('Card payment'), findsWidgets);
        expect(find.text('Paid from'), findsOneWidget);
        expect(find.text('Wallet'), findsOneWidget);
        expect(find.text('Credit card'), findsOneWidget);
        expect(find.text('Daily card'), findsOneWidget);
      },
    );

    testWidgets(
      'shows unknown category fallback when category metadata is missing',
      (tester) async {
        final environment = DeleteTestEnvironment(
          categories: [salaryCategory()],
          transactions: [
            expenseTransaction(
              id: 'tx-coffee',
              title: 'Coffee',
              date: daysAgo(0),
            ),
          ],
        );

        await environment.pumpApp(
          tester,
          home: const Scaffold(body: HomePage()),
        );
        await openTransactionDetailsFromHome(tester, 'Coffee');

        expect(find.text('Unknown category'), findsOneWidget);
      },
    );

    testWidgets(
      'shows unknown account fallback when primary account metadata is missing',
      (tester) async {
        final environment = DeleteTestEnvironment(
          accounts: [travelAccount()],
          transactions: [
            expenseTransaction(
              id: 'tx-coffee',
              title: 'Coffee',
              date: daysAgo(0),
            ),
          ],
        );

        await environment.pumpApp(
          tester,
          home: const Scaffold(body: HomePage()),
        );
        await openTransactionDetailsFromHome(tester, 'Coffee');

        expect(find.text('Unknown account'), findsOneWidget);
      },
    );

    testWidgets(
      'shows unknown source and destination fallbacks when transfer account metadata is missing',
      (tester) async {
        final environment = DeleteTestEnvironment(
          accounts: const [],
          transactions: [
            transferTransaction(
              id: 'tx-transfer',
              title: 'Trip fund',
              date: daysAgo(0),
            ),
          ],
        );

        await environment.pumpApp(
          tester,
          home: const TransactionDetailPage(transactionId: 'tx-transfer'),
        );

        expect(find.text('Unknown account'), findsNWidgets(2));
      },
    );

    testWidgets('shows short date time and full date fields', (tester) async {
      final transaction = expenseTransaction(
        id: 'tx-lunch',
        title: 'Lunch',
        date: DateTime(2026, 4, 9, 14, 35),
      );
      final environment = DeleteTestEnvironment(transactions: [transaction]);

      await environment.pumpApp(
        tester,
        home: const TransactionDetailPage(transactionId: 'tx-lunch'),
      );

      final localizations = MaterialLocalizations.of(
        tester.element(find.byType(TransactionDetailPage)),
      );

      expect(find.text('Date'), findsOneWidget);
      expect(
        find.text(localizations.formatShortDate(transaction.date)),
        findsOneWidget,
      );
      expect(find.text('Time'), findsOneWidget);
      expect(
        find.text(
          localizations.formatTimeOfDay(
            TimeOfDay.fromDateTime(transaction.date),
          ),
        ),
        findsOneWidget,
      );
      expect(find.text('Full date'), findsOneWidget);
      expect(
        find.text(localizations.formatFullDate(transaction.date)),
        findsOneWidget,
      );
    });

    testWidgets(
      'tap category tile opens category detail page when category exists',
      (tester) async {
        final environment = DeleteTestEnvironment(
          transactions: [
            expenseTransaction(
              id: 'tx-coffee',
              title: 'Coffee',
              date: daysAgo(0),
            ),
          ],
        );

        await environment.pumpApp(
          tester,
          home: const Scaffold(body: HomePage()),
        );
        await openTransactionDetailsFromHome(tester, 'Coffee');

        await tapVisible(tester, find.text('Food'));
        await tester.pumpAndSettle();

        expect(find.byType(CategoryDetailPage), findsOneWidget);
        expect(find.text('Category details'), findsOneWidget);
      },
    );

    testWidgets('tap edit opens add transaction page in edit mode', (
      tester,
    ) async {
      final environment = DeleteTestEnvironment(
        transactions: [
          expenseTransaction(
            id: 'tx-coffee',
            title: 'Coffee',
            date: daysAgo(0),
          ),
        ],
      );

      await environment.pumpApp(tester, home: const Scaffold(body: HomePage()));
      await openTransactionDetailsFromHome(tester, 'Coffee');

      expect(find.text('Edit'), findsOneWidget);
      expect(find.text('Delete'), findsOneWidget);

      await tapVisible(tester, find.text('Edit'));
      await tester.pumpAndSettle();

      expect(find.byType(AddTransactionPage), findsOneWidget);
      expect(find.text('Edit transaction'), findsOneWidget);
    });
  });
}

Future<void> openTransactionDetailsFromHome(
  WidgetTester tester,
  String transactionTitle,
) async {
  expect(find.text(transactionTitle), findsOneWidget);
  await tapVisible(tester, find.byType(TransactionTile).first);
  await tester.pumpAndSettle();
}

TransactionItem transferTransaction({
  required String id,
  required String title,
  required DateTime date,
  double amount = 50,
}) {
  return TransactionItem(
    id: id,
    title: title,
    amount: amount,
    currencyCode: 'EUR',
    date: date,
    type: TransactionType.transfer,
    sourceAccountId: 'account-wallet',
    destinationAccountId: 'account-travel',
    destinationAmount: amount,
    destinationCurrencyCode: 'EUR',
  );
}

TransactionItem creditCardPaymentTransaction({
  required String id,
  required String title,
  required DateTime date,
  double amount = 120,
}) {
  return TransactionItem(
    id: id,
    title: title,
    amount: amount,
    currencyCode: 'EUR',
    date: date,
    type: TransactionType.transfer,
    sourceAccountId: 'account-wallet',
    destinationAccountId: 'account-credit-card',
    destinationAmount: amount,
    destinationCurrencyCode: 'EUR',
    transferKind: TransactionTransferKind.creditCardPayment,
  );
}

TransactionItem foreignExpenseTransaction() {
  return TransactionItem(
    id: 'tx-foreign-expense',
    title: 'Museum tickets',
    amount: 18.4,
    currencyCode: 'EUR',
    date: daysAgo(0),
    type: TransactionType.expense,
    accountId: 'account-wallet',
    categoryId: 'category-food',
    foreignAmount: 20,
    foreignCurrencyCode: 'USD',
    exchangeRate: 0.92,
  );
}

Account creditCardAccount() {
  return const Account(
    id: 'account-credit-card',
    name: 'Daily card',
    type: AccountType.creditCard,
    openingBalance: 0,
    currencyCode: 'EUR',
  );
}
