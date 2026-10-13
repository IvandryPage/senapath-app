import 'dart:math' as math;

import 'ride_history_entry.dart';

class RideTimePrediction {
  const RideTimePrediction({
    required this.durationMinutes,
    required this.neighborCount,
    required this.neighborSessionIds,
  });

  final double durationMinutes;
  final int neighborCount;
  final List<String> neighborSessionIds;
}

class RideTimePredictor {
  const RideTimePredictor({this.neighborCount = 3});

  final int neighborCount;

  RideTimePrediction? predict({
    required double distanceKm,
    required double elevationGainMeters,
    required List<RideHistoryEntry> history,
  }) {
    if (!distanceKm.isFinite ||
        distanceKm <= 0 ||
        !elevationGainMeters.isFinite ||
        elevationGainMeters < 0 ||
        neighborCount < 1) {
      return null;
    }

    final eligibleHistory = history.where((entry) => entry.hasValidFeatures);
    final routeProfile = elevationGainMeters / distanceKm;
    final neighbors =
        [
          for (final entry in eligibleHistory)
            _Neighbor(
              entry: entry,
              distance: _distance(
                distanceKm: distanceKm,
                elevationGainMeters: elevationGainMeters,
                elevationPerDistance: routeProfile,
                entry: entry,
              ),
            ),
        ]..sort((left, right) {
          final byDistance = left.distance.compareTo(right.distance);
          return byDistance != 0
              ? byDistance
              : left.entry.completedAt.compareTo(right.entry.completedAt);
        });

    if (neighbors.length < neighborCount) return null;
    final nearest = neighbors.take(neighborCount).toList(growable: false);
    final averageDuration =
        nearest.fold<double>(
          0,
          (sum, neighbor) => sum + neighbor.entry.durationMinutes,
        ) /
        nearest.length;
    return RideTimePrediction(
      durationMinutes: averageDuration,
      neighborCount: nearest.length,
      neighborSessionIds: [
        for (final neighbor in nearest) neighbor.entry.sessionId,
      ],
    );
  }

  double _distance({
    required double distanceKm,
    required double elevationGainMeters,
    required double elevationPerDistance,
    required RideHistoryEntry entry,
  }) {
    final normalizedDistance = (distanceKm - entry.distanceKm) / 50;
    final normalizedElevation =
        (elevationGainMeters - entry.elevationGainMeters) / 1000;
    final normalizedProfile =
        (elevationPerDistance - entry.elevationPerDistance) / 20;
    return math.sqrt(
      normalizedDistance * normalizedDistance +
          normalizedElevation * normalizedElevation +
          normalizedProfile * normalizedProfile,
    );
  }
}

class _Neighbor {
  const _Neighbor({required this.entry, required this.distance});

  final RideHistoryEntry entry;
  final double distance;
}
