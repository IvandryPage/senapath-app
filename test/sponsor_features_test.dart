import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:senapath/core/storage/app_database.dart';
import 'package:senapath/core/storage/secure_vault.dart';
import 'package:senapath/features/gamification/data/rider_profile_repository.dart';
import 'package:senapath/features/gamification/domain/rider_progress.dart';
import 'package:senapath/features/ledger/data/ride_ledger_repository.dart';
import 'package:senapath/features/notifications/data/notification_settings_repository.dart';
import 'package:senapath/features/routes/data/saved_route_repository.dart';
import 'package:senapath/features/routes/domain/route_progress.dart';
import 'package:senapath/features/routes/domain/saved_route.dart';
import 'package:senapath/features/session/data/encrypted_telemetry_codec.dart';
import 'package:senapath/features/session/data/session_file_service.dart';
import 'package:senapath/features/session/domain/ride_session.dart';

void main() {
  late AppDatabase database;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await database.close();
  });

  test('GPX route points and named waypoints become route checkpoints', () {
    const document = '''
<gpx version="1.1" creator="test">
  <rte>
    <name>Loop Pagi</name>
    <rtept lat="-6.2000" lon="106.8000"><ele>10</ele></rtept>
    <rtept lat="-6.2010" lon="106.8010"><ele>12</ele></rtept>
  </rte>
  <wpt lat="-6.2005" lon="106.8005"><name>Pos Air</name></wpt>
</gpx>
''';

    final imported = const SessionFileService().parseGpxDocument(document);

    expect(imported.name, 'Loop Pagi');
    expect(imported.locations, hasLength(2));
    expect(imported.checkpoints, hasLength(1));
    expect(imported.checkpoints.single.name, 'Pos Air');
    expect(imported.locations.first.recordedAt.year, 2000);
  });

  test('rider appearance is persisted locally', () async {
    final repository = RiderProfileRepository(database);
    const appearance = RiderAppearance(
      kitColor: RiderKitColor.violet,
      accessory: RiderAccessory.glasses,
    );

    await repository.saveAppearance(appearance);

    expect(await repository.loadAppearance(), appearance);
  });

  test(
    'GPX track and checkpoints survive encrypted local persistence',
    () async {
      final repository = SavedRouteRepository(
        database,
        geometryCodec: EncryptedTelemetryCodec(
          secureVault: _MemorySecureVault(),
        ),
      );
      final route = await repository.saveImportedRoute(
        name: 'Rute Air',
        points: const [
          (latitude: -6.2, longitude: 106.8, elevation: 10),
          (latitude: -6.201, longitude: 106.801, elevation: 12),
        ],
        checkpoints: const [
          RouteCheckpoint(
            name: 'Pos Air',
            latitude: -6.2005,
            longitude: 106.8005,
          ),
        ],
      );

      final restored = (await repository.search('Rute Air')).single;

      expect(restored.points, hasLength(2));
      expect(restored.checkpoints.single.name, 'Pos Air');
      await repository.saveSelectedSessionRoute(route.id);
      expect((await repository.loadSelectedSessionRoute())?.id, route.id);
    },
  );

  test(
    'route progress uses the nearest route point and total route length',
    () {
      final route = RouteRecord(
        id: 'test',
        name: 'Test',
        source: 'GPX lokal',
        updatedAt: _fixedDate,
        availability: 'offline',
        points: [
          RoutePoint(latitude: -6.2, longitude: 106.8, elevationMeters: 0),
          RoutePoint(latitude: -6.201, longitude: 106.8, elevationMeters: 0),
          RoutePoint(latitude: -6.202, longitude: 106.8, elevationMeters: 0),
        ],
      );
      final progress = RouteProgress.calculate(
        route: route,
        location: TelemetryLocation(
          recordedAt: _fixedDate,
          latitude: -6.201,
          longitude: 106.8,
          accuracyMeters: 5,
          altitudeMeters: 0,
          speedMetersPerSecond: 0,
        ),
      );

      expect(progress?.percent, 50);
      expect(progress?.distanceFromRouteMeters, lessThan(1));
    },
  );

  test('rider level and XP are derived from completed session metrics', () {
    final session = RideSessionSnapshot(
      id: 'ride-1',
      startedAt: _fixedDate,
      endedAt: _fixedDate.add(const Duration(minutes: 60)),
      status: RideSessionStatus.completed,
      totalPausedMilliseconds: 0,
      distanceMeters: 10000,
      currentSpeedMetersPerSecond: 0,
    );

    final progress = RiderProgress.fromSessions([
      session,
    ], style: RiderStyle.climber);

    expect(progress.experience, 184);
    expect(progress.level, 1);
    expect(progress.style, RiderStyle.climber);
    expect(progress.completedRides, 1);
    expect(progress.rideDurationSeconds, 3600);
    expect(progress.longestRideMeters, 10000);
  });

  test('rider titles progress through expanding level ranges', () {
    expect(RiderRank.forLevel(1), RiderRank.rookie);
    expect(RiderRank.forLevel(10), RiderRank.rookie);
    expect(RiderRank.forLevel(11), RiderRank.clubRider);
    expect(RiderRank.forLevel(30), RiderRank.clubRider);
    expect(RiderRank.forLevel(31), RiderRank.granFondo);
    expect(RiderRank.forLevel(61), RiderRank.eliteRider);
    expect(RiderRank.forLevel(101), RiderRank.proRider);
  });

  test('rider achievements unlock from level, distance, and ride counts', () {
    const progress = RiderProgress(
      experience: 0,
      level: 31,
      distanceMeters: 100000,
      completedRides: 10,
      style: RiderStyle.explorer,
    );

    final achievements = progress.achievements;
    RiderAchievement achievement(String title) =>
        achievements.singleWhere((item) => item.title == title);

    expect(achievements.length, 31);
    expect(achievement('Gowes Pertama').isUnlocked, isTrue);
    expect(achievement('Rutin Gowes').isUnlocked, isTrue);
    expect(achievement('Centurion').isUnlocked, isTrue);
    expect(achievement('Penjelajah Jarak Jauh').isUnlocked, isFalse);
    expect(achievement('Level 11 · Club Rider').isUnlocked, isTrue);
    expect(achievement('Level 31 · Gran Fondo').isUnlocked, isTrue);
    expect(achievement('Metric Century').isUnlocked, isFalse);
  });

  test('ride proof chain detects edited block data', () async {
    final repository = RideLedgerRepository(database);
    final endedAt = _fixedDate.add(const Duration(hours: 1));
    final session = RideSessionSnapshot(
      id: 'ride-proof',
      startedAt: _fixedDate,
      endedAt: endedAt,
      status: RideSessionStatus.completed,
      totalPausedMilliseconds: 0,
      distanceMeters: 1234,
      currentSpeedMetersPerSecond: 0,
    );

    await repository.appendSession(session);
    await repository.appendSession(session);

    expect(await repository.loadBlocks(), hasLength(1));
    expect(await repository.verify(), isTrue);

    await (database.update(
      database.appPreferences,
    )..where((row) => row.key.equals('ride_proof_chain_v1'))).write(
      AppPreferencesCompanion.insert(
        key: 'ride_proof_chain_v1',
        value: jsonEncode([
          {
            ...(await repository.loadBlocks()).single.toJson(),
            'distanceMeters': 9999,
          },
        ]),
      ),
    );

    expect(await repository.verify(), isFalse);
  });

  test(
    'notification settings persist reminder and GPX choices locally',
    () async {
      final repository = NotificationSettingsRepository(database);
      const settings = RideNotificationSettings(
        routeProgressEnabled: false,
        remindersEnabled: true,
        reminderWeekdays: {1, 5},
        reminderHour: 19,
        reminderMinute: 30,
      );

      await repository.save(settings);

      final restored = await repository.load();
      expect(restored.routeProgressEnabled, isFalse);
      expect(restored.remindersEnabled, isTrue);
      expect(restored.reminderWeekdays, {1, 5});
      expect(restored.reminderHour, 19);
      expect(restored.reminderMinute, 30);
    },
  );
}

final _fixedDate = DateTime.utc(2026, 10, 9, 8);

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
