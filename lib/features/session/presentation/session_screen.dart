import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/units/unit_settings_cubit.dart';
import '../../../core/units/unit_system.dart';
import '../data/readiness_checker.dart';
import '../domain/ride_session.dart';
import 'session_cubit.dart';

class SessionScreen extends StatefulWidget {
  const SessionScreen({super.key});

  @override
  State<SessionScreen> createState() => _SessionScreenState();
}

class _SessionScreenState extends State<SessionScreen> {
  bool _initialized = false;

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
              const SizedBox(height: 18),
              const Text(
                'Sesi disimpan di perangkat. Sinkronisasi cloud menunggu '
                'konfigurasi Supabase.',
                textAlign: TextAlign.center,
              ),
            ],
          );
        },
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
      return SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: state.canStart
              ? () => context.read<RideSessionCubit>().start()
              : null,
          icon: const Icon(Icons.add),
          label: const Text('Mulai sesi baru'),
        ),
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
