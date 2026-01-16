import 'package:expense_tracker/features/transactions/data/datasources/transactions_data_source.dart';
import 'package:expense_tracker/features/transactions/data/mappers/transaction_mapper.dart';
import 'package:expense_tracker/features/transactions/domain/models/transaction.dart';
import 'package:expense_tracker/features/transactions/domain/repositories/transactions_repository.dart';

class TransactionsRepositoryImpl implements TransactionsRepository {
  final TransactionsDataSource _ds;

  TransactionsRepositoryImpl(this._ds);

  void _validate(Transaction tx) {
    if (tx.name.trim().isEmpty) {
      throw ArgumentError('Transaction name cannot be empty.');
    }
    if (tx.amountCents <= 0) {
      throw ArgumentError('Amount must be > 0.');
    }
    if (tx.category.trim().isEmpty) {
      throw ArgumentError('Category cannot be empty.');
    }
  }

  List<Transaction> _sortDesc(List<Transaction> list) {
    list.sort((a, b) => b.date.compareTo(a.date));
    return list;
  }

  bool _sameMonth(DateTime d, DateTime month) =>
      d.year == month.year && d.month == month.month;

  @override
  Future<void> init() => _ds.init();

  @override
  Future<void> upsert(Transaction transaction) {
    _validate(transaction);
    return _ds.upsert(toHive(transaction));
  }

  @override
  Future<void> deleteById(String id) => _ds.deleteById(id);

  @override
  Future<void> clear() => _ds.clear();

  @override
  Future<Transaction?> getById(String id) async {
    final model = await _ds.getById(id);
    if (model == null) {
      return null;
    }
    return toDomain(model);
  }

  @override
  Future<List<Transaction>> listAll() async {
    final models = await _ds.listAll();
    final transactions = models.map((m) => toDomain(m)).toList();
    return _sortDesc(transactions);
  }

  @override
  Future<List<Transaction>> listByCategory(String category) async {
    final models = await _ds.listByCategory(category);
    final transactions = models.map((m) => toDomain(m)).toList();
    return _sortDesc(transactions);
  }

  @override
  Stream<List<Transaction>> watchAll() async* {
    await for (final models in _ds.watchAll()) {
      final transactions = models.map((m) => toDomain(m)).toList();
      yield _sortDesc(transactions);
    }
  }

  @override
  Stream<List<Transaction>> watchByMonth(DateTime month) async* {
    await for (final models in _ds.watchAll()) {
      final transactions = models
          .map((m) => toDomain(m))
          .where((tx) => _sameMonth(tx.date, month))
          .toList();
      yield _sortDesc(transactions);
    }
  }
}
