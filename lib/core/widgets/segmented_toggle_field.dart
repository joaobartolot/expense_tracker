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
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: colors.background,
            borderRadius: BorderRadius.circular(20),
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
    final theme = Theme.of(context);
    final colors = AppColors.of(context);
    final foregroundColor = isSelected ? AppColors.white : colors.textPrimary;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.brand : colors.surface,
          borderRadius: BorderRadius.circular(16),
          border: isSelected ? null : Border.all(color: colors.border),
          boxShadow: isSelected
              ? const [
                  BoxShadow(
                    color: AppColors.shadow,
                    blurRadius: 10,
                    offset: Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(item.icon, size: 16, color: foregroundColor),
              const SizedBox(width: 8),
              Text(
                item.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: foregroundColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
