import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:geolocator/geolocator.dart';

import '../../../core/storage/app_database.dart';
import '../../session/data/encrypted_telemetry_codec.dart';
import '../domain/saved_route.dart';

class SavedRouteRepository {
  const SavedRouteRepository(this.database, {required this.geometryCodec});

  final AppDatabase database;
  final EncryptedTelemetryCodec geometryCodec;

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
    return Future.wait(rows.map(_map));
  }

  Future<RouteRecord> saveImportedRoute({
    required String name,
    String description = '',
    required List<({double latitude, double longitude, double elevation})>
    points,
  }) async {
    if (points.length < 2) {
      throw const FormatException('Rute membutuhkan minimal dua titik.');
    }
    for (final point in points) {
      if (!point.latitude.isFinite ||
          point.latitude < -90 ||
          point.latitude > 90 ||
          !point.longitude.isFinite ||
          point.longitude < -180 ||
          point.longitude > 180 ||
          !point.elevation.isFinite) {
        throw const FormatException('Koordinat rute tidak valid.');
      }
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
    final encryptedGeometry = await geometryCodec.encryptBytes(
      utf8.encode(
        jsonEncode([
          for (final point in points)
            {
              'latitude': point.latitude,
              'longitude': point.longitude,
              'elevationMeters': point.elevation,
            },
        ]),
      ),
    );
    await database
        .into(database.savedRoutes)
        .insert(
          SavedRoutesCompanion.insert(
            id: routeId,
            name: name.trim().isEmpty ? 'Rute GPX impor' : name.trim(),
            source: 'GPX lokal',
            description: Value(description.trim()),
            updatedAt: DateTime.now().toUtc(),
            distanceMeters: Value(distanceMeters),
            elevationGainMeters: Value(elevationGainMeters),
            availability: const Value('offline'),
            encryptedGeometry: Value(encryptedGeometry),
          ),
        );
    final row = await (database.select(
      database.savedRoutes,
    )..where((route) => route.id.equals(routeId))).getSingle();
    return _map(row);
  }

  Future<RouteRecord> _map(SavedRoute row) async => RouteRecord(
    id: row.id,
    name: row.name,
    source: row.source,
    updatedAt: row.updatedAt,
    availability: row.availability,
    description: row.description,
    distanceMeters: row.distanceMeters,
    elevationGainMeters: row.elevationGainMeters,
    poiSummary: row.poiSummary,
    points: row.encryptedGeometry == null
        ? const []
        : await _decodeGeometry(row.encryptedGeometry!),
  );

  Future<List<RoutePoint>> _decodeGeometry(Uint8List encrypted) async {
    final decoded = jsonDecode(
      utf8.decode(await geometryCodec.decryptBytes(encrypted)),
    );
    if (decoded is! List || decoded.length < 2) {
      throw const FormatException('Geometri rute tersimpan tidak valid.');
    }
    return [
      for (final item in decoded)
        if (item is Map)
          _decodePoint(Map<String, Object?>.from(item))
        else
          throw const FormatException('Titik rute tersimpan tidak valid.'),
    ];
  }

  RoutePoint _decodePoint(Map<String, Object?> json) {
    final latitude = (json['latitude'] as num?)?.toDouble();
    final longitude = (json['longitude'] as num?)?.toDouble();
    final elevation = (json['elevationMeters'] as num?)?.toDouble();
    if (latitude == null ||
        longitude == null ||
        elevation == null ||
        !latitude.isFinite ||
        latitude < -90 ||
        latitude > 90 ||
        !longitude.isFinite ||
        longitude < -180 ||
        longitude > 180 ||
        !elevation.isFinite) {
      throw const FormatException('Titik rute tersimpan tidak valid.');
    }
    return RoutePoint(
      latitude: latitude,
      longitude: longitude,
      elevationMeters: elevation,
    );
  }
}
