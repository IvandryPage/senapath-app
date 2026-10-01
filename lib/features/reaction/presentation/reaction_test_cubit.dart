import 'dart:async';
import 'dart:math';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/reaction_test_repository.dart';
import '../domain/reaction_test_result.dart';

enum ReactionTestPhase { idle, waiting, ready, completed }

class ReactionTestState {
  const ReactionTestState({
    this.phase = ReactionTestPhase.idle,
    this.durationMilliseconds = 120000,
    this.remainingMilliseconds = 120000,
    this.attempts = const [],
    this.results = const [],
    this.isLoaded = false,
    this.isLoading = false,
    this.isSaving = false,
    this.latestResult,
    this.error,
  });

  final ReactionTestPhase phase;
  final int durationMilliseconds;
  final int remainingMilliseconds;
  final List<ReactionAttempt> attempts;
  final List<ReactionTestResult> results;
  final bool isLoaded;
  final bool isLoading;
  final bool isSaving;
  final ReactionTestResult? latestResult;
  final String? error;

  bool get isRunning =>
      phase == ReactionTestPhase.waiting || phase == ReactionTestPhase.ready;

  ReactionTestState copyWith({
    ReactionTestPhase? phase,
    int? durationMilliseconds,
    int? remainingMilliseconds,
    List<ReactionAttempt>? attempts,
    List<ReactionTestResult>? results,
    bool? isLoaded,
    bool? isLoading,
    bool? isSaving,
    ReactionTestResult? latestResult,
    bool clearLatestResult = false,
    String? error,
  }) => ReactionTestState(
    phase: phase ?? this.phase,
    durationMilliseconds: durationMilliseconds ?? this.durationMilliseconds,
    remainingMilliseconds: remainingMilliseconds ?? this.remainingMilliseconds,
    attempts: attempts ?? this.attempts,
    results: results ?? this.results,
    isLoaded: isLoaded ?? this.isLoaded,
    isLoading: isLoading ?? this.isLoading,
    isSaving: isSaving ?? this.isSaving,
    latestResult: clearLatestResult ? null : latestResult ?? this.latestResult,
    error: error,
  );
}

class ReactionTestCubit extends Cubit<ReactionTestState> {
  ReactionTestCubit(
    this._repository, {
    Duration duration = const Duration(minutes: 2),
    Duration tickInterval = const Duration(milliseconds: 100),
    Duration minimumStimulusDelay = const Duration(milliseconds: 800),
    Duration maximumStimulusDelay = const Duration(milliseconds: 2200),
    Duration minimumResponseGap = const Duration(milliseconds: 120),
    Duration Function()? stimulusDelay,
    Random? random,
    DateTime Function()? clock,
  }) : _duration = duration,
       _tickInterval = tickInterval,
       _minimumStimulusDelay = minimumStimulusDelay,
       _maximumStimulusDelay = maximumStimulusDelay,
       _minimumResponseGap = minimumResponseGap,
       _stimulusDelayOverride = stimulusDelay,
       _random = random ?? Random(),
       _clock = clock ?? DateTime.now,
       super(
         ReactionTestState(
           durationMilliseconds: duration.inMilliseconds,
           remainingMilliseconds: duration.inMilliseconds,
         ),
       );

  final ReactionTestRepository _repository;
  final Duration _duration;
  final Duration _tickInterval;
  final Duration _minimumStimulusDelay;
  final Duration _maximumStimulusDelay;
  final Duration _minimumResponseGap;
  final Duration Function()? _stimulusDelayOverride;
  final Random _random;
  final DateTime Function() _clock;
  final Stopwatch _stopwatch = Stopwatch();
  final List<ReactionAttempt> _attempts = [];

  Timer? _completionTimer;
  Timer? _tickTimer;
  Timer? _stimulusTimer;
  int? _stimulusAtMilliseconds;
  int? _lastResponseAtMilliseconds;
  bool _isRunning = false;

  Future<void> load() async {
    if (state.isLoaded || state.isLoading) return;
    emit(state.copyWith(isLoading: true, error: null));
    try {
      emit(
        state.copyWith(
          results: await _repository.loadRecent(),
          isLoaded: true,
          isLoading: false,
          error: null,
        ),
      );
    } catch (_) {
      emit(
        state.copyWith(
          isLoading: false,
          error: 'Riwayat tes reaksi tidak dapat dibaca.',
        ),
      );
    }
  }

