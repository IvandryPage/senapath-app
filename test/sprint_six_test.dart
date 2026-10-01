import 'package:drift/native.dart';
import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:senapath/core/storage/app_database.dart';
import 'package:senapath/core/storage/secure_vault.dart';
import 'package:senapath/features/session/data/encrypted_telemetry_codec.dart';
import 'package:senapath/features/routes/data/saved_route_repository.dart';

void main() {
  late AppDatabase database;
  late SavedRouteRepository repository;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    repository = SavedRouteRepository(
      database,
      geometryCodec: EncryptedTelemetryCodec(secureVault: _MemorySecureVault()),
    );
  });

  tearDown(() async {
    await database.close();
  });

  test('search returns saved offline route metadata', () async {
    await database
        .into(database.savedRoutes)
        .insert(
          SavedRoutesCompanion.insert(
            id: 'route-1',
            name: 'Bukit Sentul',
            source: 'GPX lokal',
            updatedAt: DateTime.utc(2026, 10, 1),
            distanceMeters: const Value(24500),
            elevationGainMeters: const Value(680),
            poiSummary: const Value('Pos nutrisi, pos medis'),
          ),
        );

    final routes = await repository.search('sentul');

    expect(routes, hasLength(1));
    expect(routes.single.name, 'Bukit Sentul');
    expect(routes.single.availability, 'offline');
    expect(routes.single.poiSummary, contains('pos medis'));
  });

  test('empty search remains an honest empty state', () async {
    expect(await repository.search(''), isEmpty);
    expect(await repository.search('unknown'), isEmpty);
  });

  test('imported route is persisted with offline metadata', () async {
    final route = await repository.saveImportedRoute(
      name: 'Rute Latihan',
      points: const [
        (latitude: -6.2, longitude: 106.8, elevation: 10),
        (latitude: -6.201, longitude: 106.801, elevation: 18),
      ],
    );

    expect(route.availability, 'offline');
    expect(route.source, 'GPX lokal');
    expect(route.distanceMeters, greaterThan(0));
    expect(route.elevationGainMeters, 8);
    final restored = (await repository.search('Latihan')).single;
    expect(restored.id, route.id);
    expect(restored.points, hasLength(2));
    expect(restored.points.first.latitude, -6.2);
    expect(restored.points.last.longitude, 106.801);
  });
}

class _MemorySecureVault implements SecureVault {
  final values = <String, String>{};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;

  @override
  Future<void> delete(String key) async => values.remove(key);
}
