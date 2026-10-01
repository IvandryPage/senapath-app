import 'package:flutter_test/flutter_test.dart';
import 'package:senapath/features/session/data/session_file_service.dart';
import 'package:senapath/features/session/domain/ride_session.dart';

void main() {
  const service = SessionFileService();
  final session = RideSessionSnapshot(
    id: 'session-1',
    startedAt: DateTime.utc(2026, 10, 1, 8),
    endedAt: DateTime.utc(2026, 10, 1, 9),
    status: RideSessionStatus.completed,
    totalPausedMilliseconds: 0,
    distanceMeters: 1200,
    currentSpeedMetersPerSecond: 4,
  );
  final locations = [
    TelemetryLocation(
      recordedAt: DateTime.utc(2026, 10, 1, 8),
      latitude: -6.2,
      longitude: 106.8,
      accuracyMeters: 5,
      altitudeMeters: 10,
      speedMetersPerSecond: 3,
    ),
    TelemetryLocation(
      recordedAt: DateTime.utc(2026, 10, 1, 8, 1),
      latitude: -6.201,
      longitude: 106.801,
      accuracyMeters: 5,
      altitudeMeters: 12,
      speedMetersPerSecond: 4,
    ),
  ];

  test('JSON export includes a versioned session schema', () {
    final output = service.toJson(session: session, locations: locations);

    expect(output, contains('"schemaVersion": 1'));
    expect(output, contains('senapath.session'));
    expect(output, contains('session-1'));
    expect(output, contains('latitude'));
  });

  test('GPX export can be parsed back into route points', () {
    final gpx = service.toGpx(locations);
    final parsed = service.parseGpx(gpx);

    expect(parsed, hasLength(2));
    expect(parsed.first.latitude, locations.first.latitude);
    expect(parsed.last.longitude, locations.last.longitude);
  });

  test('invalid GPX is rejected with a clear format error', () {
    expect(
      () => service.parseGpx('<gpx><trk><trkseg /></trk></gpx>'),
      throwsA(isA<FormatException>()),
    );
    expect(
      () => service.parseGpx('<gpx><trkpt lat="bad" lon="106.8" /></gpx>'),
      throwsA(isA<FormatException>()),
    );
  });
}
