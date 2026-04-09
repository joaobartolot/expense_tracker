import 'package:expense_tracker/core/utils/currency_conversion_service.dart';
import 'package:expense_tracker/features/categories/domain/models/category_item.dart';
import 'package:expense_tracker/features/transactions/data/exchange_rate_service.dart';
import 'package:expense_tracker/features/transactions/data/transaction_repository.dart';
import 'package:expense_tracker/features/transactions/domain/models/transaction_item.dart';
import 'package:expense_tracker/features/transactions/domain/services/transaction_balance_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

void main() {
  late InMemoryTransactionRepository transactionRepository;
  late TransactionBalanceService service;

  setUp(() {
    transactionRepository = InMemoryTransactionRepository();
    service = TransactionBalanceService(
      currencyConversionService: CurrencyConversionService(
        exchangeRateService: const _UnusedExchangeRateService(),
      ),
      transactionRepository: transactionRepository,
    );
  });

  group('transaction balance service removal guardrails', () {
    test(
      'save fails instead of falling back when account resolution fails',
      () async {
        final transaction = TransactionItem(
          id: 'missing-account-transaction',
          title: 'Lunch',
          amount: 1250,
          currencyCode: 'EUR',
          date: DateTime(2026, 4, 8),
          type: TransactionType.expense,
          accountId: 'missing-account',
          categoryId: 'category-1',
        );

        await expectLater(
          service.saveTransaction(
            transaction,
            isEditing: false,
            currentAccounts: const [],
            currentCategories: const [
              CategoryItem(
                id: 'category-1',
                name: 'Food',
                description: '',
                type: CategoryType.expense,
                icon: Icons.restaurant_outlined,
              ),
            ],
          ),
          throwsA(
            isA<StateError>().having(
              (error) => error.message,
              'message',
              'Could not resolve the transaction account.',
            ),
          ),
        );

        expect(transactionRepository.transactions, isEmpty);
      },
    );
  });
}

class InMemoryTransactionRepository implements TransactionRepository {
  final List<TransactionItem> transactions = [];

  @override
  Future<void> addTransaction(TransactionItem transaction) async {
    transactions.add(transaction);
  }

  @override
  String createTransactionId() => 'generated-transaction-id';

  @override
  Future<void> deleteTransaction(String transactionId) async {
    transactions.removeWhere((transaction) => transaction.id == transactionId);
  }

  @override
  Future<List<TransactionItem>> getTransactions() async {
    return List<TransactionItem>.from(transactions);
  }

  @override
  ValueListenable<Box<dynamic>> listenable() => _DummyBoxListenable();

  @override
  Future<void> updateTransaction(TransactionItem transaction) async {}
}

class _UnusedExchangeRateService extends ExchangeRateService {
  const _UnusedExchangeRateService();

  @override
  Future<double> fetchExchangeRate({
    required String fromCurrencyCode,
    required String toCurrencyCode,
    required DateTime date,
  }) async {
    throw UnimplementedError();
  }
}

class _DummyBoxListenable extends ChangeNotifier
    implements ValueListenable<Box<dynamic>> {
  @override
  Box<dynamic> get value => throw UnimplementedError();
}
