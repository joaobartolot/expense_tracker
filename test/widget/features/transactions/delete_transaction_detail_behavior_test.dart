import 'package:expense_tracker/features/transactions/presentation/pages/home_page.dart';
import 'package:expense_tracker/features/transactions/presentation/widgets/transaction_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'delete_transaction_test_harness.dart';

void main() {
  group('transaction detail delete behavior', () {
    testWidgets('delete shows confirmation dialog', (tester) async {
      final transaction = expenseTransaction(
        id: 'tx-lunch',
        title: 'Lunch',
        date: daysAgo(0),
      );
      final environment = DeleteTestEnvironment(transactions: [transaction]);

      await environment.pumpApp(tester, home: const Scaffold(body: HomePage()));
      await openTransactionDetailsFromHome(tester, 'Lunch');

      expect(find.text('Transaction details'), findsOneWidget);
      await tapVisible(tester, find.text('Delete'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('Delete transaction?'), findsOneWidget);
      expect(
        find.text('This transaction will be removed from your history.'),
        findsOneWidget,
      );
      expect(find.widgetWithText(TextButton, 'Cancel'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.widgetWithText(FilledButton, 'Delete'),
        ),
        findsOneWidget,
      );
    });

    testWidgets(
      'delete cancel keeps the transaction and stays on the detail page',
      (tester) async {
        final transaction = expenseTransaction(
          id: 'tx-coffee',
          title: 'Coffee',
          date: daysAgo(0),
        );
        final environment = DeleteTestEnvironment(transactions: [transaction]);

        await environment.pumpApp(
          tester,
          home: const Scaffold(body: HomePage()),
        );
        await openTransactionDetailsFromHome(tester, 'Coffee');
        expect(find.text('Transaction details'), findsOneWidget);
        await tapVisible(tester, find.text('Delete'));
        await tester.pumpAndSettle();

        await cancelDeleteDialog(tester);

        expect(find.text('Transaction details'), findsOneWidget);
        expect(find.text('Coffee'), findsOneWidget);
        expect(environment.transactionRepository.transactions, hasLength(1));
        expect(
          environment.transactionRepository.transactions.single.id,
          'tx-coffee',
        );
        expect(find.text('Delete transaction?'), findsNothing);
      },
    );

    testWidgets(
      'delete confirm removes the transaction and pops with a success result',
      (tester) async {
        final transaction = expenseTransaction(
          id: 'tx-groceries',
          title: 'Groceries',
          date: daysAgo(0),
        );
        final environment = DeleteTestEnvironment(transactions: [transaction]);

        await environment.pumpApp(
          tester,
          home: const Scaffold(body: HomePage()),
        );
        await openTransactionDetailsFromHome(tester, 'Groceries');
        expect(find.text('Transaction details'), findsOneWidget);
        await tapVisible(tester, find.text('Delete'));
        await tester.pumpAndSettle();

        await confirmDeleteDialog(tester);

        expect(find.text('Transaction details'), findsNothing);
        expect(find.text('Groceries'), findsNothing);
        expect(environment.transactionRepository.transactions, isEmpty);
        expect(environment.transactionBalanceService.deletedTransactionIds, [
          'tx-groceries',
        ]);
      },
    );

    testWidgets(
      'delete failure keeps the transaction, does not pop, and does not show missing-state UI',
      (tester) async {
        final transaction = expenseTransaction(
          id: 'tx-rent',
          title: 'Rent',
          date: daysAgo(0),
        );
        final environment = DeleteTestEnvironment(
          transactions: [transaction],
          deleteError: StateError('delete failed'),
        );

        await environment.pumpApp(
          tester,
          home: const Scaffold(body: HomePage()),
        );
        await openTransactionDetailsFromHome(tester, 'Rent');
        expect(find.text('Transaction details'), findsOneWidget);
        await tapVisible(tester, find.text('Delete'));
        await tester.pumpAndSettle();

        await confirmDeleteDialog(tester);
        expect(find.text('Transaction details'), findsOneWidget);
        expect(find.text('Rent'), findsOneWidget);
        expect(find.text('This transaction no longer exists.'), findsNothing);
        expect(
          find.text('Could not delete the transaction. Please try again.'),
          findsOneWidget,
        );
        expect(environment.transactionRepository.transactions, hasLength(1));
        expect(
          environment.transactionRepository.transactions.single.id,
          'tx-rent',
        );
        expect(find.text('Delete transaction?'), findsNothing);
      },
    );
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
