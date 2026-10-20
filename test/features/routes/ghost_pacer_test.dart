import 'package:flutter_test/flutter_test.dart';
import 'package:senapath/features/routes/domain/ghost_pacer.dart';
import 'package:senapath/features/routes/domain/saved_route.dart';

RoutePoint _point(double latitude, double longitude) => RoutePoint(
  latitude: latitude,
  longitude: longitude,
  elevationMeters: 10,
);

void main() {
  group('GhostPacerPerformance.distanceAt', () {
    final performance = GhostPacerPerformance(
      sessionId: 's1',
      duration: const Duration(minutes: 10),
      samples: const [
        GhostPacerSample(elapsed: Duration.zero, distanceMeters: 0),
        GhostPacerSample(
          elapsed: Duration(minutes: 5),
          distanceMeters: 1000,
        ),
        GhostPacerSample(
          elapsed: Duration(minutes: 10),
          distanceMeters: 3000,
        ),
      ],
    );

    test('returns the starting distance before the first sample', () {
      expect(performance.distanceAt(const Duration(minutes: -1)), 0);
      expect(performance.distanceAt(Duration.zero), 0);
    });

    test('interpolates between samples', () {
      expect(
        performance.distanceAt(const Duration(minutes: 2, seconds: 30)),
        500,
      );
      expect(
        performance.distanceAt(const Duration(minutes: 7, seconds: 30)),
        2000,
      );
    });

    test('clamps to the last sample once the ride is over', () {
      expect(
        performance.distanceAt(const Duration(minutes: 12)),
        3000,
      );
    });

    test('handles empty samples and zero-length intervals', () {
      final empty = GhostPacerPerformance(
        sessionId: 's2',
        duration: Duration.zero,
        samples: const [],
      );
      expect(empty.distanceAt(Duration.zero), 0);

      final duplicated = GhostPacerPerformance(
        sessionId: 's3',
        duration: const Duration(minutes: 5),
        samples: const [
          GhostPacerSample(elapsed: Duration.zero, distanceMeters: 100),
          GhostPacerSample(
            elapsed: Duration(minutes: 5),
            distanceMeters: 100,
          ),
        ],
      );
      expect(duplicated.distanceAt(const Duration(minutes: 2)), 100);
    });
  });

  group('ghostPacerMapPositionAt', () {
    final route = [
      _point(-6.20, 106.80),
      _point(-6.19, 106.80),
      _point(-6.18, 106.80),
    ];

    test('returns null for short routes or non-finite distances', () {
      expect(ghostPacerMapPositionAt([_point(-6.2, 106.8)], 0), isNull);
      expect(ghostPacerMapPositionAt(route, double.nan), isNull);
    });

    test('places the ghost at the start of the route', () {
      final position = ghostPacerMapPositionAt(route, 0)!;
      expect(position.point.latitude, moreOrLessEquals(-6.20, epsilon: 1e-6));
      expect(position.headingDegrees, moreOrLessEquals(0, epsilon: 1));
    });

    test('interpolates along the first segment', () {
      final position = ghostPacerMapPositionAt(route, 550)!;
      expect(position.point.latitude, lessThan(-6.19));
      expect(position.point.latitude, greaterThan(-6.20));
      expect(position.point.elevationMeters, 10);
    });

    test('advances into the second segment', () {
      final position = ghostPacerMapPositionAt(route, 1700)!;
      expect(position.point.latitude, lessThan(-6.18));
      expect(position.point.latitude, greaterThan(-6.19));
    });

    test('clamps past-the-end distances to the final point', () {
      final position = ghostPacerMapPositionAt(route, 999999)!;
      expect(position.point.latitude, moreOrLessEquals(-6.18, epsilon: 1e-6));
    });

    test('clamps negative distances to the first point', () {
      final position = ghostPacerMapPositionAt(route, -100)!;
      expect(position.point.latitude, moreOrLessEquals(-6.20, epsilon: 1e-6));
    });
  });
}
