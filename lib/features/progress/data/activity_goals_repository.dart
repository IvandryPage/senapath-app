import 'dart:convert';

import '../../../core/storage/app_database.dart';
import '../../account_sync/data/account_cloud_gateway.dart';
import '../domain/activity_progress.dart';

class ActivityGoalsRepository {
  const ActivityGoalsRepository(this._database, {this._cloud});

  static const _preferenceKey = 'activity_goals_v1';
  final AppDatabase _database;
  final AccountCloudGateway? _cloud;

  Future<List<ActivityGoal>> load() async {
    final cloud = _cloud;
    if (cloud != null && cloud.isSignedIn) {
      try {
        final remote = await cloud.pullSetting(_preferenceKey);
        if (remote != null) {
          final goals = _decode(remote);
          await _saveLocal(goals);
          return goals;
        }
        final local = await _loadLocal();
        if (local.isNotEmpty) {
          await cloud.pushSetting(
            _preferenceKey,
            local.map((goal) => goal.toJson()).toList(),
          );
        }
        return local;
      } catch (_) {
        // Fall back to local goals when the cloud is unavailable.
      }
    }
    return _loadLocal();
  }

  Future<void> save(List<ActivityGoal> goals) async {
    await _saveLocal(goals);
    final cloud = _cloud;
    if (cloud != null && cloud.isSignedIn) {
      try {
        await cloud.pushSetting(
          _preferenceKey,
          goals.map((goal) => goal.toJson()).toList(),
        );
      } catch (_) {
        // Persist locally only; a later load retries the cloud copy.
      }
    }
  }

  Future<List<ActivityGoal>> _loadLocal() async {
    final row = await (_database.select(
      _database.appPreferences,
    )..where((item) => item.key.equals(_preferenceKey))).getSingleOrNull();
    if (row == null) return const [];
    return _decode(jsonDecode(row.value));
  }

  List<ActivityGoal> _decode(Object? decoded) {
    if (decoded is! List) {
      throw const FormatException('Data target aktivitas tidak valid.');
    }
    return decoded
        .map((item) {
          if (item is! Map) {
            throw const FormatException('Data target aktivitas tidak valid.');
          }
          return ActivityGoal.fromJson(Map<String, dynamic>.from(item));
        })
        .toList(growable: false);
  }

  Future<void> _saveLocal(List<ActivityGoal> goals) async {
    await _database
        .into(_database.appPreferences)
        .insertOnConflictUpdate(
          AppPreferencesCompanion.insert(
            key: _preferenceKey,
            value: jsonEncode(goals.map((goal) => goal.toJson()).toList()),
          ),
        );
  }
}
