import 'package:expense_tracker/app/state/app_state_provider.dart';
import 'package:expense_tracker/app/state/app_state_snapshot.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:expense_tracker/features/transactions/presentation/pages/transaction_history_page.dart';

import 'delete_transaction_test_harness.dart';

void main() {
  group('transaction history delete behavior', () {
    testWidgets('long-press menu exposes delete action', (tester) async {
      final environment = DeleteTestEnvironment(
        transactions: [
          expenseTransaction(
            id: 'tx-coffee',
            title: 'Coffee',
            date: daysAgo(0),
          ),
          expenseTransaction(
            id: 'tx-groceries',
            title: 'Groceries',
            date: daysAgo(2),
          ),
        ],
      );

      await environment.pumpApp(tester, home: const TransactionHistoryPage());

      await longPressVisible(tester, find.text('Coffee'));

      expect(find.text('Edit'), findsOneWidget);
      expect(find.text('Delete'), findsOneWidget);
    });

    testWidgets('delete cancel keeps the transaction visible in history', (
      tester,
    ) async {
      final environment = DeleteTestEnvironment(
        transactions: [
          expenseTransaction(id: 'tx-lunch', title: 'Lunch', date: daysAgo(0)),
        ],
      );

      await environment.pumpApp(tester, home: const TransactionHistoryPage());

      await openContextDeleteAction(tester, 'Lunch');
      await cancelDeleteDialog(tester);

      expect(find.text('Lunch'), findsOneWidget);
      expect(environment.transactionRepository.transactions, hasLength(1));
    });

    testWidgets(
      'delete confirm removes the transaction and preserves search, filter, and sort controls',
      (tester) async {
        final environment = DeleteTestEnvironment(
          transactions: [
            expenseTransaction(
              id: 'tx-coffee',
              title: 'Coffee',
              date: daysAgo(0),
            ),
            expenseTransaction(
              id: 'tx-groceries',
              title: 'Groceries',
              date: daysAgo(3),
            ),
            incomeTransaction(
              id: 'tx-salary',
              title: 'Salary',
              date: daysAgo(1),
            ),
          ],
        );

        await environment.pumpApp(tester, home: const TransactionHistoryPage());

        await selectHistoryExpenseFilter(tester);
        await selectHistoryOldestFirstSort(tester);
        await enterHistorySearchQuery(tester, 'coffee');

        await openContextDeleteAction(tester, 'Coffee');
        await confirmDeleteDialog(tester);

        expect(find.text('Coffee'), findsNothing);
        expect(environment.transactionRepository.transactions, hasLength(2));
        expect(
          environment.transactionRepository.transactions.map((item) => item.id),
          ['tx-groceries', 'tx-salary'],
        );
        expect(find.text('No transactions match your search.'), findsOneWidget);
        final container = ProviderScope.containerOf(
          tester.element(find.byType(TransactionHistoryPage)),
        );
        final state = container.read(appStateProvider);
        expect(state.historyFilter, TransactionHistoryFilter.expense);
        expect(state.historySort, TransactionHistorySort.oldestFirst);
        expect(state.historySearchQuery, 'coffee');
      },
    );

    testWidgets(
      'delete failure keeps the transaction visible and preserves the current history controls',
      (tester) async {
        final environment = DeleteTestEnvironment(
          transactions: [
            expenseTransaction(id: 'tx-rent', title: 'Rent', date: daysAgo(0)),
            expenseTransaction(id: 'tx-gas', title: 'Gas', date: daysAgo(2)),
          ],
          deleteError: StateError('delete failed'),
        );

        await environment.pumpApp(tester, home: const TransactionHistoryPage());

        await selectHistoryExpenseFilter(tester);
        await enterHistorySearchQuery(tester, 'rent');
        await openContextDeleteAction(tester, 'Rent');
        await confirmDeleteDialog(tester);
        expect(
          find.text('Could not delete the transaction. Please try again.'),
          findsOneWidget,
        );
        final searchField = tester.widget<TextField>(find.byType(TextField));
        expect(searchField.controller?.text, 'rent');
        expect(find.text('Rent'), findsOneWidget);
        expect(environment.transactionRepository.transactions, hasLength(2));
        final container = ProviderScope.containerOf(
          tester.element(find.byType(TransactionHistoryPage)),
        );
        final state = container.read(appStateProvider);
        expect(state.historyFilter, TransactionHistoryFilter.expense);
        expect(state.historySearchQuery, 'rent');
      },
    );
  });
}
