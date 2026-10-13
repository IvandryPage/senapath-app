import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:senapath/core/storage/app_database.dart';
import 'package:senapath/core/storage/secure_vault.dart';
import 'package:senapath/features/account_sync/data/account_cloud_gateway.dart';
import 'package:senapath/features/gamification/domain/rider_progress.dart';
import 'package:senapath/features/notifications/data/notification_settings_repository.dart';
import 'package:senapath/features/notifications/data/ride_notification_service.dart';
import 'package:senapath/features/routes/domain/saved_route.dart';
import 'package:senapath/features/session/data/encrypted_telemetry_codec.dart';
import 'package:senapath/features/session/data/readiness_checker.dart';
import 'package:senapath/features/session/data/ride_session_repository.dart';
import 'package:senapath/features/session/data/ride_session_cloud_sync.dart';
import 'package:senapath/features/session/data/session_sync_coordinator.dart';
import 'package:senapath/features/session/data/session_sync_gateway.dart';
import 'package:senapath/features/session/data/session_sync_settings_repository.dart';
import 'package:senapath/features/session/domain/ride_session.dart';
import 'package:senapath/features/session/presentation/session_cubit.dart';
import 'package:senapath/features/workouts/data/interval_workout_repository.dart';
import 'package:senapath/features/workouts/domain/interval_workout.dart';

