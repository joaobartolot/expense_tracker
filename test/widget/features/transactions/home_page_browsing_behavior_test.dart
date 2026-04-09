import 'package:expense_tracker/app/state/app_state_dependencies.dart';
import 'package:expense_tracker/core/utils/currency_conversion_service.dart';
import 'package:expense_tracker/core/utils/currency_formatter.dart';
import 'package:expense_tracker/features/accounts/domain/models/account.dart';
import 'package:expense_tracker/features/transactions/domain/models/transaction_item.dart';
import 'package:expense_tracker/features/transactions/presentation/pages/add_transaction_page.dart';
import 'package:expense_tracker/features/transactions/presentation/pages/home_page.dart';
import 'package:expense_tracker/features/transactions/presentation/pages/transaction_detail_page.dart';
import 'package:expense_tracker/features/transactions/presentation/pages/transaction_history_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'delete_transaction_test_harness.dart';

void main() {
  group('home page browsing behavior', () {
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
          child: const MaterialApp(home: Scaffold(body: HomePage())),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Balance'), findsOneWidget);
    });

    testWidgets('shows the initial empty state when there are no accounts', (
      tester,
    ) async {
      final environment = DeleteTestEnvironment(accounts: const []);

      await environment.pumpApp(tester, home: const Scaffold(body: HomePage()));

      expect(find.text('Create an account to get started'), findsOneWidget);
      expect(find.textContaining('Once you add an account'), findsOneWidget);
      expect(find.text('View more'), findsNothing);
    });

    testWidgets(
      'shows the empty period state when accounts exist but no transactions match',
      (tester) async {
        final environment = DeleteTestEnvironment(
          transactions: [
            expenseTransaction(
              id: 'tx-old',
              title: 'Old lunch',
              date: daysAgo(50),
            ),
          ],
        );

        await environment.pumpApp(
          tester,
          home: const Scaffold(body: HomePage()),
        );

        expect(find.textContaining('Nothing recorded for'), findsOneWidget);
        expect(find.text('Old lunch'), findsNothing);
        expect(find.text('View more'), findsOneWidget);
      },
    );

    testWidgets('hides view more when there are no transactions anywhere', (
      tester,
    ) async {
      final environment = DeleteTestEnvironment();

      await environment.pumpApp(tester, home: const Scaffold(body: HomePage()));

      expect(find.text('View more'), findsNothing);
    });

    testWidgets('shows balance and activity summaries for the current period', (
      tester,
    ) async {
      final environment = DeleteTestEnvironment(
        transactions: [
          incomeTransaction(
            id: 'tx-salary',
            title: 'Salary',
            date: daysAgo(1),
            amount: 1000,
          ),
          expenseTransaction(
            id: 'tx-groceries',
            title: 'Groceries',
            date: daysAgo(0),
            amount: 40,
          ),
        ],
      );

      await environment.pumpApp(tester, home: const Scaffold(body: HomePage()));

      expect(find.text('Hello'), findsOneWidget);
      expect(find.text('Balance'), findsOneWidget);
      expect(find.text('Income'), findsOneWidget);
      expect(find.text('Expenses'), findsOneWidget);
      expect(find.text('Net'), findsOneWidget);
      expect(find.text(formatCurrency(960)), findsWidgets);
      expect(find.text(formatCurrency(1000)), findsOneWidget);
      expect(find.text(formatCurrency(40)), findsOneWidget);
    });

    testWidgets(
      'shows a missing conversion indicator when exchange rates are unavailable',
      (tester) async {
        final environment = DeleteTestEnvironment(
          accounts: [
            const Account(
              id: 'account-usd',
              name: 'Travel USD',
              type: AccountType.bank,
              openingBalance: 125,
              currencyCode: 'USD',
            ),
          ],
          currencyConversionService: const _MissingUsdConversionService(),
        );

        await environment.pumpApp(
          tester,
          home: const Scaffold(body: HomePage()),
        );

        expect(
          find.textContaining('excluded until exchange rates load.'),
          findsOneWidget,
        );
      },
    );

    testWidgets('shows only current-period transactions sorted newest first', (
      tester,
    ) async {
      final environment = DeleteTestEnvironment(
        transactions: [
          transactionAt(
            id: 'tx-newer',
            title: 'Coffee',
            type: TransactionType.expense,
            hour: 15,
          ),
          transactionAt(
            id: 'tx-older',
            title: 'Salary',
            type: TransactionType.income,
            hour: 9,
          ),
          expenseTransaction(id: 'tx-old', title: 'Ancient', date: daysAgo(50)),
        ],
      );

      await environment.pumpApp(tester, home: const Scaffold(body: HomePage()));

      expect(find.text('Coffee'), findsOneWidget);
      expect(find.text('Salary'), findsOneWidget);
      expect(find.text('Ancient'), findsNothing);
      expect(titleTop(tester, 'Coffee'), lessThan(titleTop(tester, 'Salary')));
    });

    testWidgets('shows transfer rows with source and destination accounts', (
      tester,
    ) async {
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

      await environment.pumpApp(tester, home: const Scaffold(body: HomePage()));

      expect(find.text('Trip fund'), findsOneWidget);
      expect(find.text('Wallet -> Travel'), findsOneWidget);
    });

    testWidgets(
      'shows an unknown category fallback when category metadata is missing',
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

        expect(find.text('Unknown category · Wallet'), findsOneWidget);
      },
    );

    testWidgets(
      'shows an unknown account fallback when account metadata is missing',
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

        expect(find.text('Food · Unknown account'), findsOneWidget);
      },
    );

    testWidgets('tapping a transaction opens the transaction detail page', (
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

      await tapVisible(tester, find.text('Coffee'));
      await tester.pumpAndSettle();

      expect(find.byType(TransactionDetailPage), findsOneWidget);
      expect(find.text('Transaction details'), findsOneWidget);
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

        await environment.pumpApp(
          tester,
          home: const Scaffold(body: HomePage()),
        );

        await longPressVisible(tester, find.text('Coffee'));

        expect(find.text('Edit'), findsOneWidget);
        expect(find.text('Delete'), findsOneWidget);
      },
    );

    testWidgets(
      'tapping add opens the add transaction page when accounts exist',
      (tester) async {
        final environment = DeleteTestEnvironment();

        await environment.pumpApp(
          tester,
          home: const Scaffold(body: HomePage()),
        );

        await tapVisible(tester, find.byIcon(Icons.add));
        await tester.pumpAndSettle();

        expect(find.byType(AddTransactionPage), findsOneWidget);
        expect(find.text('Add transaction'), findsOneWidget);
      },
    );

    testWidgets('tapping add shows a snackbar when there are no accounts', (
      tester,
    ) async {
      final environment = DeleteTestEnvironment(accounts: const []);

      await environment.pumpApp(tester, home: const Scaffold(body: HomePage()));

      await tapVisible(tester, find.byIcon(Icons.add));
      await tester.pumpAndSettle();

      expect(find.byType(AddTransactionPage), findsNothing);
      expect(
        find.text('Create an account before adding your first transaction.'),
        findsOneWidget,
      );
    });

    testWidgets('tapping view more opens the transaction history page', (
      tester,
    ) async {
      final environment = DeleteTestEnvironment(
        transactions: [
          expenseTransaction(
            id: 'tx-old',
            title: 'Old lunch',
            date: daysAgo(50),
          ),
        ],
      );

      await environment.pumpApp(tester, home: const Scaffold(body: HomePage()));

      await tapVisible(tester, find.text('View more'));
      await tester.pumpAndSettle();

      expect(find.byType(TransactionHistoryPage), findsOneWidget);
      expect(find.text('Transactions'), findsOneWidget);
    });
  });
}

