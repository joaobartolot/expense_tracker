import 'package:expense_tracker/features/settings/domain/models/app_theme_preference.dart';

class AppSettings {
  const AppSettings({required this.displayName, required this.themePreference});

  final String displayName;
  final AppThemePreference themePreference;

  String get greeting {
    final trimmedName = displayName.trim();
    if (trimmedName.isEmpty) {
      return 'Hello';
    }

    return 'Hello, $trimmedName';
  }

  AppSettings copyWith({
    String? displayName,
    AppThemePreference? themePreference,
  }) {
    return AppSettings(
      displayName: displayName ?? this.displayName,
      themePreference: themePreference ?? this.themePreference,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'displayName': displayName,
      'themePreference': themePreference.storageValue,
    };
  }

  factory AppSettings.fromMap(Map<dynamic, dynamic>? map) {
    final normalizedMap = map ?? const <dynamic, dynamic>{};

    return AppSettings(
      displayName: (normalizedMap['displayName'] as String? ?? '').trim(),
      themePreference: appThemePreferenceFromStorage(
        normalizedMap['themePreference'] as String?,
      ),
    );
  }
}
