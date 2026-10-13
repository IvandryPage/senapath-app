import 'package:flutter_test/flutter_test.dart';
import 'package:senapath/features/routes/domain/route_wind.dart';
import 'package:senapath/features/routes/domain/saved_route.dart';

void main() {
  group('route wind direction', () {
    const northbound = [
      RoutePoint(
        latitude: 0,
        longitude: 0,
        elevationMeters: 0,
      ),
      RoutePoint(
        latitude: 1,
        longitude: 0,
        elevationMeters: 0,
      ),
    ];

    test('calculates route heading from the current route segment', () {
      expect(routeHeadingDegrees(northbound, 0), closeTo(0, 0.01));
      expect(routeHeadingDegrees(northbound, 1), closeTo(0, 0.01));
    });

    test('uses the next distinct point when a segment has duplicate points', () {
      const points = [
        RoutePoint(latitude: 0, longitude: 0, elevationMeters: 0),
        RoutePoint(latitude: 0, longitude: 0, elevationMeters: 0),
        RoutePoint(latitude: 0, longitude: 1, elevationMeters: 0),
      ];

      expect(routeHeadingDegrees(points, 0), closeTo(90, 0.01));
      expect(routeHeadingDegrees(points, 1), closeTo(90, 0.01));
      expect(routeHeadingDegrees(points, 2), closeTo(90, 0.01));
    });

    test('classifies wind coming from relative to the route heading', () {
      expect(
        relativeWindDescription(windFromDegrees: 5, routeHeadingDegrees: 0),
        'angin dari depan',
      );
      expect(
        relativeWindDescription(windFromDegrees: 180, routeHeadingDegrees: 0),
        'angin dari belakang',
      );
      expect(
        relativeWindDescription(windFromDegrees: 90, routeHeadingDegrees: 0),
        'angin dari kanan',
      );
      expect(
        relativeWindDescription(windFromDegrees: 270, routeHeadingDegrees: 0),
        'angin dari kiri',
      );
    });

    test('rotates wind arrow to the direction the wind is blowing', () {
      expect(
        windArrowRotationRadians(
          windFromDegrees: 0,
          routeHeadingDegrees: 0,
        ),
        closeTo(3.14159, 0.001),
      );
      expect(
        windArrowRotationRadians(
          windFromDegrees: 180,
          routeHeadingDegrees: 0,
        ),
        closeTo(0, 0.001),
      );
    });
  });
}
