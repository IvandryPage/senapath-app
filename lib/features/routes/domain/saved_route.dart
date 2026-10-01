class RoutePoint {
  const RoutePoint({
    required this.latitude,
    required this.longitude,
    required this.elevationMeters,
  });

  final double latitude;
  final double longitude;
  final double elevationMeters;
}

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
    this.points = const [],
  });

  final String id;
  final String name;
  final String source;
  final DateTime updatedAt;
  final String availability;
  final double? distanceMeters;
  final double? elevationGainMeters;
  final String poiSummary;
  final List<RoutePoint> points;
}
