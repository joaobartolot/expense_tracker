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
  late Account validAccount;
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
    validAccount = _account();
    existingTransaction = _transaction(
      id: 'c1c992ba-60ef-4a5b-894f-782035de1f11',
      title: 'Existing lunch',
      amount: 1100,
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

  Future<void> saveCreate(
    TransactionItem transaction, {
    List<Account>? currentAccounts,
  }) {
    return service.saveTransaction(
      transaction,
      isEditing: false,
      currentAccounts: currentAccounts ?? [validAccount],
    );
  }

  Future<void> saveEdit(
    TransactionItem transaction, {
    List<Account>? currentAccounts,
  }) {
    return service.saveTransaction(
      transaction,
      isEditing: true,
      previousTransaction: existingTransaction,
      currentAccounts: currentAccounts ?? [validAccount],
    );
  }

  group('account requirement', () {
    test('rejects create when account is missing', () async {
      await expectLater(
        saveCreate(_transaction().copyWith(clearAccountId: true)),
        throwsA(anything),
      );

      expect(transactionRepository.transactions, [existingTransaction]);
      expect(transactionRepository.addCallCount, 0);
      expect(transactionRepository.updateCallCount, 0);
    });

    test('rejects edit when account is missing', () async {
      await expectLater(
        saveEdit(existingTransaction.copyWith(clearAccountId: true)),
        throwsA(anything),
      );

      expect(transactionRepository.transactions, [existingTransaction]);
      expect(transactionRepository.addCallCount, 0);
      expect(transactionRepository.updateCallCount, 0);
    });

    test(
      'rejects create when account id is present but cannot be resolved',
      () async {
        final unresolvedTransaction = _transaction(
          accountId: 'missing-account',
        );

        await expectLater(
          saveCreate(
            unresolvedTransaction,
            currentAccounts: [_account(id: 'other-account')],
          ),
          throwsA(anything),
        );

        expect(transactionRepository.transactions, [existingTransaction]);
        expect(transactionRepository.addCallCount, 0);
        expect(transactionRepository.updateCallCount, 0);
      },
    );

    test(
      'rejects edit when account id is present but cannot be resolved',
      () async {
        final unresolvedUpdate = existingTransaction.copyWith(
          accountId: 'missing-account',
        );

        await expectLater(
          saveEdit(
            unresolvedUpdate,
            currentAccounts: [_account(id: 'other-account')],
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
