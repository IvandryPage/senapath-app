import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/leaderboard_gateway.dart';
import '../domain/leaderboard_models.dart';

class LeaderboardState {
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
  LeaderboardCubit(this._gateway) : super(const LeaderboardState());

  final LeaderboardGateway _gateway;
  int _requestGeneration = 0;

  Future<void> load() async {
    final generation = ++_requestGeneration;
    if (!_gateway.isConfigured || !_gateway.isSignedIn) {
      emit(
        LeaderboardState(
          category: state.category,
          error: !_gateway.isConfigured
              ? 'Akun online belum tersedia karena Supabase belum dikonfigurasi.'
              : 'Masuk ke akun online untuk melihat leaderboard.',
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
    } catch (_) {
      if (isClosed || generation != _requestGeneration) return;
      emit(
        state.copyWith(
          isLoading: false,
          error: 'Leaderboard gagal dimuat. Periksa koneksi dan coba lagi.',
        ),
      );
    }
  }

  Future<void> selectCategory(LeaderboardCategory category) async {
    if (state.category == category) return;
    emit(state.copyWith(category: category));
    await load();
  }

  Future<void> saveConsent({
    required String alias,
    required bool isOptedIn,
  }) async {
    final cleanedAlias = alias.trim();
    if (isOptedIn &&
        (cleanedAlias.length < 3 ||
            cleanedAlias.length > 24 ||
            !RegExp(r'^[A-Za-z0-9 _-]+$').hasMatch(cleanedAlias))) {
      emit(
        state.copyWith(
          error: 'Alias harus 3–24 karakter: huruf, angka, spasi, - atau _.',
          clearMessage: true,
        ),
      );
      return;
    }
    if (!_gateway.isConfigured || !_gateway.isSignedIn) {
      await load();
      return;
    }

    final generation = ++_requestGeneration;
    emit(state.copyWith(isSaving: true, clearError: true, clearMessage: true));
    try {
      await _gateway.saveConsent(alias: cleanedAlias, isOptedIn: isOptedIn);
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
              ? 'Partisipasi leaderboard diaktifkan.'
              : 'Partisipasi dinonaktifkan dan skor Anda dihapus.',
        ),
      );
    } catch (_) {
      if (isClosed || generation != _requestGeneration) return;
      emit(
        state.copyWith(
          isSaving: false,
          error: 'Pengaturan leaderboard gagal disimpan.',
        ),
      );
    }
  }

  Future<void> submitSession(String sessionId) async {
    if (state.settings?.isOptedIn != true) {
      emit(
        state.copyWith(
          error: 'Aktifkan partisipasi leaderboard sebelum mengirim sesi.',
          clearMessage: true,
        ),
      );
      return;
    }
    final generation = ++_requestGeneration;
    emit(state.copyWith(isSaving: true, clearError: true, clearMessage: true));
    try {
      await _gateway.submitSession(sessionId);
      final entries = await _gateway.loadEntries(state.category);
      if (isClosed || generation != _requestGeneration) return;
      emit(
        state.copyWith(
          entries: entries,
          isSaving: false,
          message: 'Ringkasan sesi ditambahkan ke leaderboard minggu UTC ini.',
        ),
      );
    } catch (_) {
      if (isClosed || generation != _requestGeneration) return;
      emit(
        state.copyWith(
          isSaving: false,
          error: 'Sesi tidak dapat dikirim. Sinkronkan ringkasan sesi dahulu.',
        ),
      );
    }
  }

  void clearForAccountChange() {
    _requestGeneration++;
    emit(const LeaderboardState());
  }
}
