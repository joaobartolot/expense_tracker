import 'dart:io';

import 'package:expense_tracker/core/storage/hive_storage.dart';
import 'package:expense_tracker/features/categories/data/hive_category_repository.dart';
import 'package:expense_tracker/features/categories/domain/models/category_item.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDirectory;
  late Box<dynamic> categoriesBox;
  late HiveCategoryRepository repository;

  setUp(() async {
    tempDirectory = await Directory.systemTemp.createTemp(
      'vero-hive-category-repository-test-',
    );
    Hive.init(tempDirectory.path);
    categoriesBox = await Hive.openBox<dynamic>(HiveStorage.categoriesBoxName);
    await categoriesBox.put(HiveStorage.categoriesKey, const []);
    repository = HiveCategoryRepository();
  });

  tearDown(() async {
    await Hive.close();
    if (await tempDirectory.exists()) {
      await tempDirectory.delete(recursive: true);
    }
  });

  test('addCategory inserts the new category at the front', () async {
    await _storeCategories(categoriesBox, [
      _category(id: 'category-old', name: 'Old', type: CategoryType.expense),
    ]);

    await repository.addCategory(
      _category(id: 'category-new', name: 'New', type: CategoryType.expense),
    );

    final categories = await repository.getCategories();
    expect(categories.map((category) => category.id), [
      'category-new',
      'category-old',
    ]);
  });

  test('updateCategory replaces an existing category', () async {
    await _storeCategories(categoriesBox, [
      _category(id: 'category-food', name: 'Food', type: CategoryType.expense),
    ]);

    await repository.updateCategory(
      _category(
        id: 'category-food',
        name: 'Dining out',
        type: CategoryType.expense,
      ),
    );

    final categories = await repository.getCategories();
    expect(categories.single.name, 'Dining out');
  });

  test('updateCategory ignores missing categories', () async {
    await _storeCategories(categoriesBox, [
      _category(id: 'category-food', name: 'Food', type: CategoryType.expense),
    ]);

    await repository.updateCategory(
      _category(id: 'missing', name: 'Missing', type: CategoryType.expense),
    );

    final categories = await repository.getCategories();
    expect(categories.map((category) => category.id), ['category-food']);
  });

  test('deleteCategory removes the matching category', () async {
    await _storeCategories(categoriesBox, [
      _category(id: 'category-food', name: 'Food', type: CategoryType.expense),
      _category(
        id: 'category-salary',
        name: 'Salary',
        type: CategoryType.income,
      ),
    ]);

    await repository.deleteCategory('category-food');

    final categories = await repository.getCategories();
    expect(categories.map((category) => category.id), ['category-salary']);
  });

  test('getCategories skips malformed stored entries', () async {
    await categoriesBox.put(HiveStorage.categoriesKey, [
      _category(
        id: 'category-food',
        name: 'Food',
        type: CategoryType.expense,
      ).toMap(),
      {
        'id': 'broken-category',
        'name': 123,
        'description': 'Broken',
        'type': 'expense',
        'icon': const {'codePoint': 0},
      },
    ]);

    final categories = await repository.getCategories();

    expect(categories.map((category) => category.id), ['category-food']);
  });
}

Future<void> _storeCategories(Box<dynamic> box, List<CategoryItem> categories) {
  return box.put(
    HiveStorage.categoriesKey,
    categories.map((category) => category.toMap()).toList(growable: false),
  );
}

CategoryItem _category({
  required String id,
  required String name,
  required CategoryType type,
}) {
  return CategoryItem(
    id: id,
    name: name,
    description: '$name category',
    type: type,
    icon: Icons.sell_outlined,
  );
}
