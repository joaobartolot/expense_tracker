import 'package:expense_tracker/features/accounts/data/account_repository.dart';
import 'package:expense_tracker/features/accounts/domain/models/account.dart';
import 'package:expense_tracker/features/accounts/domain/services/balance_overview_service.dart';
import 'package:expense_tracker/features/transactions/domain/models/transaction_item.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

void main() {
  late BalanceOverviewService service;

  setUp(() {
    service = BalanceOverviewService(
      accountRepository: _NoopAccountRepository(),
    );
  });

  group('calculateEffectiveBalances', () {
    test(
      'returns opening balances unchanged when there are no transactions',
      () {
        final balances = service.calculateEffectiveBalances(
          accounts: [
            _account(id: 'account-wallet', openingBalance: 100),
            _account(id: 'account-savings', openingBalance: 250),
          ],
          transactions: const [],
        );

        expect(balances, {'account-wallet': 100, 'account-savings': 250});
      },
    );

    test('applies income and expense balance changes cumulatively', () {
      final balances = service.calculateEffectiveBalances(
        accounts: [_account(id: 'account-wallet', openingBalance: 100)],
        transactions: [
          _incomeTransaction(
            id: 'tx-salary',
            amount: 50,
            accountId: 'account-wallet',
          ),
          _expenseTransaction(
            id: 'tx-groceries',
            amount: 20,
            accountId: 'account-wallet',
          ),
        ],
      );

      expect(balances, {'account-wallet': 130});
    });

    test(
      'applies transfer balance changes to both source and destination accounts',
      () {
        final balances = service.calculateEffectiveBalances(
          accounts: [
            _account(id: 'account-wallet', openingBalance: 100),
            _account(id: 'account-travel', openingBalance: 10),
          ],
          transactions: [
            _transferTransaction(
              id: 'tx-transfer',
              amount: 30,
              sourceAccountId: 'account-wallet',
              destinationAccountId: 'account-travel',
              destinationAmount: 50,
            ),
          ],
        );

        expect(balances, {'account-wallet': 70, 'account-travel': 60});
      },
    );

    test(
      'includes transaction-created balances for linked accounts not in the account list',
      () {
        final balances = service.calculateEffectiveBalances(
          accounts: [_account(id: 'account-wallet', openingBalance: 100)],
          transactions: [
            _transferTransaction(
              id: 'tx-transfer',
              amount: 20,
              sourceAccountId: 'account-wallet',
              destinationAccountId: 'account-external',
              destinationAmount: 20,
            ),
          ],
        );

        expect(balances, {'account-wallet': 80, 'account-external': 20});
      },
    );
  });

  group('calculateBalanceOverview', () {
    test('sums same-currency account balances directly', () async {
      final overview = await service.calculateBalanceOverview(
        accounts: [
          _account(id: 'account-wallet', openingBalance: 100),
          _account(id: 'account-savings', openingBalance: 250),
        ],
        effectiveBalances: const {
          'account-wallet': 120,
          'account-savings': 200,
        },
        baseCurrencyCode: 'EUR',
        currentRates: const {'EUR': 1},
      );

      expect(overview.totalBalance, 320);
      expect(overview.missingAccountIds, isEmpty);
    });

    test('uses provided rates for mixed-currency balances', () async {
      final overview = await service.calculateBalanceOverview(
        accounts: [
          _account(
            id: 'account-wallet',
            openingBalance: 0,
            currencyCode: 'EUR',
          ),
          _account(id: 'account-usd', openingBalance: 0, currencyCode: 'USD'),
        ],
        effectiveBalances: const {'account-wallet': 120, 'account-usd': 50},
        baseCurrencyCode: 'EUR',
        currentRates: const {'EUR': 1, 'USD': 0.92},
      );

      expect(overview.totalBalance, 166);
      expect(overview.missingAccountIds, isEmpty);
    });

    test(
      'tracks missing-rate accounts and excludes them from total balance',
      () async {
        final overview = await service.calculateBalanceOverview(
          accounts: [
            _account(
              id: 'account-wallet',
              openingBalance: 0,
              currencyCode: 'EUR',
            ),
            _account(id: 'account-usd', openingBalance: 0, currencyCode: 'USD'),
          ],
          effectiveBalances: const {'account-wallet': 120, 'account-usd': 50},
          baseCurrencyCode: 'EUR',
          currentRates: const {'EUR': 1},
        );

        expect(overview.totalBalance, 120);
        expect(overview.missingAccountIds, {'account-usd'});
      },
    );

    test(
      'falls back to one for the base currency without an explicit rate entry',
      () async {
        final overview = await service.calculateBalanceOverview(
          accounts: [
            _account(
              id: 'account-wallet',
              openingBalance: 100,
              currencyCode: ' eur ',
            ),
          ],
          effectiveBalances: const {},
          baseCurrencyCode: 'EUR',
          currentRates: const {},
        );

        expect(overview.totalBalance, 100);
        expect(overview.missingAccountIds, isEmpty);
      },
    );

    test(
      'uses opening balance when effective balances lack an account entry',
      () async {
        final overview = await service.calculateBalanceOverview(
          accounts: [
            _account(
              id: 'account-wallet',
              openingBalance: 100,
              currencyCode: 'EUR',
            ),
            _account(
              id: 'account-usd',
              openingBalance: 10,
              currencyCode: 'USD',
            ),
          ],
          effectiveBalances: const {'account-wallet': 120},
          baseCurrencyCode: 'EUR',
          currentRates: const {'USD': 0.9},
        );

        expect(overview.totalBalance, 129);
        expect(overview.missingAccountIds, isEmpty);
      },
    );

    test('normalizes currency codes when looking up account rates', () async {
      final overview = await service.calculateBalanceOverview(
        accounts: [
          _account(
            id: 'account-usd',
            openingBalance: 10,
            currencyCode: ' usd ',
          ),
        ],
        effectiveBalances: const {'account-usd': 25},
        baseCurrencyCode: ' eur ',
        currentRates: const {'USD': 0.92},
      );

      expect(overview.totalBalance, 23);
      expect(overview.missingAccountIds, isEmpty);
    });
  });
}

