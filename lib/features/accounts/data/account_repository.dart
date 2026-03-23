import 'package:expense_tracker/features/accounts/domain/models/account.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

abstract class AccountRepository {
  Future<List<Account>> getAccounts();
  ValueListenable<Box<dynamic>> listenable();
  Future<void> addAccount(Account account);
  Future<void> updateAccount(Account account);
  Future<void> deleteAccount(String accountId);
  Future<void> reorderAccounts(List<Account> accounts);
  String createAccountId();
}