void main() {
  late AppDatabase database;
  late DriftRideSessionRepository repository;
  late StreamController<Position> positions;
  late StreamController<AccelerometerEvent> accelerometerReadings;
  late StreamController<GyroscopeEvent> gyroscopeReadings;
  RideSessionCubit? sessionCubit;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    repository = DriftRideSessionRepository(
      database: database,
      telemetryCodec: EncryptedTelemetryCodec(
        secureVault: _MemorySecureVault(),
      ),
    );
    positions = StreamController<Position>.broadcast();
    accelerometerReadings = StreamController<AccelerometerEvent>.broadcast();
    gyroscopeReadings = StreamController<GyroscopeEvent>.broadcast();
  });

  tearDown(() async {
    await sessionCubit?.close();
    await positions.close();
    await accelerometerReadings.close();
    await gyroscopeReadings.close();
    await database.close();
  });

  test('finished sessions sync automatically when opted in', () async {
    final settingsRepository = SessionSyncSettingsRepository(database);
    await settingsRepository.saveAutoSyncEnabled(true);
    final gateway = _TestSessionSyncGateway();
    sessionCubit = RideSessionCubit(
      repository: repository,
      readinessChecker: const _RecordingReadinessChecker(),
      locationSource: _TestLocationSource(positions.stream),
      syncCoordinator: SessionSyncCoordinator(
        repository: repository,
        gateway: gateway,
      ),
      syncSettingsRepository: settingsRepository,
    );

    await sessionCubit!.initialize();
    await sessionCubit!.start();
    final sessionId = sessionCubit!.state.session!.id;
    await sessionCubit!.finish();
    await sessionCubit!.stream
        .firstWhere(
          (state) => state.completedSessions.any(
            (session) =>
                session.id == sessionId && session.syncStatus == 'synced',
          ),
        )
        .timeout(const Duration(seconds: 2));

    expect(gateway.uploadedSummary?.session.id, sessionId);
  });

  test('reports local save success when refreshing history fails', () async {
    final failingRepository = _HistoryFailingRepository(
      database: database,
      telemetryCodec: EncryptedTelemetryCodec(
        secureVault: _MemorySecureVault(),
      ),
    );
    sessionCubit = RideSessionCubit(
      repository: failingRepository,
      readinessChecker: const _RecordingReadinessChecker(),
      locationSource: _TestLocationSource(positions.stream),
    );

    await sessionCubit!.initialize();
    await sessionCubit!.start();
    failingRepository.failHistoryLoads = true;
    final sessionId = sessionCubit!.state.session!.id;

    await sessionCubit!.finish();

    expect(sessionCubit!.state.session?.status, RideSessionStatus.completed);
    expect(sessionCubit!.state.messageIsSuccess, isTrue);
    expect(sessionCubit!.state.message, contains('tersimpan aman di perangkat'));
    expect(
      (await repository.loadCompletedSessions()).single.id,
      sessionId,
    );
  });

  test('pauses the session and reports location stream failures', () async {
    sessionCubit = RideSessionCubit(
      repository: repository,
      readinessChecker: const _RecordingReadinessChecker(),
      locationSource: _TestLocationSource(positions.stream),
    );

    await sessionCubit!.initialize();
    await sessionCubit!.start();
    final sessionId = sessionCubit!.state.session!.id;

    positions.addError(StateError('foreground notification unavailable'));

    final pausedState = await sessionCubit!.stream
        .firstWhere(
          (state) =>
              state.session?.id == sessionId &&
                state.session?.status == RideSessionStatus.paused &&
                state.message?.contains(
                      'foreground notification unavailable',
                    ) ==
                    true,
          )
        .timeout(const Duration(seconds: 2));

    expect(pausedState.message, contains('tersimpan dan dijeda'));
  });

  test('account GPS sync stays local until the user opts in', () async {
    final session = await repository.start(DateTime.utc(2026, 9, 30, 10));
    await repository.finish(session.id, DateTime.utc(2026, 9, 30, 11));
    final gateway = _TestAccountCloudGateway();
    sessionCubit = RideSessionCubit(
      repository: repository,
      readinessChecker: const _RecordingReadinessChecker(),
      locationSource: _TestLocationSource(positions.stream),
      syncSettingsRepository: SessionSyncSettingsRepository(database),
      cloudSync: RideSessionCloudSync(repository: repository, gateway: gateway),
    );

    await sessionCubit!.initialize();
    await sessionCubit!.syncCloudSessions();

    expect(gateway.pullCalls, 0);
    expect(gateway.pushCalls, 0);
    expect(
      (await repository.loadCompletedSessions()).single.syncStatus,
      'pending',
    );
  });

  test(
    'account GPS sync uploads opted-in sessions and restores cloud data',
    () async {
      final session = await repository.start(DateTime.utc(2026, 9, 30, 10));
      await repository.finish(session.id, DateTime.utc(2026, 9, 30, 11));
      final settingsRepository = SessionSyncSettingsRepository(database);
      await settingsRepository.saveAutoSyncEnabled(true);
      final gateway = _TestAccountCloudGateway();
      sessionCubit = RideSessionCubit(
        repository: repository,
        readinessChecker: const _RecordingReadinessChecker(),
        locationSource: _TestLocationSource(positions.stream),
        syncSettingsRepository: settingsRepository,
        cloudSync: RideSessionCloudSync(
          repository: repository,
          gateway: gateway,
        ),
      );

      await sessionCubit!.initialize();
      await sessionCubit!.syncCloudSessions();

      expect(gateway.pullCalls, 1);
      expect(gateway.pushCalls, 1);
      expect(
        (await repository.loadCompletedSessions()).single.syncStatus,
        'synced',
      );
    },
  );

  test('motion sensors keep recording after session resume', () async {
    sessionCubit = RideSessionCubit(
      repository: repository,
      readinessChecker: const _RecordingReadinessChecker(),
      locationSource: _TestLocationSource(positions.stream),
      motionSensorSource: _TestMotionSensorSource(
        accelerometerReadings.stream,
        gyroscopeReadings.stream,
      ),
    );

    await sessionCubit!.start();
    final startedAt = DateTime.now().toUtc();
    accelerometerReadings.add(AccelerometerEvent(1, 2, 2, DateTime.now()));
    gyroscopeReadings.add(GyroscopeEvent(0.1, 0.2, 0.2, DateTime.now()));
    await Future<void>.delayed(const Duration(milliseconds: 20));
    final firstSample = sessionCubit!.stream.firstWhere(
      (state) => state.recordedLocations.length == 1,
    );
    positions.add(_positionAt(startedAt));
    await firstSample.timeout(const Duration(seconds: 2));

    await sessionCubit!.pause();
    await sessionCubit!.resume();
    accelerometerReadings.add(AccelerometerEvent(0, 4, 3, DateTime.now()));
    gyroscopeReadings.add(GyroscopeEvent(0, 0, 2, DateTime.now()));
    await Future<void>.delayed(const Duration(milliseconds: 20));
    final secondSample = sessionCubit!.stream.firstWhere(
      (state) => state.recordedLocations.length == 2,
    );
    positions.add(_positionAt(startedAt.add(const Duration(seconds: 10))));
    await secondSample.timeout(const Duration(seconds: 2));

    final locations = await repository.loadTelemetryLocations(
      sessionCubit!.state.session!.id,
    );
    expect(
      locations
          .map(
            (location) => location.accelerationMagnitudeMetersPerSecondSquared,
          )
          .toList(),
      [3, 5],
    );
    expect(
      locations
          .map((location) => location.rotationRateMagnitudeRadiansPerSecond)
          .toList(),
      [closeTo(0.3, 0.0001), closeTo(2.0, 0.0001)],
    );
  });

  test(
    'performance chart samples every five seconds without dropping GPS',
    () async {
      var now = DateTime.utc(2026, 9, 30, 12);
      sessionCubit = RideSessionCubit(
        repository: repository,
        readinessChecker: const _RecordingReadinessChecker(),
        locationSource: _TestLocationSource(positions.stream),
        clock: () => now,
      );
      await sessionCubit!.start();

      var recorded = sessionCubit!.stream.firstWhere(
        (state) => state.recordedLocations.length == 1,
      );
      positions.add(_positionAt(now));
      await recorded.timeout(const Duration(seconds: 2));
      expect(sessionCubit!.state.performanceLocations.length, 1);

      now = now.add(const Duration(seconds: 4));
      recorded = sessionCubit!.stream.firstWhere(
        (state) => state.recordedLocations.length == 2,
      );
      positions.add(_positionAt(now, longitude: 106.8001));
      await recorded.timeout(const Duration(seconds: 2));
      expect(sessionCubit!.state.performanceLocations.length, 1);

      now = now.add(const Duration(seconds: 1));
      recorded = sessionCubit!.stream.firstWhere(
        (state) => state.recordedLocations.length == 3,
      );
      positions.add(_positionAt(now, longitude: 106.8002));
      await recorded.timeout(const Duration(seconds: 2));

      expect(sessionCubit!.state.recordedLocations, hasLength(3));
      expect(sessionCubit!.state.performanceLocations, hasLength(2));
      expect(
        await repository.loadTelemetryLocations(
          sessionCubit!.state.session!.id,
        ),
        hasLength(3),
      );
    },
  );

  test('active GPX sessions notify route progress and checkpoints', () async {
    final notificationService = _RecordingRideNotificationService();
    sessionCubit = RideSessionCubit(
      repository: repository,
      readinessChecker: const _RecordingReadinessChecker(),
      locationSource: _TestLocationSource(positions.stream),
      notificationService: notificationService,
      notificationSettingsRepository: NotificationSettingsRepository(database),
    );
    await sessionCubit!.start();
    sessionCubit!.setActiveRoute(
      RouteRecord(
        id: 'notification-route',
        name: 'Rute Tes',
        source: 'test',
        updatedAt: DateTime.utc(2026),
        availability: 'local',
        points: const [
          RoutePoint(latitude: -6.2, longitude: 106.8, elevationMeters: 0),
          RoutePoint(latitude: -6.2, longitude: 106.81, elevationMeters: 0),
          RoutePoint(latitude: -6.2, longitude: 106.813, elevationMeters: 0),
          RoutePoint(latitude: -6.2, longitude: 106.815, elevationMeters: 0),
          RoutePoint(latitude: -6.2, longitude: 106.83, elevationMeters: 0),
        ],
        checkpoints: const [
          RouteCheckpoint(name: 'Pos Air', latitude: -6.2, longitude: 106.815),
        ],
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 30));

    final startedAt = DateTime.now().toUtc();
    const longitudes = [106.8, 106.81, 106.813, 106.815];
    for (var index = 0; index < longitudes.length; index++) {
      final count = index + 1;
      final locationRecorded = sessionCubit!.stream.firstWhere(
        (state) => state.recordedLocations.length == count,
      );
      positions.add(
        _positionAt(
          startedAt.add(Duration(seconds: index * 10)),
          longitude: longitudes[index],
        ),
      );
      await locationRecorded.timeout(const Duration(seconds: 2));
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }

    expect(
      notificationService.notifications.map(
        (notification) => notification.title,
      ),
      containsAll([
        'Progres rute 25%',
        'Checkpoint dekat',
        'Checkpoint tercapai',
      ]),
    );
    expect(notificationService.permissionRequests, 1);
  });

  test('interval workout persists and pauses with its recording', () async {
    final workoutRepository = IntervalWorkoutRepository(database);
    const workout = IntervalWorkout(
      id: 'test-workout',
      name: 'Tes interval',
      intervals: [
        WorkoutInterval(
          name: 'Pemanasan',
          targetType: WorkoutTargetType.duration,
          targetValue: 1,
        ),
        WorkoutInterval(
          name: 'Pemulihan',
          targetType: WorkoutTargetType.duration,
          targetValue: 5,
          isRecovery: true,
        ),
      ],
    );
    await workoutRepository.saveWorkouts([workout]);
    final loadedWorkout = (await workoutRepository.loadWorkouts()).single;
    expect(loadedWorkout.name, workout.name);
    expect(
      loadedWorkout.intervals.map((interval) => interval.toJson()).toList(),
      workout.intervals.map((interval) => interval.toJson()).toList(),
    );

    sessionCubit = RideSessionCubit(
      repository: repository,
      readinessChecker: const _RecordingReadinessChecker(),
      locationSource: _TestLocationSource(positions.stream),
      intervalWorkoutRepository: workoutRepository,
    );
    await sessionCubit!.start(workout: loadedWorkout);
    expect(sessionCubit!.state.workoutProgress?.index, 0);

    await sessionCubit!.stream
        .firstWhere((state) => state.workoutProgress?.index == 1)
        .timeout(const Duration(seconds: 4));
    expect(sessionCubit!.state.session?.status, RideSessionStatus.recording);
    await sessionCubit!.pause();
    final pausedRemaining = sessionCubit!.state.workoutProgress!.remainingValue;
    await Future<void>.delayed(const Duration(milliseconds: 1200));
    expect(
      sessionCubit!.state.workoutProgress!.remainingValue,
      pausedRemaining,
    );

    await sessionCubit!.close();
    sessionCubit = RideSessionCubit(
      repository: repository,
      readinessChecker: const _RecordingReadinessChecker(),
      locationSource: _TestLocationSource(positions.stream),
      intervalWorkoutRepository: workoutRepository,
    );
    await sessionCubit!.initialize();
    expect(sessionCubit!.state.session?.status, RideSessionStatus.paused);
    expect(sessionCubit!.state.workoutProgress?.index, 1);
    expect(
      sessionCubit!.state.workoutProgress!.remainingValue,
      pausedRemaining,
    );
    await Future<void>.delayed(const Duration(milliseconds: 1100));
    expect(
      sessionCubit!.state.workoutProgress!.remainingValue,
      pausedRemaining,
    );

    await sessionCubit!.resume();
    await Future<void>.delayed(const Duration(milliseconds: 200));
    expect(sessionCubit!.state.workoutProgress?.index, 1);
    final checkpoint = await workoutRepository.loadCheckpoint(
      sessionCubit!.state.session!.id,
    );
    expect(checkpoint?.intervalIndex, 1);
  });

  test('distance workout advances only with accepted GPS distance', () async {
    final workoutRepository = IntervalWorkoutRepository(database);
    const workout = IntervalWorkout(
      id: 'distance-workout',
      name: 'Jarak tervalidasi',
      intervals: [
        WorkoutInterval(
          name: 'Interval jarak',
          targetType: WorkoutTargetType.distance,
          targetValue: 20,
        ),
        WorkoutInterval(
          name: 'Pemulihan',
          targetType: WorkoutTargetType.duration,
          targetValue: 30,
          isRecovery: true,
        ),
      ],
      audioCueEnabled: false,
      hapticCueEnabled: false,
    );
    sessionCubit = RideSessionCubit(
      repository: repository,
      readinessChecker: const _RecordingReadinessChecker(),
      locationSource: _TestLocationSource(positions.stream),
      intervalWorkoutRepository: workoutRepository,
    );
    await sessionCubit!.start(workout: workout);
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(sessionCubit!.state.workoutProgress?.index, 0);
    expect(sessionCubit!.state.session?.distanceMeters, 0);

    final recordedAt = DateTime.now().toUtc();
    positions.add(_positionAt(recordedAt));
    await sessionCubit!.stream
        .firstWhere((state) => state.recordedLocations.length == 1)
        .timeout(const Duration(seconds: 2));
    positions.add(
      _positionAt(
        recordedAt.add(const Duration(seconds: 10)),
        longitude: 106.80025,
      ),
    );
    await sessionCubit!.stream
        .firstWhere((state) => state.workoutProgress?.index == 1)
        .timeout(const Duration(seconds: 2));

    expect(
      sessionCubit!.state.session!.distanceMeters,
      greaterThanOrEqualTo(20),
    );
    expect(sessionCubit!.state.workoutProgress?.index, 1);
  });

  test('interval model rejects invalid targets and empty plans', () {
    expect(
      () => WorkoutInterval.create(
        name: 'Tidak valid',
        targetType: WorkoutTargetType.distance,
        targetValue: 0,
      ),
      throwsArgumentError,
    );
    expect(
      () => IntervalWorkout.create(id: 'empty', name: 'Kosong', intervals: []),
      throwsArgumentError,
    );
  });

  test(
    'uses barometer for elevation and includes sensor sample coverage',
    () async {
      final startedAt = DateTime.utc(2026, 9, 30, 12);
      final session = await repository.start(startedAt);
      const pressureSamples = [1013.25, 1012.9, 1012.55, 1012.2, 1011.85];

      for (var index = 0; index < pressureSamples.length; index++) {
        await repository.recordLocation(
          sessionId: session.id,
          location: TelemetryLocation(
            recordedAt: startedAt.add(Duration(seconds: index * 10)),
            latitude: -6.2,
            longitude: 106.8 + index * 0.0001,
            accuracyMeters: 5,
            altitudeMeters: 20,
            altitudeAccuracyMeters: 5,
            barometricPressureHpa: pressureSamples[index],
            accelerationMagnitudeMetersPerSecondSquared: 9.8,
            rotationRateMagnitudeRadiansPerSecond: 0.2,
            speedMetersPerSecond: 4.0 + index,
          ),
          addedDistanceMeters: 10,
        );
      }

      final summary = await repository.loadSummary(session.id);

      expect(summary.sampleCount, 5);
      expect(summary.elevationSource, 'Barometer');
      expect(summary.elevationGainMeters, greaterThan(0));
      expect(summary.accelerometerSampleCount, 5);
      expect(summary.gyroscopeSampleCount, 5);
      expect(summary.hasSpeedGraph, isTrue);
    },
  );

  test(
    'uses labeled GPS elevation estimate when barometer is unavailable',
    () async {
      final startedAt = DateTime.utc(2026, 9, 30, 13);
      final session = await repository.start(startedAt);
      const altitudes = [20.0, 24.0, 22.0, 29.0, 27.0];

      for (var index = 0; index < altitudes.length; index++) {
        await repository.recordLocation(
          sessionId: session.id,
          location: TelemetryLocation(
            recordedAt: startedAt.add(Duration(seconds: index * 10)),
            latitude: -6.2,
            longitude: 106.8 + index * 0.0001,
            accuracyMeters: 5,
            altitudeMeters: altitudes[index],
            altitudeAccuracyMeters: 4,
            speedMetersPerSecond: 3,
          ),
          addedDistanceMeters: 0,
        );
      }

      final summary = await repository.loadSummary(session.id);

      expect(summary.elevationSource, 'Estimasi GPS');
      expect(summary.elevationGainMeters, 11);
      expect(summary.accelerometerSampleCount, 0);
      expect(summary.gyroscopeSampleCount, 0);
    },
  );

  test('does not report elevation or graph for sparse telemetry', () async {
    final startedAt = DateTime.utc(2026, 9, 30, 14);
    final session = await repository.start(startedAt);
    await repository.recordLocation(
      sessionId: session.id,
      location: TelemetryLocation(
        recordedAt: startedAt,
        latitude: -6.2,
        longitude: 106.8,
        accuracyMeters: 5,
        altitudeMeters: 20,
        altitudeAccuracyMeters: 4,
        speedMetersPerSecond: 2,
      ),
      addedDistanceMeters: 0,
    );

    final summary = await repository.loadSummary(session.id);

    expect(summary.elevationGainMeters, isNull);
    expect(summary.elevationSource, 'Tidak tersedia');
    expect(summary.hasSpeedGraph, isFalse);
  });

  test(
    'updates activity metadata without changing recorded telemetry',
    () async {
      final startedAt = DateTime.utc(2026, 9, 30, 15);
      final session = await repository.start(startedAt);
      await repository.recordLocation(
        sessionId: session.id,
        location: TelemetryLocation(
          recordedAt: startedAt,
          latitude: -6.2,
          longitude: 106.8,
          accuracyMeters: 5,
          altitudeMeters: 20,
          speedMetersPerSecond: 2,
        ),
        addedDistanceMeters: 0,
      );
      final before = await repository.loadTelemetryLocations(session.id);

      final updated = await repository.updateActivityMetadata(
        sessionId: session.id,
        title: '  Gowes pagi  ',
        activityType: RideActivityType.training,
      );
      final restored = await repository.loadSummary(session.id);
      final after = await repository.loadTelemetryLocations(session.id);

      expect(updated.title, 'Gowes pagi');
      expect(updated.activityType, RideActivityType.training);
      expect(updated.source, 'recorded');
      expect(restored.session.title, 'Gowes pagi');
      expect(
        after.map((point) => point.toJson()).toList(),
        before.map((point) => point.toJson()).toList(),
      );
    },
  );

  test('deletes completed session and its telemetry atomically', () async {
    final session = await repository.start(DateTime.utc(2026, 9, 30, 16));
    await repository.recordLocation(
      sessionId: session.id,
      location: TelemetryLocation(
        recordedAt: DateTime.utc(2026, 9, 30, 16),
        latitude: -6.2,
        longitude: 106.8,
        accuracyMeters: 5,
        altitudeMeters: 20,
        speedMetersPerSecond: 2,
      ),
      addedDistanceMeters: 0,
    );
    await repository.finish(session.id, DateTime.utc(2026, 9, 30, 17));

    await repository.deleteCompletedSession(session.id);

    expect(await repository.loadCompletedSessions(), isEmpty);
    expect(await repository.loadTelemetryLocations(session.id), isEmpty);
  });
}

