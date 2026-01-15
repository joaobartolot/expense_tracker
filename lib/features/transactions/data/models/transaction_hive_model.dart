import 'package:hive/hive.dart';

part 'transaction_hive_model.g.dart';

@HiveType(typeId: 0)
class TransactionHiveModel extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String name;

  @HiveField(2)
  final int amountCents;

  /// 0 = expense, 1 = income
  @HiveField(3)
  final int type;

  @HiveField(4)
  final String category;

  /// Unix epoch in milliseconds
  @HiveField(5)
  final int dateEpochMillis;

  @HiveField(6)
  final String? note;

  TransactionHiveModel({
    required this.id,
    required this.name,
    required this.amountCents,
    required this.type,
    required this.category,
    required this.dateEpochMillis,
    this.note,
  });
}
