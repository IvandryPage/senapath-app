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
import '../../notifications/presentation/notification_settings_cubit.dart';

class OverviewScreen extends StatefulWidget {
  const OverviewScreen({super.key});

  @override
  State<OverviewScreen> createState() => _OverviewScreenState();
}

class _OverviewScreenState extends State<OverviewScreen> {
  bool _initialized = false;

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

  @override
  Widget build(BuildContext context) {
    return BlocListener<RideSessionCubit, RideSessionState>(
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
          final weekSessions = sessions.where((session) {
            final startedAt = session.startedAt.toLocal();
            return !startedAt.isBefore(weekStart) &&
                !startedAt.isAfter(localNow);
          }).toList(growable: false);
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
              _WeeklySummary(
                distanceMeters: weekDistance,
                rideDuration: weekDuration,
                averageSpeedMetersPerSecond: averageSpeedMetersPerSecond,
                sessionCount: weekSessions.length,
                unitSystem: unit,
              ),
              const SizedBox(height: 18),
              _RideCoachPreview(
                sessionState: state,
                onSendNotification: (recommendation) => context
                    .read<NotificationSettingsCubit>()
                    .sendRecommendation(recommendation),
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
    );
  }
}

class _WeeklySummary extends StatelessWidget {
  const _WeeklySummary({
    required this.distanceMeters,
    required this.rideDuration,
    required this.averageSpeedMetersPerSecond,
    required this.sessionCount,
    required this.unitSystem,
  });

  final double distanceMeters;
  final Duration rideDuration;
  final double averageSpeedMetersPerSecond;
  final int sessionCount;
  final UnitSystem unitSystem;

