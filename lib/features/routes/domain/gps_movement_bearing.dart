import 'dart:math' as math;

import '../../session/domain/ride_session.dart';

const _earthRadiusMeters = 6371000.0;

double? gpsMovementBearing(
  List<TelemetryLocation> locations, {
  required DateTime now,
}) {
  final recentLocations = <TelemetryLocation>[];
  for (final location in locations.reversed) {
    final age = now.difference(location.recordedAt);
    if (age.isNegative) continue;
    if (age > const Duration(seconds: 20)) break;
    if (!location.accuracyMeters.isFinite ||
        location.accuracyMeters < 0 ||
        location.accuracyMeters > 25 ||
        !location.latitude.isFinite ||
        location.latitude < -90 ||
        location.latitude > 90 ||
        !location.longitude.isFinite ||
        location.longitude < -180 ||
        location.longitude > 180) {
      continue;
    }
    recentLocations.add(location);
    if (recentLocations.length == 2) break;
  }

  if (recentLocations.length < 2) return null;
  final latest = recentLocations[0];
  final previous = recentLocations[1];
  final elapsedSeconds =
      latest.recordedAt.difference(previous.recordedAt).inMilliseconds /
      Duration.millisecondsPerSecond;
  if (elapsedSeconds <= 0 || elapsedSeconds > 20) return null;

  final previousLatitude = _degreesToRadians(previous.latitude);
  final latestLatitude = _degreesToRadians(latest.latitude);
  final latitudeDifference = latestLatitude - previousLatitude;
  final longitudeDifference = _degreesToRadians(
    latest.longitude - previous.longitude,
  );
  final haversine =
      math.pow(math.sin(latitudeDifference / 2), 2) +
      math.cos(previousLatitude) *
          math.cos(latestLatitude) *
          math.pow(math.sin(longitudeDifference / 2), 2);
  final distanceMeters =
      2 * _earthRadiusMeters * math.asin(math.sqrt(haversine));
  if (distanceMeters < 3 || distanceMeters / elapsedSeconds < 1.5) {
    return null;
  }

  final y = math.sin(longitudeDifference) * math.cos(latestLatitude);
  final x =
      math.cos(previousLatitude) * math.sin(latestLatitude) -
      math.sin(previousLatitude) *
          math.cos(latestLatitude) *
          math.cos(longitudeDifference);
  return (math.atan2(y, x) * 180 / math.pi + 360) % 360;
}

double _degreesToRadians(double degrees) => degrees * math.pi / 180;
