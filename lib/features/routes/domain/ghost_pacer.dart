import 'dart:math' as math;

import 'saved_route.dart';

class GhostPacerSample {
  const GhostPacerSample({
    required this.elapsed,
    required this.distanceMeters,
  });

  final Duration elapsed;
  final double distanceMeters;
}

class GhostPacerPerformance {
  const GhostPacerPerformance({
    required this.sessionId,
    required this.duration,
    required this.samples,
  });

  final String sessionId;
  final Duration duration;
  final List<GhostPacerSample> samples;

  double distanceAt(Duration elapsed) {
    if (samples.isEmpty || elapsed <= samples.first.elapsed) {
      return samples.isEmpty ? 0 : samples.first.distanceMeters;
    }
    if (elapsed >= duration) return samples.last.distanceMeters;

    for (var index = 1; index < samples.length; index++) {
      final previous = samples[index - 1];
      final next = samples[index];
      if (elapsed > next.elapsed) continue;
      final interval = next.elapsed.inMicroseconds -
          previous.elapsed.inMicroseconds;
      if (interval <= 0) return next.distanceMeters;
      final progress =
          (elapsed.inMicroseconds - previous.elapsed.inMicroseconds) /
          interval;
      return previous.distanceMeters +
          (next.distanceMeters - previous.distanceMeters) * progress;
    }
    return samples.last.distanceMeters;
  }
}

class GhostPacerMapPosition {
  const GhostPacerMapPosition({
    required this.point,
    required this.headingDegrees,
  });

  final RoutePoint point;
  final double headingDegrees;
}

GhostPacerMapPosition? ghostPacerMapPositionAt(
  List<RoutePoint> route,
  double distanceMeters,
) {
  if (route.length < 2 || !distanceMeters.isFinite) return null;

  var distanceLeft = math.max(0, distanceMeters);
  for (var index = 1; index < route.length; index++) {
    final start = route[index - 1];
    final end = route[index];
    final segmentLength = _distanceBetween(start, end);
    if (distanceLeft <= segmentLength || index == route.length - 1) {
      final fraction = segmentLength == 0
          ? 0.0
          : (distanceLeft / segmentLength).clamp(0.0, 1.0);
      return GhostPacerMapPosition(
        point: RoutePoint(
          latitude: start.latitude + (end.latitude - start.latitude) * fraction,
          longitude:
              start.longitude + (end.longitude - start.longitude) * fraction,
          elevationMeters:
              start.elevationMeters +
              (end.elevationMeters - start.elevationMeters) * fraction,
        ),
        headingDegrees: _headingBetween(start, end),
      );
    }
    distanceLeft -= segmentLength;
  }
  return null;
}

double _distanceBetween(RoutePoint first, RoutePoint second) {
  const earthRadiusMeters = 6371000.0;
  final latitudeDelta = _radians(second.latitude - first.latitude);
  final longitudeDelta = _radians(second.longitude - first.longitude);
  final a =
      math.pow(math.sin(latitudeDelta / 2), 2) +
      math.cos(_radians(first.latitude)) *
          math.cos(_radians(second.latitude)) *
          math.pow(math.sin(longitudeDelta / 2), 2);
  return earthRadiusMeters * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
}

double _headingBetween(RoutePoint first, RoutePoint second) {
  final latitude1 = _radians(first.latitude);
  final latitude2 = _radians(second.latitude);
  final longitudeDelta = _radians(second.longitude - first.longitude);
  final y = math.sin(longitudeDelta) * math.cos(latitude2);
  final x =
      math.cos(latitude1) * math.sin(latitude2) -
      math.sin(latitude1) * math.cos(latitude2) * math.cos(longitudeDelta);
  return (math.atan2(y, x) * 180 / math.pi + 360) % 360;
}

double _radians(double degrees) => degrees * math.pi / 180;
