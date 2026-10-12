import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../domain/leaderboard_models.dart';
import 'leaderboard_cubit.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  bool _loaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loaded) return;
    _loaded = true;
    context.read<LeaderboardCubit>().load();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<LeaderboardCubit, LeaderboardState>(
      listenWhen: (previous, current) =>
          previous.error != current.error ||
          previous.message != current.message,
      listener: (context, state) {
        final notice = state.error ?? state.message;
        if (notice != null) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(content: Text(notice)));
        }
      },
      child: BlocBuilder<LeaderboardCubit, LeaderboardState>(
        builder: (context, state) {
          final cubit = context.read<LeaderboardCubit>();
          final settings = state.settings;

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
            children: [
              Text(
                'Peringkat mingguan',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              Text(
                'Minggu berjalan · UTC',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('Durasi aktif'),
                    selected: state.category == LeaderboardCategory.duration,
                    onSelected: state.isLoading
                        ? null
                        : (_) => cubit.selectCategory(
                            LeaderboardCategory.duration,
                          ),
                  ),
                  ChoiceChip(
                    label: const Text('Jarak'),
                    selected: state.category == LeaderboardCategory.distance,
                    onSelected: state.isLoading
                        ? null
                        : (_) => cubit.selectCategory(
                            LeaderboardCategory.distance,
                          ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (state.isLoading)
                const Center(child: CircularProgressIndicator())
              else if (state.error != null)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(state.error!),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: cubit.load,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Coba lagi'),
                    ),
                  ],
                )
              else if (settings?.isOptedIn != true)
                const Text(
                  'Partisipasi belum aktif. Atur partisipasi di Profil > Pengaturan.',
                )
              else if (state.entries.isEmpty)
                const Text(
                  'Belum ada skor yang dikirim untuk kategori ini minggu ini.',
                )
              else ...[
                _LeaderboardTopThree(
                  entries: state.entries.take(3).toList(growable: false),
                  category: state.category,
                  formatScore: _formatScore,
                ),
                for (final entry in state.entries.skip(3))
                  Card(
                    margin: const EdgeInsets.only(top: 8),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerHighest,
                        child: Text(
                          '${entry.rank}',
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                      title: Text('${entry.alias} · Lv.${entry.riderLevel}'),
                      subtitle: Text(
                        '${entry.riderStyle.label} · ${entry.riderExperience} XP',
                      ),
                      trailing: Text(_formatScore(entry, state.category)),
                    ),
                  ),
              ],
            ],
          );
        },
      ),
    );
  }

  String _formatScore(LeaderboardEntry entry, LeaderboardCategory category) {
    if (category == LeaderboardCategory.distance) {
      return '${(entry.score / 1000).toStringAsFixed(1)} km';
    }
    final seconds = entry.score.round();
    final hours = seconds ~/ 3600;
    final minutes = seconds % 3600 ~/ 60;
    return hours > 0 ? '${hours}j ${minutes}m' : '${minutes}m ${seconds % 60}d';
  }
}

class _LeaderboardTopThree extends StatelessWidget {
  const _LeaderboardTopThree({
    required this.entries,
    required this.category,
    required this.formatScore,
  });

  final List<LeaderboardEntry> entries;
  final LeaderboardCategory category;
  final String Function(LeaderboardEntry, LeaderboardCategory) formatScore;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      children: [
        for (final entry in entries)
          Card(
            margin: const EdgeInsets.only(bottom: 8),
            color: switch (entry.rank) {
              1 => const Color(0xFFFFF5D6),
              2 => const Color(0xFFF0F2F4),
              3 => const Color(0xFFF8EAE2),
              _ => colors.surface,
            },
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: switch (entry.rank) {
                  1 => const Color(0xFFFFE8A3),
                  2 => const Color(0xFFDCE1E5),
                  3 => const Color(0xFFE8C3AD),
                  _ => colors.surfaceContainerHighest,
                },
                child: Icon(
                  entry.rank == 1
                      ? Icons.emoji_events_rounded
                      : Icons.directions_bike_outlined,
                  color: switch (entry.rank) {
                    1 => const Color(0xFFB77900),
                    2 => const Color(0xFF68727D),
                    3 => const Color(0xFF9C5A36),
                    _ => colors.primary,
                  },
                ),
              ),
              title: Text(
                '${entry.rank} · ${entry.alias}',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              subtitle: Text(
                'Lv.${entry.riderLevel} · ${entry.riderStyle.label}',
              ),
              trailing: Text(
                formatScore(entry, category),
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ),
      ],
    );
  }
}
