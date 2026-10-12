import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart' as latlong;

import '../../../core/units/unit_settings_cubit.dart';
import '../../../core/units/unit_system.dart';
import '../../../app/theme/senapath_design.dart';
import '../../routes/data/route_file_exchange.dart';
import '../../routes/presentation/explore_map.dart';
import '../../routes/presentation/routes_cubit.dart';
import '../../emergency/presentation/emergency_cubit.dart';
import '../../profile/domain/user_profile.dart';
import '../../profile/presentation/profile_cubit.dart';
import '../../workouts/domain/interval_workout.dart';
import '../../workouts/presentation/interval_workout_cubit.dart';
import '../data/readiness_checker.dart';
import '../data/session_file_service.dart';
import '../domain/ride_session.dart';
import 'session_cubit.dart';

class SessionScreen extends StatefulWidget {
  const SessionScreen({
    this.showMap = true,
    this.showHistory = true,
    this.showSummary = true,
    this.historyOnly = false,
    this.summarySessionId,
    this.initialPanelSize = 0.7,
    this.compactControls = false,
    this.hideReadinessDetails = false,
    super.key,
  });

  final bool showMap;
  final bool showHistory;
  final bool showSummary;
  final bool historyOnly;
  final String? summarySessionId;
  final double initialPanelSize;
  final bool compactControls;
  final bool hideReadinessDetails;

  @override
  State<SessionScreen> createState() => _SessionScreenState();
}

