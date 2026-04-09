import 'dart:io';

import 'package:expense_tracker/core/storage/hive_storage.dart';
import 'package:expense_tracker/features/settings/data/hive_settings_repository.dart';
import 'package:expense_tracker/features/settings/domain/models/app_settings.dart';
import 'package:expense_tracker/features/settings/domain/models/app_theme_preference.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDirectory;
  late Box<dynamic> settingsBox;
  late HiveSettingsRepository repository;

  setUp(() async {
    tempDirectory = await Directory.systemTemp.createTemp(
      'vero-hive-settings-repository-test-',
    );
    Hive.init(tempDirectory.path);
    settingsBox = await Hive.openBox<dynamic>(HiveStorage.settingsBoxName);
    repository = HiveSettingsRepository();
  });

  tearDown(() async {
    await Hive.close();
    if (await tempDirectory.exists()) {
      await tempDirectory.delete(recursive: true);
    }
  });

  test('getSettings returns defaults when nothing is stored', () {
    final settings = repository.getSettings();

    expect(settings.displayName, '');
    expect(settings.themePreference, AppThemePreference.system);
    expect(settings.defaultCurrencyCode, 'EUR');
    expect(settings.financialCycleDay, 1);
  });

  test('updateDisplayName trims the persisted value', () async {
    await _storeSettings(
      settingsBox,
      const AppSettings(
        displayName: '',
        themePreference: AppThemePreference.system,
        defaultCurrencyCode: 'EUR',
        financialCycleDay: 1,
      ),
    );

    await repository.updateDisplayName('  Joao  ');

    expect(repository.getSettings().displayName, 'Joao');
  });

  test('updateDefaultCurrencyCode normalizes to upper-case', () async {
    await _storeSettings(
      settingsBox,
      const AppSettings(
        displayName: '',
        themePreference: AppThemePreference.system,
        defaultCurrencyCode: 'EUR',
        financialCycleDay: 1,
      ),
    );

    await repository.updateDefaultCurrencyCode(' usd ');

    expect(repository.getSettings().defaultCurrencyCode, 'USD');
  });

  test('updateFinancialCycleDay clamps the stored value', () async {
    await _storeSettings(
      settingsBox,
      const AppSettings(
        displayName: '',
        themePreference: AppThemePreference.system,
        defaultCurrencyCode: 'EUR',
        financialCycleDay: 1,
      ),
    );

    await repository.updateFinancialCycleDay(50);

    expect(repository.getSettings().financialCycleDay, 31);
  });

  test('updateThemePreference persists the selected theme', () async {
    await _storeSettings(
      settingsBox,
      const AppSettings(
        displayName: '',
        themePreference: AppThemePreference.system,
        defaultCurrencyCode: 'EUR',
        financialCycleDay: 1,
      ),
    );

    await repository.updateThemePreference(AppThemePreference.dark);

    expect(repository.getSettings().themePreference, AppThemePreference.dark);
  });

  test(
    'getSettings normalizes malformed stored values through AppSettings.fromMap',
    () async {
      await settingsBox.put(HiveStorage.settingsKey, {
        'displayName': '  Vero  ',
        'themePreference': 'unknown',
        'defaultCurrencyCode': ' usd ',
        'financialCycleDay': 99,
      });

      final settings = repository.getSettings();

      expect(settings.displayName, 'Vero');
      expect(settings.themePreference, AppThemePreference.system);
      expect(settings.defaultCurrencyCode, 'USD');
      expect(settings.financialCycleDay, 31);
    },
  );
}

Future<void> _storeSettings(Box<dynamic> box, AppSettings settings) {
  return box.put(HiveStorage.settingsKey, settings.toMap());
}
