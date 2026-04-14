import 'package:expense_tracker/core/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart' show kTouchSlop;

class DropdownSelectorItem<T> {
  const DropdownSelectorItem({
    required this.value,
    required this.label,
    this.icon,
    this.subtitle,
  });

  final T value;
  final String label;
  final IconData? icon;
  final String? subtitle;
}

class CustomDropdownSelector<T> extends StatefulWidget {
  const CustomDropdownSelector({
    super.key,
    required this.label,
    required this.hintText,
    required this.items,
    required this.onChanged,
    this.value,
    this.errorText,
  });

  final String label;
  final String hintText;
  final List<DropdownSelectorItem<T>> items;
  final ValueChanged<T> onChanged;
  final T? value;
  final String? errorText;

  @override
  State<CustomDropdownSelector<T>> createState() =>
      _CustomDropdownSelectorState<T>();
}

class _CustomDropdownSelectorState<T> extends State<CustomDropdownSelector<T>>
    with SingleTickerProviderStateMixin {
  static const double _outsideTapSlop = kTouchSlop;

  bool _isExpanded = false;
  int? _outsidePointer;
  Offset? _outsidePointerDownPosition;

  DropdownSelectorItem<T>? get _selectedItem {
    final value = widget.value;

    if (value == null) {
      return null;
    }

    for (final item in widget.items) {
      if (item.value == value) {
        return item;
      }
    }

    return null;
  }

  void _setExpanded(bool isExpanded) {
    if (_isExpanded == isExpanded) {
      return;
    }

    setState(() {
      _isExpanded = isExpanded;
    });
  }

  void _toggleExpanded() {
    if (widget.items.isEmpty) {
      return;
    }

    _setExpanded(!_isExpanded);
  }

  void _closeExpanded() {
    _setExpanded(false);
  }

  void _handleTapOutside(PointerDownEvent event) {
    _outsidePointer = event.pointer;
    _outsidePointerDownPosition = event.position;
  }

  void _handleTapUpOutside(PointerUpEvent event) {
    if (_outsidePointer != event.pointer) {
      return;
    }

    final downPosition = _outsidePointerDownPosition;
    _outsidePointer = null;
    _outsidePointerDownPosition = null;

    if (downPosition == null) {
      return;
    }

    final dragDistance = (event.position - downPosition).distance;
    if (dragDistance <= _outsideTapSlop) {
      _closeExpanded();
    }
  }

  void _selectItem(T value) {
    widget.onChanged(value);
    _closeExpanded();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = AppColors.of(context);
    final selectedItem = _selectedItem;
    final hasError = widget.errorText != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: colors.textPrimary,
          ),
        ),
        const SizedBox(height: 10),
        TapRegion(
          onTapOutside: _handleTapOutside,
          onTapUpOutside: _handleTapUpOutside,
          child: Container(
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: hasError
                    ? Colors.red.shade400
                    : _isExpanded
                    ? AppColors.brand
                    : colors.border,
                width: 1.4,
              ),
              boxShadow: _isExpanded
                  ? const [
                      BoxShadow(
                        color: AppColors.shadow,
                        blurRadius: 20,
                        offset: Offset(0, 10),
                      ),
                    ]
                  : null,
            ),
            child: Column(
              children: [
                InkWell(
                  onTap: _toggleExpanded,
                  borderRadius: BorderRadius.circular(24),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 16,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: selectedItem == null
                              ? Text(
                                  widget.hintText,
                                  style: theme.textTheme.bodyLarge?.copyWith(
                                    color: colors.textSecondary,
                                  ),
                                )
                              : _DropdownSelectorContent(item: selectedItem),
                        ),
                        const SizedBox(width: 12),
                        AnimatedRotation(
                          turns: _isExpanded ? 0.5 : 0,
                          duration: const Duration(milliseconds: 180),
                          child: Icon(
                            Icons.keyboard_arrow_down_rounded,
                            color: widget.items.isEmpty
                                ? colors.textSecondary
                                : colors.iconMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(24),
                  ),
                  child: AnimatedCrossFade(
                    firstChild: const SizedBox.shrink(),
                    secondChild: Column(
                      children: [
                        Container(height: 1, color: colors.background),
                        for (
                          var index = 0;
                          index < widget.items.length;
                          index++
                        )
                          _DropdownSelectorOption<T>(
                            item: widget.items[index],
                            isSelected:
                                widget.items[index].value == widget.value,
                            isLast: index == widget.items.length - 1,
                            onTap: () => _selectItem(widget.items[index].value),
                          ),
                      ],
                    ),
                    crossFadeState: _isExpanded
                        ? CrossFadeState.showSecond
                        : CrossFadeState.showFirst,
                    duration: const Duration(milliseconds: 180),
                    sizeCurve: Curves.easeOutCubic,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (widget.errorText case final errorText?) ...[
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              errorText,
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.red.shade500,
                fontSize: 12,
                height: 1.2,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _DropdownSelectorContent<T> extends StatelessWidget {
  const _DropdownSelectorContent({required this.item});

  final DropdownSelectorItem<T> item;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    if (item.icon case final IconData icon) {
      return Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: colors.background,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 18, color: colors.iconMuted),
          ),
          const SizedBox(width: 12),
          Expanded(child: _DropdownSelectorText(item: item)),
        ],
      );
    }

    return _DropdownSelectorText(item: item);
  }
}

class _DropdownSelectorText<T> extends StatelessWidget {
  const _DropdownSelectorText({required this.item});

  final DropdownSelectorItem<T> item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = AppColors.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          item.label,
          style: theme.textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.w600,
            color: colors.textPrimary,
          ),
        ),
        if (item.subtitle case final String subtitle) ...[
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colors.textSecondary,
            ),
          ),
        ],
      ],
    );
  }
}

class _DropdownSelectorOption<T> extends StatelessWidget {
  const _DropdownSelectorOption({
    required this.item,
    required this.isSelected,
    required this.isLast,
    required this.onTap,
  });

  final DropdownSelectorItem<T> item;
  final bool isSelected;
  final bool isLast;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Material(
      color: isSelected
          ? AppColors.brand.withValues(alpha: 0.08)
          : colors.surface,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.fromLTRB(18, 14, 18, isLast ? 18 : 14),
          child: Row(
            children: [
              Expanded(child: _DropdownSelectorContent(item: item)),
              const SizedBox(width: 12),
              if (isSelected)
                const Icon(
                  Icons.check_rounded,
                  color: AppColors.brand,
                  size: 18,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
