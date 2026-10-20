import 'package:flutter_test/flutter_test.dart';
import 'package:senapath/features/routes/domain/route_progress.dart';
import 'package:senapath/features/routes/domain/saved_route.dart';
import 'package:senapath/features/session/domain/ride_session.dart';

RoutePoint _point(double latitude, double longitude) => RoutePoint(
  latitude: latitude,
  longitude: longitude,
  elevationMeters: 0,
);

RouteRecord _route(List<RoutePoint> points) => RouteRecord(
  id: 'r1',
  name: 'Test route',
  source: 'manual',
  updatedAt: DateTime.utc(2026),
  availability: 'available',
  points: points,
);

TelemetryLocation _location(double latitude, double longitude) =>
    TelemetryLocation(
      recordedAt: DateTime.utc(2026),
      latitude: latitude,
      longitude: longitude,
      accuracyMeters: 5,
      altitudeMeters: 0,
      speedMetersPerSecond: 0,
    );

void main() {
  group('RouteProgress.calculate', () {
    test('returns null for routes with fewer than two points', () {
      final progress = RouteProgress.calculate(
        route: _route([_point(-6.2, 106.8)]),
        location: _location(-6.2, 106.8),
      );
      expect(progress, isNull);
    });

    test('returns null when coordinates are not finite', () {
      final progress = RouteProgress.calculate(
        route: _route([_point(-6.2, 106.8), _point(-6.3, 106.9)]),
        location: _location(double.nan, 106.8),
      );
      expect(progress, isNull);
    });

    test('reports progress along a northbound route', () {
      // Roughly 1.1 km per 0.01 degree of latitude.
      final route = _route([
        _point(-6.20, 106.80),
        _point(-6.19, 106.80),
        _point(-6.18, 106.80),
      ]);

      final start = RouteProgress.calculate(
        route: route,
        location: _location(-6.20, 106.80),
      )!;
      expect(start.nearestPointIndex, 0);
      expect(start.percent, 0);
      expect(start.distanceTravelledMeters, 0);
      expect(start.distanceRemainingMeters, greaterThan(2000));

      final middle = RouteProgress.calculate(
        route: route,
        location: _location(-6.19, 106.80),
      )!;
      expect(middle.nearestPointIndex, 1);
      expect(middle.percent, 50);
      expect(
        middle.distanceTravelledMeters,
        moreOrLessEquals(middle.distanceTravelledMeters, epsilon: 0.1),
      );
      expect(
        middle.distanceRemainingMeters,
        moreOrLessEquals(middle.distanceTravelledMeters, epsilon: 1),
      );

      final end = RouteProgress.calculate(
        route: route,
        location: _location(-6.18, 106.80),
      )!;
      expect(end.nearestPointIndex, 2);
      expect(end.percent, 100);
      expect(end.distanceRemainingMeters, 0);
      expect(end.distanceFromRouteMeters, lessThan(20));
    });

    test('measures how far the rider strayed from the route', () {
      final route = _route([
        _point(-6.20, 106.80),
        _point(-6.18, 106.80),
      ]);
      final progress = RouteProgress.calculate(
        route: route,
        location: _location(-6.19, 106.81),
      )!;
      expect(progress.distanceFromRouteMeters, greaterThan(500));
    });

    test('handles zero-length routes without dividing by zero', () {
      final route = _route([
        _point(-6.20, 106.80),
        _point(-6.20, 106.80),
      ]);
      final progress = RouteProgress.calculate(
        route: route,
        location: _location(-6.20, 106.80),
      )!;
      expect(progress.percent, 0);
      expect(progress.distanceTravelledMeters, 0);
      expect(progress.distanceRemainingMeters, 0);
    });
  });

  group('RouteProgress.distanceToCheckpoint', () {
    test('measures the straight-line distance', () {
      final distance = RouteProgress.distanceToCheckpoint(
        _location(-6.20, 106.80),
        const RouteCheckpoint(name: 'Finish', latitude: -6.19, longitude: 106.80),
      );
      expect(distance, greaterThan(1000));
      expect(distance, lessThan(1300));
    });

    test('is zero when standing on the checkpoint', () {
      final distance = RouteProgress.distanceToCheckpoint(
        _location(-6.20, 106.80),
        const RouteCheckpoint(
          name: 'Here',
          latitude: -6.20,
          longitude: 106.80,
        ),
      );
      expect(distance, moreOrLessEquals(0, epsilon: 0.01));
    });
  });
}
