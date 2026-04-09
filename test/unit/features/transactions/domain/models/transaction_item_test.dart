import 'package:expense_tracker/features/transactions/domain/models/transaction_item.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('copyWith', () {
    test('updates provided fields while preserving unspecified values', () {
      final original = _expenseTransaction();

      final updated = original.copyWith(
        title: 'Groceries',
        amount: 42,
        date: DateTime(2026, 4, 10, 8),
      );

      expect(updated.id, original.id);
      expect(updated.title, 'Groceries');
      expect(updated.amount, 42);
      expect(updated.date, DateTime(2026, 4, 10, 8));
      expect(updated.accountId, original.accountId);
      expect(updated.categoryId, original.categoryId);
      expect(updated.type, original.type);
    });

    test('supports clearing nullable fields', () {
      final original = _transferTransaction(
        destinationAmount: 75,
        destinationCurrencyCode: 'USD',
        transferKind: TransactionTransferKind.creditCardPayment,
      );

      final updated = original.copyWith(
        clearDestinationAmount: true,
        clearDestinationCurrencyCode: true,
        clearTransferKind: true,
      );

      expect(updated.destinationAmount, isNull);
      expect(updated.destinationCurrencyCode, isNull);
      expect(updated.transferKind, isNull);
      expect(updated.destinationAccountId, original.destinationAccountId);
    });
  });

  group('toMap and fromMap', () {
    test('round-trips an income or expense transaction', () {
      final transaction = _expenseTransaction();

      final restored = TransactionItem.fromMap(transaction.toMap());

      expect(restored, transaction);
    });

    test('round-trips a transfer transaction with transfer kind', () {
      final transaction = _transferTransaction(
        destinationAmount: 75,
        destinationCurrencyCode: 'USD',
        transferKind: TransactionTransferKind.creditCardPayment,
      );

      final restored = TransactionItem.fromMap(transaction.toMap());

      expect(restored, transaction);
      expect(restored.isCreditCardPayment, isTrue);
    });
  });

  group('equality and hashCode', () {
    test('treats identical transactions as equal', () {
      final left = _expenseTransaction();
      final right = _expenseTransaction();

      expect(left, equals(right));
      expect(left.hashCode, right.hashCode);
    });

    test('treats changed transactions as not equal', () {
      final left = _expenseTransaction();
      final right = _expenseTransaction(title: 'Groceries');

      expect(left == right, isFalse);
    });
  });

  group('hasForeignCurrency', () {
    test('is true when a foreign snapshot exists in a different currency', () {
      final transaction = _expenseTransaction(
        foreignAmount: 80,
        foreignCurrencyCode: 'USD',
        exchangeRate: 0.9,
      );

      expect(transaction.hasForeignCurrency, isTrue);
    });

    test('is false when the foreign snapshot is missing or same-currency', () {
      expect(_expenseTransaction().hasForeignCurrency, isFalse);
      expect(
        _expenseTransaction(
          foreignAmount: 90,
          foreignCurrencyCode: 'EUR',
          exchangeRate: 1,
        ).hasForeignCurrency,
        isFalse,
      );
    });
  });

  group('balanceChanges', () {
    test('returns a positive balance change for income', () {
      final transaction = _incomeTransaction(amount: 120);

      expect(transaction.balanceChanges, {'account-wallet': 120});
    });

    test('returns a negative balance change for expense', () {
      final transaction = _expenseTransaction(amount: 35);

      expect(transaction.balanceChanges, {'account-wallet': -35});
    });

    test('returns source and destination changes for transfers', () {
      final transaction = _transferTransaction(
        amount: 50,
        destinationAmount: 75,
      );

      expect(transaction.balanceChanges, {
        'account-wallet': -50,
        'account-travel': 75,
      });
    });
  });

  group('linked-account helpers', () {
    test('uses accountId as the primary account for income and expense', () {
      final transaction = _expenseTransaction();

      expect(transaction.primaryAccountId, 'account-wallet');
      expect(transaction.secondaryAccountId, isNull);
      expect(transaction.linkedAccountIds.toList(growable: false), [
        'account-wallet',
      ]);
    });

    test('uses source and destination accounts for transfers', () {
      final transaction = _transferTransaction();

      expect(transaction.primaryAccountId, 'account-wallet');
      expect(transaction.secondaryAccountId, 'account-travel');
      expect(transaction.linkedAccountIds.toList(growable: false), [
        'account-wallet',
        'account-travel',
      ]);
    });

    test('skips empty linked-account values', () {
      final transaction = TransactionItem(
        id: 'tx-transfer',
        title: 'Transfer',
        amount: 50,
        currencyCode: 'EUR',
        date: DateTime(2026, 4, 9, 12),
        type: TransactionType.transfer,
        sourceAccountId: '',
        destinationAccountId: 'account-travel',
      );

      expect(transaction.linkedAccountIds.toList(growable: false), [
        'account-travel',
      ]);
    });
  });
}

TransactionItem _expenseTransaction({
  String title = 'Coffee',
  double amount = 12,
  double? foreignAmount,
  String? foreignCurrencyCode,
  double? exchangeRate,
}) {
  return TransactionItem(
    id: 'tx-expense',
    title: title,
    amount: amount,
    currencyCode: 'EUR',
    date: DateTime(2026, 4, 9, 12),
    type: TransactionType.expense,
    accountId: 'account-wallet',
    categoryId: 'category-food',
    foreignAmount: foreignAmount,
    foreignCurrencyCode: foreignCurrencyCode,
    exchangeRate: exchangeRate,
  );
}

TransactionItem _incomeTransaction({double amount = 100}) {
  return TransactionItem(
    id: 'tx-income',
    title: 'Salary',
    amount: amount,
    currencyCode: 'EUR',
    date: DateTime(2026, 4, 9, 12),
    type: TransactionType.income,
    accountId: 'account-wallet',
    categoryId: 'category-salary',
  );
}

TransactionItem _transferTransaction({
  double amount = 50,
  double? destinationAmount,
  String? destinationCurrencyCode,
  TransactionTransferKind? transferKind,
}) {
  return TransactionItem(
    id: 'tx-transfer',
    title: 'Trip fund',
    amount: amount,
    currencyCode: 'EUR',
    date: DateTime(2026, 4, 9, 12),
    type: TransactionType.transfer,
    sourceAccountId: 'account-wallet',
    destinationAccountId: 'account-travel',
    destinationAmount: destinationAmount,
    destinationCurrencyCode: destinationCurrencyCode,
    transferKind: transferKind,
  );
}
