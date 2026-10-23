import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/widgets/press_scale.dart';

import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart' as latlong;

import '../../../core/units/unit_settings_cubit.dart';
import '../../../core/units/unit_system.dart';
import '../../../core/validation/input_formatters.dart';
import '../../../core/validation/validators.dart';
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
import '../../ride_coach/presentation/ride_coach_session_panel.dart';
import 'session_cubit.dart';

class SessionScreen extends StatefulWidget {
  /// Membuat layar sesi dengan opsi tampilan yang dapat diatur.
  const SessionScreen({
    this.showMap = true,
    this.showHistory = true,
    this.showSummary = true,
    this.historyOnly = false,
    this.summarySessionId,
    this.panelHeightFactor = 0.7,
    this.compactControls = false,
    this.hideReadinessDetails = false,
    super.key,
  });

  final bool showMap;
  final bool showHistory;
  final bool showSummary;
  final bool historyOnly;
  final String? summarySessionId;
  final double panelHeightFactor;
  final bool compactControls;
  final bool hideReadinessDetails;

  /// Membuat state layar sesi.
  @override
  State<SessionScreen> createState() => _SessionScreenState();
}

class _SessionScreenState extends State<SessionScreen>
    with WidgetsBindingObserver {
  bool _initialized = false;
  String? _loadedSummarySessionId;
  static const _fileExchange = RouteFileExchange(SessionFileService());

  /// Mendaftarkan observer siklus hidup aplikasi.
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  /// Menginisialisasi cubit dan memuat ringkasan sesi bila diminta.
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

  /// Memeriksa ulang kesiapan saat aplikasi kembali aktif tanpa sesi.
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

  /// Melepas observer siklus hidup aplikasi.
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Menyusun pesan snackbar serta tampilan peta, kontrol, metrik, riwayat,
  /// dan ringkasan sesi sesuai mode layar.
  @override
  Widget build(BuildContext context) {
    return BlocListener<RideSessionCubit, RideSessionState>(
      listenWhen: (previous, current) =>
          previous.message != current.message && current.message != null,
      listener: (context, state) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              backgroundColor: state.messageIsSuccess
                  ? const Color(0xFF16834A)
                  : null,
              content: Row(
                children: [
                  if (state.messageIsSuccess) ...[
                    const Icon(Icons.check_circle, color: Colors.white),
                    const SizedBox(width: 10),
                  ],
                  Expanded(child: Text(state.message!)),
                ],
              ),
            ),
          );
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
                      : const Text('Ringkasan perjalanan belum tersedia.'),
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
                    onDelete: () =>
                        _confirmDeleteSession(context, summary.session),
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
                      'Perjalanan yang selesai akan muncul di sini.',
                      textAlign: TextAlign.center,
                    ),
                  )
                else ...[
                  OutlinedButton.icon(
                    onPressed: () =>
                        _exportAllSessions(context, state.completedSessions),
                    icon: const Icon(Icons.download_outlined),
                    label: const Text('Ekspor perjalanan dan rute GPS'),
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
                Align(
                  alignment: Alignment.bottomCenter,
                  child: SizedBox(
                    height:
                        constraints.maxHeight *
                        (widget.showMap
                            ? widget.panelHeightFactor.clamp(0.2, 1.0)
                            : 1.0),
                    child: Material(
                      color: Theme.of(context).colorScheme.surface
                          .withValues(alpha: 0.97),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(widget.showMap ? 4 : 0),
                        ),
                        side: BorderSide(
                          color: Theme.of(context).colorScheme.outline,
                          width: widget.showMap ? 2 : 0,
                        ),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                        children: [
                          if (widget.compactControls) ...[
                            _buildCompactControls(context, state, unitSystem),
                            if (session != null &&
                                session.status !=
                                    RideSessionStatus.completed) ...[
                              const SizedBox(height: 24),
                              _buildLivePerformance(
                                context,
                                state,
                                session,
                                unitSystem,
                              ),
                              const SizedBox(height: 16),
                              RideCoachSessionPanel(sessionState: state),
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
                                    'Izin dan kesiapan perangkat',
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
                              const SizedBox(height: 16),
                              RideCoachSessionPanel(sessionState: state),
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
                              state.recordedLocations.isEmpty
                                  ? null
                                  : state.recordedLocations.last,
                            ),
                            const SizedBox(height: 18),
                            const Text(
                              'Perjalanan dan titik lokasinya tetap tersimpan '
                              'dengan aman di ponsel. Hanya ringkasan yang '
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

  /// Membangun panel pesan darurat dengan hitung mundur dan kontak tujuan.
  Widget _buildEmergencyPanel(
    BuildContext context,
    List<EmergencyContact> contacts,
    EmergencyState emergencyState,
    TelemetryLocation? lastLocation,
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
                  'Pesan darurat',
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (contact == null)
              const Text(
                'Tambahkan kontak darurat di Profil sebelum memakai fitur ini.',
              )
            else if (isCountingDown) ...[
              Text(
                'WhatsApp akan dibuka untuk mengirim pesan ke ${contact.name} '
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
                  label: const Text('Batalkan'),
                ),
              ),
            ] else ...[
              Text('Kontak tujuan: ${contact.name} · ${contact.phone}'),
              const SizedBox(height: 4),
              Text(
                'Tombol darurat membuka WhatsApp dengan pesan dan lokasi terakhir. '
                'Kamu tetap harus menekan Kirim.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () =>
                      context.read<EmergencyCubit>().startCountdown(
                        contact: contact,
                        lastLocation: lastLocation,
                      ),
                  icon: const Icon(Icons.warning_amber),
                  label: const Text('Mulai hitung mundur'),
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

  /// Membangun kontrol ringkas status, durasi, metrik, dan tombol sesi.
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
      RideSessionStatus.paused => 'REKAMAN DIJEDA',
      RideSessionStatus.completed => 'PERJALANAN SELESAI',
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
                    ? 'Lokasi belum diperiksa'
                    : state.readiness?.gpsFixAvailable == true
                    ? 'Lokasi siap'
                    : 'Lokasi belum ditemukan',
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
              'Tekan “Mulai merekam” untuk memulai perjalanan. Aplikasi akan '
              'meminta izin lokasi saat diperlukan.',
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
              label: const Text('Mulai merekam'),
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
                        ? 'Lokasi GPS'
                        : 'Ketepatan ±${gpsAccuracy.toStringAsFixed(0)} m',
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
                    ? 'Izinkan dan periksa lokasi'
                    : 'Periksa lokasi sekarang',
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

  /// Membangun ringkasan performa langsung beserta grafik kecepatan.
  Widget _buildLivePerformance(
    BuildContext context,
    RideSessionState state,
    RideSessionSnapshot session,
    UnitSystem unitSystem,
  ) {
    final locations = state.recordedLocations;
    final performanceLocations = state.performanceLocations;
    final metric = unitSystem == UnitSystem.metric;
    final speedFactor = metric ? 3.6 : 2.236936;
    final speedUnit = metric ? 'km/j' : 'mph';
    final speeds = locations
        .map((location) => location.speedMetersPerSecond)
        .where((speed) => speed.isFinite && speed >= 0)
        .map((speed) => speed * speedFactor)
        .toList(growable: false);
    final chartSpeeds = performanceLocations
        .map((location) => location.speedMetersPerSecond)
        .where((speed) => speed.isFinite && speed >= 0)
        .map((speed) => speed * speedFactor)
        .toList(growable: false);
    final elapsed = state.elapsed;
    final averageSpeed = elapsed.inSeconds > 0
        ? session.distanceMeters / elapsed.inSeconds * speedFactor
        : 0.0;
    final maxSpeed = speeds.isEmpty
        ? 0.0
        : speeds.reduce((first, next) => math.max(first, next).toDouble());
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Ringkasan perjalanan',
                    style: Theme.of(context).textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                Text(
                  'Grafik diperbarui tiap 5 dtk',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _MetricValue(
                    label: 'Rata-rata',
                    value: averageSpeed.toStringAsFixed(1),
                    unit: speedUnit,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _MetricValue(
                    label: 'Maksimum',
                    value: maxSpeed.toStringAsFixed(1),
                    unit: speedUnit,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Kecepatan $speedUnit',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            if (chartSpeeds.length >= 5)
              _SpeedGraph(values: chartSpeeds)
            else
              Text(
                'Grafik akan muncul setelah lokasi terekam beberapa kali.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Membangun indikator status dan keterangan sesi saat ini.
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
                  RideSessionStatus.recording => 'Rekaman tersimpan di ponsel. Perekaman saat layar mati belum dipastikan berfungsi.',
                  RideSessionStatus.paused =>
                    'Rekaman tersimpan di ponsel dan menunggu dilanjutkan.',
                  RideSessionStatus.completed =>
                    'Perjalanan tersimpan di ponsel.',
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

  /// Membangun daftar pemeriksaan izin, sensor, layanan, dan lokasi.
  Widget _buildReadiness(
    BuildContext context,
    ReadinessReport? readiness,
    RideSessionState state,
  ) {
    if (readiness == null) {
      return const Center(child: Text('Status kesiapan belum tersedia.'));
    }

    final locationLabel = readiness.locationPermissionGranted
        ? 'Akses lokasi aktif'
        : readiness.locationPermanentlyDenied
        ? 'Akses lokasi diblokir di pengaturan'
        : 'Akses lokasi belum diizinkan';
    final gpsLabel = !readiness.locationServicesEnabled
        ? 'Lokasi perangkat mati'
        : !readiness.gpsFixChecked
        ? 'Lokasi belum diperiksa'
        : readiness.gpsFixAvailable
        ? 'Lokasi siap · ketepatan ±${readiness.gpsAccuracyMeters!.toStringAsFixed(0)} m'
        : 'Lokasi GPS belum ditemukan';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Periksa sebelum mulai',
          style: Theme.of(context).textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        _ReadinessLine(
          label: locationLabel,
          isReady: readiness.locationPermissionGranted,
        ),
        if (readiness.locationPermissionGranted) ...[
          _ReadinessLine(
            label: readiness.backgroundLocationGranted
                ? 'Akses lokasi tetap aktif saat aplikasi ditutup'
                : 'Perekaman saat layar terkunci memerlukan izin tambahan',
            isReady: readiness.backgroundLocationGranted,
            isWarning: !readiness.backgroundLocationGranted,
          ),
          if (!readiness.backgroundLocationGranted)
            Padding(
              padding: const EdgeInsets.only(left: 34, bottom: 8),
              child: TextButton.icon(
                onPressed: state.isCheckingReadiness
                    ? null
                    : () => context
                          .read<RideSessionCubit>()
                          .openLocationSettings(),
                icon: const Icon(Icons.settings_outlined),
                label: const Text('Periksa izin di pengaturan aplikasi'),
              ),
            ),
        ],
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
            label: const Text('Aktifkan lokasi perangkat'),
          ),
        ],
        if (readiness.locationPermissionGranted &&
            readiness.hasLimitedMetrics) ...[
          const SizedBox(height: 10),
          Text(
            'Sebagian metrik mungkin terbatas. Kamu tetap dapat mulai; '
            'Ketepatan bergantung pada sinyal lokasi dan sensor di ponsel.',
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: Theme.of(context).colorScheme.tertiary),
          ),
        ],
        if (readiness.locationPermissionGranted) ...[
          const SizedBox(height: 8),
          Text(
            'Rekaman layar terkunci bergantung pada izin latar belakang, '
            'pengaturan baterai, versi OS, dan kebijakan perangkat. '
            'Uji perangkat diperlukan untuk memastikan keandalannya.',
            style: Theme.of(context).textTheme.bodySmall,
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

  /// Membangun metrik jarak, durasi, kecepatan, dan sumber posisi.
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
                label: 'Kecepatan',
                value: speed.toStringAsFixed(1),
                unit: speedUnit,
              ),
            ),
            Expanded(
              child: _MetricValue(
                label: 'Sumber posisi',
                value: session.gpsAccuracyMeters == null
                    ? 'Lokasi belum tersedia'
                    : 'Ketepatan lokasi',
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

  /// Membangun tombol mulai perekaman dengan pemeriksaan kesiapan.
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
      label: 'Mulai merekam',
      animatePress: true,
    );
  }

  /// Membangun tombol pemilih latihan interval.
  Widget _buildWorkoutPicker(BuildContext context) {
    final workout = context.watch<IntervalWorkoutCubit>().state.selectedWorkout;
    return OutlinedButton.icon(
      onPressed: () => context.push('/routes/workouts'),
      icon: const Icon(Icons.timer_outlined),
      label: Text(
        workout == null
            ? 'Pilih latihan interval (opsional)'
            : 'Latihan: ${workout.name}',
      ),
    );
  }

  /// Membangun kartu progres interval latihan yang sedang aktif.
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
                    'Latihan · ${progress.index + 1}/${progress.total}',
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

  /// Membangun tombol jeda, lanjut, selesai, atau mulai ulang sesuai status.
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
            label: 'Mulai perjalanan baru',
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
            child: PressScale(
              enabled: state.canStart,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  overlayColor: Colors.transparent,
                  splashFactory: NoSplash.splashFactory,
                ),
                onPressed: state.canStart
                    ? () => context.read<RideSessionCubit>().resume(
                        route: context.read<RoutesCubit>().state.sessionRoute,
                      )
                    : null,
                icon: const Icon(Icons.play_arrow),
                label: const Text('Lanjutkan'),
              ),
            ),
          ),
          const SizedBox(width: 12),
          IconButton.filledTonal(
            tooltip: 'Selesaikan perjalanan',
            onPressed: () => context.read<RideSessionCubit>().finish(),
            icon: const Icon(Icons.stop),
          ),
        ],
      );
    }

    return Row(
      children: [
        Expanded(
          child: PressScale(
            child: FilledButton.tonalIcon(
              style: FilledButton.styleFrom(
                overlayColor: Colors.transparent,
                splashFactory: NoSplash.splashFactory,
              ),
              onPressed: () => context.read<RideSessionCubit>().pause(),
              icon: const Icon(Icons.pause),
              label: const Text('Jeda'),
            ),
          ),
        ),
        const SizedBox(width: 12),
        IconButton.filled(
          tooltip: 'Selesaikan perjalanan',
          onPressed: () => _confirmFinish(context),
          icon: const Icon(Icons.stop),
        ),
      ],
    );
  }

  /// Meminta izin lokasi lalu memulai perekaman bila perangkat siap.
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

  /// Membangun daftar riwayat perjalanan yang telah selesai.
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
          'Riwayat perjalanan',
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
                      'Hapus ${session.title.isEmpty ? 'perjalanan' : session.title}',
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

  /// Menampilkan konfirmasi lalu menghapus sesi terpilih.
  Future<void> _confirmDeleteSession(
    BuildContext context,
    RideSessionSnapshot session,
  ) async {
    final approved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => SenapathAlertDialog(
        title: const Text('Hapus perjalanan?'),
        content: const Text(
          'Ringkasan dan titik lokasi akan dihapus dari ponsel dan akun online. '
          'Jika salinan online tidak dapat dihapus, perjalanan ini tetap disimpan di ponsel.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Hapus perjalanan'),
          ),
        ],
      ),
    );
    if (approved == true && context.mounted) {
      final deleted = await context
          .read<RideSessionCubit>()
          .deleteCompletedSession(session.id);
      if (deleted && context.mounted && widget.summarySessionId != null) {
        context.pop();
      }
    }
  }

  /// Menampilkan konfirmasi dan mengekspor seluruh sesi ke berkas JSON.
  Future<void> _exportAllSessions(
    BuildContext context,
    List<RideSessionSnapshot> sessions,
  ) async {
    final approved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => SenapathAlertDialog(
        title: const Text('Ekspor semua perjalanan?'),
        content: const Text(
          'File akan berisi ringkasan dan titik lokasi semua perjalanan yang '
          'selesai di ponsel ini. Bagikan file hanya kepada orang yang kamu percaya.',
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
            saved
                ? 'Berkas aktivitas siap dibagikan atau disimpan.'
                : 'Ekspor dibatalkan.',
          ),
        ),
      );
    } on Exception {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('File perjalanan tidak dapat disimpan. Coba lagi.'),
        ),
      );
    }
  }

  /// Membangun detail ringkasan, peta, performa, dan opsi ekspor sesi.
  Widget _buildSummaryDetail(
    BuildContext context,
    RideSessionSummary summary,
    List<TelemetryLocation> locations,
    UnitSystem unitSystem, {
    VoidCallback? onDelete,
  }) {
    final metric = unitSystem == UnitSystem.metric;
    final session = summary.session;
    final distanceLabel = _formatDistance(session.distanceMeters, metric);
    final duration = session.durationAt(session.endedAt ?? session.startedAt);
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
    final accelerationSamples = locations
        .map((point) => point.accelerationMagnitudeMetersPerSecondSquared)
        .whereType<double>()
        .where((value) => value.isFinite)
        .toList(growable: false);
    final rotationSamples = locations
        .map((point) => point.rotationRateMagnitudeRadiansPerSecond)
        .whereType<double>()
        .where((value) => value.isFinite)
        .toList(growable: false);
    final averageAcceleration = accelerationSamples.isEmpty
        ? null
        : accelerationSamples.reduce((a, b) => a + b) /
              accelerationSamples.length;
    final peakAcceleration = accelerationSamples.isEmpty
        ? null
        : accelerationSamples.reduce((first, next) => math.max(first, next));
    final averageRotation = rotationSamples.isEmpty
        ? null
        : rotationSamples.reduce((a, b) => a + b) / rotationSamples.length;
    final peakRotation = rotationSamples.isEmpty
        ? null
        : rotationSamples.reduce((first, next) => math.max(first, next));

    final colors = Theme.of(context).colorScheme;
    final hasSensorData =
        summary.accelerometerSampleCount > 0 ||
        summary.gyroscopeSampleCount > 0;
    final elevationGain = summary.elevationGainMeters;
    final elevationLabel = elevationGain == null
        ? '—'
        : '${elevationGain.toStringAsFixed(0)} m';

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
                    session.title.isEmpty
                        ? 'Ringkasan perjalanan'
                        : session.title,
                    style: Theme.of(context).textTheme.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_activityTypeLabel(session.activityType)} · '
                    '${_formatSessionDate(session.startedAt)}',
                    style: Theme.of(context).textTheme.bodyMedium
                        ?.copyWith(color: colors.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (onDelete != null)
                  IconButton(
                    tooltip: 'Hapus perjalanan',
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete_outline),
                    color: Theme.of(context).colorScheme.error,
                  ),
                IconButton(
                  tooltip: 'Ubah nama dan jenis aktivitas',
                  onPressed: () => _editActivityMetadata(context, session),
                  icon: const Icon(Icons.edit_outlined),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),
        SenapathCard(
          margin: EdgeInsets.zero,
          color: SenapathColors.navy,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'JARAK TEMPUH',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: SenapathColors.accent,
                    letterSpacing: 1.1,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  distanceLabel,
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _HeroSessionMetric(
                        label: 'Durasi',
                        value: _formatDuration(duration),
                      ),
                    ),
                    Expanded(
                      child: _HeroSessionMetric(
                        label: 'Elevasi naik',
                        value: elevationLabel,
                      ),
                    ),
                    Expanded(
                      child: _HeroSessionMetric(
                        label: 'Rata-rata',
                        value: '${averageSpeed.toStringAsFixed(1)} $speedUnit',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        _SessionSectionHeading(
          title: 'Jejak rute',
          trailing: trackPoints.isEmpty
              ? null
              : '${trackPoints.length} titik lokasi',
        ),
        const SizedBox(height: 10),
        if (trackPoints.isEmpty)
          Container(
            height: 180,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: colors.surfaceContainerHighest,
              border: Border.all(color: colors.outlineVariant),
              borderRadius: BorderRadius.circular(SenapathShape.medium),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.route_outlined,
                    size: 30,
                    color: colors.onSurfaceVariant,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Rute perjalanan ini belum memiliki titik lokasi.',
                  ),
                ],
              ),
            ),
          )
        else
          ClipRRect(
            borderRadius: BorderRadius.circular(SenapathShape.medium),
            child: ExploreMap(
              height: 240,
              borderRadius: SenapathShape.medium,
              trackPoints: trackPoints,
              currentLocation: trackPoints.last,
              showLocationButton: false,
              showEmptyMessage: false,
            ),
          ),
        if (trackPoints.length == 1)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              'Peta perjalanan memerlukan setidaknya dua titik lokasi.',
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: colors.onSurfaceVariant),
            ),
          ),
        const SizedBox(height: 24),
        _SessionSectionHeading(title: 'Performa'),
        const SizedBox(height: 10),
        SenapathCard(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                  'Grafik kecepatan ($speedUnit)',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                if (summary.hasSpeedGraph) ...[
                  const SizedBox(height: 8),
                  _SpeedGraph(values: graphSpeeds),
                ] else
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'Belum cukup sampel untuk menampilkan grafik.',
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(color: colors.onSurfaceVariant),
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (elevationSamples.length >= 2) ...[
          const SizedBox(height: 16),
          SenapathCard(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Profil elevasi',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Sumber: ${summary.elevationSource.toLowerCase()}',
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: colors.onSurfaceVariant),
                  ),
                  const SizedBox(height: 8),
                  _SpeedGraph(values: elevationSamples),
                ],
              ),
            ),
          ),
        ],
        if (hasSensorData) ...[
          const SizedBox(height: 16),
          SenapathCard(
            margin: EdgeInsets.zero,
            child: ExpansionTile(
              tilePadding: const EdgeInsets.symmetric(horizontal: 16),
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              leading: const Icon(Icons.sensors_outlined),
              title: const Text('Data sensor gerak'),
              subtitle: Text(
                '${summary.accelerometerSampleCount} data gerak · '
                '${summary.gyroscopeSampleCount} data putaran',
              ),
              children: [
                Column(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _MetricValue(
                            label: 'Akselerasi rata-rata',
                            value:
                                averageAcceleration?.toStringAsFixed(1) ?? '—',
                            unit: averageAcceleration == null ? '' : 'm/s²',
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _MetricValue(
                            label: 'Akselerasi puncak',
                            value: peakAcceleration?.toStringAsFixed(1) ?? '—',
                            unit: peakAcceleration == null ? '' : 'm/s²',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _MetricValue(
                            label: 'Rotasi rata-rata',
                            value: averageRotation?.toStringAsFixed(2) ?? '—',
                            unit: averageRotation == null ? '' : 'rad/s',
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _MetricValue(
                            label: 'Rotasi puncak',
                            value: peakRotation?.toStringAsFixed(2) ?? '—',
                            unit: peakRotation == null ? '' : 'rad/s',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  'Data sensor disimpan bersama titik lokasi. Angka ini hanya '
                  'perkiraan gerakan ponsel, bukan ukuran tenaga atau kemiringan sepeda.',
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: colors.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 24),
        _SessionSectionHeading(title: 'Penyimpanan online'),
        const SizedBox(height: 8),
        SenapathCard(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(children: [_buildSummarySync(context, summary)]),
          ),
        ),
        const SizedBox(height: 24),
        _SessionSectionHeading(title: 'Simpan atau bagikan data'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: () => _exportSession(context, summary, asGpx: true),
              icon: const Icon(Icons.route_outlined),
              label: const Text('Simpan rute (GPX)'),
            ),
            TextButton.icon(
              onPressed: () => _exportSession(context, summary, asGpx: false),
              icon: const Icon(Icons.data_object),
              label: const Text('Simpan data (JSON)'),
            ),
          ],
        ),
      ],
    );
  }

  /// Menampilkan dialog untuk mengubah nama dan jenis aktivitas.
  Future<void> _editActivityMetadata(
    BuildContext context,
    RideSessionSnapshot session,
  ) async {
    final result = await showDialog<(String, RideActivityType)>(
      context: context,
      builder: (_) => _ActivityMetadataDialog(
        initialName: session.title,
        initialType: session.activityType,
      ),
    );
    if (result == null || !context.mounted) return;
    await context.read<RideSessionCubit>().updateActivityMetadata(
      sessionId: session.id,
      title: result.$1,
      activityType: result.$2,
    );
  }

  /// Menyusun sampel elevasi sesuai sumber barometer atau GPS.
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

  /// Membangun status dan keterangan penyimpanan online sesi.
  Widget _buildSummarySync(BuildContext context, RideSessionSummary summary) {
    final session = summary.session;
    final isSyncing = context.select<RideSessionCubit, bool>(
      (cubit) => cubit.state.syncingSessionId == session.id,
    );
    final autoSyncEnabled = context.select<RideSessionCubit, bool>(
      (cubit) => cubit.state.autoSyncEnabled,
    );

    if (session.syncStatus == 'synced') {
      return const ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(Icons.cloud_done_outlined),
        title: Text('Perjalanan disimpan online'),
        subtitle: Text('Track GPS dan data sensor mentah ikut tersimpan.'),
      );
    }

    final cubit = context.read<RideSessionCubit>();
    final message = !autoSyncEnabled
        ? 'Aktifkan “Simpan perjalanan online otomatis” di Profil > Pengaturan. '
              'Track GPS dan sensor mentah tetap tersimpan di ponsel.'
        : !cubit.canSyncSessions
        ? 'Akun online belum terhubung. Perjalanan tetap tersimpan di ponsel dan '
              'akan dicoba lagi otomatis.'
        : isSyncing || session.syncStatus == 'syncing'
        ? 'Perjalanan, track GPS, dan sensor mentah sedang disimpan ke akun online.'
        : session.syncStatus == 'failed'
        ? 'Perjalanan belum tersimpan online. Data tetap aman di ponsel dan akan '
              'dicoba lagi otomatis.'
        : 'Menunggu untuk disimpan online. Track GPS dan sensor mentah ikut dikirim.';

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: isSyncing || session.syncStatus == 'syncing'
          ? const SizedBox.square(
              dimension: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.cloud_upload_outlined),
      title: Text(
        isSyncing || session.syncStatus == 'syncing'
            ? 'Menyimpan online…'
            : session.syncStatus == 'failed'
            ? 'Belum tersimpan online'
            : 'Tersimpan di ponsel',
      ),
      subtitle: Text(message),
    );
  }

  /// Mengubah kode status sinkronisasi menjadi label berbahasa Indonesia.
  String _syncStatusLabel(String status) => switch (status) {
    'synced' => 'Disimpan online',
    'syncing' => 'Sedang disimpan online',
    'failed' => 'Tersimpan di ponsel · Belum online',
    _ => 'Tersimpan di ponsel · Belum online',
  };

  /// Mengubah jenis aktivitas menjadi label yang ditampilkan.
  String _activityTypeLabel(RideActivityType type) =>
      _activityTypeLabelForDialog(type);

  /// Mengekspor sesi ke berkas GPX atau JSON lalu memberi notifikasi.
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
      if (asGpx && locations.isEmpty) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Rute GPX belum tersedia karena perjalanan ini tidak memiliki titik lokasi.',
            ),
          ),
        );
        return;
      }
      final content = asGpx
          ? _fileExchange.fileService.toGpx(
              locations,
              trackName: summary.session.title.trim().isEmpty
                  ? 'Senapath session'
                  : summary.session.title.trim(),
            )
          : _fileExchange.fileService.toJson(
              session: summary.session,
              locations: locations,
            );
      final saved = await _fileExchange.exportText(
        content: content,
        suggestedName: asGpx
            ? 'senapath-session-${summary.session.id}.gpx'
            : 'senapath-session-${summary.session.id}.json',
        extension: asGpx ? 'gpx' : 'json',
        mimeType: asGpx ? 'application/gpx+xml' : 'application/json',
      );
      if (!context.mounted) return;
      if (!saved) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('File ${asGpx ? 'GPX' : 'JSON'} berhasil disimpan.'),
        ),
      );
    } on Exception {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('File tidak dapat disimpan. Coba lagi.')),
      );
    }
  }

  /// Memformat jarak meter ke kilometer atau mil.
  String _formatDistance(double meters, bool metric) => metric
      ? '${(meters / 1000).toStringAsFixed(2)} km'
      : '${(meters / 1609.344).toStringAsFixed(2)} mi';

  /// Memformat kecepatan sesuai sistem satuan yang dipilih.
  String _formatSpeed(double metersPerSecond, UnitSystem unitSystem) {
    final metric = unitSystem == UnitSystem.metric;
    final speed = metersPerSecond * (metric ? 3.6 : 2.236936);
    return '${speed.toStringAsFixed(1)} ${metric ? 'km/j' : 'mph'}';
  }

  /// Memformat tanggal dan waktu sesi untuk tampilan.
  String _formatSessionDate(DateTime date) {
    final local = date.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$day/$month/${local.year} · $hour:$minute';
  }

  /// Menampilkan konfirmasi sebelum menyelesaikan perjalanan.
  Future<void> _confirmFinish(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => SenapathAlertDialog(
        title: const Text('Selesaikan perjalanan?'),
        content: const Text('Rekaman akan disimpan di ponsel.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Lanjut merekam'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Selesaikan'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await context.read<RideSessionCubit>().finish();
    }
  }

  /// Memformat durasi sebagai jam:menit:detik atau menit:detik.
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

class _ActivityMetadataDialog extends StatefulWidget {
  /// Membuat dialog pengubahan detail aktivitas.
  const _ActivityMetadataDialog({
    required this.initialName,
    required this.initialType,
  });

  final String initialName;
  final RideActivityType initialType;

  /// Membuat state dialog detail aktivitas.
  @override
  State<_ActivityMetadataDialog> createState() =>
      _ActivityMetadataDialogState();
}

class _ActivityMetadataDialogState extends State<_ActivityMetadataDialog> {
  late final TextEditingController _nameController;
  final _formKey = GlobalKey<FormState>();
  late RideActivityType _activityType;

  /// Menyiapkan pengendali nama dan jenis aktivitas awal.
  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName);
    _activityType = widget.initialType;
  }

  /// Membuang pengendali teks dialog.
  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  /// Membangun formulir nama dan jenis aktivitas.
  @override
  Widget build(BuildContext context) => AlertDialog(
    scrollable: true,
    title: const Text('Detail aktivitas'),
    content: Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextFormField(
            controller: _nameController,
            maxLength: InputLimits.sessionNameMaxLength,
            textCapitalization: TextCapitalization.sentences,
            inputFormatters: const [
              SingleLineInputFormatter(),
              ForbiddenCharactersInputFormatter(),
            ],
            decoration: const InputDecoration(
              labelText: 'Nama aktivitas',
              hintText: 'Contoh: Gowes pagi',
            ),
            validator: (value) => TextValidators.name(
              value,
              label: 'nama aktivitas',
              maxLength: InputLimits.sessionNameMaxLength,
              emptyMessage: 'Isi nama aktivitas.',
            ),
          ),
          const SizedBox(height: 12),
          InputDecorator(
            decoration: const InputDecoration(labelText: 'Jenis'),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<RideActivityType>(
                value: _activityType,
                isExpanded: true,
                isDense: true,
                items: [
                  for (final type in RideActivityType.values)
                    DropdownMenuItem(
                      value: type,
                      child: Text(_activityTypeLabelForDialog(type)),
                    ),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => _activityType = value);
                },
              ),
            ),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Batal'),
      ),
      FilledButton(
        onPressed: () {
          if (!_formKey.currentState!.validate()) return;
          Navigator.pop(context, (_nameController.text.trim(), _activityType));
        },
        child: const Text('Simpan'),
      ),
    ],
  );
}

