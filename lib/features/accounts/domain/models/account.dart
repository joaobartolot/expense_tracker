import 'package:flutter/material.dart';

enum AccountType { bank, cash, savings, creditCard }

enum CreditCardPaymentTracking { manual, automatic }

class Account {
  const Account({
    required this.id,
    required this.name,
    required this.type,
    required this.openingBalance,
    required this.currencyCode,
    this.isPrimary = false,
    this.description = '',
    this.creditCardDueDay,
    this.paymentTracking,
  });

  final String id;
  final String name;
  final AccountType type;
  final double openingBalance;
  final String currencyCode;
  final bool isPrimary;
  final String description;
  final int? creditCardDueDay;
  final CreditCardPaymentTracking? paymentTracking;

  bool get isCreditCard => type == AccountType.creditCard;
  // TODO: Hook credit card due-day and payment-tracking fields into real payment/reminder behavior.

  String get typeLabel => switch (type) {
    AccountType.bank => 'Bank account',
    AccountType.cash => 'Cash',
    AccountType.savings => 'Savings',
    AccountType.creditCard => 'Credit card',
  };

  IconData get icon => switch (type) {
    AccountType.bank => Icons.account_balance_outlined,
    AccountType.cash => Icons.payments_outlined,
    AccountType.savings => Icons.savings_outlined,
    AccountType.creditCard => Icons.credit_card_outlined,
  };

  String? get paymentTrackingLabel => switch (paymentTracking) {
    CreditCardPaymentTracking.manual => 'Manual payments',
    CreditCardPaymentTracking.automatic => 'Automatic payments',
    null => null,
  };

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'name': name,
      'type': type.name,
      'openingBalance': openingBalance,
      'currencyCode': currencyCode,
      'isPrimary': isPrimary,
      'description': description,
      'creditCardDueDay': creditCardDueDay,
      'paymentTracking': paymentTracking?.name,
    };
  }

  factory Account.fromMap(Map<dynamic, dynamic> map) {
    return Account(
      id: map['id'] as String? ?? '',
      name: map['name'] as String? ?? '',
      type: _accountTypeFromName(map['type'] as String?),
      openingBalance:
          (map['openingBalance'] as num?)?.toDouble() ??
          (map['balance'] as num?)?.toDouble() ??
          0,
      currencyCode: map['currencyCode'] as String? ?? 'EUR',
      isPrimary: map['isPrimary'] as bool? ?? false,
      description: map['description'] as String? ?? '',
      creditCardDueDay: map['creditCardDueDay'] as int?,
      paymentTracking: _paymentTrackingFromName(
        map['paymentTracking'] as String?,
      ),
    );
  }

  Account copyWith({
    String? id,
    String? name,
    AccountType? type,
    double? openingBalance,
    String? currencyCode,
    bool? isPrimary,
    String? description,
    int? creditCardDueDay,
    bool clearCreditCardDueDay = false,
    CreditCardPaymentTracking? paymentTracking,
    bool clearPaymentTracking = false,
  }) {
    return Account(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      openingBalance: openingBalance ?? this.openingBalance,
      currencyCode: currencyCode ?? this.currencyCode,
      isPrimary: isPrimary ?? this.isPrimary,
      description: description ?? this.description,
      creditCardDueDay: clearCreditCardDueDay
          ? null
          : creditCardDueDay ?? this.creditCardDueDay,
      paymentTracking: clearPaymentTracking
          ? null
          : paymentTracking ?? this.paymentTracking,
    );
  }

  static CreditCardPaymentTracking? _paymentTrackingFromName(String? value) {
    if (value == null || value.isEmpty) {
      return null;
    }

    return CreditCardPaymentTracking.values.firstWhere(
      (tracking) => tracking.name == value,
      orElse: () => CreditCardPaymentTracking.manual,
    );
  }

  static AccountType _accountTypeFromName(String? value) {
    return AccountType.values.firstWhere(
      (type) => type.name == value,
      orElse: () => AccountType.bank,
    );
  }
}
