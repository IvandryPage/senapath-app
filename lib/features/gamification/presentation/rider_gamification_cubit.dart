import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../session/domain/ride_session.dart';
import '../data/rider_profile_repository.dart';
import '../domain/rider_progress.dart';

class RiderGamificationState {
  const RiderGamificationState({
    this.progress,
    this.appearance = const RiderAppearance(),
    this.isLoading = false,
    this.isSaving = false,
    this.error,
  });

  final RiderProgress? progress;
  final RiderAppearance appearance;
  final bool isLoading;
  final bool isSaving;
  final String? error;
}

class RiderGamificationCubit extends Cubit<RiderGamificationState> {
  RiderGamificationCubit(this._repository)
    : super(const RiderGamificationState());

  final RiderProfileRepository _repository;
  List<RideSessionSnapshot> _sessions = const [];
  RiderStyle? _pendingCyclistType;

  Future<void> load(List<RideSessionSnapshot> sessions) async {
    _sessions = sessions;
    if (state.isLoading) return;
    if (state.progress != null) {
      updateSessions(sessions);
      return;
    }
    emit(
      RiderGamificationState(
        progress: state.progress,
        appearance: state.appearance,
        isLoading: true,
      ),
    );
    var style = RiderStyle.explorer;
    var appearance = state.appearance;
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
    final pendingCyclistType = _pendingCyclistType;
    if (pendingCyclistType != null) {
      style = pendingCyclistType;
      _pendingCyclistType = null;
    }
    try {
      appearance = await _repository.loadAppearance();
    } catch (_) {
      syncError = 'Tampilan rider tersimpan tidak dapat dimuat.';
    }
    final progress = RiderProgress.fromSessions(_sessions, style: style);
    if (!isClosed) {
      emit(
        RiderGamificationState(
          progress: progress,
          appearance: appearance,
          error: syncError,
        ),
      );
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
            appearance: appearance,
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
        appearance: state.appearance,
      ),
    );
    final updated = state.progress!;
    unawaited(_syncProfile(updated));
  }

  void clearForAccountChange() {
    emit(const RiderGamificationState());
  }

  Future<void> applyCyclistType(RiderStyle style) async {
    final current = state.progress;
    if (state.isSaving) return;
    _pendingCyclistType = style;
    if (current == null) {
      try {
        await _repository.saveStyle(style);
        _pendingCyclistType = null;
      } catch (_) {
        if (!isClosed) {
          emit(
            RiderGamificationState(
              appearance: state.appearance,
              error:
                  'Tipe pesepeda tersimpan di profil, tetapi rider tidak dapat diperbarui.',
            ),
          );
        }
      }
      return;
    }
    emit(
      RiderGamificationState(
        progress: current,
        appearance: state.appearance,
        isSaving: true,
      ),
    );
    try {
      await _repository.saveStyle(style);
      _pendingCyclistType = null;
      final updated = RiderProgress.fromSessions(_sessions, style: style);
      if (!isClosed) {
        emit(
          RiderGamificationState(
            progress: updated,
            appearance: state.appearance,
          ),
        );
      }
    } catch (_) {
      if (!isClosed) {
        emit(
          RiderGamificationState(
            progress: current,
            appearance: state.appearance,
            error: 'Tipe pesepeda tersimpan di profil, tetapi progres rider tidak dapat diperbarui.',
          ),
        );
      }
    }
  }

  Future<void> setAppearance(RiderAppearance appearance) async {
    if (state.progress == null || state.isSaving) return;
    final progress = state.progress!;
    emit(
      RiderGamificationState(
        progress: progress,
        appearance: state.appearance,
        isSaving: true,
      ),
    );
    try {
      await _repository.saveAppearance(appearance);
      if (!isClosed) {
        emit(RiderGamificationState(progress: progress, appearance: appearance));
      }
    } catch (_) {
      if (!isClosed) {
        emit(
          RiderGamificationState(
            progress: progress,
            appearance: state.appearance,
            error: 'Tampilan rider tidak dapat disimpan.',
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
            appearance: state.appearance,
            error: 'Progres rider belum tersinkron ke cloud.',
          ),
        );
      }
    }
  }
}
