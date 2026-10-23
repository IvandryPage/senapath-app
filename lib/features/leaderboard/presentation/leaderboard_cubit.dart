import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/leaderboard_gateway.dart';
import '../domain/leaderboard_models.dart';
import '../../session/domain/ride_session.dart';

class LeaderboardState {
  /// Membuat state leaderboard dengan kategori dan data awal opsional.
  const LeaderboardState({
    this.category = LeaderboardCategory.duration,
    this.settings,
    this.entries = const [],
    this.isLoading = false,
    this.isSaving = false,
    this.error,
    this.message,
  });

  final LeaderboardCategory category;
  final LeaderboardSettings? settings;
  final List<LeaderboardEntry> entries;
  final bool isLoading;
  final bool isSaving;
  final String? error;
  final String? message;

  /// Menyalin state dengan nilai baru dan opsi menghapus pesan atau error.
  LeaderboardState copyWith({
    LeaderboardCategory? category,
    LeaderboardSettings? settings,
    List<LeaderboardEntry>? entries,
    bool? isLoading,
    bool? isSaving,
    String? error,
    bool clearError = false,
    String? message,
    bool clearMessage = false,
  }) => LeaderboardState(
    category: category ?? this.category,
    settings: settings ?? this.settings,
    entries: entries ?? this.entries,
    isLoading: isLoading ?? this.isLoading,
    isSaving: isSaving ?? this.isSaving,
    error: clearError ? null : error ?? this.error,
    message: clearMessage ? null : message ?? this.message,
  );
}

class LeaderboardCubit extends Cubit<LeaderboardState> {
  /// Membuat cubit leaderboard dengan gateway sebagai sumber data.
  LeaderboardCubit(this._gateway) : super(const LeaderboardState());

  final LeaderboardGateway _gateway;
  int _requestGeneration = 0;
  int _longestDurationSeconds = 0;
  double _longestDistanceMeters = 0;
  bool _isSyncingRecords = false;

  /// Memuat pengaturan dan entri leaderboard sesuai kategori aktif.
  Future<void> load() async {
    final generation = ++_requestGeneration;
    if (!_gateway.isConfigured || !_gateway.isSignedIn) {
      emit(
        LeaderboardState(
          category: state.category,
          error: !_gateway.isConfigured
              ? 'Fitur akun online belum tersedia.'
              : 'Masuk ke akun online untuk melihat papan peringkat.',
        ),
      );
      return;
    }
    emit(state.copyWith(isLoading: true, clearError: true, clearMessage: true));
    try {
      final settings = await _gateway.loadSettings();
      final entries = settings.isOptedIn
          ? await _gateway.loadEntries(state.category)
          : <LeaderboardEntry>[];
      if (isClosed || generation != _requestGeneration) return;
      emit(
        state.copyWith(settings: settings, entries: entries, isLoading: false),
      );
      unawaited(_syncPersonalBest());
    } catch (error) {
      if (isClosed || generation != _requestGeneration) return;
      emit(
        state.copyWith(
          isLoading: false,
          error:
              'Papan peringkat tidak dapat dimuat. Periksa koneksi internet.',
        ),
      );
    }
  }

  /// Mengganti kategori peringkat aktif lalu memuat ulang datanya.
  Future<void> selectCategory(LeaderboardCategory category) async {
    if (state.category == category) return;
    emit(state.copyWith(category: category));
    await load();
  }

  /// Menyimpan persetujuan leaderboard lalu memuat ulang pengaturan dan entri.
  Future<void> saveConsent({required bool isOptedIn}) async {
    if (!_gateway.isConfigured || !_gateway.isSignedIn) {
      await load();
      return;
    }

    final generation = ++_requestGeneration;
    emit(state.copyWith(isSaving: true, clearError: true, clearMessage: true));
    try {
      await _gateway.saveConsent(isOptedIn: isOptedIn);
      final settings = await _gateway.loadSettings();
      final entries = settings.isOptedIn
          ? await _gateway.loadEntries(state.category)
          : <LeaderboardEntry>[];
      if (isClosed || generation != _requestGeneration) return;
      emit(
        state.copyWith(
          settings: settings,
          entries: entries,
          isSaving: false,
          message: isOptedIn
              ? 'Kamu sudah ikut papan peringkat.'
              : 'Kamu berhenti ikut dan hasilmu dihapus dari papan peringkat.',
        ),
      );
      unawaited(_syncPersonalBest());
    } catch (_) {
      if (isClosed || generation != _requestGeneration) return;
      emit(
        state.copyWith(
          isSaving: false,
          error: 'Pengaturan papan peringkat tidak dapat disimpan. Coba lagi.',
        ),
      );
    }
  }

  /// Menghitung rekor durasi dan jarak terbaik dari sesi yang selesai.
  void updateLocalRecords(List<RideSessionSnapshot> sessions) {
    var longestDuration = 0;
    var longestDistance = 0.0;
    for (final session in sessions) {
      if (session.status != RideSessionStatus.completed ||
          session.endedAt == null) {
        continue;
      }
      final durationSeconds = session.durationAt(session.endedAt!).inSeconds;
      if (durationSeconds > longestDuration && durationSeconds <= 172800) {
        longestDuration = durationSeconds;
      }
      if (session.distanceMeters > longestDistance &&
          session.distanceMeters < 1000000) {
        longestDistance = session.distanceMeters;
      }
    }
    _longestDurationSeconds = longestDuration;
    _longestDistanceMeters = longestDistance;
    unawaited(_syncPersonalBest());
  }

  /// Menyinkronkan rekor terbaik ke server, mencegah pengiriman bersamaan.
  Future<void> _syncPersonalBest() async {
    if (_isSyncingRecords ||
        !_gateway.isConfigured ||
        !_gateway.isSignedIn ||
        (_longestDurationSeconds < 1 && _longestDistanceMeters <= 0)) {
      return;
    }
    _isSyncingRecords = true;
    final syncedDuration = _longestDurationSeconds;
    final syncedDistance = _longestDistanceMeters;
    try {
      await _gateway.recordPersonalBest(
        durationSeconds: syncedDuration,
        distanceMeters: syncedDistance,
      );
      if (state.settings?.isOptedIn == true) {
        final entries = await _gateway.loadEntries(state.category);
        if (isClosed || state.settings?.isOptedIn != true) return;
        emit(
          state.copyWith(
            entries: entries,
            clearError: true,
            message: 'Rekor pribadi tersinkron ke leaderboard.',
          ),
        );
      }
    } catch (_) {
      if (!isClosed) {
        emit(
          state.copyWith(
            error: 'Rekor profil belum tersinkron ke akun online. Coba muat ulang saat online.',
            clearMessage: true,
          ),
        );
      }
    } finally {
      _isSyncingRecords = false;
      if (_longestDurationSeconds > syncedDuration ||
          _longestDistanceMeters > syncedDistance) {
        unawaited(_syncPersonalBest());
      }
    }
  }

  /// Membatalkan permintaan lama dan mereset state saat akun berganti.
  void clearForAccountChange() {
    _requestGeneration++;
    emit(const LeaderboardState());
  }
}
