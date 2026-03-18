import 'package:flutter/material.dart';

enum TransactionType { income, expense }

class TransactionItem {
  const TransactionItem({
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.date,
    required this.type,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final double amount;
  final DateTime date;
  final TransactionType type;
  final IconData icon;

  double get signedAmount {
    if (type == TransactionType.income) {
      return amount;
    }

    return -amount;
  }
}
