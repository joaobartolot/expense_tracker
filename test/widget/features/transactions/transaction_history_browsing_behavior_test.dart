import 'package:expense_tracker/app/state/app_state_dependencies.dart';
import 'package:expense_tracker/app/state/app_state_provider.dart';
import 'package:expense_tracker/features/transactions/domain/models/transaction_item.dart';
import 'package:expense_tracker/features/transactions/presentation/pages/transaction_detail_page.dart';
import 'package:expense_tracker/features/transactions/presentation/pages/transaction_history_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'delete_transaction_test_harness.dart';

void main() {
  group('transaction history browsing behavior', () {
    testWidgets('shows a loading indicator while app state is loading', (
      tester,
    ) async {
      final environment = DeleteTestEnvironment();

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
          ],
          child: const MaterialApp(home: TransactionHistoryPage()),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Transactions'), findsOneWidget);
    });

    testWidgets('shows an all-transactions empty label when history is empty', (
      tester,
    ) async {
      final environment = DeleteTestEnvironment(transactions: const []);

      await environment.pumpApp(tester, home: const TransactionHistoryPage());

      expect(find.text('No transactions yet.'), findsOneWidget);
    });

    testWidgets('shows an income empty label when no income matches', (
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

      await environment.pumpApp(tester, home: const TransactionHistoryPage());

      await openHistoryFilter(tester);
      await tapVisible(tester, find.text('Income'));
      await tester.pumpAndSettle();

      expect(
        find.text('No income transactions match this filter.'),
        findsOneWidget,
      );
    });

    testWidgets('shows an expense empty label when no expense matches', (
      tester,
    ) async {
      final environment = DeleteTestEnvironment(
        transactions: [
          incomeTransaction(id: 'tx-salary', title: 'Salary', date: daysAgo(0)),
        ],
      );

      await environment.pumpApp(tester, home: const TransactionHistoryPage());

      await openHistoryFilter(tester);
      await tapVisible(tester, find.text('Expenses'));
      await tester.pumpAndSettle();

      expect(
        find.text('No expense transactions match this filter.'),
        findsOneWidget,
      );
    });

    testWidgets('shows a transfer empty label when no transfer matches', (
      tester,
    ) async {
      final environment = DeleteTestEnvironment(
        transactions: [
          expenseTransaction(
            id: 'tx-groceries',
            title: 'Groceries',
            date: daysAgo(0),
          ),
        ],
      );

      await environment.pumpApp(tester, home: const TransactionHistoryPage());

      await openHistoryFilter(tester);
      await tapVisible(tester, find.text('Transfers'));
      await tester.pumpAndSettle();

      expect(
        find.text('No transfer transactions match this filter.'),
        findsOneWidget,
      );
    });

    testWidgets('shows a search empty label when search has no matches', (
      tester,
    ) async {
      final environment = DeleteTestEnvironment(
        transactions: [
          expenseTransaction(id: 'tx-lunch', title: 'Lunch', date: daysAgo(0)),
        ],
      );

      await environment.pumpApp(tester, home: const TransactionHistoryPage());
      await enterHistorySearchQuery(tester, 'rent');

      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Search transactions'), findsOneWidget);
      expect(find.text('No transactions match your search.'), findsOneWidget);
    });

    testWidgets('search query filters visible transactions by title', (
      tester,
    ) async {
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
            date: daysAgo(1),
          ),
        ],
      );

      await environment.pumpApp(tester, home: const TransactionHistoryPage());
      await enterHistorySearchQuery(tester, 'coffee');

      expect(find.text('Coffee'), findsOneWidget);
      expect(find.text('Groceries'), findsNothing);
    });

    testWidgets('search query filters by category and account metadata', (
      tester,
    ) async {
      final environment = DeleteTestEnvironment(
        accounts: [walletAccount(), travelAccount()],
        transactions: [
          expenseTransaction(
            id: 'tx-coffee',
            title: 'Coffee',
            date: daysAgo(0),
          ),
          transferTransaction(
            id: 'tx-trip',
            title: 'Trip fund',
            date: daysAgo(1),
          ),
        ],
      );

      await environment.pumpApp(tester, home: const TransactionHistoryPage());

      await enterHistorySearchQuery(tester, 'food');
      expect(find.text('Coffee'), findsOneWidget);
      expect(find.text('Trip fund'), findsNothing);

      await enterHistorySearchQuery(tester, 'travel');
      expect(find.text('Coffee'), findsNothing);
      expect(find.text('Trip fund'), findsOneWidget);
    });

    testWidgets('search query trims and normalizes input through app state', (
      tester,
    ) async {
      final environment = DeleteTestEnvironment(
        transactions: [
          incomeTransaction(id: 'tx-salary', title: 'Salary', date: daysAgo(0)),
        ],
      );

      await environment.pumpApp(tester, home: const TransactionHistoryPage());
      await enterHistorySearchQuery(tester, '  SALARY  ');

      expect(find.text('Salary'), findsOneWidget);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(TransactionHistoryPage)),
      );
      expect(container.read(appStateProvider).historySearchQuery, 'salary');
    });

    testWidgets('clear search resets the query and restores all results', (
      tester,
    ) async {
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
            date: daysAgo(1),
          ),
        ],
      );

      await environment.pumpApp(tester, home: const TransactionHistoryPage());
      await enterHistorySearchQuery(tester, 'coffee');
      await tapVisible(tester, find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();

      final searchField = tester.widget<TextField>(find.byType(TextField));
      expect(searchField.controller?.text, isEmpty);
      expect(find.text('Coffee'), findsOneWidget);
      expect(find.text('Groceries'), findsOneWidget);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(TransactionHistoryPage)),
      );
      expect(container.read(appStateProvider).historySearchQuery, '');
    });

    testWidgets('sort button opens the sort sheet with the current selection', (
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

      await environment.pumpApp(tester, home: const TransactionHistoryPage());
      await tapVisible(tester, find.byTooltip('Sort'));
      await tester.pumpAndSettle();

      expect(find.text('Newest first'), findsOneWidget);
      expect(find.text('Oldest first'), findsOneWidget);
      expect(
        find.descendant(
          of: listTileWithText('Newest first'),
          matching: find.byIcon(Icons.check_rounded),
        ),
        findsOneWidget,
      );
    });

    testWidgets('selecting newest first updates the visible order', (
      tester,
    ) async {
      final environment = DeleteTestEnvironment(
        transactions: [
          expenseTransaction(id: 'tx-older', title: 'Older', date: daysAgo(3)),
          expenseTransaction(id: 'tx-newer', title: 'Newer', date: daysAgo(0)),
        ],
      );

      await environment.pumpApp(tester, home: const TransactionHistoryPage());
      await selectHistoryOldestFirstSort(tester);
      await tapVisible(tester, find.byTooltip('Sort'));
      await tester.pumpAndSettle();
      await tapVisible(tester, find.text('Newest first'));
      await tester.pumpAndSettle();

      expect(titleTop(tester, 'Newer'), lessThan(titleTop(tester, 'Older')));
    });

    testWidgets('selecting oldest first updates the visible order', (
      tester,
    ) async {
      final environment = DeleteTestEnvironment(
        transactions: [
          expenseTransaction(id: 'tx-older', title: 'Older', date: daysAgo(3)),
          expenseTransaction(id: 'tx-newer', title: 'Newer', date: daysAgo(0)),
        ],
      );

      await environment.pumpApp(tester, home: const TransactionHistoryPage());
      await selectHistoryOldestFirstSort(tester);

      expect(titleTop(tester, 'Older'), lessThan(titleTop(tester, 'Newer')));
    });

    testWidgets('changing sort resets the visible count to the first page', (
      tester,
    ) async {
      final environment = DeleteTestEnvironment(
        transactions: pagedExpenseTransactions(22),
      );

      await environment.pumpApp(tester, home: const TransactionHistoryPage());
      await scrollUntilTransactionVisible(tester, 'Expense 21');

      expect(find.text('Expense 21'), findsOneWidget);

      await selectHistoryOldestFirstSort(tester);

      expect(find.text('Expense 01'), findsNothing);
      expect(find.text('Expense 00'), findsNothing);
    });

    testWidgets(
      'filter button opens the filter sheet with the current selection',
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

        await environment.pumpApp(tester, home: const TransactionHistoryPage());
        await openHistoryFilter(tester);

        expect(find.text('All transactions'), findsOneWidget);
        expect(find.text('Income'), findsOneWidget);
        expect(find.text('Expenses'), findsOneWidget);
        expect(find.text('Transfers'), findsOneWidget);
        expect(
          find.descendant(
            of: listTileWithText('All transactions'),
            matching: find.byIcon(Icons.check_rounded),
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets('selecting all transactions shows all result types', (
      tester,
    ) async {
      final environment = DeleteTestEnvironment(
        transactions: [
          expenseTransaction(
            id: 'tx-coffee',
            title: 'Coffee',
            date: daysAgo(0),
          ),
          incomeTransaction(id: 'tx-salary', title: 'Salary', date: daysAgo(1)),
          transferTransaction(
            id: 'tx-trip',
            title: 'Trip fund',
            date: daysAgo(2),
          ),
        ],
      );

      await environment.pumpApp(tester, home: const TransactionHistoryPage());
      await selectHistoryExpenseFilter(tester);
      await openHistoryFilter(tester);
      await tapVisible(tester, find.text('All transactions'));
      await tester.pumpAndSettle();

      expect(find.text('Coffee'), findsOneWidget);
      expect(find.text('Salary'), findsOneWidget);
      expect(find.text('Trip fund'), findsOneWidget);
    });

    testWidgets('selecting income shows only income results', (tester) async {
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

      await environment.pumpApp(tester, home: const TransactionHistoryPage());
      await openHistoryFilter(tester);
      await tapVisible(tester, find.text('Income'));
      await tester.pumpAndSettle();

      expect(find.text('Salary'), findsOneWidget);
      expect(find.text('Coffee'), findsNothing);
    });

    testWidgets('selecting expenses shows only expense results', (
      tester,
    ) async {
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

      await environment.pumpApp(tester, home: const TransactionHistoryPage());
      await selectHistoryExpenseFilter(tester);

      expect(find.text('Coffee'), findsOneWidget);
      expect(find.text('Salary'), findsNothing);
    });

    testWidgets('selecting transfers shows only transfer results', (
      tester,
    ) async {
      final environment = DeleteTestEnvironment(
        transactions: [
          expenseTransaction(
            id: 'tx-coffee',
            title: 'Coffee',
            date: daysAgo(0),
          ),
          transferTransaction(
            id: 'tx-trip',
            title: 'Trip fund',
            date: daysAgo(1),
          ),
        ],
      );

      await environment.pumpApp(tester, home: const TransactionHistoryPage());
      await openHistoryFilter(tester);
      await tapVisible(tester, find.text('Transfers'));
      await tester.pumpAndSettle();

      expect(find.text('Trip fund'), findsOneWidget);
      expect(find.text('Coffee'), findsNothing);
    });

    testWidgets('changing filter resets the visible count to the first page', (
      tester,
    ) async {
      final environment = DeleteTestEnvironment(
        transactions: [
          ...pagedExpenseTransactions(22),
          incomeTransaction(
            id: 'tx-salary',
            title: 'Salary',
            date: daysAgo(30),
          ),
        ],
      );

      await environment.pumpApp(tester, home: const TransactionHistoryPage());
      await scrollUntilTransactionVisible(tester, 'Expense 21');

      expect(find.text('Expense 21'), findsOneWidget);

      await selectHistoryExpenseFilter(tester);

      expect(find.text('Expense 20'), findsNothing);
      expect(find.text('Expense 21'), findsNothing);
    });

    testWidgets('shows only the first page initially when more results exist', (
      tester,
    ) async {
      final environment = DeleteTestEnvironment(
        transactions: pagedExpenseTransactions(25),
      );

      await environment.pumpApp(tester, home: const TransactionHistoryPage());

      expect(find.text('Expense 00'), findsOneWidget);
      expect(find.text('Expense 20'), findsNothing);
      expect(find.text('Expense 24'), findsNothing);
    });

    testWidgets('scrolling near the bottom loads more results', (tester) async {
      final environment = DeleteTestEnvironment(
        transactions: pagedExpenseTransactions(25),
      );

      await environment.pumpApp(tester, home: const TransactionHistoryPage());
      await scrollUntilTransactionVisible(tester, 'Expense 24');

      expect(find.text('Expense 24'), findsOneWidget);
    });

    testWidgets(
      'loading more shows a progress indicator near the list bottom',
      (tester) async {
        final environment = DeleteTestEnvironment(
          transactions: pagedExpenseTransactions(25),
        );

        await environment.pumpApp(tester, home: const TransactionHistoryPage());

        expect(find.byType(CircularProgressIndicator), findsOneWidget);
      },
    );

    testWidgets('does not load more when all results are already visible', (
      tester,
    ) async {
      final environment = DeleteTestEnvironment(
        transactions: pagedExpenseTransactions(3),
      );

      await environment.pumpApp(tester, home: const TransactionHistoryPage());
      await tester.drag(find.byType(ListView), const Offset(0, -1000));
      await tester.pumpAndSettle();

      expect(find.text('Expense 00'), findsOneWidget);
      expect(find.text('Expense 02'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('search changes reset pagination back to the first page', (
      tester,
    ) async {
      final environment = DeleteTestEnvironment(
        transactions: pagedExpenseTransactions(22),
      );

      await environment.pumpApp(tester, home: const TransactionHistoryPage());
      await scrollUntilTransactionVisible(tester, 'Expense 21');

      expect(find.text('Expense 21'), findsOneWidget);

      await tester.drag(find.byType(ListView), const Offset(0, 3000));
      await tester.pumpAndSettle();
      await enterHistorySearchQuery(tester, 'expense');

      expect(find.text('Expense 20'), findsNothing);
      expect(find.text('Expense 21'), findsNothing);
    });

    testWidgets('tapping a transaction opens the detail page', (tester) async {
      final environment = DeleteTestEnvironment(
        transactions: [
          expenseTransaction(
            id: 'tx-coffee',
            title: 'Coffee',
            date: daysAgo(0),
          ),
        ],
      );

      await environment.pumpApp(tester, home: const TransactionHistoryPage());
      await tapVisible(tester, find.text('Coffee'));
      await tester.pumpAndSettle();

      expect(find.byType(TransactionDetailPage), findsOneWidget);
      expect(find.text('Transaction details'), findsOneWidget);
      expect(find.text('Coffee'), findsOneWidget);
    });

    testWidgets(
      'long-pressing a transaction opens an action menu with edit and delete',
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

        await environment.pumpApp(tester, home: const TransactionHistoryPage());
        await longPressVisible(tester, find.text('Coffee'));

        expect(find.text('Edit'), findsOneWidget);
        expect(find.text('Delete'), findsOneWidget);
      },
    );
  });
}

Future<void> openHistoryFilter(WidgetTester tester) async {
  await tapVisible(tester, find.byTooltip('Filter'));
  await tester.pumpAndSettle();
}

Future<void> scrollHistoryToBottom(WidgetTester tester) async {
  await tester.drag(find.byType(ListView), const Offset(0, -3000));
  await tester.pump();
  await tester.pump();
  await tester.pumpAndSettle();
}

Future<void> scrollUntilTransactionVisible(
  WidgetTester tester,
  String title,
) async {
  await tester.scrollUntilVisible(
    find.text(title),
    300,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
}

double titleTop(WidgetTester tester, String title) {
  return tester.getTopLeft(find.text(title).first).dy;
}

List<TransactionItem> pagedExpenseTransactions(int count) {
  return List.generate(
    count,
    (index) => expenseTransaction(
      id: 'tx-expense-$index',
      title: 'Expense ${index.toString().padLeft(2, '0')}',
      date: daysAgo(index),
    ),
  );
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
