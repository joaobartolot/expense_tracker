import 'package:flutter/material.dart';

enum AppThemePreference { system, light, dark }

extension AppThemePreferenceX on AppThemePreference {
  ThemeMode get themeMode {
    switch (this) {
      case AppThemePreference.system:
        return ThemeMode.system;
      case AppThemePreference.light:
        return ThemeMode.light;
      case AppThemePreference.dark:
        return ThemeMode.dark;
    }
  }

  String get storageValue {
    return switch (this) {
      AppThemePreference.system => 'system',
      AppThemePreference.light => 'light',
      AppThemePreference.dark => 'dark',
    };
  }

  String get label {
    return switch (this) {
      AppThemePreference.system => 'System',
      AppThemePreference.light => 'Light',
      AppThemePreference.dark => 'Dark',
    };
  }
}

AppThemePreference appThemePreferenceFromStorage(String? value) {
  return switch (value) {
    'light' => AppThemePreference.light,
    'dark' => AppThemePreference.dark,
    _ => AppThemePreference.system,
  };
}
