import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/senapath_design.dart';
import '../../../core/units/unit_settings_cubit.dart';
import '../../../core/units/unit_system.dart';
import '../data/route_wind_service.dart';
import '../domain/route_wind.dart';
import '../domain/saved_route.dart';
import 'route_guidance_cubit.dart';
import 'route_wind_indicator.dart';

/// Memformat jarak panduan sesuai sistem satuan metrik atau imperial.
String formatGuidanceDistance(double meters, UnitSystem unitSystem) {
  if (unitSystem == UnitSystem.metric) {
    return meters >= 1000
        ? '${(meters / 1000).toStringAsFixed(1)} km'
        : '${NumberFormat('0').format(meters)} m';
  }
  return meters >= 1609.344
      ? '${(meters / 1609.344).toStringAsFixed(1)} mi'
      : '${NumberFormat('0').format(meters * 3.28084)} ft';
}

class GuidanceStatusLine extends StatefulWidget {
  /// Membuat baris status panduan untuk [route] beserta layanan angin.
  const GuidanceStatusLine({
    required this.route,
    this.windService,
    this.ghostPacerError = false,
    super.key,
  });

  final RouteRecord route;
  final RouteWindService? windService;
  final bool ghostPacerError;

  /// Membuat state baris status panduan.
  @override
  State<GuidanceStatusLine> createState() => _GuidanceStatusLineState();
}

class _GuidanceStatusLineState extends State<GuidanceStatusLine> {
  late final RouteWindService _windService =
      widget.windService ?? OpenMeteoRouteWindService();
  RouteWindObservation? _wind;
  ({double latitude, double longitude})? _lastWindPosition;
  DateTime? _lastWindRequestAt;
  bool _windConsentGranted = false;
  bool _isLoadingWind = false;
  bool _hasWindError = false;

