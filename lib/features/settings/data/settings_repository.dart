import 'package:expense_tracker/features/settings/domain/models/app_settings.dart';
import 'package:expense_tracker/features/settings/domain/models/app_theme_preference.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

abstract class SettingsRepository {
  AppSettings getSettings();
  ValueListenable<Box<dynamic>> listenable();
  Future<void> updateDisplayName(String name);
  Future<void> updateDefaultCurrencyCode(String code);
  Future<void> updateFinancialCycleDay(int day);
  Future<void> updateThemePreference(AppThemePreference preference);
}
