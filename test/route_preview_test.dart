import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:senapath/core/storage/app_database.dart';
import 'package:senapath/core/storage/secure_vault.dart';
import 'package:senapath/core/units/unit_settings_cubit.dart';
import 'package:senapath/core/units/unit_settings_repository.dart';
import 'package:senapath/core/units/unit_system.dart';
import 'package:senapath/features/routes/data/route_file_exchange.dart';
import 'package:senapath/features/routes/data/saved_route_repository.dart';
import 'package:senapath/features/routes/presentation/explore_map.dart';
import 'package:senapath/features/routes/presentation/routes_cubit.dart';
import 'package:senapath/features/routes/presentation/routes_screen.dart';
import 'package:senapath/features/session/data/encrypted_telemetry_codec.dart';
import 'package:senapath/features/session/data/session_file_service.dart';

void main() {
  testWidgets('opens an imported route over an OpenStreetMap basemap', (
    tester,
  ) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    final repository = SavedRouteRepository(
      database,
      geometryCodec: EncryptedTelemetryCodec(secureVault: _MemorySecureVault()),
    );
    await repository.saveImportedRoute(
      name: 'Loop Utara',
      points: const [
        (latitude: -6.2, longitude: 106.8, elevation: 10),
        (latitude: -6.202, longitude: 106.804, elevation: 24),
        (latitude: -6.205, longitude: 106.801, elevation: 18),
      ],
    );
    final cubit = RoutesCubit(
      repository,
      const RouteFileExchange(SessionFileService()),
    );
    await cubit.load();
    final unitCubit = UnitSettingsCubit(UnitSettingsRepository(database));
    await unitCubit.load();
    addTearDown(cubit.close);
    addTearDown(unitCubit.close);
    addTearDown(database.close);

    await tester.pumpWidget(
      BlocProvider.value(
        value: cubit,
        child: BlocProvider.value(
          value: unitCubit,
          child: const MaterialApp(home: Scaffold(body: RoutesScreen())),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(ExploreMap), findsOneWidget);
    await tester.ensureVisible(find.text('Loop Utara'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Loop Utara'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Jejak GPX lokal'), findsOneWidget);
    expect(
      find.bySemanticsLabel(
        'Peta OpenStreetMap dengan jejak GPX lokal 3 titik',
      ),
      findsOneWidget,
    );
    expect(find.byType(RichAttributionWidget), findsNWidgets(2));
    expect(find.text('Ikuti rute'), findsOneWidget);
  });

  testWidgets('route distance and elevation respect imperial units', (
    tester,
  ) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    final repository = SavedRouteRepository(
      database,
      geometryCodec: EncryptedTelemetryCodec(secureVault: _MemorySecureVault()),
    );
    await repository.saveImportedRoute(
      name: 'Imperial route',
      points: const [
        (latitude: -6.2, longitude: 106.8, elevation: 10),
        (latitude: -6.22, longitude: 106.82, elevation: 24),
      ],
    );
    final routeCubit = RoutesCubit(
      repository,
      const RouteFileExchange(SessionFileService()),
    );
    final unitCubit = UnitSettingsCubit(UnitSettingsRepository(database));
    await routeCubit.load();
    await unitCubit.load();
    await unitCubit.select(UnitSystem.imperial);
    addTearDown(routeCubit.close);
    addTearDown(unitCubit.close);
    addTearDown(database.close);

    await tester.pumpWidget(
      BlocProvider.value(
        value: routeCubit,
        child: BlocProvider.value(
          value: unitCubit,
          child: const MaterialApp(home: Scaffold(body: RoutesScreen())),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('mi'), findsOneWidget);
    expect(find.textContaining('ft'), findsOneWidget);
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
