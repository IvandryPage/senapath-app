import 'dart:math' as math;

import '../domain/ghost_pacer.dart';
import '../domain/saved_route.dart';
import '../../session/data/ride_session_repository.dart';
import '../../session/domain/ride_session.dart';

abstract interface class GhostPacerHistory {
  Future<List<RideSessionSnapshot>> loadCompletedSessions();
  Future<List<TelemetryLocation>> loadTelemetryLocations(String sessionId);
}

class GhostPacerService {
  const GhostPacerService({required this.history});

  final GhostPacerHistory history;

  Future<GhostPacerPerformance?> loadBestForRoute(RouteRecord route) async {
    if (route.points.length < 2) return null;
    final sessions = await history.loadCompletedSessions();
    GhostPacerPerformance? best;
    for (final session in sessions) {
      if (session.status != RideSessionStatus.completed ||
          session.endedAt == null) {
        continue;
      }
      final duration = session.durationAt(session.endedAt!);
      if (duration <= Duration.zero ||
          (best != null && duration >= best.duration)) {
        continue;
      }
      final locations = await history.loadTelemetryLocations(session.id);
      final performance = _matchPerformance(
        route,
        session,
        duration,
        locations,
      );
      if (performance != null) best = performance;
    }
    return best;
  }
}

class RideSessionGhostPacerHistory implements GhostPacerHistory {
  const RideSessionGhostPacerHistory(this.repository);

  final RideSessionRepository repository;

  @override
  Future<List<RideSessionSnapshot>> loadCompletedSessions() =>
      repository.loadCompletedSessions();

  @override
  Future<List<TelemetryLocation>> loadTelemetryLocations(String sessionId) =>
      repository.loadTelemetryLocations(sessionId);
}

GhostPacerPerformance? _matchPerformance(
  RouteRecord route,
  RideSessionSnapshot session,
  Duration duration,
  List<TelemetryLocation> locations,
) {
  final routeSamples = _sampleRoute(route.points);
  final validLocations =
      locations
          .where(
            (location) =>
                location.latitude.isFinite &&
                location.longitude.isFinite &&
                location.accuracyMeters.isFinite &&
                location.accuracyMeters <= 100,
          )
          .toList(growable: false)
        ..sort(
          (first, second) => first.recordedAt.compareTo(second.recordedAt),
        );
  final trackSamples = _sampleTrack(validLocations);
  if (routeSamples.length < 2 || trackSamples.length < 5) return null;

  var lastProgressMeters = 0.0;
  var matchedCount = 0;
  var totalDeviationMeters = 0.0;
  final matchedProgress = <double>[];
  for (final location in trackSamples) {
    var nearestDistance = double.infinity;
    var nearestProgress = lastProgressMeters;
    for (var index = 1; index < routeSamples.length; index++) {
      final start = routeSamples[index - 1];
      final end = routeSamples[index];
      if (end.distanceMeters < lastProgressMeters - 60) continue;
      final projection = _projectOnSegment(
        location.latitude,
        location.longitude,
        start.point,
        end.point,
      );
      final progress =
          start.distanceMeters +
          (end.distanceMeters - start.distanceMeters) * projection.fraction;
      if (progress < lastProgressMeters - 60) continue;
      if (projection.distanceMeters < nearestDistance) {
        nearestDistance = projection.distanceMeters;
        nearestProgress = progress;
      }
    }

    final tolerance = math.min(
      100.0,
      math.max(40.0, location.accuracyMeters * 2),
    );
    if (nearestDistance <= tolerance) {
      lastProgressMeters = math.max(lastProgressMeters, nearestProgress);
      matchedCount++;
      totalDeviationMeters += nearestDistance;
      matchedProgress.add(lastProgressMeters);
    } else {
      matchedProgress.add(lastProgressMeters);
    }
  }

  final routeLength = routeSamples.last.distanceMeters;
  if (routeLength <= 0 ||
      matchedCount / trackSamples.length < 0.75 ||
      matchedProgress.last < routeLength * 0.85 ||
      matchedProgress.first > routeLength * 0.15 ||
      totalDeviationMeters / matchedCount > 60) {
    return null;
  }

  final firstRecordedAt = trackSamples.first.recordedAt;
  final wallDuration = trackSamples.last.recordedAt.difference(firstRecordedAt);
  if (wallDuration <= Duration.zero) return null;

  final samples = <GhostPacerSample>[];
  for (var index = 0; index < trackSamples.length; index++) {
    final wallElapsed = trackSamples[index].recordedAt.difference(
      firstRecordedAt,
    );
    final elapsed = Duration(
      microseconds:
          (wallElapsed.inMicroseconds *
                  duration.inMicroseconds /
                  wallDuration.inMicroseconds)
              .round(),
    );
    final distance = matchedProgress[index];
    if (samples.isNotEmpty &&
        (elapsed < samples.last.elapsed ||
            distance < samples.last.distanceMeters)) {
      continue;
    }
    samples.add(GhostPacerSample(elapsed: elapsed, distanceMeters: distance));
  }
  if (samples.length < 2) return null;

  return GhostPacerPerformance(
    sessionId: session.id,
    duration: duration,
    samples: List.unmodifiable(samples),
  );
}