  @override
  Widget build(BuildContext context) {
    final distance = unitSystem == UnitSystem.metric
        ? '${(distanceMeters / 1000).toStringAsFixed(1)} km'
        : '${(distanceMeters / 1609.344).toStringAsFixed(1)} mi';
    final speed = unitSystem == UnitSystem.metric
        ? '${(averageSpeedMetersPerSecond * 3.6).toStringAsFixed(1)} km/j'
        : '${(averageSpeedMetersPerSecond * 2.236936).toStringAsFixed(1)} mph';
    final hours = rideDuration.inHours;
    final minutes = rideDuration.inMinutes.remainder(60);
    final duration = hours > 0 ? '${hours}j ${minutes}m' : '${minutes}m';

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _SummaryTile(
                icon: Icons.route_outlined,
                value: distance,
                label: 'Jarak ditempuh',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _SummaryTile(
                icon: Icons.speed_outlined,
                value: speed,
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
                value: duration,
                label: 'Waktu gowes',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _SummaryTile(
                icon: Icons.directions_bike_outlined,
                value: '$sessionCount',
                label: 'Sesi selesai',
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _RideCoachPreview extends StatelessWidget {
  const _RideCoachPreview({
    required this.sessionState,
    required this.onSendNotification,
  });

  final RideSessionState sessionState;
  final Future<void> Function(String recommendation) onSendNotification;

  @override
  Widget build(BuildContext context) {
    final session = sessionState.session;
    final route = sessionState.activeRoute;
    final isActive =
        session != null &&
        (session.status == RideSessionStatus.recording ||
            session.status == RideSessionStatus.paused);
    final location = sessionState.recordedLocations.isEmpty
        ? null
        : sessionState.recordedLocations.last;
    final progress = isActive ? sessionState.routeProgress : null;
    final nextCheckpoint = route == null || location == null
        ? null
        : _nextCheckpoint(route, location);

    return BlocBuilder<RideCoachCubit, RideCoachState>(
      builder: (context, coachState) => SenapathCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Theme.of(context)
                      .colorScheme
                      .tertiaryContainer,
                  child: Icon(
                    Icons.auto_awesome_outlined,
                    color: Theme.of(context).colorScheme.onTertiaryContainer,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Pelatih AI saat gowes',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      Text(
                        route == null
                            ? 'Pilih GPX dan mulai sesi untuk saran kontekstual.'
                            : '${route.name} · ${progress?.percent ?? 0}% selesai',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (coachState.recommendation != null) ...[
              const SizedBox(height: 14),
              Text(coachState.recommendation!),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () =>
                      onSendNotification(coachState.recommendation!),
                  icon: const Icon(Icons.notifications_active_outlined),
                  label: const Text('Kirim sebagai notifikasi'),
                ),
              ),
            ],
            if (coachState.error != null) ...[
              const SizedBox(height: 10),
              Text(
                coachState.error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            if (coachState.notice != null) ...[
              const SizedBox(height: 10),
              Text(coachState.notice!),
            ],
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed:
                  coachState.isLoading ||
                      !context.read<RideCoachCubit>().isConfigured ||
                      !context.read<RideCoachCubit>().isSignedIn
                  ? null
                  : () =>
                        context.read<RideCoachCubit>().diagnoseConfiguration(),
              icon: const Icon(Icons.manage_search_outlined),
              label: const Text('Cek konfigurasi Gemini'),
            ),
            FilledButton.tonalIcon(
              onPressed: coachState.isLoading
                  ? null
                  : () {
                      final blocker =
                          !context.read<RideCoachCubit>().isConfigured
                          ? 'Layanan AI belum terhubung. Periksa konfigurasi Supabase.'
                          : !context.read<RideCoachCubit>().isSignedIn
                          ? 'Masuk ke akun online untuk meminta rekomendasi.'
                          : !isActive
                          ? 'Mulai atau lanjutkan sesi gowes terlebih dahulu.'
                          : route == null
                          ? 'Pilih GPX untuk sesi ini agar pelatih dapat membaca progres rute.'
                          : progress == null
                          ? 'Tunggu sampai lokasi GPS dan progres rute tersedia.'
                          : null;
                      if (blocker != null) {
                        ScaffoldMessenger.of(context)
                          ..hideCurrentSnackBar()
                          ..showSnackBar(SnackBar(content: Text(blocker)));
                        return;
                      }
                      _requestRecommendation(
                        context,
                        route: route!,
                        progress: progress!,
                        elapsedMinutes: sessionState.elapsed.inMinutes,
                        speedKmh: session!.currentSpeedMetersPerSecond * 3.6,
                        nextCheckpoint: nextCheckpoint,
                      );
                    },
              icon: coachState.isLoading
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.lightbulb_outline),
              label: Text(
                coachState.isLoading ? 'Menganalisis...' : 'Minta rekomendasi',
              ),
            ),
            if (route != null && progress != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Konteks yang dikirim hanya ringkasan rute, progres, durasi, kecepatan, '
                  'dan checkpoint berikutnya—bukan koordinat GPS.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
          ],
        ),
      ),
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

  Future<void> _requestRecommendation(
    BuildContext context, {
    required RouteRecord route,
    required RouteProgress progress,
    required int elapsedMinutes,
    required double speedKmh,
    required RouteCheckpoint? nextCheckpoint,
  }) async {
    final consent = await showDialog<bool>(
      context: context,
      builder: (context) => SenapathAlertDialog(
        title: const Text('Minta saran pelatih AI?'),
        content: const Text(
          'Ringkasan nama rute, persentase dan jarak tersisa, durasi, kecepatan, '
          'serta checkpoint berikutnya akan dikirim ke layanan AI untuk membuat rekomendasi. '
          'Koordinat GPS mentah tidak dikirim.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Setuju & minta saran'),
          ),
        ],
      ),
    );
    if (consent != true || !context.mounted) return;
    await context.read<RideCoachCubit>().recommend(
      consent: true,
      rideContext: {
        'routeName': route.name,
        'distanceRemainingKm': progress.distanceRemainingMeters / 1000,
        'progressPercent': progress.percent,
        'elapsedMinutes': elapsedMinutes,
        'speedKmh': speedKmh,
        'nextCheckpoint': nextCheckpoint?.name,
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
                    padding: const EdgeInsets.fromLTRB(16, 14, 12, 12),
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
                              'Papan peringkat mingguan',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(
                                    color: SenapathColors.white,
                                    fontWeight: FontWeight.w800,
                                  ),
                            ),
                          ),
                          TextButton(
                            onPressed: onOpen,
                            style: TextButton.styleFrom(
                              foregroundColor: SenapathColors.white,
                            ),
                            child: const Text('Lihat semua'),
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
                          ? 'Ikut tantangan mingguan dan lihat progres pesepeda lain.'
                          : 'Tantangan mingguan menunggu akun online. Kamu bisa '
                                'melihat detail dan pengaturan leaderboard.',
                      onOpen: onOpen,
                    )
                  else if (state.error != null)
                    _LeaderboardInvitation(
                      message: 'Peringkat belum bisa dimuat. Coba lagi nanti.',
                      onOpen: onOpen,
                    )
                  else if (state.entries.isEmpty)
                    _LeaderboardInvitation(
                      message:
                          'Belum ada skor pekan ini. Selesaikan sesi dan '
                          'mulai kumpulkan poinmu!',
                      onOpen: onOpen,
                    )
                  else ...[
                    Text(
                      'Pekan ini · ${state.category == LeaderboardCategory.distance ? 'jarak terjauh' : 'durasi aktif'}',
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(color: colors.onSurfaceVariant),
                    ),
                    const SizedBox(height: 8),
                    for (final entry in state.entries.take(3))
                      _LeaderboardPreviewRow(
                        rank: entry.rank,
                        alias: entry.alias,
                        score: _leaderboardScoreText(entry, state.category),
                      ),
                    const SizedBox(height: 4),
                    Text(
                      'Terus gowes, kejar posisi berikutnya!',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colors.primary,
                        fontWeight: FontWeight.w700,
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
  const _LeaderboardInvitation({required this.message, required this.onOpen});

  final String message;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(message),
      const SizedBox(height: 10),
      Align(
        alignment: AlignmentDirectional.centerStart,
        child: FilledButton.tonalIcon(
          key: const Key('home-shortcut-leaderboard'),
          onPressed: onOpen,
          icon: const Icon(Icons.emoji_events_outlined),
          label: const Text('Ikut tantangan'),
        ),
      ),
    ],
  );
}

class _LeaderboardPreviewRow extends StatelessWidget {
  const _LeaderboardPreviewRow({
    required this.rank,
    required this.alias,
    required this.score,
  });

  final int rank;
  final String alias;
  final String score;

  @override
  Widget build(BuildContext context) {
    final medalColor = switch (rank) {
      1 => const Color(0xFFB77900),
      2 => const Color(0xFF68727D),
      3 => const Color(0xFF9C5A36),
      _ => Theme.of(context).colorScheme.primary,
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: medalColor.withValues(alpha: 0.14),
            child: Text(
              '$rank',
              style: TextStyle(
                color: medalColor,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              alias,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Text(score, style: const TextStyle(fontWeight: FontWeight.w700)),
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
