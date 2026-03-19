import 'package:expense_tracker/core/theme/app_colors.dart';
import 'package:flutter/material.dart';

class PillBottomNavBar extends StatelessWidget {
  const PillBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.items,
    required this.onTap,
  });

  final int currentIndex;
  final List<NavItemData> items;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(999),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 24,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          const outerPadding = 6.0;
          const indicatorHorizontalInset = 6.0;
          final itemWidth =
              (constraints.maxWidth - (outerPadding * 2)) / items.length;

          return Stack(
            children: [
              AnimatedPositioned(
                duration: const Duration(milliseconds: 320),
                curve: Curves.easeOutCubic,
                left:
                    outerPadding +
                    indicatorHorizontalInset +
                    (itemWidth * currentIndex),
                top: outerPadding,
                width: itemWidth - (indicatorHorizontalInset * 2),
                height: constraints.maxHeight - (outerPadding * 2),
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.brand.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: outerPadding,
                      ),
                      child: Row(
                        children: [
                          for (var i = 0; i < items.length; i++)
                            Expanded(
                              child: _NavBarButton(
                                data: items[i],
                                isActive: i == currentIndex,
                                onTap: () => onTap(i),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _NavBarButton extends StatelessWidget {
  const _NavBarButton({
    required this.data,
    required this.isActive,
    required this.onTap,
  });

  final NavItemData data;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: data.label,
      selected: isActive,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: SizedBox.expand(
          child: Center(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              transitionBuilder: (child, animation) {
                return FadeTransition(
                  opacity: animation,
                  child: ScaleTransition(scale: animation, child: child),
                );
              },
              child: Icon(
                isActive ? data.activeIcon : data.icon,
                key: ValueKey<IconData>(isActive ? data.activeIcon : data.icon),
                size: 24,
                color: isActive ? AppColors.brand : AppColors.iconMuted,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class NavItemData {
  const NavItemData({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
}
