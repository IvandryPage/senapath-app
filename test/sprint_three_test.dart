import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:senapath/core/storage/app_database.dart';
import 'package:senapath/core/storage/secure_vault.dart';
import 'package:senapath/features/session/data/encrypted_telemetry_codec.dart';
import 'package:senapath/features/session/data/ride_session_repository.dart';
import 'package:senapath/features/session/domain/ride_session.dart';

void main() {
  late AppDatabase database;
  late _MemorySecureVault secureVault;
  late EncryptedTelemetryCodec codec;
  late DriftRideSessionRepository repository;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    secureVault = _MemorySecureVault();
    codec = EncryptedTelemetryCodec(secureVault: secureVault);
    repository = DriftRideSessionRepository(
      database: database,
      telemetryCodec: codec,
    );
  });

  tearDown(() async {
    await database.close();
  });

  test(
    'telemetry coordinates are encrypted and decode back to their source',
    () async {
      final location = TelemetryLocation(
        recordedAt: DateTime.utc(2026, 9, 30, 10),
        latitude: -6.2088,
        longitude: 106.8456,
        accuracyMeters: 6.5,
        altitudeMeters: 12,
        speedMetersPerSecond: 5.2,
      );

      final encrypted = await codec.encode(location);
      expect(
        utf8.decode(encrypted, allowMalformed: true),
        isNot(contains('-6.2088')),
      );

      final decoded = await codec.decode(
        encrypted,
        recordedAt: location.recordedAt,
      );
      expect(decoded.latitude, location.latitude);
      expect(decoded.longitude, location.longitude);
      expect(decoded.accuracyMeters, location.accuracyMeters);
      expect(decoded.speedMetersPerSecond, location.speedMetersPerSecond);
    },
  );

  test(
    'session transitions preserve active duration and pending status',
    () async {
      final startedAt = DateTime.utc(2026, 9, 30, 10);
      final started = await repository.start(startedAt);
      expect(started.status, RideSessionStatus.recording);

      final paused = await repository.pause(
        started.id,
        startedAt.add(const Duration(seconds: 60)),
      );
      expect(paused.status, RideSessionStatus.paused);
      expect(
        paused.durationAt(startedAt.add(const Duration(seconds: 60))),
        const Duration(seconds: 60),
      );

      final resumed = await repository.resume(
        started.id,
        startedAt.add(const Duration(seconds: 90)),
      );
      expect(resumed.status, RideSessionStatus.recording);
      expect(
        resumed.totalPausedMilliseconds,
        const Duration(seconds: 30).inMilliseconds,
      );

      final completed = await repository.finish(
        started.id,
        startedAt.add(const Duration(seconds: 150)),
      );
      expect(completed.status, RideSessionStatus.completed);
      expect(
        completed.durationAt(startedAt.add(const Duration(seconds: 150))),
        const Duration(seconds: 120),
      );

      final row = await (database.select(
        database.rideSessions,
      )..where((session) => session.id.equals(started.id))).getSingle();
      expect(row.syncStatus, 'pending');
    },
  );

  test('interrupted recording is recovered as paused', () async {
    final started = await repository.start(DateTime.utc(2026, 9, 30, 11));

    final recovered = await repository.recoverCurrentSession();

    expect(recovered?.id, started.id);
    expect(recovered?.status, RideSessionStatus.paused);
    expect(recovered?.pausedAt, isNotNull);
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
