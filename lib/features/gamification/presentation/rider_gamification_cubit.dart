import 'dart:async';

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
    if (state.progress != null) {
      updateSessions(sessions);
      return;
    }
    emit(RiderGamificationState(progress: state.progress, isLoading: true));
    var style = RiderStyle.explorer;
    String? syncError;
    try {
      style = await _repository.loadStyle();
    } catch (_) {
      try {
        style = await _repository.loadLocalStyle();
        syncError = 'Gaya rider cloud tidak dapat dimuat; memakai setelan lokal.';
      } catch (_) {
        if (!isClosed) {
          emit(
            RiderGamificationState(
              progress: state.progress,
              error: 'Progres rider tidak dapat dibuka.',
            ),
          );
        }
        return;
      }
    }
    final progress = RiderProgress.fromSessions(_sessions, style: style);
    if (!isClosed) {
      emit(RiderGamificationState(progress: progress, error: syncError));
    }
    try {
      await _repository.saveCloudProfile(
        style: style,
        level: progress.level,
        experience: progress.experience,
      );
    } catch (_) {
      if (!isClosed) {
        emit(
          RiderGamificationState(
            progress: progress,
            error: 'Progres rider tersimpan lokal; sinkronisasi cloud gagal.',
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
    final updated = state.progress!;
    unawaited(_syncProfile(updated));
  }

  void clearForAccountChange() {
    emit(const RiderGamificationState());
  }

  Future<void> setStyle(RiderStyle style) async {
    final current = state.progress;
    if (current == null || state.isSaving) return;
    emit(RiderGamificationState(progress: current, isSaving: true));
    try {
      await _repository.saveStyle(style);
      final updated = RiderProgress.fromSessions(_sessions, style: style);
      if (!isClosed) {
        emit(RiderGamificationState(progress: updated));
      }
      await _repository.saveCloudProfile(
        style: updated.style,
        level: updated.level,
        experience: updated.experience,
      );
    } catch (_) {
      final updated = RiderProgress.fromSessions(_sessions, style: style);
      if (!isClosed) {
        emit(
          RiderGamificationState(
            progress: updated,
            error: 'Gaya tersimpan lokal; sinkronisasi ke cloud gagal.',
          ),
        );
      }
    }
  }

  Future<void> _syncProfile(RiderProgress progress) async {
    try {
      await _repository.saveCloudProfile(
        style: progress.style,
        level: progress.level,
        experience: progress.experience,
      );
    } catch (_) {
      if (!isClosed) {
        emit(
          RiderGamificationState(
            progress: progress,
            error: 'Progres rider belum tersinkron ke cloud.',
          ),
        );
      }
    }
  }
}
