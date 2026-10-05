import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/units/unit_settings_cubit.dart';
import '../../../core/units/unit_system.dart';
import '../../routes/presentation/explore_map.dart';
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
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<RideSessionCubit, RideSessionState>(
      builder: (context, state) {
        final colorScheme = Theme.of(context).colorScheme;
        final sessions = state.completedSessions;
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
              onExplore: () => context.go('/routes'),
              onStart: () => context.go('/session'),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Peta perjalanan',
                    style: Theme.of(context).textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
                TextButton.icon(
                  onPressed: () => context.go('/routes'),
                  icon: const Icon(Icons.open_in_new, size: 18),
                  label: const Text('Buka peta'),
                ),
              ],
            ),
            ExploreMap(height: 215, showLocationButton: true),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '7 hari terakhir',
                    style: Theme.of(context).textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
                TextButton(
                  onPressed: () => context.go('/session'),
                  child: const Text('Riwayat'),
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
            const SizedBox(height: 22),
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
                    onPressed: () => context.go('/session'),
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
                  onTap: () => context.go('/session'),
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
                    key: const Key('home-shortcut-leaderboard'),
                    icon: Icons.leaderboard_outlined,
                    title: 'Papan peringkat',
                    subtitle: 'Mingguan · opsional',
                    onTap: () => context.push('/leaderboard'),
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
  const _WelcomeCard({required this.onExplore, required this.onStart});

  final VoidCallback onExplore;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [colors.primary, colors.secondary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
      ),
      padding: const EdgeInsets.fromLTRB(20, 18, 14, 18),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'RIDE YOUR WAY',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: colors.onPrimary.withValues(alpha: 0.78),
                    letterSpacing: 1.4,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Rencanakan rute.\nNikmati perjalanan.',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: colors.onPrimary,
                    height: 1.15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton(
                      onPressed: onExplore,
                      style: FilledButton.styleFrom(
                        backgroundColor: colors.surface,
                        foregroundColor: colors.primary,
                      ),
                      child: const Text('Jelajahi'),
                    ),
                    OutlinedButton(
                      onPressed: onStart,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: colors.onPrimary,
                        side: BorderSide(
                          color: colors.onPrimary.withValues(alpha: 0.65),
                        ),
                      ),
                      child: const Text('Mulai sesi'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          Icon(
            Icons.directions_bike_rounded,
            color: colors.onPrimary.withValues(alpha: 0.2),
            size: 76,
          ),
        ],
      ),
    );
  }
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
    return Card(
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
    return Card(
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
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
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
                    value: session.syncStatus == 'synced'
                        ? 'Tersinkron'
                        : 'Lokal',
                    label: 'Penyimpanan',
                  ),
                ],
              ),
            ],
          ),
        ),
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
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
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
        ),
      ),
    );
  }
}