class _HistoryFailingRepository extends DriftRideSessionRepository {
  _HistoryFailingRepository({
    required super.database,
    required super.telemetryCodec,
  });

  bool failHistoryLoads = false;

  @override
  Future<List<RideSessionSnapshot>> loadCompletedSessions() {
    if (failHistoryLoads) throw StateError('History refresh unavailable.');
    return super.loadCompletedSessions();
  }
}

Position _positionAt(DateTime timestamp, {double longitude = 106.8}) =>
    Position(
      latitude: -6.2,
      longitude: longitude,
      timestamp: timestamp,
      accuracy: 5,
      altitude: 20,
      altitudeAccuracy: 5,
      heading: 0,
      headingAccuracy: 0,
      speed: 0,
      speedAccuracy: 0,
    );

class _RecordedNotification {
  const _RecordedNotification(this.title, this.body);

  final String title;
  final String body;
}

class _RecordingRideNotificationService implements RideNotificationService {
  final notifications = <_RecordedNotification>[];
  int permissionRequests = 0;

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> requestPermission() async {
    permissionRequests++;
    return true;
  }

  @override
  Future<void> show({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    notifications.add(_RecordedNotification(title, body));
  }

  @override
  Future<void> scheduleWeeklyReminder({
    required Set<int> weekdays,
    required int hour,
    required int minute,
  }) async {}

  @override
  Future<void> cancelWeeklyReminders() async {}
}

class _RecordingReadinessChecker implements ReadinessChecker {
  const _RecordingReadinessChecker();

