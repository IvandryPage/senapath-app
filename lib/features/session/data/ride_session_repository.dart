import 'dart:math';

import 'package:drift/drift.dart';

import '../../../core/storage/app_database.dart';
import '../domain/ride_session.dart';
import 'encrypted_telemetry_codec.dart';

abstract interface class RideSessionRepository {
  Future<RideSessionSnapshot?> recoverCurrentSession();
  Future<List<RideSessionSnapshot>> loadCompletedSessions();
  Future<RideSessionSummary> loadSummary(String sessionId);
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
  Future<List<RideSessionSnapshot>> loadCompletedSessions() async {
    final rows =
        await (database.select(database.rideSessions)
              ..where(
                (session) =>
                    session.status.equals(RideSessionStatus.completed.name),
              )
              ..orderBy([(session) => OrderingTerm.desc(session.endedAt)])
              ..limit(50))
            .get();
    return rows.map(_toSnapshot).toList(growable: false);
  }

  @override
  Future<RideSessionSummary> loadSummary(String sessionId) async {
    final row = await _getSession(sessionId);
    final session = _toSnapshot(row);
    final points =
        await (database.select(database.telemetryPoints)
              ..where((point) => point.sessionId.equals(sessionId))
              ..orderBy([(point) => OrderingTerm.asc(point.recordedAt)]))
            .get();

    final locations = <TelemetryLocation>[];
    for (final point in points) {
      locations.add(
        await telemetryCodec.decode(
          point.encryptedPayload,
          recordedAt: point.recordedAt,
        ),
      );
    }

    final pressureSamples = locations
        .where(
          (location) =>
              location.barometricPressureHpa != null &&
              location.barometricPressureHpa! >= 300 &&
              location.barometricPressureHpa! <= 1100,
        )
        .toList(growable: false);
    double? elevationGainMeters;
    var elevationSource = 'Tidak tersedia';
    if (pressureSamples.length >= 3) {
      elevationGainMeters = _calculateElevationGain(
        pressureSamples
            .map((location) => location.barometricPressureHpa!)
            .toList(growable: false),
        minimumStepMeters: 1,
        isPressure: true,
      );
      elevationSource = 'Barometer';
    } else {
      final gpsAltitudes = locations
          .where(
            (location) =>
                location.altitudeAccuracyMeters != null &&
                location.altitudeAccuracyMeters! > 0 &&
                location.altitudeAccuracyMeters! <= 25 &&
                location.altitudeMeters.isFinite,
          )
          .map((location) => location.altitudeMeters)
          .toList(growable: false);
      if (gpsAltitudes.length >= 3) {
        elevationGainMeters = _calculateElevationGain(
          gpsAltitudes,
          minimumStepMeters: 3,
          isPressure: false,
        );
        elevationSource = 'Estimasi GPS';
      }
    }

    final speedSamples = locations
        .where(
          (location) =>
              location.speedMetersPerSecond.isFinite &&
              location.speedMetersPerSecond >= 0,
        )
        .map(
          (location) => RideSpeedSample(
            recordedAt: location.recordedAt,
            speedMetersPerSecond: location.speedMetersPerSecond,
          ),
        )
        .toList(growable: false);
    final accelerometerSampleCount = locations
        .where(
          (location) =>
              location.accelerationMagnitudeMetersPerSecondSquared != null,
        )
        .length;
    final gyroscopeSampleCount = locations
        .where(
          (location) => location.rotationRateMagnitudeRadiansPerSecond != null,
        )
        .length;

    return RideSessionSummary(
      session: session,
      sampleCount: locations.length,
      speedSamples: speedSamples,
      elevationGainMeters: elevationGainMeters,
      elevationSource: elevationSource,
      accelerometerSampleCount: accelerometerSampleCount,
      gyroscopeSampleCount: gyroscopeSampleCount,
    );
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
      syncStatus: row.syncStatus,
      gpsAccuracyMeters: gpsAccuracyMeters ?? row.gpsAccuracyMeters,
    );
  }

  double _calculateElevationGain(
    List<double> values, {
    required double minimumStepMeters,
    required bool isPressure,
  }) {
    if (values.length < 3) return 0;
    final elevations = isPressure
        ? values
              .map(
                (pressure) =>
                    44330 * (1 - pow(pressure / values.first, 0.190294957)),
              )
              .map((value) => value.toDouble())
              .toList(growable: false)
        : values;
    var totalAscent = 0.0;
    var previous = elevations.first;
    for (final elevation in elevations.skip(1)) {
      final change = elevation - previous;
      if (change >= minimumStepMeters) totalAscent += change;
      previous = elevation;
    }
    return totalAscent;
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
