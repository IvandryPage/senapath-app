import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/units/unit_settings_cubit.dart';
import '../../../core/units/unit_system.dart';
import '../../routes/data/route_file_exchange.dart';
import '../../emergency/presentation/emergency_cubit.dart';
import '../../profile/domain/user_profile.dart';
import '../../profile/presentation/profile_cubit.dart';
import '../data/readiness_checker.dart';
import '../data/session_file_service.dart';
import '../domain/ride_session.dart';
import 'session_cubit.dart';

class SessionScreen extends StatefulWidget {
  const SessionScreen({super.key});

  @override
  State<SessionScreen> createState() => _SessionScreenState();
}

class _SessionScreenState extends State<SessionScreen> {
  bool _initialized = false;
  static const _fileExchange = RouteFileExchange(SessionFileService());

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    unawaited(context.read<RideSessionCubit>().initialize());
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
          final emergencyState = context.watch<EmergencyCubit>().state;
          final emergencyContacts = context
              .watch<ProfileCubit>()
              .state
              .contacts;

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
            children: [
              _buildSessionStatus(context, session),
              if (session != null) ...[
                const SizedBox(height: 24),
                _buildMetrics(context, session, state.elapsed, unitSystem),
                const SizedBox(height: 16),
                _buildSessionControls(context, state),
              ] else ...[
                const SizedBox(height: 24),
                _buildReadiness(context, readiness, state),
                const SizedBox(height: 20),
                _buildStartControl(context, state),
              ],
              if (state.completedSessions.isNotEmpty) ...[
                const SizedBox(height: 28),
                _buildHistory(context, state.completedSessions, unitSystem),
              ],
              if (state.isLoadingSummary) ...[
                const SizedBox(height: 20),
                const LinearProgressIndicator(),
              ],
              if (state.summary case final summary?) ...[
                const SizedBox(height: 24),
                _buildSummary(context, summary, unitSystem),
              ],
              const SizedBox(height: 24),
              _buildEmergencyPanel(context, emergencyContacts, emergencyState),
              const SizedBox(height: 18),
              const Text(
                'Sesi dan titik lokasi tetap tersimpan terenkripsi di perangkat. '
                'Hanya ringkasan yang dikirim setelah kamu menyetujuinya.',
                textAlign: TextAlign.center,
              ),
            ],
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
    return Card(
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
                session == null
                    ? 'Periksa perangkat sebelum merekam.'
                    : 'Data sesi tersimpan lokal.',
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
                : () => context
                      .read<RideSessionCubit>()
                      .checkReadiness(requestNotificationPermission: true),
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
              : () => context.read<RideSessionCubit>().checkReadiness(),
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
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: state.canStart
            ? () => context.read<RideSessionCubit>().start()
            : null,
        icon: const Icon(Icons.play_arrow),
        label: const Text('Mulai sesi'),
      ),
    );
  }

  Widget _buildSessionControls(BuildContext context, RideSessionState state) {
    final session = state.session!;
    if (session.status == RideSessionStatus.completed) {
      return Column(
        children: [
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: state.canStart
                  ? () => context.read<RideSessionCubit>().start()
                  : null,
              icon: const Icon(Icons.add),
              label: const Text('Mulai sesi baru'),
            ),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: () =>
                context.read<RideSessionCubit>().loadSummary(session.id),
            icon: const Icon(Icons.summarize_outlined),
            label: const Text('Lihat ringkasan'),
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
                  ? () => context.read<RideSessionCubit>().resume()
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
        for (final session in sessions.take(10))
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.route_outlined),
            title: Text(_formatSessionDate(session.startedAt)),
            subtitle: Text(
              '${_formatDistance(session.distanceMeters, metric)} · '
              '${_formatDuration(session.durationAt(session.endedAt ?? session.startedAt))} · '
              '${_syncStatusLabel(session.syncStatus)}',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () =>
                context.read<RideSessionCubit>().loadSummary(session.id),
          ),
      ],
    );
  }

  Widget _buildSummary(
    BuildContext context,
    RideSessionSummary summary,
    UnitSystem unitSystem,
  ) {
    final metric = unitSystem == UnitSystem.metric;
    final session = summary.session;
    final distanceLabel = _formatDistance(session.distanceMeters, metric);
    final elevationLabel = summary.elevationGainMeters == null
        ? 'Tidak tersedia'
        : '${summary.elevationGainMeters!.toStringAsFixed(0)} m';
    final speedUnit = metric ? 'km/j' : 'mph';
    final graphSpeeds = summary.speedSamples
        .map(
          (sample) => metric
              ? sample.speedMetersPerSecond * 3.6
              : sample.speedMetersPerSecond * 2.236936,
        )
        .toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Ringkasan sesi',
                style: Theme.of(context).textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            IconButton(
              tooltip: 'Tutup ringkasan',
              onPressed: () => context.read<RideSessionCubit>().closeSummary(),
              icon: const Icon(Icons.close),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _MetricValue(
                label: 'Jarak',
                value: distanceLabel.split(' ').first,
                unit: distanceLabel.split(' ').last,
              ),
            ),
            Expanded(
              child: _MetricValue(
                label: 'Durasi',
                value: _formatDuration(
                  session.durationAt(session.endedAt ?? session.startedAt),
                ),
                unit: '',
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _MetricValue(
                label: 'Akumulasi elevasi',
                value: elevationLabel,
                unit: '',
              ),
            ),
            Expanded(
              child: _MetricValue(
                label: 'Sampel tersimpan',
                value: '${summary.sampleCount}',
                unit: '',
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'Sumber elevasi: ${summary.elevationSource}. '
          'Data barometer/GPS yang tidak cukup atau tidak akurat ditandai '
          'sebagai tidak tersedia.',
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 18),
        Text(
          'Sampel gerak/orientasi: akselerometer '
          '${summary.accelerometerSampleCount}/${summary.sampleCount}, '
          'gyroscope ${summary.gyroscopeSampleCount}/${summary.sampleCount}. '
          'Data ini tidak ditafsirkan sebagai cadence atau lean angle.',
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 18),
        Text(
          'Grafik kecepatan ($speedUnit)',
          style: Theme.of(context).textTheme.titleSmall
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        if (summary.hasSpeedGraph)
          _SpeedGraph(values: graphSpeeds)
        else
          const Text('Belum cukup sampel untuk menampilkan grafik kecepatan.'),
        const SizedBox(height: 16),
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
      builder: (dialogContext) => AlertDialog(
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
      builder: (context) => AlertDialog(
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 4),
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 5,
          children: [
            Text(
              value,
              style: Theme.of(context).textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            if (unit.isNotEmpty)
              Text(unit, style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      ],
    );
  }
}

class _SpeedGraph extends StatelessWidget {
  const _SpeedGraph({required this.values});

  final List<double> values;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 150,
      width: double.infinity,
      child: CustomPaint(
        painter: _SpeedGraphPainter(
          values: values,
          lineColor: Theme.of(context).colorScheme.primary,
          gridColor: Theme.of(context).colorScheme.outlineVariant,
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

    final maxSpeed = math.max(1, values.reduce(math.max));
    final path = Path();
    for (var index = 0; index < values.length; index++) {
      final x = size.width * index / (values.length - 1);
      final y =
          size.height -
          (values[index].clamp(0, maxSpeed) / maxSpeed) * size.height;
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
