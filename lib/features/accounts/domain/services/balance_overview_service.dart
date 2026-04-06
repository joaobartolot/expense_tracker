import 'package:expense_tracker/features/accounts/data/account_repository.dart';
import 'package:expense_tracker/features/accounts/domain/models/account.dart';
import 'package:expense_tracker/features/transactions/domain/models/transaction_item.dart';

class BalanceOverview {
  const BalanceOverview({
    required this.totalBalance,
    required this.missingAccountIds,
  });

  final double totalBalance;
  final Set<String> missingAccountIds;
}

class BalanceOverviewService {
  const BalanceOverviewService({required AccountRepository accountRepository})
    : _accountRepository = accountRepository;

  final AccountRepository _accountRepository;

  Future<Map<String, double>> getEffectiveBalances() async {
    final accounts = await _accountRepository.getAccounts();
    return calculateEffectiveBalances(
      accounts: accounts,
      transactions: const [],
    );
  }

  Map<String, double> calculateEffectiveBalances({
    required List<Account> accounts,
    required List<TransactionItem> transactions,
  }) {
    final balances = {
      for (final account in accounts) account.id: account.openingBalance,
    };

    for (final transaction in transactions) {
      for (final entry in transaction.balanceChanges.entries) {
        balances.update(
          entry.key,
          (value) => value + entry.value,
          ifAbsent: () => entry.value,
        );
      }
    }

    return balances;
  }

  Future<BalanceOverview> calculateBalanceOverview({
    required List<Account> accounts,
    required Map<String, double> effectiveBalances,
    required String baseCurrencyCode,
    required Map<String, double?> currentRates,
  }) async {
    var totalBalance = 0.0;
    final missingAccountIds = <String>{};

    for (final account in accounts) {
      final currentBalance =
          effectiveBalances[account.id] ?? account.openingBalance;
      final rate =
          currentRates[account.currencyCode.trim().toUpperCase()] ??
          (account.currencyCode.trim().toUpperCase() ==
                  baseCurrencyCode.trim().toUpperCase()
              ? 1
              : null);
      final convertedBalance = rate == null ? null : currentBalance * rate;

      if (convertedBalance == null) {
        missingAccountIds.add(account.id);
        continue;
      }

      totalBalance += convertedBalance;
    }

    return BalanceOverview(
      totalBalance: totalBalance,
      missingAccountIds: missingAccountIds,
    );
  }
}