List<TelemetryLocation> _sampleTrack(List<TelemetryLocation> locations) {
  if (locations.length <= 300) return locations;
  return [
    for (var sampleIndex = 0; sampleIndex < 300; sampleIndex++)
      locations[(sampleIndex * (locations.length - 1) / 299).round()],
  ];
}

class _RouteSample {
  const _RouteSample({required this.point, required this.distanceMeters});

  final RoutePoint point;
  final double distanceMeters;
}

List<_RouteSample> _sampleRoute(List<RoutePoint> points) {
  final distances = List<double>.filled(points.length, 0);
  for (var index = 1; index < points.length; index++) {
    distances[index] =
        distances[index - 1] +
        _distanceBetweenPoints(points[index - 1], points[index]);
  }
  if (points.length <= 180) {
    return [
      for (var index = 0; index < points.length; index++)
        _RouteSample(point: points[index], distanceMeters: distances[index]),
    ];
  }

  return [
    for (var sampleIndex = 0; sampleIndex < 180; sampleIndex++)
      () {
        final index = (sampleIndex * (points.length - 1) / 179).round();
        return _RouteSample(
          point: points[index],
          distanceMeters: distances[index],
        );
      }(),
  ];
}

double _distanceBetweenPoints(RoutePoint first, RoutePoint second) =>
    _distanceBetweenCoordinates(
      first.latitude,
      first.longitude,
      second.latitude,
      second.longitude,
    );

double _distanceBetweenCoordinates(
  double latitude1,
  double longitude1,
  double latitude2,
  double longitude2,
) {
  const earthRadiusMeters = 6371000.0;
  final latitudeDelta = _radians(latitude2 - latitude1);
  final longitudeDelta = _radians(longitude2 - longitude1);
  final a =
      math.pow(math.sin(latitudeDelta / 2), 2) +
      math.cos(_radians(latitude1)) *
          math.cos(_radians(latitude2)) *
          math.pow(math.sin(longitudeDelta / 2), 2);
  return earthRadiusMeters * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
}

({double fraction, double distanceMeters}) _projectOnSegment(
  double latitude,
  double longitude,
  RoutePoint start,
  RoutePoint end,
) {
  const earthRadiusMeters = 6371000.0;
  final referenceLatitude = _radians(latitude);
  final startX =
      _radians(start.longitude - longitude) *
      earthRadiusMeters *
      math.cos(referenceLatitude);
  final startY = _radians(start.latitude - latitude) * earthRadiusMeters;
  final endX =
      _radians(end.longitude - longitude) *
      earthRadiusMeters *
      math.cos(referenceLatitude);
  final endY = _radians(end.latitude - latitude) * earthRadiusMeters;
  final segmentX = endX - startX;
  final segmentY = endY - startY;
  final segmentLengthSquared = segmentX * segmentX + segmentY * segmentY;
  final fraction = segmentLengthSquared == 0
      ? 0.0
      : (-(startX * segmentX + startY * segmentY) / segmentLengthSquared).clamp(
          0.0,
          1.0,
        );
  final distanceX = startX + segmentX * fraction;
  final distanceY = startY + segmentY * fraction;
  return (
    fraction: fraction,
    distanceMeters: math.sqrt(distanceX * distanceX + distanceY * distanceY),
  );
}

double _radians(double degrees) => degrees * math.pi / 180;
