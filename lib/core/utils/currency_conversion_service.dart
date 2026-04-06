import 'package:expense_tracker/features/transactions/data/exchange_rate_service.dart';

class CurrencyConversionService {
  const CurrencyConversionService({
    required ExchangeRateService exchangeRateService,
  }) : _exchangeRateService = exchangeRateService;

  final ExchangeRateService _exchangeRateService;

  Future<Map<String, double?>> latestRatesToCurrency({
    required Set<String> fromCurrencyCodes,
    required String toCurrencyCode,
    required DateTime date,
  }) async {
    final rates = <String, double?>{};

    for (final currencyCode in fromCurrencyCodes) {
      final normalizedCode = currencyCode.trim().toUpperCase();
      if (normalizedCode == toCurrencyCode.trim().toUpperCase()) {
        rates[normalizedCode] = 1;
        continue;
      }

      try {
        rates[normalizedCode] = await _exchangeRateService.fetchExchangeRate(
          fromCurrencyCode: normalizedCode,
          toCurrencyCode: toCurrencyCode,
          date: date,
        );
      } on ExchangeRateLookupException {
        rates[normalizedCode] = null;
      }
    }

    return rates;
  }

  Future<double?> tryConvertAmount({
    required double amount,
    required String fromCurrencyCode,
    required String toCurrencyCode,
    required DateTime date,
  }) async {
    final normalizedFrom = fromCurrencyCode.trim().toUpperCase();
    final normalizedTo = toCurrencyCode.trim().toUpperCase();
    if (normalizedFrom == normalizedTo) {
      return amount;
    }

    try {
      final rate = await _exchangeRateService.fetchExchangeRate(
        fromCurrencyCode: normalizedFrom,
        toCurrencyCode: normalizedTo,
        date: date,
      );
      return amount * rate;
    } on ExchangeRateLookupException {
      return null;
    }
  }
}
