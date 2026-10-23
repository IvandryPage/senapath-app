import 'dart:convert';

import '../../../core/storage/app_database.dart';
import '../domain/interval_workout.dart';

class IntervalWorkoutRepository {
  /// Membuat repositori penyimpanan workout interval pada [database].
  const IntervalWorkoutRepository(this._database);

  static const _workoutsKey = 'interval_workouts_v1';
  static const _selectedWorkoutKey = 'selected_interval_workout_v1';
  static const _checkpointKey = 'active_interval_workout_checkpoint_v1';

  final AppDatabase _database;

  /// Memuat daftar workout interval yang tersimpan di perangkat.
  Future<List<IntervalWorkout>> loadWorkouts() async {
    final value = await _read(_workoutsKey);
    if (value == null) return const [];
    final decoded = jsonDecode(value);
    if (decoded is! List) {
      throw const FormatException('Data workout lokal tidak valid.');
    }
    return decoded
        .map((item) {
          if (item is! Map<String, dynamic>) {
            throw const FormatException('Data workout lokal tidak valid.');
          }
          return IntervalWorkout.fromJson(item);
        })
        .toList(growable: false);
  }

  /// Memuat ID workout interval yang sedang dipilih.
  Future<String?> loadSelectedWorkoutId() => _read(_selectedWorkoutKey);

  /// Menyimpan seluruh daftar [workouts] ke penyimpanan lokal.
  Future<void> saveWorkouts(List<IntervalWorkout> workouts) async {
    await _write(
      _workoutsKey,
      jsonEncode(workouts.map((workout) => workout.toJson()).toList()),
    );
  }

  /// Menyimpan atau menghapus pilihan workout berdasarkan [workoutId].
  Future<void> selectWorkout(String? workoutId) async {
    if (workoutId == null) {
      await _delete(_selectedWorkoutKey);
    } else {
      await _write(_selectedWorkoutKey, workoutId);
    }
  }

  /// Memuat checkpoint workout yang cocok dengan [sessionId].
  Future<WorkoutCheckpoint?> loadCheckpoint(String sessionId) async {
    final value = await _read(_checkpointKey);
    if (value == null) return null;
    final decoded = jsonDecode(value);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Progres workout lokal tidak valid.');
    }
    final checkpoint = WorkoutCheckpoint.fromJson(decoded);
    return checkpoint.sessionId == sessionId ? checkpoint : null;
  }

  /// Menyimpan checkpoint progres workout yang sedang berjalan.
  Future<void> saveCheckpoint(WorkoutCheckpoint checkpoint) =>
      _write(_checkpointKey, jsonEncode(checkpoint.toJson()));

  /// Menghapus checkpoint progres workout yang tersimpan.
  Future<void> clearCheckpoint() => _delete(_checkpointKey);

  /// Membaca nilai preferensi [key] dan mengembalikan null bila tidak ada.
  Future<String?> _read(String key) async {
    final row = await (_database.select(
      _database.appPreferences,
    )..where((item) => item.key.equals(key))).getSingleOrNull();
    return row?.value;
  }

  /// Menyimpan atau menimpa nilai preferensi [key].
  Future<void> _write(String key, String value) async {
    await _database
        .into(_database.appPreferences)
        .insertOnConflictUpdate(
          AppPreferencesCompanion.insert(key: key, value: value),
        );
  }

  /// Menghapus preferensi dengan [key] dari basis data.
  Future<void> _delete(String key) async {
    await (_database.delete(
      _database.appPreferences,
    )..where((item) => item.key.equals(key))).go();
  }
}
