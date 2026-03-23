import 'dart:math' as math;

import 'package:expense_tracker/core/theme/app_colors.dart';
import 'package:flutter/material.dart';

class CategoryIconPicker extends StatelessWidget {
  const CategoryIconPicker({
    super.key,
    required this.selectedIcon,
    required this.onIconSelected,
    this.accentColor = AppColors.brand,
    this.backgroundColor,
  });

  final IconData selectedIcon;
  final ValueChanged<IconData> onIconSelected;
  final Color accentColor;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: 92,
          height: 92,
          child: Material(
            color: backgroundColor ?? AppColors.surface,
            shape: const CircleBorder(),
            child: InkWell(
              onTap: () async {
                final icon = await showCategoryIconPickerDialog(
                  context,
                  selectedIcon: selectedIcon,
                  accentColor: accentColor,
                );

                if (icon != null) {
                  onIconSelected(icon);
                }
              },
              customBorder: const CircleBorder(),
              child: DecoratedBox(
                decoration: BoxDecoration(shape: BoxShape.circle),
                child: Icon(selectedIcon, size: 34, color: accentColor),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

Future<IconData?> showCategoryIconPickerDialog(
  BuildContext context, {
  required IconData selectedIcon,
  required Color accentColor,
}) {
  return showDialog<IconData>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.35),
    builder: (context) => MediaQuery.removeViewInsets(
      removeLeft: true,
      removeTop: true,
      removeRight: true,
      removeBottom: true,
      context: context,
      child: _CategoryIconPickerDialog(
        selectedIcon: selectedIcon,
        accentColor: accentColor,
      ),
    ),
  );
}

class _CategoryIconPickerDialog extends StatefulWidget {
  const _CategoryIconPickerDialog({
    required this.selectedIcon,
    required this.accentColor,
  });

  final IconData selectedIcon;
  final Color accentColor;

  @override
  State<_CategoryIconPickerDialog> createState() =>
      _CategoryIconPickerDialogState();
}

class _CategoryIconPickerDialogState extends State<_CategoryIconPickerDialog> {
  static const int _iconsPerPage = 12;

  late final TextEditingController _searchController;
  late final PageController _pageController;

  String _query = '';

  List<_CategoryIconEntry> get _filteredIcons {
    final normalizedQuery = _query.trim().toLowerCase();
    if (normalizedQuery.isEmpty) {
      return _iconLibrary;
    }

    return _iconLibrary
        .where((entry) => entry.matches(normalizedQuery))
        .toList();
  }

  int get _pageCount =>
      math.max(1, (_filteredIcons.length / _iconsPerPage).ceil());

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final filteredIcons = _filteredIcons;
    final pages = List.generate(_pageCount, (pageIndex) {
      final start = pageIndex * _iconsPerPage;
      final end = math.min(start + _iconsPerPage, filteredIcons.length);
      return filteredIcons.sublist(start, end);
    });

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: double.infinity,
            constraints: const BoxConstraints(maxWidth: 420),
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(32),
              boxShadow: const [
                BoxShadow(
                  color: AppColors.shadow,
                  blurRadius: 28,
                  offset: Offset(0, 16),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Choose an icon',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    InkWell(
                      onTap: () => Navigator.of(context).pop(),
                      borderRadius: BorderRadius.circular(18),
                      child: Ink(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: const Icon(Icons.close_rounded, size: 20),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                TextField(
                  controller: _searchController,
                  onChanged: (value) {
                    _pageController.jumpToPage(0);
                    setState(() {
                      _query = value;
                    });
                  },
                  decoration: InputDecoration(
                    hintText: 'Search icons',
                    prefixIcon: const Icon(Icons.search_rounded),
                    filled: true,
                    fillColor: AppColors.surface,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 16,
                    ),
                    enabledBorder: _border(AppColors.border),
                    focusedBorder: _border(widget.accentColor, width: 1.4),
                  ),
                ),
                const SizedBox(height: 18),
                if (filteredIcons.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      vertical: 32,
                      horizontal: 20,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.search_off_rounded,
                          size: 30,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'No icons match your search.',
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  )
                else ...[
                  SizedBox(
                    height: 288,
                    child: PageView.builder(
                      controller: _pageController,
                      itemCount: pages.length,
                      padEnds: false,
                      itemBuilder: (context, index) {
                        return Padding(
                          padding: EdgeInsets.only(
                            right: index == pages.length - 1 ? 0 : 12,
                          ),
                          child: _IconGridPage(
                            icons: pages[index],
                            selectedIcon: widget.selectedIcon,
                            accentColor: widget.accentColor,
                          ),
                        );
                      },
                    ),
                  ),
                  if (pages.length > 1) ...[
                    const SizedBox(height: 14),
                    _PageDots(
                      controller: _pageController,
                      pageCount: pages.length,
                      activeColor: widget.accentColor,
                    ),
                  ],
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  OutlineInputBorder _border(Color color, {double width = 1}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(22),
      borderSide: BorderSide(color: color, width: width),
    );
  }
}

class _IconGridPage extends StatelessWidget {
  const _IconGridPage({
    required this.icons,
    required this.selectedIcon,
    required this.accentColor,
  });

  final List<_CategoryIconEntry> icons;
  final IconData selectedIcon;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.border),
      ),
      child: GridView.builder(
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
        ),
        itemCount: icons.length,
        itemBuilder: (context, index) {
          final entry = icons[index];
          final isSelected = entry.icon == selectedIcon;

          return InkWell(
            onTap: () => Navigator.of(context).pop(entry.icon),
            borderRadius: BorderRadius.circular(22),
            child: Ink(
              decoration: BoxDecoration(
                color: isSelected
                    ? accentColor.withValues(alpha: 0.12)
                    : AppColors.background,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: isSelected ? accentColor : AppColors.border,
                  width: isSelected ? 1.4 : 1,
                ),
              ),
              child: Icon(
                entry.icon,
                color: isSelected ? accentColor : AppColors.iconMuted,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _PageDots extends StatefulWidget {
  const _PageDots({
    required this.controller,
    required this.pageCount,
    required this.activeColor,
  });

  final PageController controller;
  final int pageCount;
  final Color activeColor;

  @override
  State<_PageDots> createState() => _PageDotsState();
}

class _PageDotsState extends State<_PageDots> {
  double _page = 0;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_handlePageChange);
  }

  @override
  void didUpdateWidget(covariant _PageDots oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_handlePageChange);
      widget.controller.addListener(_handlePageChange);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handlePageChange);
    super.dispose();
  }

  void _handlePageChange() {
    if (!mounted) {
      return;
    }

    setState(() {
      _page = widget.controller.hasClients ? (widget.controller.page ?? 0) : 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(widget.pageCount, (index) {
        final isActive = (_page - index).abs() < 0.5;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: isActive ? 18 : 8,
          height: 8,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: isActive
                ? widget.activeColor
                : AppColors.border.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(999),
          ),
        );
      }),
    );
  }
}

class _CategoryIconEntry {
  const _CategoryIconEntry(this.icon, this.label, [this.keywords = const []]);

