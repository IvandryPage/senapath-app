import '../../../core/storage/app_database.dart';

class SessionSyncSettingsRepository {
  const SessionSyncSettingsRepository(this._database);

  static const _autoSyncPreferenceKey = 'ride_session_auto_sync';

  final AppDatabase _database;

  Future<bool> loadAutoSyncEnabled() async {
    final row =
        await (_database.select(_database.appPreferences)
              ..where(
                (preference) =>
                    preference.key.equals(_autoSyncPreferenceKey),
              ))
            .getSingleOrNull();
    return row?.value == 'true';
  }

  Future<void> saveAutoSyncEnabled(bool enabled) async {
    await _database
        .into(_database.appPreferences)
        .insertOnConflictUpdate(
          AppPreferencesCompanion.insert(
            key: _autoSyncPreferenceKey,
            value: enabled.toString(),
          ),
        );
  }
}
