import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'app_database.g.dart';

class AppPreferences extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column<Object>> get primaryKey => {key};
}

class RideSessions extends Table {
  TextColumn get id => text()();
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

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class ReactionTestResults extends Table {
  TextColumn get id => text()();
  DateTimeColumn get completedAt => dateTime()();
  TextColumn get resultJson => text()();
  TextColumn get syncStatus => text().withDefault(const Constant('pending'))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class StrategyGameResults extends Table {
  TextColumn get id => text()();
  DateTimeColumn get playedAt => dateTime()();
  TextColumn get resultJson => text()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DriftDatabase(
  tables: [
    AppPreferences,
    RideSessions,
    TelemetryPoints,
    SavedRoutes,
    ReactionTestResults,
    StrategyGameResults,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(driftDatabase(name: 'senapath'));

  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 6;

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
      if (from < 4) {
        await migrator.createTable(reactionTestResults);
      }
      if (from < 5) {
        await migrator.addColumn(savedRoutes, savedRoutes.description);
      }
      if (from < 6) {
        await migrator.createTable(strategyGameResults);
      }
    },
  );
}
