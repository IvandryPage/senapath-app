import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../../core/units/unit_settings_cubit.dart';
import '../../../core/units/unit_system.dart';
import '../domain/saved_route.dart';
import 'google_directions_map.dart';
import 'route_guidance_cubit.dart';
import 'routes_screen.dart';

class RouteGuidanceScreen extends StatelessWidget {
  const RouteGuidanceScreen({
    required this.route,
    this.positionSource,
    super.key,
  });

  final RouteRecord route;
  final RoutePositionSource? positionSource;

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) {
      final cubit = RouteGuidanceCubit(
        positionSource ?? const GeolocatorRoutePositionSource(),
      );
      unawaited(cubit.start(route));
      return cubit;
    },
    child: _RouteGuidanceView(route: route),
  );
}

class _RouteGuidanceView extends StatefulWidget {
  const _RouteGuidanceView({required this.route});

  final RouteRecord route;

  @override
  State<_RouteGuidanceView> createState() => _RouteGuidanceViewState();
}

class _RouteGuidanceViewState extends State<_RouteGuidanceView> {
  @override
  void dispose() {
    unawaited(WakelockPlus.disable());
    super.dispose();
  }

  @override
  Widget build(
    BuildContext context,
  ) => BlocListener<RouteGuidanceCubit, RouteGuidanceState>(
    listenWhen: (previous, current) => previous.isRunning != current.isRunning,
    listener: (_, state) {
      unawaited(
        state.isRunning ? WakelockPlus.enable() : WakelockPlus.disable(),
      );
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
        return Stack(
          fit: StackFit.expand,
          children: [
            widget.route.source.startsWith('Google Maps')
                ? GoogleDirectionsMap(
                    route: widget.route,
                    currentPosition: positionPoint,
                    height: null,
                  )
                : RouteMapPreview(
                    points: widget.route.points,
                    source: widget.route.source,
                    currentPosition: positionPoint,
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
              ),
            ),
            Positioned(
              left: 12,
              right: 12,
              bottom: 12,
              child: _GuidanceControls(
                distanceRemaining: state.distanceRemainingMeters == null
                    ? 'Menunggu GPS'
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

  String _statusLabel(RouteGuidanceState state) {
    if (state.error != null) return state.error!;
    if (state.hasReachedEnd) return 'Rute selesai';
    if (state.isStarting) return 'Memulai GPS…';
    if (state.currentPosition == null) return 'Menunggu posisi GPS…';
    if (state.isOffRoute) return 'Periksa posisi terhadap jalur';
    return widget.route.source.startsWith('Google Maps')
        ? 'Ikuti rute Google Maps'
        : 'Ikuti jalur GPX';
  }

  String? _warningLabel(RouteGuidanceState state) {
    if (state.isOffRoute) {
      return 'Di luar jalur sekitar ${state.distanceToRouteMeters!.toStringAsFixed(0)} m. Berhenti di tempat aman untuk memeriksa rute.';
    }
    if (state.currentPosition != null && !state.hasAccurateFix) {
      return 'GPS kurang akurat; posisi dan peringatan rute terbatas.';
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
  });

  final String label;
  final double? accuracyMeters;
  final String? warning;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(Icons.navigation_outlined, color: colors.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                if (accuracyMeters != null)
                  Text('±${accuracyMeters!.toStringAsFixed(0)} m'),
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
  Widget build(BuildContext context) => Card(
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
            'Ikuti garis GPX. File ini tidak memuat instruksi belokan atau peta jalan.',
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
