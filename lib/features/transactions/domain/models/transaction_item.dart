enum TransactionType { income, expense, transfer }

class TransactionItem {
  TransactionItem({
    required this.id,
    required this.title,
    required this.amount,
    required this.currencyCode,
    required this.date,
    required this.type,
    this.categoryId,
    this.accountId,
    this.sourceAccountId,
    this.destinationAccountId,
    this.foreignAmount,
    this.foreignCurrencyCode,
    this.exchangeRate,
  }) : assert(
         _isValidConfiguration(
           type: type,
           categoryId: categoryId,
           accountId: accountId,
           sourceAccountId: sourceAccountId,
           destinationAccountId: destinationAccountId,
         ),
         'Transaction configuration does not match its type.',
       );

  final String id;
  final String title;
  final String? categoryId;
  final String? accountId;
  final double amount;
  final String currencyCode;
  final DateTime date;
  final TransactionType type;
  final String? sourceAccountId;
  final String? destinationAccountId;
  final double? foreignAmount;
  final String? foreignCurrencyCode;
  final double? exchangeRate;

  bool get isTransfer => type == TransactionType.transfer;

  bool get isIncomeOrExpense => !isTransfer;

  bool get requiresCategory => !isTransfer;

  String? get primaryAccountId => isTransfer ? sourceAccountId : accountId;

  String? get secondaryAccountId => isTransfer ? destinationAccountId : null;

  Iterable<String> get linkedAccountIds sync* {
    if (isTransfer) {
      if (_hasValue(sourceAccountId)) {
        yield sourceAccountId!;
      }
      if (_hasValue(destinationAccountId)) {
        yield destinationAccountId!;
      }
      return;
    }

    if (_hasValue(accountId)) {
      yield accountId!;
    }
  }

  Map<String, double> get balanceChanges {
    if (isTransfer) {
      return {
        if (_hasValue(sourceAccountId)) sourceAccountId!: -amount,
        if (_hasValue(destinationAccountId)) destinationAccountId!: amount,
      };
    }

    if (!_hasValue(accountId)) {
      return const {};
    }

    return {accountId!: signedAmount};
  }

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
      'sourceAccountId': sourceAccountId,
      'destinationAccountId': destinationAccountId,
      'foreignAmount': foreignAmount,
      'foreignCurrencyCode': foreignCurrencyCode,
      'exchangeRate': exchangeRate,
    };
  }

  factory TransactionItem.fromMap(Map<dynamic, dynamic> map) {
    return TransactionItem(
      id: map['id'] as String? ?? '',
      title: map['title'] as String? ?? '',
      categoryId: _optionalString(map['categoryId']),
      accountId: _optionalString(map['accountId']),
      amount: (map['amount'] as num?)?.toDouble() ?? 0,
      currencyCode: map['currencyCode'] as String? ?? 'EUR',
      date: DateTime.tryParse(map['date'] as String? ?? '') ?? DateTime.now(),
      type: _transactionTypeFromName(map['type'] as String?),
      sourceAccountId: _optionalString(map['sourceAccountId']),
      destinationAccountId: _optionalString(map['destinationAccountId']),
      foreignAmount: (map['foreignAmount'] as num?)?.toDouble(),
      foreignCurrencyCode: map['foreignCurrencyCode'] as String?,
      exchangeRate: (map['exchangeRate'] as num?)?.toDouble(),
    );
  }

  TransactionItem copyWith({
    String? id,
    String? title,
    String? categoryId,
    bool clearCategoryId = false,
    String? accountId,
    bool clearAccountId = false,
    double? amount,
    String? currencyCode,
    DateTime? date,
    TransactionType? type,
    String? sourceAccountId,
    bool clearSourceAccountId = false,
    String? destinationAccountId,
    bool clearDestinationAccountId = false,
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
      categoryId: clearCategoryId ? null : categoryId ?? this.categoryId,
      accountId: clearAccountId ? null : accountId ?? this.accountId,
      amount: amount ?? this.amount,
      currencyCode: currencyCode ?? this.currencyCode,
      date: date ?? this.date,
      type: type ?? this.type,
      sourceAccountId: clearSourceAccountId
          ? null
          : sourceAccountId ?? this.sourceAccountId,
      destinationAccountId: clearDestinationAccountId
          ? null
          : destinationAccountId ?? this.destinationAccountId,
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
    if (type == TransactionType.transfer) {
      return 0;
    }

    return -amount;
  }

  static bool _isValidConfiguration({
    required TransactionType type,
    required String? categoryId,
    required String? accountId,
    required String? sourceAccountId,
    required String? destinationAccountId,
  }) {
    if (type == TransactionType.transfer) {
      return !_hasValue(categoryId) &&
          !_hasValue(accountId) &&
          _hasValue(sourceAccountId) &&
          _hasValue(destinationAccountId);
    }

    return _hasValue(categoryId) &&
        _hasValue(accountId) &&
        !_hasValue(sourceAccountId) &&
        !_hasValue(destinationAccountId);
  }

  static bool _hasValue(String? value) => value != null && value.isNotEmpty;

  static String? _optionalString(Object? value) {
    final stringValue = value as String?;
    if (stringValue == null || stringValue.isEmpty) {
      return null;
    }

    return stringValue;
  }

  static TransactionType _transactionTypeFromName(String? value) {
    return TransactionType.values.firstWhere(
      (type) => type.name == value,
      orElse: () => TransactionType.expense,
    );
  }
}
