import 'package:expense_tracker/core/theme/app_colors.dart';
import 'package:flutter/material.dart';

class AppTheme {
  const AppTheme._();

  static ThemeData light() {
    return ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.brand,
        brightness: Brightness.light,
      ),
      scaffoldBackgroundColor: AppColors.background,
      useMaterial3: true,
    );
  }
}
