import 'dart:convert';

import '../../../core/storage/app_database.dart';
import '../../account_sync/data/account_cloud_gateway.dart';
import '../domain/logistics_models.dart';

class LogisticsRepository {
  const LogisticsRepository(this._database, {this._cloud});

  static const _preferenceKey = 'logistics_data_v1';

  final AppDatabase _database;
  final AccountCloudGateway? _cloud;

  Future<LogisticsData> load() async {
    final cloud = _cloud;
    if (cloud != null && cloud.isSignedIn) {
      try {
        final remote = await cloud.pullSetting(_preferenceKey);
        if (remote is Map) {
          final data = LogisticsData.fromJson(
            Map<String, Object?>.from(remote),
          );
          await _saveLocal(data);
          return data;
        }
        final local = await _loadLocal();
        await cloud.pushSetting(_preferenceKey, local.toJson());
        return local;
      } catch (_) {
        // Fall back to local data when the cloud is unavailable.
      }
    }
    return _loadLocal();
  }

  Future<void> save(LogisticsData data) async {
    await _saveLocal(data);
    final cloud = _cloud;
    if (cloud != null && cloud.isSignedIn) {
      try {
        await cloud.pushSetting(_preferenceKey, data.toJson());
      } catch (_) {
        // Persist locally only; a later load retries the cloud copy.
      }
    }
  }

  Future<LogisticsData> _loadLocal() async {
    final row =
        await (_database.select(_database.appPreferences)
              ..where((preference) => preference.key.equals(_preferenceKey)))
            .getSingleOrNull();
    if (row == null) return const LogisticsData();

    final decoded = jsonDecode(row.value);
    if (decoded is! Map) throw const FormatException('Invalid logistics data.');
    return LogisticsData.fromJson(Map<String, Object?>.from(decoded));
  }

  Future<void> _saveLocal(LogisticsData data) async {
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
