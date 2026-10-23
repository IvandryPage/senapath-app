import 'dart:math' as math;

import 'package:geolocator/geolocator.dart';

import '../../session/domain/ride_session.dart';
import 'saved_route.dart';

class RouteProgress {
  /// Membuat ringkasan progres perjalanan pada rute.
  const RouteProgress({
    required this.percent,
    required this.distanceTravelledMeters,
    required this.distanceRemainingMeters,
    required this.distanceFromRouteMeters,
    required this.nearestPointIndex,
  });

  final int percent;
  final double distanceTravelledMeters;
  final double distanceRemainingMeters;
  final double distanceFromRouteMeters;
  final int nearestPointIndex;

  /// Menghitung progres rute dari posisi [location] saat ini.
  static RouteProgress? calculate({
    required RouteRecord route,
    required TelemetryLocation location,
  }) => RouteProgressCalculator(route).calculate(location);

  /// Menghitung jarak meter dari [location] ke [checkpoint].
  static double distanceToCheckpoint(
    TelemetryLocation location,
    RouteCheckpoint checkpoint,
  ) => Geolocator.distanceBetween(
    location.latitude,
    location.longitude,
    checkpoint.latitude,
    checkpoint.longitude,
  );
}

class RouteProgressCalculator {
  /// Menyiapkan kalkulator dengan jarak kumulatif dari [route].
  RouteProgressCalculator(RouteRecord route)
    : _route = route,
      _cumulativeDistances = _calculateCumulativeDistances(route.points);

  final RouteRecord _route;
  final List<double> _cumulativeDistances;

  /// Mencari titik terdekat pada rute lalu menghitung persentase progres.
  RouteProgress? calculate(TelemetryLocation location) {
    if (_route.points.length < 2 ||
        !location.latitude.isFinite ||
        !location.longitude.isFinite) {
      return null;
    }

    var nearestIndex = 0;
    var nearestDistance = double.infinity;
    for (var index = 0; index < _route.points.length; index++) {
      final point = _route.points[index];
      final distance = Geolocator.distanceBetween(
        location.latitude,
        location.longitude,
        point.latitude,
        point.longitude,
      );
      if (distance < nearestDistance) {
        nearestIndex = index;
        nearestDistance = distance;
      }
    }
    final totalDistance = _cumulativeDistances.last;
    final travelled = _cumulativeDistances[nearestIndex];
    final percent = totalDistance <= 0
        ? 0
        : (travelled / totalDistance * 100).round().clamp(0, 100);
    return RouteProgress(
      percent: percent,
      distanceTravelledMeters: travelled,
      distanceRemainingMeters: math.max(0, totalDistance - travelled),
      distanceFromRouteMeters: nearestDistance,
      nearestPointIndex: nearestIndex,
    );
  }

  /// Menghitung jarak kumulatif setiap titik rute dari titik awal.
  static List<double> _calculateCumulativeDistances(List<RoutePoint> points) {
    final cumulative = List<double>.filled(points.length, 0);
    for (var index = 1; index < points.length; index++) {
      cumulative[index] =
          cumulative[index - 1] + _distance(points[index - 1], points[index]);
    }
    return cumulative;
  }

  /// Menghitung jarak meter dari [location] ke [checkpoint].
  static double distanceToCheckpoint(
    TelemetryLocation location,
    RouteCheckpoint checkpoint,
  ) => Geolocator.distanceBetween(
    location.latitude,
    location.longitude,
    checkpoint.latitude,
    checkpoint.longitude,
  );

  /// Menghitung jarak meter antara dua titik rute.
  static double _distance(RoutePoint first, RoutePoint second) =>
      Geolocator.distanceBetween(
        first.latitude,
        first.longitude,
        second.latitude,
        second.longitude,
      );
}
