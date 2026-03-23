class SupportedCurrency {
  const SupportedCurrency({required this.code, required this.name});

  final String code;
  final String name;
}

const supportedCurrencies = [
  SupportedCurrency(code: 'EUR', name: 'Euro'),
  SupportedCurrency(code: 'USD', name: 'US Dollar'),
  SupportedCurrency(code: 'BRL', name: 'Brazilian Real'),
  SupportedCurrency(code: 'GBP', name: 'British Pound'),
  SupportedCurrency(code: 'JPY', name: 'Japanese Yen'),
  SupportedCurrency(code: 'CAD', name: 'Canadian Dollar'),
  SupportedCurrency(code: 'AUD', name: 'Australian Dollar'),
  SupportedCurrency(code: 'CHF', name: 'Swiss Franc'),
  SupportedCurrency(code: 'CNY', name: 'Chinese Yuan'),
];

SupportedCurrency currencyForCode(String? code) {
  final normalizedCode = (code ?? '').trim().toUpperCase();

  for (final currency in supportedCurrencies) {
    if (currency.code == normalizedCode) {
      return currency;
    }
  }

  return const SupportedCurrency(code: 'EUR', name: 'Euro');
}
