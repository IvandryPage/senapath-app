import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../data/readiness_checker.dart';
import '../data/ambient_light_source.dart';
import '../data/ride_session_cloud_sync.dart';
import '../data/ride_session_repository.dart';
import '../data/session_sync_coordinator.dart';
import '../data/session_sync_settings_repository.dart';
import '../../notifications/data/notification_settings_repository.dart';
import '../../notifications/data/ride_notification_service.dart';
import '../../ledger/data/ride_ledger_repository.dart';
import '../../ride_prediction/data/ride_history_repository.dart';
import '../../routes/domain/route_progress.dart';
import '../../routes/domain/saved_route.dart';
import '../domain/ride_session.dart';
import '../../workouts/data/interval_workout_repository.dart';
import '../../workouts/domain/interval_workout.dart';

class RideSessionState {
  const RideSessionState({
    this.isInitialized = false,
    this.isLoading = false,
    this.isCheckingReadiness = false,
    this.readiness,
    this.session,
    this.recordedLocations = const [],
    this.performanceLocations = const [],
    this.completedSessions = const [],
    this.summary,
    this.summaryLocations = const [],
    this.isLoadingSummary = false,
    this.autoSyncEnabled = false,
    this.isSavingAutoSync = false,
    this.syncingSessionId,
    this.activeRoute,
    this.routeProgress,
    this.workout,
    this.workoutProgress,
    this.motion,
    this.now,
    this.message,
    this.isAmbientBright = false,
    this.messageIsSuccess = false,
  });

  final bool isInitialized;
  final bool isLoading;
  final bool isCheckingReadiness;
  final ReadinessReport? readiness;
  final RideSessionSnapshot? session;
  final List<TelemetryLocation> recordedLocations;
  final List<TelemetryLocation> performanceLocations;
  final List<RideSessionSnapshot> completedSessions;
  final RideSessionSummary? summary;
  final List<TelemetryLocation> summaryLocations;
  final bool isLoadingSummary;
  final bool autoSyncEnabled;
  final bool isSavingAutoSync;
  final String? syncingSessionId;
  final RouteRecord? activeRoute;
  final RouteProgress? routeProgress;
  final IntervalWorkout? workout;
  final WorkoutIntervalProgress? workoutProgress;
  final MotionSnapshot? motion;
  final DateTime? now;
  final String? message;
  final bool isAmbientBright;
  final bool messageIsSuccess;

