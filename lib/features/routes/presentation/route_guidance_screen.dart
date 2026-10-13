import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../../app/theme/senapath_design.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/units/unit_settings_cubit.dart';
import '../../../core/units/unit_system.dart';
import '../data/ghost_pacer_service.dart';
import '../data/route_wind_service.dart';
import '../domain/ghost_pacer.dart';
import '../domain/route_wind.dart';
import '../domain/saved_route.dart';
import 'route_guidance_cubit.dart';
import 'route_wind_indicator.dart';
import 'routes_screen.dart';

class RouteGuidanceScreen extends StatelessWidget {
  const RouteGuidanceScreen({
    required this.route,
    this.positionSource,
    this.windService,
    this.ghostPacerService,
    this.ambientBright = false,
    super.key,
  });

  final RouteRecord route;
  final RoutePositionSource? positionSource;
  final RouteWindService? windService;
  final GhostPacerService? ghostPacerService;
  final bool ambientBright;

  @override
  Widget build(BuildContext context) => AnimatedTheme(
    data: ambientBright ? AppTheme.rideBright : Theme.of(context),
    duration: const Duration(milliseconds: 450),
    curve: Curves.easeInOut,
    child: BlocProvider(
      create: (_) {
        final cubit = RouteGuidanceCubit(
          positionSource ?? const GeolocatorRoutePositionSource(),
        );
        unawaited(cubit.start(route));
        return cubit;
      },
      child: _RouteGuidanceView(
        route: route,
        windService: windService,
        ghostPacerService: ghostPacerService,
      ),
    ),
  );
}

class _RouteGuidanceView extends StatefulWidget {
  const _RouteGuidanceView({
    required this.route,
    this.windService,
    this.ghostPacerService,
  });

  final RouteRecord route;
  final RouteWindService? windService;
  final GhostPacerService? ghostPacerService;

  @override
  State<_RouteGuidanceView> createState() => _RouteGuidanceViewState();
}

class _RouteGuidanceViewState extends State<_RouteGuidanceView> {
  late final RouteWindService _windService =
      widget.windService ?? OpenMeteoRouteWindService();
  RouteWindObservation? _wind;
  ({double latitude, double longitude})? _lastWindPosition;
  DateTime? _lastWindRequestAt;
  bool _windConsentGranted = false;
  bool _isLoadingWind = false;
  bool _hasWindError = false;
  GhostPacerPerformance? _ghostPacer;
  bool _hasGhostPacerError = false;
  DateTime? _ghostStartedAt;
  Timer? _ghostClock;

  @override
  void initState() {
    super.initState();
    unawaited(_loadGhostPacer());
  }

  @override
  void dispose() {
    _ghostClock?.cancel();
    unawaited(WakelockPlus.disable());
    super.dispose();
  }

  @override
  Widget build(
    BuildContext context,
  ) => BlocListener<RouteGuidanceCubit, RouteGuidanceState>(
    listenWhen: (previous, current) =>
        previous.isRunning != current.isRunning ||
        previous.currentPosition != current.currentPosition,
    listener: (_, state) {
      _syncGhostClock(state);
      if (state.isRunning) {
        unawaited(WakelockPlus.enable());
      } else {
        unawaited(WakelockPlus.disable());
      }
      if (_windConsentGranted &&
          state.currentPosition != null &&
          state.hasAccurateFix) {
        unawaited(_refreshWindIfNeeded(state));
      }
    },
    child: BlocBuilder<RouteGuidanceCubit, RouteGuidanceState>(
      builder: (context, state) {
        final unitSystem = context.watch<UnitSettingsCubit>().state.unitSystem;
        final current = state.currentPosition;
        final positionPoint = current == null
            ? null
            : RoutePoint(
                latitude: current.latitude,
                longitude: current.longitude,
                elevationMeters: 0,
              );
        final routeHeading = widget.route.points.length < 2
            ? null
            : routeHeadingDegrees(widget.route.points, state.nearestRouteIndex);
        final ghostPosition = state.isRunning && !state.hasReachedEnd
            ? _ghostPacerPosition()
            : null;
        return Stack(
          fit: StackFit.expand,
          children: [
            RouteMapPreview(
              points: widget.route.points,
              source: widget.route.source,
              currentPosition: positionPoint,
              ghostPosition: ghostPosition?.point,
              ghostHeadingDegrees: ghostPosition?.headingDegrees,
              height: null,
            ),
            Positioned(
              top: 12,
              left: 16,
              right: 16,
              child: _GuidanceStatus(
                label: _statusLabel(state),
                accuracyMeters: current?.accuracyMeters,
                warning: _warningLabel(state),
                windIndicator: RouteWindIndicator(
                  wind: _wind,
                  routeHeadingDegrees: routeHeading,
                  isLoading: _isLoadingWind,
                  hasError: _hasWindError,
                  isLocationReady: current != null && state.hasAccurateFix,
                  onPressed: current == null || !state.hasAccurateFix
                      ? null
                      : () => _requestWind(state),
                ),
              ),
            ),
            Positioned(
              left: 12,
              right: 12,
              bottom: 12,
              child: _GuidanceControls(
                distanceRemaining: state.distanceRemainingMeters == null
                    ? 'Menunggu lokasi'
                    : _formatDistance(
                        state.distanceRemainingMeters!,
                        unitSystem,
                      ),
                routePosition:
                    '${state.nearestRouteIndex + 1}/${widget.route.points.length}',
                onStop: () {
                  unawaited(context.read<RouteGuidanceCubit>().stop());
                  context.pop();
                },
              ),
            ),
          ],
        );
      },
    ),
  );

