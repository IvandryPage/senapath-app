import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:senapath/core/storage/app_database.dart';
import 'package:senapath/features/ride_prediction/data/ride_history_repository.dart';
import 'package:senapath/features/ride_prediction/domain/ride_history_entry.dart';
import 'package:senapath/features/ride_prediction/domain/ride_time_predictor.dart';
import 'package:senapath/features/session/domain/ride_session.dart';

void main() {
  test('uses the mean duration of the three nearest completed rides', () {
    final prediction = const RideTimePredictor().predict(
      distanceKm: 41,
      elevationGainMeters: 820,
      history: [
        _entry('near-1', 40, 800, 120),
        _entry('near-2', 42, 850, 130),
        _entry('near-3', 39, 780, 110),
        _entry('far', 100, 3000, 500),
      ],
    );

    expect(prediction, isNotNull);
    expect(prediction!.neighborCount, 3);
    expect(prediction.durationMinutes, closeTo(120, 0.001));
    expect(prediction.neighborSessionIds, isNot(contains('far')));
  });

  test('does not predict with fewer than three usable rides', () {
    final prediction = const RideTimePredictor().predict(
      distanceKm: 40,
      elevationGainMeters: 800,
      history: [_entry('one', 40, 800, 120), _entry('two', 42, 850, 130)],
    );

    expect(prediction, isNull);
  });

  test('persists completed ride features in local Drift history', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final repository = RideHistoryRepository(database);
    final startedAt = DateTime.utc(2026, 10, 13, 8);
    final session = RideSessionSnapshot(
      id: 'ride-1',
      startedAt: startedAt,
      endedAt: DateTime.utc(2026, 10, 13, 10),
      status: RideSessionStatus.completed,
      totalPausedMilliseconds: 20 * 60 * 1000,
      distanceMeters: 40000,
      currentSpeedMetersPerSecond: 0,
    );

    await repository.recordCompletedRide(
      RideSessionSummary(
        session: session,
        sampleCount: 10,
        speedSamples: [],
        elevationGainMeters: 800,
        elevationSource: 'Barometer',
      ),
    );

    final history = await repository.loadHistory();
    expect(history, hasLength(1));
    expect(history.single.distanceKm, 40);
    expect(history.single.elevationGainMeters, 800);
    expect(history.single.elevationPerDistance, 20);
    expect(history.single.durationMinutes, 100);
  });

  test('backfills local completed rides once', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final repository = RideHistoryRepository(database);
    final endedAt = DateTime.utc(2026, 10, 13, 10);
    final session = RideSessionSnapshot(
      id: 'older-ride',
      startedAt: DateTime.utc(2026, 10, 13, 8),
      endedAt: endedAt,
      status: RideSessionStatus.completed,
      totalPausedMilliseconds: 0,
      distanceMeters: 30000,
      currentSpeedMetersPerSecond: 0,
    );
    var summaryLoadCount = 0;

    Future<RideSessionSummary> loadSummary(String _) async {
      summaryLoadCount++;
      return RideSessionSummary(
        session: session,
        sampleCount: 10,
        speedSamples: const [],
        elevationGainMeters: 450,
        elevationSource: 'Barometer',
      );
    }

    await repository.backfillCompletedRides(
      sessions: [session],
      loadSummary: loadSummary,
    );
    await repository.backfillCompletedRides(
      sessions: [session],
      loadSummary: loadSummary,
    );

    expect(summaryLoadCount, 1);
    expect(await repository.loadHistory(), hasLength(1));
  });
}

RideHistoryEntry _entry(
  String id,
  double distanceKm,
  double elevationGainMeters,
  double durationMinutes,
) => RideHistoryEntry(
  sessionId: id,
  distanceKm: distanceKm,
  elevationGainMeters: elevationGainMeters,
  elevationPerDistance: elevationGainMeters / distanceKm,
  durationMinutes: durationMinutes,
  completedAt: DateTime.utc(2026, 10, 1),
);