  RideSessionState copyWith({
    bool? isInitialized,
    bool? isLoading,
    bool? isCheckingReadiness,
    ReadinessReport? readiness,
    RideSessionSnapshot? session,
    List<TelemetryLocation>? recordedLocations,
    List<TelemetryLocation>? performanceLocations,
    List<RideSessionSnapshot>? completedSessions,
    RideSessionSummary? summary,
    List<TelemetryLocation>? summaryLocations,
    bool? isLoadingSummary,
    bool? autoSyncEnabled,
    bool? isSavingAutoSync,
    String? syncingSessionId,
    bool clearSummary = false,
    bool clearSyncingSession = false,
    RouteRecord? activeRoute,
    bool clearActiveRoute = false,
    RouteProgress? routeProgress,
    bool clearRouteProgress = false,
    IntervalWorkout? workout,
    WorkoutIntervalProgress? workoutProgress,
    bool clearWorkout = false,
    MotionSnapshot? motion,
    bool clearMotion = false,
    DateTime? now,
    String? message,
    bool clearMessage = false,
    bool? isAmbientBright,
    bool messageIsSuccess = false,
  }) => RideSessionState(
    isInitialized: isInitialized ?? this.isInitialized,
    isLoading: isLoading ?? this.isLoading,
    isCheckingReadiness: isCheckingReadiness ?? this.isCheckingReadiness,
    readiness: readiness ?? this.readiness,
    session: session ?? this.session,
    recordedLocations: recordedLocations ?? this.recordedLocations,
    performanceLocations: performanceLocations ?? this.performanceLocations,
    completedSessions: completedSessions ?? this.completedSessions,
    summary: clearSummary ? null : summary ?? this.summary,
    summaryLocations: clearSummary
        ? const []
        : summaryLocations ?? this.summaryLocations,
    isLoadingSummary: isLoadingSummary ?? this.isLoadingSummary,
    autoSyncEnabled: autoSyncEnabled ?? this.autoSyncEnabled,
    isSavingAutoSync: isSavingAutoSync ?? this.isSavingAutoSync,
    syncingSessionId: clearSyncingSession
        ? null
        : syncingSessionId ?? this.syncingSessionId,
    activeRoute: clearActiveRoute ? null : activeRoute ?? this.activeRoute,
    routeProgress: clearRouteProgress
        ? null
        : routeProgress ?? this.routeProgress,
    workout: clearWorkout ? null : workout ?? this.workout,
    workoutProgress: clearWorkout
        ? null
        : workoutProgress ?? this.workoutProgress,
    motion: clearMotion ? null : motion ?? this.motion,
    now: now ?? this.now,
    message: clearMessage ? null : message ?? this.message,
    isAmbientBright: isAmbientBright ?? this.isAmbientBright,
    messageIsSuccess: clearMessage
        ? false
        : message == null
        ? this.messageIsSuccess
        : messageIsSuccess,
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
    this.syncSettingsRepository,
    this.cloudSync,
    this.notificationService,
    this.notificationSettingsRepository,
    this.ledgerRepository,
    this.rideHistoryRepository,
    this.intervalWorkoutRepository,
    this.ambientLightSource,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now,
       super(const RideSessionState());

  final RideSessionRepository repository;
  final ReadinessChecker readinessChecker;
  final LocationSource locationSource;
  final BarometerSource? barometerSource;
  final MotionSensorSource? motionSensorSource;
  final SessionSyncCoordinator? syncCoordinator;
  final SessionSyncSettingsRepository? syncSettingsRepository;
  final RideSessionCloudSync? cloudSync;
  final RideNotificationService? notificationService;
  final NotificationSettingsRepository? notificationSettingsRepository;
  final RideLedgerRepository? ledgerRepository;
  final RideHistoryRepository? rideHistoryRepository;
  final IntervalWorkoutRepository? intervalWorkoutRepository;
  final AmbientLightSource? ambientLightSource;
  final DateTime Function() _clock;
  StreamSubscription<Position>? _positionSubscription;
  StreamSubscription<double>? _barometerSubscription;
  StreamSubscription<AccelerometerEvent>? _accelerometerSubscription;
  StreamSubscription<GyroscopeEvent>? _gyroscopeSubscription;
  StreamSubscription<int>? _ambientLightSubscription;
  double? _barometricPressureHpa;
  double? _accelerationMagnitude;
  double? _rotationRateMagnitude;
  double? _cadenceRpm;
  final List<double> _accelerationHistory = [];
  final List<double> _rotationHistory = [];
  final List<double> _cadenceHistory = [];
  Timer? _ticker;
  Timer? _motionTicker;
  Timer? _autoSyncRetryTimer;
  final _CadenceEstimator _cadenceEstimator = _CadenceEstimator();
  static const int _maxMotionSamples = 150;
  int _syncGeneration = 0;
  int _summaryGeneration = 0;
  int _lastNotifiedProgress = 0;
  final Set<int> _approachedCheckpoints = {};
  final Set<int> _reachedCheckpoints = {};
  bool _routeNotificationsFailed = false;
  bool _routeNotificationsEnabled = false;
  bool _routeNotificationPermissionRequested = false;
  DateTime? _lastPerformanceSampleAt;
  RouteProgressCalculator? _routeProgressCalculator;
  WorkoutCheckpoint? _workoutCheckpoint;
  bool _updatingWorkout = false;
  bool _syncSettingsLoaded = false;

  static const Duration _performanceChartSampleInterval = Duration(seconds: 5);
  static const int _maxPerformanceChartSamples = 60;

  bool get canSyncSessions =>
      syncCoordinator?.gateway.isConfigured == true &&
      syncCoordinator?.gateway.isSignedIn == true;

  bool get canCloudSync => cloudSync?.canSync == true;

  Future<void> initialize() async {
    if (state.isInitialized || state.isLoading) return;
    emit(state.copyWith(isLoading: true, clearMessage: true));
    try {
      final autoSyncEnabled = await _loadAutoSyncSetting();
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
          locationMessage =
              'Rute perjalanan yang tersimpan di ponsel tidak dapat dibuka.';
        }
      }
      IntervalWorkout? workout;
      WorkoutIntervalProgress? workoutProgress;
      final workoutRepository = intervalWorkoutRepository;
      if (session != null && workoutRepository != null) {
        try {
          _workoutCheckpoint = await workoutRepository.loadCheckpoint(
            session.id,
          );
          if (_workoutCheckpoint case final checkpoint?) {
            final workouts = await workoutRepository.loadWorkouts();
            for (final candidate in workouts) {
              if (candidate.id == checkpoint.workoutId) {
                workout = candidate;
                workoutProgress = _calculateWorkoutProgress(
                  candidate,
                  checkpoint,
                  session.durationAt(_clock().toUtc()).inSeconds,
                  session.distanceMeters,
                );
                break;
              }
            }
          }
        } catch (_) {
          locationMessage ??=
              'Kemajuan latihan sebelumnya tidak dapat dipulihkan.';
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
          autoSyncEnabled: autoSyncEnabled,
          workout: workout,
          workoutProgress: workoutProgress,
          now: _clock().toUtc(),
          message: locationMessage,
        ),
      );
      final historyRepository = rideHistoryRepository;
      if (historyRepository != null) {
        unawaited(
          historyRepository
              .backfillCompletedRides(
                sessions: completedSessions,
                loadSummary: repository.loadSummary,
              )
              .catchError((Object _) {
                if (!isClosed) {
                  _setMessage(
                    'Sebagian riwayat lama belum dapat disiapkan untuk prediksi.',
                  );
                }
              }),
        );
      }
      if (autoSyncEnabled) {
        _startAutoSyncRetry(runImmediately: !canCloudSync);
      }
      _startAmbientLightStream();
      if (session?.status == RideSessionStatus.recording) {
        await _startLocationStream(session!.id);
        await _startBarometerStream();
        await _startMotionSensorStreams();
        _startTicker();
      }
    } catch (_) {
      emit(
        state.copyWith(
          isInitialized: true,
          isLoading: false,
          message:
              'Izin perangkat atau rekaman perjalanan tidak dapat diperiksa.',
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

  Future<void> start({RouteRecord? route, IntervalWorkout? workout}) async {
    if (state.session != null &&
        state.session!.status != RideSessionStatus.completed) {
      _setMessage('Selesaikan atau lanjutkan rekaman yang masih berjalan.');
      return;
    }
    late ReadinessReport startReadiness;
    String? workoutStartMessage;
    try {
      final readiness = await readinessChecker.check(
        requestLocationPermission: true,
        checkGpsFix: false,
      );
      startReadiness = readiness;
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
      _lastPerformanceSampleAt = null;
      _workoutCheckpoint = null;
      if (workout != null && intervalWorkoutRepository != null) {
        final checkpoint = WorkoutCheckpoint(
          sessionId: session.id,
          workoutId: workout.id,
          intervalIndex: 0,
          intervalStartElapsedSeconds: 0,
          intervalStartDistanceMeters: 0,
        );
        try {
          await intervalWorkoutRepository!.saveCheckpoint(checkpoint);
          _workoutCheckpoint = checkpoint;
        } catch (_) {
          workoutStartMessage = 'Latihan tidak tersimpan; perjalanan tetap direkam tanpa latihan.';
        }
      }
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
          performanceLocations: const [],
          now: _clock().toUtc(),
          workout: _workoutCheckpoint == null ? null : workout,
          workoutProgress: _workoutCheckpoint == null || workout == null
              ? null
              : _calculateWorkoutProgress(workout, _workoutCheckpoint!, 0, 0),
          clearWorkout: workout == null || _workoutCheckpoint == null,
          message:
              workoutStartMessage ??
              (!startReadiness.backgroundLocationGranted
                  ? 'Agar perjalanan tetap direkam saat layar mati, izinkan akses lokasi “Sepanjang waktu”.'
                  : null),
          clearMessage:
              workoutStartMessage == null &&
              startReadiness.backgroundLocationGranted,
        ),
      );
      await _prepareRouteNotifications();
      await _startLocationStream(session.id);
      await _startBarometerStream();
      await _startMotionSensorStreams();
      _startTicker();
      await _updateWorkoutProgress();
    } catch (_) {
      _setMessage(
        'Perjalanan tidak dapat dimulai. Rekaman lama tetap tersimpan.',
      );
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
      _lastPerformanceSampleAt = null;
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
      await _startLocationStream(resumed.id);
      await _startBarometerStream();
      await _startMotionSensorStreams();
      _startTicker();
      await _updateWorkoutProgress();
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
    final followUpMessages = <String>[];
    for (final stopStream in [
      _stopLocationStream,
      _stopBarometerStream,
      _stopMotionSensorStreams,
    ]) {
      try {
        await stopStream();
      } catch (_) {
        followUpMessages.add('Sebagian sensor belum berhenti dengan rapi.');
      }
    }
    _ticker?.cancel();
    late final RideSessionSnapshot completed;
    try {
      completed = await repository.finish(session.id, _clock().toUtc());
    } catch (_) {
      _setMessage(
        'Perjalanan belum dapat diselesaikan. Data di ponsel tetap aman.',
      );
      return;
    }

    final confirmation = !state.autoSyncEnabled
        ? 'Perjalanan epik Anda tersimpan aman di perangkat. Sinkronisasi cloud nonaktif.'
        : canCloudSync || canSyncSessions
        ? 'Perjalanan epik Anda tersimpan aman di perangkat. Sinkronisasi cloud akan dicoba saat koneksi tersedia.'
        : 'Perjalanan epik Anda tersimpan aman di perangkat. Untuk sinkronisasi cloud, masuk kembali ke akun dan sambungkan internet.';
    _workoutCheckpoint = null;
    _activeRoute = null;
    _routeProgressCalculator = null;
    emit(
      state.copyWith(
        session: completed,
        clearActiveRoute: true,
        clearRouteProgress: true,
        now: completed.endedAt,
        clearSummary: true,
        clearMotion: true,
        clearWorkout: true,
        message: confirmation,
        messageIsSuccess: true,
      ),
    );

    try {
      await intervalWorkoutRepository?.clearCheckpoint();
    } catch (_) {
      followUpMessages.add('Kemajuan latihan belum dibersihkan.');
    }
    try {
      final history = await repository.loadCompletedSessions();
      if (!isClosed) emit(state.copyWith(completedSessions: history));
    } catch (_) {
      followUpMessages.add('Riwayat lokal belum dapat dimuat ulang.');
    }
    try {
      await ledgerRepository?.appendSession(completed);
    } catch (_) {
      followUpMessages.add('Kode bukti perjalanan belum dibuat.');
    }
    try {
      final historyRepository = rideHistoryRepository;
      if (historyRepository != null) {
        await historyRepository.recordCompletedRide(
          await repository.loadSummary(completed.id),
        );
      }
    } catch (_) {
      followUpMessages.add('Fitur prediksi belum dapat menyimpan data latihan.');
    }
    if (followUpMessages.isNotEmpty && !isClosed) {
      _setMessage(
        '$confirmation ${followUpMessages.join(' ')}',
        isSuccess: true,
      );
    }
    if (state.autoSyncEnabled) {
      if (canCloudSync) {
        unawaited(_pushCloudSession(completed.id));
      } else {
        unawaited(
          _syncCompletedSession(completed.id, preserveLocalConfirmation: true),
        );
      }
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
          message: 'Ringkasan perjalanan yang tersimpan di ponsel tidak dapat dibuka.',
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
      if (canCloudSync) unawaited(_pushCloudSession(sessionId));
    } catch (_) {
      _setMessage('Nama atau jenis aktivitas tidak dapat disimpan.');
    }
  }

  Future<void> deleteCompletedSession(String sessionId) async {
    final sync = cloudSync;
    final remoteCopyMayExist = state.completedSessions.any(
      (session) => session.id == sessionId && session.syncStatus != 'pending',
    );
    if (remoteCopyMayExist && (sync == null || !sync.canSync)) {
      _setMessage(
        'Perjalanan belum dihapus. Sambungkan akun online untuk menghapus salinannya juga.',
      );
      return;
    }

    final deleteOnlineCopy = sync?.canSync == true;
    try {
      if (deleteOnlineCopy) await sync!.deleteSession(sessionId);
      await repository.deleteCompletedSession(sessionId);
      final history = state.completedSessions
          .where((session) => session.id != sessionId)
          .toList(growable: false);
      final clearSummary = state.summary?.session.id == sessionId;
      emit(
        state.copyWith(
          completedSessions: history,
          clearSummary: clearSummary,
          message: deleteOnlineCopy
              ? 'Perjalanan dihapus dari ponsel dan akun online.'
              : 'Perjalanan dihapus dari ponsel.',
        ),
      );
    } catch (_) {
      _setMessage(
        'Perjalanan belum dihapus. Salinan online tidak dapat dihapus. Periksa koneksi dan coba lagi.',
      );
    }
  }

  Future<void> syncSummary(
    String sessionId, {
    required bool consented,
    String? shareWithTeamId,
    bool preserveLocalConfirmation = false,
  }) async {
    final coordinator = syncCoordinator;
    if (coordinator == null) {
      _setMessage('Fitur akun online belum tersedia.');
      return;
    }
    if (state.syncingSessionId != null) return;

    final generation = ++_syncGeneration;
    emit(
      state.copyWith(
        syncingSessionId: sessionId,
        clearMessage: !preserveLocalConfirmation,
      ),
    );
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
          session: state.session?.id == sessionId
              ? summary.session
              : state.session,
          completedSessions: history,
          summary: summary,
          summaryLocations: summaryLocations,
          clearSyncingSession: true,
          message: shareWithTeamId == null
              ? 'Ringkasan perjalanan tersimpan di akun online.'
              : 'Ringkasan perjalanan dibagikan ke tim.',
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
          session: state.session?.id == sessionId
              ? summary.session
              : state.session,
          completedSessions: history,
          summary: summary,
          summaryLocations: summaryLocations,
          clearSyncingSession: true,
          message: preserveLocalConfirmation
              ? 'Perjalanan epik Anda tersimpan aman di perangkat. Sinkronisasi cloud tertunda; perjalanan ini tetap menunggu sinkronisasi.'
              : 'Ringkasan belum bisa disimpan ke akun online. Data tetap aman di ponsel; coba lagi saat internet tersedia.',
          messageIsSuccess: preserveLocalConfirmation,
        ),
      );
    }
  }

  Future<bool> _loadAutoSyncSetting() async {
    final repository = syncSettingsRepository;
    if (repository == null) {
      _syncSettingsLoaded = true;
      return false;
    }
    final enabled = await repository.loadAutoSyncEnabled();
    _syncSettingsLoaded = true;
    return enabled;
  }

  Future<void> loadSyncSettings() async {
    if (_syncSettingsLoaded || state.isLoading) return;
    try {
      final enabled = await _loadAutoSyncSetting();
      if (isClosed) return;
      emit(state.copyWith(autoSyncEnabled: enabled));
      if (enabled) _startAutoSyncRetry();
    } catch (_) {
      _setMessage('Pengaturan penyimpanan otomatis tidak dapat dibuka.');
    }
  }

  Future<void> setAutoSyncEnabled(bool enabled) async {
    final repository = syncSettingsRepository;
    if (repository == null || state.isSavingAutoSync) return;
    emit(state.copyWith(isSavingAutoSync: true, clearMessage: true));
    try {
      await repository.saveAutoSyncEnabled(enabled);
      _syncSettingsLoaded = true;
      if (isClosed) return;
      emit(state.copyWith(autoSyncEnabled: enabled, isSavingAutoSync: false));
      if (enabled) {
        _startAutoSyncRetry(runImmediately: !canCloudSync);
        if (canCloudSync) unawaited(syncCloudSessions());
      } else {
        _autoSyncRetryTimer?.cancel();
        _autoSyncRetryTimer = null;
      }
    } catch (_) {
      if (isClosed) return;
      emit(
        state.copyWith(
          isSavingAutoSync: false,
          message: 'Pengaturan penyimpanan otomatis tidak dapat disimpan.',
        ),
      );
    }
  }

  Future<void> syncPendingSessions() async {
    if (!state.autoSyncEnabled ||
        canCloudSync ||
        !canSyncSessions ||
        isClosed) {
      return;
    }
    final pendingSessions = state.completedSessions
        .where(
          (session) =>
              session.syncStatus == 'pending' || session.syncStatus == 'failed',
        )
        .toList(growable: false);
    for (final session in pendingSessions) {
      if (isClosed || !state.autoSyncEnabled || !canSyncSessions) return;
      if (state.syncingSessionId != null) return;
      await _syncCompletedSession(session.id);
    }
  }

  void _startAutoSyncRetry({bool runImmediately = true}) {
    _autoSyncRetryTimer ??= Timer.periodic(
      const Duration(minutes: 1),
      (_) => unawaited(
        canCloudSync ? _pushPendingCloudSessions() : syncPendingSessions(),
      ),
    );
    if (runImmediately) {
      unawaited(
        canCloudSync ? _pushPendingCloudSessions() : syncPendingSessions(),
      );
    }
  }

  /// Pulls every ride from the account cloud, merges it into local storage, and
  /// pushes any locally recorded rides that are not yet in the cloud.
  Future<void> syncCloudSessions() async {
    final sync = cloudSync;
    if (sync == null || !state.autoSyncEnabled || !canCloudSync || isClosed) {
      return;
    }
    try {
      await sync.pullSessions(
        shouldContinue: () =>
            !isClosed && state.autoSyncEnabled && canCloudSync,
      );
    } catch (_) {
      // Offline or transient failure: local history remains authoritative.
    }
    await _reloadCompletedSessions();
    await _pushPendingCloudSessions();
  }

  Future<void> _pushPendingCloudSessions() async {
    final sync = cloudSync;
    if (sync == null || !state.autoSyncEnabled || !canCloudSync || isClosed) {
      return;
    }
    final pending = state.completedSessions
        .where((session) => session.syncStatus != 'synced')
        .toList(growable: false);
    var changed = false;
    for (final session in pending) {
      if (isClosed || !state.autoSyncEnabled || !canCloudSync) break;
      try {
        final pushed = await sync.pushSession(
          session.id,
          shouldContinue: () =>
              !isClosed && state.autoSyncEnabled && canCloudSync,
        );
        if (pushed) changed = true;
      } catch (_) {
        // Keep the ride pending for the next attempt.
      }
    }
    if (changed) await _reloadCompletedSessions();
  }

  Future<void> _pushCloudSession(String sessionId) async {
    final sync = cloudSync;
    if (sync == null || !state.autoSyncEnabled || !canCloudSync || isClosed) {
      return;
    }
    try {
      await sync.pushSession(
        sessionId,
        shouldContinue: () =>
            !isClosed && state.autoSyncEnabled && canCloudSync,
      );
      await _reloadCompletedSessions();
    } catch (_) {
      if (!isClosed) {
        _setMessage(
          'Perjalanan epik Anda tersimpan aman di perangkat. Sinkronisasi cloud tertunda; perjalanan ini tetap menunggu sinkronisasi.',
          isSuccess: true,
        );
      }
    }
  }

  Future<void> _reloadCompletedSessions() async {
    try {
      final history = await repository.loadCompletedSessions();
      if (isClosed) return;
      emit(state.copyWith(completedSessions: history));
    } catch (_) {
      // Ignore reload failures; the in-memory history stays usable.
    }
  }

  Future<void> _syncCompletedSession(
    String sessionId, {
    bool preserveLocalConfirmation = false,
  }) async {
    if (!state.autoSyncEnabled ||
        canCloudSync ||
        !canSyncSessions ||
        state.syncingSessionId != null) {
      return;
    }
    await syncSummary(
      sessionId,
      consented: true,
      preserveLocalConfirmation: preserveLocalConfirmation,
    );
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
    double? derivedSpeed;
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
        if (distance > 0.5) {
          derivedSpeed = distance / seconds;
        }
      }
    }

    final reportedSpeed = position.speed.isFinite && position.speed > 0
        ? position.speed
        : null;

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
      speedMetersPerSecond: reportedSpeed ?? derivedSpeed ?? 0,
    );
    final updated = await repository.recordLocation(
      sessionId: sessionId,
      location: location,
      addedDistanceMeters: addedDistanceMeters,
    );
    if (updated != null && state.session?.id == sessionId) {
      final routeProgress = _routeProgressCalculator?.calculate(location);
      final now = _clock().toUtc();
      final lastSample = _lastPerformanceSampleAt;
      final shouldSamplePerformance =
          lastSample == null ||
          now.difference(lastSample) >= _performanceChartSampleInterval;
      if (shouldSamplePerformance) _lastPerformanceSampleAt = now;
      final performanceLocations = shouldSamplePerformance
          ? [...state.performanceLocations, location]
          : state.performanceLocations;
      if (performanceLocations.length > _maxPerformanceChartSamples) {
        performanceLocations.removeRange(
          0,
          performanceLocations.length - _maxPerformanceChartSamples,
        );
      }
      emit(
        state.copyWith(
          session: updated,
          recordedLocations: [...state.recordedLocations, location],
          performanceLocations: shouldSamplePerformance
              ? performanceLocations
              : null,
          routeProgress: routeProgress,
          clearRouteProgress: routeProgress == null,
          now: now,
        ),
      );
      await _updateWorkoutProgress();
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
      if (_routeNotificationsEnabled &&
          !_routeNotificationPermissionRequested) {
        _routeNotificationPermissionRequested = true;
        if (!await service.requestPermission()) {
          _routeNotificationsEnabled = false;
          _setMessage(
            'Notifikasi rute tidak aktif karena izin belum diberikan.',
          );
        }
      }
    } catch (error) {
      _routeNotificationsEnabled = false;
      _setMessage('Pengaturan notifikasi rute tidak dapat dibaca: $error');
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
    } catch (error) {
      _routeNotificationsFailed = true;
      if (!isClosed) {
        _setMessage('Notifikasi progres rute tidak dapat ditampilkan: $error');
      }
    }
  }

  Future<void> _startLocationStream(String sessionId) async {
    await _stopLocationStream();
    if (state.session?.id != sessionId ||
        state.session?.status != RideSessionStatus.recording) {
      return;
    }
    _positionSubscription = locationSource.positions.listen(
      (position) => unawaited(_handlePosition(sessionId, position)),
      onError: (Object _) =>
          _setMessage('Sinyal GPS terputus. Sesi tetap lokal.'),
    );
  }

  Future<void> _startBarometerStream() async {
    await _stopBarometerStream();
    final source = barometerSource;
    if (source == null) return;
    if (state.session?.status != RideSessionStatus.recording) return;
    _barometricPressureHpa = null;
    _barometerSubscription = source.pressureHpa.listen((pressure) {
      _barometricPressureHpa =
          pressure.isFinite && pressure >= 300 && pressure <= 1100
          ? pressure
          : null;
    }, onError: (Object _) => _barometricPressureHpa = null);
  }

  Future<void> _startMotionSensorStreams() async {
    await _stopMotionSensorStreams();
    final source = motionSensorSource;
    if (source == null) return;
    if (state.session?.status != RideSessionStatus.recording) return;
    _accelerationMagnitude = null;
    _rotationRateMagnitude = null;
    _cadenceRpm = null;
    _accelerationHistory.clear();
    _rotationHistory.clear();
    _cadenceHistory.clear();
    _cadenceEstimator.reset();
    _accelerometerSubscription = source.accelerometerReadings.listen(
      _handleAccelerometerEvent,
      onError: (Object _) =>
          _setMessage('Sensor akselerometer tidak tersedia.'),
    );
    _gyroscopeSubscription = source.gyroscopeReadings.listen(
      _handleGyroscopeEvent,
      onError: (Object _) => _setMessage('Sensor gyroscope tidak tersedia.'),
    );
    _startMotionTicker();
  }

  void _handleAccelerometerEvent(AccelerometerEvent event) {
    final magnitude = math.sqrt(
      event.x * event.x + event.y * event.y + event.z * event.z,
    );
    if (!magnitude.isFinite) return;
    _accelerationMagnitude = magnitude;
    _appendMotionSample(_accelerationHistory, magnitude);
    _cadenceRpm = _cadenceEstimator.add(magnitude, _clock().toUtc());
    if (_cadenceRpm != null) {
      _appendMotionSample(_cadenceHistory, _cadenceRpm!);
    }
  }

  void _handleGyroscopeEvent(GyroscopeEvent event) {
    final magnitude = math.sqrt(
      event.x * event.x + event.y * event.y + event.z * event.z,
    );
    if (!magnitude.isFinite) return;
    _rotationRateMagnitude = magnitude;
    _appendMotionSample(_rotationHistory, magnitude);
  }

  void _appendMotionSample(List<double> history, double value) {
    history.add(value);
    if (history.length > _maxMotionSamples) {
      history.removeRange(0, history.length - _maxMotionSamples);
    }
  }

  void _startMotionTicker() {
    _motionTicker?.cancel();
    _motionTicker = Timer.periodic(_performanceChartSampleInterval, (_) {
      _emitMotion();
    });
  }

  void _emitMotion() {
    if (isClosed || state.session?.status != RideSessionStatus.recording) {
      return;
    }
    emit(
      state.copyWith(
        motion: MotionSnapshot(
          accelerationMagnitude: _accelerationMagnitude,
          rotationRateMagnitude: _rotationRateMagnitude,
          cadenceRpm: _cadenceRpm,
          accelerationHistory: List<double>.of(_accelerationHistory),
          rotationHistory: List<double>.of(_rotationHistory),
          cadenceHistory: List<double>.of(_cadenceHistory),
        ),
      ),
    );
  }

  Future<void> _stopLocationStream() async {
    final subscription = _positionSubscription;
    _positionSubscription = null;
    await subscription?.cancel();
  }

  Future<void> _stopBarometerStream() async {
    final subscription = _barometerSubscription;
    _barometerSubscription = null;
    await subscription?.cancel();
  }

  Future<void> _stopMotionSensorStreams() async {
    _motionTicker?.cancel();
    _motionTicker = null;
    final accelerometerSubscription = _accelerometerSubscription;
    final gyroscopeSubscription = _gyroscopeSubscription;
    _accelerometerSubscription = null;
    _gyroscopeSubscription = null;
    await Future.wait([
      if (accelerometerSubscription != null) accelerometerSubscription.cancel(),
      if (gyroscopeSubscription != null) gyroscopeSubscription.cancel(),
    ]);
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (state.session?.status == RideSessionStatus.recording) {
        emit(state.copyWith(now: _clock().toUtc()));
        unawaited(_updateWorkoutProgress());
      }
    });
  }

  Future<void> _updateWorkoutProgress() async {
    if (_updatingWorkout || isClosed) return;
    final workout = state.workout;
    final checkpoint = _workoutCheckpoint;
    final session = state.session;
    if (workout == null || checkpoint == null || session == null) return;
    _updatingWorkout = true;
    try {
      final elapsedSeconds = state.elapsed.inSeconds;
      final progress = _calculateWorkoutProgress(
        workout,
        checkpoint,
        elapsedSeconds,
        session.distanceMeters,
      );
      if (session.status != RideSessionStatus.recording) {
        emit(state.copyWith(workoutProgress: progress));
        return;
      }
      if (progress.remainingValue > 0) {
        emit(state.copyWith(workoutProgress: progress));
        return;
      }

      final nextIndex = checkpoint.intervalIndex + 1;
      if (nextIndex >= workout.intervals.length) {
        String? message;
        try {
          await intervalWorkoutRepository?.clearCheckpoint();
        } catch (_) {
          message = 'Workout selesai, tetapi progres lokal belum dibersihkan.';
        }
        _workoutCheckpoint = null;
        emit(
          state.copyWith(
            workoutProgress: WorkoutIntervalProgress(
              interval: null,
              index: workout.intervals.length,
              total: workout.intervals.length,
              remainingValue: 0,
              isComplete: true,
            ),
            clearWorkout: true,
            message: message ?? 'Workout selesai.',
          ),
        );
        await _playWorkoutCue(workout);
        return;
      }

      final nextCheckpoint = WorkoutCheckpoint(
        sessionId: checkpoint.sessionId,
        workoutId: checkpoint.workoutId,
        intervalIndex: nextIndex,
        intervalStartElapsedSeconds: elapsedSeconds,
        intervalStartDistanceMeters: session.distanceMeters,
      );
      _workoutCheckpoint = nextCheckpoint;
      String? message;
      try {
        await intervalWorkoutRepository?.saveCheckpoint(nextCheckpoint);
      } catch (_) {
        message = 'Progres workout belum tersimpan untuk pemulihan aplikasi.';
      }
      final nextProgress = _calculateWorkoutProgress(
        workout,
        nextCheckpoint,
        elapsedSeconds,
        session.distanceMeters,
      );
      emit(
        state.copyWith(
          workoutProgress: nextProgress,
          message: message,
          clearMessage: message == null,
        ),
      );
      await _playWorkoutCue(workout);
    } finally {
      _updatingWorkout = false;
    }
  }

  WorkoutIntervalProgress _calculateWorkoutProgress(
    IntervalWorkout workout,
    WorkoutCheckpoint checkpoint,
    int elapsedSeconds,
    double distanceMeters,
  ) {
    if (checkpoint.intervalIndex >= workout.intervals.length) {
      return WorkoutIntervalProgress(
        interval: null,
        index: workout.intervals.length,
        total: workout.intervals.length,
        remainingValue: 0,
        isComplete: true,
      );
    }
    final interval = workout.intervals[checkpoint.intervalIndex];
    final progress = interval.targetType == WorkoutTargetType.duration
        ? elapsedSeconds - checkpoint.intervalStartElapsedSeconds
        : (distanceMeters - checkpoint.intervalStartDistanceMeters).floor();
    return WorkoutIntervalProgress(
      interval: interval,
      index: checkpoint.intervalIndex,
      total: workout.intervals.length,
      remainingValue: (interval.targetValue - progress)
          .clamp(0, interval.targetValue)
          .toDouble(),
      isComplete: false,
    );
  }

  Future<void> _playWorkoutCue(IntervalWorkout workout) async {
    // Cue channels are best-effort and must never interrupt ride capture.
    var cueFailed = false;
    if (workout.audioCueEnabled) {
      try {
        await SystemSound.play(SystemSoundType.alert);
      } on Object {
        cueFailed = true;
      }
    }
    if (workout.hapticCueEnabled) {
      try {
        await HapticFeedback.mediumImpact();
      } on Object {
        cueFailed = true;
      }
    }
    if (cueFailed && !isClosed) {
      emit(
        state.copyWith(
          message: 'Cue workout tidak tersedia; perekaman tetap berjalan.',
        ),
      );
    }
  }

  void _setMessage(String message, {bool isSuccess = false}) =>
      emit(state.copyWith(message: message, messageIsSuccess: isSuccess));

  void clearMessage() => emit(state.copyWith(clearMessage: true));

  void _startAmbientLightStream() {
    final source = ambientLightSource;
    if (source == null || _ambientLightSubscription != null) return;
    try {
      _ambientLightSubscription = source.readings.listen(
        (lux) {
          final isBright = shouldUseHighAmbientContrast(
            isBright: state.isAmbientBright,
            lux: lux,
          );
          if (isBright != state.isAmbientBright && !isClosed) {
            emit(state.copyWith(isAmbientBright: isBright));
          }
        },
        onError: (Object _) {
          if (!isClosed) {
            emit(
              state.copyWith(
                isAmbientBright: false,
                message: 'Sensor cahaya tidak tersedia; tampilan menggunakan kontras standar.',
              ),
            );
          }
        },
        onDone: () {
          if (!isClosed && state.isAmbientBright) {
            emit(state.copyWith(isAmbientBright: false));
          }
        },
      );
    } catch (_) {
      emit(
        state.copyWith(
          isAmbientBright: false,
          message: 'Sensor cahaya tidak tersedia; tampilan menggunakan kontras standar.',
        ),
      );
    }
  }

  @override
  Future<void> close() async {
    _ticker?.cancel();
    _autoSyncRetryTimer?.cancel();
    await _ambientLightSubscription?.cancel();
    await _stopLocationStream();
    await _stopBarometerStream();
    await _stopMotionSensorStreams();
    await super.close();
  }
}

