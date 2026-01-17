import 'package:expense_tracker/features/transactions/domain/models/transaction.dart';
import 'package:expense_tracker/features/transactions/presentation/pages/add_transaction.dart';
import 'package:expense_tracker/features/transactions/presentation/pages/edit_transaction.dart';
import 'package:expense_tracker/features/transactions/presentation/pages/home_page.dart';
import 'package:expense_tracker/features/transactions/presentation/pages/transaction_details.dart';
import 'package:go_router/go_router.dart';

abstract class Routes {
  static const home = '/';
  static const addTransaction = '/add-transaction';
  static const transactionDetails = '/transaction-details';
  static const editTransaction = '/edit-transaction';
}

final router = GoRouter(
  routes: [
    GoRoute(path: Routes.home, builder: (context, state) => const HomePage()),
    GoRoute(
      path: Routes.addTransaction,
      builder: (context, state) => const AddTransaction(),
    ),
    GoRoute(
      path: Routes.transactionDetails,
      builder: (context, state) {
        final transaction = state.extra as Transaction;
        return TransactionDetails(transaction: transaction);
      },
    ),
    GoRoute(
      path: Routes.editTransaction,
      builder: (context, state) {
        final transaction = state.extra as Transaction;
        return EditTransaction(transaction: transaction);
      },
    ),
  ],
);
