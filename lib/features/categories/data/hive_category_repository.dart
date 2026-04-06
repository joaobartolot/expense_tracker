import 'package:expense_tracker/core/logging/scoped_log_printer.dart';
import 'package:expense_tracker/core/storage/hive_storage.dart';
import 'package:expense_tracker/features/categories/data/category_repository.dart';
import 'package:expense_tracker/features/categories/domain/models/category_item.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:logger/logger.dart';

final _logger = Logger(printer: ScopedLogPrinter('categories_repository'));

class HiveCategoryRepository implements CategoryRepository {
  HiveCategoryRepository() : _box = Hive.box(HiveStorage.categoriesBoxName);

  final Box<dynamic> _box;

  @override
  ValueListenable<Box<dynamic>> listenable() {
    return _box.listenable(keys: [HiveStorage.categoriesKey]);
  }

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
      await _saveCategories(categories);
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

  @override
  Future<void> updateCategory(CategoryItem category) async {
    try {
      final categories = _readCategories();
      final index = categories.indexWhere((item) => item.id == category.id);
      if (index == -1) {
        _logger.w('Skipped update for missing category ${category.id}.');
        return;
      }

      categories[index] = category;
      await _saveCategories(categories);
      _logger.i('Updated category ${category.id}.');
    } catch (error, stackTrace) {
      _logger.e(
        'Failed to update category ${category.id}.',
        error: error,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  @override
  Future<void> deleteCategory(String categoryId) async {
    try {
      final categories = _readCategories()
        ..removeWhere((category) => category.id == categoryId);
      await _saveCategories(categories);
      _logger.i('Deleted category $categoryId.');
    } catch (error, stackTrace) {
      _logger.e(
        'Failed to delete category $categoryId.',
        error: error,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  Future<void> _saveCategories(List<CategoryItem> categories) {
    return _box.put(
      HiveStorage.categoriesKey,
      categories.map((item) => item.toMap()).toList(growable: false),
    );
  }

  List<CategoryItem> _readCategories() {
    final storedCategories =
        (_box.get(HiveStorage.categoriesKey) as List<dynamic>? ?? const [])
            .cast<Map<dynamic, dynamic>>();

    final categories = <CategoryItem>[];
    for (final map in storedCategories) {
      try {
        categories.add(CategoryItem.fromMap(map));
      } catch (error, stackTrace) {
        _logger.w(
          'Skipped invalid stored category entry.',
          error: error,
          stackTrace: stackTrace,
        );
      }
    }

    return categories;
  }
}
