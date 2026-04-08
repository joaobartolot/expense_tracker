enum TransactionType { income, expense, transfer }

enum TransactionTransferKind { standard, creditCardPayment }

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
    this.destinationAmount,
    this.destinationCurrencyCode,
    this.foreignAmount,
    this.foreignCurrencyCode,
    this.exchangeRate,
    this.transferKind,
  });

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
  final double? destinationAmount;
  final String? destinationCurrencyCode;
  final double? foreignAmount;
  final String? foreignCurrencyCode;
  final double? exchangeRate;
  final TransactionTransferKind? transferKind;

  bool get isTransfer => type == TransactionType.transfer;

  TransactionTransferKind get resolvedTransferKind => isTransfer
      ? (transferKind ?? TransactionTransferKind.standard)
      : TransactionTransferKind.standard;

  bool get isCreditCardPayment =>
      isTransfer &&
      resolvedTransferKind == TransactionTransferKind.creditCardPayment;

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
        if (_hasValue(destinationAccountId))
          destinationAccountId!: destinationAmount ?? amount,
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
      'amount': _serializeMoney(amount),
      'currencyCode': currencyCode,
      'date': date.toIso8601String(),
      'type': type.name,
      'sourceAccountId': sourceAccountId,
      'destinationAccountId': destinationAccountId,
      'destinationAmount': _serializeOptionalMoney(destinationAmount),
      'destinationCurrencyCode': destinationCurrencyCode,
      'foreignAmount': _serializeOptionalMoney(foreignAmount),
      'foreignCurrencyCode': foreignCurrencyCode,
      'exchangeRate': exchangeRate,
      'transferKind': isTransfer ? resolvedTransferKind.name : null,
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
      destinationAmount: (map['destinationAmount'] as num?)?.toDouble(),
      destinationCurrencyCode: map['destinationCurrencyCode'] as String?,
      foreignAmount: (map['foreignAmount'] as num?)?.toDouble(),
      foreignCurrencyCode: map['foreignCurrencyCode'] as String?,
      exchangeRate: (map['exchangeRate'] as num?)?.toDouble(),
      transferKind: _transferKindFromName(map['transferKind'] as String?),
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
    double? destinationAmount,
    bool clearDestinationAmount = false,
    String? destinationCurrencyCode,
    bool clearDestinationCurrencyCode = false,
    double? foreignAmount,
    bool clearForeignAmount = false,
    String? foreignCurrencyCode,
    bool clearForeignCurrencyCode = false,
    double? exchangeRate,
    bool clearExchangeRate = false,
    TransactionTransferKind? transferKind,
    bool clearTransferKind = false,
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
      destinationAmount: clearDestinationAmount
          ? null
          : destinationAmount ?? this.destinationAmount,
      destinationCurrencyCode: clearDestinationCurrencyCode
          ? null
          : destinationCurrencyCode ?? this.destinationCurrencyCode,
      foreignAmount: clearForeignAmount
          ? null
          : foreignAmount ?? this.foreignAmount,
      foreignCurrencyCode: clearForeignCurrencyCode
          ? null
          : foreignCurrencyCode ?? this.foreignCurrencyCode,
      exchangeRate: clearExchangeRate
          ? null
          : exchangeRate ?? this.exchangeRate,
      transferKind: clearTransferKind
          ? null
          : transferKind ?? this.transferKind,
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

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is TransactionItem &&
            other.id == id &&
            other.title == title &&
            other.categoryId == categoryId &&
            other.accountId == accountId &&
            other.amount == amount &&
            other.currencyCode == currencyCode &&
            other.date == date &&
            other.type == type &&
            other.sourceAccountId == sourceAccountId &&
            other.destinationAccountId == destinationAccountId &&
            other.destinationAmount == destinationAmount &&
            other.destinationCurrencyCode == destinationCurrencyCode &&
            other.foreignAmount == foreignAmount &&
            other.foreignCurrencyCode == foreignCurrencyCode &&
            other.exchangeRate == exchangeRate &&
            other.transferKind == transferKind;
  }

  @override
  int get hashCode => Object.hash(
    id,
    title,
    categoryId,
    accountId,
    amount,
    currencyCode,
    date,
    type,
    sourceAccountId,
    destinationAccountId,
    destinationAmount,
    destinationCurrencyCode,
    foreignAmount,
    foreignCurrencyCode,
    exchangeRate,
    transferKind,
  );

  static bool _hasValue(String? value) => value != null && value.isNotEmpty;

  static String? _optionalString(Object? value) {
    final stringValue = value as String?;
    if (stringValue == null || stringValue.isEmpty) {
      return null;
    }

    return stringValue;
  }

  static int _serializeMoney(double value) {
    return value.round();
  }

  static int? _serializeOptionalMoney(double? value) {
    if (value == null) {
      return null;
    }

    return _serializeMoney(value);
  }

  static TransactionType _transactionTypeFromName(String? value) {
    return TransactionType.values.firstWhere(
      (type) => type.name == value,
      orElse: () => TransactionType.expense,
    );
  }

  static TransactionTransferKind? _transferKindFromName(String? value) {
    if (!_hasValue(value)) {
      return null;
    }

    return TransactionTransferKind.values.firstWhere(
      (kind) => kind.name == value,
      orElse: () => TransactionTransferKind.standard,
    );
  }
}
