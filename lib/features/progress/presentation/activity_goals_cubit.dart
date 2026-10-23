import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/validation/validators.dart';
import '../data/activity_goals_repository.dart';
import '../domain/activity_progress.dart';

class ActivityGoalsState {
  /// Membuat keadaan awal daftar target aktivitas.
  const ActivityGoalsState({
    this.goals = const [],
    this.isLoading = false,
    this.isSaving = false,
    this.isLoaded = false,
    this.error,
  });

  final List<ActivityGoal> goals;
  final bool isLoading;
  final bool isSaving;
  final bool isLoaded;
  final String? error;
}

class ActivityGoalsCubit extends Cubit<ActivityGoalsState> {
  /// Membuat cubit target aktivitas dengan repositori penyimpanan.
  ActivityGoalsCubit(this._repository) : super(const ActivityGoalsState());

  final ActivityGoalsRepository _repository;

  /// Memuat target aktivitas sekali dan menangani kegagalan baca.
  Future<void> load() async {
    if (state.isLoading || state.isLoaded) return;
    emit(ActivityGoalsState(goals: state.goals, isLoading: true));
    try {
      final goals = await _repository.load();
      if (!isClosed) emit(ActivityGoalsState(goals: goals, isLoaded: true));
    } catch (_) {
      if (!isClosed) {
        emit(
          ActivityGoalsState(
            goals: state.goals,
            error: 'Target aktivitas lokal tidak dapat dibuka.',
          ),
        );
      }
    }
  }

  /// Memvalidasi target lalu menambah atau memperbarui target pada daftar.
  Future<void> upsert(ActivityGoal goal) async {
    final maxTarget = switch (goal.metric) {
      GoalMetric.completedSessions => InputLimits.goalSessionsMax,
      GoalMetric.distanceMeters => InputLimits.goalDistanceKmMax * 1000,
      GoalMetric.activeSeconds => InputLimits.goalActiveHoursMax * 3600,
    };
    if (goal.id.trim().isEmpty ||
        !goal.target.isFinite ||
        goal.target <= 0 ||
        goal.target > maxTarget) {
      throw ArgumentError.value(
        goal.target,
        'target',
        'Use a positive target within the allowed limit.',
      );
    }
    final index = state.goals.indexWhere((item) => item.id == goal.id);
    final updated = [...state.goals];
    if (index < 0) {
      updated.add(goal);
    } else {
      updated[index] = goal;
    }
    await _persist(updated);
  }

  /// Menghapus target berdasarkan id lalu menyimpan daftar terbaru.
  Future<void> remove(String id) async {
    final updated = state.goals.where((goal) => goal.id != id).toList();
    await _persist(updated);
  }

  /// Menyimpan daftar target sambil mengatur status simpan dan pesan galat.
  Future<void> _persist(List<ActivityGoal> updated) async {
    if (state.isSaving) return;
    emit(
      ActivityGoalsState(
        goals: state.goals,
        isSaving: true,
        isLoaded: state.isLoaded,
      ),
    );
    try {
      await _repository.save(updated);
      if (!isClosed) emit(ActivityGoalsState(goals: updated));
    } catch (_) {
      if (!isClosed) {
        emit(
          ActivityGoalsState(
            goals: state.goals,
            isLoaded: state.isLoaded,
            error: 'Target aktivitas tidak dapat disimpan.',
          ),
        );
      }
    }
  }
}