double titleTop(WidgetTester tester, String title) {
  return tester.getTopLeft(find.text(title).first).dy;
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

TransactionItem transactionAt({
  required String id,
  required String title,
  required TransactionType type,
  required int hour,
}) {
  final now = DateTime.now();
  return TransactionItem(
    id: id,
    title: title,
    amount: type == TransactionType.income ? 1000 : 12.5,
    currencyCode: 'EUR',
    date: DateTime(now.year, now.month, now.day, hour),
    type: type,
    accountId: 'account-wallet',
    categoryId: type == TransactionType.income
        ? 'category-salary'
        : 'category-food',
  );
}

class _MissingUsdConversionService implements CurrencyConversionService {
  const _MissingUsdConversionService();

  @override
  Future<Map<String, double?>> latestRatesToCurrency({
    required Set<String> fromCurrencyCodes,
    required String toCurrencyCode,
    required DateTime date,
  }) async {
    return {
      for (final currencyCode in fromCurrencyCodes)
        currencyCode.trim().toUpperCase():
            currencyCode.trim().toUpperCase() == 'USD' ? null : 1,
    };
  }

  @override
  Future<double?> tryConvertAmount({
    required double amount,
    required String fromCurrencyCode,
    required String toCurrencyCode,
    required DateTime date,
  }) async {
    return fromCurrencyCode.trim().toUpperCase() == 'USD' ? null : amount;
  }
}
