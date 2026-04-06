import 'package:expense_tracker/core/theme/app_colors.dart';
import 'package:flutter/material.dart';

class DayOfMonthPickerField extends StatelessWidget {
  const DayOfMonthPickerField({
    super.key,
    required this.label,
    required this.dialogTitle,
    required this.dialogDescription,
    required this.value,
    required this.onChanged,
    this.valueLabel,
    this.icon = Icons.calendar_month_outlined,
    this.maxDay = 31,
  });

  final String label;
  final String dialogTitle;
  final String dialogDescription;
  final int value;
  final ValueChanged<int> onChanged;
  final String? valueLabel;
  final IconData icon;
  final int maxDay;

  Future<void> _openPicker(BuildContext context) async {
    final selectedDay = await showDialog<int>(
      context: context,
      builder: (context) => _DayOfMonthDialog(
        title: dialogTitle,
        description: dialogDescription,
        selectedDay: value,
        maxDay: maxDay,
      ),
    );

    if (selectedDay != null) {
      onChanged(selectedDay);
    }
  }

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
        Material(
          color: colors.surface,
          borderRadius: BorderRadius.circular(24),
          child: InkWell(
            onTap: () => _openPicker(context),
            borderRadius: BorderRadius.circular(24),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: colors.border, width: 1.4),
              ),
              child: Row(
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
                  Expanded(
                    child: Text(
                      valueLabel ?? 'Day $value',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: colors.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: colors.iconMuted,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _DayOfMonthDialog extends StatefulWidget {
  const _DayOfMonthDialog({
    required this.title,
    required this.description,
    required this.selectedDay,
    required this.maxDay,
  });

  final String title;
  final String description;
  final int selectedDay;
  final int maxDay;

  @override
  State<_DayOfMonthDialog> createState() => _DayOfMonthDialogState();
}

class _DayOfMonthDialogState extends State<_DayOfMonthDialog> {
  late int _pendingDay;

  @override
  void initState() {
    super.initState();
    _pendingDay = widget.selectedDay;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = AppColors.of(context);

    return Dialog(
      backgroundColor: colors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.title,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              widget.description,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.textSecondary,
              ),
            ),
            const SizedBox(height: 20),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: widget.maxDay,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
              ),
              itemBuilder: (context, index) {
                final day = index + 1;
                final isSelected = day == _pendingDay;

                return InkWell(
                  onTap: () {
                    setState(() {
                      _pendingDay = day;
                    });
                  },
                  customBorder: const CircleBorder(),
                  child: Center(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.brand
                            : Colors.transparent,
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '$day',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: isSelected
                              ? AppColors.white
                              : colors.textPrimary,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(_pendingDay),
                  child: const Text('Confirm'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
