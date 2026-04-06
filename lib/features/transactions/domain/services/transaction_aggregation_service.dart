import 'package:expense_tracker/features/transactions/domain/models/transaction_item.dart';

class TransactionAggregationResult {
  const TransactionAggregationResult({
    required this.convertedAmounts,
    required this.missingTransactionIds,
  });

  final Map<String, double> convertedAmounts;
  final Set<String> missingTransactionIds;
}

class TransactionAggregationService {
  const TransactionAggregationService();

  Future<TransactionAggregationResult> buildAggregation({
    required List<TransactionItem> transactions,
    required String baseCurrencyCode,
    required Map<String, double?> currentRates,
  }) async {
    final convertedAmounts = <String, double>{};
    final missingTransactionIds = <String>{};

    for (final transaction in transactions) {
      final currencyCode = transaction.currencyCode.trim().toUpperCase();
      final rate =
          currentRates[currencyCode] ??
          (currencyCode == baseCurrencyCode.trim().toUpperCase() ? 1 : null);
      final convertedAmount = rate == null ? null : transaction.amount * rate;

      if (convertedAmount == null) {
        missingTransactionIds.add(transaction.id);
        continue;
      }

      convertedAmounts[transaction.id] = convertedAmount;
    }

    return TransactionAggregationResult(
      convertedAmounts: convertedAmounts,
      missingTransactionIds: missingTransactionIds,
    );
  }
}
