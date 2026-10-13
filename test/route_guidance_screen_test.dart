import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:senapath/core/storage/app_database.dart';
import 'package:senapath/core/units/unit_settings_cubit.dart';
import 'package:senapath/core/units/unit_settings_repository.dart';
import 'package:senapath/features/routes/data/route_wind_service.dart';
import 'package:senapath/features/routes/data/ghost_pacer_service.dart';
import 'package:senapath/features/routes/domain/route_wind.dart';
import 'package:senapath/features/routes/domain/saved_route.dart';
import 'package:senapath/features/routes/presentation/route_guidance_cubit.dart';
import 'package:senapath/features/routes/presentation/route_guidance_screen.dart';
import 'package:senapath/features/routes/presentation/routes_screen.dart';
import 'package:senapath/features/session/domain/ride_session.dart';

void main() {
  testWidgets(
    'keeps the GPX route visible when location permission is denied',
    (tester) async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      final unitCubit = UnitSettingsCubit(UnitSettingsRepository(database));
      await unitCubit.load();
      addTearDown(unitCubit.close);
      addTearDown(database.close);

      await tester.pumpWidget(
        BlocProvider.value(
          value: unitCubit,
          child: MaterialApp(
            home: Scaffold(
              body: RouteGuidanceScreen(
                route: _route(),
                positionSource: _DeniedPositionSource(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(RouteMapPreview), findsOneWidget);
      expect(
        tester.getSize(find.byType(RouteMapPreview)).height,
        greaterThan(220),
      );
      expect(find.textContaining('Izin lokasi'), findsWidgets);
      expect(
        find.textContaining('tanpa petunjuk belokan atau peta jalan'),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel('Peta rute dengan 2 titik'), findsOneWidget);
    },
  );

  testWidgets('requests wind only after disclosing GPS sharing', (
    tester,
  ) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    final unitCubit = UnitSettingsCubit(UnitSettingsRepository(database));
    final windService = _FakeRouteWindService();
    await unitCubit.load();
    addTearDown(unitCubit.close);
    addTearDown(database.close);

    await tester.pumpWidget(
      BlocProvider.value(
        value: unitCubit,
        child: MaterialApp(
          home: Scaffold(
            body: RouteGuidanceScreen(
              route: _route(),
              positionSource: _GrantedPositionSource(),
              windService: windService,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final windButton = find.byTooltip(
      'Ketuk untuk mengambil arah angin di lokasi saat ini.',
    );
    expect(windButton, findsOneWidget);
    await tester.tap(windButton);
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Koordinat GPS saat ini akan dikirim ke Open-Meteo untuk '
        'mengambil arah angin lokal. Aplikasi hanya menampilkan panah relatif '
        'terhadap arah rute dan tidak menampilkan kecepatan angin.',
      ),
      findsOneWidget,
    );
    expect(windService.requestCount, 0);

    await tester.tap(find.text('Izinkan sekali untuk panduan ini'));
    await tester.pumpAndSettle();

    expect(windService.requestCount, 1);
    expect(windService.lastLatitude, -6.2);
    expect(windService.lastLongitude, 106.8);
    expect(find.byIcon(Icons.navigation_outlined), findsAtLeastNWidgets(1));
    expect(
      find.byTooltip('angin dari depan relatif arah rute'),
      findsOneWidget,
    );
    expect(find.textContaining('m/s'), findsNothing);
  });

  testWidgets('shows one small ghost arrow for a matching completed ride', (
    tester,
  ) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    final unitCubit = UnitSettingsCubit(UnitSettingsRepository(database));
    await unitCubit.load();
    addTearDown(unitCubit.close);
    addTearDown(database.close);

    await tester.pumpWidget(
      BlocProvider.value(
        value: unitCubit,
        child: MaterialApp(
          home: Scaffold(
            body: RouteGuidanceScreen(
              route: _route(),
              positionSource: _GrantedPositionSource(),
              ghostPacerService: GhostPacerService(
                history: _MatchingGhostPacerHistory(_route()),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final ghost = find.byTooltip('Hantu dari sesi terbaik sebelumnya');
    expect(ghost, findsOneWidget);
    final ghostArrow = find.descendant(
      of: ghost,
      matching: find.byIcon(Icons.navigation),
    );
    expect(tester.widget<Icon>(ghostArrow).size, 18);
    expect(
      tester.widget<Icon>(ghostArrow).color!.a,
      lessThan(Theme.of(tester.element(ghostArrow)).colorScheme.primary.a),
    );
  });
}

RouteRecord _route() => RouteRecord(
  id: 'route-screen-test',
  name: 'Loop Selatan',
  source: 'GPX lokal',
  updatedAt: DateTime.utc(2026),
  availability: 'offline',
  points: const [
    RoutePoint(latitude: -6.2, longitude: 106.8, elevationMeters: 12),
    RoutePoint(latitude: -6.203, longitude: 106.803, elevationMeters: 35),
  ],
);

class _DeniedPositionSource implements RoutePositionSource {
  @override
  Future<bool> requestPermission() async => false;

  @override
  Stream<RoutePosition> watch() => const Stream.empty();
}

class _GrantedPositionSource implements RoutePositionSource {
  @override
  Future<bool> requestPermission() async => true;

  @override
  Stream<RoutePosition> watch() => Stream.value(
    const RoutePosition(latitude: -6.2, longitude: 106.8, accuracyMeters: 5),
  );
}

class _FakeRouteWindService implements RouteWindService {
  int requestCount = 0;
  double? lastLatitude;
  double? lastLongitude;

  @override
  Future<RouteWindObservation> fetchCurrentWind({
    required double latitude,
    required double longitude,
  }) async {
    requestCount++;
    lastLatitude = latitude;
    lastLongitude = longitude;
    return RouteWindObservation(
      directionFromDegrees: 135,
      observedAt: DateTime.utc(2026, 10, 13),
    );
  }
}

class _MatchingGhostPacerHistory implements GhostPacerHistory {
  _MatchingGhostPacerHistory(this.route);

  final RouteRecord route;

  @override
  Future<List<RideSessionSnapshot>> loadCompletedSessions() async {
    final startedAt = DateTime.utc(2026);
    return [
      RideSessionSnapshot(
        id: 'previous-match',
        startedAt: startedAt,
        endedAt: startedAt.add(const Duration(minutes: 30)),
        status: RideSessionStatus.completed,
        totalPausedMilliseconds: 0,
        distanceMeters: 350,
        currentSpeedMetersPerSecond: 0,
      ),
    ];
  }

  @override
  Future<List<TelemetryLocation>> loadTelemetryLocations(
    String sessionId,
  ) async {
    final startedAt = DateTime.utc(2026);
    final first = route.points.first;
    final last = route.points.last;
    return List.generate(7, (index) {
      final progress = index / 6;
      return TelemetryLocation(
        recordedAt: startedAt.add(Duration(minutes: index * 5)),
        latitude: first.latitude + (last.latitude - first.latitude) * progress,
        longitude:
            first.longitude + (last.longitude - first.longitude) * progress,
        accuracyMeters: 5,
        altitudeMeters: 0,
        speedMetersPerSecond: 3,
      );
    });
  }
}
