import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../data/readiness_checker.dart';
import '../data/ride_session_repository.dart';
import '../data/session_sync_coordinator.dart';
import '../domain/ride_session.dart';

class RideSessionState {
  const RideSessionState({
    this.isInitialized = false,
    this.isLoading = false,
    this.isCheckingReadiness = false,
    this.readiness,
    this.session,
    this.completedSessions = const [],
    this.summary,
    this.isLoadingSummary = false,
    this.syncingSessionId,
    this.now,
    this.message,
  });

  final bool isInitialized;
  final bool isLoading;
  final bool isCheckingReadiness;
  final ReadinessReport? readiness;
  final RideSessionSnapshot? session;
  final List<RideSessionSnapshot> completedSessions;
  final RideSessionSummary? summary;
  final bool isLoadingSummary;
  final String? syncingSessionId;
  final DateTime? now;
  final String? message;

  RideSessionState copyWith({
    bool? isInitialized,
    bool? isLoading,
    bool? isCheckingReadiness,
    ReadinessReport? readiness,
    RideSessionSnapshot? session,
    List<RideSessionSnapshot>? completedSessions,
    RideSessionSummary? summary,
    bool? isLoadingSummary,
    String? syncingSessionId,
    bool clearSummary = false,
    bool clearSyncingSession = false,
    DateTime? now,
    String? message,
    bool clearMessage = false,
  }) => RideSessionState(
    isInitialized: isInitialized ?? this.isInitialized,
    isLoading: isLoading ?? this.isLoading,
    isCheckingReadiness: isCheckingReadiness ?? this.isCheckingReadiness,
    readiness: readiness ?? this.readiness,
    session: session ?? this.session,
    completedSessions: completedSessions ?? this.completedSessions,
    summary: clearSummary ? null : summary ?? this.summary,
    isLoadingSummary: isLoadingSummary ?? this.isLoadingSummary,
    syncingSessionId: clearSyncingSession
        ? null
        : syncingSessionId ?? this.syncingSessionId,
    now: now ?? this.now,
    message: clearMessage ? null : message ?? this.message,
  );

  bool get canStart => readiness?.canStartRecording ?? false;

  Duration get elapsed => session == null
      ? Duration.zero
      : session!.durationAt(now ?? DateTime.now().toUtc());
}

