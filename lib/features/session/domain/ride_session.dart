enum RideSessionStatus { recording, paused, completed }

class RideSessionSnapshot {
  const RideSessionSnapshot({
    required this.id,
    required this.startedAt,
    required this.status,
    required this.totalPausedMilliseconds,
    required this.distanceMeters,
    required this.currentSpeedMetersPerSecond,
    this.endedAt,
    this.pausedAt,
    this.gpsAccuracyMeters,
  });

  final String id;
  final DateTime startedAt;
  final DateTime? endedAt;
  final DateTime? pausedAt;
  final RideSessionStatus status;
  final int totalPausedMilliseconds;
  final double distanceMeters;
  final double currentSpeedMetersPerSecond;
  final double? gpsAccuracyMeters;

  Duration durationAt(DateTime now) {
    final end = endedAt ?? now;
    final currentlyPaused =
        status == RideSessionStatus.paused && pausedAt != null
        ? end.difference(pausedAt!).inMilliseconds
        : 0;
    final elapsed =
        end.difference(startedAt).inMilliseconds -
        totalPausedMilliseconds -
        currentlyPaused;
    return Duration(milliseconds: elapsed.clamp(0, 1 << 62));
  }
}

class TelemetryLocation {
  const TelemetryLocation({
    required this.recordedAt,
    required this.latitude,
    required this.longitude,
    required this.accuracyMeters,
    required this.altitudeMeters,
    required this.speedMetersPerSecond,
  });

  final DateTime recordedAt;
  final double latitude;
  final double longitude;
  final double accuracyMeters;
  final double altitudeMeters;
  final double speedMetersPerSecond;

  Map<String, Object> toJson() => {
    'latitude': latitude,
    'longitude': longitude,
    'accuracyMeters': accuracyMeters,
    'altitudeMeters': altitudeMeters,
    'speedMetersPerSecond': speedMetersPerSecond,
  };

  factory TelemetryLocation.fromJson(
    Map<String, dynamic> json, {
    required DateTime recordedAt,
  }) => TelemetryLocation(
    recordedAt: recordedAt,
    latitude: (json['latitude'] as num).toDouble(),
    longitude: (json['longitude'] as num).toDouble(),
    accuracyMeters: (json['accuracyMeters'] as num).toDouble(),
    altitudeMeters: (json['altitudeMeters'] as num).toDouble(),
    speedMetersPerSecond: (json['speedMetersPerSecond'] as num).toDouble(),
  );
}
