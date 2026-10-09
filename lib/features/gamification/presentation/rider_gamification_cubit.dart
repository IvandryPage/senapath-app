import 'package:flutter_bloc/flutter_bloc.dart';

import '../../session/domain/ride_session.dart';
import '../data/rider_profile_repository.dart';
import '../domain/rider_progress.dart';

class RiderGamificationState {
  const RiderGamificationState({
    this.progress,
    this.isLoading = false,
    this.isSaving = false,
    this.error,
  });

  final RiderProgress? progress;
  final bool isLoading;
  final bool isSaving;
  final String? error;
}

class RiderGamificationCubit extends Cubit<RiderGamificationState> {
  RiderGamificationCubit(this._repository)
    : super(const RiderGamificationState());

  final RiderProfileRepository _repository;
  List<RideSessionSnapshot> _sessions = const [];

  Future<void> load(List<RideSessionSnapshot> sessions) async {
    _sessions = sessions;
    if (state.isLoading) return;
    emit(RiderGamificationState(progress: state.progress, isLoading: true));
    try {
      final style = await _repository.loadStyle();
      if (!isClosed) {
        emit(
          RiderGamificationState(
            progress: RiderProgress.fromSessions(_sessions, style: style),
          ),
        );
      }
    } catch (_) {
      if (!isClosed) {
        emit(
          RiderGamificationState(
            progress: state.progress,
            error: 'Progres rider tidak dapat dibuka.',
          ),
        );
      }
    }
  }

  void updateSessions(List<RideSessionSnapshot> sessions) {
    _sessions = sessions;
    final progress = state.progress;
    if (progress == null) return;
    emit(
      RiderGamificationState(
        progress: RiderProgress.fromSessions(sessions, style: progress.style),
      ),
    );
  }

  Future<void> setStyle(RiderStyle style) async {
    final current = state.progress;
    if (current == null || state.isSaving) return;
    emit(RiderGamificationState(progress: current, isSaving: true));
    try {
      await _repository.saveStyle(style);
      if (!isClosed) {
        emit(
          RiderGamificationState(
            progress: RiderProgress.fromSessions(_sessions, style: style),
          ),
        );
      }
    } catch (_) {
      if (!isClosed) {
        emit(
          RiderGamificationState(
            progress: current,
            error: 'Gaya rider tidak dapat disimpan.',
          ),
        );
      }
    }
  }
}