  /// Membangun label status, akurasi, indikator angin, dan peringatan rute.
  @override
  Widget build(BuildContext context) =>
      BlocListener<RouteGuidanceCubit, RouteGuidanceState>(
        listenWhen: (previous, current) =>
            previous.currentPosition != current.currentPosition,
        listener: (_, state) {
          if (_windConsentGranted &&
              state.currentPosition != null &&
              state.hasAccurateFix) {
            unawaited(_refreshWindIfNeeded(state));
          }
        },
        child: BlocBuilder<RouteGuidanceCubit, RouteGuidanceState>(
          builder: (context, state) {
            final colors = Theme.of(context).colorScheme;
            final textTheme = Theme.of(context).textTheme;
            final current = state.currentPosition;
            final routeHeading = widget.route.points.length < 2
                ? null
                : routeHeadingDegrees(
                    widget.route.points,
                    state.nearestRouteIndex,
                  );
            final warning = _warningLabel(state);
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.navigation_outlined,
                      size: 18,
                      color: SenapathColors.accent,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _statusLabel(state),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (current != null)
                      Text(
                        '±${current.accuracyMeters.toStringAsFixed(0)} m',
                        style: textTheme.labelMedium?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    RouteWindIndicator(
                      wind: _wind,
                      routeHeadingDegrees: routeHeading,
                      isLoading: _isLoadingWind,
                      hasError: _hasWindError,
                      isLocationReady: current != null && state.hasAccurateFix,
                      onPressed: current == null || !state.hasAccurateFix
                          ? null
                          : () => _requestWind(state),
                    ),
                  ],
                ),
                if (warning != null) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: colors.errorContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      warning,
                      style: textTheme.bodySmall?.copyWith(
                        color: colors.onErrorContainer,
                      ),
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      );

  /// Meminta izin pengguna lalu mengambil arah angin bila disetujui.
  Future<void> _requestWind(RouteGuidanceState state) async {
    if (_windConsentGranted) {
      await _fetchWind(state);
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => SenapathAlertDialog(
        title: const Text('Tampilkan arah angin?'),
        content: const Text(
          'Koordinat GPS saat ini akan dikirim ke Open-Meteo untuk mengambil '
          'arah angin lokal. Aplikasi hanya menampilkan panah relatif terhadap '
          'arah rute dan tidak menampilkan kecepatan angin.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Izinkan sekali untuk panduan ini'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    _windConsentGranted = true;
    await _fetchWind(state);
  }

  /// Memuat ulang angin bila posisi bergeser 5 km atau sudah 10 menit.
  Future<void> _refreshWindIfNeeded(RouteGuidanceState state) async {
    final position = state.currentPosition!;
    final currentCoordinates = (
      latitude: position.latitude,
      longitude: position.longitude,
    );
    final previousCoordinates = _lastWindPosition;
    final movedMeters = previousCoordinates == null
        ? double.infinity
        : Geolocator.distanceBetween(
            previousCoordinates.latitude,
            previousCoordinates.longitude,
            currentCoordinates.latitude,
            currentCoordinates.longitude,
          );
    final hasExpired =
        _lastWindRequestAt == null ||
        DateTime.now().difference(_lastWindRequestAt!) >=
            const Duration(minutes: 10);
    if (movedMeters >= 5000 || hasExpired) await _fetchWind(state);
  }

  /// Mengambil observasi angin dan memperbarui status muat atau galat.
  Future<void> _fetchWind(RouteGuidanceState state) async {
    final position = state.currentPosition;
    if (position == null || !state.hasAccurateFix || _isLoadingWind) return;
    setState(() {
      _isLoadingWind = true;
      _hasWindError = false;
    });
    _lastWindPosition = (
      latitude: position.latitude,
      longitude: position.longitude,
    );
    _lastWindRequestAt = DateTime.now();
    try {
      final observation = await _windService.fetchCurrentWind(
        latitude: position.latitude,
        longitude: position.longitude,
      );
      if (!mounted) return;
      setState(() {
        _wind = observation;
        _isLoadingWind = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoadingWind = false;
        _hasWindError = true;
      });
    }
  }

  /// Menentukan teks status panduan berdasarkan kondisi [state].
  String _statusLabel(RouteGuidanceState state) {
    if (state.error != null) return state.error!;
    if (state.hasReachedEnd) return 'Rute selesai';
    if (state.isStarting) return 'Mencari lokasi…';
    if (state.currentPosition == null) return 'Menunggu lokasi…';
    if (state.isOffRoute) return 'Periksa posisi terhadap jalur';
    return 'Ikuti garis rute';
  }

  /// Menentukan pesan peringatan rute atau posisi, bila ada.
  String? _warningLabel(RouteGuidanceState state) {
    if (widget.ghostPacerError) {
      return 'Hantu performa sebelumnya tidak dapat dimuat.';
    }
    if (state.isOffRoute) {
      return 'Di luar jalur sekitar ${state.distanceToRouteMeters!.toStringAsFixed(0)} m. Berhenti di tempat aman untuk memeriksa rute.';
    }
    if (state.currentPosition != null && !state.hasAccurateFix) {
      return 'Sinyal lokasi lemah. Posisi dan peringatan rute mungkin kurang tepat.';
    }
    return state.error;
  }
}

class GuidanceToolbar extends StatelessWidget {
  /// Membuat toolbar panduan dengan aksi berhenti [onStop].
  const GuidanceToolbar({required this.route, required this.onStop, super.key});

  final RouteRecord route;
  final VoidCallback onStop;

  /// Membangun metrik jarak tersisa, posisi rute, dan tombol akhiri panduan.
  @override
  Widget build(
    BuildContext context,
  ) => BlocBuilder<RouteGuidanceCubit, RouteGuidanceState>(
    builder: (context, state) {
      final unitSystem = context.watch<UnitSettingsCubit>().state.unitSystem;
      final distanceRemaining = state.distanceRemainingMeters == null
          ? 'Menunggu lokasi'
          : formatGuidanceDistance(state.distanceRemainingMeters!, unitSystem);
      final routePosition =
          '${state.nearestRouteIndex + 1}/${route.points.length}';
      return SenapathCard(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: _ToolbarMetric(
                  label: 'Jarak tersisa',
                  value: distanceRemaining,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ToolbarMetric(
                  label: 'Posisi rute',
                  value: routePosition,
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.tonalIcon(
                onPressed: () {
                  unawaited(context.read<RouteGuidanceCubit>().stop());
                  onStop();
                },
                icon: const Icon(Icons.stop_circle_outlined, size: 18),
                label: const Text('Akhiri panduan'),
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _ToolbarMetric extends StatelessWidget {
  /// Membuat metrik toolbar dengan [label] dan [value].
  const _ToolbarMetric({required this.label, required this.value});

  final String label;
  final String value;

  /// Membangun tampilan label dan nilai metrik secara vertikal.
  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: textTheme.bodySmall,
        ),
        const SizedBox(height: 2),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}