class _NoopAccountRepository implements AccountRepository {
  @override
  Future<void> addAccount(Account account) async {}

  @override
  String createAccountId() => 'generated-account-id';

  @override
  Future<void> deleteAccount(String accountId) async {}

  @override
  Future<List<Account>> getAccounts() async => const [];

  @override
  ValueListenable<Box<dynamic>> listenable() => _NoopListenable();

  @override
  Future<void> reorderAccounts(List<Account> nextAccounts) async {}

  @override
  Future<void> updateAccount(Account account) async {}
}

class _NoopListenable extends ChangeNotifier
    implements ValueListenable<Box<dynamic>> {
  @override
  Box<dynamic> get value => throw UnimplementedError();
}

Account _account({
  required String id,
  required double openingBalance,
  String currencyCode = 'EUR',
}) {
  return Account(
    id: id,
    name: 'Account $id',
    type: AccountType.bank,
    openingBalance: openingBalance,
    currencyCode: currencyCode,
  );
}

TransactionItem _incomeTransaction({
  required String id,
  required double amount,
  required String accountId,
}) {
  return TransactionItem(
    id: id,
    title: 'Income $id',
    amount: amount,
    currencyCode: 'EUR',
    date: DateTime(2026, 4, 9, 12),
    type: TransactionType.income,
    accountId: accountId,
    categoryId: 'category-salary',
  );
}

TransactionItem _expenseTransaction({
  required String id,
  required double amount,
  required String accountId,
}) {
  return TransactionItem(
    id: id,
    title: 'Expense $id',
    amount: amount,
    currencyCode: 'EUR',
    date: DateTime(2026, 4, 9, 12),
    type: TransactionType.expense,
    accountId: accountId,
    categoryId: 'category-food',
  );
}

TransactionItem _transferTransaction({
  required String id,
  required double amount,
  required String sourceAccountId,
  required String destinationAccountId,
  required double destinationAmount,
}) {
  return TransactionItem(
    id: id,
    title: 'Transfer $id',
    amount: amount,
    currencyCode: 'EUR',
    date: DateTime(2026, 4, 9, 12),
    type: TransactionType.transfer,
    sourceAccountId: sourceAccountId,
    destinationAccountId: destinationAccountId,
    destinationAmount: destinationAmount,
    destinationCurrencyCode: 'EUR',
  );
}
