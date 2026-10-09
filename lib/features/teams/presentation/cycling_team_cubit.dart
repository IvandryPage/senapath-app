import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/cycling_team_repository.dart';
import '../domain/cycling_team.dart';

class CyclingTeamState {
  const CyclingTeamState({
    this.teams = const [],
    this.dashboard,
    this.isLoading = false,
    this.isSaving = false,
    this.error,
    this.message,
  });

  final List<CyclingTeam> teams;
  final CyclingTeamDashboard? dashboard;
  final bool isLoading;
  final bool isSaving;
  final String? error;
  final String? message;

  CyclingTeamState copyWith({
    List<CyclingTeam>? teams,
    CyclingTeamDashboard? dashboard,
    bool clearDashboard = false,
    bool? isLoading,
    bool? isSaving,
    String? error,
    String? message,
    bool clearError = false,
    bool clearMessage = false,
  }) => CyclingTeamState(
    teams: teams ?? this.teams,
    dashboard: clearDashboard ? null : dashboard ?? this.dashboard,
    isLoading: isLoading ?? this.isLoading,
    isSaving: isSaving ?? this.isSaving,
    error: clearError ? null : error ?? this.error,
    message: clearMessage ? null : message ?? this.message,
  );
}

class CyclingTeamCubit extends Cubit<CyclingTeamState> {
  CyclingTeamCubit(this._repository) : super(const CyclingTeamState());

  final CyclingTeamRepository _repository;

  bool get isConfigured => _repository.isConfigured;
  bool get isSignedIn => _repository.isSignedIn;
  String? get currentUserId => _repository.currentUserId;

  Future<void> loadTeams() async {
    emit(state.copyWith(isLoading: true, clearError: true));
    try {
      final teams = await _repository.loadTeams();
      emit(state.copyWith(teams: teams, isLoading: false, clearError: true));
    } catch (error) {
      emit(
        state.copyWith(
          isLoading: false,
          error: _message(error, 'Daftar tim tidak dapat dimuat.'),
        ),
      );
    }
  }

  void clearForAccountChange() => emit(const CyclingTeamState());

  Future<void> loadDashboard(String teamId) async {
    emit(
      state.copyWith(
        isLoading: true,
        clearDashboard: true,
        clearError: true,
      ),
    );
    try {
      final dashboard = await _repository.loadDashboard(teamId);
      emit(
        state.copyWith(
          dashboard: dashboard,
          isLoading: false,
          clearError: true,
        ),
      );
    } catch (error) {
      emit(
        state.copyWith(
          isLoading: false,
          error: _message(error, 'Detail tim tidak dapat dimuat.'),
        ),
      );
    }
  }

  Future<void> createTeam({
    required String name,
    required String displayName,
  }) async {
    await _mutate(
      () => _repository.createTeam(name, displayName),
      successMessage: 'Tim berhasil dibuat.',
    );
  }

  Future<void> joinTeam({
    required String inviteCode,
    required String displayName,
  }) async {
    await _mutate(
      () => _repository.joinTeam(inviteCode, displayName),
      successMessage: 'Berhasil bergabung dengan tim.',
    );
  }

  Future<void> leaveTeam(String teamId) async {
    emit(state.copyWith(isSaving: true, clearError: true, clearMessage: true));
    try {
      await _repository.leaveTeam(teamId);
      final teams = await _repository.loadTeams();
      emit(
        state.copyWith(
          teams: teams,
          isSaving: false,
          clearDashboard: true,
          message: 'Kamu telah keluar dari tim.',
        ),
      );
    } catch (error) {
      emit(
        state.copyWith(
          isSaving: false,
          error: _message(error, 'Tidak dapat keluar dari tim.'),
        ),
      );
    }
  }

  Future<void> unshareSession(String teamId, String sessionId) async {
    emit(state.copyWith(isSaving: true, clearError: true, clearMessage: true));
    try {
      await _repository.unshareSession(teamId, sessionId);
      final dashboard = await _repository.loadDashboard(teamId);
      emit(
        state.copyWith(
          dashboard: dashboard,
          isSaving: false,
          message: 'Ringkasan tidak lagi dibagikan ke tim.',
        ),
      );
    } catch (error) {
      emit(
        state.copyWith(
          isSaving: false,
          error: _message(error, 'Ringkasan tidak dapat ditarik dari tim.'),
        ),
      );
    }
  }

  Future<void> setMemberRole(
    String teamId,
    String userId,
    String role,
  ) async {
    emit(state.copyWith(isSaving: true, clearError: true, clearMessage: true));
    try {
      await _repository.setMemberRole(teamId, userId, role);
      final dashboard = await _repository.loadDashboard(teamId);
      emit(
        state.copyWith(
          dashboard: dashboard,
          isSaving: false,
          message: role == 'manager'
              ? 'Anggota dipromosikan menjadi ketua.'
              : 'Peran ketua anggota diperbarui.',
        ),
      );
    } catch (error) {
      emit(
        state.copyWith(
          isSaving: false,
          error: _message(error, 'Peran anggota tidak dapat diperbarui.'),
        ),
      );
    }
  }

  Future<void> _mutate(
    Future<CyclingTeam> Function() operation, {
    required String successMessage,
  }) async {
    emit(state.copyWith(isSaving: true, clearError: true, clearMessage: true));
    try {
      await operation();
      final teams = await _repository.loadTeams();
      emit(
        state.copyWith(
          teams: teams,
          isSaving: false,
          message: successMessage,
        ),
      );
    } catch (error) {
      emit(
        state.copyWith(
          isSaving: false,
          error: _message(error, 'Perubahan tim tidak dapat disimpan.'),
        ),
      );
    }
  }

  void clearMessage() =>
      emit(state.copyWith(clearMessage: true, clearError: true));

  String _message(Object error, String fallback) {
    if (error is PostgrestException) return error.message;
    final message = error.toString().replaceFirst('Exception: ', '').trim();
    return message.isEmpty ? fallback : message;
  }
}
