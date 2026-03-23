import 'package:expense_tracker/core/theme/app_colors.dart';
import 'package:flutter/material.dart';

class HighlightSummaryCard extends StatefulWidget {
  const HighlightSummaryCard({
    super.key,
    required this.title,
    required this.value,
    this.subtitle,
    this.footer,
  });

  final String title;
  final String value;
  final String? subtitle;
  final Widget? footer;

  @override
  State<HighlightSummaryCard> createState() => _HighlightSummaryCardState();
}

class _HighlightSummaryCardState extends State<HighlightSummaryCard> {
  bool _isValueVisible = true;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final valueStyle = theme.textTheme.headlineMedium?.copyWith(
      color: AppColors.white,
      fontWeight: FontWeight.w700,
    );
    final valueHeight =
        (valueStyle?.fontSize ?? 29) * (valueStyle?.height ?? 1.15);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.brand,
        borderRadius: BorderRadius.circular(32),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 24,
            offset: Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  widget.title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: AppColors.whiteMuted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              IconButton(
                onPressed: () {
                  setState(() {
                    _isValueVisible = !_isValueVisible;
                  });
                },
                visualDensity: VisualDensity.compact,
                tooltip: _isValueVisible ? 'Hide amount' : 'Show amount',
                icon: Icon(
                  _isValueVisible
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: AppColors.whiteMuted,
                  size: 20,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: valueHeight,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              switchInCurve: Curves.easeOut,
              switchOutCurve: Curves.easeIn,
              layoutBuilder: (currentChild, previousChildren) {
                return currentChild ?? const SizedBox.shrink();
              },
              transitionBuilder: (child, animation) {
                return FadeTransition(opacity: animation, child: child);
              },
              child: _isValueVisible
                  ? Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        widget.value,
                        key: const ValueKey('visible-value'),
                        style: valueStyle,
                      ),
                    )
                  : const _MaskedValue(key: ValueKey('masked-value')),
            ),
          ),
          if (widget.subtitle != null) ...[
            const SizedBox(height: 12),
            Text(
              widget.subtitle!,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: AppColors.whiteMuted,
              ),
            ),
          ],
          if (widget.footer != null) ...[
            const SizedBox(height: 16),
            widget.footer!,
          ],
        ],
      ),
    );
  }
}

class _MaskedValue extends StatelessWidget {
  const _MaskedValue({super.key});

  static const int _dotCount = 8;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: List.generate(
          _dotCount,
          (index) => Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        ),
      ),
    );
  }
}
