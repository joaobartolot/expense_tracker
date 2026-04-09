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
  late TransactionItem validTransaction;
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
    validTransaction = _transaction();
    existingTransaction = _transaction(
      id: '1a666ffe-f4af-4d43-b81d-e0296783237e',
      title: 'Existing transaction',
      amount: 900,
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

  group('basic invalid input rejection', () {
    test('rejects create when name is empty', () async {
      await expectLater(
        saveCreate(validTransaction.copyWith(title: '')),
        throwsA(anything),
      );

      expect(transactionRepository.transactions, [existingTransaction]);
      expect(transactionRepository.addCallCount, 0);
      expect(transactionRepository.updateCallCount, 0);
    });

    test('rejects edit when name is empty', () async {
      final invalidUpdate = existingTransaction.copyWith(title: '');

      await expectLater(saveEdit(invalidUpdate), throwsA(anything));

      expect(transactionRepository.transactions, [existingTransaction]);
      expect(transactionRepository.addCallCount, 0);
      expect(transactionRepository.updateCallCount, 0);
    });

    test('rejects create when name is blank only', () async {
      await expectLater(
        saveCreate(validTransaction.copyWith(title: '   ')),
        throwsA(anything),
      );

      expect(transactionRepository.transactions, [existingTransaction]);
      expect(transactionRepository.addCallCount, 0);
      expect(transactionRepository.updateCallCount, 0);
    });

    test('rejects edit when name is blank only', () async {
      final invalidUpdate = existingTransaction.copyWith(title: '   ');

      await expectLater(saveEdit(invalidUpdate), throwsA(anything));

      expect(transactionRepository.transactions, [existingTransaction]);
      expect(transactionRepository.addCallCount, 0);
      expect(transactionRepository.updateCallCount, 0);
    });

    test('rejects create when amount is zero', () async {
      await expectLater(
        saveCreate(validTransaction.copyWith(amount: 0)),
        throwsA(anything),
      );

      expect(transactionRepository.transactions, [existingTransaction]);
      expect(transactionRepository.addCallCount, 0);
    });

    test('rejects edit when amount is zero', () async {
      await expectLater(
        saveEdit(existingTransaction.copyWith(amount: 0)),
        throwsA(anything),
      );

      expect(transactionRepository.transactions, [existingTransaction]);
      expect(transactionRepository.updateCallCount, 0);
    });

    test('rejects create when amount is negative', () async {
      await expectLater(
        saveCreate(validTransaction.copyWith(amount: -1)),
        throwsA(anything),
      );

      expect(transactionRepository.transactions, [existingTransaction]);
      expect(transactionRepository.addCallCount, 0);
    });

    test('rejects edit when amount is negative', () async {
      await expectLater(
        saveEdit(existingTransaction.copyWith(amount: -1)),
        throwsA(anything),
      );

      expect(transactionRepository.transactions, [existingTransaction]);
      expect(transactionRepository.updateCallCount, 0);
    });

    test('rejects create when account is missing', () async {
      await expectLater(
        saveCreate(validTransaction.copyWith(clearAccountId: true)),
        throwsA(anything),
      );

      expect(transactionRepository.transactions, [existingTransaction]);
      expect(transactionRepository.addCallCount, 0);
    });

    test('rejects edit when account is missing', () async {
      await expectLater(
        saveEdit(existingTransaction.copyWith(clearAccountId: true)),
        throwsA(anything),
      );

      expect(transactionRepository.transactions, [existingTransaction]);
      expect(transactionRepository.updateCallCount, 0);
    });

    test('rejects create when category is missing', () async {
      await expectLater(
        saveCreate(validTransaction.copyWith(clearCategoryId: true)),
        throwsA(anything),
      );

      expect(transactionRepository.transactions, [existingTransaction]);
      expect(transactionRepository.addCallCount, 0);
    });

    test('rejects edit when category is missing', () async {
      await expectLater(
        saveEdit(existingTransaction.copyWith(clearCategoryId: true)),
        throwsA(anything),
      );

      expect(transactionRepository.transactions, [existingTransaction]);
      expect(transactionRepository.updateCallCount, 0);
    });

    test('rejects create when required exchange rate is unavailable', () async {
      final foreignTransaction = validTransaction.copyWith(
        amount: 1000,
        currencyCode: 'USD',
        foreignAmount: 1000,
        foreignCurrencyCode: 'USD',
        clearExchangeRate: true,
      );
      when(
        () => currencyConversionService.tryConvertAmount(
          amount: 1000,
          fromCurrencyCode: 'USD',
          toCurrencyCode: 'EUR',
          date: foreignTransaction.date,
        ),
      ).thenAnswer((_) async => null);

      await expectLater(saveCreate(foreignTransaction), throwsStateError);

      expect(transactionRepository.transactions, [existingTransaction]);
      expect(transactionRepository.addCallCount, 0);
      expect(transactionRepository.updateCallCount, 0);
    });

    test('rejects edit when required exchange rate is unavailable', () async {
      final foreignTransaction = existingTransaction.copyWith(
        amount: 1000,
        currencyCode: 'USD',
        foreignAmount: 1000,
        foreignCurrencyCode: 'USD',
        clearExchangeRate: true,
      );
      when(
        () => currencyConversionService.tryConvertAmount(
          amount: 1000,
          fromCurrencyCode: 'USD',
          toCurrencyCode: 'EUR',
          date: foreignTransaction.date,
        ),
      ).thenAnswer((_) async => null);

      await expectLater(saveEdit(foreignTransaction), throwsStateError);

      expect(transactionRepository.transactions, [existingTransaction]);
      expect(transactionRepository.addCallCount, 0);
      expect(transactionRepository.updateCallCount, 0);
    });

    test(
      'rejects combined invalid create input without persisting anything',
      () async {
        final invalidTransaction = validTransaction.copyWith(
          title: '',
          amount: 0,
          clearAccountId: true,
          clearCategoryId: true,
        );

        await expectLater(saveCreate(invalidTransaction), throwsA(anything));

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
  String createTransactionId() {
    return 'generated-id';
  }

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

Account _account({String id = 'account-1', String currencyCode = 'EUR'}) {
  return Account(
    id: id,
    name: 'Main account',
    type: AccountType.bank,
    openingBalance: 0,
    currencyCode: currencyCode,
  );
}

TransactionItem _transaction({
  String id = '385b555b-35ec-4ee4-bf74-f67593834f67',
  String title = 'Groceries',
  double amount = 1000,
  String currencyCode = 'EUR',
  DateTime? date,
  TransactionType type = TransactionType.expense,
  String accountId = 'account-1',
  String categoryId = 'category-1',
  double? foreignAmount,
  String? foreignCurrencyCode,
  double? exchangeRate,
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
    foreignAmount: foreignAmount,
    foreignCurrencyCode: foreignCurrencyCode,
    exchangeRate: exchangeRate,
  );
}