/// Mengubah jenis aktivitas menjadi label untuk dialog.
String _activityTypeLabelForDialog(RideActivityType type) => switch (type) {
  RideActivityType.ride => 'Bersepeda',
  RideActivityType.commute => 'Komuter',
  RideActivityType.training => 'Latihan',
  RideActivityType.race => 'Balapan',
};

class _ReadinessLine extends StatelessWidget {
  /// Membuat baris status kesiapan.
  const _ReadinessLine({
    required this.label,
    required this.isReady,
    this.isWarning = false,
  });

  final String label;
  final bool isReady;
  final bool isWarning;

  /// Membangun baris ikon dan label status kesiapan.
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
  /// Membuat pil status kesiapan ringkas.
  const _ReadinessPill({required this.label, required this.isReady});

  final String label;
  final bool isReady;

  /// Membangun pil berlatar warna sesuai status kesiapan.
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
  /// Membuat metrik ringkas dengan ikon.
  const _CompactMetric({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  /// Membangun kartu metrik ringkas berisi ikon, label, dan nilai.
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
  /// Membuat nilai metrik dengan label dan satuan.
  const _MetricValue({
    required this.label,
    required this.value,
    required this.unit,
  });

  final String label;
  final String value;
  final String unit;

  /// Membangun nilai metrik menggunakan komponen Senapath.
  @override
  Widget build(BuildContext context) {
    return SenapathMetric(label: label, value: value, unit: unit);
  }
}

class _HeroSessionMetric extends StatelessWidget {
  /// Membuat metrik utama ringkasan sesi.
  const _HeroSessionMetric({required this.label, required this.value});

  final String label;
  final String value;

  /// Membangun metrik utama dengan label dan nilai berwarna terang.
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(right: 8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.labelSmall
              ?.copyWith(color: SenapathColors.accent),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    ),
  );
}

class _SessionSectionHeading extends StatelessWidget {
  /// Membuat judul bagian sesi.
  const _SessionSectionHeading({required this.title, this.trailing});

