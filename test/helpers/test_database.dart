import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:senapath/core/storage/app_database.dart';

/// Creates an isolated in-memory database for tests.
AppDatabase createTestDatabase() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  return AppDatabase.forTesting(NativeDatabase.memory());
}
