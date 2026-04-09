import 'package:expense_tracker/core/utils/currency_conversion_service.dart';
import 'package:expense_tracker/features/accounts/domain/models/account.dart';
import 'package:expense_tracker/features/categories/domain/models/category_item.dart';
import 'package:expense_tracker/features/transactions/data/transaction_repository.dart';
import 'package:expense_tracker/features/transactions/domain/models/transaction_item.dart';
import 'package:expense_tracker/features/transactions/domain/services/transaction_balance_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

void main() {
  late MockCurrencyConversionService currencyConversionService;
  late MockTransactionRepository transactionRepository;
  late TransactionBalanceService service;

  setUpAll(() {
    registerFallbackValue(_transaction());
  });

  setUp(() {
    currencyConversionService = MockCurrencyConversionService();
    transactionRepository = MockTransactionRepository();
    service = TransactionBalanceService(
      currencyConversionService: currencyConversionService,
      transactionRepository: transactionRepository,
    );

    when(
      () => transactionRepository.addTransaction(any()),
    ).thenAnswer((_) async {});
    when(
      () => transactionRepository.updateTransaction(any()),
    ).thenAnswer((_) async {});
  });

  group('saveTransaction normalization', () {
    test('normalizes create flow into the selected account currency', () async {
      final transaction = _transaction(
        amount: 1000,
        currencyCode: 'USD',
        foreignAmount: 1000,
        foreignCurrencyCode: 'USD',
        exchangeRate: 0.8,
      );

      when(
        () => currencyConversionService.tryConvertAmount(
          amount: 1000,
          fromCurrencyCode: 'USD',
          toCurrencyCode: 'EUR',
          date: transaction.date,
        ),
      ).thenAnswer((_) async => 800);

      await service.saveTransaction(
        transaction,
        isEditing: false,
        currentAccounts: [_account(currencyCode: 'EUR')],
        currentCategories: _categoriesFor(transaction.type),
      );

      final captured =
          verify(
                () => transactionRepository.addTransaction(captureAny()),
              ).captured.single
              as TransactionItem;

      expect(captured.amount, 800);
      expect(captured.currencyCode, 'EUR');
      expect(captured.foreignAmount, 1000);
      expect(captured.foreignCurrencyCode, 'USD');
      expect(captured.exchangeRate, 0.8);
      verifyNever(() => transactionRepository.updateTransaction(any()));
    });

    test('normalizes edit flow using the same account-currency rule', () async {
      final previousTransaction = _transaction(
        amount: 500,
        currencyCode: 'EUR',
      );
      final updatedTransaction = _transaction(
        amount: 1000,
        currencyCode: 'USD',
        foreignAmount: 1000,
        foreignCurrencyCode: 'USD',
        exchangeRate: 0.8,
      );

      when(
        () => currencyConversionService.tryConvertAmount(
          amount: 1000,
          fromCurrencyCode: 'USD',
          toCurrencyCode: 'EUR',
          date: updatedTransaction.date,
        ),
      ).thenAnswer((_) async => 800);

      await service.saveTransaction(
        updatedTransaction,
        isEditing: true,
        previousTransaction: previousTransaction,
        currentAccounts: [_account(currencyCode: 'EUR')],
        currentCategories: _categoriesFor(updatedTransaction.type),
      );

      final captured =
          verify(
                () => transactionRepository.updateTransaction(captureAny()),
              ).captured.single
              as TransactionItem;

      expect(captured.amount, 800);
      expect(captured.currencyCode, 'EUR');
      expect(captured.foreignAmount, 1000);
      expect(captured.foreignCurrencyCode, 'USD');
      expect(captured.exchangeRate, 0.8);
      verifyNever(() => transactionRepository.addTransaction(any()));
    });

    test(
      'persists same-currency transactions directly without foreign snapshot fields',
      () async {
        final transaction = _transaction(
          amount: 1234,
          currencyCode: 'EUR',
          foreignAmount: 1234,
          foreignCurrencyCode: 'EUR',
          exchangeRate: 1,
        );

        when(
          () => currencyConversionService.tryConvertAmount(
            amount: 1234,
            fromCurrencyCode: 'EUR',
            toCurrencyCode: 'EUR',
            date: transaction.date,
          ),
        ).thenAnswer((_) async => 1234);

        await service.saveTransaction(
          transaction,
          isEditing: false,
          currentAccounts: [_account(currencyCode: 'EUR')],
          currentCategories: _categoriesFor(transaction.type),
        );

        final captured =
            verify(
                  () => transactionRepository.addTransaction(captureAny()),
                ).captured.single
                as TransactionItem;

        expect(captured.amount, 1234);
        expect(captured.currencyCode, 'EUR');
        expect(captured.exchangeRate, isNull);
        expect(captured.foreignAmount, isNull);
        expect(captured.foreignCurrencyCode, isNull);
      },
    );

    test(
      'uses account currency rather than any global or entry currency as persisted ledger currency',
      () async {
        final transaction = _transaction(
          amount: 1000,
          currencyCode: 'USD',
          foreignAmount: 1000,
          foreignCurrencyCode: 'USD',
          exchangeRate: 0.8,
        );

        when(
          () => currencyConversionService.tryConvertAmount(
            amount: 1000,
            fromCurrencyCode: 'USD',
            toCurrencyCode: 'GBP',
            date: transaction.date,
          ),
        ).thenAnswer((_) async => 790);

        await service.saveTransaction(
          transaction,
          isEditing: false,
          currentAccounts: [_account(currencyCode: 'GBP')],
          currentCategories: _categoriesFor(transaction.type),
        );

        final captured =
            verify(
                  () => transactionRepository.addTransaction(captureAny()),
                ).captured.single
                as TransactionItem;

        expect(captured.amount, 790);
        expect(captured.currencyCode, 'GBP');
        expect(captured.currencyCode, isNot('USD'));
      },
    );

    test(
      'fails create when conversion is required and no exchange rate is available',
      () async {
        final transaction = _transaction(
          amount: 1000,
          currencyCode: 'USD',
          foreignAmount: 1000,
          foreignCurrencyCode: 'USD',
          exchangeRate: null,
        );

        when(
          () => currencyConversionService.tryConvertAmount(
            amount: 1000,
            fromCurrencyCode: 'USD',
            toCurrencyCode: 'EUR',
            date: transaction.date,
          ),
        ).thenAnswer((_) async => null);

        await expectLater(
          service.saveTransaction(
            transaction,
            isEditing: false,
            currentAccounts: [_account(currencyCode: 'EUR')],
            currentCategories: _categoriesFor(transaction.type),
          ),
          throwsStateError,
        );

        verifyNever(() => transactionRepository.addTransaction(any()));
        verifyNever(() => transactionRepository.updateTransaction(any()));
      },
    );

    test(
      'fails edit when conversion is required and no exchange rate is available',
      () async {
        final transaction = _transaction(
          amount: 1000,
          currencyCode: 'USD',
          foreignAmount: 1000,
          foreignCurrencyCode: 'USD',
          exchangeRate: null,
        );

        when(
          () => currencyConversionService.tryConvertAmount(
            amount: 1000,
            fromCurrencyCode: 'USD',
            toCurrencyCode: 'EUR',
            date: transaction.date,
          ),
        ).thenAnswer((_) async => null);

        await expectLater(
          service.saveTransaction(
            transaction,
            isEditing: true,
            previousTransaction: _transaction(
              amount: 1000,
              currencyCode: 'EUR',
            ),
            currentAccounts: [_account(currencyCode: 'EUR')],
            currentCategories: _categoriesFor(transaction.type),
          ),
          throwsStateError,
        );

        verifyNever(() => transactionRepository.addTransaction(any()));
        verifyNever(() => transactionRepository.updateTransaction(any()));
      },
    );

    test(
      'fails when the target account cannot be resolved for create',
      () async {
        final transaction = _transaction(accountId: 'missing-account');

        await expectLater(
          service.saveTransaction(
            transaction,
            isEditing: false,
            currentAccounts: [_account(id: 'other-account')],
            currentCategories: _categoriesFor(transaction.type),
          ),
          throwsStateError,
        );

        verifyNever(() => transactionRepository.addTransaction(any()));
        verifyNever(() => transactionRepository.updateTransaction(any()));
        verifyNever(
          () => currencyConversionService.tryConvertAmount(
            amount: any(named: 'amount'),
            fromCurrencyCode: any(named: 'fromCurrencyCode'),
            toCurrencyCode: any(named: 'toCurrencyCode'),
            date: any(named: 'date'),
          ),
        );
      },
    );

    test('fails when the target account cannot be resolved for edit', () async {
      final transaction = _transaction(accountId: 'missing-account');

      await expectLater(
        service.saveTransaction(
          transaction,
          isEditing: true,
          previousTransaction: _transaction(),
          currentAccounts: [_account(id: 'other-account')],
          currentCategories: _categoriesFor(transaction.type),
        ),
        throwsStateError,
      );

      verifyNever(() => transactionRepository.addTransaction(any()));
      verifyNever(() => transactionRepository.updateTransaction(any()));
    });

    test(
      'rejects incomplete foreign snapshot combinations when conversion is required',
      () async {
        final transaction = _transaction(
          amount: 1000,
          currencyCode: 'USD',
          foreignAmount: 1000,
          foreignCurrencyCode: null,
          exchangeRate: 0.8,
        );

        await expectLater(
          service.saveTransaction(
            transaction,
            isEditing: false,
            currentAccounts: [_account(currencyCode: 'EUR')],
            currentCategories: _categoriesFor(transaction.type),
          ),
          throwsA(anything),
        );

        verifyNever(() => transactionRepository.addTransaction(any()));
        verifyNever(() => transactionRepository.updateTransaction(any()));
      },
    );

    test('rejects zero normalized values after conversion', () async {
      final transaction = _transaction(
        amount: 1000,
        currencyCode: 'USD',
        foreignAmount: 1000,
        foreignCurrencyCode: 'USD',
        exchangeRate: 0.0,
      );

      when(
        () => currencyConversionService.tryConvertAmount(
          amount: 1000,
          fromCurrencyCode: 'USD',
          toCurrencyCode: 'EUR',
          date: transaction.date,
        ),
      ).thenAnswer((_) async => 0);

      await expectLater(
        service.saveTransaction(
          transaction,
          isEditing: false,
          currentAccounts: [_account(currencyCode: 'EUR')],
          currentCategories: _categoriesFor(transaction.type),
        ),
        throwsA(anything),
      );

      verifyNever(() => transactionRepository.addTransaction(any()));
    });

    test(
      'replaces same-currency data with a complete foreign snapshot during edit',
      () async {
        final previousTransaction = _transaction(
          amount: 1000,
          currencyCode: 'EUR',
        );
        final updatedTransaction = _transaction(
          amount: 1000,
          currencyCode: 'USD',
          foreignAmount: 1000,
          foreignCurrencyCode: 'USD',
          exchangeRate: 0.8,
        );

        when(
          () => currencyConversionService.tryConvertAmount(
            amount: 1000,
            fromCurrencyCode: 'USD',
            toCurrencyCode: 'EUR',
            date: updatedTransaction.date,
          ),
        ).thenAnswer((_) async => 800);

        await service.saveTransaction(
          updatedTransaction,
          isEditing: true,
          previousTransaction: previousTransaction,
          currentAccounts: [_account(currencyCode: 'EUR')],
          currentCategories: _categoriesFor(updatedTransaction.type),
        );

        final captured =
            verify(
                  () => transactionRepository.updateTransaction(captureAny()),
                ).captured.single
                as TransactionItem;

        expect(captured.amount, 800);
        expect(captured.currencyCode, 'EUR');
        expect(captured.foreignAmount, 1000);
        expect(captured.foreignCurrencyCode, 'USD');
        expect(captured.exchangeRate, 0.8);
      },
    );

    test(
      'clears stale foreign snapshot data when edit becomes same-currency',
      () async {
        final previousTransaction = _transaction(
          amount: 800,
          currencyCode: 'EUR',
          foreignAmount: 1000,
          foreignCurrencyCode: 'USD',
          exchangeRate: 0.8,
        );
        final updatedTransaction = _transaction(
          amount: 1200,
          currencyCode: 'EUR',
        );

        when(
          () => currencyConversionService.tryConvertAmount(
            amount: 1200,
            fromCurrencyCode: 'EUR',
            toCurrencyCode: 'EUR',
            date: updatedTransaction.date,
          ),
        ).thenAnswer((_) async => 1200);

        await service.saveTransaction(
          updatedTransaction,
          isEditing: true,
          previousTransaction: previousTransaction,
          currentAccounts: [_account(currencyCode: 'EUR')],
          currentCategories: _categoriesFor(updatedTransaction.type),
        );

        final captured =
            verify(
                  () => transactionRepository.updateTransaction(captureAny()),
                ).captured.single
                as TransactionItem;

        expect(captured.amount, 1200);
        expect(captured.currencyCode, 'EUR');
        expect(captured.exchangeRate, isNull);
        expect(captured.foreignAmount, isNull);
        expect(captured.foreignCurrencyCode, isNull);
      },
    );
  });
}

class MockCurrencyConversionService extends Mock
    implements CurrencyConversionService {}

class MockTransactionRepository extends Mock implements TransactionRepository {}

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
  String id = 'd59a486c-7711-4d8e-b490-c5073fd82599',
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

List<CategoryItem> _categoriesFor(TransactionType type) {
  return [
    _category(id: 'expense-category', name: 'Food', type: CategoryType.expense),
    _category(id: 'income-category', name: 'Salary', type: CategoryType.income),
    _category(
      id: 'category-1',
      name: type == TransactionType.income ? 'Salary' : 'Food',
      type: type == TransactionType.income
          ? CategoryType.income
          : CategoryType.expense,
    ),
  ];
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
    icon: Icons.category_outlined,
  );
}
