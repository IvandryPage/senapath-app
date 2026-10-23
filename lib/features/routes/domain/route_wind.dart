import 'dart:math' as math;

import 'saved_route.dart';

class RouteWindObservation {
  /// Membuat observasi arah angin pada waktu tertentu.
  const RouteWindObservation({
    required this.directionFromDegrees,
    required this.observedAt,
  });

  final int directionFromDegrees;
  final DateTime observedAt;

  /// Membangun observasi angin dari respons JSON Open-Meteo.
  factory RouteWindObservation.fromJson(Map<String, Object?> json) {
    final current = json['current'];
    if (current is! Map) {
      throw const FormatException('Missing current weather observation.');
    }
    final direction = (current['wind_direction_10m'] as num?)?.toDouble();
    final observedAt = DateTime.tryParse(current['time'] as String? ?? '');
    if (direction == null ||
        !direction.isFinite ||
        direction < 0 ||
        direction >= 360 ||
        observedAt == null) {
      throw const FormatException('Invalid current wind observation.');
    }
    return RouteWindObservation(
      directionFromDegrees: direction.round() % 360,
      observedAt: observedAt,
    );
  }
}

/// Menghitung arah rute derajat di sekitar indeks titik terdekat.
double routeHeadingDegrees(List<RoutePoint> points, int nearestPointIndex) {
  if (points.length < 2) {
    throw ArgumentError.value(points.length, 'points');
  }
  final index = nearestPointIndex.clamp(0, points.length - 1);
  var startIndex = index;
  var endIndex = index + 1;
  while (endIndex < points.length &&
      _sameCoordinate(points[startIndex], points[endIndex])) {
    endIndex++;
  }
  if (endIndex == points.length) {
    endIndex = index;
    startIndex = index - 1;
    while (startIndex >= 0 &&
        _sameCoordinate(points[startIndex], points[endIndex])) {
      startIndex--;
    }
  }
  if (startIndex < 0 || endIndex >= points.length) return 0;

  final first = points[startIndex];
  final second = points[endIndex];
  final latitude1 = first.latitude * math.pi / 180;
  final latitude2 = second.latitude * math.pi / 180;
  final longitudeDelta = (second.longitude - first.longitude) * math.pi / 180;
  final y = math.sin(longitudeDelta) * math.cos(latitude2);
  final x =
      math.cos(latitude1) * math.sin(latitude2) -
      math.sin(latitude1) * math.cos(latitude2) * math.cos(longitudeDelta);
  return (math.atan2(y, x) * 180 / math.pi + 360) % 360;
}

/// Memeriksa apakah dua titik memiliki koordinat yang sama.
bool _sameCoordinate(RoutePoint first, RoutePoint second) =>
    first.latitude == second.latitude && first.longitude == second.longitude;

/// Menjelaskan posisi angin relatif terhadap arah rute.
String relativeWindDescription({
  required int windFromDegrees,
  required double routeHeadingDegrees,
}) {
  final difference = (windFromDegrees - routeHeadingDegrees + 360) % 360;
  if (difference <= 45 || difference >= 315) return 'angin dari depan';
  if (difference >= 135 && difference <= 225) return 'angin dari belakang';
  return difference < 180 ? 'angin dari kanan' : 'angin dari kiri';
}

/// Menghitung rotasi panah angin relatif terhadap arah rute.
double windArrowRotationRadians({
  required int windFromDegrees,
  required double routeHeadingDegrees,
}) {
  final blowingTo = (windFromDegrees + 180) % 360;
  final relativeBearing = (blowingTo - routeHeadingDegrees + 360) % 360;
  return relativeBearing * math.pi / 180;
}
