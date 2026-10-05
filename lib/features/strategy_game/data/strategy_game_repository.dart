import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../core/storage/app_database.dart' hide StrategyGameResult;
import '../domain/strategy_game_result.dart';

class StrategyGameRepository {
  const StrategyGameRepository(this._database);

  final AppDatabase _database;

  Future<List<StrategyGameResult>> loadRecent({int limit = 20}) async {
    final rows =
        await (_database.select(_database.strategyGameResults)
              ..orderBy([(result) => OrderingTerm.desc(result.playedAt)])
              ..limit(limit))
            .get();
    return [
      for (final row in rows)
        StrategyGameResult.fromJson(
          Map<String, Object?>.from(jsonDecode(row.resultJson) as Map),
        ),
    ];
  }

  Future<void> save(StrategyGameResult result) async {
    await _database
        .into(_database.strategyGameResults)
        .insertOnConflictUpdate(
          StrategyGameResultsCompanion.insert(
            id: result.id,
            playedAt: result.playedAt,
            resultJson: jsonEncode(result.toJson()),
          ),
        );
  }
}
