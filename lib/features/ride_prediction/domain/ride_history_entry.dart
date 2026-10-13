class RideHistoryEntry {
  const RideHistoryEntry({
    required this.sessionId,
    required this.distanceKm,
    required this.elevationGainMeters,
    required this.elevationPerDistance,
    required this.durationMinutes,
    required this.completedAt,
  });

  final String sessionId;
  final double distanceKm;
  final double elevationGainMeters;
  final double elevationPerDistance;
  final double durationMinutes;
  final DateTime completedAt;

  bool get hasValidFeatures =>
      distanceKm.isFinite &&
      distanceKm > 0 &&
      elevationGainMeters.isFinite &&
      elevationGainMeters >= 0 &&
      elevationPerDistance.isFinite &&
      elevationPerDistance >= 0 &&
      durationMinutes.isFinite &&
      durationMinutes > 0;
}
