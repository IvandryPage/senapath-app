import 'dart:math';

import 'package:drift/drift.dart';

import '../../../core/storage/app_database.dart';
import '../domain/ride_session.dart';
import 'encrypted_telemetry_codec.dart';

abstract interface class RideSessionRepository {
  Future<RideSessionSnapshot?> recoverCurrentSession();
  Future<RideSessionSnapshot> start(DateTime now);
  Future<RideSessionSnapshot> pause(String sessionId, DateTime now);
  Future<RideSessionSnapshot> resume(String sessionId, DateTime now);
  Future<RideSessionSnapshot> finish(String sessionId, DateTime now);
  Future<TelemetryLocation?> latestLocation(String sessionId);
  Future<RideSessionSnapshot?> recordLocation({
    required String sessionId,
    required TelemetryLocation location,
    required double addedDistanceMeters,
  });
}

class DriftRideSessionRepository implements RideSessionRepository {
  DriftRideSessionRepository({
    required this.database,
    required this.telemetryCodec,
  });

  final AppDatabase database;
  final EncryptedTelemetryCodec telemetryCodec;

  @override
  Future<RideSessionSnapshot?> recoverCurrentSession() async {
    final row =
        await (database.select(database.rideSessions)
              ..where((session) => session.endedAt.isNull())
              ..orderBy([(session) => OrderingTerm.desc(session.startedAt)])
              ..limit(1))
            .getSingleOrNull();
    if (row == null) return null;

    if (row.status == RideSessionStatus.recording.name) {
      final recoveredAt = DateTime.now().toUtc();
      await (database.update(
        database.rideSessions,
      )..where((session) => session.id.equals(row.id))).write(
        RideSessionsCompanion(
          status: Value(RideSessionStatus.paused.name),
          pausedAt: Value(recoveredAt),
          syncStatus: const Value('pending'),
        ),
      );
      return _toSnapshot(
        row,
        status: RideSessionStatus.paused,
        pausedAt: recoveredAt,
      );
    }

    if (row.status == RideSessionStatus.paused.name) {
      return _toSnapshot(row, status: RideSessionStatus.paused);
    }
    return null;
  }

  @override
  Future<RideSessionSnapshot> start(DateTime now) async {
    final session = RideSessionsCompanion.insert(
      id: _newSessionId(),
      startedAt: now.toUtc(),
      status: RideSessionStatus.recording.name,
      syncStatus: const Value('pending'),
    );
    await database.into(database.rideSessions).insert(session);
    final row = await (database.select(
      database.rideSessions,
    )..where((item) => item.id.equals(session.id.value))).getSingle();
    return _toSnapshot(row);
  }

  @override
  Future<RideSessionSnapshot> pause(String sessionId, DateTime now) async {
    final row = await _getSession(sessionId);
    if (row.status != RideSessionStatus.recording.name) {
      throw StateError('Only a recording session can be paused.');
    }
    await (database.update(
      database.rideSessions,
    )..where((session) => session.id.equals(sessionId))).write(
      RideSessionsCompanion(
        status: Value(RideSessionStatus.paused.name),
        pausedAt: Value(now.toUtc()),
        syncStatus: const Value('pending'),
      ),
    );
    return _toSnapshot(
      row,
      status: RideSessionStatus.paused,
      pausedAt: now.toUtc(),
    );
  }

  @override
  Future<RideSessionSnapshot> resume(String sessionId, DateTime now) async {
    final row = await _getSession(sessionId);
    if (row.status != RideSessionStatus.paused.name || row.pausedAt == null) {
      throw StateError('Only a paused session can be resumed.');
    }
    final resumedAt = now.toUtc();
    final pausedMilliseconds =
        row.totalPausedMilliseconds +
        resumedAt.difference(row.pausedAt!).inMilliseconds;
    await (database.update(
      database.rideSessions,
    )..where((session) => session.id.equals(sessionId))).write(
      RideSessionsCompanion(
        status: Value(RideSessionStatus.recording.name),
        pausedAt: const Value(null),
        totalPausedMilliseconds: Value(pausedMilliseconds),
        syncStatus: const Value('pending'),
      ),
    );
    return _toSnapshot(
      row,
      status: RideSessionStatus.recording,
      pausedAt: null,
      totalPausedMilliseconds: pausedMilliseconds,
    );
  }

