import 'dart:async';

import 'package:expense_tracker/core/theme/app_colors.dart';
import 'package:flutter/material.dart';

class ContextActionMenuItem<T> {
  const ContextActionMenuItem({
    required this.value,
    required this.label,
    required this.icon,
    this.foregroundColor,
  });

  final T value;
  final String label;
  final IconData icon;
  final Color? foregroundColor;
}

VoidCallback? _activeMenuDismiss;

Future<T?> showContextActionMenu<T>({
  required BuildContext context,
  required Offset globalPosition,
  required List<ContextActionMenuItem<T>> items,
}) {
  _activeMenuDismiss?.call();

  final overlay = Overlay.of(context);
  final overlayBox = overlay.context.findRenderObject()! as RenderBox;
  const horizontalPadding = 12.0;
  const verticalPadding = 12.0;
  const menuWidth = 172.0;
  const rowHeight = 48.0;
  const menuOffset = 8.0;
  final menuHeight = items.length * rowHeight;

  final maxLeft = overlayBox.size.width - menuWidth - horizontalPadding;
  final maxTop = overlayBox.size.height - menuHeight - verticalPadding;

  final left = (globalPosition.dx - (menuWidth / 2))
      .clamp(
        horizontalPadding,
        maxLeft < horizontalPadding ? horizontalPadding : maxLeft,
      )
      .toDouble();

  final prefersBelow =
      globalPosition.dy + menuHeight + menuOffset <=
      overlayBox.size.height - verticalPadding;
  final rawTop = prefersBelow
      ? globalPosition.dy + menuOffset
      : globalPosition.dy - menuHeight - menuOffset;
  final top = rawTop
      .clamp(
        verticalPadding,
        maxTop < verticalPadding ? verticalPadding : maxTop,
      )
      .toDouble();

  final menuRect = Rect.fromLTWH(left, top, menuWidth, menuHeight);
  final completer = Completer<T?>();
  late final OverlayEntry entry;

  void close([T? result]) {
    if (_activeMenuDismiss == close) {
      _activeMenuDismiss = null;
    }

    if (entry.mounted) {
      entry.remove();
    }

    if (!completer.isCompleted) {
      completer.complete(result);
    }
  }

  entry = OverlayEntry(
    builder: (context) {
      return Material(
        color: Colors.transparent,
        child: Stack(
          children: [
            Positioned.fill(
              child: Listener(
                behavior: HitTestBehavior.translucent,
                onPointerDown: (event) {
                  if (!menuRect.inflate(6).contains(event.position)) {
                    close();
                  }
                },
              ),
            ),
            Positioned(
              left: left,
              top: top,
              width: menuWidth,
              child: _ContextActionMenuCard<T>(items: items, onSelected: close),
            ),
          ],
        ),
      );
    },
  );

  _activeMenuDismiss = close;
  overlay.insert(entry);
  return completer.future;
}

class _ContextActionMenuCard<T> extends StatelessWidget {
  const _ContextActionMenuCard({required this.items, required this.onSelected});

  final List<ContextActionMenuItem<T>> items;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 20,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var index = 0; index < items.length; index++)
              _ContextActionMenuOption<T>(
                item: items[index],
                isLast: index == items.length - 1,
                onTap: () => onSelected(items[index].value),
              ),
          ],
        ),
      ),
    );
  }
}

class _ContextActionMenuOption<T> extends StatelessWidget {
  const _ContextActionMenuOption({
    required this.item,
    required this.isLast,
    required this.onTap,
  });

  final ContextActionMenuItem<T> item;
  final bool isLast;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = item.foregroundColor ?? AppColors.textPrimary;

    return InkWell(
      onTap: onTap,
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          border: isLast
              ? null
              : Border(bottom: BorderSide(color: AppColors.background)),
        ),
        child: Row(
          children: [
            Icon(item.icon, size: 18, color: color),
            const SizedBox(width: 10),
            Text(item.label, style: TextStyle(color: color)),
          ],
        ),
      ),
    );
  }
}
