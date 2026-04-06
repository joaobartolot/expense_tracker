import 'package:expense_tracker/features/settings/domain/models/app_theme_preference.dart';

class AppSettings {
  const AppSettings({
    required this.displayName,
    required this.themePreference,
    required this.defaultCurrencyCode,
    required this.financialCycleDay,
  });

  final String displayName;
  final AppThemePreference themePreference;
  final String defaultCurrencyCode;
  final int financialCycleDay;

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
    String? defaultCurrencyCode,
    int? financialCycleDay,
  }) {
    return AppSettings(
      displayName: displayName ?? this.displayName,
      themePreference: themePreference ?? this.themePreference,
      defaultCurrencyCode: defaultCurrencyCode ?? this.defaultCurrencyCode,
      financialCycleDay: financialCycleDay ?? this.financialCycleDay,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'displayName': displayName,
      'themePreference': themePreference.storageValue,
      'defaultCurrencyCode': defaultCurrencyCode,
      'financialCycleDay': financialCycleDay,
    };
  }

  factory AppSettings.fromMap(Map<dynamic, dynamic>? map) {
    final normalizedMap = map ?? const <dynamic, dynamic>{};

    return AppSettings(
      displayName: (normalizedMap['displayName'] as String? ?? '').trim(),
      themePreference: appThemePreferenceFromStorage(
        normalizedMap['themePreference'] as String?,
      ),
      defaultCurrencyCode:
          (normalizedMap['defaultCurrencyCode'] as String? ?? 'EUR')
              .trim()
              .toUpperCase(),
      financialCycleDay:
          ((normalizedMap['financialCycleDay'] as num?)?.toInt() ?? 1).clamp(
            1,
            31,
          ),
    );
  }
}
