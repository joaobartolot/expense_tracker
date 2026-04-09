import 'package:expense_tracker/features/transactions/presentation/pages/home_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'delete_transaction_test_harness.dart';

void main() {
  group('home page delete behavior', () {
    testWidgets('long-press menu exposes delete action', (tester) async {
      final environment = DeleteTestEnvironment(
        transactions: [
          expenseTransaction(
            id: 'tx-coffee',
            title: 'Coffee',
            date: daysAgo(0),
          ),
          incomeTransaction(id: 'tx-salary', title: 'Salary', date: daysAgo(1)),
        ],
      );

      await environment.pumpApp(tester, home: const Scaffold(body: HomePage()));

      await longPressVisible(tester, find.text('Coffee'));

      expect(find.text('Edit'), findsOneWidget);
      expect(find.text('Delete'), findsOneWidget);
    });

    testWidgets(
      'delete cancel keeps the transaction visible in the home list',
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

        await openContextDeleteAction(tester, 'Coffee');
        expect(find.text('Delete transaction?'), findsOneWidget);

        await cancelDeleteDialog(tester);

        expect(find.text('Coffee'), findsOneWidget);
        expect(environment.transactionRepository.transactions, hasLength(1));
        expect(find.textContaining('Nothing recorded for'), findsNothing);
      },
    );

    testWidgets(
      'delete confirm removes the transaction from home and shows the empty-period state',
      (tester) async {
        final environment = DeleteTestEnvironment(
          transactions: [
            expenseTransaction(
              id: 'tx-groceries',
              title: 'Groceries',
              date: daysAgo(0),
            ),
          ],
        );

        await environment.pumpApp(
          tester,
          home: const Scaffold(body: HomePage()),
        );

        await openContextDeleteAction(tester, 'Groceries');
        await confirmDeleteDialog(tester);

        expect(find.text('Groceries'), findsNothing);
        expect(environment.transactionRepository.transactions, isEmpty);
        expect(find.textContaining('Nothing recorded for'), findsOneWidget);
        expect(find.text('View more'), findsNothing);
      },
    );

    testWidgets(
      'delete failure keeps the transaction visible and does not produce false success',
      (tester) async {
        final environment = DeleteTestEnvironment(
          transactions: [
            expenseTransaction(id: 'tx-rent', title: 'Rent', date: daysAgo(0)),
          ],
          deleteError: StateError('delete failed'),
        );

        await environment.pumpApp(
          tester,
          home: const Scaffold(body: HomePage()),
        );

        await openContextDeleteAction(tester, 'Rent');
        await confirmDeleteDialog(tester);
        expect(find.text('Rent'), findsOneWidget);
        expect(
          find.text('Could not delete the transaction. Please try again.'),
          findsOneWidget,
        );
        expect(environment.transactionRepository.transactions, hasLength(1));
        expect(
          environment.transactionRepository.transactions.single.id,
          'tx-rent',
        );
        expect(find.textContaining('Nothing recorded for'), findsNothing);
      },
    );
  });
}
