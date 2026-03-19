import 'package:expense_tracker/features/categories/data/in_memory_category_repository.dart';
import 'package:expense_tracker/core/theme/app_theme.dart';
import 'package:expense_tracker/features/home/data/in_memory_transaction_repository.dart';
import 'package:expense_tracker/features/navigation/presentation/pages/app_shell.dart';
import 'package:flutter/material.dart';

class ExpenseTrackerApp extends StatelessWidget {
  const ExpenseTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Expense Tracker',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: AppShell(
        repository: InMemoryTransactionRepository(),
        categoryRepository: InMemoryCategoryRepository(),
      ),
    );
  }
}
