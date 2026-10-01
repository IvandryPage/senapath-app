import 'dart:convert';

import '../../../core/storage/app_database.dart';
import '../domain/logistics_models.dart';

class LogisticsRepository {
  const LogisticsRepository(this._database);

  static const _preferenceKey = 'logistics_data_v1';

  final AppDatabase _database;

  Future<LogisticsData> load() async {
    final row =
        await (_database.select(_database.appPreferences)
              ..where((preference) => preference.key.equals(_preferenceKey)))
            .getSingleOrNull();
    if (row == null) return const LogisticsData();

    final decoded = jsonDecode(row.value);
    if (decoded is! Map) throw const FormatException('Invalid logistics data.');
    return LogisticsData.fromJson(Map<String, Object?>.from(decoded));
  }

  Future<void> save(LogisticsData data) async {
    await _database
        .into(_database.appPreferences)
        .insertOnConflictUpdate(
          AppPreferencesCompanion.insert(
            key: _preferenceKey,
            value: jsonEncode(data.toJson()),
          ),
        );
  }
}