  Future<void> _loadGhostPacer() async {
    final service = widget.ghostPacerService;
    if (service == null) return;
    try {
      final performance = await service.loadBestForRoute(widget.route);
      if (mounted) setState(() => _ghostPacer = performance);
    } catch (_) {
      if (mounted) setState(() => _hasGhostPacerError = true);
    }
  }

  void _syncGhostClock(RouteGuidanceState state) {
    if (state.isRunning && !state.hasReachedEnd) {
      _ghostStartedAt ??= DateTime.now();
      _ghostClock ??= Timer.periodic(const Duration(seconds: 5), (_) {
        if (mounted) setState(() {});
      });
    } else {
      _ghostClock?.cancel();
      _ghostClock = null;
    }
  }

  GhostPacerMapPosition? _ghostPacerPosition() {
    final performance = _ghostPacer;
    final startedAt = _ghostStartedAt;
    if (performance == null || startedAt == null) return null;
    final elapsed = DateTime.now().difference(startedAt);
    return ghostPacerMapPositionAt(
      widget.route.points,
      performance.distanceAt(elapsed),
    );
  }

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

  String _statusLabel(RouteGuidanceState state) {
    if (state.error != null) return state.error!;
    if (state.hasReachedEnd) return 'Rute selesai';
    if (state.isStarting) return 'Mencari lokasi…';
    if (state.currentPosition == null) return 'Menunggu lokasi…';
    if (state.isOffRoute) return 'Periksa posisi terhadap jalur';
    return 'Ikuti garis rute';
  }

  String? _warningLabel(RouteGuidanceState state) {
    if (_hasGhostPacerError) {
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

  String _formatDistance(double meters, UnitSystem unitSystem) {
    if (unitSystem == UnitSystem.metric) {
      return meters >= 1000
          ? '${(meters / 1000).toStringAsFixed(1)} km'
          : '${NumberFormat('0').format(meters)} m';
    }
    return meters >= 1609.344
        ? '${(meters / 1609.344).toStringAsFixed(1)} mi'
        : '${NumberFormat('0').format(meters * 3.28084)} ft';
  }
}

class _GuidanceStatus extends StatelessWidget {
  const _GuidanceStatus({
    required this.label,
    required this.accuracyMeters,
    required this.warning,
    required this.windIndicator,
  });

  final String label;
  final double? accuracyMeters;
  final String? warning;
  final Widget windIndicator;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SenapathCard(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(Icons.navigation_outlined, color: SenapathColors.accent),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                if (accuracyMeters != null)
                  Text('±${accuracyMeters!.toStringAsFixed(0)} m'),
                windIndicator,
              ],
            ),
            if (warning != null) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: colors.errorContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  warning!,
                  style: TextStyle(color: colors.onErrorContainer),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _GuidanceControls extends StatelessWidget {
  const _GuidanceControls({
    required this.distanceRemaining,
    required this.routePosition,
    required this.onStop,
  });

  final String distanceRemaining;
  final String routePosition;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) => SenapathCard(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: _GuidanceMetric(
                  label: 'Jarak tersisa',
                  value: distanceRemaining,
                ),
              ),
              Expanded(
                child: _GuidanceMetric(
                  label: 'Posisi rute',
                  value: routePosition,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'File GPX hanya menunjukkan garis rute, tanpa petunjuk belokan atau peta jalan.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: onStop,
            icon: const Icon(Icons.stop_circle_outlined),
            label: const Text('Akhiri panduan'),
          ),
        ],
      ),
    ),
  );
}

class _GuidanceMetric extends StatelessWidget {
  const _GuidanceMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: Theme.of(context).textTheme.bodySmall),
      const SizedBox(height: 2),
      Text(
        value,
        style: Theme.of(context).textTheme.titleMedium
            ?.copyWith(fontWeight: FontWeight.w700),
      ),
    ],
  );
}
