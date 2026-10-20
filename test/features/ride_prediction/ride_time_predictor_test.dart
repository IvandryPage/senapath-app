import 'package:flutter_test/flutter_test.dart';
import 'package:senapath/features/ride_prediction/domain/ride_history_entry.dart';
import 'package:senapath/features/ride_prediction/domain/ride_time_predictor.dart';

RideHistoryEntry _entry({
  required String sessionId,
  required double distanceKm,
  required double elevationGainMeters,
  required double durationMinutes,
  DateTime? completedAt,
}) => RideHistoryEntry(
  sessionId: sessionId,
  distanceKm: distanceKm,
  elevationGainMeters: elevationGainMeters,
  elevationPerDistance: elevationGainMeters / distanceKm,
  durationMinutes: durationMinutes,
  completedAt: completedAt ?? DateTime.utc(2026, 1, 1),
);

void main() {
  group('RideHistoryEntry.hasValidFeatures', () {
    test('accepts positive distances and durations', () {
      expect(
        _entry(
          sessionId: 'a',
          distanceKm: 30,
          elevationGainMeters: 300,
          durationMinutes: 75,
        ).hasValidFeatures,
        isTrue,
      );
    });

    test('rejects non-positive or non-finite features', () {
      expect(
        _entry(
          sessionId: 'a',
          distanceKm: 0,
          elevationGainMeters: 100,
          durationMinutes: 60,
        ).hasValidFeatures,
        isFalse,
      );
      expect(
        _entry(
          sessionId: 'a',
          distanceKm: double.nan,
          elevationGainMeters: 100,
          durationMinutes: 60,
        ).hasValidFeatures,
        isFalse,
      );
      expect(
        _entry(
          sessionId: 'a',
          distanceKm: 30,
          elevationGainMeters: -1,
          durationMinutes: 60,
        ).hasValidFeatures,
        isFalse,
      );
      expect(
        _entry(
          sessionId: 'a',
          distanceKm: 30,
          elevationGainMeters: 100,
          durationMinutes: 0,
        ).hasValidFeatures,
        isFalse,
      );
    });
  });

  group('RideTimePredictor.predict', () {
    final predictor = const RideTimePredictor();

    test('returns null for invalid route inputs', () {
      final history = [
        _entry(
          sessionId: 'a',
          distanceKm: 30,
          elevationGainMeters: 300,
          durationMinutes: 75,
        ),
      ];
      expect(
        predictor.predict(
          distanceKm: 0,
          elevationGainMeters: 0,
          history: history,
        ),
        isNull,
      );
      expect(
        predictor.predict(
          distanceKm: double.nan,
          elevationGainMeters: 0,
          history: history,
        ),
        isNull,
      );
      expect(
        predictor.predict(
          distanceKm: 30,
          elevationGainMeters: -10,
          history: history,
        ),
        isNull,
      );
      expect(
        const RideTimePredictor(neighborCount: 0).predict(
          distanceKm: 30,
          elevationGainMeters: 0,
          history: history,
        ),
        isNull,
      );
    });

    test('returns null without enough valid history', () {
      expect(
        predictor.predict(
          distanceKm: 30,
          elevationGainMeters: 300,
          history: const [],
        ),
        isNull,
      );
      final invalid = [
        _entry(
          sessionId: 'a',
          distanceKm: 0,
          elevationGainMeters: 0,
          durationMinutes: 60,
        ),
      ];
      expect(
        predictor.predict(
          distanceKm: 30,
          elevationGainMeters: 300,
          history: invalid,
        ),
        isNull,
      );
    });

    test('averages the nearest rides', () {
      final history = [
        _entry(
          sessionId: 'near-1',
          distanceKm: 30,
          elevationGainMeters: 300,
          durationMinutes: 70,
        ),
        _entry(
          sessionId: 'near-2',
          distanceKm: 31,
          elevationGainMeters: 310,
          durationMinutes: 80,
        ),
        _entry(
          sessionId: 'near-3',
          distanceKm: 29,
          elevationGainMeters: 290,
          durationMinutes: 90,
        ),
        _entry(
          sessionId: 'far',
          distanceKm: 120,
          elevationGainMeters: 1500,
          durationMinutes: 300,
        ),
      ];

      final prediction = predictor.predict(
        distanceKm: 30,
        elevationGainMeters: 300,
        history: history,
      )!;

      expect(prediction.neighborCount, 3);
      expect(prediction.durationMinutes, moreOrLessEquals(80));
      expect(
        prediction.neighborSessionIds,
        containsAll(['near-1', 'near-2', 'near-3']),
      );
      expect(prediction.neighborSessionIds, isNot(contains('far')));
    });

    test('honours a custom neighbour count', () {
      final history = [
        for (var index = 0; index < 6; index++)
          _entry(
            sessionId: 's$index',
            distanceKm: 30 + index.toDouble(),
            elevationGainMeters: 300,
            durationMinutes: 60 + index * 10.0,
            completedAt: DateTime.utc(2026, 1, 1 + index),
          ),
      ];

      final prediction = const RideTimePredictor(neighborCount: 2).predict(
        distanceKm: 30,
        elevationGainMeters: 300,
        history: history,
      )!;

      expect(prediction.neighborCount, 2);
      expect(prediction.neighborSessionIds, ['s0', 's1']);
      expect(prediction.durationMinutes, moreOrLessEquals(65));
    });

    test('breaks feature-space ties by completion time', () {
      final history = [
        _entry(
          sessionId: 'older',
          distanceKm: 30,
          elevationGainMeters: 300,
          durationMinutes: 60,
          completedAt: DateTime.utc(2026, 1, 1),
        ),
        _entry(
          sessionId: 'newer',
          distanceKm: 30,
          elevationGainMeters: 300,
          durationMinutes: 80,
          completedAt: DateTime.utc(2026, 2, 1),
        ),
      ];

      final prediction = const RideTimePredictor(neighborCount: 1).predict(
        distanceKm: 30,
        elevationGainMeters: 300,
        history: history,
      )!;

      expect(prediction.neighborSessionIds, ['older']);
      expect(prediction.durationMinutes, 60);
    });
  });
}
