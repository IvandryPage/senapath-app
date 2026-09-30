import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'app_database.g.dart';

class AppPreferences extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column<Object>> get primaryKey => {key};
}

@DriftDatabase(tables: [AppPreferences])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(driftDatabase(name: 'senapath'));

  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 1;
}
