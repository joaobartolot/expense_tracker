import 'package:expense_tracker/core/navigation/app_navigator_key.dart';
import 'package:flutter/material.dart';

class AppColors {
  const AppColors._();

  static const Color brand = Color(0xFF0F766E);
  static const Color secondary = Color(0xFF4F46E5);
  static const Color brandDark = Color(0xFF134E4A);
  static const Color _lightBackground = Color(0xFFF6F8F7);
  static const Color _darkBackground = Color(0xFF071210);
  static const Color _lightSurface = Colors.white;
  static const Color _darkSurface = Color(0xFF0E1B19);
  static const Color _lightSurfaceAlt = Color(0xFFEFF3F1);
  static const Color _darkSurfaceAlt = Color(0xFF13231F);
  static const Color _lightTextPrimary = Color(0xFF111827);
  static const Color _darkTextPrimary = Color(0xFFF3F7F5);
  static const Color _lightTextSecondary = Color(0xFF6B7280);
  static const Color _darkTextSecondary = Color(0xFF9FB2AE);
  static const Color _lightIconMuted = Color(0xFF374151);
  static const Color _darkIconMuted = Color(0xFFC7D5D1);
  static const Color _lightBorder = Color(0xFFD9E1DC);
  static const Color _darkBorder = Color(0xFF263B37);
  static const Color _lightIncomeSurface = Color(0xFFD1FAE5);
  static const Color _darkIncomeSurface = Color(0xFF0B3D36);
  static const Color _lightExpenseSurface = Color(0xFFE5E7EB);
  static const Color _darkExpenseSurface = Color(0xFF1B2C30);

  static const Color income = Color(0xFF047857);
  static const Color dangerSurface = Color(0xFFFEE2E2);
  static const Color danger = Color(0xFFDC2626);
  static const Color dangerDark = Color(0xFF991B1B);

  static const Color white = Colors.white;
  static const Color whiteMuted = Colors.white70;

  static const Color shadow = Color(0x22000000);

  static Brightness _brightness() {
    final context = appNavigatorKey.currentContext;
    if (context != null) {
      return Theme.of(context).brightness;
    }

    return WidgetsBinding.instance.platformDispatcher.platformBrightness;
  }

  static AppColorPalette get currentPalette {
    return paletteFor(_brightness());
  }

  static AppColorPalette of(BuildContext context) {
    return paletteFor(Theme.of(context).brightness);
  }

  static AppColorPalette paletteFor(Brightness brightness) {
    return brightness == Brightness.dark
        ? const AppColorPalette(
            background: _darkBackground,
            surface: _darkSurface,
            surfaceAlt: _darkSurfaceAlt,
            textPrimary: _darkTextPrimary,
            textSecondary: _darkTextSecondary,
            iconMuted: _darkIconMuted,
            border: _darkBorder,
            incomeSurface: _darkIncomeSurface,
            expenseSurface: _darkExpenseSurface,
          )
        : const AppColorPalette(
            background: _lightBackground,
            surface: _lightSurface,
            surfaceAlt: _lightSurfaceAlt,
            textPrimary: _lightTextPrimary,
            textSecondary: _lightTextSecondary,
            iconMuted: _lightIconMuted,
            border: _lightBorder,
            incomeSurface: _lightIncomeSurface,
            expenseSurface: _lightExpenseSurface,
          );
  }

  static Color get background => currentPalette.background;
  static Color get surface => currentPalette.surface;
  static Color get textPrimary => currentPalette.textPrimary;
  static Color get textSecondary => currentPalette.textSecondary;
  static Color get iconMuted => currentPalette.iconMuted;
  static Color get border => currentPalette.border;
  static Color get incomeSurface => currentPalette.incomeSurface;
  static Color get expenseSurface => currentPalette.expenseSurface;
}

class AppColorPalette {
  const AppColorPalette({
    required this.background,
    required this.surface,
    required this.surfaceAlt,
    required this.textPrimary,
    required this.textSecondary,
    required this.iconMuted,
    required this.border,
    required this.incomeSurface,
    required this.expenseSurface,
  });

  final Color background;
  final Color surface;
  final Color surfaceAlt;
  final Color textPrimary;
  final Color textSecondary;
  final Color iconMuted;
  final Color border;
  final Color incomeSurface;
  final Color expenseSurface;
}
