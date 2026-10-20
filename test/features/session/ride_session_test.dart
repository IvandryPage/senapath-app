import 'package:flutter_test/flutter_test.dart';
import 'package:senapath/features/session/domain/ride_session.dart';

void main() {
  group('RideSessionSnapshot.durationAt', () {
    final start = DateTime(2026, 1, 5, 8);

    test('uses endedAt when the session is completed', () {
      final session = RideSessionSnapshot(
        id: 's1',
        startedAt: start,
        endedAt: start.add(const Duration(minutes: 90)),
        status: RideSessionStatus.completed,
        totalPausedMilliseconds: 0,
        distanceMeters: 0,
        currentSpeedMetersPerSecond: 0,
      );
      expect(session.durationAt(start), const Duration(minutes: 90));
      expect(
        session.durationAt(start.add(const Duration(hours: 5))),
        const Duration(minutes: 90),
      );
    });

    test('uses the provided time while recording', () {
      final session = RideSessionSnapshot(
        id: 's1',
        startedAt: start,
        status: RideSessionStatus.recording,
        totalPausedMilliseconds: 0,
        distanceMeters: 0,
        currentSpeedMetersPerSecond: 0,
      );
      expect(
        session.durationAt(start.add(const Duration(minutes: 10))),
        const Duration(minutes: 10),
      );
    });

    test('subtracts recorded and in-flight pauses', () {
      final pausedAt = start.add(const Duration(minutes: 5));
      final session = RideSessionSnapshot(
        id: 's1',
        startedAt: start,
        pausedAt: pausedAt,
        status: RideSessionStatus.paused,
        totalPausedMilliseconds: const Duration(minutes: 2).inMilliseconds,
        distanceMeters: 0,
        currentSpeedMetersPerSecond: 0,
      );

      // 12 min elapsed, minus 2 min recorded pause, minus 7 min in-flight
      // pause since the last checkpoint.
      expect(
        session.durationAt(start.add(const Duration(minutes: 12))),
        const Duration(minutes: 3),
      );
    });

    test('never returns a negative duration', () {
      final session = RideSessionSnapshot(
        id: 's1',
        startedAt: start,
        status: RideSessionStatus.recording,
        totalPausedMilliseconds: const Duration(hours: 1).inMilliseconds,
        distanceMeters: 0,
        currentSpeedMetersPerSecond: 0,
      );
      expect(
        session.durationAt(start.add(const Duration(minutes: 10))),
        Duration.zero,
      );
    });
  });

  group('TelemetryLocation JSON', () {
    test('round-trips optional sensor readings', () {
      final recordedAt = DateTime.utc(2026, 1, 5, 1);
      final original = TelemetryLocation(
        recordedAt: recordedAt,
        latitude: -6.2,
        longitude: 106.8,
        accuracyMeters: 4.5,
        altitudeMeters: 12,
        altitudeAccuracyMeters: 2,
        barometricPressureHpa: 1012.3,
        accelerationMagnitudeMetersPerSecondSquared: 9.8,
        rotationRateMagnitudeRadiansPerSecond: 0.1,
        speedMetersPerSecond: 8.2,
      );

      final restored = TelemetryLocation.fromJson(
        original.toJson(),
        recordedAt: recordedAt,
      );
      expect(restored.recordedAt, recordedAt);
      expect(restored.latitude, -6.2);
      expect(restored.longitude, 106.8);
      expect(restored.accuracyMeters, 4.5);
      expect(restored.altitudeMeters, 12);
      expect(restored.altitudeAccuracyMeters, 2);
      expect(restored.barometricPressureHpa, 1012.3);
      expect(restored.accelerationMagnitudeMetersPerSecondSquared, 9.8);
      expect(restored.rotationRateMagnitudeRadiansPerSecond, 0.1);
      expect(restored.speedMetersPerSecond, 8.2);
    });

    test('tolerates missing optional fields', () {
      final restored = TelemetryLocation.fromJson(
        {'latitude': 1, 'longitude': 2, 'accuracyMeters': 3, 'altitudeMeters': 4, 'speedMetersPerSecond': 5},
        recordedAt: DateTime.utc(2026),
      );
      expect(restored.altitudeAccuracyMeters, isNull);
      expect(restored.barometricPressureHpa, isNull);
      expect(restored.accelerationMagnitudeMetersPerSecondSquared, isNull);
      expect(restored.rotationRateMagnitudeRadiansPerSecond, isNull);
    });
  });

  group('MotionSnapshot', () {
    test('reports available data and graph readiness', () {
      const empty = MotionSnapshot();
      expect(empty.hasData, isFalse);
      expect(empty.hasAccelerationGraph, isFalse);
      expect(empty.peakAcceleration, isNull);

      const single = MotionSnapshot(accelerationMagnitude: 9.8);
      expect(single.hasData, isTrue);
      expect(single.hasAccelerationGraph, isFalse);

      const graphed = MotionSnapshot(
        accelerationHistory: [1, 3, 2],
        rotationHistory: [0.2, 0.5],
        cadenceHistory: [80, 90],
      );
      expect(graphed.hasAccelerationGraph, isTrue);
      expect(graphed.hasRotationGraph, isTrue);
      expect(graphed.hasCadenceGraph, isTrue);
      expect(graphed.peakAcceleration, 3);
      expect(graphed.peakRotation, 0.5);
    });
  });

  group('RideSessionSummary', () {
    test('requires five samples before showing a speed graph', () {
      final session = RideSessionSnapshot(
        id: 's1',
        startedAt: DateTime(2026),
        status: RideSessionStatus.completed,
        totalPausedMilliseconds: 0,
        distanceMeters: 0,
        currentSpeedMetersPerSecond: 0,
      );
      RideSessionSummary summary(int sampleCount) => RideSessionSummary(
        session: session,
        sampleCount: sampleCount,
        speedSamples: [
          for (var i = 0; i < sampleCount; i++)
            RideSpeedSample(
              recordedAt: DateTime(2026, 1, 1, i),
              speedMetersPerSecond: i.toDouble(),
            ),
        ],
        elevationSource: 'gps',
      );

      expect(summary(4).hasSpeedGraph, isFalse);
      expect(summary(5).hasSpeedGraph, isTrue);

      final copy = summary(5).copyWith(session: session);
      expect(copy.sampleCount, 5);
      expect(copy.elevationSource, 'gps');
    });
  });
}
