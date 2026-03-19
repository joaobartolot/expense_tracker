import 'package:flutter/material.dart';

enum TransactionType { income, expense }

class TransactionItem {
  const TransactionItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.date,
    required this.type,
    required this.icon,
  });

  final String id;
  final String title;
  final String subtitle;
  final double amount;
  final DateTime date;
  final TransactionType type;
  final IconData icon;

  TransactionItem copyWith({
    String? id,
    String? title,
    String? subtitle,
    double? amount,
    DateTime? date,
    TransactionType? type,
    IconData? icon,
  }) {
    return TransactionItem(
      id: id ?? this.id,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      amount: amount ?? this.amount,
      date: date ?? this.date,
      type: type ?? this.type,
      icon: icon ?? this.icon,
    );
  }

  double get signedAmount {
    if (type == TransactionType.income) {
      return amount;
    }

    return -amount;
  }
}
