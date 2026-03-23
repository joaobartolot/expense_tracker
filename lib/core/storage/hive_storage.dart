import 'package:expense_tracker/core/logging/scoped_log_printer.dart';
import 'package:expense_tracker/features/categories/domain/models/category_item.dart';
import 'package:expense_tracker/features/transactions/domain/models/transaction_item.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:logger/logger.dart';
import 'package:uuid/uuid.dart';

class HiveStorage {
  HiveStorage._();

  static const String categoriesBoxName = 'categories_box';
  static const String transactionsBoxName = 'transactions_box';
  static const String settingsBoxName = 'settings_box';

  static const String categoriesKey = 'categories';
  static const String transactionsKey = 'transactions';
  static const String settingsKey = 'settings';
  static const _uuid = Uuid();
  static final _logger = Logger(printer: ScopedLogPrinter('hive_storage'));

  static Future<void> initialize() async {
    await Hive.initFlutter();

    final categoriesBox = await Hive.openBox(categoriesBoxName);
    final transactionsBox = await Hive.openBox(transactionsBoxName);
    final settingsBox = await Hive.openBox(settingsBoxName);

    if (categoriesBox.get(categoriesKey) == null) {
      await categoriesBox.put(
        categoriesKey,
        _initialCategories.map((category) => category.toMap()).toList(),
      );
    } else {
      final storedCategories =
          (categoriesBox.get(categoriesKey) as List<dynamic>? ?? const [])
              .cast<Map<dynamic, dynamic>>();

      if (storedCategories.any((category) => category['id'] == null)) {
        final migratedCategories = storedCategories
            .map((category) {
              if (category['id'] != null) {
                return Map<dynamic, dynamic>.from(category);
              }

              return {
                ...Map<dynamic, dynamic>.from(category),
                'id': _uuid.v4(),
              };
            })
            .toList(growable: false);

        await categoriesBox.put(categoriesKey, migratedCategories);
      }
    }

    if (transactionsBox.get(transactionsKey) == null) {
      await transactionsBox.put(
        transactionsKey,
        _initialTransactions.map((transaction) => transaction.toMap()).toList(),
      );
    } else {
      await _migrateTransactions(
        categoriesBox: categoriesBox,
        transactionsBox: transactionsBox,
      );
    }

    if (settingsBox.get(settingsKey) == null) {
      await settingsBox.put(settingsKey, _initialSettings);
    }
  }

  static Map<String, dynamic> get _initialSettings {
    return {'displayName': '', 'themePreference': 'system'};
  }

  static List<CategoryItem> get _initialCategories {
    return const [
      CategoryItem(
        id: '9a4d31a8-5e0f-4c44-8ca7-543700196001',
        name: 'Groceries',
        description: 'Food and supermarket runs',
        type: CategoryType.expense,
        icon: Icons.shopping_basket_outlined,
      ),
      CategoryItem(
        id: '9a4d31a8-5e0f-4c44-8ca7-543700196002',
        name: 'Transport',
        description: 'Fuel, metro, and rides',
        type: CategoryType.expense,
        icon: Icons.directions_car_outlined,
      ),
      CategoryItem(
        id: '9a4d31a8-5e0f-4c44-8ca7-543700196003',
        name: 'Dining',
        description: 'Restaurants and coffee stops',
        type: CategoryType.expense,
        icon: Icons.restaurant_outlined,
      ),
      CategoryItem(
        id: '9a4d31a8-5e0f-4c44-8ca7-543700196004',
        name: 'Salary',
        description: 'Primary monthly pay',
        type: CategoryType.income,
        icon: Icons.payments_outlined,
      ),
      CategoryItem(
        id: '9a4d31a8-5e0f-4c44-8ca7-543700196005',
        name: 'Freelance',
        description: 'Side work and consulting',
        type: CategoryType.income,
        icon: Icons.laptop_mac_outlined,
      ),
      CategoryItem(
        id: '9a4d31a8-5e0f-4c44-8ca7-543700196006',
        name: 'Entertainment',
        description: 'Subscriptions and digital services',
        type: CategoryType.expense,
        icon: Icons.play_circle_outline,
      ),
      CategoryItem(
        id: '9a4d31a8-5e0f-4c44-8ca7-543700196007',
        name: 'Refunds',
        description: 'Returned money and reimbursements',
        type: CategoryType.income,
        icon: Icons.replay_circle_filled_outlined,
      ),
    ];
  }

