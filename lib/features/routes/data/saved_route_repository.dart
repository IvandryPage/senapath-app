import 'package:drift/drift.dart';

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
