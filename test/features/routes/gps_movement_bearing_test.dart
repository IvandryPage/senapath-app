import 'package:flutter_test/flutter_test.dart';
import 'package:senapath/features/routes/domain/gps_movement_bearing.dart';
import 'package:senapath/features/session/domain/ride_session.dart';

TelemetryLocation _location({
  required DateTime recordedAt,
  required double latitude,
  required double longitude,
  double accuracyMeters = 5,
}) => TelemetryLocation(
  recordedAt: recordedAt,
  latitude: latitude,
  longitude: longitude,
  accuracyMeters: accuracyMeters,
  altitudeMeters: 0,
  speedMetersPerSecond: 0,
);

void main() {
  final now = DateTime.utc(2026, 1, 5, 10);

  group('gpsMovementBearing', () {
    test('returns null when fewer than two recent fixes exist', () {
      expect(gpsMovementBearing(const [], now: now), isNull);
      expect(
        gpsMovementBearing(
          [_location(recordedAt: now, latitude: -6.2, longitude: 106.8)],
          now: now,
        ),
        isNull,
      );
    });

    test('returns null when fixes are too old', () {
      final locations = [
        _location(
          recordedAt: now.subtract(const Duration(minutes: 5)),
          latitude: -6.20,
          longitude: 106.80,
        ),
        _location(
          recordedAt: now.subtract(const Duration(minutes: 4)),
          latitude: -6.19,
          longitude: 106.80,
        ),
      ];
      expect(gpsMovementBearing(locations, now: now), isNull);
    });

    test('returns null for future timestamps', () {
      final locations = [
        _location(recordedAt: now.add(const Duration(seconds: 5)), latitude: -6.20, longitude: 106.80),
        _location(recordedAt: now, latitude: -6.19, longitude: 106.80),
      ];
      expect(gpsMovementBearing(locations, now: now), isNull);
    });

    test('computes a northbound bearing', () {
      final locations = [
        _location(
          recordedAt: now.subtract(const Duration(seconds: 10)),
          latitude: -6.20,
          longitude: 106.80,
        ),
        _location(recordedAt: now, latitude: -6.19, longitude: 106.80),
      ];
      final bearing = gpsMovementBearing(locations, now: now);
      expect(bearing, isNotNull);
      expect(bearing!, moreOrLessEquals(0, epsilon: 1));
    });

    test('computes an eastbound bearing', () {
      final locations = [
        _location(
          recordedAt: now.subtract(const Duration(seconds: 10)),
          latitude: -6.20,
          longitude: 106.80,
        ),
        _location(recordedAt: now, latitude: -6.20, longitude: 106.82),
      ];
      final bearing = gpsMovementBearing(locations, now: now);
      expect(bearing, isNotNull);
      expect(bearing!, moreOrLessEquals(90, epsilon: 1));
    });

    test('ignores low-accuracy fixes', () {
      final locations = [
        _location(
          recordedAt: now.subtract(const Duration(seconds: 10)),
          latitude: -6.20,
          longitude: 106.80,
          accuracyMeters: 100,
        ),
        _location(recordedAt: now, latitude: -6.19, longitude: 106.80),
      ];
      expect(gpsMovementBearing(locations, now: now), isNull);
    });

    test('returns null when the rider is standing still', () {
      final locations = [
        _location(
          recordedAt: now.subtract(const Duration(seconds: 10)),
          latitude: -6.2000,
          longitude: 106.8000,
        ),
        _location(recordedAt: now, latitude: -6.200001, longitude: 106.800001),
      ];
      expect(gpsMovementBearing(locations, now: now), isNull);
    });

    test('returns null when moving too slowly', () {
      final locations = [
        _location(
          recordedAt: now.subtract(const Duration(seconds: 10)),
          latitude: -6.20000,
          longitude: 106.80000,
        ),
        // ~10 m in 10 s = 1 m/s, below the 1.5 m/s threshold.
        _location(recordedAt: now, latitude: -6.19991, longitude: 106.80000),
      ];
      expect(gpsMovementBearing(locations, now: now), isNull);
    });

    test('skips invalid coordinates and keeps the newest valid pair', () {
      final locations = [
        _location(
          recordedAt: now.subtract(const Duration(seconds: 15)),
          latitude: -6.20,
          longitude: 106.80,
        ),
        _location(
          recordedAt: now.subtract(const Duration(seconds: 10)),
          latitude: double.infinity,
          longitude: 106.80,
        ),
        _location(recordedAt: now, latitude: -6.20, longitude: 106.82),
      ];
      final bearing = gpsMovementBearing(locations, now: now);
      expect(bearing, isNotNull);
      expect(bearing!, moreOrLessEquals(90, epsilon: 1));
    });
  });
}
