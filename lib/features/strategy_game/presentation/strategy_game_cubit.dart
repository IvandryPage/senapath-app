import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/strategy_game_repository.dart';
import '../domain/strategy_game_result.dart';
import '../domain/strategy_scenario.dart';

enum StrategyGamePhase { idle, playing, completed }

class StrategyGameState {
  const StrategyGameState({
    this.phase = StrategyGamePhase.idle,
    this.results = const [],
    this.answers = const [],
    this.scenarioIndex = 0,
    this.selectedOption,
    this.isLoaded = false,
    this.isLoading = false,
    this.isSaving = false,
    this.error,
  });

  final StrategyGamePhase phase;
  final List<StrategyGameResult> results;
  final List<StrategyGameAnswer> answers;
  final int scenarioIndex;
  final int? selectedOption;
  final bool isLoaded;
  final bool isLoading;
  final bool isSaving;
  final String? error;

  bool get isPlaying => phase == StrategyGamePhase.playing;

  StrategyGameState copyWith({
    StrategyGamePhase? phase,
    List<StrategyGameResult>? results,
    List<StrategyGameAnswer>? answers,
    int? scenarioIndex,
    int? selectedOption,
    bool clearSelectedOption = false,
    bool? isLoaded,
    bool? isLoading,
    bool? isSaving,
    String? error,
    bool clearError = false,
  }) => StrategyGameState(
    phase: phase ?? this.phase,
    results: results ?? this.results,
    answers: answers ?? this.answers,
    scenarioIndex: scenarioIndex ?? this.scenarioIndex,
    selectedOption: clearSelectedOption
        ? null
        : selectedOption ?? this.selectedOption,
    isLoaded: isLoaded ?? this.isLoaded,
    isLoading: isLoading ?? this.isLoading,
    isSaving: isSaving ?? this.isSaving,
    error: clearError ? null : error ?? this.error,
  );
}

class StrategyGameCubit extends Cubit<StrategyGameState> {
  StrategyGameCubit(
    this._repository, {
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now,
       super(const StrategyGameState());

  final StrategyGameRepository _repository;
  final DateTime Function() _clock;

  Future<void> load() async {
    if (state.isLoaded || state.isLoading) return;
    emit(state.copyWith(isLoading: true, clearError: true));
    try {
      final results = await _repository.loadRecent();
      if (isClosed) return;
      emit(
        state.copyWith(results: results, isLoaded: true, isLoading: false),
      );
    } catch (_) {
      if (isClosed) return;
      emit(
        state.copyWith(
          isLoading: false,
          error: 'Riwayat tantangan strategi tidak dapat dibaca.',
        ),
      );
    }
  }

  void startGame() {
    if (!state.isLoaded || state.isSaving || state.isPlaying) return;
    emit(
      state.copyWith(
        phase: StrategyGamePhase.playing,
        answers: const [],
        scenarioIndex: 0,
        clearSelectedOption: true,
        clearError: true,
      ),
    );
  }

  void selectOption(int optionIndex) {
    if (!state.isPlaying || state.selectedOption != null) return;
    final scenario = strategyScenarios[state.scenarioIndex];
    if (optionIndex < 0 || optionIndex >= scenario.options.length) return;
    final answer = StrategyGameAnswer(
      scenarioId: scenario.id,
      category: scenario.category,
      selectedOption: optionIndex,
      wasRecommended: optionIndex == scenario.recommendedOption,
    );
    emit(
      state.copyWith(
        selectedOption: optionIndex,
        answers: List.unmodifiable([...state.answers, answer]),
      ),
    );
  }

  Future<void> continueGame() async {
    if (!state.isPlaying || state.selectedOption == null) return;
    if (state.scenarioIndex < strategyScenarios.length - 1) {
      emit(
        state.copyWith(
          scenarioIndex: state.scenarioIndex + 1,
          clearSelectedOption: true,
        ),
      );
      return;
    }
    await _complete();
  }

  void cancelGame() {
    if (!state.isPlaying || state.isSaving) return;
    emit(
      state.copyWith(
        phase: StrategyGamePhase.idle,
        answers: const [],
        scenarioIndex: 0,
        clearSelectedOption: true,
        clearError: true,
      ),
    );
  }

  Future<void> _complete() async {
    final now = _clock().toUtc();
    final result = StrategyGameResult(
      id: now.microsecondsSinceEpoch.toString(),
      playedAt: now,
      answers: List.unmodifiable(state.answers),
      scenarioCount: strategyScenarios.length,
    );
    emit(
      state.copyWith(
        phase: StrategyGamePhase.completed,
        isSaving: true,
        clearError: true,
      ),
    );
    try {
      await _repository.save(result);
      if (isClosed) return;
      emit(
        state.copyWith(
          results: List.unmodifiable([result, ...state.results]),
          isSaving: false,
        ),
      );
    } catch (_) {
      if (isClosed) return;
      emit(
        state.copyWith(
          isSaving: false,
          error: 'Skor selesai, tetapi belum berhasil disimpan lokal.',
        ),
      );
    }
  }
}
