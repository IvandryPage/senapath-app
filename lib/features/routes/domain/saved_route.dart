class RoutePoint {
  /// Membuat titik rute dari koordinat dan elevasi.
  const RoutePoint({
    required this.latitude,
    required this.longitude,
    required this.elevationMeters,
  });

  final double latitude;
  final double longitude;
  final double elevationMeters;
}

class RouteCheckpoint {
  /// Membuat checkpoint rute dengan nama dan koordinat.
  const RouteCheckpoint({
    required this.name,
    required this.latitude,
    required this.longitude,
  });

  final String name;
  final double latitude;
  final double longitude;
}

class RouteRecord {
  /// Membuat rekaman rute dengan metadata dan geometri opsional.
  const RouteRecord({
    required this.id,
    required this.name,
    required this.source,
    required this.updatedAt,
    required this.availability,
    this.description = '',
    this.distanceMeters,
    this.elevationGainMeters,
    this.poiSummary = '',
    this.points = const [],
    this.checkpoints = const [],
  });

  final String id;
  final String name;
  final String source;
  final DateTime updatedAt;
  final String availability;
  final String description;
  final double? distanceMeters;
  final double? elevationGainMeters;
  final String poiSummary;
  final List<RoutePoint> points;
  final List<RouteCheckpoint> checkpoints;
}
