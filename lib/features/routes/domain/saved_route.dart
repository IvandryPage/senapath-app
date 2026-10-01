class RouteRecord {
  const RouteRecord({
    required this.id,
    required this.name,
    required this.source,
    required this.updatedAt,
    required this.availability,
    this.distanceMeters,
    this.elevationGainMeters,
    this.poiSummary = '',
  });

  final String id;
  final String name;
  final String source;
  final DateTime updatedAt;
  final String availability;
  final double? distanceMeters;
  final double? elevationGainMeters;
  final String poiSummary;
}
