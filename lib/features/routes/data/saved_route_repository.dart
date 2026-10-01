import 'package:drift/drift.dart';
import 'package:geolocator/geolocator.dart';

import '../../../core/storage/app_database.dart';
import '../domain/saved_route.dart';

class SavedRouteRepository {
  const SavedRouteRepository(this.database);

  final AppDatabase database;

  Future<List<RouteRecord>> search(String query) async {
    final normalized = query.trim();
    final rows =
        await (database.select(database.savedRoutes)
              ..where(
                (route) => normalized.isEmpty
                    ? const Constant(true)
                    : route.name.like('%$normalized%'),
              )
              ..orderBy([(route) => OrderingTerm.desc(route.updatedAt)]))
            .get();
    return rows.map(_map).toList(growable: false);
  }

  Future<RouteRecord> saveImportedRoute({
    required String name,
    required List<({double latitude, double longitude, double elevation})>
    points,
  }) async {
    if (points.length < 2) {
      throw const FormatException('Rute membutuhkan minimal dua titik.');
    }
    var distanceMeters = 0.0;
    var elevationGainMeters = 0.0;
    for (var index = 1; index < points.length; index++) {
      final previous = points[index - 1];
      final current = points[index];
      distanceMeters += Geolocator.distanceBetween(
        previous.latitude,
        previous.longitude,
        current.latitude,
        current.longitude,
      );
      final elevationChange = current.elevation - previous.elevation;
      if (elevationChange > 3) elevationGainMeters += elevationChange;
    }

    final routeId = 'gpx-${DateTime.now().microsecondsSinceEpoch}';
    await database
        .into(database.savedRoutes)
        .insert(
          SavedRoutesCompanion.insert(
            id: routeId,
            name: name.trim().isEmpty ? 'Rute GPX impor' : name.trim(),
            source: 'GPX lokal',
            updatedAt: DateTime.now().toUtc(),
            distanceMeters: Value(distanceMeters),
            elevationGainMeters: Value(elevationGainMeters),
            availability: const Value('offline'),
          ),
        );
    final row = await (database.select(
      database.savedRoutes,
    )..where((route) => route.id.equals(routeId))).getSingle();
    return _map(row);
  }

  RouteRecord _map(SavedRoute row) => RouteRecord(
    id: row.id,
    name: row.name,
    source: row.source,
    updatedAt: row.updatedAt,
    availability: row.availability,
    distanceMeters: row.distanceMeters,
    elevationGainMeters: row.elevationGainMeters,
    poiSummary: row.poiSummary,
  );
}
