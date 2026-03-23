import 'dart:convert';
import 'dart:io';

import 'package:intl/intl.dart';

class ExchangeRateLookupException implements Exception {
  const ExchangeRateLookupException(this.message);

  final String message;

  @override
  String toString() => message;
}

class ExchangeRateService {
  const ExchangeRateService();

  static const _host = 'api.frankfurter.dev';
  static final Map<String, double> _exchangeRateCache = {};

  Future<double> fetchExchangeRate({
    required String fromCurrencyCode,
    required String toCurrencyCode,
    required DateTime date,
  }) async {
    if (fromCurrencyCode == toCurrencyCode) {
      return 1;
    }

    final formattedDate = DateFormat('yyyy-MM-dd').format(date);
    final cacheKey =
        '$formattedDate:${fromCurrencyCode.toUpperCase()}:${toCurrencyCode.toUpperCase()}';
    final cachedRate = _exchangeRateCache[cacheKey];
    if (cachedRate != null) {
      return cachedRate;
    }

    final uri = Uri.https(_host, '/v1/$formattedDate', {
      'base': fromCurrencyCode,
      'symbols': toCurrencyCode,
    });

    final httpClient = HttpClient();

    try {
      final request = await httpClient.getUrl(uri);
      final response = await request.close();

      if (response.statusCode != HttpStatus.ok) {
        throw const ExchangeRateLookupException(
          'Could not fetch the exchange rate right now.',
        );
      }

      final payload = await utf8.decodeStream(response);
      final map = jsonDecode(payload);
      if (map is! Map<String, dynamic>) {
        throw const ExchangeRateLookupException(
          'Received an invalid exchange rate response.',
        );
      }

      final rates = map['rates'];
      if (rates is! Map<String, dynamic>) {
        throw const ExchangeRateLookupException(
          'The exchange rate response did not include rates.',
        );
      }

      final rate = rates[toCurrencyCode];
      if (rate is num) {
        final parsedRate = rate.toDouble();
        _exchangeRateCache[cacheKey] = parsedRate;
        return parsedRate;
      }

      throw const ExchangeRateLookupException(
        'The selected currency pair is not available.',
      );
    } on SocketException {
      throw const ExchangeRateLookupException(
        'Check your connection and try again.',
      );
    } on HandshakeException {
      throw const ExchangeRateLookupException(
        'Could not verify the exchange rate service.',
      );
    } on FormatException {
      throw const ExchangeRateLookupException(
        'Received an unreadable exchange rate response.',
      );
    } finally {
      httpClient.close(force: true);
    }
  }
}
