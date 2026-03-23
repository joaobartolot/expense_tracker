enum TransactionType { income, expense }

class TransactionItem {
  const TransactionItem({
    required this.id,
    required this.title,
    required this.categoryId,
    required this.accountId,
    required this.amount,
    required this.currencyCode,
    required this.date,
    required this.type,
    this.foreignAmount,
    this.foreignCurrencyCode,
    this.exchangeRate,
  });

  final String id;
  final String title;
  final String categoryId;
  final String accountId;
  final double amount;
  final String currencyCode;
  final DateTime date;
  final TransactionType type;
  final double? foreignAmount;
  final String? foreignCurrencyCode;
  final double? exchangeRate;

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'title': title,
      'categoryId': categoryId,
      'accountId': accountId,
      'amount': amount,
      'currencyCode': currencyCode,
      'date': date.toIso8601String(),
      'type': type.name,
      'foreignAmount': foreignAmount,
      'foreignCurrencyCode': foreignCurrencyCode,
      'exchangeRate': exchangeRate,
    };
  }

  factory TransactionItem.fromMap(Map<dynamic, dynamic> map) {
    return TransactionItem(
      id: map['id'] as String? ?? '',
      title: map['title'] as String? ?? '',
      categoryId: map['categoryId'] as String? ?? '',
      accountId: map['accountId'] as String? ?? '',
      amount: (map['amount'] as num?)?.toDouble() ?? 0,
      currencyCode: map['currencyCode'] as String? ?? 'EUR',
      date: DateTime.tryParse(map['date'] as String? ?? '') ?? DateTime.now(),
      type: TransactionType.values.byName(map['type'] as String? ?? 'expense'),
      foreignAmount: (map['foreignAmount'] as num?)?.toDouble(),
      foreignCurrencyCode: map['foreignCurrencyCode'] as String?,
      exchangeRate: (map['exchangeRate'] as num?)?.toDouble(),
    );
  }

  TransactionItem copyWith({
    String? id,
    String? title,
    String? categoryId,
    String? accountId,
    double? amount,
    String? currencyCode,
    DateTime? date,
    TransactionType? type,
    double? foreignAmount,
    bool clearForeignAmount = false,
    String? foreignCurrencyCode,
    bool clearForeignCurrencyCode = false,
    double? exchangeRate,
    bool clearExchangeRate = false,
  }) {
    return TransactionItem(
      id: id ?? this.id,
      title: title ?? this.title,
      categoryId: categoryId ?? this.categoryId,
      accountId: accountId ?? this.accountId,
      amount: amount ?? this.amount,
      currencyCode: currencyCode ?? this.currencyCode,
      date: date ?? this.date,
      type: type ?? this.type,
      foreignAmount: clearForeignAmount
          ? null
          : foreignAmount ?? this.foreignAmount,
      foreignCurrencyCode: clearForeignCurrencyCode
          ? null
          : foreignCurrencyCode ?? this.foreignCurrencyCode,
      exchangeRate: clearExchangeRate
          ? null
          : exchangeRate ?? this.exchangeRate,
    );
  }

  bool get hasForeignCurrency =>
      foreignAmount != null &&
      foreignCurrencyCode != null &&
      foreignCurrencyCode != currencyCode;

  double get signedAmount {
    if (type == TransactionType.income) {
      return amount;
    }

    return -amount;
  }
}
