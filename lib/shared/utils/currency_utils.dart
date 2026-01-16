/// Utility functions for currency conversions to avoid floating-point precision errors
///
/// All monetary amounts in the app are stored as integers (cents) to avoid
/// floating-point precision issues. These utilities handle the conversion
/// between user-facing decimal amounts and internal cent representations.
library;

/// Converts a decimal amount (euros) to cents (integer)
///
/// This function uses string-based parsing to avoid floating-point precision
/// errors. For example, 0.29 * 100 might not equal exactly 29 due to
/// floating-point representation limitations.
///
/// Example:
/// ```dart
/// eurosToCents(10.50) // returns 1050
/// eurosToCents(0.29) // returns 29
/// ```
int eurosToCents(double euros) {
  // Convert to string and split by decimal point
  final eurosStr = euros.toStringAsFixed(2);
  final parts = eurosStr.split('.');

  final euroPart = int.parse(parts[0]);
  final centPart = parts.length > 1 ? int.parse(parts[1]) : 0;

  return euroPart * 100 + centPart;
}

/// Converts an amount string (from text input) to cents (integer)
///
/// This function safely parses user input and converts it to cents,
/// handling various decimal formats and avoiding precision errors.
///
/// Example:
/// ```dart
/// stringToCents('10.50') // returns 1050
/// stringToCents('0.29') // returns 29
/// stringToCents('5') // returns 500
/// ```
int stringToCents(String amountStr) {
  // Remove any whitespace
  final trimmed = amountStr.trim();

  // Parse the string as double first to validate
  final euros = double.parse(trimmed);

  // Use eurosToCents for safe conversion
  return eurosToCents(euros);
}

/// Converts cents (integer) to a decimal amount (euros)
///
/// This is a simple division by 100, safe because we're converting
/// from integer to double.
///
/// Example:
/// ```dart
/// centsToEuros(1050) // returns 10.50
/// centsToEuros(29) // returns 0.29
/// ```
double centsToEuros(int cents) {
  return cents / 100.0;
}

/// Formats cents as a currency string with euro symbol
///
/// Example:
/// ```dart
/// formatCents(1050) // returns '€10.50'
/// formatCents(-29) // returns '-€0.29'
/// ```
String formatCents(int cents) {
  final abs = cents.abs();
  final euros = abs ~/ 100;
  final remainder = abs % 100;
  final sign = cents < 0 ? '-' : '';
  return '$sign€$euros.${remainder.toString().padLeft(2, '0')}';
}
