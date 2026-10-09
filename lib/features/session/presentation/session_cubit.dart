import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../data/readiness_checker.dart';
import '../data/ride_session_repository.dart';
import '../data/session_sync_coordinator.dart';
import '../../notifications/data/notification_settings_repository.dart';
import '../../notifications/data/ride_notification_service.dart';
import '../../ledger/data/ride_ledger_repository.dart';
import '../../routes/domain/route_progress.dart';
import '../../routes/domain/saved_route.dart';
import '../domain/ride_session.dart';

class RideSessionState {
  const RideSessionState({
    this.isInitialized = false,
    this.isLoading = false,
    this.isCheckingReadiness = false,
    this.readiness,
    this.session,
    this.recordedLocations = const [],
    this.completedSessions = const [],
    this.summary,
    this.summaryLocations = const [],
    this.isLoadingSummary = false,
    this.syncingSessionId,
    this.activeRoute,
    this.routeProgress,
    this.now,
    this.message,
  });

  final bool isInitialized;
  final bool isLoading;
  final bool isCheckingReadiness;
  final ReadinessReport? readiness;
  final RideSessionSnapshot? session;
  final List<TelemetryLocation> recordedLocations;
  final List<RideSessionSnapshot> completedSessions;
  final RideSessionSummary? summary;
  final List<TelemetryLocation> summaryLocations;
  final bool isLoadingSummary;
  final String? syncingSessionId;
  final RouteRecord? activeRoute;
  final RouteProgress? routeProgress;
  final DateTime? now;
  final String? message;

