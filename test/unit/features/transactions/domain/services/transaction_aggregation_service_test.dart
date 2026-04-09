import 'package:expense_tracker/features/transactions/domain/models/transaction_item.dart';
import 'package:expense_tracker/features/transactions/domain/services/transaction_aggregation_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late TransactionAggregationService service;

  setUp(() {
    service = const TransactionAggregationService();
  });

  group('buildAggregation', () {
    test('returns unchanged amount for a base-currency transaction', () async {
      final result = await service.buildAggregation(
        transactions: [
          _transaction(id: 'tx-eur', amount: 12.5, currencyCode: 'EUR'),
        ],
        baseCurrencyCode: 'EUR',
        currentRates: const {},
      );

      expect(result.convertedAmounts, {'tx-eur': 12.5});
      expect(result.missingTransactionIds, isEmpty);
    });

    test('uses provided base-currency rate when present', () async {
      final result = await service.buildAggregation(
        transactions: [
          _transaction(id: 'tx-eur', amount: 12.5, currencyCode: 'EUR'),
        ],
        baseCurrencyCode: 'EUR',
        currentRates: const {'EUR': 1},
      );

      expect(result.convertedAmounts, {'tx-eur': 12.5});
      expect(result.missingTransactionIds, isEmpty);
    });

    test('converts mixed-currency transactions using provided rates', () async {
      final result = await service.buildAggregation(
        transactions: [
          _transaction(id: 'tx-usd', amount: 10, currencyCode: 'USD'),
          _transaction(id: 'tx-gbp', amount: 8, currencyCode: 'GBP'),
        ],
        baseCurrencyCode: 'EUR',
        currentRates: const {'USD': 0.92, 'GBP': 1.18},
      );

      expect(result.convertedAmounts['tx-usd'], closeTo(9.2, 0.000001));
      expect(result.convertedAmounts['tx-gbp'], closeTo(9.44, 0.000001));
      expect(result.missingTransactionIds, isEmpty);
    });

    test(
      'marks missing-rate transactions and excludes them from converted amounts',
      () async {
        final result = await service.buildAggregation(
          transactions: [
            _transaction(id: 'tx-eur', amount: 20, currencyCode: 'EUR'),
            _transaction(id: 'tx-usd', amount: 10, currencyCode: 'USD'),
          ],
          baseCurrencyCode: 'EUR',
          currentRates: const {},
        );

        expect(result.convertedAmounts, {'tx-eur': 20});
        expect(result.missingTransactionIds, {'tx-usd'});
      },
    );

    test('keeps resolvable transactions when some rates are missing', () async {
      final result = await service.buildAggregation(
        transactions: [
          _transaction(id: 'tx-usd', amount: 10, currencyCode: 'USD'),
          _transaction(id: 'tx-jpy', amount: 1000, currencyCode: 'JPY'),
          _transaction(id: 'tx-eur', amount: 5, currencyCode: 'EUR'),
        ],
        baseCurrencyCode: 'EUR',
        currentRates: const {'USD': 0.9},
      );

      expect(result.convertedAmounts, {'tx-usd': 9, 'tx-eur': 5});
      expect(result.missingTransactionIds, {'tx-jpy'});
    });

    test('normalizes currency codes when looking up rates', () async {
      final result = await service.buildAggregation(
        transactions: [
          _transaction(id: 'tx-usd', amount: 10, currencyCode: ' usd '),
        ],
        baseCurrencyCode: ' eur ',
        currentRates: const {'USD': 0.92},
      );

      expect(result.convertedAmounts['tx-usd'], closeTo(9.2, 0.000001));
      expect(result.missingTransactionIds, isEmpty);
    });

    test(
      'falls back to one for the base currency when no explicit rate exists',
      () async {
        final result = await service.buildAggregation(
          transactions: [
            _transaction(id: 'tx-eur', amount: 33, currencyCode: 'eur'),
          ],
          baseCurrencyCode: ' EUR ',
          currentRates: const {'USD': 0.91},
        );

        expect(result.convertedAmounts, {'tx-eur': 33});
        expect(result.missingTransactionIds, isEmpty);
      },
    );
  });
}

TransactionItem _transaction({
  required String id,
  required double amount,
  required String currencyCode,
}) {
  return TransactionItem(
    id: id,
    title: 'Transaction $id',
    amount: amount,
    currencyCode: currencyCode,
    date: DateTime(2026, 4, 9, 12),
    type: TransactionType.expense,
    accountId: 'account-wallet',
    categoryId: 'category-food',
  );
}
