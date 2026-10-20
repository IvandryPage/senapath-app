import 'package:flutter_test/flutter_test.dart';
import 'package:senapath/features/routes/domain/route_wind.dart';
import 'package:senapath/features/routes/domain/saved_route.dart';

RoutePoint _point(double latitude, double longitude) => RoutePoint(
  latitude: latitude,
  longitude: longitude,
  elevationMeters: 0,
);

void main() {
  group('RouteWindObservation.fromJson', () {
    test('parses a valid observation', () {
      final observation = RouteWindObservation.fromJson({
        'current': {
          'wind_direction_10m': 270.4,
          'time': '2026-01-05T10:00',
        },
      });
      expect(observation.directionFromDegrees, 270);
      expect(observation.observedAt, DateTime(2026, 1, 5, 10));
    });

    test('wraps a full-circle direction back to zero', () {
      final observation = RouteWindObservation.fromJson({
        'current': {'wind_direction_10m': 359.6, 'time': '2026-01-05T10:00'},
      });
      expect(observation.directionFromDegrees, 0);
    });

    test('rejects a missing current block', () {
      expect(
        () => RouteWindObservation.fromJson(const {}),
        throwsFormatException,
      );
    });

    test('rejects out-of-range directions and bad timestamps', () {
      expect(
        () => RouteWindObservation.fromJson({
          'current': {'wind_direction_10m': 360, 'time': '2026-01-05T10:00'},
        }),
        throwsFormatException,
      );
      expect(
        () => RouteWindObservation.fromJson({
          'current': {'wind_direction_10m': -1, 'time': '2026-01-05T10:00'},
        }),
        throwsFormatException,
      );
      expect(
        () => RouteWindObservation.fromJson({
          'current': {'wind_direction_10m': 10, 'time': 'nope'},
        }),
        throwsFormatException,
      );
      expect(
        () => RouteWindObservation.fromJson({
          'current': {'wind_direction_10m': null, 'time': '2026-01-05T10:00'},
        }),
        throwsFormatException,
      );
    });
  });

  group('routeHeadingDegrees', () {
    test('computes a northbound heading', () {
      final heading = routeHeadingDegrees(
        [_point(-6.20, 106.80), _point(-6.18, 106.80)],
        0,
      );
      expect(heading, moreOrLessEquals(0, epsilon: 0.5));
    });

    test('computes an eastbound heading', () {
      final heading = routeHeadingDegrees(
        [_point(-6.20, 106.80), _point(-6.20, 106.82)],
        0,
      );
      expect(heading, moreOrLessEquals(90, epsilon: 0.5));
    });

    test('clamps an out-of-range nearest index', () {
      final points = [_point(-6.20, 106.80), _point(-6.18, 106.80)];
      // Index 99 clamps to the final point, heading back to the previous one.
      expect(routeHeadingDegrees(points, 99), moreOrLessEquals(0, epsilon: 1));
    });

    test('skips repeated identical points ahead of the index', () {
      final heading = routeHeadingDegrees(
        [
          _point(-6.20, 106.80),
          _point(-6.20, 106.80),
          _point(-6.20, 106.82),
        ],
        0,
      );
      expect(heading, moreOrLessEquals(90, epsilon: 0.5));
    });

    test('looks backwards when only duplicates follow the index', () {
      // The final point duplicates its predecessor, so the heading is taken
      // from the previous distinct point, which is eastbound.
      final heading = routeHeadingDegrees(
        [
          _point(-6.20, 106.80),
          _point(-6.20, 106.82),
          _point(-6.20, 106.82),
        ],
        2,
      );
      expect(heading, moreOrLessEquals(90, epsilon: 0.5));
    });

    test('throws for fewer than two points', () {
      expect(
        () => routeHeadingDegrees([_point(-6.2, 106.8)], 0),
        throwsArgumentError,
      );
    });
  });

  group('relativeWindDescription', () {
    test('describes headwind and tailwind', () {
      expect(
        relativeWindDescription(windFromDegrees: 0, routeHeadingDegrees: 0),
        'angin dari depan',
      );
      expect(
        relativeWindDescription(windFromDegrees: 350, routeHeadingDegrees: 0),
        'angin dari depan',
      );
      expect(
        relativeWindDescription(windFromDegrees: 180, routeHeadingDegrees: 0),
        'angin dari belakang',
      );
    });

    test('describes crosswinds from both sides', () {
      expect(
        relativeWindDescription(windFromDegrees: 90, routeHeadingDegrees: 0),
        'angin dari kanan',
      );
      expect(
        relativeWindDescription(windFromDegrees: 270, routeHeadingDegrees: 0),
        'angin dari kiri',
      );
    });
  });

  group('windArrowRotationRadians', () {
    test('converts the relative bearing into radians', () {
      expect(
        windArrowRotationRadians(
          windFromDegrees: 0,
          routeHeadingDegrees: 0,
        ),
        moreOrLessEquals(3.14159265, epsilon: 0.0001),
        reason: 'wind from ahead blows towards the rider (180 degrees)',
      );
      expect(
        windArrowRotationRadians(
          windFromDegrees: 180,
          routeHeadingDegrees: 0,
        ),
        moreOrLessEquals(0, epsilon: 0.0001),
        reason: 'tailwind blows in the riding direction',
      );
    });
  });
}
