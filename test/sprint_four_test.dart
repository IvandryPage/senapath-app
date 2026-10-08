import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:senapath/core/storage/app_database.dart';
import 'package:senapath/core/storage/secure_vault.dart';
import 'package:senapath/features/session/data/encrypted_telemetry_codec.dart';
import 'package:senapath/features/session/data/ride_session_repository.dart';
import 'package:senapath/features/session/domain/ride_session.dart';

void main() {
  late AppDatabase database;
  late DriftRideSessionRepository repository;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    repository = DriftRideSessionRepository(
      database: database,
      telemetryCodec: EncryptedTelemetryCodec(
        secureVault: _MemorySecureVault(),
      ),
    );
  });

  tearDown(() async {
    await database.close();
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
