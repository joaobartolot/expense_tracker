import 'package:expense_tracker/app/state/app_state_snapshot.dart';
import 'package:expense_tracker/features/accounts/domain/models/account.dart';
import 'package:expense_tracker/features/categories/domain/models/category_item.dart';
import 'package:expense_tracker/features/recurring_transactions/domain/models/recurring_transaction.dart';
import 'package:expense_tracker/features/settings/domain/models/app_settings.dart';
import 'package:expense_tracker/features/settings/domain/models/app_theme_preference.dart';
import 'package:expense_tracker/features/transactions/domain/models/transaction_item.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('transactionsForCategory', () {
    test('returns only transactions linked to the requested category', () {
      final snapshot = _snapshot();

      expect(
        snapshot.transactionsForCategory('category-food').map((tx) => tx.id),
        ['tx-expense', 'tx-unconverted'],
      );
    });
  });

  group('transactionsForAccount', () {
    test('returns income and expense transactions for the account', () {
      final snapshot = _snapshot();

      expect(
        snapshot.transactionsForAccount('account-wallet').map((tx) => tx.id),
        ['tx-income', 'tx-expense', 'tx-transfer', 'tx-unconverted'],
      );
    });

    test(
      'returns transfer transactions linked through destination account',
      () {
        final snapshot = _snapshot();

        expect(
          snapshot.transactionsForAccount('account-travel').map((tx) => tx.id),
          ['tx-transfer'],
        );
      },
    );
  });

  group('linked transaction and recurring helpers', () {
    test('detects linked transactions for accounts and categories', () {
      final snapshot = _snapshot();

      expect(
        snapshot.hasLinkedTransactionsForAccount('account-wallet'),
        isTrue,
      );
      expect(
        snapshot.hasLinkedTransactionsForAccount('account-missing'),
        isFalse,
      );
      expect(
        snapshot.hasLinkedTransactionsForCategory('category-food'),
        isTrue,
      );
      expect(
        snapshot.hasLinkedTransactionsForCategory('category-missing'),
        isFalse,
      );
    });

    test('detects linked recurring items for accounts and categories', () {
      final snapshot = _snapshot();

      expect(
        snapshot.hasLinkedRecurringTransactionsForAccount('account-wallet'),
        isTrue,
      );
      expect(
        snapshot.hasLinkedRecurringTransactionsForAccount('account-travel'),
        isTrue,
      );
      expect(
        snapshot.hasLinkedRecurringTransactionsForAccount('account-missing'),
        isFalse,
      );
      expect(
        snapshot.hasLinkedRecurringTransactionsForCategory('category-food'),
        isTrue,
      );
      expect(
        snapshot.hasLinkedRecurringTransactionsForCategory('category-salary'),
        isTrue,
      );
      expect(
        snapshot.hasLinkedRecurringTransactionsForCategory('category-missing'),
        isFalse,
      );
    });
  });

  group('conversion helpers', () {
    test('returns the converted amount for a transaction when present', () {
      final snapshot = _snapshot();

      expect(snapshot.convertedAmountForTransaction('tx-income'), 100);
      expect(snapshot.convertedAmountForTransaction('tx-missing'), isNull);
    });

    test('totals only transactions with converted amounts', () {
      final snapshot = _snapshot();

      expect(
        snapshot.totalForTransactions([
          _incomeTransaction(),
          _expenseTransaction(),
          _unconvertedExpenseTransaction(),
        ]),
        112,
      );
    });

    test('counts only transactions marked with missing conversions', () {
      final snapshot = _snapshot();

      expect(
        snapshot.missingConversionCountForTransactions([
          _incomeTransaction(),
          _unconvertedExpenseTransaction(),
          _transferTransaction(),
        ]),
        1,
      );
    });
  });
}