class _CadenceEstimator {
  static const Duration _window = Duration(seconds: 4);

  final List<double> _magnitudes = [];
  final List<DateTime> _times = [];

  double? add(double magnitude, DateTime at) {
    if (!magnitude.isFinite) return null;
    _magnitudes.add(magnitude);
    _times.add(at);
    final cutoff = at.subtract(_window);
    while (_times.isNotEmpty && _times.first.isBefore(cutoff)) {
      _times.removeAt(0);
      _magnitudes.removeAt(0);
    }
    if (_magnitudes.length < 30 || _times.length < 2) return null;

    final mean = _magnitudes.reduce((a, b) => a + b) / _magnitudes.length;
    final minValue = _magnitudes.reduce(math.min);
    final maxValue = _magnitudes.reduce(math.max);
    if (maxValue - minValue < 0.5) return null;

    var crossings = 0;
    for (var i = 1; i < _magnitudes.length; i++) {
      if (_magnitudes[i - 1] <= mean && _magnitudes[i] > mean) {
        crossings++;
      }
    }
    final spanSeconds =
        _times.last.difference(_times.first).inMicroseconds /
        Duration.microsecondsPerSecond;
    if (spanSeconds <= 0) return null;
    final rpm = crossings / spanSeconds * 60;
    if (rpm < 20 || rpm > 220) return null;
    return rpm;
  }

  void reset() {
    _magnitudes.clear();
    _times.clear();
  }
}
