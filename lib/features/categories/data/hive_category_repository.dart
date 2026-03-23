import 'package:expense_tracker/core/logging/scoped_log_printer.dart';
import 'package:expense_tracker/core/storage/hive_storage.dart';
import 'package:expense_tracker/features/categories/data/category_repository.dart';
import 'package:expense_tracker/features/categories/domain/models/category_item.dart';
import 'package:hive/hive.dart';
import 'package:logger/logger.dart';

final _logger = Logger(printer: ScopedLogPrinter('categories_repository'));

class HiveCategoryRepository implements CategoryRepository {
  HiveCategoryRepository() : _box = Hive.box(HiveStorage.categoriesBoxName);

  final Box<dynamic> _box;

  @override
  Future<List<CategoryItem>> getCategories() async {
    try {
      return _readCategories();
    } catch (error, stackTrace) {
      _logger.e(
        'Failed to read categories from Hive.',
        error: error,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  @override
  Future<void> addCategory(CategoryItem category) async {
    try {
      final categories = _readCategories()..insert(0, category);
      await _box.put(
        HiveStorage.categoriesKey,
        categories.map((item) => item.toMap()).toList(growable: false),
      );
      _logger.i('Saved category ${category.name}.');
    } catch (error, stackTrace) {
      _logger.e(
        'Failed to add category ${category.name}.',
        error: error,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  List<CategoryItem> _readCategories() {
    final storedCategories =
        (_box.get(HiveStorage.categoriesKey) as List<dynamic>? ?? const [])
            .cast<Map<dynamic, dynamic>>();

    return storedCategories.map(CategoryItem.fromMap).toList();
  }
}
