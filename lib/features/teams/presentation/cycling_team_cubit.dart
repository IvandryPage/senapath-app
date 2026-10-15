import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/validation/validators.dart';
import '../data/cycling_team_repository.dart';
import '../domain/cycling_team.dart';

class CyclingTeamState {
  const CyclingTeamState({
    this.teams = const [],
    this.dashboard,
    this.hasLoadedTeams = false,
    this.isLoading = false,
    this.isSaving = false,
    this.error,
    this.message,
  });

  final List<CyclingTeam> teams;
  final CyclingTeamDashboard? dashboard;
  final bool hasLoadedTeams;
  final bool isLoading;
  final bool isSaving;
  final String? error;
  final String? message;

  CyclingTeamState copyWith({
    List<CyclingTeam>? teams,
    CyclingTeamDashboard? dashboard,
    bool? hasLoadedTeams,
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
    hasLoadedTeams: hasLoadedTeams ?? this.hasLoadedTeams,
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
      emit(
        state.copyWith(
          teams: teams,
          hasLoadedTeams: true,
          isLoading: false,
          clearError: true,
        ),
      );
    } catch (error) {
      emit(
        state.copyWith(
          isLoading: false,
          hasLoadedTeams: true,
          error: _message(error, 'Daftar tim tidak dapat dimuat.'),
        ),
      );
    }
  }

  void clearForAccountChange() => emit(const CyclingTeamState());

  Future<void> loadDashboard(String teamId) async {
    emit(
      state.copyWith(isLoading: true, clearDashboard: true, clearError: true),
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
    final error = TextValidators.name(
          name,
          label: 'nama tim',
          minLength: InputLimits.teamNameMinLength,
          maxLength: InputLimits.teamNameMaxLength,
        ) ??
        TextValidators.name(
          displayName,
          label: 'nama tampilan',
          maxLength: InputLimits.displayNameMaxLength,
        );
    if (error != null) {
      emit(state.copyWith(isSaving: false, error: error));
      return;
    }
    await _mutate(
      () => _repository.createTeam(
        TextValidators.sanitizeSingleLine(name),
        TextValidators.sanitizeSingleLine(displayName),
      ),
      successMessage: 'Tim berhasil dibuat.',
    );
  }

  Future<void> joinTeam({
    required String inviteCode,
    required String displayName,
  }) async {
    final error =
        TextValidators.inviteCode(inviteCode) ??
        TextValidators.name(
          displayName,
          label: 'nama tampilan',
          maxLength: InputLimits.displayNameMaxLength,
        );
    if (error != null) {
      emit(state.copyWith(isSaving: false, error: error));
      return;
    }
    await _mutate(
      () => _repository.joinTeam(
        TextValidators.sanitizeSingleLine(inviteCode).toUpperCase(),
        TextValidators.sanitizeSingleLine(displayName),
      ),
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
          hasLoadedTeams: true,
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

  Future<void> deleteTeam(String teamId) async {
    emit(state.copyWith(isSaving: true, clearError: true, clearMessage: true));
    try {
      await _repository.deleteTeam(teamId);
      var teams = state.teams
          .where((team) => team.id != teamId)
          .toList(growable: false);
      var message = 'Tim berhasil dihapus.';
      try {
        teams = await _repository.loadTeams();
      } catch (error) {
        message =
            'Tim berhasil dihapus, tetapi daftar tim tidak dapat diperbarui. '
            '${_message(error, 'Coba muat ulang daftar tim.')}';
      }
      emit(
        state.copyWith(
          teams: teams,
          hasLoadedTeams: true,
          isSaving: false,
          clearDashboard: true,
          message: message,
        ),
      );
    } catch (error) {
      emit(
        state.copyWith(
          isSaving: false,
          error: _message(error, 'Tidak dapat menghapus tim.'),
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
          error: _message(error, 'Detail tim tidak dapat dimuat.'),
        ),
      );
    }
  }

  Future<void> setMemberRole(String teamId, String userId, String role) async {
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
        state.copyWith(teams: teams, isSaving: false, message: successMessage),
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
    final details = error is StateError ? error.message : error;
    return '$fallback ${details.toString()}';
  }
}