  void startTest() {
    if (!state.isLoaded || state.isRunning || state.isSaving) return;
    _cancelTimers();
    _attempts.clear();
    _lastResponseAtMilliseconds = null;
    _stimulusAtMilliseconds = null;
    _stopwatch
      ..reset()
      ..start();
    _isRunning = true;
    emit(
      state.copyWith(
        phase: ReactionTestPhase.waiting,
        attempts: const [],
        remainingMilliseconds: _duration.inMilliseconds,
        isSaving: false,
        clearLatestResult: true,
        error: null,
      ),
    );
    _completionTimer = Timer(_duration, () => unawaited(_completeTest()));
    _tickTimer = Timer.periodic(_tickInterval, (_) => _updateRemaining());
    _scheduleStimulus();
  }

  void recordResponse() {
    if (!_isRunning) return;
    final elapsed = _stopwatch.elapsedMilliseconds;
    final lastResponse = _lastResponseAtMilliseconds;
    if (lastResponse != null &&
        elapsed - lastResponse < _minimumResponseGap.inMilliseconds) {
      return;
    }
    _lastResponseAtMilliseconds = elapsed;
    _stimulusTimer?.cancel();

    if (state.phase == ReactionTestPhase.ready &&
        _stimulusAtMilliseconds != null) {
      _attempts.add(
        ReactionAttempt(
          wasCorrect: true,
          reactionMilliseconds: elapsed - _stimulusAtMilliseconds!,
        ),
      );
    } else if (state.phase == ReactionTestPhase.waiting) {
      _attempts.add(const ReactionAttempt(wasCorrect: false));
    } else {
      return;
    }

    _stimulusAtMilliseconds = null;
    emit(
      state.copyWith(
        phase: ReactionTestPhase.waiting,
        attempts: List.unmodifiable(_attempts),
        error: null,
      ),
    );
    _scheduleStimulus();
  }

  void cancelTest() {
    if (!_isRunning) return;
    _isRunning = false;
    _stopwatch.stop();
    _cancelTimers();
    _attempts.clear();
    emit(
      state.copyWith(
        phase: ReactionTestPhase.idle,
        remainingMilliseconds: _duration.inMilliseconds,
        attempts: const [],
        isSaving: false,
        clearLatestResult: true,
        error: null,
      ),
    );
  }

  Duration _nextStimulusDelay() {
    final override = _stimulusDelayOverride;
    if (override != null) return override();
    final minimum = _minimumStimulusDelay.inMilliseconds;
    final maximum = _maximumStimulusDelay.inMilliseconds;
    return Duration(
      milliseconds: minimum + _random.nextInt(maximum - minimum + 1),
    );
  }

  void _scheduleStimulus() {
    if (!_isRunning) return;
    _stimulusTimer = Timer(_nextStimulusDelay(), () {
      if (!_isRunning) return;
      _stimulusAtMilliseconds = _stopwatch.elapsedMilliseconds;
      emit(state.copyWith(phase: ReactionTestPhase.ready));
    });
  }

  void _updateRemaining() {
    if (!_isRunning) return;
    final remaining =
        (_duration.inMilliseconds - _stopwatch.elapsedMilliseconds)
            .clamp(0, _duration.inMilliseconds)
            .toInt();
    emit(state.copyWith(remainingMilliseconds: remaining));
    if (remaining == 0) unawaited(_completeTest());
  }

  Future<void> _completeTest() async {
    if (!_isRunning) return;
    _isRunning = false;
    _stopwatch.stop();
    _cancelTimers();
    final completedAt = _clock().toUtc();
    final result = ReactionTestResult(
      id: completedAt.microsecondsSinceEpoch.toString(),
      completedAt: completedAt,
      durationMilliseconds: _duration.inMilliseconds,
      attempts: List.unmodifiable(_attempts),
    );
    emit(
      state.copyWith(
        phase: ReactionTestPhase.completed,
        remainingMilliseconds: 0,
        attempts: result.attempts,
        latestResult: result,
        isSaving: true,
        error: null,
      ),
    );
    try {
      await _repository.save(result);
      emit(
        state.copyWith(
          results: await _repository.loadRecent(),
          isSaving: false,
          error: null,
        ),
      );
    } catch (_) {
      emit(
        state.copyWith(
          isSaving: false,
          error: 'Hasil tes selesai, tetapi belum berhasil disimpan.',
        ),
      );
    }
  }

  void _cancelTimers() {
    _completionTimer?.cancel();
    _tickTimer?.cancel();
    _stimulusTimer?.cancel();
    _completionTimer = null;
    _tickTimer = null;
    _stimulusTimer = null;
  }

  @override
  Future<void> close() {
    _isRunning = false;
    _stopwatch.stop();
    _cancelTimers();
    return super.close();
  }
}
