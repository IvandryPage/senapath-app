import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:senapath/core/storage/app_database.dart';
import 'package:senapath/core/storage/secure_vault.dart';
import 'package:senapath/features/session/data/encrypted_telemetry_codec.dart';
import 'package:senapath/features/session/data/ride_session_repository.dart';
import 'package:senapath/features/session/data/session_sync_coordinator.dart';
import 'package:senapath/features/session/data/session_sync_gateway.dart';
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

  test('sync status can only change for completed sessions', () async {
    final startedAt = DateTime.utc(2026, 9, 30, 11, 30);
    final session = await repository.start(startedAt);

    await expectLater(
      repository.updateSyncStatus(session.id, 'synced'),
      throwsStateError,
    );
    await expectLater(
      repository.updateSyncStatus(session.id, 'unknown'),
      throwsArgumentError,
    );

    await repository.finish(
      session.id,
      startedAt.add(const Duration(minutes: 2)),
    );
    await repository.updateSyncStatus(session.id, 'synced');

    final row = await (database.select(
      database.rideSessions,
    )..where((item) => item.id.equals(session.id))).getSingle();
    expect(row.syncStatus, 'synced');
  });

  test(
    'syncs a completed summary only after consent and records status',
    () async {
      final startedAt = DateTime.utc(2026, 9, 30, 12);
      final session = await repository.start(startedAt);
      await repository.finish(
        session.id,
        startedAt.add(const Duration(minutes: 5)),
      );
      final gateway = _FakeSessionSyncGateway();
      final coordinator = SessionSyncCoordinator(
        repository: repository,
        gateway: gateway,
      );

      await coordinator.syncSummary(session.id, consented: true);

      final row = await (database.select(
        database.rideSessions,
      )..where((item) => item.id.equals(session.id))).getSingle();
      expect(row.syncStatus, 'synced');
      expect(gateway.uploadedSummary?.session.id, session.id);
      expect(gateway.uploadCalls, 1);
    },
  );

  test('does not upload without consent or an authenticated session', () async {
    final startedAt = DateTime.utc(2026, 9, 30, 13);
    final session = await repository.start(startedAt);
    await repository.finish(
      session.id,
      startedAt.add(const Duration(minutes: 2)),
    );
    final gateway = _FakeSessionSyncGateway()..signedIn = false;
    final coordinator = SessionSyncCoordinator(
      repository: repository,
      gateway: gateway,
    );

    await expectLater(
      coordinator.syncSummary(session.id, consented: false),
      throwsStateError,
    );
    await expectLater(
      coordinator.syncSummary(session.id, consented: true),
      throwsStateError,
    );

    expect(gateway.uploadCalls, 0);
  });

  test(
    'leaves failed uploads retryable without claiming they synced',
    () async {
      final startedAt = DateTime.utc(2026, 9, 30, 14);
      final session = await repository.start(startedAt);
      await repository.finish(
        session.id,
        startedAt.add(const Duration(minutes: 2)),
      );
      final gateway = _FakeSessionSyncGateway()..shouldFail = true;
      final coordinator = SessionSyncCoordinator(
        repository: repository,
        gateway: gateway,
      );

      await expectLater(
        coordinator.syncSummary(session.id, consented: true),
        throwsStateError,
      );

      final row = await (database.select(
        database.rideSessions,
      )..where((item) => item.id.equals(session.id))).getSingle();
      expect(row.syncStatus, 'failed');
    },
  );
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

class _FakeSessionSyncGateway implements SessionSyncGateway {
  bool signedIn = true;
  bool shouldFail = false;
  int uploadCalls = 0;
  RideSessionSummary? uploadedSummary;

  @override
  bool get isConfigured => true;

  @override
  bool get isSignedIn => signedIn;

  @override
  Future<void> uploadSummary(RideSessionSummary summary) async {
    uploadCalls++;
    if (shouldFail) throw StateError('Simulated network failure.');
    uploadedSummary = summary;
  }
}