class _SessionScreenState extends State<SessionScreen>
    with WidgetsBindingObserver {
  bool _initialized = false;
  String? _loadedSummarySessionId;
  static const _fileExchange = RouteFileExchange(SessionFileService());

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      unawaited(context.read<RideSessionCubit>().initialize());
    }
    final sessionId = widget.summarySessionId;
    if (sessionId != null && _loadedSummarySessionId != sessionId) {
      _loadedSummarySessionId = sessionId;
      unawaited(context.read<RideSessionCubit>().loadSummary(sessionId));
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        mounted &&
        context.read<RideSessionCubit>().state.session == null) {
      unawaited(
        context.read<RideSessionCubit>().checkReadiness(checkGpsFix: false),
      );
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<RideSessionCubit, RideSessionState>(
      listenWhen: (previous, current) =>
          previous.message != current.message && current.message != null,
      listener: (context, state) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(state.message!)));
        context.read<RideSessionCubit>().clearMessage();
      },
      child: BlocBuilder<RideSessionCubit, RideSessionState>(
        builder: (context, state) {
          if (state.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          final unitSystem = context
              .watch<UnitSettingsCubit>()
              .state
              .unitSystem;
          final readiness = state.readiness;
          final session = state.session;

          if (widget.historyOnly) {
            if (widget.summarySessionId case final sessionId?) {
              final summary = state.summary;
              if (state.isLoadingSummary || summary == null) {
                return Center(
                  child: state.isLoadingSummary
                      ? const CircularProgressIndicator()
                      : const Text('Ringkasan sesi tidak tersedia.'),
                );
              }
              if (summary.session.id != sessionId) {
                return const Center(child: CircularProgressIndicator());
              }
              return ListView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                children: [
                  _buildSummaryDetail(
                    context,
                    summary,
                    state.summaryLocations,
                    unitSystem,
                  ),
                ],
              );
            }
            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
              children: [
                if (state.completedSessions.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 32),
                    child: Text(
                      'Sesi yang sudah selesai akan muncul di sini.',
                      textAlign: TextAlign.center,
                    ),
                  )
                else ...[
                  OutlinedButton.icon(
                    onPressed: () =>
                        _exportAllSessions(context, state.completedSessions),
                    icon: const Icon(Icons.download_outlined),
                    label: const Text('Ekspor semua sesi dan jejak GPS'),
                  ),
                  const SizedBox(height: 12),
                  _buildHistory(context, state.completedSessions, unitSystem),
                ],
              ],
            );
          }

          final recordedLocations = state.recordedLocations;
          final trackPoints = [
            for (final location in recordedLocations)
              latlong.LatLng(location.latitude, location.longitude),
          ];
          final currentLocation = recordedLocations.isEmpty
              ? null
              : trackPoints.last;

          return LayoutBuilder(
            builder: (context, constraints) => Stack(
              fit: StackFit.expand,
              children: [
                if (widget.showMap)
                  ExploreMap(
                    height: constraints.maxHeight,
                    borderRadius: 0,
                    trackPoints: trackPoints,
                    currentLocation: currentLocation,
                    followLocation:
                        session?.status == RideSessionStatus.recording,
                    showEmptyMessage: false,
                  ),
                DraggableScrollableSheet(
                  initialChildSize: widget.initialPanelSize,
                  minChildSize: 0.2,
                  maxChildSize: 0.92,
                  builder: (context, scrollController) => Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Material(
                      color: Theme.of(context).colorScheme.surface
                          .withValues(alpha: 0.97),
                      shape: RoundedRectangleBorder(
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(4),
                        ),
                        side: BorderSide(
                          color: Theme.of(context).colorScheme.outline,
                          width: 2,
                        ),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: ListView(
                        controller: scrollController,
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                        children: [
                          Center(
                            child: Container(
                              width: 36,
                              height: 4,
                              decoration: BoxDecoration(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant
                                    .withValues(alpha: 0.35),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          if (widget.compactControls) ...[
                            _buildCompactControls(context, state, unitSystem),
                            if (session != null &&
                                session.status !=
                                    RideSessionStatus.completed) ...[
                              const SizedBox(height: 24),
                              _buildLivePerformance(
                                context,
                                session,
                                state.recordedLocations,
                                state.elapsed,
                                unitSystem,
                              ),
                            ],
                            if (!widget.hideReadinessDetails &&
                                (session == null ||
                                    session.status ==
                                        RideSessionStatus.completed)) ...[
                              const SizedBox(height: 8),
                              Theme(
                                data: Theme.of(context)
                                    .copyWith(dividerColor: Colors.transparent),
                                child: ExpansionTile(
                                  tilePadding: EdgeInsets.zero,
                                  childrenPadding: EdgeInsets.zero,
                                  title: const Text(
                                    'Detail kesiapan & izin',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  children: [
                                    _buildReadiness(context, readiness, state),
                                  ],
                                ),
                              ),
                            ],
                          ] else ...[
                            _buildSessionStatus(context, session),
                            if (session != null) ...[
                              if (state.workout?.visualCueEnabled == true &&
                                  state.workoutProgress != null) ...[
                                const SizedBox(height: 16),
                                _buildWorkoutProgress(context, state),
                              ],
                              const SizedBox(height: 24),
                              _buildMetrics(
                                context,
                                session,
                                state.elapsed,
                                unitSystem,
                              ),
                              const SizedBox(height: 16),
                              _buildSessionControls(context, state),
                            ] else ...[
                              const SizedBox(height: 24),
                              _buildReadiness(context, readiness, state),
                              const SizedBox(height: 20),
                              _buildWorkoutPicker(context),
                              const SizedBox(height: 10),
                              _buildStartControl(context, state),
                            ],
                          ],
                          if (widget.showHistory &&
                              state.completedSessions.isNotEmpty) ...[
                            const SizedBox(height: 28),
                            _buildHistory(
                              context,
                              state.completedSessions,
                              unitSystem,
                            ),
                          ],
                          if (state.isLoadingSummary) ...[
                            const SizedBox(height: 20),
                            const LinearProgressIndicator(),
                          ],
                          if (widget.showSummary)
                            if (state.summary case final summary?) ...[
                              const SizedBox(height: 24),
                              _buildSummaryDetail(
                                context,
                                summary,
                                state.summaryLocations,
                                unitSystem,
                              ),
                            ],
                          const SizedBox(height: 24),
                          if (widget.showMap) ...[
                            _buildEmergencyPanel(
                              context,
                              context.watch<ProfileCubit>().state.contacts,
                              context.watch<EmergencyCubit>().state,
                            ),
                            const SizedBox(height: 18),
                            const Text(
                              'Sesi dan titik lokasi tetap tersimpan '
                              'terenkripsi di perangkat. Hanya ringkasan yang '
                              'dikirim setelah kamu menyetujuinya.',
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmergencyPanel(
    BuildContext context,
    List<EmergencyContact> contacts,
    EmergencyState emergencyState,
  ) {
    final contact = contacts.isEmpty ? null : contacts.first;
    final isCountingDown = emergencyState.isCountingDown;
    return SenapathCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.sos, color: Theme.of(context).colorScheme.error),
                const SizedBox(width: 8),
                Text(
                  'SOS darurat',
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (contact == null)
              const Text(
                'Tambahkan minimal satu kontak darurat di Profil sebelum '
                'menggunakan SOS.',
              )
            else if (isCountingDown) ...[
              Text(
                'Potensi insiden. WhatsApp akan dibuka untuk ${contact.name} '
                'setelah hitung mundur selesai.',
              ),
              const SizedBox(height: 12),
              Center(
                child: Text(
                  '${emergencyState.secondsRemaining}',
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton.tonalIcon(
                  onPressed: () =>
                      context.read<EmergencyCubit>().cancelCountdown(),
                  icon: const Icon(Icons.close),
                  label: const Text('Batalkan SOS'),
                ),
              ),
            ] else ...[
              Text('Kontak tujuan: ${contact.name} · ${contact.phone}'),
              const SizedBox(height: 4),
              Text(
                'SOS membuka WhatsApp dengan pesan dan lokasi terakhir. '
                'Kamu tetap harus menekan Kirim.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => context
                      .read<EmergencyCubit>()
                      .startCountdown(contact: contact),
                  icon: const Icon(Icons.warning_amber),
                  label: const Text('Mulai hitung mundur SOS'),
                ),
              ),
              if (emergencyState.message != null) ...[
                const SizedBox(height: 8),
                Text(
                  emergencyState.message!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCompactControls(
    BuildContext context,
    RideSessionState state,
    UnitSystem unitSystem,
  ) {
    final session = state.session;
    final theme = Theme.of(context);
    final gpsAccuracy = state.readiness?.gpsAccuracyMeters;
    final isRecording = session?.status == RideSessionStatus.recording;
    final statusLabel = switch (session?.status) {
      RideSessionStatus.recording => 'SEDANG MEREKAM',
      RideSessionStatus.paused => 'SESI DIJEDA',
      RideSessionStatus.completed => 'SESI SELESAI',
      null => 'SIAP BERSEPEDA',
    };
    final statusColor = isRecording
        ? theme.colorScheme.error
        : theme.colorScheme.primary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(
              isRecording ? Icons.fiber_manual_record : Icons.directions_bike,
              color: statusColor,
              size: 17,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                statusLabel,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: statusColor,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.7,
                ),
              ),
            ),
            if (session == null)
              Text(
                state.readiness?.gpsFixChecked != true
                    ? 'GPS belum dicek'
                    : state.readiness?.gpsFixAvailable == true
                    ? 'GPS siap'
                    : 'GPS belum mendapat fix',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
        if (session == null) ...[
          if (widget.hideReadinessDetails) ...[
            const SizedBox(height: 14),
            _buildWorkoutPicker(context),
            const SizedBox(height: 8),
            Text(
              'Mulai rekam perjalananmu. Izin lokasi akan diminta saat '
              'diperlukan.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed:
                  state.isCheckingReadiness ||
                      context.watch<IntervalWorkoutCubit>().state.isLoading
                  ? null
                  : () => _requestLocationAndStart(context),
              icon: state.isCheckingReadiness
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.play_arrow),
              label: const Text('Mulai sesi'),
            ),
          ] else ...[
            const SizedBox(height: 14),
            _buildWorkoutPicker(context),
            const SizedBox(height: 8),
            if (state.readiness?.gpsMessage case final gpsMessage?)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(gpsMessage, style: theme.textTheme.bodySmall),
              ),
            Row(
              children: [
                Expanded(
                  child: _ReadinessPill(
                    label: 'Lokasi',
                    isReady:
                        state.readiness?.locationPermissionGranted ?? false,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _ReadinessPill(
                    label: gpsAccuracy == null
                        ? 'GPS'
                        : 'GPS ±${gpsAccuracy.toStringAsFixed(0)} m',
                    isReady:
                        state.readiness?.locationServicesEnabled == true &&
                        state.readiness?.gpsFixAvailable == true,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: state.isCheckingReadiness
                  ? null
                  : state.readiness?.locationPermanentlyDenied == true
                  ? () =>
                        context.read<RideSessionCubit>().openLocationSettings()
                  : state.readiness?.locationServicesEnabled == false
                  ? () => context
                        .read<RideSessionCubit>()
                        .openLocationServiceSettings()
                  : () => context.read<RideSessionCubit>().checkReadiness(
                      requestLocationPermission:
                          state.readiness?.locationPermissionGranted != true,
                      checkGpsFix: true,
                    ),
              icon: state.isCheckingReadiness
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.gps_fixed),
              label: Text(
                state.readiness?.locationPermanentlyDenied == true
                    ? 'Buka pengaturan izin lokasi'
                    : state.readiness?.locationServicesEnabled == false
                    ? 'Buka pengaturan lokasi'
                    : state.readiness?.locationPermissionGranted != true
                    ? 'Izinkan lokasi & cek GPS'
                    : 'Cek GPS sekarang',
              ),
            ),
            const SizedBox(height: 8),
            _buildStartControl(context, state),
          ],
        ] else ...[
          const SizedBox(height: 6),
          Center(
            child: Text(
              _formatDuration(state.elapsed),
              style: theme.textTheme.displaySmall?.copyWith(
                fontWeight: FontWeight.w800,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          Center(
            child: Text(
              'DURASI',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                letterSpacing: 1.6,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (state.workout?.visualCueEnabled == true &&
              state.workoutProgress != null) ...[
            const SizedBox(height: 12),
            _buildWorkoutProgress(context, state),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _CompactMetric(
                  label: 'Jarak',
                  value: _formatDistance(
                    session.distanceMeters,
                    unitSystem == UnitSystem.metric,
                  ),
                  icon: Icons.route_outlined,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _CompactMetric(
                  label: 'Kecepatan',
                  value: _formatSpeed(
                    session.currentSpeedMetersPerSecond,
                    unitSystem,
                  ),
                  icon: Icons.speed,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _buildSessionControls(context, state),
        ],
      ],
    );
  }

  Widget _buildLivePerformance(
    BuildContext context,
    RideSessionSnapshot session,
    List<TelemetryLocation> locations,
    Duration elapsed,
    UnitSystem unitSystem,
  ) {
    final metric = unitSystem == UnitSystem.metric;
    final speedFactor = metric ? 3.6 : 2.236936;
    final speedUnit = metric ? 'km/j' : 'mph';
    final speeds = locations
        .map((location) => location.speedMetersPerSecond)
        .where((speed) => speed.isFinite && speed >= 0)
        .map((speed) => speed * speedFactor)
        .toList(growable: false);
    final averageSpeed = elapsed.inSeconds > 0
        ? session.distanceMeters / elapsed.inSeconds * speedFactor
        : 0.0;
    final maxSpeed = speeds.isEmpty
        ? 0.0
        : speeds.reduce((first, next) => math.max(first, next).toDouble());
    final elevationSamples = _elevationProfile(
      locations,
      source: 'Estimasi GPS',
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Performa sesi',
          style: Theme.of(context).textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        _SummaryMetricCard(
          children: [
            _MetricValue(
              label: 'Kecepatan rata-rata',
              value: averageSpeed.toStringAsFixed(1),
              unit: speedUnit,
            ),
            _MetricValue(
              label: 'Kecepatan maksimum',
              value: maxSpeed.toStringAsFixed(1),
              unit: speedUnit,
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          'Perubahan kecepatan ($speedUnit)',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        if (speeds.length >= 5)
          _SpeedGraph(values: speeds)
        else
          const Text('Grafik muncul setelah terkumpul cukup sampel GPS.'),
        if (elevationSamples.length >= 2) ...[
          const SizedBox(height: 20),
          Text(
            'Perubahan elevasi GPS',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          _SpeedGraph(values: elevationSamples),
        ],
      ],
    );
  }

  Widget _buildSessionStatus(
    BuildContext context,
    RideSessionSnapshot? session,
  ) {
    final theme = Theme.of(context);
    final status = switch (session?.status) {
      RideSessionStatus.recording => ('Merekam', Icons.fiber_manual_record),
      RideSessionStatus.paused => ('Dijeda', Icons.pause_circle_outline),
      RideSessionStatus.completed => ('Selesai', Icons.check_circle_outline),
      null => ('Siap bersepeda?', Icons.directions_bike_outlined),
    };

    return Row(
      children: [
        Icon(status.$2, color: theme.colorScheme.primary, size: 30),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                status.$1,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                switch (session?.status) {
                  null => 'Periksa perangkat sebelum merekam.',
                  RideSessionStatus.recording => 'Tersimpan lokal. Perekaman saat layar mati belum didukung atau diverifikasi.',
                  RideSessionStatus.paused =>
                    'Sesi tersimpan lokal dan menunggu dilanjutkan.',
                  RideSessionStatus.completed => 'Data sesi tersimpan lokal.',
                },
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildReadiness(
    BuildContext context,
    ReadinessReport? readiness,
    RideSessionState state,
  ) {
    if (readiness == null) {
      return const Center(child: Text('Status kesiapan belum tersedia.'));
    }

    final locationLabel = readiness.locationPermissionGranted
        ? 'Izin lokasi diizinkan'
        : readiness.locationPermanentlyDenied
        ? 'Izin lokasi ditolak permanen'
        : 'Izin lokasi belum diberikan';
    final gpsLabel = !readiness.locationServicesEnabled
        ? 'Layanan lokasi perangkat nonaktif'
        : !readiness.gpsFixChecked
        ? 'GPS belum dicek'
        : readiness.gpsFixAvailable
        ? 'GPS siap · akurasi ±${readiness.gpsAccuracyMeters!.toStringAsFixed(0)} m'
        : 'GPS belum mendapat fix';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Pemeriksaan pra-balapan',
          style: Theme.of(context).textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        _ReadinessLine(
          label: locationLabel,
          isReady: readiness.locationPermissionGranted,
        ),
        if (readiness.gpsMessage case final message?)
          Padding(
            padding: const EdgeInsets.only(left: 34, bottom: 8),
            child: Text(message, style: Theme.of(context).textTheme.bodySmall),
          ),
        _ReadinessLine(
          label: gpsLabel,
          isReady:
              readiness.locationServicesEnabled && readiness.gpsFixAvailable,
          isWarning:
              readiness.locationPermissionGranted && !readiness.gpsFixAvailable,
        ),
        _ReadinessLine(
          label: readiness.accelerometerAvailable
              ? 'Accelerometer tersedia'
              : 'Accelerometer tidak tersedia',
          isReady: readiness.accelerometerAvailable,
        ),
        _ReadinessLine(
          label: readiness.gyroscopeAvailable
              ? 'Gyroscope tersedia'
              : 'Gyroscope tidak tersedia',
          isReady: readiness.gyroscopeAvailable,
        ),
        _ReadinessLine(
          label: readiness.notificationsGranted
              ? 'Izin notifikasi diberikan'
              : 'Izin notifikasi belum diberikan',
          isReady: readiness.notificationsGranted,
          isWarning: true,
        ),
        if (!readiness.notificationsGranted) ...[
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: state.isCheckingReadiness
                ? null
                : readiness.notificationsPermanentlyDenied
                ? () => context
                      .read<RideSessionCubit>()
                      .openNotificationSettings()
                : () => context.read<RideSessionCubit>().checkReadiness(
                    requestNotificationPermission: true,
                  ),
            icon: Icon(
              readiness.notificationsPermanentlyDenied
                  ? Icons.settings_outlined
                  : Icons.notifications_active_outlined,
            ),
            label: Text(
              readiness.notificationsPermanentlyDenied
                  ? 'Buka pengaturan notifikasi'
                  : 'Izinkan notifikasi',
            ),
          ),
        ],
        if (!readiness.locationPermissionGranted) ...[
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: state.isCheckingReadiness
                  ? null
                  : readiness.locationPermanentlyDenied
                  ? () =>
                        context.read<RideSessionCubit>().openLocationSettings()
                  : () => context.read<RideSessionCubit>().checkReadiness(
                      requestLocationPermission: true,
                      checkGpsFix: true,
                    ),
              icon: Icon(
                readiness.locationPermanentlyDenied
                    ? Icons.settings_outlined
                    : Icons.my_location,
              ),
              label: Text(
                readiness.locationPermanentlyDenied
                    ? 'Buka pengaturan izin'
                    : 'Izinkan lokasi',
              ),
            ),
          ),
        ],
        if (readiness.locationPermissionGranted &&
            !readiness.locationServicesEnabled) ...[
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () =>
                context.read<RideSessionCubit>().openLocationServiceSettings(),
            icon: const Icon(Icons.location_on_outlined),
            label: const Text('Buka pengaturan lokasi perangkat'),
          ),
        ],
        if (readiness.locationPermissionGranted &&
            readiness.hasLimitedMetrics) ...[
          const SizedBox(height: 10),
          Text(
            'Sebagian metrik mungkin terbatas. Kamu tetap dapat mulai; '
            'akurasi bergantung pada GPS dan sensor yang tersedia.',
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: Theme.of(context).colorScheme.tertiary),
          ),
        ],
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: state.isCheckingReadiness
              ? null
              : () => context.read<RideSessionCubit>().checkReadiness(
                  checkGpsFix: true,
                ),
          icon: state.isCheckingReadiness
              ? const SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.refresh),
          label: const Text('Periksa kembali'),
        ),
      ],
    );
  }

  Widget _buildMetrics(
    BuildContext context,
    RideSessionSnapshot session,
    Duration elapsed,
    UnitSystem unitSystem,
  ) {
    final metric = unitSystem == UnitSystem.metric;
    final distance = metric
        ? session.distanceMeters / 1000
        : session.distanceMeters / 1609.344;
    final speed = metric
        ? session.currentSpeedMetersPerSecond * 3.6
        : session.currentSpeedMetersPerSecond * 2.236936;
    final distanceUnit = metric ? 'km' : 'mi';
    final speedUnit = metric ? 'km/j' : 'mph';
    final duration = _formatDuration(elapsed);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: _MetricValue(
                label: 'Jarak',
                value: distance.toStringAsFixed(2),
                unit: distanceUnit,
              ),
            ),
            Expanded(
              child: _MetricValue(label: 'Durasi', value: duration, unit: ''),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: _MetricValue(
                label: 'Kecepatan GPS',
                value: speed.toStringAsFixed(1),
                unit: speedUnit,
              ),
            ),
            Expanded(
              child: _MetricValue(
                label: 'Sumber posisi',
                value: session.gpsAccuracyMeters == null
                    ? 'Menunggu GPS'
                    : 'GPS',
                unit: session.gpsAccuracyMeters == null
                    ? ''
                    : '±${session.gpsAccuracyMeters!.toStringAsFixed(0)} m',
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStartControl(BuildContext context, RideSessionState state) {
    final isLoadingWorkout = context
        .watch<IntervalWorkoutCubit>()
        .state
        .isLoading;
    return SenapathButton(
      onPressed: state.canStart && !isLoadingWorkout
          ? () => context.read<RideSessionCubit>().start(
              route: context.read<RoutesCubit>().state.sessionRoute,
              workout: context
                  .read<IntervalWorkoutCubit>()
                  .state
                  .selectedWorkout,
            )
          : null,
      icon: Icons.play_arrow,
      label: 'Mulai sesi',
    );
  }

  Widget _buildWorkoutPicker(BuildContext context) {
    final workout = context.watch<IntervalWorkoutCubit>().state.selectedWorkout;
    return OutlinedButton.icon(
      onPressed: () => context.push('/routes/workouts'),
      icon: const Icon(Icons.timer_outlined),
      label: Text(
        workout == null
            ? 'Pilih workout interval (opsional)'
            : 'Workout: ${workout.name}',
      ),
    );
  }

  Widget _buildWorkoutProgress(BuildContext context, RideSessionState state) {
    final progress = state.workoutProgress!;
    final interval = progress.interval;
    if (interval == null) return const SizedBox.shrink();
    final remaining = switch (interval.targetType) {
      WorkoutTargetType.duration =>
        '${progress.remainingValue.ceil()} detik tersisa',
      WorkoutTargetType.distance =>
        '${(progress.remainingValue / 1000).toStringAsFixed(2)} km tersisa',
    };
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            const Icon(Icons.timer_outlined),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Workout · ${progress.index + 1}/${progress.total}',
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                  Text(
                    interval.name,
                    style: Theme.of(context).textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  Text(
                    '${interval.isRecovery ? 'Pemulihan · ' : ''}$remaining',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSessionControls(BuildContext context, RideSessionState state) {
    final session = state.session!;
    if (session.status == RideSessionStatus.completed) {
      return Column(
        children: [
          SenapathButton(
            onPressed: state.canStart
                ? () => context.read<RideSessionCubit>().start(
                    route: context.read<RoutesCubit>().state.sessionRoute,
                    workout: context
                        .read<IntervalWorkoutCubit>()
                        .state
                        .selectedWorkout,
                  )
                : null,
            icon: Icons.add,
            label: 'Mulai sesi baru',
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: () => context.go('/profile/sessions'),
            icon: const Icon(Icons.summarize_outlined),
            label: const Text('Lihat ringkasan di Profil'),
          ),
        ],
      );
    }

    if (session.status == RideSessionStatus.paused) {
      return Row(
        children: [
          Expanded(
            child: FilledButton.icon(
              onPressed: state.canStart
                  ? () => context.read<RideSessionCubit>().resume(
                      route: context.read<RoutesCubit>().state.sessionRoute,
                    )
                  : null,
              icon: const Icon(Icons.play_arrow),
              label: const Text('Lanjutkan'),
            ),
          ),
          const SizedBox(width: 12),
          IconButton.filledTonal(
            tooltip: 'Akhiri sesi',
            onPressed: () => context.read<RideSessionCubit>().finish(),
            icon: const Icon(Icons.stop),
          ),
        ],
      );
    }

    return Row(
      children: [
        Expanded(
          child: FilledButton.tonalIcon(
            onPressed: () => context.read<RideSessionCubit>().pause(),
            icon: const Icon(Icons.pause),
            label: const Text('Jeda'),
          ),
        ),
        const SizedBox(width: 12),
        IconButton.filled(
          tooltip: 'Akhiri sesi',
          onPressed: () => _confirmFinish(context),
          icon: const Icon(Icons.stop),
        ),
      ],
    );
  }

  Future<void> _requestLocationAndStart(BuildContext context) async {
    final sessionCubit = context.read<RideSessionCubit>();
    await sessionCubit.checkReadiness(requestLocationPermission: true);
    if (!context.mounted) return;

    final readiness = sessionCubit.state.readiness;
    if (readiness?.canStartRecording != true) {
      final message = readiness?.locationServicesEnabled == false
          ? 'Aktifkan layanan lokasi untuk mulai merekam.'
          : readiness?.locationPermanentlyDenied == true
          ? 'Izinkan lokasi dari pengaturan perangkat untuk mulai merekam.'
          : 'Izin lokasi diperlukan untuk mulai merekam.';
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));
      if (readiness?.locationServicesEnabled == false) {
        await sessionCubit.openLocationServiceSettings();
      } else if (readiness?.locationPermanentlyDenied == true) {
        await sessionCubit.openLocationSettings();
      }
      return;
    }
    await sessionCubit.start(
      route: context.read<RoutesCubit>().state.sessionRoute,
      workout: context.read<IntervalWorkoutCubit>().state.selectedWorkout,
    );
  }

  Widget _buildHistory(
    BuildContext context,
    List<RideSessionSnapshot> sessions,
    UnitSystem unitSystem,
  ) {
    final metric = unitSystem == UnitSystem.metric;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Riwayat sesi',
          style: Theme.of(context).textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        for (final session in sessions)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.route_outlined),
            title: Text(
              session.title.isEmpty
                  ? _formatSessionDate(session.startedAt)
                  : session.title,
            ),
            subtitle: Text(
              '${_activityTypeLabel(session.activityType)} · '
              '${_formatDistance(session.distanceMeters, metric)} · '
              '${_formatDuration(session.durationAt(session.endedAt ?? session.startedAt))} · '
              '${_syncStatusLabel(session.syncStatus)}',
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip:
                      'Hapus ${session.title.isEmpty ? 'sesi' : session.title}',
                  onPressed: () => _confirmDeleteSession(context, session),
                  icon: const Icon(Icons.delete_outline),
                ),
                const Icon(Icons.chevron_right),
              ],
            ),
            onTap: () => context.push('/profile/sessions/${session.id}'),
          ),
      ],
    );
  }

  Future<void> _confirmDeleteSession(
    BuildContext context,
    RideSessionSnapshot session,
  ) async {
    final approved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => SenapathAlertDialog(
        title: const Text('Hapus aktivitas lokal?'),
        content: const Text(
          'Ringkasan dan titik GPS sesi ini akan dihapus dari perangkat. '
          'Salinan yang pernah disinkronkan ke cloud tidak ikut terhapus.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Hapus dari perangkat'),
          ),
        ],
      ),
    );
    if (approved == true && context.mounted) {
      await context.read<RideSessionCubit>().deleteCompletedSession(session.id);
    }
  }

  Future<void> _exportAllSessions(
    BuildContext context,
    List<RideSessionSnapshot> sessions,
  ) async {
    final approved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => SenapathAlertDialog(
        title: const Text('Ekspor semua sesi?'),
        content: const Text(
          'File JSON akan memuat ringkasan dan jejak lokasi GPS semua sesi '
          'selesai di perangkat ini. Simpan dan bagikan file hanya kepada '
          'orang yang kamu percaya.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Lanjut ekspor'),
          ),
        ],
      ),
    );
    if (approved != true || !context.mounted) return;

    try {
      final repository = context.read<RideSessionCubit>().repository;
      final activities =
          <
            ({RideSessionSnapshot session, List<TelemetryLocation> locations})
          >[];
      for (final session in sessions) {
        activities.add((
          session: session,
          locations: await repository.loadTelemetryLocations(session.id),
        ));
      }
      final content = _fileExchange.fileService.toJsonArchive(
        activities: activities,
      );
      final saved = await _fileExchange.exportText(
        content: content,
        suggestedName: 'senapath-activities.json',
        extension: 'json',
        mimeType: 'application/json',
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            saved ? 'Ekspor aktivitas selesai.' : 'Ekspor dibatalkan.',
          ),
        ),
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Ekspor aktivitas gagal.')));
    }
  }

  Widget _buildSummaryDetail(
    BuildContext context,
    RideSessionSummary summary,
    List<TelemetryLocation> locations,
    UnitSystem unitSystem,
  ) {
    final metric = unitSystem == UnitSystem.metric;
    final session = summary.session;
    final distanceLabel = _formatDistance(session.distanceMeters, metric);
    final duration = session.durationAt(session.endedAt ?? session.startedAt);
    final elevationLabel = summary.elevationGainMeters == null
        ? 'Tidak tersedia'
        : '${summary.elevationGainMeters!.toStringAsFixed(0)} m';
    final speedUnit = metric ? 'km/j' : 'mph';
    final speedFactor = metric ? 3.6 : 2.236936;
    final graphSpeeds = summary.speedSamples
        .map((sample) => sample.speedMetersPerSecond * speedFactor)
        .toList(growable: false);
    final averageSpeed = duration.inSeconds > 0
        ? session.distanceMeters / duration.inSeconds * speedFactor
        : 0.0;
    final maxSpeed = summary.speedSamples.isEmpty
        ? 0.0
        : summary.speedSamples
                  .map((sample) => sample.speedMetersPerSecond)
                  .reduce((first, next) => math.max(first, next).toDouble()) *
              speedFactor;
    final trackPoints = locations
        .where(
          (point) =>
              point.accuracyMeters <= 50 &&
              point.latitude.isFinite &&
              point.longitude.isFinite &&
              point.latitude >= -90 &&
              point.latitude <= 90 &&
              point.longitude >= -180 &&
              point.longitude <= 180,
        )
        .map((point) => latlong.LatLng(point.latitude, point.longitude))
        .toList(growable: false);
    final elevationSamples = _elevationProfile(
      locations,
      source: summary.elevationSource,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    session.title.isEmpty ? 'Ringkasan sesi' : session.title,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_activityTypeLabel(session.activityType)} · '
                    '${_formatSessionDate(session.startedAt)}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Ubah nama dan jenis aktivitas',
              onPressed: () => _editActivityMetadata(context, session),
              icon: const Icon(Icons.edit_outlined),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (trackPoints.isEmpty)
          Container(
            height: 180,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Padding(
              padding: EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.route_outlined, size: 30),
                  SizedBox(height: 8),
                  Text('Tidak ada jejak GPS untuk divisualisasikan.'),
                ],
              ),
            ),
          )
        else
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: ExploreMap(
              height: 260,
              borderRadius: 4,
              trackPoints: trackPoints,
              currentLocation: trackPoints.last,
              showLocationButton: false,
              showEmptyMessage: false,
            ),
          ),
        const SizedBox(height: 8),
        Text(
          trackPoints.length < 2
              ? 'Jejak peta tidak tersedia untuk sesi ini.'
              : '${trackPoints.length} titik GPS pada jejak sesi',
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 24),
        Text('Metrik utama', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        _SummaryMetricCard(
          children: [
            _MetricValue(
              label: 'Jarak',
              value: distanceLabel.split(' ').first,
              unit: distanceLabel.split(' ').last,
            ),
            _MetricValue(
              label: 'Durasi',
              value: _formatDuration(duration),
              unit: '',
            ),
            _MetricValue(
              label: 'Elevasi naik',
              value: elevationLabel.replaceAll(' m', ''),
              unit: elevationLabel.endsWith(' m') ? 'm' : '',
            ),
            _MetricValue(
              label: 'Sampel GPS',
              value: '${summary.sampleCount}',
              unit: '',
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Sumber elevasi: ${summary.elevationSource}. '
          'Nilai kosong berarti data sensor yang akurat belum tersedia.',
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 20),
        Text('Kecepatan', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        _SummaryMetricCard(
          children: [
            _MetricValue(
              label: 'Rata-rata',
              value: averageSpeed.toStringAsFixed(1),
              unit: speedUnit,
            ),
            _MetricValue(
              label: 'Maksimum tercatat',
              value: maxSpeed.toStringAsFixed(1),
              unit: speedUnit,
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          'Grafik kecepatan ($speedUnit)',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        if (summary.hasSpeedGraph)
          _SpeedGraph(values: graphSpeeds)
        else
          const Text('Belum cukup sampel untuk menampilkan grafik kecepatan.'),
        const SizedBox(height: 20),
        Text('Profil elevasi', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(
          elevationSamples.length >= 2
              ? 'Perubahan relatif dari ${summary.elevationSource.toLowerCase()}'
              : 'Data elevasi belum cukup untuk membuat grafik.',
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
        if (elevationSamples.length >= 2) ...[
          const SizedBox(height: 8),
          _SpeedGraph(values: elevationSamples),
        ],
        const SizedBox(height: 20),
        Text(
          'Sensor & kualitas data',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Text(
          'Akselerometer: ${summary.accelerometerSampleCount} dari '
          '${summary.sampleCount} sampel · Gyroscope: '
          '${summary.gyroscopeSampleCount} dari ${summary.sampleCount} sampel. '
          'Data gerak tidak ditafsirkan sebagai cadence atau lean angle.',
          style: Theme.of(context).textTheme.bodyMedium
              ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 20),
        _buildSummarySync(context, summary),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: () => context.push('/leaderboard', extra: summary),
          icon: const Icon(Icons.leaderboard_outlined),
          label: const Text('Papan peringkat'),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: () => _exportSession(context, summary, asGpx: false),
              icon: const Icon(Icons.data_object),
              label: const Text('Ekspor JSON'),
            ),
            OutlinedButton.icon(
              onPressed: () => _exportSession(context, summary, asGpx: true),
              icon: const Icon(Icons.route),
              label: const Text('Ekspor GPX'),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _editActivityMetadata(
    BuildContext context,
    RideSessionSnapshot session,
  ) async {
    final titleController = TextEditingController(text: session.title);
    var activityType = session.activityType;
    final result = await showDialog<(String, RideActivityType)>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => SenapathAlertDialog(
          title: const Text('Detail aktivitas'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                maxLength: 60,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Nama aktivitas',
                  hintText: 'Contoh: Gowes pagi',
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<RideActivityType>(
                initialValue: activityType,
                decoration: const InputDecoration(labelText: 'Jenis'),
                items: [
                  for (final type in RideActivityType.values)
                    DropdownMenuItem(
                      value: type,
                      child: Text(_activityTypeLabel(type)),
                    ),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => activityType = value);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, (
                titleController.text,
                activityType,
              )),
              child: const Text('Simpan'),
            ),
          ],
        ),
      ),
    );
    titleController.dispose();
    if (result == null || !context.mounted) return;
    await context.read<RideSessionCubit>().updateActivityMetadata(
      sessionId: session.id,
      title: result.$1,
      activityType: result.$2,
    );
  }

  List<double> _elevationProfile(
    List<TelemetryLocation> locations, {
    required String source,
  }) {
    if (source == 'Barometer') {
      final barometerReadings = locations
          .where((location) {
            final pressure = location.barometricPressureHpa;
            return pressure != null &&
                pressure.isFinite &&
                pressure >= 300 &&
                pressure <= 1100;
          })
          .toList(growable: false);
      if (barometerReadings.length < 2) return const [];
      final referencePressure = barometerReadings.first.barometricPressureHpa!;
      return barometerReadings
          .map(
            (location) =>
                (44330 *
                        (1 -
                            math.pow(
                              location.barometricPressureHpa! /
                                  referencePressure,
                              0.1903,
                            )))
                    .toDouble(),
          )
          .toList(growable: false);
    }

    if (source != 'Estimasi GPS') return const [];
    return locations
        .where(
          (location) =>
              location.altitudeMeters.isFinite &&
              location.altitudeAccuracyMeters != null &&
              location.altitudeAccuracyMeters! > 0 &&
              location.altitudeAccuracyMeters! <= 25,
        )
        .map((location) => location.altitudeMeters)
        .toList(growable: false);
  }

  Widget _buildSummarySync(BuildContext context, RideSessionSummary summary) {
    final session = summary.session;
    final cubit = context.read<RideSessionCubit>();
    final isSyncing = context.select<RideSessionCubit, bool>(
      (value) => value.state.syncingSessionId == session.id,
    );

    if (session.syncStatus == 'synced') {
      return const ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(Icons.cloud_done_outlined),
        title: Text('Ringkasan tersinkron'),
        subtitle: Text('Tidak termasuk koordinat GPS atau titik telemetri.'),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          !cubit.canSyncSessions
              ? 'Masuk ke akun online untuk menyinkronkan ringkasan. Data tetap lokal.'
              : session.syncStatus == 'failed'
              ? 'Sinkronisasi terakhir gagal. Ringkasan masih tersimpan lokal.'
              : 'Ringkasan belum disinkronkan. Tidak ada koordinat atau titik GPS yang akan dikirim.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: !cubit.canSyncSessions || isSyncing
              ? null
              : () => _confirmSummarySync(context, summary),
          icon: isSyncing
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.cloud_upload_outlined),
          label: Text(isSyncing ? 'Menyinkronkan…' : 'Sinkronkan ringkasan'),
        ),
      ],
    );
  }

  Future<void> _confirmSummarySync(
    BuildContext context,
    RideSessionSummary summary,
  ) async {
    final session = summary.session;
    final approved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => SenapathAlertDialog(
        title: const Text('Sinkronkan ringkasan sesi?'),
        content: Text(
          'Data yang dikirim ke akun Supabase milikmu: waktu mulai/selesai, '
          'durasi, jarak, jumlah sampel, sumber/elevasi, dan jumlah sampel '
          'sensor. Koordinat GPS, rute, dan telemetri mentah tidak dikirim. '
          'Sesi ${session.id} dapat diperbarui secara idempoten dan akan '
          'terhapus saat akun Supabase dihapus.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Setujui & sinkronkan'),
          ),
        ],
      ),
    );
    if (approved == true && context.mounted) {
      await context.read<RideSessionCubit>().syncSummary(
        session.id,
        consented: true,
      );
    }
  }

  String _syncStatusLabel(String status) => switch (status) {
    'synced' => 'Tersinkron ke Supabase',
    'syncing' => 'Sedang disinkronkan',
    'failed' => 'Lokal · Sinkronisasi gagal',
    _ => 'Tersimpan lokal · Belum disinkronkan',
  };

  String _activityTypeLabel(RideActivityType type) => switch (type) {
    RideActivityType.ride => 'Bersepeda',
    RideActivityType.commute => 'Komuter',
    RideActivityType.training => 'Latihan',
    RideActivityType.race => 'Balapan',
  };

  Future<void> _exportSession(
    BuildContext context,
    RideSessionSummary summary, {
    required bool asGpx,
  }) async {
    try {
      final sessionCubit = context.read<RideSessionCubit>();
      final locations = await sessionCubit.repository.loadTelemetryLocations(
        summary.session.id,
      );
      final content = asGpx
          ? _fileExchange.fileService.toGpx(locations)
          : _fileExchange.fileService.toJson(
              session: summary.session,
              locations: locations,
            );
      final saved = await _fileExchange.exportText(
        content: content,
        suggestedName: asGpx ? 'senapath-session.gpx' : 'senapath-session.json',
        extension: asGpx ? 'gpx' : 'json',
        mimeType: asGpx ? 'application/gpx+xml' : 'application/json',
      );
      if (!context.mounted || !saved) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Berkas ${asGpx ? 'GPX' : 'JSON'} berhasil disimpan.'),
        ),
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ekspor gagal atau dibatalkan.')),
      );
    }
  }

  String _formatDistance(double meters, bool metric) => metric
      ? '${(meters / 1000).toStringAsFixed(2)} km'
      : '${(meters / 1609.344).toStringAsFixed(2)} mi';

  String _formatSpeed(double metersPerSecond, UnitSystem unitSystem) {
    final metric = unitSystem == UnitSystem.metric;
    final speed = metersPerSecond * (metric ? 3.6 : 2.236936);
    return '${speed.toStringAsFixed(1)} ${metric ? 'km/j' : 'mph'}';
  }

  String _formatSessionDate(DateTime date) {
    final local = date.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$day/$month/${local.year} · $hour:$minute';
  }

  Future<void> _confirmFinish(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => SenapathAlertDialog(
        title: const Text('Akhiri sesi?'),
        content: const Text('Data sesi akan disimpan di perangkat.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Lanjut merekam'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Akhiri'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await context.read<RideSessionCubit>().finish();
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int value) => value.toString().padLeft(2, '0');
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    return hours > 0
        ? '${twoDigits(hours)}:${twoDigits(minutes)}:${twoDigits(seconds)}'
        : '${twoDigits(duration.inMinutes)}:${twoDigits(seconds)}';
  }
}

class _ReadinessLine extends StatelessWidget {
  const _ReadinessLine({
    required this.label,
    required this.isReady,
    this.isWarning = false,
  });

  final String label;
  final bool isReady;
  final bool isWarning;

  @override
  Widget build(BuildContext context) {
    final color = isReady
        ? Theme.of(context).colorScheme.primary
        : isWarning
        ? Theme.of(context).colorScheme.tertiary
        : Theme.of(context).colorScheme.error;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Icon(
            isReady ? Icons.check_circle_outline : Icons.info_outline,
            size: 20,
            color: color,
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(label)),
        ],
      ),
    );
  }
}

class _ReadinessPill extends StatelessWidget {
  const _ReadinessPill({required this.label, required this.isReady});

  final String label;
  final bool isReady;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: isReady ? colors.secondaryContainer : colors.surfaceContainer,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(
            isReady ? Icons.check_circle : Icons.location_searching,
            size: 17,
            color: isReady ? colors.primary : colors.onSurfaceVariant,
          ),
          const SizedBox(width: 7),
          Text(
            '$label · ${isReady ? 'siap' : 'perlu dicek'}',
            style: Theme.of(context).textTheme.labelMedium
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _CompactMetric extends StatelessWidget {
  const _CompactMetric({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: colors.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icon, color: colors.primary, size: 19),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelSmall
                      ?.copyWith(color: colors.onSurfaceVariant),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricValue extends StatelessWidget {
  const _MetricValue({
    required this.label,
    required this.value,
    required this.unit,
  });

  final String label;
  final String value;
  final String unit;

  @override
  Widget build(BuildContext context) {
    return SenapathMetric(label: label, value: value, unit: unit);
  }
}

class _SummaryMetricCard extends StatelessWidget {
  const _SummaryMetricCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SenapathCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            for (var index = 0; index < children.length; index += 2) ...[
              if (index > 0) const SizedBox(height: 18),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: children[index]),
                  if (index + 1 < children.length) ...[
                    const SizedBox(width: 12),
                    Expanded(child: children[index + 1]),
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SpeedGraph extends StatelessWidget {
  const _SpeedGraph({required this.values});

  final List<double> values;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 160,
      width: double.infinity,
      child: Semantics(
        label: 'Grafik garis sesi',
        child: CustomPaint(
          painter: _SpeedGraphPainter(
            values: values,
            lineColor: Theme.of(context).colorScheme.onSurface,
            gridColor: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
      ),
    );
  }
}

class _SpeedGraphPainter extends CustomPainter {
  const _SpeedGraphPainter({
    required this.values,
    required this.lineColor,
    required this.gridColor,
  });

  final List<double> values;
  final Color lineColor;
  final Color gridColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2 || size.isEmpty) return;
    final bounds = Rect.fromLTWH(0, 0, size.width, size.height);
    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    for (var row = 1; row < 4; row++) {
      final y = size.height * row / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final minValue = values.reduce(
      (first, next) => first < next ? first : next,
    );
    final maxValue = values.reduce(
      (first, next) => first > next ? first : next,
    );
    final range = math.max(1, maxValue - minValue).toDouble();
    final path = Path();
    for (var index = 0; index < values.length; index++) {
      final x = size.width * index / (values.length - 1);
      final y =
          size.height - ((values[index] - minValue) / range) * size.height;
      if (index == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    canvas.save();
    canvas.clipRect(bounds);
    canvas.drawPath(
      path,
      Paint()
        ..color = lineColor
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _SpeedGraphPainter oldDelegate) =>
      oldDelegate.values != values ||
      oldDelegate.lineColor != lineColor ||
      oldDelegate.gridColor != gridColor;
}
