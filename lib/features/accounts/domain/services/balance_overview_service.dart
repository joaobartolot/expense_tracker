import 'package:expense_tracker/features/accounts/data/account_repository.dart';
import 'package:expense_tracker/features/accounts/domain/models/account.dart';

class BalanceOverviewService {
  const BalanceOverviewService({required AccountRepository accountRepository})
    : _accountRepository = accountRepository;

  final AccountRepository _accountRepository;

  Future<double> getGlobalBalance() async {
    final accounts = await _accountRepository.getAccounts();
    return calculateGlobalBalance(accounts);
  }

  Future<Map<String, double>> getEffectiveBalances() async {
    final accounts = await _accountRepository.getAccounts();
    return calculateEffectiveBalances(accounts: accounts);
  }

  Map<String, double> calculateEffectiveBalances({
    required List<Account> accounts,
  }) {
    return {for (final account in accounts) account.id: account.balance};
  }

  double calculateGlobalBalance(List<Account> accounts) {
    return _sumTrackedBalances(accounts.map((account) => account.balance));
  }

  double _sumTrackedBalances(Iterable<double> balances) {
    return balances.fold<double>(0, (sum, balance) => sum + balance);
  }
}
