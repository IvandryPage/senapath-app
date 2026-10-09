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
      final colors = Theme.of(context).colorScheme;
      return ListView(
        padding: const EdgeInsets.all(20),
        children: [
          SenapathCard(
            color: SenapathColors.indigo,
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: SenapathColors.gold,
                      child: Icon(
                        _styleIcon(progress.style),
                        color: SenapathColors.ink,
                        size: 30,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            progress.style.label.toUpperCase(),
                            style: Theme.of(context).textTheme.labelLarge
                                ?.copyWith(
                                  color: SenapathColors.white.withValues(
                                    alpha: 0.75,
                                  ),
                                  letterSpacing: 1.2,
                                ),
                          ),
                          Text(
                            'Level ${progress.level}',
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(
                                  color: SenapathColors.white,
                                  fontWeight: FontWeight.w800,
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
                  color: SenapathColors.gold,
                ),
                const SizedBox(height: 8),
                Text(
                  '${progress.experience % RiderProgress.experiencePerLevel} / '
                  '${RiderProgress.experiencePerLevel} XP · '
                  '${progress.experienceToNextLevel} XP ke level berikutnya',
                  style: TextStyle(
                    color: SenapathColors.white.withValues(alpha: 0.9),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  label: 'Total jarak',
                  value:
                      '${(progress.distanceMeters / 1000).toStringAsFixed(1)} km',
                  icon: Icons.route_outlined,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  label: 'Sesi selesai',
                  value: '${progress.completedRides}',
                  icon: Icons.directions_bike_outlined,
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Text(
            'Pilih gaya rider',
            style: Theme.of(context).textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          RadioGroup<RiderStyle>(
            groupValue: progress.style,
            onChanged: (value) {
              if (!state.isSaving && value != null) {
                context.read<RiderGamificationCubit>().setStyle(value);
              }
            },
            child: Column(
              children: [
                for (final style in RiderStyle.values)
                  RadioListTile<RiderStyle>(
                    value: style,
                    secondary: Icon(_styleIcon(style), color: colors.primary),
                    title: Text(style.label),
                    subtitle: Text(style.description),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
              ],
            ),
          ),
          if (state.isSaving) const LinearProgressIndicator(),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => context.push('/rider/ledger'),
            icon: const Icon(Icons.link),
            label: const Text('Bukti perjalanan'),
          ),
          const SizedBox(height: 8),
          const Text(
            'XP dihitung dari jarak dan durasi sesi yang selesai. Progres disimpan di perangkat.',
          ),
        ],
      );
    },
  );

  IconData _styleIcon(RiderStyle style) => switch (style) {
    RiderStyle.sprinter => Icons.bolt,
    RiderStyle.climber => Icons.terrain,
    RiderStyle.explorer => Icons.explore,
  };
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) => SenapathCard(
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: Theme.of(context).colorScheme.primary),
        const SizedBox(height: 12),
        Text(value, style: Theme.of(context).textTheme.titleLarge),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    ),
  );
}
