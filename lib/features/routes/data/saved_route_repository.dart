import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:geolocator/geolocator.dart';

import '../../../core/storage/app_database.dart';
import '../../session/data/encrypted_telemetry_codec.dart';
import '../domain/saved_route.dart';

class SavedRouteRepository {
  /// Membuat repositori dengan [database] dan kodek geometri terenkripsi.
  const SavedRouteRepository(this.database, {required this.geometryCodec});

  final AppDatabase database;
  final EncryptedTelemetryCodec geometryCodec;

  static const _selectedSessionRouteKey = 'selected_session_route_id';

  /// Memuat rute impor yang terakhir dipilih untuk sesi, bila ada.
  Future<RouteRecord?> loadSelectedSessionRoute() async {
    final preference =
        await (database.select(database.appPreferences)
              ..where((item) => item.key.equals(_selectedSessionRouteKey)))
            .getSingleOrNull();
    final routeId = preference?.value;
    if (routeId == null || routeId.isEmpty) return null;
    final row =
        await (database.select(database.savedRoutes)..where(
              (route) =>
                  route.id.equals(routeId) & route.source.equals('GPX lokal'),
            ))
            .getSingleOrNull();
    return row == null ? null : _map(row);
  }

  /// Menyimpan atau menghapus rute sesi yang dipilih berdasarkan [routeId].
  Future<void> saveSelectedSessionRoute(String? routeId) async {
    await database
        .into(database.appPreferences)
        .insertOnConflictUpdate(
          AppPreferencesCompanion.insert(
            key: _selectedSessionRouteKey,
            value: routeId ?? '',
          ),
        );
  }

  /// Mencari rute tersimpan berdasarkan nama dan mengurutkan yang terbaru.
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

  /// Memvalidasi, menghitung metrik, dan menyimpan rute GPX hasil impor.
  Future<RouteRecord> saveImportedRoute({
    required String name,
    String description = '',
    required List<({double latitude, double longitude, double elevation})>
    points,
    List<RouteCheckpoint> checkpoints = const [],
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
        jsonEncode({
          'track': [
            for (final point in points)
              {
                'latitude': point.latitude,
                'longitude': point.longitude,
                'elevationMeters': point.elevation,
              },
          ],
          'checkpoints': [
            for (final checkpoint in checkpoints)
              {
                'name': checkpoint.name,
                'latitude': checkpoint.latitude,
                'longitude': checkpoint.longitude,
              },
          ],
        }),
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

  /// Menghapus rute impor [routeId], gagal bila bukan rute impor.
  Future<void> deleteImportedRoute(String routeId) async {
    final deleted =
        await (database.delete(database.savedRoutes)..where(
              (route) =>
                  route.id.equals(routeId) & route.source.equals('GPX lokal'),
            ))
            .go();
    if (deleted == 0) {
      throw StateError('Rute GPX tidak ditemukan atau bukan rute impor.');
    }
  }

  /// Memetakan baris basis data menjadi [RouteRecord] dengan geometri terurai.
  Future<RouteRecord> _map(SavedRoute row) async {
    final geometry = row.encryptedGeometry == null
        ? (points: const <RoutePoint>[], checkpoints: const <RouteCheckpoint>[])
        : await _decodeGeometry(row.encryptedGeometry!);
    return RouteRecord(
      id: row.id,
      name: row.name,
      source: row.source,
      updatedAt: row.updatedAt,
      availability: row.availability,
      description: row.description,
      distanceMeters: row.distanceMeters,
      elevationGainMeters: row.elevationGainMeters,
      poiSummary: row.poiSummary,
      points: geometry.points,
      checkpoints: geometry.checkpoints,
    );
  }

  /// Mendekripsi dan mengurai geometri rute beserta checkpoint-nya.
  Future<({List<RoutePoint> points, List<RouteCheckpoint> checkpoints})>
  _decodeGeometry(Uint8List encrypted) async {
    final decoded = jsonDecode(
      utf8.decode(await geometryCodec.decryptBytes(encrypted)),
    );
    final rawPoints = decoded is List
        ? decoded
        : decoded is Map
        ? decoded['track']
        : null;
    final rawCheckpoints = decoded is Map ? decoded['checkpoints'] : const [];
    if (rawPoints is! List || rawPoints.length < 2) {
      throw const FormatException('Geometri rute tersimpan tidak valid.');
    }
    final points = [
      for (final item in rawPoints)
        if (item is Map)
          _decodePoint(Map<String, Object?>.from(item))
        else
          throw const FormatException('Titik rute tersimpan tidak valid.'),
    ];
    if (rawCheckpoints is! List) {
      throw const FormatException('Checkpoint rute tersimpan tidak valid.');
    }
    final checkpoints = [
      for (final item in rawCheckpoints)
        if (item is Map)
          _decodeCheckpoint(Map<String, Object?>.from(item))
        else
          throw const FormatException('Checkpoint rute tersimpan tidak valid.'),
    ];
    return (points: points, checkpoints: checkpoints);
  }

  /// Memvalidasi dan membangun [RouteCheckpoint] dari JSON tersimpan.
  RouteCheckpoint _decodeCheckpoint(Map<String, Object?> json) {
    final name = json['name'];
    final latitude = (json['latitude'] as num?)?.toDouble();
    final longitude = (json['longitude'] as num?)?.toDouble();
    if (name is! String ||
        name.trim().isEmpty ||
        latitude == null ||
        longitude == null ||
        !latitude.isFinite ||
        latitude < -90 ||
        latitude > 90 ||
        !longitude.isFinite ||
        longitude < -180 ||
        longitude > 180) {
      throw const FormatException('Checkpoint rute tersimpan tidak valid.');
    }
    return RouteCheckpoint(
      name: name,
      latitude: latitude,
      longitude: longitude,
    );
  }

  /// Memvalidasi dan membangun [RoutePoint] dari JSON tersimpan.
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
