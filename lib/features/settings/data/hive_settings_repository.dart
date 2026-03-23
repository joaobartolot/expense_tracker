import 'package:expense_tracker/core/storage/hive_storage.dart';
import 'package:expense_tracker/features/settings/data/settings_repository.dart';
import 'package:expense_tracker/features/settings/domain/models/app_settings.dart';
import 'package:expense_tracker/features/settings/domain/models/app_theme_preference.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

class HiveSettingsRepository implements SettingsRepository {
  Box<dynamic> get _box => Hive.box(HiveStorage.settingsBoxName);

  @override
  AppSettings getSettings() {
    final map = _box.get(HiveStorage.settingsKey) as Map<dynamic, dynamic>?;
    return AppSettings.fromMap(map);
  }

  @override
  ValueListenable<Box<dynamic>> listenable() {
    return _box.listenable(keys: [HiveStorage.settingsKey]);
  }

  @override
  Future<void> updateDisplayName(String name) async {
    final settings = getSettings();
    await _box.put(
      HiveStorage.settingsKey,
      settings.copyWith(displayName: name.trim()).toMap(),
    );
  }

  @override
  Future<void> updateDefaultCurrencyCode(String code) async {
    final settings = getSettings();
    await _box.put(
      HiveStorage.settingsKey,
      settings.copyWith(defaultCurrencyCode: code.trim().toUpperCase()).toMap(),
    );
  }

  @override
  Future<void> updateThemePreference(AppThemePreference preference) async {
    final settings = getSettings();
    await _box.put(
      HiveStorage.settingsKey,
      settings.copyWith(themePreference: preference).toMap(),
    );
  }
}
