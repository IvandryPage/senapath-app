import 'package:drift/drift.dart';

import '../../../core/storage/app_database.dart';
import '../../session/domain/ride_session.dart';
import '../domain/ride_history_entry.dart';
import '../domain/ride_time_predictor.dart';

class RideHistoryRepository {
  static const _backfillPreferenceKey = 'ride_history_backfill_v1';

  /// Membuat repositori dengan [database] dan [predictor] opsional.
  const RideHistoryRepository(
    this._database, {
    this._predictor = const RideTimePredictor(),
  });

  final AppDatabase _database;
  final RideTimePredictor _predictor;

  /// Menyimpan ringkasan perjalanan selesai bila fitur-fiturnya valid.
  Future<void> recordCompletedRide(RideSessionSummary summary) async {
    final session = summary.session;
    final endedAt = session.endedAt;
    final distanceKm = session.distanceMeters / 1000;
    final elevationGainMeters = summary.elevationGainMeters;
    final durationMinutes =
        session.durationAt(endedAt ?? session.startedAt).inSeconds / 60;
    if (endedAt == null ||
        !distanceKm.isFinite ||
        distanceKm <= 0 ||
        elevationGainMeters == null ||
        !elevationGainMeters.isFinite ||
        elevationGainMeters < 0 ||
        !durationMinutes.isFinite ||
        durationMinutes <= 0) {
      return;
    }

    await _database
        .into(_database.rideHistory)
        .insertOnConflictUpdate(
          RideHistoryCompanion.insert(
            sessionId: session.id,
            distanceKm: distanceKm,
            elevationGainMeters: elevationGainMeters,
            elevationPerDistance: elevationGainMeters / distanceKm,
            durationMinutes: durationMinutes,
            completedAt: endedAt,
          ),
        );
  }

  /// Memuat seluruh riwayat perjalanan, terbaru lebih dahulu.
  Future<List<RideHistoryEntry>> loadHistory() async {
    final rows = await (_database.select(
      _database.rideHistory,
    )..orderBy([(entry) => OrderingTerm.desc(entry.completedAt)])).get();
    return [
      for (final row in rows)
        RideHistoryEntry(
          sessionId: row.sessionId,
          distanceKm: row.distanceKm,
          elevationGainMeters: row.elevationGainMeters,
          elevationPerDistance: row.elevationPerDistance,
          durationMinutes: row.durationMinutes,
          completedAt: row.completedAt,
        ),
    ];
  }

  /// Mengisi riwayat dari sesi selesai lama yang belum tercatat sekali saja.
  Future<void> backfillCompletedRides({
    required List<RideSessionSnapshot> sessions,
    required Future<RideSessionSummary> Function(String sessionId) loadSummary,
  }) async {
    final backfillState =
        await (_database.select(_database.appPreferences)..where(
              (preference) => preference.key.equals(_backfillPreferenceKey),
            ))
            .getSingleOrNull();
    if (backfillState?.value == 'complete') return;

    final storedRows = await _database.select(_database.rideHistory).get();
    final storedSessionIds = storedRows.map((row) => row.sessionId).toSet();
    for (final session in sessions) {
      if (session.status != RideSessionStatus.completed ||
          session.endedAt == null ||
          storedSessionIds.contains(session.id)) {
        continue;
      }
      await recordCompletedRide(await loadSummary(session.id));
    }

    await _database
        .into(_database.appPreferences)
        .insertOnConflictUpdate(
          AppPreferencesCompanion.insert(
            key: _backfillPreferenceKey,
            value: 'complete',
          ),
        );
  }

  /// Memprediksi durasi berdasarkan riwayat lokal dan parameter rute.
  Future<RideTimePrediction?> predict({
    required double distanceKm,
    required double elevationGainMeters,
  }) async => _predictor.predict(
    distanceKm: distanceKm,
    elevationGainMeters: elevationGainMeters,
    history: await loadHistory(),
  );

  /// Menghapus entri riwayat untuk sesi [sessionId].
  Future<void> deleteRide(String sessionId) async {
    await (_database.delete(
      _database.rideHistory,
    )..where((entry) => entry.sessionId.equals(sessionId))).go();
  }
}
