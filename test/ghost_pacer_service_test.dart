import 'package:flutter_test/flutter_test.dart';
import 'package:senapath/features/routes/data/ghost_pacer_service.dart';
import 'package:senapath/features/routes/domain/ghost_pacer.dart';
import 'package:senapath/features/routes/domain/saved_route.dart';
import 'package:senapath/features/session/domain/ride_session.dart';

void main() {
  final route = _route();

  test(
    'matches completed telemetry to the same route and builds a pace',
    () async {
      final duration = const Duration(minutes: 60);
      final history = _FakeGhostPacerHistory(
        sessions: [_session('best', duration)],
        telemetry: {'best': _locations(route, duration)},
      );
      final performance = await GhostPacerService(history: history)
          .loadBestForRoute(route);

      expect(performance, isNotNull);
      expect(performance!.sessionId, 'best');
      expect(performance.duration, duration);
      expect(
        performance.distanceAt(const Duration(minutes: 30)),
        closeTo(333, 25),
      );
    },
  );

  test(
    'does not use a ride whose recorded track is on a different route',
    () async {
      final shiftedRoute = RouteRecord(
        id: 'elsewhere',
        name: 'Rute lain',
        source: 'GPX lokal',
        updatedAt: DateTime.utc(2026),
        availability: 'offline',
        points: const [
          RoutePoint(latitude: -6.21, longitude: 106.8, elevationMeters: 0),
          RoutePoint(latitude: -6.21, longitude: 106.81, elevationMeters: 0),
        ],
      );
      final history = _FakeGhostPacerHistory(
        sessions: [_session('elsewhere', const Duration(minutes: 30))],
        telemetry: {
          'elsewhere': _locations(shiftedRoute, const Duration(minutes: 30)),
        },
      );

      expect(
        await GhostPacerService(history: history).loadBestForRoute(route),
        isNull,
      );
    },
  );

  test('selects the fastest matching completed session', () async {
    final slowerDuration = const Duration(minutes: 60);
    final fasterDuration = const Duration(minutes: 45);
    final history = _FakeGhostPacerHistory(
      sessions: [
        _session('slower', slowerDuration),
        _session('faster', fasterDuration),
      ],
      telemetry: {
        'slower': _locations(route, slowerDuration),
        'faster': _locations(route, fasterDuration),
      },
    );

    final performance = await GhostPacerService(history: history)
        .loadBestForRoute(route);

    expect(performance?.sessionId, 'faster');
    expect(performance?.duration, fasterDuration);
  });

  test('interpolates one map marker and route heading at ghost distance', () {
    final marker = ghostPacerMapPositionAt(route.points, 250);

    expect(marker, isNotNull);
    expect(marker!.point.longitude, greaterThan(route.points.first.longitude));
    expect(marker.point.longitude, lessThan(route.points.last.longitude));
    expect(marker.headingDegrees, closeTo(90, 1));
    expect(ghostPacerMapPositionAt(const [], 0), isNull);
  });
}

RouteRecord _route() => RouteRecord(
  id: 'loop',
  name: 'Loop',
  source: 'GPX lokal',
  updatedAt: DateTime.utc(2026),
  availability: 'offline',
  points: const [
    RoutePoint(latitude: -6.2, longitude: 106.8, elevationMeters: 0),
    RoutePoint(latitude: -6.2, longitude: 106.806, elevationMeters: 0),
  ],
);

RideSessionSnapshot _session(String id, Duration duration) {
  final startedAt = DateTime.utc(2026, 1, 1);
  return RideSessionSnapshot(
    id: id,
    startedAt: startedAt,
    endedAt: startedAt.add(duration),
    status: RideSessionStatus.completed,
    totalPausedMilliseconds: 0,
    distanceMeters: 650,
    currentSpeedMetersPerSecond: 0,
  );
}

List<TelemetryLocation> _locations(RouteRecord route, Duration wallDuration) {
  final start = DateTime.utc(2026, 1, 1);
  return List.generate(11, (index) {
    final progress = index / 10;
    final first = route.points.first;
    final last = route.points.last;
    return TelemetryLocation(
      recordedAt: start.add(
        Duration(microseconds: wallDuration.inMicroseconds * index ~/ 10),
      ),
      latitude: first.latitude + (last.latitude - first.latitude) * progress,
      longitude:
          first.longitude + (last.longitude - first.longitude) * progress,
      accuracyMeters: 5,
      altitudeMeters: 0,
      speedMetersPerSecond: 3,
    );
  });
}

class _FakeGhostPacerHistory implements GhostPacerHistory {
  const _FakeGhostPacerHistory({
    required this.sessions,
    required this.telemetry,
  });

  final List<RideSessionSnapshot> sessions;
  final Map<String, List<TelemetryLocation>> telemetry;

  @override
  Future<List<RideSessionSnapshot>> loadCompletedSessions() async => sessions;

  @override
  Future<List<TelemetryLocation>> loadTelemetryLocations(
    String sessionId,
  ) async => telemetry[sessionId] ?? const [];
}
