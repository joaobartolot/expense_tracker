import 'package:expense_tracker/core/utils/supported_currencies.dart';
import 'package:intl/intl.dart';

String currencySymbolFor(String currencyCode, {String locale = 'en_US'}) {
  final normalizedCode = currencyForCode(currencyCode).code;
  return NumberFormat.simpleCurrency(
    name: normalizedCode,
    locale: locale,
  ).currencySymbol;
}

String formatCurrency(
  double amount, {
  String currencyCode = 'EUR',
  String locale = 'en_US',
}) {
  final normalizedCode = currencyForCode(currencyCode).code;
  return NumberFormat.currency(
    name: normalizedCode,
    locale: locale,
    symbol: currencySymbolFor(normalizedCode, locale: locale),
  ).format(amount);
}
