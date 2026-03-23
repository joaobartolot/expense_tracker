import 'package:expense_tracker/core/theme/app_colors.dart';
import 'package:flutter/material.dart';

class SegmentedToggleItem<T> {
  const SegmentedToggleItem({
    required this.value,
    required this.label,
    required this.icon,
  });

  final T value;
  final String label;
  final IconData icon;
}

class SegmentedToggleField<T> extends StatelessWidget {
  const SegmentedToggleField({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final String label;
  final T value;
  final List<SegmentedToggleItem<T>> items;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = AppColors.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: colors.textPrimary,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: colors.background,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Row(
            children: [
              for (var index = 0; index < items.length; index++) ...[
                if (index > 0) const SizedBox(width: 8),
                Expanded(
                  child: _SegmentedToggleOption<T>(
                    item: items[index],
                    isSelected: items[index].value == value,
                    onTap: () => onChanged(items[index].value),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _SegmentedToggleOption<T> extends StatelessWidget {
  const _SegmentedToggleOption({
    required this.item,
    required this.isSelected,
    required this.onTap,
  });

  final SegmentedToggleItem<T> item;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final foregroundColor = isSelected ? AppColors.white : colors.textPrimary;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.brand : colors.surface,
          borderRadius: BorderRadius.circular(20),
          boxShadow: isSelected
              ? const [
                  BoxShadow(
                    color: AppColors.shadow,
                    blurRadius: 16,
                    offset: Offset(0, 8),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(item.icon, size: 18, color: foregroundColor),
                  const SizedBox(height: 6),
                  Text(
                    item.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: foregroundColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
