import 'package:expense_tracker/core/theme/app_colors.dart';
import 'package:expense_tracker/features/home/data/transaction_repository.dart';
import 'package:expense_tracker/features/home/presentation/pages/home_page.dart';
import 'package:expense_tracker/features/navigation/presentation/widgets/pill_bottom_nav_bar.dart';
import 'package:flutter/material.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.repository});

  final TransactionRepository repository;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _currentIndex = 0;

  late final List<Widget> _pages = [
    HomePage(repository: widget.repository),
    const _PlaceholderPage(label: 'Accounts'),
    const _PlaceholderPage(label: 'Categories'),
    const _PlaceholderPage(label: 'Recurring'),
    const _PlaceholderPage(label: 'Settings'),
  ];

  static const List<NavItemData> _items = [
    NavItemData(
      icon: Icons.home_outlined,
      activeIcon: Icons.home_rounded,
      label: 'Home',
    ),
    NavItemData(
      icon: Icons.account_balance_wallet_outlined,
      activeIcon: Icons.account_balance_wallet_rounded,
      label: 'Accounts',
    ),
    NavItemData(
      icon: Icons.category_outlined,
      activeIcon: Icons.category_rounded,
      label: 'Categories',
    ),
    NavItemData(
      icon: Icons.sync_outlined,
      activeIcon: Icons.sync_rounded,
      label: 'Recurring',
    ),
    NavItemData(
      icon: Icons.settings_outlined,
      activeIcon: Icons.settings_rounded,
      label: 'Settings',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: IndexedStack(index: _currentIndex, children: _pages),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: SafeArea(
          top: false,
          child: PillBottomNavBar(
            currentIndex: _currentIndex,
            items: _items,
            onTap: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
          ),
        ),
      ),
    );
  }
}

class _PlaceholderPage extends StatelessWidget {
  const _PlaceholderPage({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      child: Center(
        child: Text(
          label,
          style: theme.textTheme.headlineMedium?.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
