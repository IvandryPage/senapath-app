import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';

import '../data/readiness_checker.dart';
import '../data/ride_session_repository.dart';
import '../domain/ride_session.dart';

class RideSessionState {
  const RideSessionState({
    this.isInitialized = false,
    this.isLoading = false,
    this.isCheckingReadiness = false,
    this.readiness,
    this.session,
    this.now,
    this.message,
  });

  final bool isInitialized;
  final bool isLoading;
  final bool isCheckingReadiness;
  final ReadinessReport? readiness;
  final RideSessionSnapshot? session;
  final DateTime? now;
  final String? message;

  RideSessionState copyWith({
    bool? isInitialized,
    bool? isLoading,
    bool? isCheckingReadiness,
    ReadinessReport? readiness,
    RideSessionSnapshot? session,
    DateTime? now,
    String? message,
    bool clearMessage = false,
  }) => RideSessionState(
    isInitialized: isInitialized ?? this.isInitialized,
    isLoading: isLoading ?? this.isLoading,
    isCheckingReadiness: isCheckingReadiness ?? this.isCheckingReadiness,
    readiness: readiness ?? this.readiness,
    session: session ?? this.session,
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
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now,
       super(const RideSessionState());

  final RideSessionRepository repository;
  final ReadinessChecker readinessChecker;
  final LocationSource locationSource;
  final DateTime Function() _clock;
  StreamSubscription<Position>? _positionSubscription;
  Timer? _ticker;

  Future<void> initialize() async {
    if (state.isInitialized || state.isLoading) return;
    emit(state.copyWith(isLoading: true, clearMessage: true));
    try {
      final results = await Future.wait([
        readinessChecker.check(),
        repository.recoverCurrentSession(),
      ]);
      final readiness = results[0] as ReadinessReport;
      final session = results[1] as RideSessionSnapshot?;
      emit(
        state.copyWith(
          isInitialized: true,
          isLoading: false,
          readiness: readiness,
          session: session,
          now: _clock().toUtc(),
        ),
      );
      if (session?.status == RideSessionStatus.recording) {
        _startLocationStream(session!.id);
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
    _ticker?.cancel();
    try {
      final completed = await repository.finish(session.id, _clock().toUtc());
      emit(state.copyWith(session: completed, now: completed.endedAt));
    } catch (_) {
      _setMessage('Sesi belum dapat diakhiri. Data lokal tetap tersedia.');
    }
  }

  Future<void> _handlePosition(String sessionId, Position position) async {
    final current = state.session;
    if (current == null ||
        current.id != sessionId ||
        current.status != RideSessionStatus.recording ||
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
        speedMetersPerSecond: position.speed,
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

  Future<void> _stopLocationStream() async {
    await _positionSubscription?.cancel();
    _positionSubscription = null;
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
    await super.close();
  }
}
