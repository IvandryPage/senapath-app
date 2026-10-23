import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'app_database.g.dart';

class AppPreferences extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  /// Menetapkan kolom key sebagai kunci utama preferensi.
  @override
  Set<Column<Object>> get primaryKey => {key};
}

class RideSessions extends Table {
  TextColumn get id => text()();
  TextColumn get title => text().withDefault(const Constant(''))();
  TextColumn get activityType => text().withDefault(const Constant('ride'))();
  TextColumn get source => text().withDefault(const Constant('recorded'))();
  DateTimeColumn get startedAt => dateTime()();
  DateTimeColumn get endedAt => dateTime().nullable()();
  DateTimeColumn get pausedAt => dateTime().nullable()();
  IntColumn get totalPausedMilliseconds =>
      integer().withDefault(const Constant(0))();
  TextColumn get status => text()();
  TextColumn get syncStatus => text().withDefault(const Constant('pending'))();
  RealColumn get distanceMeters => real().withDefault(const Constant(0))();
  RealColumn get currentSpeedMetersPerSecond =>
      real().withDefault(const Constant(0))();
  RealColumn get gpsAccuracyMeters => real().nullable()();

  /// Menetapkan kolom id sesi sebagai kunci utama.
  @override
  Set<Column<Object>> get primaryKey => {id};
}

class TelemetryPoints extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get sessionId => text().references(RideSessions, #id)();
  DateTimeColumn get recordedAt => dateTime()();
  BlobColumn get encryptedPayload => blob()();
}

class SavedRoutes extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get source => text()();
  TextColumn get description => text().withDefault(const Constant(''))();
  DateTimeColumn get updatedAt => dateTime()();
  RealColumn get distanceMeters => real().nullable()();
  RealColumn get elevationGainMeters => real().nullable()();
  TextColumn get poiSummary => text().withDefault(const Constant(''))();
  TextColumn get availability =>
      text().withDefault(const Constant('offline'))();
  BlobColumn get encryptedGeometry => blob().nullable()();

  /// Menetapkan kolom id rute tersimpan sebagai kunci utama.
  @override
  Set<Column<Object>> get primaryKey => {id};
}

class RideHistory extends Table {
  TextColumn get sessionId => text()();
  RealColumn get distanceKm => real()();
  RealColumn get elevationGainMeters => real()();
  RealColumn get elevationPerDistance => real()();
  RealColumn get durationMinutes => real()();
  DateTimeColumn get completedAt => dateTime()();

  /// Menetapkan kolom sessionId sebagai kunci utama riwayat perjalanan.
  @override
  Set<Column<Object>> get primaryKey => {sessionId};
}

@DriftDatabase(
  tables: [
    AppPreferences,
    RideSessions,
    TelemetryPoints,
    SavedRoutes,
    RideHistory,
  ],
)
class AppDatabase extends _$AppDatabase {
  /// Membuka basis data lokal Drift bernama `senapath`.
  AppDatabase() : super(driftDatabase(name: 'senapath'));

  /// Membuat basis data dengan executor khusus untuk pengujian.
  AppDatabase.forTesting(super.executor);

  /// Menunjukkan versi skema basis data yang sedang dipakai.
  @override
  int get schemaVersion => 9;

  /// Mendefinisikan pembuatan tabel awal dan migrasi bertahap antar versi.
  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (migrator) => migrator.createAll(),
    onUpgrade: (migrator, from, to) async {
      if (from < 2) {
        await migrator.createTable(rideSessions);
        await migrator.createTable(telemetryPoints);
      }
      if (from < 3) {
        await migrator.createTable(savedRoutes);
      }
      if (from < 5) {
        await migrator.addColumn(savedRoutes, savedRoutes.description);
      }
      if (from < 7) {
        await migrator.addColumn(rideSessions, rideSessions.title);
        await migrator.addColumn(rideSessions, rideSessions.activityType);
        await migrator.addColumn(rideSessions, rideSessions.source);
      }
      if (from < 8) {
        await customStatement('DROP TABLE IF EXISTS reaction_test_results');
        await customStatement('DROP TABLE IF EXISTS strategy_game_results');
      }
      if (from < 9) {
        await migrator.createTable(rideHistory);
      }
    },
  );
}
