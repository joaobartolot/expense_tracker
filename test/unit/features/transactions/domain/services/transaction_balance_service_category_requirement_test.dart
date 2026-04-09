import 'package:expense_tracker/core/utils/currency_conversion_service.dart';
import 'package:expense_tracker/features/accounts/domain/models/account.dart';
import 'package:expense_tracker/features/transactions/data/transaction_repository.dart';
import 'package:expense_tracker/features/transactions/domain/models/transaction_item.dart';
import 'package:expense_tracker/features/transactions/domain/services/transaction_balance_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:mocktail/mocktail.dart';

void main() {
  late MockCurrencyConversionService currencyConversionService;
  late FakeTransactionRepository transactionRepository;
  late TransactionBalanceService service;
  late Account account;
  late TransactionItem existingTransaction;

  setUpAll(() {
    registerFallbackValue(_transaction());
  });

  setUp(() {
    currencyConversionService = MockCurrencyConversionService();
    transactionRepository = FakeTransactionRepository();
    service = TransactionBalanceService(
      currencyConversionService: currencyConversionService,
      transactionRepository: transactionRepository,
    );
    account = _account();
    existingTransaction = _transaction(
      id: '3552ff09-6ee9-4ac0-a4e8-b5d6b8ef0b8f',
      title: 'Existing groceries',
      amount: 1500,
      type: TransactionType.expense,
      categoryId: 'expense-category',
    );
    transactionRepository.transactions.add(existingTransaction);

    when(
      () => currencyConversionService.tryConvertAmount(
        amount: any(named: 'amount'),
        fromCurrencyCode: any(named: 'fromCurrencyCode'),
        toCurrencyCode: any(named: 'toCurrencyCode'),
        date: any(named: 'date'),
      ),
    ).thenAnswer(
      (invocation) async => invocation.namedArguments[#amount] as double,
    );
  });

  Future<void> saveCreate(TransactionItem transaction) {
    return service.saveTransaction(
      transaction,
      isEditing: false,
      currentAccounts: [account],
    );
  }

  Future<void> saveEdit(TransactionItem transaction) {
    return service.saveTransaction(
      transaction,
      isEditing: true,
      previousTransaction: existingTransaction,
      currentAccounts: [account],
    );
  }

  group('category requirement', () {
    test('rejects create when category is missing', () async {
      await expectLater(
        saveCreate(_transaction().copyWith(clearCategoryId: true)),
        throwsA(anything),
      );

      expect(transactionRepository.transactions, [existingTransaction]);
      expect(transactionRepository.addCallCount, 0);
      expect(transactionRepository.updateCallCount, 0);
    });

    test('rejects edit when category is missing', () async {
      await expectLater(
        saveEdit(existingTransaction.copyWith(clearCategoryId: true)),
        throwsA(anything),
      );

      expect(transactionRepository.transactions, [existingTransaction]);
      expect(transactionRepository.addCallCount, 0);
      expect(transactionRepository.updateCallCount, 0);
    });

    test('rejects create when category is unresolved', () async {
      await expectLater(
        saveCreate(_transaction(categoryId: 'missing-category')),
        throwsA(anything),
      );

      expect(transactionRepository.transactions, [existingTransaction]);
      expect(transactionRepository.addCallCount, 0);
      expect(transactionRepository.updateCallCount, 0);
    });

    test('rejects edit when category is unresolved', () async {
      await expectLater(
        saveEdit(existingTransaction.copyWith(categoryId: 'missing-category')),
        throwsA(anything),
      );

      expect(transactionRepository.transactions, [existingTransaction]);
      expect(transactionRepository.addCallCount, 0);
      expect(transactionRepository.updateCallCount, 0);
    });

    test(
      'rejects create when category does not match the transaction type',
      () async {
        await expectLater(
          saveCreate(
            _transaction(
              type: TransactionType.income,
              categoryId: 'expense-category',
            ),
          ),
          throwsA(anything),
        );

        expect(transactionRepository.transactions, [existingTransaction]);
        expect(transactionRepository.addCallCount, 0);
        expect(transactionRepository.updateCallCount, 0);
      },
    );

    test(
      'rejects edit when category does not match the transaction type',
      () async {
        await expectLater(
          saveEdit(
            existingTransaction.copyWith(
              type: TransactionType.income,
              categoryId: 'expense-category',
            ),
          ),
          throwsA(anything),
        );

        expect(transactionRepository.transactions, [existingTransaction]);
        expect(transactionRepository.addCallCount, 0);
        expect(transactionRepository.updateCallCount, 0);
      },
    );
  });
}

class MockCurrencyConversionService extends Mock
    implements CurrencyConversionService {}

class FakeTransactionRepository extends Fake implements TransactionRepository {
  final List<TransactionItem> transactions = [];
  int addCallCount = 0;
  int updateCallCount = 0;

  @override
  Future<void> addTransaction(TransactionItem transaction) async {
    addCallCount += 1;
    transactions.add(transaction);
  }

  @override
  String createTransactionId() => 'generated-id';

  @override
  Future<void> deleteTransaction(String transactionId) async {
    transactions.removeWhere((transaction) => transaction.id == transactionId);
  }

  @override
  Future<List<TransactionItem>> getTransactions() async {
    return List<TransactionItem>.from(transactions);
  }

  @override
  ValueListenable<Box<dynamic>> listenable() {
    throw UnimplementedError();
  }

  @override
  Future<void> updateTransaction(TransactionItem transaction) async {
    updateCallCount += 1;
    final index = transactions.indexWhere((item) => item.id == transaction.id);
    if (index != -1) {
      transactions[index] = transaction;
    }
  }
}

Account _account() {
  return const Account(
    id: 'account-1',
    name: 'Main account',
    type: AccountType.bank,
    openingBalance: 0,
    currencyCode: 'EUR',
  );
}

TransactionItem _transaction({
  String id = 'd5aa2a98-7732-4698-a578-e51f246c78db',
  String title = 'Groceries',
  double amount = 1000,
  String currencyCode = 'EUR',
  DateTime? date,
  TransactionType type = TransactionType.expense,
  String accountId = 'account-1',
  String categoryId = 'expense-category',
}) {
  return TransactionItem(
    id: id,
    title: title,
    amount: amount,
    currencyCode: currencyCode,
    date: date ?? DateTime(2026, 4, 8),
    type: type,
    accountId: accountId,
    categoryId: categoryId,
  );
}
