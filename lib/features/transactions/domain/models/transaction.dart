import 'package:expense_tracker/features/transactions/domain/enums/transaction_type.dart';

class Transaction {
  const Transaction({
    required this.id,
    required this.name,
    required this.amountCents,
    required this.type,
    required this.category,
    required this.date,
    this.note,
  });

  final String id; // UUID
  final String name;
  final int amountCents;
  final TransactionType type;
  final String category;
  final DateTime date;
  final String? note;

  bool get isExpense => type == TransactionType.expense;
  bool get isIncome => type == TransactionType.income;

  Transaction copyWith({
    String? id,
    String? name,
    int? amountCents,
    TransactionType? type,
    String? category,
    DateTime? date,
    String? note,
  }) {
    return Transaction(
      id: id ?? this.id,
      name: name ?? this.name,
      amountCents: amountCents ?? this.amountCents,
      type: type ?? this.type,
      category: category ?? this.category,
      date: date ?? this.date,
      note: note ?? this.note,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Transaction &&
          id == other.id &&
          name == other.name &&
          amountCents == other.amountCents &&
          type == other.type &&
          category == other.category &&
          date == other.date &&
          note == other.note;

  @override
  int get hashCode =>
      Object.hash(id, name, amountCents, type, category, date, note);
}