class RideSessionCubit extends Cubit<RideSessionState> {
  RideSessionCubit({
    required this.repository,
    required this.readinessChecker,
    required this.locationSource,
    this.barometerSource,
    this.motionSensorSource,
    this.syncCoordinator,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now,
       super(const RideSessionState());

  final RideSessionRepository repository;
  final ReadinessChecker readinessChecker;
  final LocationSource locationSource;
  final BarometerSource? barometerSource;
  final MotionSensorSource? motionSensorSource;
  final SessionSyncCoordinator? syncCoordinator;
  final DateTime Function() _clock;
  StreamSubscription<Position>? _positionSubscription;
  StreamSubscription<double>? _barometerSubscription;
  StreamSubscription<AccelerometerEvent>? _accelerometerSubscription;
  StreamSubscription<GyroscopeEvent>? _gyroscopeSubscription;
  double? _barometricPressureHpa;
  double? _accelerationMagnitude;
  double? _rotationRateMagnitude;
  Timer? _ticker;
  int _syncGeneration = 0;

  bool get canSyncSessions =>
      syncCoordinator?.gateway.isConfigured == true &&
      syncCoordinator?.gateway.isSignedIn == true;

  Future<void> initialize() async {
    if (state.isInitialized || state.isLoading) return;
    emit(state.copyWith(isLoading: true, clearMessage: true));
    try {
      final results = await Future.wait([
        readinessChecker.check(),
        repository.recoverCurrentSession(),
        repository.loadCompletedSessions(),
      ]);
      final readiness = results[0] as ReadinessReport;
      final session = results[1] as RideSessionSnapshot?;
      final completedSessions = results[2] as List<RideSessionSnapshot>;
      emit(
        state.copyWith(
          isInitialized: true,
          isLoading: false,
          readiness: readiness,
          session: session,
          completedSessions: completedSessions,
          now: _clock().toUtc(),
        ),
      );
      if (session?.status == RideSessionStatus.recording) {
        _startLocationStream(session!.id);
        _startBarometerStream();
        _startMotionSensorStreams();
        _startTicker();
      }
    } catch (_) {
      emit(
        state.copyWith(
          isInitialized: true,
          isLoading: false,
          message: 'Kesiapan perangkat atau sesi lokal tidak dapat diperiksa.',
        ),
      );
    }
  }

  Future<void> checkReadiness({bool requestLocationPermission = false}) async {
    emit(state.copyWith(isCheckingReadiness: true, clearMessage: true));
    try {
      final readiness = await readinessChecker.check(
        requestLocationPermission: requestLocationPermission,
      );
      emit(
        state.copyWith(
          isInitialized: true,
          isCheckingReadiness: false,
          readiness: readiness,
        ),
      );
    } catch (_) {
      emit(
        state.copyWith(
          isCheckingReadiness: false,
          message: 'Pemeriksaan kesiapan gagal. Coba periksa kembali.',
        ),
      );
    }
  }

  Future<void> openLocationSettings() async {
    try {
      await readinessChecker.openLocationSettings();
    } catch (_) {
      _setMessage('Pengaturan izin perangkat tidak dapat dibuka.');
    }
  }

  Future<void> start() async {
    if (state.session != null &&
        state.session!.status != RideSessionStatus.completed) {
      _setMessage('Selesaikan atau lanjutkan sesi yang sedang tersimpan.');
      return;
    }
    if (!state.canStart) {
      _setMessage('Izin lokasi diperlukan untuk mulai merekam.');
      return;
    }

    try {
      final session = await repository.start(_clock().toUtc());
      emit(state.copyWith(session: session, now: _clock().toUtc()));
      _startLocationStream(session.id);
      _startBarometerStream();
      _startMotionSensorStreams();
      _startTicker();
    } catch (_) {
      _setMessage('Sesi tidak dapat dimulai. Data sebelumnya tetap tersimpan.');
    }
  }

  Future<void> pause() async {
    final session = state.session;
    if (session == null || session.status != RideSessionStatus.recording) {
      _setMessage('Tidak ada sesi yang sedang merekam.');
      return;
    }
    await _stopLocationStream();
    await _stopBarometerStream();
    await _stopMotionSensorStreams();
    _ticker?.cancel();
    try {
      final paused = await repository.pause(session.id, _clock().toUtc());
      emit(state.copyWith(session: paused, now: _clock().toUtc()));
    } catch (_) {
      _setMessage('Sesi tidak dapat dijeda.');
    }
  }

  Future<void> resume() async {
    final session = state.session;
    if (session == null || session.status != RideSessionStatus.paused) {
      _setMessage('Tidak ada sesi jeda untuk dilanjutkan.');
      return;
    }
    if (!state.canStart) {
      _setMessage('Izin lokasi diperlukan untuk melanjutkan perekaman.');
      return;
    }
    try {
      final resumed = await repository.resume(session.id, _clock().toUtc());
      emit(state.copyWith(session: resumed, now: _clock().toUtc()));
      _startLocationStream(resumed.id);
      _startBarometerStream();
      _startMotionSensorStreams();
      _startTicker();
    } catch (_) {
      _setMessage('Sesi tidak dapat dilanjutkan.');
    }
  }

  Future<void> finish() async {
    final session = state.session;
    if (session == null || session.status == RideSessionStatus.completed) {
      _setMessage('Tidak ada sesi aktif untuk diakhiri.');
      return;
    }
    await _stopLocationStream();
    await _stopBarometerStream();
    await _stopMotionSensorStreams();
    _ticker?.cancel();
    try {
      final completed = await repository.finish(session.id, _clock().toUtc());
      final history = await repository.loadCompletedSessions();
      emit(
        state.copyWith(
          session: completed,
          completedSessions: history,
          now: completed.endedAt,
          clearSummary: true,
        ),
      );
    } catch (_) {
      _setMessage('Sesi belum dapat diakhiri. Data lokal tetap tersedia.');
    }
  }

  Future<void> loadSummary(String sessionId) async {
    emit(state.copyWith(isLoadingSummary: true, clearSummary: true));
    try {
      final summary = await repository.loadSummary(sessionId);
      emit(state.copyWith(summary: summary, isLoadingSummary: false));
    } catch (_) {
      emit(
        state.copyWith(
          isLoadingSummary: false,
          message: 'Ringkasan lokal tidak dapat dibuka.',
        ),
      );
    }
  }

  Future<void> syncSummary(
    String sessionId, {
    required bool consented,
  }) async {
    final coordinator = syncCoordinator;
    if (coordinator == null) {
      _setMessage('Sinkronisasi Supabase belum dikonfigurasi.');
      return;
    }
    if (state.syncingSessionId != null) return;

    final generation = ++_syncGeneration;
    emit(
      state.copyWith(
        syncingSessionId: sessionId,
        clearMessage: true,
      ),
    );
    try {
      await coordinator.syncSummary(sessionId, consented: consented);
      if (isClosed || generation != _syncGeneration) return;
      final history = await repository.loadCompletedSessions();
      if (isClosed || generation != _syncGeneration) return;
      final summary = await repository.loadSummary(sessionId);
      if (isClosed || generation != _syncGeneration) return;
      emit(
        state.copyWith(
          completedSessions: history,
          summary: summary,
          clearSyncingSession: true,
          message: 'Ringkasan sesi tersinkron ke akun Supabase.',
        ),
      );
    } catch (_) {
      if (isClosed || generation != _syncGeneration) return;
      final history = await repository.loadCompletedSessions();
      if (isClosed || generation != _syncGeneration) return;
      final summary = await repository.loadSummary(sessionId);
      if (isClosed || generation != _syncGeneration) return;
      emit(
        state.copyWith(
          completedSessions: history,
          summary: summary,
          clearSyncingSession: true,
          message:
              'Sinkronisasi gagal. Ringkasan tetap tersimpan lokal; coba lagi saat online.',
        ),
      );
    }
  }

  void cancelPendingSync() {
    if (state.syncingSessionId == null) return;
    _syncGeneration++;
    emit(state.copyWith(clearSyncingSession: true));
  }

  void closeSummary() => emit(state.copyWith(clearSummary: true));

  Future<void> _handlePosition(String sessionId, Position position) async {
    final current = state.session;
    if (current == null ||
        current.id != sessionId ||
        current.status != RideSessionStatus.recording ||
        !position.latitude.isFinite ||
        !position.longitude.isFinite ||
        !position.accuracy.isFinite ||
        position.accuracy > 50) {
      return;
    }

    final recordedAt = position.timestamp.toUtc();
    final previous = await repository.latestLocation(sessionId);
    var addedDistanceMeters = 0.0;
    if (previous != null && recordedAt.isAfter(previous.recordedAt)) {
      final distance = Geolocator.distanceBetween(
        previous.latitude,
        previous.longitude,
        position.latitude,
        position.longitude,
      );
      final seconds =
          recordedAt.difference(previous.recordedAt).inMilliseconds /
          Duration.millisecondsPerSecond;
      if (seconds > 0 && distance / seconds <= 45) {
        addedDistanceMeters = distance;
      }
    }

    final updated = await repository.recordLocation(
      sessionId: sessionId,
      location: TelemetryLocation(
        recordedAt: recordedAt,
        latitude: position.latitude,
        longitude: position.longitude,
        accuracyMeters: position.accuracy,
        altitudeMeters: position.altitude,
        altitudeAccuracyMeters: position.altitudeAccuracy,
        barometricPressureHpa: _barometricPressureHpa,
        accelerationMagnitudeMetersPerSecondSquared: _accelerationMagnitude,
        rotationRateMagnitudeRadiansPerSecond: _rotationRateMagnitude,
        speedMetersPerSecond: position.speed.isFinite ? position.speed : 0,
      ),
      addedDistanceMeters: addedDistanceMeters,
    );
    if (updated != null && state.session?.id == sessionId) {
      emit(state.copyWith(session: updated, now: _clock().toUtc()));
    }
  }

  void _startLocationStream(String sessionId) {
    unawaited(_stopLocationStream());
    _positionSubscription = locationSource.positions.listen(
      (position) => unawaited(_handlePosition(sessionId, position)),
      onError: (Object _) =>
          _setMessage('Sinyal GPS terputus. Sesi tetap lokal.'),
    );
  }

  void _startBarometerStream() {
    final source = barometerSource;
    if (source == null) return;
    _barometricPressureHpa = null;
    unawaited(_stopBarometerStream());
    _barometerSubscription = source.pressureHpa.listen((pressure) {
      _barometricPressureHpa =
          pressure.isFinite && pressure >= 300 && pressure <= 1100
          ? pressure
          : null;
    }, onError: (Object _) => _barometricPressureHpa = null);
  }

  void _startMotionSensorStreams() {
    final source = motionSensorSource;
    if (source == null) return;
    _accelerationMagnitude = null;
    _rotationRateMagnitude = null;
    unawaited(_stopMotionSensorStreams());
    _accelerometerSubscription = source.accelerometerReadings.listen((event) {
      final magnitude = math.sqrt(
        event.x * event.x + event.y * event.y + event.z * event.z,
      );
      _accelerationMagnitude = magnitude.isFinite ? magnitude : null;
    }, onError: (Object _) => _accelerationMagnitude = null);
    _gyroscopeSubscription = source.gyroscopeReadings.listen((event) {
      final magnitude = math.sqrt(
        event.x * event.x + event.y * event.y + event.z * event.z,
      );
      _rotationRateMagnitude = magnitude.isFinite ? magnitude : null;
    }, onError: (Object _) => _rotationRateMagnitude = null);
  }

  Future<void> _stopLocationStream() async {
    await _positionSubscription?.cancel();
    _positionSubscription = null;
  }

  Future<void> _stopBarometerStream() async {
    await _barometerSubscription?.cancel();
    _barometerSubscription = null;
  }

  Future<void> _stopMotionSensorStreams() async {
    await _accelerometerSubscription?.cancel();
    await _gyroscopeSubscription?.cancel();
    _accelerometerSubscription = null;
    _gyroscopeSubscription = null;
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (state.session?.status == RideSessionStatus.recording) {
        emit(state.copyWith(now: _clock().toUtc()));
      }
    });
  }

  void _setMessage(String message) => emit(state.copyWith(message: message));

  void clearMessage() => emit(state.copyWith(clearMessage: true));

  @override
  Future<void> close() async {
    _ticker?.cancel();
    await _stopLocationStream();
    await _stopBarometerStream();
    await _stopMotionSensorStreams();
    await super.close();
  }
}