  @override
  Future<ReadinessReport> check({
    bool requestLocationPermission = false,
    bool requestNotificationPermission = false,
    bool checkGpsFix = false,
  }) async => const ReadinessReport(
    locationPermissionGranted: true,
    backgroundLocationGranted: false,
    locationPermanentlyDenied: false,
    locationServicesEnabled: true,
    gpsFixAvailable: true,
    accelerometerAvailable: true,
    gyroscopeAvailable: true,
    notificationsGranted: true,
    notificationsPermanentlyDenied: false,
  );

  @override
  Future<bool> openLocationSettings() async => false;

  @override
  Future<bool> openLocationServiceSettings() async => false;

  @override
  Future<bool> openNotificationSettings() async => false;
}

class _TestLocationSource implements LocationSource {
  const _TestLocationSource(this._positions);

  final Stream<Position> _positions;

  @override
  Stream<Position> get positions => _positions;
}

class _TestSessionSyncGateway implements SessionSyncGateway {
  RideSessionSummary? uploadedSummary;

  @override
  bool get isConfigured => true;

  @override
  bool get isSignedIn => true;

  @override
  Future<void> uploadSummary(
    RideSessionSummary summary, {
    String? shareWithTeamId,
  }) async {
    uploadedSummary = summary;
  }
}

class _TestAccountCloudGateway implements AccountCloudGateway {
  int pullCalls = 0;
  int pushCalls = 0;

