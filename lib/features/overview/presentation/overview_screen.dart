import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/senapath_design.dart';
import '../../../core/units/unit_settings_cubit.dart';
import '../../../core/units/unit_system.dart';
import '../../leaderboard/domain/leaderboard_models.dart';
import '../../leaderboard/presentation/leaderboard_cubit.dart';
import '../../session/domain/ride_session.dart';
import '../../session/presentation/session_cubit.dart';
import '../../gamification/presentation/rider_gamification_cubit.dart';
import '../../gamification/presentation/rider_avatar.dart';

import '../../routes/domain/route_progress.dart';
import '../../routes/domain/saved_route.dart';
import '../../ride_coach/presentation/ride_coach_cubit.dart';

class OverviewScreen extends StatefulWidget {
  const OverviewScreen({super.key});

  @override
  State<OverviewScreen> createState() => _OverviewScreenState();
}

class _OverviewScreenState extends State<OverviewScreen> {
  bool _initialized = false;

  static const _coachRefreshInterval = Duration(hours: 1);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    unawaited(_initialize());
    unawaited(context.read<LeaderboardCubit>().load());
  }

  Future<void> _initialize() async {
    final sessionCubit = context.read<RideSessionCubit>();
    await sessionCubit.initialize();
    if (!mounted) return;
    await context.read<RiderGamificationCubit>().load(
      sessionCubit.state.completedSessions,
    );
  }

  void _handleCoachSessionUpdate(RideSessionState state) {
    final session = state.session;
    final isActive =
        session != null && session.status != RideSessionStatus.completed;
    final coachCubit = context.read<RideCoachCubit>();
    if (!isActive) {
      coachCubit.setActiveSession(null);
      return;
    }

    coachCubit.setActiveSession(session.id);

    final lastRequestAt = coachCubit.lastRequestAt;
    if (session.status == RideSessionStatus.recording &&
        coachCubit.hasConsentForSession(session.id) &&
        coachCubit.isConfigured &&
        coachCubit.isSignedIn &&
        !coachCubit.state.isLoading &&
        lastRequestAt != null &&
        DateTime.now().difference(lastRequestAt) >= _coachRefreshInterval) {
      unawaited(_requestRideCoach(state));
    }
  }

  Future<void> _requestRideCoach(RideSessionState rideState) async {
    final session = rideState.session;
    if (session == null || session.status == RideSessionStatus.completed) {
      return;
    }

    final coachCubit = context.read<RideCoachCubit>();
    coachCubit.setActiveSession(session.id);
    if (coachCubit.state.isLoading) return;
    if (!coachCubit.isConfigured || !coachCubit.isSignedIn) {
      final message = !coachCubit.isConfigured
          ? 'Layanan pelatih AI belum terhubung. Coba lagi nanti.'
          : 'Masuk ke akun online untuk menggunakan pelatih AI.';
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));
      return;
    }

    if (!coachCubit.hasConsentForSession(session.id)) {
      final consent = await showDialog<bool>(
        context: context,
        builder: (context) => SenapathAlertDialog(
          title: const Text('Aktifkan pelatih AI untuk sesi ini?'),
          content: const Text(
            'Untuk memberi saran selama sesi ini, Senapath akan mengirim ringkasan '
            'nama rute, progres dan jarak tersisa (jika tersedia), durasi, kecepatan, '
            'serta checkpoint berikutnya. Persetujuan ini berlaku sampai sesi berakhir; '
            'koordinat GPS mentah tidak dikirim.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Setuju untuk sesi ini'),
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
      if (!coachCubit.grantConsentForSession(session.id)) return;
    }

    final route = rideState.activeRoute;
    final progress = rideState.routeProgress;
    final location = rideState.recordedLocations.isEmpty
        ? null
        : rideState.recordedLocations.last;
    final nextCheckpoint = route == null || location == null
        ? null
        : _nextCheckpoint(route, location);
    coachCubit.markRequestStarted(session.id);
    await coachCubit.recommend(
      consent: true,
      rideContext: {
        'routeName':
            route?.name ??
            (session.title.trim().isEmpty ? 'Rute bebas' : session.title),
        'distanceRemainingKm': progress == null
            ? null
            : progress.distanceRemainingMeters / 1000,
        'progressPercent': progress?.percent,
        'elapsedMinutes': rideState.elapsed.inMinutes,
        'speedKmh': session.currentSpeedMetersPerSecond * 3.6,
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
    return BlocListener<RideSessionCubit, RideSessionState>(
      listener: (context, state) => _handleCoachSessionUpdate(state),
      child: BlocListener<RideSessionCubit, RideSessionState>(
        listenWhen: (previous, current) =>
            !identical(previous.completedSessions, current.completedSessions),
        listener: (context, state) => context
            .read<RiderGamificationCubit>()
            .updateSessions(state.completedSessions),
        child: BlocBuilder<RideSessionCubit, RideSessionState>(
          builder: (context, state) {
            final sessions = state.completedSessions;
            final activeSession =
                state.session != null &&
                state.session!.status != RideSessionStatus.completed;
            final now = DateTime.now();
            final localNow = now.toLocal();
            final weekStart = DateTime(
              localNow.year,
              localNow.month,
              localNow.day - (localNow.weekday - DateTime.monday),
            );
            final weekSessions = sessions
                .where((session) {
                  final startedAt = session.startedAt.toLocal();
                  return !startedAt.isBefore(weekStart) &&
                      !startedAt.isAfter(localNow);
                })
                .toList(growable: false);
            final weekDistance = weekSessions.fold<double>(
              0,
              (total, session) => total + session.distanceMeters,
            );
            final weekDuration = weekSessions.fold<Duration>(
              Duration.zero,
              (total, session) =>
                  total + session.durationAt(session.endedAt ?? now),
            );
            final averageSpeedMetersPerSecond = weekDuration.inSeconds == 0
                ? 0.0
                : weekDistance / weekDuration.inSeconds;
            final unit = context.watch<UnitSettingsCubit>().state.unitSystem;

            return ListView(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
              children: [
                _WelcomeCard(
                  title: activeSession ? 'RIDE IN PROGRESS' : 'READY TO RIDE',
                  onExplore: () => context.go('/routes'),
                ),
                const SizedBox(height: 18),
                _RiderProgressPreview(onOpen: () => context.push('/rider')),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Ringkasan minggu ini',
                        style: Theme.of(context).textTheme.titleLarge
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ),
                    TextButton(
                      onPressed: () => context.go('/progress'),
                      child: const Text('Progres'),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Expanded(
                      child: _SummaryTile(
                        icon: Icons.route_outlined,
                        value: _formatDistance(weekDistance, unit),
                        label: 'Jarak ditempuh',
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _SummaryTile(
                        icon: Icons.speed_outlined,
                        value: unit == UnitSystem.metric
                            ? '${(averageSpeedMetersPerSecond * 3.6).toStringAsFixed(1)} km/j'
                            : '${(averageSpeedMetersPerSecond * 2.236936).toStringAsFixed(1)} mph',
                        label: 'Rata-rata kecepatan',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _SummaryTile(
                        icon: Icons.timer_outlined,
                        value: _formatDuration(weekDuration),
                        label: 'Waktu gowes',
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _SummaryTile(
                        icon: Icons.directions_bike_outlined,
                        value: '${weekSessions.length}',
                        label: 'Sesi selesai',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                _RideCoachPreview(
                  sessionState: state,
                  hasSessionConsent:
                      state.session != null &&
                      context.read<RideCoachCubit>().hasConsentForSession(
                        state.session!.id,
                      ),
                  onRequestRecommendation: () => _requestRideCoach(state),
                ),
                const SizedBox(height: 20),
                _LeaderboardPreview(onOpen: () => context.push('/leaderboard')),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Aktivitas terbaru',
                        style: Theme.of(context).textTheme.titleLarge
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ),
                    if (sessions.isNotEmpty)
                      TextButton(
                        onPressed: () => context.go('/profile/sessions'),
                        child: const Text('Lihat semua'),
                      ),
                  ],
                ),
                if (state.isLoading && sessions.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (sessions.isEmpty)
                  const _EmptyActivityCard()
                else
                  for (final session in sessions.take(3))
                    _ActivityCard(
                      session: session,
                      onTap: () =>
                          context.push('/profile/sessions/${session.id}'),
                    ),
              ],
            );
          },
        ),
      ),
    );
  }
}

String _formatDistance(double meters, UnitSystem unit) =>
    unit == UnitSystem.metric
    ? '${(meters / 1000).toStringAsFixed(1)} km'
    : '${(meters / 1609.344).toStringAsFixed(1)} mi';

String _formatDuration(Duration duration) => duration.inHours > 0
    ? '${duration.inHours}j ${duration.inMinutes.remainder(60)}m'
    : '${duration.inMinutes}m';

class _RideCoachPreview extends StatelessWidget {
  const _RideCoachPreview({
    required this.sessionState,
    required this.hasSessionConsent,
    required this.onRequestRecommendation,
  });

  final RideSessionState sessionState;
  final bool hasSessionConsent;
  final VoidCallback onRequestRecommendation;

  @override
  Widget build(BuildContext context) {
    final session = sessionState.session;
    final route = sessionState.activeRoute;
    final isActive =
        session != null &&
        (session.status == RideSessionStatus.recording ||
            session.status == RideSessionStatus.paused);
    final progress = isActive ? sessionState.routeProgress : null;

    return BlocBuilder<RideCoachCubit, RideCoachState>(
      builder: (context, coachState) {
        final colors = Theme.of(context).colorScheme;
        final subtitle = !isActive
            ? 'Saran kontekstual muncul saat sesi gowes berlangsung.'
            : route == null
            ? 'Sesi bebas · ${_formatDuration(sessionState.elapsed)}'
            : '${route.name} · ${progress?.percent.toStringAsFixed(0) ?? '—'}% selesai';

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
                const SizedBox(height: 16),
                Text(
                  coachState.recommendation!,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ] else if (isActive && coachState.isLoading) ...[
                const SizedBox(height: 16),
                const Text('Coach sedang membaca progres sesi ini...'),
              ] else if (!isActive) ...[
                const SizedBox(height: 16),
                const Text(
                  'Mulai sesi gowes untuk mendapatkan arahan coach yang mengikuti progresmu.',
                ),
              ] else if (!hasSessionConsent) ...[
                const SizedBox(height: 16),
                const Text(
                  'Minta arahan pace, progres, dan fokus gowes berdasarkan sesi yang sedang berjalan.',
                ),
              ],
              if (coachState.error != null) ...[
                const SizedBox(height: 12),
                Text(coachState.error!, style: TextStyle(color: colors.error)),
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
              if (isActive) ...[
                const SizedBox(height: 14),
                FilledButton.tonalIcon(
                  onPressed: coachState.isLoading
                      ? null
                      : onRequestRecommendation,
                  icon: Icon(
                    coachState.recommendation == null
                        ? Icons.lightbulb_outline
                        : Icons.refresh,
                  ),
                  label: Text(
                    coachState.isLoading
                        ? 'Memperbarui saran...'
                        : coachState.recommendation == null
                        ? hasSessionConsent
                              ? 'Minta rekomendasi'
                              : 'Aktifkan coach untuk sesi ini'
                        : 'Minta saran lain',
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Saran diperbarui otomatis setiap jam saat sesi aktif. '
                  'Ringkasan aktivitas dikirim, bukan koordinat GPS mentah.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _RiderProgressPreview extends StatelessWidget {
  const _RiderProgressPreview({required this.onOpen});

  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) =>
      BlocBuilder<RiderGamificationCubit, RiderGamificationState>(
        builder: (context, state) {
          final progress = state.progress;
          if (progress == null) return const SizedBox.shrink();
          return SenapathCard(
            onTap: onOpen,
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                RiderAvatar(
                  style: progress.style,
                  appearance: state.appearance,
                  size: 44,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Rider level ${progress.level}',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 4),
                      LinearProgressIndicator(value: progress.levelProgress),
                      const SizedBox(height: 4),
                      Text(
                        '${progress.experience} XP · ${progress.style.label}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right),
              ],
            ),
          );
        },
      );
}

class _WelcomeCard extends StatelessWidget {
  const _WelcomeCard({required this.title, required this.onExplore});

  final String title;
  final VoidCallback onExplore;

  @override
  Widget build(BuildContext context) {
    return SenapathCard(
      padding: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        height: 216,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              'assets/images/app_home_cta.jpg',
              fit: BoxFit.cover,
              alignment: const Alignment(0, 0.6),
              semanticLabel: 'Pesepeda menyusuri jalan di antara perbukitan',
            ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    Color(0x00071122),
                    Color(0x99071122),
                    Color(0xE6071122),
                  ],
                  stops: [0.12, 0.55, 1],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
              child: Align(
                alignment: AlignmentDirectional.centerEnd,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'RIDE YOUR WAY',
                      textAlign: TextAlign.end,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: SenapathColors.white.withValues(alpha: 0.82),
                        letterSpacing: 1.4,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      title,
                      textAlign: TextAlign.end,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: SenapathColors.white,
                        height: 1.15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 14),
                    SenapathButton(
                      key: const Key('home-ready-to-ride-explore'),
                      fullWidth: false,
                      onPressed: onExplore,
                      label: 'Jelajahi',
                      backgroundColor: SenapathColors.pale,
                      foregroundColor: SenapathColors.navy,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LeaderboardPreview extends StatelessWidget {
  const _LeaderboardPreview({required this.onOpen});

  final VoidCallback onOpen;

  @override
  Widget build(
    BuildContext context,
  ) => BlocBuilder<LeaderboardCubit, LeaderboardState>(
    builder: (context, state) {
      final optedIn = state.settings?.isOptedIn == true;
      final colors = Theme.of(context).colorScheme;
      final topEntries = state.entries.take(3).toList(growable: false);

      return SenapathCard(
        padding: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 148,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset(
                    'assets/images/app_podium_garage.jpg',
                    fit: BoxFit.cover,
                    alignment: const Alignment(0, 0.38),
                    semanticLabel: 'Pesepeda dan podium di dalam garasi sepeda',
                  ),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomLeft,
                        end: Alignment.topRight,
                        colors: [
                          Color(0xE6071122),
                          Color(0x99071122),
                          Color(0x1A071122),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                    child: Align(
                      alignment: Alignment.bottomLeft,
                      child: Row(
                        children: [
                          const Icon(
                            Icons.emoji_events_outlined,
                            color: SenapathColors.white,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Rekor gowes',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(
                                    color: SenapathColors.white,
                                    fontWeight: FontWeight.w800,
                                  ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (state.isLoading)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (!optedIn)
                    _LeaderboardInvitation(
                      message: state.error == null
                          ? 'Peringkat ini opsional. Setujui partisipasi untuk menampilkan nama profil dan rekor terbaik.'
                          : 'Masuk ke akun online untuk mengatur partisipasi papan peringkat.',
                      onOpen: onOpen,
                      actionLabel: state.error == null
                          ? 'Atur partisipasi'
                          : 'Masuk / pengaturan',
                    )
                  else if (state.error != null) ...[
                    Text(
                      'Peringkat belum bisa dimuat. Periksa koneksi lalu coba lagi.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 10),
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: TextButton.icon(
                        onPressed: () =>
                            context.read<LeaderboardCubit>().load(),
                        icon: const Icon(Icons.refresh),
                        label: const Text('Coba lagi'),
                      ),
                    ),
                  ] else if (state.entries.isEmpty)
                    _LeaderboardInvitation(
                      message: 'Belum ada rekor peserta untuk kategori ini.',
                      onOpen: onOpen,
                      actionLabel: 'Buka papan peringkat',
                    )
                  else ...[
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '3 rekor teratas',
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: colors.primaryContainer,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            state.category == LeaderboardCategory.distance
                                ? 'Jarak terjauh'
                                : 'Durasi terlama',
                            style: Theme.of(context).textTheme.labelMedium
                                ?.copyWith(
                                  color: colors.onPrimaryContainer,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _LeaderboardWinner(
                      entry: topEntries.first,
                      category: state.category,
                    ),
                    if (topEntries.length > 1) ...[
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: _LeaderboardRunnerUp(
                              entry: topEntries[1],
                              category: state.category,
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (topEntries.length > 2)
                            Expanded(
                              child: _LeaderboardRunnerUp(
                                entry: topEntries[2],
                                category: state.category,
                              ),
                            )
                          else
                            const Expanded(child: SizedBox()),
                        ],
                      ),
                    ],
                    const SizedBox(height: 10),
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: TextButton.icon(
                        key: const Key('home-open-leaderboard'),
                        onPressed: onOpen,
                        icon: const Icon(Icons.arrow_forward),
                        label: const Text('Buka papan peringkat'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      );
    },
  );
}

class _LeaderboardInvitation extends StatelessWidget {
  const _LeaderboardInvitation({
    required this.message,
    required this.onOpen,
    required this.actionLabel,
  });

  final String message;
  final VoidCallback onOpen;
  final String actionLabel;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(message),
      const SizedBox(height: 10),
      Align(
        alignment: AlignmentDirectional.centerStart,
        child: FilledButton.tonalIcon(
          key: const Key('home-open-leaderboard'),
          onPressed: onOpen,
          icon: const Icon(Icons.emoji_events_outlined),
          label: Text(actionLabel),
        ),
      ),
    ],
  );
}

class _LeaderboardWinner extends StatelessWidget {
  const _LeaderboardWinner({required this.entry, required this.category});

  final LeaderboardEntry entry;
  final LeaderboardCategory category;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    const medalColor = Color(0xFFB77900);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.primaryContainer.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: medalColor.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: const BoxDecoration(
              color: Color(0xFFFFE8A3),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.emoji_events_rounded,
              color: medalColor,
              size: 28,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '1 · ${entry.displayName}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 2),
                Text(
                  'Lv.${entry.riderLevel} · ${entry.riderStyle.label}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: colors.onSurfaceVariant),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _leaderboardScoreText(entry, category),
            style: Theme.of(context).textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _LeaderboardRunnerUp extends StatelessWidget {
  const _LeaderboardRunnerUp({required this.entry, required this.category});

  final LeaderboardEntry entry;
  final LeaderboardCategory category;

  @override
  Widget build(BuildContext context) {
    final medalColor = entry.rank == 2
        ? const Color(0xFF68727D)
        : const Color(0xFF9C5A36);
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: medalColor.withValues(alpha: 0.14),
            child: Text(
              '${entry.rank}',
              style: TextStyle(
                color: medalColor,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelLarge
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  Text(
                    _leaderboardScoreText(entry, category),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _leaderboardScoreText(
  LeaderboardEntry entry,
  LeaderboardCategory category,
) {
  if (category == LeaderboardCategory.distance) {
    return '${(entry.score / 1000).toStringAsFixed(1)} km';
  }
  final seconds = entry.score.round();
  final hours = seconds ~/ 3600;
  final minutes = seconds % 3600 ~/ 60;
  return hours > 0 ? '${hours}j ${minutes}m' : '${minutes}m';
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SenapathCard(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: colors.primary, size: 21),
            const SizedBox(height: 10),
            Text(
              value,
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 2),
            Text(label, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _EmptyActivityCard extends StatelessWidget {
  const _EmptyActivityCard();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SenapathCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 25,
              backgroundColor: colors.secondaryContainer,
              child: Icon(
                Icons.directions_bike_outlined,
                color: colors.primary,
              ),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Belum ada sesi',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Mulai perjalanan pertamamu dan aktivitasnya muncul di sini.',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActivityCard extends StatelessWidget {
  const _ActivityCard({required this.session, required this.onTap});

  final RideSessionSnapshot session;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final duration = session.durationAt(session.endedAt ?? session.startedAt);
    final unit = context.watch<UnitSettingsCubit>().state.unitSystem;
    final distance = unit == UnitSystem.metric
        ? '${(session.distanceMeters / 1000).toStringAsFixed(2)} km'
        : '${(session.distanceMeters / 1609.344).toStringAsFixed(2)} mi';
    return SenapathCard(
      clipBehavior: Clip.antiAlias,
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: colors.secondaryContainer,
                child: Icon(
                  Icons.directions_bike_rounded,
                  size: 20,
                  color: colors.primary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Sesi bersepeda',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _formatActivityDate(session.startedAt.toLocal()),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: colors.onSurfaceVariant),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            distance,
            style: Theme.of(context).textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _ActivityMetric(
                icon: Icons.timer_outlined,
                value: _formatDuration(duration),
                label: 'Durasi',
              ),
              const SizedBox(width: 22),
              _ActivityMetric(
                icon: session.syncStatus == 'synced'
                    ? Icons.cloud_done_outlined
                    : Icons.phone_android_outlined,
                value: session.syncStatus == 'synced' ? 'Tersinkron' : 'Lokal',
                label: 'Penyimpanan',
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    return hours > 0 ? '${hours}j ${minutes}m' : '${minutes}m';
  }

  String _formatActivityDate(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'Mei',
      'Jun',
      'Jul',
      'Agu',
      'Sep',
      'Okt',
      'Nov',
      'Des',
    ];
    return '${date.day} ${months[date.month - 1]} · '
        '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}';
  }
}

class _ActivityMetric extends StatelessWidget {
  const _ActivityMetric({
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, size: 17, color: colors.primary),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value, style: Theme.of(context).textTheme.labelLarge),
            Text(label, style: Theme.of(context).textTheme.labelSmall),
          ],
        ),
      ],
    );
  }
}
