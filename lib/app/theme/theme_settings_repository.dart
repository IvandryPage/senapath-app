import 'package:flutter/material.dart';

import '../../core/storage/app_database.dart';

class ThemeSettingsRepository {
  const ThemeSettingsRepository(this._database);

  static const _preferenceKey = 'theme_mode';
  final AppDatabase _database;

  Future<ThemeMode> load() async {
    final row =
        await (_database.select(_database.appPreferences)
              ..where((preference) => preference.key.equals(_preferenceKey)))
            .getSingleOrNull();

    return switch (row?.value) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }

  Future<void> save(ThemeMode mode) async {
    await _database
        .into(_database.appPreferences)
        .insertOnConflictUpdate(
          AppPreferencesCompanion.insert(
            key: _preferenceKey,
            value: switch (mode) {
              ThemeMode.light => 'light',
              ThemeMode.dark => 'dark',
              ThemeMode.system => 'system',
            },
          ),
        );
  }
}
