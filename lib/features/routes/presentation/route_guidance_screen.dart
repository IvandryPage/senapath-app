import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../domain/saved_route.dart';
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
        final current = state.currentPosition;
        final positionPoint = current == null
            ? null
            : RoutePoint(
                latitude: current.latitude,
                longitude: current.longitude,
                elevationMeters: 0,
              );
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _statusLabel(state),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  if (current != null)
                    Text('±${current.accuracyMeters.toStringAsFixed(0)} m'),
                ],
              ),
            ),
            if (state.isOffRoute)
              _GuidanceWarning(
                text:
                    'Di luar jalur sekitar ${state.distanceToRouteMeters!.toStringAsFixed(0)} m. Berhenti di tempat aman untuk memeriksa rute.',
              )
            else if (current != null && !state.hasAccurateFix)
              const _GuidanceWarning(
                text: 'GPS kurang akurat; posisi dan peringatan rute terbatas.',
              )
            else if (state.error != null)
              _GuidanceWarning(text: state.error!),
            Expanded(
              child: RouteMapPreview(
                points: widget.route.points,
                currentPosition: positionPoint,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: _GuidanceMetric(
                      label: 'Jarak tersisa',
                      value: state.distanceRemainingMeters == null
                          ? 'Menunggu GPS'
                          : _formatDistance(state.distanceRemainingMeters!),
                    ),
                  ),
                  Expanded(
                    child: _GuidanceMetric(
                      label: 'Posisi rute',
                      value:
                          '${state.nearestRouteIndex + 1}/${widget.route.points.length}',
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Ikuti garis GPX. File ini tidak memuat instruksi belokan atau peta jalan.',
                    style: Theme.of(context).textTheme.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () {
                      unawaited(context.read<RouteGuidanceCubit>().stop());
                      context.pop();
                    },
                    icon: const Icon(Icons.stop_circle_outlined),
                    label: const Text('Akhiri panduan'),
                  ),
                ],
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
    return 'Ikuti jalur GPX';
  }

  String _formatDistance(double meters) => meters >= 1000
      ? '${(meters / 1000).toStringAsFixed(1)} km'
      : '${NumberFormat('0').format(meters)} m';
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
      Text(value, style: Theme.of(context).textTheme.titleMedium),
    ],
  );
}

class _GuidanceWarning extends StatelessWidget {
  const _GuidanceWarning({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
    color: Theme.of(context).colorScheme.errorContainer,
    child: Text(text),
  );
}
