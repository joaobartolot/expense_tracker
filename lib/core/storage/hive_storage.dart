import 'package:expense_tracker/features/accounts/domain/models/account.dart';
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
  static const String accountsBoxName = 'accounts_box';

  static const String categoriesKey = 'categories';
  static const String transactionsKey = 'transactions';
  static const String settingsKey = 'settings';
  static const String accountsKey = 'accounts';
  static const _uuid = Uuid();
  static final _uuidPattern = RegExp(
    r'^[0-9a-fA-F]{8}-'
    r'[0-9a-fA-F]{4}-'
    r'[0-9a-fA-F]{4}-'
    r'[0-9a-fA-F]{4}-'
    r'[0-9a-fA-F]{12}$',
  );
  static final _logger = Logger(printer: ScopedLogPrinter('hive_storage'));

  static Future<void> initialize() async {
    await Hive.initFlutter();
    _pendingCategoryIdRemap = {};
    _pendingAccountIdRemap = {};

    final categoriesBox = await Hive.openBox(categoriesBoxName);
    final accountsBox = await Hive.openBox(accountsBoxName);
    final transactionsBox = await Hive.openBox(transactionsBoxName);
    final settingsBox = await Hive.openBox(settingsBoxName);

    if (categoriesBox.get(categoriesKey) == null) {
      await categoriesBox.put(
        categoriesKey,
        _initialCategories.map((category) => category.toMap()).toList(),
      );
    } else {
      final categoryIdRemap = await _migrateEntityIds(
        box: categoriesBox,
        key: categoriesKey,
        scopeName: 'categories',
      );
      _pendingCategoryIdRemap = categoryIdRemap;
    }

    if (accountsBox.get(accountsKey) == null) {
      await accountsBox.put(
        accountsKey,
        _initialAccounts.map((account) => account.toMap()).toList(),
      );
    } else {
      final accountIdRemap = await _migrateEntityIds(
        box: accountsBox,
        key: accountsKey,
        scopeName: 'accounts',
      );
      _pendingAccountIdRemap = accountIdRemap;
    }

    if (transactionsBox.get(transactionsKey) == null) {
      await transactionsBox.put(
        transactionsKey,
        _initialTransactions.map((transaction) => transaction.toMap()).toList(),
      );
    } else {
      await _migrateTransactions(
        categoriesBox: categoriesBox,
        accountsBox: accountsBox,
        transactionsBox: transactionsBox,
        categoryIdRemap: _pendingCategoryIdRemap,
        accountIdRemap: _pendingAccountIdRemap,
      );
    }

    if (settingsBox.get(settingsKey) == null) {
      await settingsBox.put(settingsKey, _initialSettings);
    }
  }

  static Map<String, dynamic> get _initialSettings {
    return {
      'displayName': '',
      'themePreference': 'system',
      'defaultCurrencyCode': 'EUR',
    };
  }

  static Map<String, String> _pendingCategoryIdRemap = {};
  static Map<String, String> _pendingAccountIdRemap = {};

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
        id: 'b830b4ce-7fdc-4db0-86f1-d011c20d9001',
        title: 'Salary',
        categoryId: '9a4d31a8-5e0f-4c44-8ca7-543700196004',
        accountId: 'b830b4ce-7fdc-4db0-86f1-d011c20da001',
        amount: 2400.00,
        currencyCode: 'EUR',
        date: DateTime.now().subtract(const Duration(hours: 2)),
        type: TransactionType.income,
      ),
      TransactionItem(
        id: 'b830b4ce-7fdc-4db0-86f1-d011c20d9002',
        title: 'Groceries',
        categoryId: '9a4d31a8-5e0f-4c44-8ca7-543700196001',
        accountId: 'b830b4ce-7fdc-4db0-86f1-d011c20da001',
        amount: 52.30,
        currencyCode: 'EUR',
        date: DateTime.now().subtract(const Duration(hours: 5)),
        type: TransactionType.expense,
      ),
      TransactionItem(
        id: 'b830b4ce-7fdc-4db0-86f1-d011c20d9003',
        title: 'Coffee',
        categoryId: '9a4d31a8-5e0f-4c44-8ca7-543700196003',
        accountId: 'b830b4ce-7fdc-4db0-86f1-d011c20da004',
        amount: 3.80,
        currencyCode: 'EUR',
        date: DateTime.now().subtract(const Duration(days: 1, hours: 1)),
        type: TransactionType.expense,
      ),
      TransactionItem(
        id: 'b830b4ce-7fdc-4db0-86f1-d011c20d9004',
        title: 'Netflix',
        categoryId: '9a4d31a8-5e0f-4c44-8ca7-543700196006',
        accountId: 'b830b4ce-7fdc-4db0-86f1-d011c20da004',
        amount: 11.99,
        currencyCode: 'EUR',
        date: DateTime.now().subtract(const Duration(days: 1, hours: 4)),
        type: TransactionType.expense,
      ),
      TransactionItem(
        id: 'b830b4ce-7fdc-4db0-86f1-d011c20d9005',
        title: 'Dinner',
        categoryId: '9a4d31a8-5e0f-4c44-8ca7-543700196003',
        accountId: 'b830b4ce-7fdc-4db0-86f1-d011c20da001',
        amount: 27.40,
        currencyCode: 'EUR',
        date: DateTime.now().subtract(const Duration(days: 3, hours: 2)),
        type: TransactionType.expense,
      ),
      TransactionItem(
        id: 'b830b4ce-7fdc-4db0-86f1-d011c20d9006',
        title: 'Refund',
        categoryId: '9a4d31a8-5e0f-4c44-8ca7-543700196007',
        accountId: 'b830b4ce-7fdc-4db0-86f1-d011c20da001',
        amount: 18.00,
        currencyCode: 'EUR',
        date: DateTime.now().subtract(const Duration(days: 6)),
        type: TransactionType.income,
      ),
    ];
  }

  static List<Account> get _initialAccounts {
    return const [
      Account(
        id: 'b830b4ce-7fdc-4db0-86f1-d011c20da001',
        name: 'Main Bank',
        type: AccountType.bank,
        balance: 1850.45,
        currencyCode: 'EUR',
        description: 'Daily spending and incoming salary',
      ),
      Account(
        id: 'b830b4ce-7fdc-4db0-86f1-d011c20da002',
        name: 'Wallet',
        type: AccountType.cash,
        balance: 120.00,
        currencyCode: 'EUR',
        description: 'Cash on hand',
      ),
      Account(
        id: 'b830b4ce-7fdc-4db0-86f1-d011c20da003',
        name: 'Travel Savings',
        type: AccountType.savings,
        balance: 940.00,
        currencyCode: 'EUR',
        description: 'Set aside for future trips',
      ),
      Account(
        id: 'b830b4ce-7fdc-4db0-86f1-d011c20da004',
        name: 'Everyday Card',
        type: AccountType.creditCard,
        balance: -286.70,
        currencyCode: 'EUR',
        description: 'Monthly card spending',
        creditCardDueDay: 12,
        paymentTracking: CreditCardPaymentTracking.manual,
      ),
    ];
  }

  static Future<void> _migrateTransactions({
    required Box<dynamic> categoriesBox,
    required Box<dynamic> accountsBox,
    required Box<dynamic> transactionsBox,
    required Map<String, String> categoryIdRemap,
    required Map<String, String> accountIdRemap,
  }) async {
    final storedCategories =
        (categoriesBox.get(categoriesKey) as List<dynamic>? ?? const [])
            .cast<Map<dynamic, dynamic>>();
    final storedTransactions =
        (transactionsBox.get(transactionsKey) as List<dynamic>? ?? const [])
            .cast<Map<dynamic, dynamic>>();
    final storedAccounts =
        (accountsBox.get(accountsKey) as List<dynamic>? ?? const [])
            .cast<Map<dynamic, dynamic>>();

    final categories = storedCategories.map(CategoryItem.fromMap).toList();
    final accounts = storedAccounts.map(Account.fromMap).toList();
    final categoriesByName = {
      for (final category in categories) category.name: category,
    };
    final accountsById = {for (final account in accounts) account.id: account};
    final defaultAccountId = accounts.isEmpty ? '' : accounts.first.id;
    final categoryIds = categories.map((category) => category.id).toSet();
    final accountIds = accounts.map((account) => account.id).toSet();
    var categoriesChanged = false;

    final migratedTransactions = storedTransactions
        .map((transaction) {
          final type = TransactionItem.fromMap(transaction).type;
          final existingAccountId = _remapId(
            transaction['accountId'] as String?,
            accountIdRemap,
          );
          final existingSourceAccountId = _remapId(
            transaction['sourceAccountId'] as String?,
            accountIdRemap,
          );
          final existingDestinationAccountId = _remapId(
            transaction['destinationAccountId'] as String?,
            accountIdRemap,
          );
          final existingCategoryId = _remapId(
            transaction['categoryId'] as String?,
            categoryIdRemap,
          );
          final existingTransactionId = transaction['id'] as String?;
          final resolvedTransactionId = _normalizeId(existingTransactionId);
          final hasValidTransferAccounts =
              existingSourceAccountId != null &&
              existingDestinationAccountId != null &&
              existingSourceAccountId.isNotEmpty &&
              existingDestinationAccountId.isNotEmpty &&
              accountIds.contains(existingSourceAccountId) &&
              accountIds.contains(existingDestinationAccountId);
          final hasValidStandardReferences =
              existingCategoryId != null &&
              existingCategoryId.isNotEmpty &&
              categoryIds.contains(existingCategoryId) &&
              existingAccountId != null &&
              existingAccountId.isNotEmpty &&
              accountIds.contains(existingAccountId);

          if ((type == TransactionType.transfer && hasValidTransferAccounts) ||
              (type != TransactionType.transfer &&
                  hasValidStandardReferences)) {
            return {
              'id': resolvedTransactionId,
              'title': transaction['title'],
              'categoryId': type == TransactionType.transfer
                  ? null
                  : existingCategoryId,
              'accountId': type == TransactionType.transfer
                  ? null
                  : existingAccountId,
              'amount': transaction['amount'],
              'currencyCode':
                  transaction['currencyCode'] ??
                  accountsById[existingAccountId]?.currencyCode ??
                  accountsById[existingSourceAccountId]?.currencyCode ??
                  'EUR',
              'date': transaction['date'],
              'type': transaction['type'],
              'sourceAccountId': type == TransactionType.transfer
                  ? existingSourceAccountId
                  : null,
              'destinationAccountId': type == TransactionType.transfer
                  ? existingDestinationAccountId
                  : null,
              'foreignAmount': transaction['foreignAmount'],
              'foreignCurrencyCode': transaction['foreignCurrencyCode'],
              'exchangeRate': transaction['exchangeRate'],
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

          final resolvedAccountId = accountIds.contains(existingAccountId)
              ? existingAccountId
              : defaultAccountId;
          final resolvedSourceAccountId =
              accountIds.contains(existingSourceAccountId)
              ? existingSourceAccountId
              : defaultAccountId;
          final resolvedDestinationAccountId =
              accountIds.contains(existingDestinationAccountId)
              ? existingDestinationAccountId
              : defaultAccountId;

          return {
            'id': resolvedTransactionId,
            'title': transaction['title'],
            'categoryId': type == TransactionType.transfer
                ? null
                : category?.id,
            'accountId': type == TransactionType.transfer
                ? null
                : resolvedAccountId,
            'amount': transaction['amount'],
            'currencyCode':
                transaction['currencyCode'] ??
                accountsById[resolvedAccountId]?.currencyCode ??
                'EUR',
            'date': transaction['date'],
            'type': transaction['type'],
            'sourceAccountId': type == TransactionType.transfer
                ? resolvedSourceAccountId
                : null,
            'destinationAccountId': type == TransactionType.transfer
                ? resolvedDestinationAccountId
                : null,
            'foreignAmount': transaction['foreignAmount'],
            'foreignCurrencyCode': transaction['foreignCurrencyCode'],
            'exchangeRate': transaction['exchangeRate'],
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
          (((transaction['type'] as String?) ?? '') !=
                  TransactionType.transfer.name &&
              transaction['categoryId'] == null) ||
          transaction['subtitle'] != null ||
          ((((transaction['type'] as String?) ?? '') !=
                  TransactionType.transfer.name) &&
              transaction['accountId'] == null) ||
          transaction['currencyCode'] == null ||
          !_isUuid(transaction['id'] as String?) ||
          categoryIdRemap.containsKey(
            transaction['categoryId'] as String? ?? '',
          ) ||
          accountIdRemap.containsKey(
            transaction['accountId'] as String? ?? '',
          ) ||
          accountIdRemap.containsKey(
            transaction['sourceAccountId'] as String? ?? '',
          ) ||
          accountIdRemap.containsKey(
            transaction['destinationAccountId'] as String? ?? '',
          ) ||
          (((transaction['type'] as String?) ?? '') ==
                  TransactionType.transfer.name
              ? !accountIds.contains(
                      transaction['sourceAccountId'] as String? ?? '',
                    ) ||
                    !accountIds.contains(
                      transaction['destinationAccountId'] as String? ?? '',
                    )
              : !accountIds.contains(
                  transaction['accountId'] as String? ?? '',
                )),
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

  static Future<Map<String, String>> _migrateEntityIds({
    required Box<dynamic> box,
    required String key,
    required String scopeName,
  }) async {
    final storedItems = (box.get(key) as List<dynamic>? ?? const [])
        .cast<Map<dynamic, dynamic>>();

    final hasLegacyIds = storedItems.any(
      (item) => !_isUuid(item['id'] as String?),
    );
    if (!hasLegacyIds) {
      return const {};
    }

    final idRemap = <String, String>{};
    final migratedItems = storedItems
        .map((item) {
          final existingId = item['id'] as String?;
          final migratedId = _normalizeId(existingId);

          if (existingId != null &&
              existingId.isNotEmpty &&
              existingId != migratedId) {
            idRemap[existingId] = migratedId;
          }

          return {...Map<dynamic, dynamic>.from(item), 'id': migratedId};
        })
        .toList(growable: false);

    await box.put(key, migratedItems);
    _logger.i('Migrated $scopeName IDs to UUID format.');
    return idRemap;
  }

  static bool _isUuid(String? value) {
    if (value == null || value.isEmpty) {
      return false;
    }

    return _uuidPattern.hasMatch(value);
  }

  static String _normalizeId(String? value) {
    if (_isUuid(value)) {
      return value!;
    }

    return _uuid.v4();
  }

  static String? _remapId(String? value, Map<String, String> idRemap) {
    if (value == null || value.isEmpty) {
      return value;
    }

    return idRemap[value] ?? value;
  }
}
