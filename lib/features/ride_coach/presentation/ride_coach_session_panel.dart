import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../app/theme/senapath_design.dart';
import '../../routes/domain/route_progress.dart';
import '../../routes/domain/saved_route.dart';
import '../../session/domain/ride_session.dart';
import '../../session/presentation/session_cubit.dart';
import 'ride_coach_cubit.dart';
import '../domain/coach_recommendation_formatter.dart';

class RideCoachSessionPanel extends StatefulWidget {
  const RideCoachSessionPanel({required this.sessionState, super.key});

  final RideSessionState sessionState;

  @override
  State<RideCoachSessionPanel> createState() => _RideCoachSessionPanelState();
}

class _RideCoachSessionPanelState extends State<RideCoachSessionPanel> {
  static const _refreshInterval = Duration(hours: 1);
  String? _localError;

  @override
  void initState() {
    super.initState();
    _scheduleSessionUpdate();
  }

  @override
  void didUpdateWidget(covariant RideCoachSessionPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.sessionState, widget.sessionState)) {
      _scheduleSessionUpdate();
    }
  }

  void _scheduleSessionUpdate() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _handleSessionUpdate(widget.sessionState);
    });
  }

  void _handleSessionUpdate(RideSessionState state) {
    final session = state.session;
    final coach = context.read<RideCoachCubit>();
    if (session == null || session.status == RideSessionStatus.completed) {
      coach.setActiveSession(null);
      return;
    }
    coach.setActiveSession(session.id);

    final lastRequestAt = coach.lastRequestAt;
    if (session.status == RideSessionStatus.recording &&
        coach.hasConsentForSession(session.id) &&
        coach.isConfigured &&
        coach.isSignedIn &&
        !coach.state.isLoading &&
        lastRequestAt != null &&
        DateTime.now().difference(lastRequestAt) >= _refreshInterval) {
      unawaited(_requestRecommendation(state));
    }
  }

  Future<void> _requestRecommendation(RideSessionState state) async {
    final session = state.session;
    if (session == null || session.status == RideSessionStatus.completed) {
      return;
    }

    final coach = context.read<RideCoachCubit>();
    coach.setActiveSession(session.id);
    if (coach.state.isLoading) return;
    if (!coach.isConfigured || !coach.isSignedIn) {
      setState(
        () => _localError = !coach.isConfigured
            ? 'Pelatih AI belum tersedia. Coba lagi nanti.'
            : 'Masuk ke akun online untuk memakai pelatih AI.',
      );
      return;
    }

    if (!coach.hasConsentForSession(session.id)) {
      final consent = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => SenapathAlertDialog(
          title: const Text('Gunakan pelatih AI selama perjalanan ini?'),
          content: const Text(
            'Agar bisa memberi saran, Senapath akan mengirim nama rute, jarak '
            'yang sudah ditempuh dan tersisa, durasi, kecepatan, serta titik '
            'rute berikutnya. Data ini dikirim sampai perjalanan selesai. '
            'Titik GPS-mu tidak dikirim.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Izinkan selama perjalanan ini'),
            ),
          ],
        ),
      );
      if (consent != true || !mounted) return;
      final currentSession = context.read<RideSessionCubit>().state.session;
      if (currentSession?.id != session.id ||
          currentSession?.status == RideSessionStatus.completed) {
        return;
      }
      if (!coach.grantConsentForSession(session.id)) return;
    }

    if (!mounted) return;
    setState(() => _localError = null);
    final currentState = context.read<RideSessionCubit>().state;
    final currentSession = currentState.session;
    if (currentSession == null ||
        currentSession.id != session.id ||
        currentSession.status == RideSessionStatus.completed) {
      return;
    }
    final route = currentState.activeRoute;
    final progress = currentState.routeProgress;
    final location = currentState.recordedLocations.isEmpty
        ? null
        : currentState.recordedLocations.last;
    final nextCheckpoint = route == null || location == null
        ? null
        : _nextCheckpoint(route, location);
    coach.markRequestStarted(session.id);
    await coach.recommend(
      consent: true,
      rideContext: {
        'routeName':
            route?.name ??
            (currentSession.title.trim().isEmpty
                ? 'Rute bebas'
                : currentSession.title),
        'distanceRemainingKm': progress == null
            ? null
            : progress.distanceRemainingMeters / 1000,
        'progressPercent': progress?.percent,
        'elapsedMinutes': currentState.elapsed.inMinutes,
        'speedKmh': currentSession.currentSpeedMetersPerSecond * 3.6,
        'nextCheckpoint': nextCheckpoint?.name,
      },
    );
  }

  RouteCheckpoint? _nextCheckpoint(
    RouteRecord route,
    TelemetryLocation location,
  ) {
    RouteCheckpoint? closest;
    var closestDistance = double.infinity;
    for (final checkpoint in route.checkpoints) {
      final distance = RouteProgress.distanceToCheckpoint(location, checkpoint);
      if (distance < closestDistance) {
        closest = checkpoint;
        closestDistance = distance;
      }
    }
    return closest;
  }

  @override
  Widget build(BuildContext context) {
    final rideState = widget.sessionState;
    final session = rideState.session;
    if (session == null || session.status == RideSessionStatus.completed) {
      return const SizedBox.shrink();
    }

    return BlocBuilder<RideCoachCubit, RideCoachState>(
      builder: (context, coachState) {
        final colors = Theme.of(context).colorScheme;
        final route = rideState.activeRoute;
        final subtitle = route == null
            ? 'Sesi bebas · ${_formatDuration(rideState.elapsed)}'
            : '${route.name} · '
                  '${rideState.routeProgress?.percent.toStringAsFixed(0) ?? '—'}% selesai';
        final error = _localError ?? coachState.error;

        return SenapathCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: colors.tertiaryContainer,
                    child: Icon(
                      Icons.auto_awesome_outlined,
                      color: colors.onTertiaryContainer,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Pelatih AI',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        Text(
                          subtitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  if (coachState.isLoading)
                    const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                ],
              ),
              if (coachState.recommendation != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colors.tertiaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.tips_and_updates_outlined,
                        size: 20,
                        color: colors.onTertiaryContainer,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          formatCoachRecommendation(coachState.recommendation!),
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: colors.onTertiaryContainer,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ),
                    ],
                  ),
                ),
              ] else if (coachState.isLoading) ...[
                const SizedBox(height: 16),
                const Text('Coach sedang membaca progres sesi ini...'),
              ] else ...[
                const SizedBox(height: 16),
                const Text(
                  'Minta arahan pace, progres, dan fokus gowes berdasarkan sesi yang sedang berjalan.',
                ),
              ],
              if (error != null) ...[
                const SizedBox(height: 12),
                Text(error, style: TextStyle(color: colors.error)),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: coachState.isLoading
                        ? null
                        : context.read<RideCoachCubit>().diagnoseConfiguration,
                    icon: const Icon(Icons.build_outlined),
                    label: const Text('Periksa konfigurasi AI'),
                  ),
                ),
              ],
              if (coachState.notice != null) ...[
                const SizedBox(height: 12),
                Text(coachState.notice!),
              ],
              const SizedBox(height: 14),
              FilledButton.tonalIcon(
                onPressed: coachState.isLoading
                    ? null
                    : () => _requestRecommendation(rideState),
                icon: Icon(
                  coachState.recommendation == null
                      ? Icons.lightbulb_outline
                      : Icons.refresh,
                ),
                label: Text(
                  coachState.isLoading
                      ? 'Memuat saran…'
                      : coachState.recommendation == null
                      ? context.read<RideCoachCubit>().hasConsentForSession(
                              session.id,
                            )
                            ? 'Minta saran'
                            : 'Izinkan pelatih untuk perjalanan ini'
                      : 'Minta saran lain',
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Saran diperbarui setiap jam selama perjalanan. Yang dikirim hanya '
                'ringkasannya, bukan titik GPS.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatDuration(Duration duration) => duration.inHours > 0
      ? '${duration.inHours}j ${duration.inMinutes.remainder(60)}m'
      : '${duration.inMinutes}m';
}
