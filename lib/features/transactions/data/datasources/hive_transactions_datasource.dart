import 'package:expense_tracker/features/transactions/data/datasources/transactions_data_source.dart';
import 'package:hive/hive.dart';

import '../models/transaction_hive_model.dart';

class HiveTransactionsDataSource implements TransactionsDataSource {
  HiveTransactionsDataSource({this.boxName = 'transactionsBox'});

  final String boxName;
  Box<TransactionHiveModel>? _box;

  @override
  Future<void> init() async {
    if (_box?.isOpen == true) return;
    _box = await Hive.openBox<TransactionHiveModel>(boxName);
  }

  Box<TransactionHiveModel> get _requireBox {
    final box = _box;
    if (box == null || !box.isOpen) {
      throw StateError(
        'Hive box not initialized. Call init() before using the data source.',
      );
    }
    return box;
  }

  @override
  Future<void> upsert(TransactionHiveModel tx) async {
    final box = _requireBox;
    await box.put(tx.id, tx);
  }

  @override
  Future<void> deleteById(String id) async {
    final box = _requireBox;
    await box.delete(id);
  }

  @override
  Future<void> clear() async {
    final box = _requireBox;
    await box.clear();
  }

  @override
  Future<TransactionHiveModel?> getById(String id) async {
    final box = _requireBox;
    return box.get(id);
  }

  @override
  Future<List<TransactionHiveModel>> listAll() async {
    final box = _requireBox;
    final items = box.values.toList(growable: false);
    return _sortNewestFirst(items);
  }

  @override
  Future<List<TransactionHiveModel>> listByCategory(String category) async {
    final box = _requireBox;
    final items = box.values
        .where((t) => t.category == category)
        .toList(growable: false);
    return _sortNewestFirst(items);
  }

  @override
  Stream<List<TransactionHiveModel>> watchAll() async* {
    final box = _requireBox;

    // Emit immediately, then on every change
    yield _sortNewestFirst(box.values.toList(growable: false));

    yield* box.watch().map((_) {
      return _sortNewestFirst(box.values.toList(growable: false));
    });
  }

  List<TransactionHiveModel> _sortNewestFirst(
    List<TransactionHiveModel> items,
  ) {
    final list = List<TransactionHiveModel>.from(items);
    list.sort((a, b) => b.dateEpochMillis.compareTo(a.dateEpochMillis));
    return list;
  }
}
