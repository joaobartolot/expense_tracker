import 'package:expense_tracker/core/theme/app_colors.dart';
import 'package:expense_tracker/features/accounts/data/account_repository.dart';
import 'package:expense_tracker/features/accounts/domain/services/balance_overview_service.dart';
import 'package:expense_tracker/features/accounts/presentation/pages/accounts_page.dart';
import 'package:expense_tracker/features/categories/data/category_repository.dart';
import 'package:expense_tracker/features/categories/presentation/pages/categories_page.dart';
import 'package:expense_tracker/features/navigation/presentation/widgets/pill_bottom_nav_bar.dart';
import 'package:expense_tracker/features/settings/data/settings_repository.dart';
import 'package:expense_tracker/features/settings/presentation/pages/settings_page.dart';
import 'package:expense_tracker/features/transactions/data/transaction_repository.dart';
import 'package:expense_tracker/features/transactions/presentation/pages/home_page.dart';
import 'package:flutter/material.dart';

class AppShell extends StatefulWidget {
  const AppShell({
    super.key,
    required this.repository,
    required this.categoryRepository,
    required this.settingsRepository,
    required this.accountRepository,
    required this.balanceOverviewService,
  });

  final TransactionRepository repository;
  final CategoryRepository categoryRepository;
  final SettingsRepository settingsRepository;
  final AccountRepository accountRepository;
  final BalanceOverviewService balanceOverviewService;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  static const double _navBarHeight = 64;
  static const double _navBarHorizontalPadding = 20;
  static const double _navBarBottomPadding = 20;

  int _currentIndex = 0;

  late final List<Widget> _pages = [
    HomePage(
      repository: widget.repository,
      categoryRepository: widget.categoryRepository,
      settingsRepository: widget.settingsRepository,
      accountRepository: widget.accountRepository,
      balanceOverviewService: widget.balanceOverviewService,
    ),
    AccountsPage(
      repository: widget.accountRepository,
      transactionRepository: widget.repository,
      settingsRepository: widget.settingsRepository,
      balanceOverviewService: widget.balanceOverviewService,
    ),
    CategoriesPage(
      repository: widget.categoryRepository,
      transactionRepository: widget.repository,
    ),
    // TODO: Replace this placeholder with the real recurring-transactions feature flow.
    const _PlaceholderPage(label: 'Recurring'),
    SettingsPage(repository: widget.settingsRepository),
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
    final colors = AppColors.of(context);

    return Scaffold(
      backgroundColor: colors.background,
      body: Stack(
        children: [
          Positioned.fill(
            child: IndexedStack(index: _currentIndex, children: _pages),
          ),
          Positioned(
            left: _navBarHorizontalPadding,
            right: _navBarHorizontalPadding,
            bottom: _navBarBottomPadding,
            child: SafeArea(
              top: false,
              child: SizedBox(
                height: _navBarHeight,
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
          ),
        ],
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
    final colors = AppColors.of(context);

    return SafeArea(
      child: Center(
        child: Text(
          label,
          style: theme.textTheme.headlineMedium?.copyWith(
            color: colors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
