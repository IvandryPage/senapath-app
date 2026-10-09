import 'package:flutter_test/flutter_test.dart';
import 'package:senapath/features/routes/domain/gps_movement_bearing.dart';
import 'package:senapath/features/session/domain/ride_session.dart';

void main() {
  final now = DateTime.utc(2026, 1, 1, 12);

  TelemetryLocation location({
    required int secondsAgo,
    required double latitude,
    required double longitude,
    double accuracyMeters = 5,
  }) => TelemetryLocation(
    recordedAt: now.subtract(Duration(seconds: secondsAgo)),
    latitude: latitude,
    longitude: longitude,
    accuracyMeters: accuracyMeters,
    altitudeMeters: 0,
    speedMetersPerSecond: 5,
  );

  test('returns a GPS bearing for reliable movement', () {
    final bearing = gpsMovementBearing([
      location(secondsAgo: 4, latitude: 0, longitude: 0),
      location(secondsAgo: 2, latitude: 0, longitude: 0.0001),
    ], now: now);

    expect(bearing, closeTo(90, 0.1));
  });

  test('returns north for reliable northbound movement', () {
    final bearing = gpsMovementBearing([
      location(secondsAgo: 4, latitude: 0, longitude: 0),
      location(secondsAgo: 2, latitude: 0.0001, longitude: 0),
    ], now: now);

    expect(bearing, closeTo(0, 0.1));
  });

  test('does not infer a bearing from stationary or inaccurate GPS fixes', () {
    final stationary = gpsMovementBearing([
      location(secondsAgo: 4, latitude: 0, longitude: 0),
      location(secondsAgo: 2, latitude: 0, longitude: 0.00001),
    ], now: now);
    final inaccurate = gpsMovementBearing([
      location(secondsAgo: 4, latitude: 0, longitude: 0),
      location(
        secondsAgo: 2,
        latitude: 0,
        longitude: 0.0001,
        accuracyMeters: 30,
      ),
    ], now: now);
    final stale = gpsMovementBearing([
      location(secondsAgo: 24, latitude: 0, longitude: 0),
      location(secondsAgo: 22, latitude: 0, longitude: 0.0001),
    ], now: now);

    expect(stationary, isNull);
    expect(inaccurate, isNull);
    expect(stale, isNull);
  });
}