  final IconData icon;
  final String label;
  final List<String> keywords;

  bool matches(String query) {
    final haystack = [
      label.toLowerCase(),
      ...keywords.map((keyword) => keyword.toLowerCase()),
    ].join(' ');

    return haystack.contains(query);
  }
}

const List<_CategoryIconEntry> _iconLibrary = [
  _CategoryIconEntry(Icons.shopping_basket_outlined, 'Groceries', [
    'food',
    'market',
  ]),
  _CategoryIconEntry(Icons.restaurant_outlined, 'Dining', [
    'restaurant',
    'coffee',
  ]),
  _CategoryIconEntry(Icons.local_cafe_outlined, 'Cafe', ['coffee', 'drink']),
  _CategoryIconEntry(Icons.fastfood_outlined, 'Fast Food', ['food', 'burger']),
  _CategoryIconEntry(Icons.local_grocery_store_outlined, 'Store', [
    'shop',
    'market',
  ]),
  _CategoryIconEntry(Icons.directions_car_outlined, 'Transport', [
    'car',
    'fuel',
  ]),
  _CategoryIconEntry(Icons.directions_bus_outlined, 'Bus', [
    'transport',
    'travel',
  ]),
  _CategoryIconEntry(Icons.train_outlined, 'Train', ['transport', 'travel']),
  _CategoryIconEntry(Icons.local_taxi_outlined, 'Taxi', ['transport', 'ride']),
  _CategoryIconEntry(Icons.flight_outlined, 'Travel', ['plane', 'trip']),
  _CategoryIconEntry(Icons.home_outlined, 'Home', ['house', 'rent']),
  _CategoryIconEntry(Icons.flash_on_outlined, 'Utilities', ['power', 'bills']),
  _CategoryIconEntry(Icons.wifi_rounded, 'Internet', ['wifi', 'bills']),
  _CategoryIconEntry(Icons.phone_iphone_rounded, 'Phone', ['mobile', 'device']),
  _CategoryIconEntry(Icons.favorite_border, 'Health', ['medical', 'pharmacy']),
  _CategoryIconEntry(Icons.fitness_center_outlined, 'Fitness', [
    'gym',
    'health',
  ]),
  _CategoryIconEntry(Icons.school_outlined, 'Education', ['study', 'learning']),
  _CategoryIconEntry(Icons.book_outlined, 'Books', ['study', 'reading']),
  _CategoryIconEntry(Icons.movie_outlined, 'Movies', [
    'cinema',
    'entertainment',
  ]),
  _CategoryIconEntry(Icons.music_note_outlined, 'Music', [
    'audio',
    'entertainment',
  ]),
  _CategoryIconEntry(Icons.sports_esports_outlined, 'Gaming', ['games', 'fun']),
  _CategoryIconEntry(Icons.shopping_bag_outlined, 'Shopping', [
    'clothes',
    'retail',
  ]),
  _CategoryIconEntry(Icons.checkroom_outlined, 'Clothing', [
    'fashion',
    'apparel',
  ]),
  _CategoryIconEntry(Icons.pets_outlined, 'Pets', ['animal', 'vet']),
  _CategoryIconEntry(Icons.child_care_outlined, 'Kids', ['family', 'children']),
  _CategoryIconEntry(Icons.card_giftcard_outlined, 'Gifts', [
    'present',
    'holiday',
  ]),
  _CategoryIconEntry(Icons.workspace_premium_outlined, 'Bonus', [
    'reward',
    'income',
  ]),
  _CategoryIconEntry(Icons.payments_outlined, 'Salary', ['income', 'paycheck']),
  _CategoryIconEntry(Icons.work_outline_rounded, 'Work', ['job', 'income']),
  _CategoryIconEntry(Icons.laptop_mac_outlined, 'Freelance', [
    'side job',
    'work',
  ]),
  _CategoryIconEntry(Icons.trending_up_outlined, 'Investments', [
    'stocks',
    'income',
  ]),
  _CategoryIconEntry(Icons.savings_outlined, 'Savings', ['money', 'bank']),
  _CategoryIconEntry(Icons.account_balance_wallet_outlined, 'Wallet', [
    'money',
    'cash',
  ]),
  _CategoryIconEntry(Icons.attach_money_rounded, 'Cash', ['money', 'income']),
  _CategoryIconEntry(Icons.credit_card_outlined, 'Card', ['payment', 'bank']),
  _CategoryIconEntry(Icons.account_balance_outlined, 'Bank', [
    'money',
    'account',
  ]),
  _CategoryIconEntry(Icons.receipt_long_outlined, 'Bills', [
    'invoice',
    'payment',
  ]),
  _CategoryIconEntry(Icons.sell_outlined, 'General', ['tag', 'category']),
  _CategoryIconEntry(Icons.build_outlined, 'Maintenance', ['repair', 'tools']),
  _CategoryIconEntry(Icons.cleaning_services_outlined, 'Cleaning', [
    'home',
    'chores',
  ]),
  _CategoryIconEntry(Icons.park_outlined, 'Outdoors', ['nature', 'park']),
  _CategoryIconEntry(Icons.beach_access_outlined, 'Vacation', [
    'travel',
    'holiday',
  ]),
  _CategoryIconEntry(Icons.volunteer_activism_outlined, 'Charity', [
    'donation',
    'give',
  ]),
  _CategoryIconEntry(Icons.security_outlined, 'Insurance', [
    'coverage',
    'policy',
  ]),
  _CategoryIconEntry(Icons.medication_outlined, 'Medicine', [
    'health',
    'pharmacy',
  ]),
  _CategoryIconEntry(Icons.design_services_outlined, 'Design', [
    'creative',
    'work',
  ]),
  _CategoryIconEntry(Icons.palette_outlined, 'Creative', ['art', 'design']),
  _CategoryIconEntry(Icons.cake_outlined, 'Celebration', ['party', 'event']),
];
