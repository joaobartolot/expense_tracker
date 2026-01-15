import 'package:expense_tracker/features/transactions/data/models/transaction_hive_model.dart';
import 'package:expense_tracker/features/transactions/domain/enums/transaction_type.dart';
import 'package:expense_tracker/features/transactions/domain/models/transaction.dart';

TransactionHiveModel toHive(Transaction transaction) {
  return TransactionHiveModel(
    id: transaction.id,
    name: transaction.name,
    amountCents: transaction.amountCents,
    type: transaction.type.index,
    category: transaction.category,
    dateEpochMillis: transaction.date.millisecondsSinceEpoch,
    note: transaction.note,
  );
}

Transaction toDomain(TransactionHiveModel hiveModel) {
  return Transaction(
    id: hiveModel.id,
    name: hiveModel.name,
    amountCents: hiveModel.amountCents,
    type: TransactionType.values[hiveModel.type],
    category: hiveModel.category,
    date: DateTime.fromMillisecondsSinceEpoch(hiveModel.dateEpochMillis),
    note: hiveModel.note,
  );
}