  static List<TransactionItem> get _initialTransactions {
    return [
      TransactionItem(
        id: 'transaction_0001',
        title: 'Salary',
        categoryId: '9a4d31a8-5e0f-4c44-8ca7-543700196004',
        amount: 2400.00,
        date: DateTime.now().subtract(const Duration(hours: 2)),
        type: TransactionType.income,
      ),
      TransactionItem(
        id: 'transaction_0002',
        title: 'Groceries',
        categoryId: '9a4d31a8-5e0f-4c44-8ca7-543700196001',
        amount: 52.30,
        date: DateTime.now().subtract(const Duration(hours: 5)),
        type: TransactionType.expense,
      ),
      TransactionItem(
        id: 'transaction_0003',
        title: 'Coffee',
        categoryId: '9a4d31a8-5e0f-4c44-8ca7-543700196003',
        amount: 3.80,
        date: DateTime.now().subtract(const Duration(days: 1, hours: 1)),
        type: TransactionType.expense,
      ),
      TransactionItem(
        id: 'transaction_0004',
        title: 'Netflix',
        categoryId: '9a4d31a8-5e0f-4c44-8ca7-543700196006',
        amount: 11.99,
        date: DateTime.now().subtract(const Duration(days: 1, hours: 4)),
        type: TransactionType.expense,
      ),
      TransactionItem(
        id: 'transaction_0005',
        title: 'Dinner',
        categoryId: '9a4d31a8-5e0f-4c44-8ca7-543700196003',
        amount: 27.40,
        date: DateTime.now().subtract(const Duration(days: 3, hours: 2)),
        type: TransactionType.expense,
      ),
      TransactionItem(
        id: 'transaction_0006',
        title: 'Refund',
        categoryId: '9a4d31a8-5e0f-4c44-8ca7-543700196007',
        amount: 18.00,
        date: DateTime.now().subtract(const Duration(days: 6)),
        type: TransactionType.income,
      ),
    ];
  }

  static Future<void> _migrateTransactions({
    required Box<dynamic> categoriesBox,
    required Box<dynamic> transactionsBox,
  }) async {
    final storedCategories =
        (categoriesBox.get(categoriesKey) as List<dynamic>? ?? const [])
            .cast<Map<dynamic, dynamic>>();
    final storedTransactions =
        (transactionsBox.get(transactionsKey) as List<dynamic>? ?? const [])
            .cast<Map<dynamic, dynamic>>();

    final categories = storedCategories.map(CategoryItem.fromMap).toList();
    final categoriesByName = {
      for (final category in categories) category.name: category,
    };
    final categoryIds = categories.map((category) => category.id).toSet();
    var categoriesChanged = false;

    final migratedTransactions = storedTransactions
        .map((transaction) {
          final existingCategoryId = transaction['categoryId'] as String?;
          if (existingCategoryId != null &&
              existingCategoryId.isNotEmpty &&
              categoryIds.contains(existingCategoryId)) {
            return {
              'id': transaction['id'],
              'title': transaction['title'],
              'categoryId': existingCategoryId,
              'amount': transaction['amount'],
              'date': transaction['date'],
              'type': transaction['type'],
            };
          }

          final legacyCategoryName = transaction['subtitle'] as String?;
          CategoryItem? category = legacyCategoryName == null
              ? null
              : categoriesByName[legacyCategoryName];

          if (category == null &&
              legacyCategoryName != null &&
              legacyCategoryName.isNotEmpty) {
            category = CategoryItem(
              id: _uuid.v4(),
              name: legacyCategoryName,
              description: 'Migrated from existing transaction data',
              type: (transaction['type'] as String? ?? 'expense') == 'income'
                  ? CategoryType.income
                  : CategoryType.expense,
              icon: _deserializeLegacyIcon(
                transaction['icon'] as Map<dynamic, dynamic>?,
              ),
            );
            categories.add(category);
            categoriesByName[category.name] = category;
            categoryIds.add(category.id);
            categoriesChanged = true;
            _logger.w(
              'Created missing category "${category.name}" during transaction migration.',
            );
          }

          return {
            'id': transaction['id'],
            'title': transaction['title'],
            'categoryId': category?.id ?? '',
            'amount': transaction['amount'],
            'date': transaction['date'],
            'type': transaction['type'],
          };
        })
        .toList(growable: false);

    if (categoriesChanged) {
      await categoriesBox.put(
        categoriesKey,
        categories.map((category) => category.toMap()).toList(growable: false),
      );
    }

    final hasLegacyTransactions = storedTransactions.any(
      (transaction) =>
          transaction['categoryId'] == null || transaction['subtitle'] != null,
    );

    if (hasLegacyTransactions) {
      await transactionsBox.put(transactionsKey, migratedTransactions);
      _logger.i('Migrated stored transactions to categoryId references.');
    }
  }

  static IconData _deserializeLegacyIcon(Map<dynamic, dynamic>? map) {
    if (map == null) {
      return Icons.sell_outlined;
    }

    return IconData(
      map['codePoint'] as int? ?? Icons.sell_outlined.codePoint,
      fontFamily: map['fontFamily'] as String?,
      fontPackage: map['fontPackage'] as String?,
      matchTextDirection: map['matchTextDirection'] as bool? ?? false,
    );
  }
}
