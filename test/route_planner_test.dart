import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:senapath/core/storage/app_database.dart';
import 'package:senapath/core/storage/secure_vault.dart';
import 'package:senapath/features/routes/data/route_file_exchange.dart';
import 'package:senapath/features/routes/data/route_planner_gateway.dart';
import 'package:senapath/features/routes/data/saved_route_repository.dart';
import 'package:senapath/features/routes/domain/saved_route.dart';
import 'package:senapath/features/routes/presentation/routes_cubit.dart';
import 'package:senapath/features/session/data/encrypted_telemetry_codec.dart';
import 'package:senapath/features/session/data/session_file_service.dart';

void main() {
  test('cycling route is shown on the map without being stored as GPX', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    final repository = SavedRouteRepository(
      database,
      geometryCodec: EncryptedTelemetryCodec(secureVault: _MemorySecureVault()),
    );
    final planner = _FakeRoutePlanner();
    final cubit = RoutesCubit(
      repository,
      const RouteFileExchange(SessionFileService()),
      routePlanner: planner,
    );
    addTearDown(cubit.close);
    addTearDown(database.close);

    await cubit.planCyclingRoute(
      originLatitude: -7.7956,
      originLongitude: 110.3695,
      destination: 'Malioboro, Yogyakarta',
    );

    expect(planner.destination, 'Malioboro, Yogyakarta');
    expect(cubit.state.plannedRoute?.source, 'Google Maps · bersepeda');
    expect(cubit.state.plannedRoute?.points, hasLength(2));
    expect(await repository.search(''), isEmpty);
    expect(cubit.state.message, contains('siap ditampilkan'));
  });

  test('shows provider configuration failure instead of a straight-line route',
      () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    final repository = SavedRouteRepository(
      database,
      geometryCodec: EncryptedTelemetryCodec(secureVault: _MemorySecureVault()),
    );
    final cubit = RoutesCubit(
      repository,
      const RouteFileExchange(SessionFileService()),
      routePlanner: _FakeRoutePlanner()..configured = false,
    );
    addTearDown(cubit.close);
    addTearDown(database.close);

    await cubit.planCyclingRoute(
      originLatitude: -7.7956,
      originLongitude: 110.3695,
      destination: 'Malioboro',
    );

    expect(cubit.state.plannedRoute, isNull);
    expect(cubit.state.message, contains('belum dikonfigurasi'));
  });
}

class _FakeRoutePlanner implements RoutePlannerGateway {
  bool configured = true;
  String? destination;

  @override
  bool get isConfigured => configured;

  @override
  Future<RouteRecord> planCyclingRoute({
    required double originLatitude,
    required double originLongitude,
    required String destination,
  }) async {
    this.destination = destination;
    return RouteRecord(
      id: 'google-test',
      name: destination,
      source: 'Google Maps · bersepeda',
      updatedAt: DateTime.utc(2026, 10, 5),
      availability: 'online',
      distanceMeters: 1200,
      points: const [
        RoutePoint(
          latitude: -7.7956,
          longitude: 110.3695,
          elevationMeters: 0,
        ),
        RoutePoint(
          latitude: -7.8,
          longitude: 110.37,
          elevationMeters: 0,
        ),
      ],
    );
  }
}

class _MemorySecureVault implements SecureVault {
  final Map<String, String> _values = {};

  @override
  Future<void> delete(String key) async => _values.remove(key);

  @override
  Future<String?> read(String key) async => _values[key];

  @override
  Future<void> write(String key, String value) async {
    _values[key] = value;
  }
}
