import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:senapath/core/storage/app_database.dart';
import 'package:senapath/core/storage/secure_vault.dart';
import 'package:senapath/features/session/data/encrypted_telemetry_codec.dart';
import 'package:senapath/features/session/data/readiness_checker.dart';
import 'package:senapath/features/session/data/ride_session_repository.dart';
import 'package:senapath/features/session/domain/ride_session.dart';
import 'package:senapath/features/session/presentation/session_cubit.dart';

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

Position _positionAt(DateTime timestamp) => Position(
  latitude: -6.2,
  longitude: 106.8,
  timestamp: timestamp,
  accuracy: 5,
  altitude: 20,
  altitudeAccuracy: 5,
  heading: 0,
  headingAccuracy: 0,
  speed: 0,
  speedAccuracy: 0,
);

class _RecordingReadinessChecker implements ReadinessChecker {
  const _RecordingReadinessChecker();

  @override
  Future<ReadinessReport> check({
    bool requestLocationPermission = false,
    bool requestNotificationPermission = false,
    bool checkGpsFix = false,
  }) async => const ReadinessReport(
    locationPermissionGranted: true,
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
