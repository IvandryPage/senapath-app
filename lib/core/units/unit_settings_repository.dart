import '../storage/app_database.dart';
import 'unit_system.dart';

class UnitSettingsRepository {
  const UnitSettingsRepository(this._database);

  static const _preferenceKey = 'unit_system';
  final AppDatabase _database;

  Future<UnitSystem> load() async {
    final row =
        await (_database.select(_database.appPreferences)
              ..where((preference) => preference.key.equals(_preferenceKey)))
            .getSingleOrNull();

    return UnitSystem.fromStorage(row?.value);
  }

  Future<void> save(UnitSystem unitSystem) async {
    await _database
        .into(_database.appPreferences)
        .insertOnConflictUpdate(
          AppPreferencesCompanion.insert(
            key: _preferenceKey,
            value: unitSystem.storageValue,
          ),
        );
  }
}
