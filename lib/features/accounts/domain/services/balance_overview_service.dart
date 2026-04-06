import 'package:expense_tracker/features/accounts/data/account_repository.dart';
import 'package:expense_tracker/features/accounts/domain/models/account.dart';
import 'package:expense_tracker/features/transactions/data/transaction_repository.dart';
import 'package:expense_tracker/features/transactions/domain/models/transaction_item.dart';

class BalanceOverviewService {
  const BalanceOverviewService({
    required AccountRepository accountRepository,
    required TransactionRepository transactionRepository,
  }) : _accountRepository = accountRepository,
       _transactionRepository = transactionRepository;

  final AccountRepository _accountRepository;
  final TransactionRepository _transactionRepository;

  Future<double> getGlobalBalance() async {
    final overview = await getOverview();
    return overview.globalBalance;
  }

  Future<Map<String, double>> getEffectiveBalances() async {
    final overview = await getOverview();
    return overview.effectiveBalances;
  }

  Future<({double globalBalance, Map<String, double> effectiveBalances})>
  getOverview() async {
    final results = await Future.wait<dynamic>([
      _accountRepository.getAccounts(),
      _transactionRepository.getTransactions(),
    ]);

    final accounts = results[0] as List<Account>;
    final transactions = results[1] as List<TransactionItem>;
    final balances = calculateEffectiveBalances(
      accounts: accounts,
      transactions: transactions,
    );

    return (
      globalBalance: _sumTrackedBalances(balances.values),
      effectiveBalances: balances,
    );
  }

  Map<String, double> calculateEffectiveBalances({
    required List<Account> accounts,
    required List<TransactionItem> transactions,
  }) {
    final balances = {
      for (final account in accounts) account.id: account.balance,
    };

    for (final transaction in transactions) {
      for (final entry in transaction.balanceChanges.entries) {
        final accountId = entry.key;
        if (!balances.containsKey(accountId)) {
          continue;
        }

        balances[accountId] = balances[accountId]! + entry.value;
      }
    }

    return balances;
  }

  double calculateGlobalBalanceFromBalances(Map<String, double> balances) {
    return _sumTrackedBalances(balances.values);
  }

  double _sumTrackedBalances(Iterable<double> balances) {
    return balances.fold<double>(0, (sum, balance) => sum + balance);
  }
}
