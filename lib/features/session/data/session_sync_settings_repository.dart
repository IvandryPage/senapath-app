import '../../../core/storage/app_database.dart';

class SessionSyncSettingsRepository {
  /// Membuat repositori pengaturan sinkronisasi.
  const SessionSyncSettingsRepository(this._database);

  static const _autoSyncPreferenceKey = 'ride_session_auto_sync';

  final AppDatabase _database;

  /// Memuat pengaturan sinkronisasi otomatis.
  Future<bool> loadAutoSyncEnabled() async {
    final row =
        await (_database.select(_database.appPreferences)..where(
              (preference) => preference.key.equals(_autoSyncPreferenceKey),
            ))
            .getSingleOrNull();
    return row?.value == 'true';
  }

  /// Menyimpan pengaturan sinkronisasi otomatis.
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
