import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/interval_workout_repository.dart';
import '../domain/interval_workout.dart';

class IntervalWorkoutState {
  const IntervalWorkoutState({
    this.workouts = const [],
    this.selectedWorkoutId,
    this.isLoading = false,
    this.error,
  });

  final List<IntervalWorkout> workouts;
  final String? selectedWorkoutId;
  final bool isLoading;
  final String? error;

  IntervalWorkout? get selectedWorkout {
    for (final workout in workouts) {
      if (workout.id == selectedWorkoutId) return workout;
    }
    return null;
  }
}

class IntervalWorkoutCubit extends Cubit<IntervalWorkoutState> {
  IntervalWorkoutCubit(this._repository)
    : super(const IntervalWorkoutState(isLoading: true));

  final IntervalWorkoutRepository _repository;
  bool _loading = false;

  Future<void> load() async {
    if (_loading) return;
    _loading = true;
    try {
      final workouts = await _repository.loadWorkouts();
      final selectedId = await _repository.loadSelectedWorkoutId();
      final selectedExists = workouts.any(
        (workout) => workout.id == selectedId,
      );
      emit(
        IntervalWorkoutState(
          workouts: workouts,
          selectedWorkoutId: selectedExists ? selectedId : null,
        ),
      );
      if (!selectedExists && selectedId != null) {
        await _repository.selectWorkout(null);
      }
    } catch (_) {
      emit(
        const IntervalWorkoutState(error: 'Workout lokal tidak dapat dimuat.'),
      );
    } finally {
      _loading = false;
    }
  }

  Future<void> save(IntervalWorkout workout) async {
    final updated = [...state.workouts];
    final index = updated.indexWhere((item) => item.id == workout.id);
    if (index < 0) {
      updated.add(workout);
    } else {
      updated[index] = workout;
    }
    await _save(updated);
  }

  Future<void> remove(String workoutId) async {
    final updated = state.workouts
        .where((workout) => workout.id != workoutId)
        .toList(growable: false);
    try {
      await _repository.saveWorkouts(updated);
      final selectedId = state.selectedWorkoutId == workoutId
          ? null
          : state.selectedWorkoutId;
      if (selectedId == null && state.selectedWorkoutId == workoutId) {
        await _repository.selectWorkout(null);
      }
      emit(
        IntervalWorkoutState(workouts: updated, selectedWorkoutId: selectedId),
      );
    } catch (_) {
      emit(
        IntervalWorkoutState(
          workouts: state.workouts,
          selectedWorkoutId: state.selectedWorkoutId,
          error: 'Workout tidak dapat dihapus.',
        ),
      );
    }
  }

  Future<void> select(String? workoutId) async {
    if (workoutId != null &&
        !state.workouts.any((workout) => workout.id == workoutId)) {
      throw ArgumentError.value(workoutId, 'workoutId');
    }
    try {
      await _repository.selectWorkout(workoutId);
      emit(
        IntervalWorkoutState(
          workouts: state.workouts,
          selectedWorkoutId: workoutId,
        ),
      );
    } catch (_) {
      emit(
        IntervalWorkoutState(
          workouts: state.workouts,
          selectedWorkoutId: state.selectedWorkoutId,
          error: 'Pilihan workout tidak dapat disimpan.',
        ),
      );
    }
  }

  Future<void> _save(List<IntervalWorkout> updated) async {
    try {
      await _repository.saveWorkouts(updated);
      emit(
        IntervalWorkoutState(
          workouts: updated,
          selectedWorkoutId: state.selectedWorkoutId,
        ),
      );
    } catch (_) {
      emit(
        IntervalWorkoutState(
          workouts: state.workouts,
          selectedWorkoutId: state.selectedWorkoutId,
          error: 'Workout tidak dapat disimpan.',
        ),
      );
    }
  }
}
