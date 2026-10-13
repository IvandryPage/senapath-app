import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/senapath_design.dart';
import '../domain/rider_progress.dart';
import 'rider_gamification_cubit.dart';

class RiderScreen extends StatelessWidget {
  const RiderScreen({super.key});

  @override
  Widget build(
    BuildContext context,
  ) => BlocConsumer<RiderGamificationCubit, RiderGamificationState>(
    listenWhen: (previous, current) => current.error != null,
    listener: (context, state) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(state.error!)));
    },
    builder: (context, state) {
      final progress = state.progress;
      if (progress == null) {
        return const Center(child: CircularProgressIndicator());
      }
      final achievements = progress.achievements;
      final unlockedAchievements = achievements
          .where((achievement) => achievement.isUnlocked)
          .length;
      return ListView(
        padding: const EdgeInsets.all(20),
        children: [
          SenapathCard(
            color: SenapathColors.navy,
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: SenapathColors.white.withValues(
                        alpha: 0.14,
                      ),
                      child: const Icon(
                        Icons.emoji_events_outlined,
                        color: SenapathColors.white,
                        size: 30,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            progress.rank.title.toUpperCase(),
                            style: Theme.of(context).textTheme.labelLarge
                                ?.copyWith(
                                  color: SenapathColors.white.withValues(
                                    alpha: 0.75,
                                  ),
                                  letterSpacing: 1.2,
                                ),
                          ),
                          Text(
                            'Level pesepeda ${progress.level}',
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(
                                  color: SenapathColors.white,
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                          Text(
                            progress.rank.levelRange,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: SenapathColors.white.withValues(
                                    alpha: 0.75,
                                  ),
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                LinearProgressIndicator(
                  value: progress.levelProgress,
                  minHeight: 10,
                  borderRadius: BorderRadius.circular(8),
                  backgroundColor: SenapathColors.white.withValues(alpha: 0.25),
                  color: SenapathColors.accent,
                ),
                const SizedBox(height: 8),
                Text(
                  '${progress.experience % RiderProgress.experiencePerLevel} / '
                  '${RiderProgress.experiencePerLevel} poin · '
                  '${progress.experienceToNextLevel} poin lagi ke level berikutnya',
                  style: TextStyle(
                    color: SenapathColors.white.withValues(alpha: 0.9),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SenapathCard(
            margin: EdgeInsets.zero,
            padding: EdgeInsets.zero,
            child: ListTile(
              leading: const Icon(Icons.verified_user_outlined),
              title: const Text('Bukti perjalanan'),
              subtitle: const Text('Lihat kode bukti dan periksa datanya.'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/rider/ledger'),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Pencapaian · $unlockedAchievements/${achievements.length}',
            style: Theme.of(context).textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            'Selesaikan tantangan gowes untuk membuka badge baru.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 10),
          for (final achievement in achievements)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _AchievementCard(achievement: achievement),
            ),
        ],
      );
    },
  );
}

class _AchievementCard extends StatelessWidget {
  const _AchievementCard({required this.achievement});

  final RiderAchievement achievement;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final icon = switch (achievement.icon) {
      RiderAchievementIcon.consistency => Icons.repeat,
      RiderAchievementIcon.distance => Icons.route_outlined,
      RiderAchievementIcon.rank => Icons.emoji_events_outlined,
      RiderAchievementIcon.duration => Icons.timer_outlined,
      RiderAchievementIcon.longRide => Icons.flag_outlined,
      RiderAchievementIcon.weekend => Icons.weekend_outlined,
    };
    final progressText = achievement.unit.isEmpty
        ? '${achievement.progress.clamp(0, achievement.target)} / ${achievement.target}'
        : '${achievement.progress.clamp(0, achievement.target)} / ${achievement.target} ${achievement.unit}';

    return SenapathCard(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundColor: achievement.isUnlocked
                  ? colors.primaryContainer
                  : colors.surfaceContainerHighest,
              foregroundColor: achievement.isUnlocked
                  ? colors.onPrimaryContainer
                  : colors.onSurfaceVariant,
              child: Icon(icon),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          achievement.title,
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                      if (achievement.isUnlocked)
                        Icon(
                          Icons.check_circle,
                          color: colors.primary,
                          size: 20,
                        ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    achievement.description,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: achievement.progressFraction,
                    minHeight: 6,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    achievement.isUnlocked ? 'Diraih' : progressText,
                    style: Theme.of(context).textTheme.labelSmall
                        ?.copyWith(color: colors.onSurfaceVariant),
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