  final String title;
  final String? trailing;

  /// Membangun judul bagian dengan teks tambahan opsional.
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(
          title,
          style: Theme.of(context).textTheme.titleLarge
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
      ),
      if (trailing != null)
        Text(
          trailing!,
          style: Theme.of(context).textTheme.labelMedium
              ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
    ],
  );
}

class _SummaryMetricCard extends StatelessWidget {
  /// Membuat kartu berisi metrik ringkasan.
  const _SummaryMetricCard({required this.children});

  final List<Widget> children;

  /// Membangun kartu yang menata metrik dalam baris dua kolom.
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
  /// Membuat grafik garis dari nilai yang diberikan.
  const _SpeedGraph({required this.values});

  final List<double> values;

  /// Membangun area grafik garis dengan label aksesibilitas.
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
  /// Membuat pelukis grafik garis.
  const _SpeedGraphPainter({
    required this.values,
    required this.lineColor,
    required this.gridColor,
  });

  final List<double> values;
  final Color lineColor;
  final Color gridColor;

  /// Menggambar kisi dan garis grafik pada kanvas.
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

  /// Menentukan apakah grafik perlu digambar ulang.
  @override
  bool shouldRepaint(covariant _SpeedGraphPainter oldDelegate) =>
      oldDelegate.values != values ||
      oldDelegate.lineColor != lineColor ||
      oldDelegate.gridColor != gridColor;
}
