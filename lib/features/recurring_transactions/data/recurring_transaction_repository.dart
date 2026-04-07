import 'package:expense_tracker/features/recurring_transactions/domain/models/recurring_transaction.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

abstract class RecurringTransactionRepository {
  Future<List<RecurringTransaction>> getRecurringTransactions();
  ValueListenable<Box<dynamic>> listenable();
  Future<void> addRecurringTransaction(
    RecurringTransaction recurringTransaction,
  );
  Future<void> updateRecurringTransaction(
    RecurringTransaction recurringTransaction,
  );
  Future<void> deleteRecurringTransaction(String recurringTransactionId);
  String createRecurringTransactionId();
}
