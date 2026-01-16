import 'package:expense_tracker/features/transactions/presentation/pages/add_transaction.dart';
import 'package:expense_tracker/features/transactions/presentation/pages/home_page.dart';
import 'package:go_router/go_router.dart';

abstract class Routes {
  static const home = '/';
  static const addTransaction = '/add-transaction';
}

final router = GoRouter(
  routes: [
    GoRoute(path: Routes.home, builder: (context, state) => const HomePage()),
    GoRoute(
      path: Routes.addTransaction,
      builder: (context, state) => const AddTransaction(),
    ),
  ],
);