AppStateSnapshot _snapshot() {
  final settings = const AppSettings(
    displayName: 'Vero',
    themePreference: AppThemePreference.system,
    defaultCurrencyCode: 'EUR',
    financialCycleDay: 1,
  );
  final transactions = [
    _incomeTransaction(),
    _expenseTransaction(),
    _transferTransaction(),
    _unconvertedExpenseTransaction(),
  ];
  final recurringTransactions = [
    _recurringExpense(),
    _recurringIncome(),
    _recurringTransfer(),
  ];

  return AppStateSnapshot.initial(settings: settings).copyWith(
    hasLoaded: true,
    isLoading: false,
    accounts: [
      _account(id: 'account-wallet', name: 'Wallet'),
      _account(id: 'account-travel', name: 'Travel'),
    ],
    categories: [
      _category(id: 'category-food', name: 'Food', type: CategoryType.expense),
      _category(
        id: 'category-salary',
        name: 'Salary',
        type: CategoryType.income,
      ),
    ],
    transactions: transactions,
    recurringTransactions: recurringTransactions,
    convertedTransactionAmounts: const {
      'tx-income': 100,
      'tx-expense': 12,
      'tx-transfer': 50,
    },
    missingConvertedTransactionIds: const {'tx-unconverted'},
  );
}

TransactionItem _incomeTransaction() {
  return TransactionItem(
    id: 'tx-income',
    title: 'Salary',
    amount: 100,
    currencyCode: 'EUR',
    date: DateTime(2026, 4, 9, 12),
    type: TransactionType.income,
    accountId: 'account-wallet',
    categoryId: 'category-salary',
  );
}

TransactionItem _expenseTransaction() {
  return TransactionItem(
    id: 'tx-expense',
    title: 'Coffee',
    amount: 12,
    currencyCode: 'EUR',
    date: DateTime(2026, 4, 9, 8),
    type: TransactionType.expense,
    accountId: 'account-wallet',
    categoryId: 'category-food',
  );
}

TransactionItem _transferTransaction() {
  return TransactionItem(
    id: 'tx-transfer',
    title: 'Transfer',
    amount: 50,
    currencyCode: 'EUR',
    date: DateTime(2026, 4, 8, 9),
    type: TransactionType.transfer,
    sourceAccountId: 'account-wallet',
    destinationAccountId: 'account-travel',
  );
}

TransactionItem _unconvertedExpenseTransaction() {
  return TransactionItem(
    id: 'tx-unconverted',
    title: 'Taxi',
    amount: 20,
    currencyCode: 'USD',
    date: DateTime(2026, 4, 7, 9),
    type: TransactionType.expense,
    accountId: 'account-wallet',
    categoryId: 'category-food',
  );
}

RecurringTransaction _recurringExpense() {
  return RecurringTransaction(
    id: 'recurring-expense',
    title: 'Rent',
    amount: 500,
    currencyCode: 'EUR',
    startDate: DateTime(2026, 4, 1, 9),
    type: TransactionType.expense,
    executionMode: RecurringExecutionMode.manual,
    frequencyPreset: RecurringFrequencyPreset.monthly,
    intervalUnit: RecurringIntervalUnit.month,
    categoryId: 'category-food',
    accountId: 'account-wallet',
  );
}

RecurringTransaction _recurringIncome() {
  return RecurringTransaction(
    id: 'recurring-income',
    title: 'Salary',
    amount: 1000,
    currencyCode: 'EUR',
    startDate: DateTime(2026, 4, 1, 9),
    type: TransactionType.income,
    executionMode: RecurringExecutionMode.manual,
    frequencyPreset: RecurringFrequencyPreset.monthly,
    intervalUnit: RecurringIntervalUnit.month,
    categoryId: 'category-salary',
    accountId: 'account-wallet',
  );
}

RecurringTransaction _recurringTransfer() {
  return RecurringTransaction(
    id: 'recurring-transfer',
    title: 'Move to travel',
    amount: 100,
    currencyCode: 'EUR',
    startDate: DateTime(2026, 4, 1, 9),
    type: TransactionType.transfer,
    executionMode: RecurringExecutionMode.manual,
    frequencyPreset: RecurringFrequencyPreset.monthly,
    intervalUnit: RecurringIntervalUnit.month,
    sourceAccountId: 'account-wallet',
    destinationAccountId: 'account-travel',
  );
}

Account _account({required String id, required String name}) {
  return Account(
    id: id,
    name: name,
    type: AccountType.cash,
    openingBalance: 0,
    currencyCode: 'EUR',
  );
}

CategoryItem _category({
  required String id,
  required String name,
  required CategoryType type,
}) {
  return CategoryItem(
    id: id,
    name: name,
    description: '$name category',
    type: type,
    icon: Icons.sell_outlined,
  );
}
