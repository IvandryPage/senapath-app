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
    unawaited(context.read<RideSessionCubit>().initialize());
    unawaited(context.read<LeaderboardCubit>().load());
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<RideSessionCubit, RideSessionState>(
      builder: (context, state) {
        final colorScheme = Theme.of(context).colorScheme;
        final sessions = state.completedSessions;
        final activeSession =
            state.session != null &&
            state.session!.status != RideSessionStatus.completed;
        final now = DateTime.now();
        final weekSessions = sessions.where(
          (session) =>
              session.startedAt.isAfter(now.subtract(const Duration(days: 7))),
        );
        final weekDistance = weekSessions.fold<double>(
          0,
          (total, session) => total + session.distanceMeters,
        );

        return ListView(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _formatLongDate(now),
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Hai, siap gowes?',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                ),
                Material(
                  color: colorScheme.surface,
                  shape: const CircleBorder(),
                  child: IconButton(
                    tooltip: 'Profil',
                    onPressed: () => context.go('/profile'),
                    icon: const Icon(Icons.person_outline),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _WelcomeCard(
              title: activeSession ? 'RIDE IN PROGRESS' : 'READY TO RIDE',
              startLabel: activeSession ? 'Lanjutkan sesi' : 'Mulai sesi',
              onExplore: () => context.go('/routes'),
              onStart: () => context.go('/routes'),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Ringkasan 7 hari',
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
                    value: _formatDistance(weekDistance),
                    label: 'Jarak total',
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
                  onTap: () => context.push('/profile/sessions/${session.id}'),
                ),
            const SizedBox(height: 18),
            Text(
              'Untuk perjalananmu',
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _FeatureShortcut(
                    key: const Key('home-shortcut-strategy'),
                    icon: Icons.flash_on_outlined,
                    title: 'Strategi rute',
                    subtitle: 'Latihan singkat',
                    onTap: () => context.push('/strategy'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _FeatureShortcut(
                    icon: Icons.map_outlined,
                    title: 'Jelajah rute',
                    subtitle: 'Peta & sesi',
                    onTap: () => context.go('/routes'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _FeatureShortcut(
                    key: const Key('home-shortcut-ai'),
                    icon: Icons.auto_awesome_outlined,
                    title: 'Chat AI',
                    subtitle: 'Tanya asisten',
                    onTap: () => context.push('/assistant'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _FeatureShortcut(
                    key: const Key('home-shortcut-feedback'),
                    icon: Icons.feedback_outlined,
                    title: 'Saran & kesan',
                    subtitle: 'Kirim masukan',
                    onTap: () => context.push('/feedback'),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  String _formatDistance(double meters) => meters >= 1000
      ? '${(meters / 1000).toStringAsFixed(1)} km'
      : '${meters.toStringAsFixed(0)} m';

  String _formatLongDate(DateTime date) {
    const weekdays = [
      'Senin',
      'Selasa',
      'Rabu',
      'Kamis',
      'Jumat',
      'Sabtu',
      'Minggu',
    ];
    const months = [
      'Januari',
      'Februari',
      'Maret',
      'April',
      'Mei',
      'Juni',
      'Juli',
      'Agustus',
      'September',
      'Oktober',
      'November',
      'Desember',
    ];
    return '${weekdays[date.weekday - 1]}, ${date.day} ${months[date.month - 1]}';
  }
}

class _WelcomeCard extends StatelessWidget {
  const _WelcomeCard({
    required this.title,
    required this.startLabel,
    required this.onExplore,
    required this.onStart,
  });

  final String title;
  final String startLabel;
  final VoidCallback onExplore;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    return SenapathCard(
      padding: const EdgeInsets.fromLTRB(20, 18, 14, 18),
      color: SenapathColors.indigo,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'RIDE YOUR WAY',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: SenapathColors.white.withValues(alpha: 0.82),
                    letterSpacing: 1.4,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: SenapathColors.white,
                    height: 1.15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    SenapathButton(
                      fullWidth: false,
                      onPressed: onStart,
                      icon: Icons.play_arrow,
                      label: startLabel,
                    ),
                    OutlinedButton(
                      onPressed: onExplore,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: SenapathColors.white,
                        side: const BorderSide(
                          color: SenapathColors.white,
                          width: 2,
                        ),
                      ),
                      child: const Text('Jelajahi'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          Icon(
            Icons.directions_bike_rounded,
            color: SenapathColors.sky,
            size: 76,
          ),
        ],
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
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.emoji_events_outlined, color: colors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Papan peringkat mingguan',
                    style: Theme.of(context).textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
                TextButton(onPressed: onOpen, child: const Text('Lihat semua')),
              ],
            ),
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

class _FeatureShortcut extends StatelessWidget {
  const _FeatureShortcut({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SenapathCard(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: colors.secondaryContainer,
            child: Icon(icon, size: 19, color: colors.primary),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelLarge
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
