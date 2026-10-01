import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../core/storage/app_database.dart' hide ReactionTestResult;
import '../domain/reaction_test_result.dart';

class ReactionTestRepository {
  const ReactionTestRepository(this._database);

  final AppDatabase _database;

  Future<List<ReactionTestResult>> loadRecent({int limit = 30}) async {
    final rows =
        await (_database.select(_database.reactionTestResults)
              ..orderBy([(result) => OrderingTerm.desc(result.completedAt)])
              ..limit(limit))
            .get();
    return [
      for (final row in rows)
        ReactionTestResult.fromJson(
          Map<String, Object?>.from(jsonDecode(row.resultJson) as Map),
        ),
    ];
  }

  Future<void> save(ReactionTestResult result) async {
    await _database
        .into(_database.reactionTestResults)
        .insertOnConflictUpdate(
          ReactionTestResultsCompanion.insert(
            id: result.id,
            completedAt: result.completedAt,
            resultJson: jsonEncode(result.toJson()),
          ),
        );
  }
}
