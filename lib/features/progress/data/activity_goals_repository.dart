import 'dart:convert';

import '../../../core/storage/app_database.dart';
import '../domain/activity_progress.dart';

class ActivityGoalsRepository {
  const ActivityGoalsRepository(this._database);

  static const _preferenceKey = 'activity_goals_v1';
  final AppDatabase _database;

  Future<List<ActivityGoal>> load() async {
    final row =
        await (_database.select(_database.appPreferences)
              ..where((item) => item.key.equals(_preferenceKey)))
            .getSingleOrNull();
    if (row == null) return const [];
    final decoded = jsonDecode(row.value);
    if (decoded is! List) {
      throw const FormatException('Data target aktivitas tidak valid.');
    }
    return decoded
        .map((item) {
          if (item is! Map<String, dynamic>) {
            throw const FormatException('Data target aktivitas tidak valid.');
          }
          return ActivityGoal.fromJson(item);
        })
        .toList(growable: false);
  }

  Future<void> save(List<ActivityGoal> goals) async {
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