  RideSessionState copyWith({
    bool? isInitialized,
    bool? isLoading,
    bool? isCheckingReadiness,
    ReadinessReport? readiness,
    RideSessionSnapshot? session,
    List<TelemetryLocation>? recordedLocations,
    List<RideSessionSnapshot>? completedSessions,
    RideSessionSummary? summary,
    List<TelemetryLocation>? summaryLocations,
    bool? isLoadingSummary,
    String? syncingSessionId,
    bool clearSummary = false,
    bool clearSyncingSession = false,
    RouteRecord? activeRoute,
    bool clearActiveRoute = false,
    RouteProgress? routeProgress,
    bool clearRouteProgress = false,
    DateTime? now,
    String? message,
    bool clearMessage = false,
  }) => RideSessionState(
    isInitialized: isInitialized ?? this.isInitialized,
    isLoading: isLoading ?? this.isLoading,
    isCheckingReadiness: isCheckingReadiness ?? this.isCheckingReadiness,
    readiness: readiness ?? this.readiness,
    session: session ?? this.session,
    recordedLocations: recordedLocations ?? this.recordedLocations,
    completedSessions: completedSessions ?? this.completedSessions,
    summary: clearSummary ? null : summary ?? this.summary,
    summaryLocations: clearSummary
        ? const []
        : summaryLocations ?? this.summaryLocations,
    isLoadingSummary: isLoadingSummary ?? this.isLoadingSummary,
    syncingSessionId: clearSyncingSession
        ? null
        : syncingSessionId ?? this.syncingSessionId,
    activeRoute: clearActiveRoute ? null : activeRoute ?? this.activeRoute,
    routeProgress: clearRouteProgress
        ? null
        : routeProgress ?? this.routeProgress,
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
    this.notificationService,
    this.notificationSettingsRepository,
    this.ledgerRepository,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now,
       super(const RideSessionState());

  final RideSessionRepository repository;
  final ReadinessChecker readinessChecker;
  final LocationSource locationSource;
  final BarometerSource? barometerSource;
  final MotionSensorSource? motionSensorSource;
  final SessionSyncCoordinator? syncCoordinator;
  final RideNotificationService? notificationService;
  final NotificationSettingsRepository? notificationSettingsRepository;
  final RideLedgerRepository? ledgerRepository;
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
  int _summaryGeneration = 0;
  int _lastNotifiedProgress = 0;
  final Set<int> _approachedCheckpoints = {};
  final Set<int> _reachedCheckpoints = {};
  bool _routeNotificationsFailed = false;
  bool _routeNotificationsEnabled = false;
  RouteProgressCalculator? _routeProgressCalculator;

  bool get canSyncSessions =>
      syncCoordinator?.gateway.isConfigured == true &&
      syncCoordinator?.gateway.isSignedIn == true;

  Future<void> initialize() async {
    if (state.isInitialized || state.isLoading) return;
    emit(state.copyWith(isLoading: true, clearMessage: true));
    try {
      final results = await Future.wait([
        readinessChecker.check(checkGpsFix: false),
        repository.recoverCurrentSession(),
        repository.loadCompletedSessions(),
      ]);
      final readiness = results[0] as ReadinessReport;
      final session = results[1] as RideSessionSnapshot?;
      final completedSessions = results[2] as List<RideSessionSnapshot>;
      var recordedLocations = const <TelemetryLocation>[];
      String? locationMessage;
      if (session != null) {
        try {
          recordedLocations = await repository.loadTelemetryLocations(
            session.id,
          );
        } catch (_) {
          locationMessage = 'Jejak sesi lokal tidak dapat dibuka.';
        }
      }
      emit(
        state.copyWith(
          isInitialized: true,
          isLoading: false,
          readiness: readiness,
          session: session,
          recordedLocations: recordedLocations,
          completedSessions: completedSessions,
          now: _clock().toUtc(),
          message: locationMessage,
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

  Future<void> checkReadiness({
    bool requestLocationPermission = false,
    bool requestNotificationPermission = false,
    bool checkGpsFix = false,
  }) async {
    emit(state.copyWith(isCheckingReadiness: true, clearMessage: true));
    try {
      final readiness = await readinessChecker.check(
        requestLocationPermission: requestLocationPermission,
        requestNotificationPermission: requestNotificationPermission,
        checkGpsFix: checkGpsFix,
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

  Future<void> openNotificationSettings() async {
    try {
      await readinessChecker.openNotificationSettings();
    } catch (_) {
      _setMessage('Pengaturan notifikasi perangkat tidak dapat dibuka.');
    }
  }

  Future<void> openLocationServiceSettings() async {
    try {
      await readinessChecker.openLocationServiceSettings();
    } catch (_) {
      _setMessage('Pengaturan layanan lokasi tidak dapat dibuka.');
    }
  }

  Future<void> start({RouteRecord? route}) async {
    if (state.session != null &&
        state.session!.status != RideSessionStatus.completed) {
      _setMessage('Selesaikan atau lanjutkan sesi yang sedang tersimpan.');
      return;
    }
    try {
      final readiness = await readinessChecker.check(
        requestLocationPermission: true,
        checkGpsFix: false,
      );
      emit(state.copyWith(readiness: readiness));
      if (!readiness.canStartRecording) {
        _setMessage(
          readiness.locationServicesEnabled
              ? 'Izin lokasi diperlukan untuk mulai merekam.'
              : 'Aktifkan layanan lokasi perangkat untuk mulai merekam.',
        );
        return;
      }
    } catch (_) {
      _setMessage('Status izin dan layanan lokasi tidak dapat diperiksa.');
      return;
    }
    try {
      final session = await repository.start(_clock().toUtc());
      _activeRoute = route;
      _routeProgressCalculator = route == null
          ? null
          : RouteProgressCalculator(route);
      _resetRouteNotifications();
      emit(
        state.copyWith(
          session: session,
          activeRoute: route,
          clearActiveRoute: route == null,
          clearRouteProgress: true,
          recordedLocations: const [],
          now: _clock().toUtc(),
        ),
      );
      await _prepareRouteNotifications();
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

  Future<void> resume({RouteRecord? route}) async {
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
      if (route != null) {
        _activeRoute = route;
        _routeProgressCalculator = RouteProgressCalculator(route);
        _resetRouteNotifications();
      }
      emit(
        state.copyWith(
          session: resumed,
          activeRoute: route,
          now: _clock().toUtc(),
        ),
      );
      await _prepareRouteNotifications();
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
      String? ledgerMessage;
      try {
        await ledgerRepository?.appendSession(completed);
      } catch (_) {
        ledgerMessage = 'Sesi selesai, tetapi bukti aktivitas belum tercatat di rantai lokal.';
      }
      emit(
        state.copyWith(
          session: completed,
          clearActiveRoute: true,
          clearRouteProgress: true,
          completedSessions: history,
          now: completed.endedAt,
          clearSummary: true,
          message: ledgerMessage,
          clearMessage: ledgerMessage == null,
        ),
      );
      _activeRoute = null;
      _routeProgressCalculator = null;
    } catch (_) {
      _setMessage('Sesi belum dapat diakhiri. Data lokal tetap tersedia.');
    }
  }

  Future<void> loadSummary(String sessionId) async {
    final generation = ++_summaryGeneration;
    emit(state.copyWith(isLoadingSummary: true, clearSummary: true));
    try {
      final results = await Future.wait([
        repository.loadSummary(sessionId),
        repository.loadTelemetryLocations(sessionId),
      ]);
      if (isClosed || generation != _summaryGeneration) return;
      emit(
        state.copyWith(
          summary: results[0] as RideSessionSummary,
          summaryLocations: results[1] as List<TelemetryLocation>,
          isLoadingSummary: false,
        ),
      );
    } catch (_) {
      if (isClosed || generation != _summaryGeneration) return;
      emit(
        state.copyWith(
          isLoadingSummary: false,
          message: 'Ringkasan lokal tidak dapat dibuka.',
        ),
      );
    }
  }

  Future<void> updateActivityMetadata({
    required String sessionId,
    required String title,
    required RideActivityType activityType,
  }) async {
    try {
      final updated = await repository.updateActivityMetadata(
        sessionId: sessionId,
        title: title,
        activityType: activityType,
      );
      final history = [
        for (final session in state.completedSessions)
          if (session.id == sessionId) updated else session,
      ];
      final summary = state.summary?.session.id == sessionId
          ? state.summary!.copyWith(session: updated)
          : state.summary;
      emit(state.copyWith(completedSessions: history, summary: summary));
    } catch (_) {
      _setMessage('Nama atau jenis aktivitas tidak dapat disimpan.');
    }
  }

  Future<void> deleteCompletedSession(String sessionId) async {
    try {
      await repository.deleteCompletedSession(sessionId);
      final history = state.completedSessions
          .where((session) => session.id != sessionId)
          .toList(growable: false);
      final clearSummary = state.summary?.session.id == sessionId;
      emit(
        state.copyWith(
          completedSessions: history,
          clearSummary: clearSummary,
          message: 'Aktivitas lokal dihapus. Salinan cloud, jika ada, tidak ikut dihapus.',
        ),
      );
    } catch (_) {
      _setMessage('Aktivitas lokal tidak dapat dihapus.');
    }
  }

  Future<void> syncSummary(
    String sessionId, {
    required bool consented,
    String? shareWithTeamId,
  }) async {
    final coordinator = syncCoordinator;
    if (coordinator == null) {
      _setMessage('Sinkronisasi Supabase belum dikonfigurasi.');
      return;
    }
    if (state.syncingSessionId != null) return;

    final generation = ++_syncGeneration;
    emit(state.copyWith(syncingSessionId: sessionId, clearMessage: true));
    try {
      await coordinator.syncSummary(
        sessionId,
        consented: consented,
        shareWithTeamId: shareWithTeamId,
        shouldContinue: () => !isClosed && generation == _syncGeneration,
      );
      if (isClosed || generation != _syncGeneration) return;
      final history = await repository.loadCompletedSessions();
      if (isClosed || generation != _syncGeneration) return;
      final summary = await repository.loadSummary(sessionId);
      final summaryLocations = await repository.loadTelemetryLocations(
        sessionId,
      );
      if (isClosed || generation != _syncGeneration) return;
      emit(
        state.copyWith(
          completedSessions: history,
          summary: summary,
          summaryLocations: summaryLocations,
          clearSyncingSession: true,
          message: shareWithTeamId == null
              ? 'Ringkasan sesi tersinkron ke akun Supabase.'
              : 'Ringkasan sesi dibagikan ke tim.',
        ),
      );
    } catch (_) {
      if (isClosed || generation != _syncGeneration) return;
      final history = await repository.loadCompletedSessions();
      if (isClosed || generation != _syncGeneration) return;
      final summary = await repository.loadSummary(sessionId);
      final summaryLocations = await repository.loadTelemetryLocations(
        sessionId,
      );
      if (isClosed || generation != _syncGeneration) return;
      emit(
        state.copyWith(
          completedSessions: history,
          summary: summary,
          summaryLocations: summaryLocations,
          clearSyncingSession: true,
          message: 'Sinkronisasi gagal. Ringkasan tetap tersimpan lokal; coba lagi saat online.',
        ),
      );
    }
  }

  void cancelPendingSync() {
    if (state.syncingSessionId == null) return;
    _syncGeneration++;
    emit(state.copyWith(clearSyncingSession: true));
  }

  void closeSummary() {
    _summaryGeneration++;
    emit(state.copyWith(clearSummary: true, isLoadingSummary: false));
  }

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

    final location = TelemetryLocation(
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
    );
    final updated = await repository.recordLocation(
      sessionId: sessionId,
      location: location,
      addedDistanceMeters: addedDistanceMeters,
    );
    if (updated != null && state.session?.id == sessionId) {
      final routeProgress = _routeProgressCalculator?.calculate(location);
      emit(
        state.copyWith(
          session: updated,
          recordedLocations: [...state.recordedLocations, location],
          routeProgress: routeProgress,
          clearRouteProgress: routeProgress == null,
          now: _clock().toUtc(),
        ),
      );
      unawaited(_notifyRouteProgress(location, routeProgress));
    }
  }

  RouteRecord? _activeRoute;

  void setActiveRoute(RouteRecord? route) {
    if (state.session?.status != RideSessionStatus.recording) return;
    _activeRoute = route;
    _routeProgressCalculator = route == null
        ? null
        : RouteProgressCalculator(route);
    _resetRouteNotifications();
    final location = state.recordedLocations.isEmpty
        ? null
        : state.recordedLocations.last;
    final progress = route == null || location == null
        ? null
        : _routeProgressCalculator?.calculate(location);
    emit(
      state.copyWith(
        activeRoute: route,
        clearActiveRoute: route == null,
        routeProgress: progress,
        clearRouteProgress: progress == null,
      ),
    );
    unawaited(_prepareRouteNotifications());
  }

  Future<void> _prepareRouteNotifications() async {
    final settingsRepository = notificationSettingsRepository;
    final service = notificationService;
    if (settingsRepository == null || service == null) return;
    try {
      final settings = await settingsRepository.load();
      _routeNotificationsEnabled = settings.routeProgressEnabled;
      if (_routeNotificationsEnabled && !await service.requestPermission()) {
        _routeNotificationsEnabled = false;
        _setMessage('Notifikasi rute tidak aktif karena izin belum diberikan.');
      }
    } catch (_) {
      _routeNotificationsEnabled = false;
      _setMessage('Pengaturan notifikasi rute tidak dapat dibaca.');
    }
  }

  void _resetRouteNotifications() {
    _lastNotifiedProgress = 0;
    _approachedCheckpoints.clear();
    _reachedCheckpoints.clear();
    _routeNotificationsFailed = false;
  }

  Future<void> _notifyRouteProgress(
    TelemetryLocation location,
    RouteProgress? progress,
  ) async {
    final route = _activeRoute;
    final service = notificationService;
    if (route == null ||
        service == null ||
        !_routeNotificationsEnabled ||
        _routeNotificationsFailed) {
      return;
    }
    if (progress == null ||
        progress.distanceFromRouteMeters >
            math.max(90, location.accuracyMeters * 2)) {
      return;
    }
    try {
      final milestone = (progress.percent ~/ 25) * 25;
      if (milestone >= 25 && milestone > _lastNotifiedProgress) {
        _lastNotifiedProgress = milestone;
        await service.show(
          id: 7200,
          title: 'Progres rute $milestone%',
          body: 'Kamu sudah menempuh $milestone% dari ${route.name}.',
          payload: 'route-progress',
        );
      }
      for (var index = 0; index < route.checkpoints.length; index++) {
        final checkpoint = route.checkpoints[index];
        final distance = RouteProgress.distanceToCheckpoint(
          location,
          checkpoint,
        );
        if (distance <= 250 && _approachedCheckpoints.add(index)) {
          await service.show(
            id: 7300 + index,
            title: 'Checkpoint dekat',
            body: '${checkpoint.name} sekitar ${distance.round()} m lagi.',
            payload: 'route-checkpoint',
          );
        }
        if (distance <= 60 && _reachedCheckpoints.add(index)) {
          await service.show(
            id: 7400 + index,
            title: 'Checkpoint tercapai',
            body: 'Kamu sudah memasuki ${checkpoint.name}.',
            payload: 'route-checkpoint',
          );
        }
      }
    } catch (_) {
      _routeNotificationsFailed = true;
      if (!isClosed) {
        _setMessage('Notifikasi progres rute tidak dapat ditampilkan.');
      }
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
