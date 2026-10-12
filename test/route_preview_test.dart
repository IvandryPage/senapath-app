import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:senapath/core/storage/app_database.dart';
import 'package:senapath/core/storage/secure_vault.dart';
import 'package:senapath/core/units/unit_settings_cubit.dart';
import 'package:senapath/core/units/unit_settings_repository.dart';
import 'package:senapath/core/units/unit_system.dart';
import 'package:senapath/app/theme/app_theme.dart';
import 'package:senapath/features/routes/data/route_file_exchange.dart';
import 'package:senapath/features/routes/data/saved_route_repository.dart';
import 'package:senapath/features/routes/presentation/routes_cubit.dart';
import 'package:senapath/features/routes/presentation/routes_screen.dart';
import 'package:senapath/features/session/data/encrypted_telemetry_codec.dart';
import 'package:senapath/features/session/data/readiness_checker.dart';
import 'package:senapath/features/session/data/ride_session_repository.dart';
import 'package:senapath/features/session/data/session_file_service.dart';
import 'package:senapath/features/session/domain/ride_session.dart';
import 'package:senapath/features/session/presentation/session_cubit.dart';
import 'package:senapath/features/session/presentation/session_screen.dart';

void main() {
  testWidgets('starts with the selected GPX without another route page', (
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
      ],
    );
    final routesCubit = RoutesCubit(
      repository,
      const RouteFileExchange(SessionFileService()),
    );
    await routesCubit.load();
    routesCubit.selectSessionRoute(routesCubit.state.routes.single);
    final unitCubit = UnitSettingsCubit(UnitSettingsRepository(database));
    final sessionCubit = RideSessionCubit(
      repository: DriftRideSessionRepository(
        database: database,
        telemetryCodec: EncryptedTelemetryCodec(
          secureVault: _MemorySecureVault(),
        ),
      ),
      readinessChecker: const _TestReadinessChecker(
        locationPermissionGranted: true,
      ),
      locationSource: _EmptyLocationSource(),
    );
    await unitCubit.load();
    addTearDown(routesCubit.close);
    addTearDown(unitCubit.close);
    addTearDown(sessionCubit.close);
    addTearDown(database.close);

    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider.value(value: routesCubit),
          BlocProvider.value(value: unitCubit),
          BlocProvider.value(value: sessionCubit),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(
            body: SessionScreen(
              showMap: false,
              showHistory: false,
              showSummary: false,
              compactControls: true,
              initialPanelSize: 0.92,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Mulai sesi'));
    await tester.pumpAndSettle();
    expect(find.text('Pakai rute untuk sesi ini?'), findsNothing);
    expect(routesCubit.state.sessionRoute?.name, 'Loop Utara');
    expect(sessionCubit.state.session?.status, RideSessionStatus.recording);
    await tester.ensureVisible(find.text('Performa sesi'));
    expect(find.text('Performa sesi'), findsOneWidget);
    await sessionCubit.pause();
  });

  testWidgets('searches saved GPX routes by name', (tester) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    final repository = SavedRouteRepository(
      database,
      geometryCodec: EncryptedTelemetryCodec(secureVault: _MemorySecureVault()),
    );
    for (final name in ['Loop Utara', 'Loop Selatan']) {
      await repository.saveImportedRoute(
        name: name,
        points: const [
          (latitude: -6.2, longitude: 106.8, elevation: 10),
          (latitude: -6.202, longitude: 106.804, elevation: 24),
        ],
      );
    }
    final routesCubit = RoutesCubit(
      repository,
      const RouteFileExchange(SessionFileService()),
    );
    final unitCubit = UnitSettingsCubit(UnitSettingsRepository(database));
    final sessionCubit = _createSessionCubit(database);
    await routesCubit.load();
    await unitCubit.load();
    addTearDown(routesCubit.close);
    addTearDown(unitCubit.close);
    addTearDown(sessionCubit.close);
    addTearDown(database.close);

    await tester.pumpWidget(
      BlocProvider.value(
        value: sessionCubit,
        child: BlocProvider.value(
          value: routesCubit,
          child: BlocProvider.value(
            value: unitCubit,
            child: const MaterialApp(home: Scaffold(body: SavedRoutesScreen())),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('gpx-route-search')),
      'Utara',
    );
    await tester.pumpAndSettle();

    expect(find.text('Loop Utara'), findsOneWidget);
    expect(find.text('Loop Selatan'), findsNothing);
  });

  testWidgets('shows live speed and distance above the session button', (
    tester,
  ) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    final telemetryCodec = EncryptedTelemetryCodec(
      secureVault: _MemorySecureVault(),
    );
    final routeRepository = SavedRouteRepository(
      database,
      geometryCodec: telemetryCodec,
    );
    final routesCubit = RoutesCubit(
      routeRepository,
      const RouteFileExchange(SessionFileService()),
    );
    final unitCubit = UnitSettingsCubit(UnitSettingsRepository(database));
    final sessionCubit = RideSessionCubit(
      repository: DriftRideSessionRepository(
        database: database,
        telemetryCodec: telemetryCodec,
      ),
      readinessChecker: const _TestReadinessChecker(
        locationPermissionGranted: true,
      ),
      locationSource: _EmptyLocationSource(),
    );
    await unitCubit.load();
    await sessionCubit.initialize();
    await sessionCubit.start();
    expect(sessionCubit.state.session?.status, RideSessionStatus.recording);
    addTearDown(routesCubit.close);
    addTearDown(unitCubit.close);
    addTearDown(sessionCubit.close);
    addTearDown(database.close);

    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider.value(value: routesCubit),
          BlocProvider.value(value: unitCubit),
          BlocProvider.value(value: sessionCubit),
        ],
        child: const MaterialApp(home: Scaffold(body: RoutesScreen())),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('0.0 km/j'), findsOneWidget);
    expect(find.text('Jarak  0.00 km'), findsOneWidget);
    expect(find.byTooltip('Detail sesi'), findsOneWidget);
    await sessionCubit.pause();
  });

  testWidgets('shows a play action and starts a session when idle', (
    tester,
  ) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    final routesCubit = RoutesCubit(
      SavedRouteRepository(
        database,
        geometryCodec: EncryptedTelemetryCodec(
          secureVault: _MemorySecureVault(),
        ),
      ),
      const RouteFileExchange(SessionFileService()),
    );
    final unitCubit = UnitSettingsCubit(UnitSettingsRepository(database));
    final sessionCubit = _createSessionCubit(
      database,
      locationPermissionGranted: true,
    );
    await unitCubit.load();
    addTearDown(routesCubit.close);
    addTearDown(unitCubit.close);
    addTearDown(sessionCubit.close);
    addTearDown(database.close);

    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider.value(value: routesCubit),
          BlocProvider.value(value: unitCubit),
          BlocProvider.value(value: sessionCubit),
        ],
        child: const MaterialApp(home: Scaffold(body: RoutesScreen())),
      ),
    );
    await tester.pumpAndSettle();

    final startButton = find.byKey(const Key('start-session-button'));
    expect(startButton, findsOneWidget);
    expect(find.byIcon(Icons.play_arrow), findsOneWidget);
    expect(find.byTooltip('Detail sesi'), findsNothing);
    await tester.tap(startButton);
    await tester.pumpAndSettle();

    expect(sessionCubit.state.session?.status, RideSessionStatus.recording);
    expect(find.byTooltip('Detail sesi'), findsOneWidget);
    await sessionCubit.pause();
  });

  testWidgets('selects an imported route from the saved route library', (
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
    final sessionCubit = _createSessionCubit(database);
    await unitCubit.load();
    addTearDown(cubit.close);
    addTearDown(unitCubit.close);
    addTearDown(sessionCubit.close);
    addTearDown(database.close);

    await tester.pumpWidget(
      BlocProvider.value(
        value: sessionCubit,
        child: BlocProvider.value(
          value: cubit,
          child: BlocProvider.value(
            value: unitCubit,
            child: const MaterialApp(home: Scaffold(body: SavedRoutesScreen())),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Loop Utara'), findsOneWidget);
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
    expect(find.byType(RichAttributionWidget), findsOneWidget);
    expect(find.text('Tampilkan di Jelajah'), findsOneWidget);
    await tester.tap(find.text('Tampilkan di Jelajah'));
    await tester.pumpAndSettle();
    expect(cubit.state.sessionRoute?.name, 'Loop Utara');
    expect(find.text('Jejak GPX lokal'), findsNothing);
  });

  testWidgets('selects, changes, and removes a GPX route on the explore map', (
    tester,
  ) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    final repository = SavedRouteRepository(
      database,
      geometryCodec: EncryptedTelemetryCodec(secureVault: _MemorySecureVault()),
    );
    for (final name in ['Loop Utara', 'Loop Selatan']) {
      await repository.saveImportedRoute(
        name: name,
        points: const [
          (latitude: -6.2, longitude: 106.8, elevation: 10),
          (latitude: -6.202, longitude: 106.804, elevation: 24),
        ],
      );
    }
    final routesCubit = RoutesCubit(
      repository,
      const RouteFileExchange(SessionFileService()),
    );
    final unitCubit = UnitSettingsCubit(UnitSettingsRepository(database));
    final sessionCubit = _createSessionCubit(database);
    await unitCubit.load();
    addTearDown(routesCubit.close);
    addTearDown(unitCubit.close);
    addTearDown(sessionCubit.close);
    addTearDown(database.close);

    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider.value(value: routesCubit),
          BlocProvider.value(value: unitCubit),
          BlocProvider.value(value: sessionCubit),
        ],
        child: const MaterialApp(home: Scaffold(body: RoutesScreen())),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Cari rute GPX'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Loop Utara'));
    await tester.pumpAndSettle();

    expect(find.text('Loop Utara'), findsOneWidget);
    expect(find.byTooltip('Ganti GPX'), findsOneWidget);
    expect(find.byTooltip('Hapus GPX dari peta'), findsOneWidget);
    expect(routesCubit.state.sessionRoute?.name, 'Loop Utara');
    expect(find.byType(PolylineLayer), findsOneWidget);

    await tester.tap(find.byTooltip('Ganti GPX'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Loop Selatan'));
    await tester.pumpAndSettle();
    expect(routesCubit.state.sessionRoute?.name, 'Loop Selatan');
    expect(find.text('Loop Selatan'), findsOneWidget);

    await tester.tap(find.byTooltip('Hapus GPX dari peta'));
    await tester.pumpAndSettle();
    expect(routesCubit.state.sessionRoute, isNull);
    expect(find.text('Cari rute GPX'), findsOneWidget);
    expect(find.byType(PolylineLayer), findsNothing);
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
    final sessionCubit = _createSessionCubit(database);
    await routeCubit.load();
    await unitCubit.load();
    await unitCubit.select(UnitSystem.imperial);
    addTearDown(routeCubit.close);
    addTearDown(unitCubit.close);
    addTearDown(sessionCubit.close);
    addTearDown(database.close);

    await tester.pumpWidget(
      BlocProvider.value(
        value: sessionCubit,
        child: BlocProvider.value(
          value: routeCubit,
          child: BlocProvider.value(
            value: unitCubit,
            child: const MaterialApp(home: Scaffold(body: SavedRoutesScreen())),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('mi'), findsOneWidget);
    expect(find.textContaining('ft'), findsOneWidget);
  });

  testWidgets('deletes an imported GPX route after confirmation', (
    tester,
  ) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    final repository = SavedRouteRepository(
      database,
      geometryCodec: EncryptedTelemetryCodec(secureVault: _MemorySecureVault()),
    );
    await repository.saveImportedRoute(
      name: 'Loop untuk dihapus',
      points: const [
        (latitude: -7.79, longitude: 110.36, elevation: 10),
        (latitude: -7.792, longitude: 110.362, elevation: 18),
      ],
    );
    final routesCubit = RoutesCubit(
      repository,
      const RouteFileExchange(SessionFileService()),
    );
    final unitCubit = UnitSettingsCubit(UnitSettingsRepository(database));
    final sessionCubit = _createSessionCubit(database);
    await routesCubit.load();
    await unitCubit.load();
    addTearDown(routesCubit.close);
    addTearDown(unitCubit.close);
    addTearDown(sessionCubit.close);
    addTearDown(database.close);

    await tester.pumpWidget(
      BlocProvider.value(
        value: sessionCubit,
        child: BlocProvider.value(
          value: routesCubit,
          child: BlocProvider.value(
            value: unitCubit,
            child: const MaterialApp(home: Scaffold(body: SavedRoutesScreen())),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Hapus rute GPX Loop untuk dihapus'));
    await tester.pumpAndSettle();
    expect(find.text('Hapus rute GPX?'), findsOneWidget);
    await tester.tap(find.text('Hapus rute'));
    await tester.pumpAndSettle();

    expect(find.text('Loop untuk dihapus'), findsNothing);
    expect(find.textContaining('Belum ada rute GPX.'), findsOneWidget);
    expect(await repository.search(''), isEmpty);
  });

  testWidgets('session details show route, metrics, and charts', (
    tester,
  ) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    final repository = DriftRideSessionRepository(
      database: database,
      telemetryCodec: EncryptedTelemetryCodec(
        secureVault: _MemorySecureVault(),
      ),
    );
    final startedAt = DateTime.utc(2026, 9, 30, 12);
    final session = await repository.start(startedAt);
    for (var index = 0; index < 5; index++) {
      await repository.recordLocation(
        sessionId: session.id,
        location: TelemetryLocation(
          recordedAt: startedAt.add(Duration(seconds: index * 10)),
          latitude: -6.2,
          longitude: 106.8 + index * 0.0001,
          accuracyMeters: 5,
          altitudeMeters: 20 + index.toDouble(),
          altitudeAccuracyMeters: 5,
          barometricPressureHpa: 1013.25 - index * 0.1,
          speedMetersPerSecond: 3 + index.toDouble(),
        ),
        addedDistanceMeters: 12,
      );
    }
    await repository.finish(
      session.id,
      startedAt.add(const Duration(minutes: 1)),
    );
    final sessionCubit = RideSessionCubit(
      repository: repository,
      readinessChecker: const _TestReadinessChecker(),
      locationSource: _EmptyLocationSource(),
    );
    final unitCubit = UnitSettingsCubit(UnitSettingsRepository(database));
    await unitCubit.load();
    addTearDown(sessionCubit.close);
    addTearDown(unitCubit.close);
    addTearDown(database.close);

    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider.value(value: sessionCubit),
          BlocProvider.value(value: unitCubit),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: SessionScreen(
              showMap: false,
              historyOnly: true,
              summarySessionId: session.id,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(sessionCubit.state.summaryLocations, hasLength(5));
    expect(find.text('Metrik utama'), findsOneWidget);
    expect(find.text('Grafik kecepatan (km/j)'), findsOneWidget);
    expect(find.text('Profil elevasi'), findsOneWidget);
    expect(find.text('5 titik GPS pada jejak sesi'), findsOneWidget);
  });
}

RideSessionCubit _createSessionCubit(
  AppDatabase database, {
  bool locationPermissionGranted = false,
}) => RideSessionCubit(
  repository: DriftRideSessionRepository(
    database: database,
    telemetryCodec: EncryptedTelemetryCodec(secureVault: _MemorySecureVault()),
  ),
  readinessChecker: _TestReadinessChecker(
    locationPermissionGranted: locationPermissionGranted,
  ),
  locationSource: _EmptyLocationSource(),
);

class _TestReadinessChecker implements ReadinessChecker {
  const _TestReadinessChecker({this.locationPermissionGranted = false});

  final bool locationPermissionGranted;

  @override
  Future<ReadinessReport> check({
    bool requestLocationPermission = false,
    bool requestNotificationPermission = false,
    bool checkGpsFix = false,
  }) async => ReadinessReport(
    locationPermissionGranted: locationPermissionGranted,
    backgroundLocationGranted: false,
    locationPermanentlyDenied: false,
    locationServicesEnabled: true,
    gpsFixAvailable: false,
    accelerometerAvailable: false,
    gyroscopeAvailable: false,
    notificationsGranted: false,
    notificationsPermanentlyDenied: false,
  );

  @override
  Future<bool> openLocationSettings() async => false;

  @override
  Future<bool> openLocationServiceSettings() async => false;

  @override
  Future<bool> openNotificationSettings() async => false;
}

class _EmptyLocationSource implements LocationSource {
  @override
  Stream<Position> get positions => const Stream.empty();
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
