import '../../../core/storage/app_database.dart';

class BiometricSignInSettingsRepository {
  /// Membuat repository pengaturan masuk biometrik.
  const BiometricSignInSettingsRepository(this._database);

  static const _preferenceKey = 'biometric_sign_in_enabled';
  final AppDatabase _database;

  /// Memuat apakah masuk dengan biometrik diaktifkan.
  Future<bool> load() async {
    final row =
        await (_database.select(_database.appPreferences)
              ..where((preference) => preference.key.equals(_preferenceKey)))
            .getSingleOrNull();
    return row?.value == 'true';
  }

  /// Menyimpan pilihan masuk dengan biometrik.
  Future<void> save(bool enabled) async {
    await _database
        .into(_database.appPreferences)
        .insertOnConflictUpdate(
          AppPreferencesCompanion.insert(
            key: _preferenceKey,
            value: enabled.toString(),
          ),
        );
  }
}
