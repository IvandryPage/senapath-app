import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../account_sync/data/account_cloud_gateway.dart';
import '../../session/domain/ride_session.dart';
import '../data/rider_profile_repository.dart';
import '../domain/rider_progress.dart';

class RiderGamificationState {
  /// Membuat state gamifikasi rider dengan nilai awal opsional.
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
  /// Membuat cubit gamifikasi dengan repositori profil rider sebagai sumber data.
  RiderGamificationCubit(this._repository)
    : super(const RiderGamificationState());

  final RiderProfileRepository _repository;
  List<RideSessionSnapshot> _sessions = const [];
  RiderStyle? _pendingCyclistType;
  int _bonusExperience = 0;

  /// Memuat progres, gaya, tampilan, dan bonus experience dari data sesi.
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
        syncError = 'Gaya pesepeda tidak dapat dimuat dari akun online. Menampilkan setelan di ponsel.';
      } catch (_) {
        if (!isClosed) {
          emit(
            RiderGamificationState(
              progress: state.progress,
              error: 'Progres pesepeda tidak dapat dibuka.',
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
      syncError = 'Tampilan pesepeda yang tersimpan tidak dapat dimuat.';
    }
    try {
      _bonusExperience = await _repository.loadBonusExperience();
    } catch (_) {
      _bonusExperience = 0;
    }
    var progress = RiderProgress.fromSessions(
      _sessions,
      style: style,
      bonusExperience: _bonusExperience,
    );
    try {
      final cloud = await _repository.loadCloudProgress();
      if (cloud != null) {
        style = cloud.style;
        appearance = cloud.appearance ?? appearance;
        await _repository.saveStyle(style);
        progress = _mergeCloudProgress(progress, cloud);
      }
    } catch (_) {
      syncError = 'Progres pesepeda dari akun online tidak dapat dimuat; memakai data di ponsel.';
    }
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
      await _repository.saveCloudProgress(progress, appearance);
    } catch (_) {
      if (!isClosed) {
        emit(
          RiderGamificationState(
            progress: progress,
            appearance: appearance,
            error: 'Progres pesepeda tersimpan di ponsel, tetapi belum tersimpan di akun online.',
          ),
        );
      }
    }
  }

  /// Menggabungkan progres lokal dan cloud dengan mengambil nilai tertinggi.
  RiderProgress _mergeCloudProgress(
    RiderProgress local,
    CloudRiderProgress cloud,
  ) {
    final experience = math.max(local.experience, cloud.experience);
    return RiderProgress(
      experience: experience,
      level: experience ~/ RiderProgress.experiencePerLevel + 1,
      distanceMeters: math.max(local.distanceMeters, cloud.distanceMeters),
      completedRides: math.max(local.completedRides, cloud.completedRides),
      style: cloud.style,
      rideDurationSeconds: math.max(
        local.rideDurationSeconds,
        cloud.rideDurationSeconds,
      ),
      longestRideMeters: local.longestRideMeters,
      weekendRides: math.max(local.weekendRides, cloud.weekendRides),
      bonusExperience: local.bonusExperience,
    );
  }

  /// Menghitung ulang progres dari daftar sesi terbaru lalu menyinkronkannya.
  void updateSessions(List<RideSessionSnapshot> sessions) {
    _sessions = sessions;
    final progress = state.progress;
    if (progress == null) return;
    emit(
      RiderGamificationState(
        progress: RiderProgress.fromSessions(
          sessions,
          style: progress.style,
          bonusExperience: _bonusExperience,
        ),
        appearance: state.appearance,
      ),
    );
    final updated = state.progress!;
    unawaited(_syncProfile(updated));
  }

  /// Mengosongkan state gamifikasi saat akun pengguna berganti.
  void clearForAccountChange() {
    emit(const RiderGamificationState());
  }

  /// Menerapkan tipe pesepeda baru dan memperbarui progres jika sudah dimuat.
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
              error: 'Tipe pesepeda tersimpan di profil, tetapi rider tidak dapat diperbarui.',
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
      final updated = RiderProgress.fromSessions(
        _sessions,
        style: style,
        bonusExperience: _bonusExperience,
      );
      if (!isClosed) {
        emit(
          RiderGamificationState(
            progress: updated,
            appearance: state.appearance,
          ),
        );
      }
      unawaited(_syncProfile(updated));
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

  /// Menyimpan tampilan rider baru lalu menyinkronkan profil ke cloud.
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
        emit(
          RiderGamificationState(progress: progress, appearance: appearance),
        );
      }
      unawaited(_syncProfile(progress));
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

  /// Menambahkan experience bonus, memperbarui level, lalu menyimpannya.
  Future<void> awardExperience(int amount) async {
    if (amount <= 0) return;
    _bonusExperience += amount;
    final progress = state.progress;
    if (progress == null) {
      try {
        await _repository.saveBonusExperience(_bonusExperience);
      } catch (_) {}
      return;
    }
    final experience = progress.experience + amount;
    final updated = RiderProgress(
      experience: experience,
      level: experience ~/ RiderProgress.experiencePerLevel + 1,
      distanceMeters: progress.distanceMeters,
      completedRides: progress.completedRides,
      style: progress.style,
      rideDurationSeconds: progress.rideDurationSeconds,
      longestRideMeters: progress.longestRideMeters,
      weekendRides: progress.weekendRides,
      bonusExperience: _bonusExperience,
    );
    emit(
      RiderGamificationState(progress: updated, appearance: state.appearance),
    );
    try {
      await _repository.saveBonusExperience(_bonusExperience);
    } catch (_) {}
    unawaited(_syncProfile(updated));
  }

  /// Menyinkronkan progres ke cloud dan melaporkan kegagalan lewat state.
  Future<void> _syncProfile(RiderProgress progress) async {
    try {
      await _repository.saveCloudProgress(progress, state.appearance);
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
