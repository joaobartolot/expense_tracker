enum TransactionType { income, expense }

class TransactionItem {
  const TransactionItem({
    required this.id,
    required this.title,
    required this.categoryId,
    required this.amount,
    required this.date,
    required this.type,
  });

  final String id;
  final String title;
  final String categoryId;
  final double amount;
  final DateTime date;
  final TransactionType type;

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'title': title,
      'categoryId': categoryId,
      'amount': amount,
      'date': date.toIso8601String(),
      'type': type.name,
    };
  }

  factory TransactionItem.fromMap(Map<dynamic, dynamic> map) {
    return TransactionItem(
      id: map['id'] as String? ?? '',
      title: map['title'] as String? ?? '',
      categoryId: map['categoryId'] as String? ?? '',
      amount: (map['amount'] as num?)?.toDouble() ?? 0,
      date: DateTime.tryParse(map['date'] as String? ?? '') ?? DateTime.now(),
      type: TransactionType.values.byName(map['type'] as String? ?? 'expense'),
    );
  }

  TransactionItem copyWith({
    String? id,
    String? title,
    String? categoryId,
    double? amount,
    DateTime? date,
    TransactionType? type,
  }) {
    return TransactionItem(
      id: id ?? this.id,
      title: title ?? this.title,
      categoryId: categoryId ?? this.categoryId,
      amount: amount ?? this.amount,
      date: date ?? this.date,
      type: type ?? this.type,
    );
  }

  double get signedAmount {
    if (type == TransactionType.income) {
      return amount;
    }

    return -amount;
  }
}