  @override
  bool get isConfigured => true;

  @override
  bool get isSignedIn => true;

  @override
  Future<Object?> pullSetting(String key) async => null;

  @override
  Future<void> pushSetting(String key, Object? value) async {}

  @override
  Future<void> pushRideSession(
    RideSessionSnapshot session,
    List<TelemetryLocation> points,
  ) async {
    pushCalls++;
  }

  @override
  Future<List<CloudRideSession>> pullRideSessions() async {
    pullCalls++;
    return const [];
  }

  @override
  Future<void> deleteRideSession(String sessionId) async {}

  @override
  Future<void> pushRiderProgress({
    required RiderStyle style,
    required int level,
    required int experience,
    required double distanceMeters,
    required int completedRides,
    required int rideDurationSeconds,
    required int weekendRides,
    required RiderAppearance appearance,
  }) async {}

  @override
  Future<CloudRiderProgress?> pullRiderProgress() async => null;
}

class _TestMotionSensorSource implements MotionSensorSource {
  const _TestMotionSensorSource(this._accelerometer, this._gyroscope);

  final Stream<AccelerometerEvent> _accelerometer;
  final Stream<GyroscopeEvent> _gyroscope;

  @override
  Stream<AccelerometerEvent> get accelerometerReadings => _accelerometer;

  @override
  Stream<GyroscopeEvent> get gyroscopeReadings => _gyroscope;
}

class _MemorySecureVault implements SecureVault {
  final Map<String, String> _values = {};

  @override
  Future<void> delete(String key) async {
    _values.remove(key);
  }

  @override
  Future<String?> read(String key) async => _values[key];

  @override
  Future<void> write(String key, String value) async {
    _values[key] = value;
  }
}