  @override
  Future<RideSessionSnapshot> finish(String sessionId, DateTime now) async {
    final row = await _getSession(sessionId);
    if (row.status == RideSessionStatus.completed.name) {
      throw StateError('The session is already completed.');
    }
    final finishedAt = now.toUtc();
    var pausedMilliseconds = row.totalPausedMilliseconds;
    if (row.status == RideSessionStatus.paused.name && row.pausedAt != null) {
      pausedMilliseconds += finishedAt.difference(row.pausedAt!).inMilliseconds;
    }
    await (database.update(
      database.rideSessions,
    )..where((session) => session.id.equals(sessionId))).write(
      RideSessionsCompanion(
        status: Value(RideSessionStatus.completed.name),
        endedAt: Value(finishedAt),
        pausedAt: const Value(null),
        totalPausedMilliseconds: Value(pausedMilliseconds),
        syncStatus: const Value('pending'),
      ),
    );
    return _toSnapshot(
      row,
      status: RideSessionStatus.completed,
      endedAt: finishedAt,
      pausedAt: null,
      totalPausedMilliseconds: pausedMilliseconds,
    );
  }

  @override
  Future<TelemetryLocation?> latestLocation(String sessionId) async {
    final point =
        await (database.select(database.telemetryPoints)
              ..where((item) => item.sessionId.equals(sessionId))
              ..orderBy([(item) => OrderingTerm.desc(item.recordedAt)])
              ..limit(1))
            .getSingleOrNull();
    if (point == null) return null;
    return telemetryCodec.decode(
      point.encryptedPayload,
      recordedAt: point.recordedAt,
    );
  }

  @override
  Future<RideSessionSnapshot?> recordLocation({
    required String sessionId,
    required TelemetryLocation location,
    required double addedDistanceMeters,
  }) async {
    final encryptedPayload = await telemetryCodec.encode(location);
    return database.transaction(() async {
      final row = await _getSession(sessionId);
      if (row.status != RideSessionStatus.recording.name) return null;

      final distanceMeters = max(
        0,
        row.distanceMeters + addedDistanceMeters,
      ).toDouble();
      final speedMetersPerSecond = max(
        0,
        location.speedMetersPerSecond,
      ).toDouble();

      await database
          .into(database.telemetryPoints)
          .insert(
            TelemetryPointsCompanion.insert(
              sessionId: sessionId,
              recordedAt: location.recordedAt.toUtc(),
              encryptedPayload: encryptedPayload,
            ),
          );
      await (database.update(
        database.rideSessions,
      )..where((session) => session.id.equals(sessionId))).write(
        RideSessionsCompanion(
          distanceMeters: Value(distanceMeters),
          currentSpeedMetersPerSecond: Value(speedMetersPerSecond),
          gpsAccuracyMeters: Value(location.accuracyMeters),
          syncStatus: const Value('pending'),
        ),
      );
      return _toSnapshot(
        row,
        distanceMeters: distanceMeters,
        currentSpeedMetersPerSecond: speedMetersPerSecond,
        gpsAccuracyMeters: location.accuracyMeters,
      );
    });
  }

  Future<RideSession> _getSession(String id) => (database.select(
    database.rideSessions,
  )..where((session) => session.id.equals(id))).getSingle();

  RideSessionSnapshot _toSnapshot(
    RideSession row, {
    RideSessionStatus? status,
    DateTime? endedAt,
    DateTime? pausedAt,
    int? totalPausedMilliseconds,
    double? distanceMeters,
    double? currentSpeedMetersPerSecond,
    double? gpsAccuracyMeters,
  }) {
    return RideSessionSnapshot(
      id: row.id,
      startedAt: row.startedAt,
      endedAt: endedAt ?? row.endedAt,
      pausedAt: pausedAt ?? row.pausedAt,
      status: status ?? _parseStatus(row.status),
      totalPausedMilliseconds:
          totalPausedMilliseconds ?? row.totalPausedMilliseconds,
      distanceMeters: distanceMeters ?? row.distanceMeters,
      currentSpeedMetersPerSecond:
          currentSpeedMetersPerSecond ?? row.currentSpeedMetersPerSecond,
      gpsAccuracyMeters: gpsAccuracyMeters ?? row.gpsAccuracyMeters,
    );
  }

  RideSessionStatus _parseStatus(String value) => switch (value) {
    'recording' => RideSessionStatus.recording,
    'paused' => RideSessionStatus.paused,
    'completed' => RideSessionStatus.completed,
    _ => throw StateError('Unknown ride session status.'),
  };

  String _newSessionId() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0'));
    final value = hex.join();
    return '${value.substring(0, 8)}-${value.substring(8, 12)}-'
        '${value.substring(12, 16)}-${value.substring(16, 20)}-'
        '${value.substring(20)}';
  }
}
