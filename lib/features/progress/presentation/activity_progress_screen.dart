import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/senapath_design.dart';
import '../../../core/units/unit_settings_cubit.dart';
import '../../../core/units/unit_system.dart';
import '../../session/domain/ride_session.dart';
import '../../session/presentation/session_cubit.dart';
import '../domain/activity_progress.dart';
import 'activity_goals_cubit.dart';

class ActivityProgressScreen extends StatefulWidget {
  const ActivityProgressScreen({super.key});

  @override
  State<ActivityProgressScreen> createState() => _ActivityProgressScreenState();
}

class _ActivityProgressScreenState extends State<ActivityProgressScreen> {
  static const _calculator = ActivityProgressCalculator();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    unawaited(context.read<ActivityGoalsCubit>().load());
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<RideSessionCubit, RideSessionState>(
      builder: (context, rideState) {
        final now = DateTime.now();
        final week = _calculator.calculate(
          rideState.completedSessions,
          now: now,
          period: ProgressPeriod.week,
        );
        final previousWeek = _calculator.calculate(
          rideState.completedSessions,
          now: now,
          period: ProgressPeriod.week,
          previousPeriod: true,
        );
        final month = _calculator.calculate(
          rideState.completedSessions,
          now: now,
          period: ProgressPeriod.month,
        );
        final previousMonth = _calculator.calculate(
          rideState.completedSessions,
          now: now,
          period: ProgressPeriod.month,
          previousPeriod: true,
        );
        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          children: [
            Text(
              'PROGRES BERDASARKAN SESI SELESAI',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 4),
            Text(
              'Angka hanya berasal dari aktivitas lokal yang tercatat pada periode ini.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            _ProgressPeriodCard(
              title: 'Minggu ini',
              progress: week,
              previousProgress: previousWeek,
              sourceSessions: rideState.completedSessions,
            ),
            const SizedBox(height: 12),
            _ProgressPeriodCard(
              title: 'Bulan ini',
              progress: month,
              previousProgress: previousMonth,
              sourceSessions: rideState.completedSessions,
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Target pribadi',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                IconButton.filled(
                  tooltip: 'Tambah target',
                  onPressed: () => _editGoal(context),
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
            Text(
              'Target pilihanmu, bukan resep latihan.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            BlocBuilder<ActivityGoalsCubit, ActivityGoalsState>(
              builder: (context, state) {
                if (state.isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (state.error != null) {
                  return SenapathCard(
                    child: ListTile(
                      leading: const Icon(Icons.error_outline),
                      title: Text(state.error!),
                      trailing: IconButton(
                        tooltip: 'Coba lagi',
                        onPressed: context.read<ActivityGoalsCubit>().load,
                        icon: const Icon(Icons.refresh),
                      ),
                    ),
                  );
                }
                if (state.goals.isEmpty) {
                  return const SenapathCard(
                    child: ListTile(
                      leading: Icon(Icons.flag_outlined),
                      title: Text('Belum ada target'),
                      subtitle: Text('Buat target mingguan atau bulanan sendiri.'),
                    ),
                  );
                }
                return Column(
                  children: [
                    for (final goal in state.goals)
                      _GoalCard(
                        goal: goal,
                        progress: goal.period == ProgressPeriod.week
                            ? week
                            : month,
                        isSaving: state.isSaving,
                        onEdit: () => _editGoal(context, goal),
                        onDelete: () => context
                            .read<ActivityGoalsCubit>()
                            .remove(goal.id),
                      ),
                  ],
                );
              },
            ),
            if (rideState.isLoading)
              const Padding(
                padding: EdgeInsets.all(20),
                child: Center(child: CircularProgressIndicator()),
              ),
          ],
        );
      },
    );
  }

  Future<void> _editGoal(
    BuildContext context, [
    ActivityGoal? existing,
  ]) async {
    final goal = await showDialog<ActivityGoal>(
      context: context,
      builder: (_) => _GoalDialog(existing: existing),
    );
    if (goal != null && context.mounted) {
      await context.read<ActivityGoalsCubit>().upsert(goal);
    }
  }
}

class _ProgressPeriodCard extends StatelessWidget {
  const _ProgressPeriodCard({
    required this.title,
    required this.progress,
    required this.previousProgress,
    required this.sourceSessions,
  });

  final String title;
  final ActivityProgress progress;
  final ActivityProgress previousProgress;
  final List<RideSessionSnapshot> sourceSessions;

  @override
  Widget build(BuildContext context) {
    final unit = context.watch<UnitSettingsCubit>().state.unitSystem;
    final distance = unit == UnitSystem.metric
        ? '${(progress.distanceMeters / 1000).toStringAsFixed(1)} km'
        : '${(progress.distanceMeters / 1609.344).toStringAsFixed(1)} mi';
    final duration = Duration(seconds: progress.activeSeconds);
    final durationText = duration.inHours > 0
        ? '${duration.inHours}j ${duration.inMinutes.remainder(60)}m'
        : '${duration.inMinutes}m';
    final sessionsById = {
      for (final session in sourceSessions) session.id: session,
    };
    final periodLabel = '${DateFormat('d MMM').format(progress.startsAt)} – '
        '${DateFormat('d MMM').format(progress.endsAt.subtract(const Duration(days: 1)))}';
    return SenapathCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            Text(periodLabel, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 12),
            Wrap(
              spacing: 18,
              runSpacing: 12,
              children: [
                _Value(label: 'Sesi', value: '${progress.completedSessions}'),
                _Value(label: 'Jarak', value: distance),
                _Value(label: 'Durasi aktif', value: durationText),
              ],
            ),
            const SizedBox(height: 12),
            _Comparison(
              current: progress,
              previous: previousProgress,
              unit: unit,
            ),
            const Divider(height: 24),
            Text(
              'Sumber: ${progress.sessionIds.length} sesi selesai',
              style: Theme.of(context).textTheme.labelMedium,
            ),
            if (progress.sessionIds.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 6),
                child: Text('Belum ada aktivitas selesai pada periode ini.'),
              )
            else
              for (final id in progress.sessionIds)
                if (sessionsById[id] case final session?)
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      'Sesi bersepeda',
                    ),
                    subtitle: Text(
                      DateFormat('d MMM yyyy · HH:mm')
                          .format(session.startedAt.toLocal()),
                    ),
                    trailing: const Icon(Icons.open_in_new, size: 18),
                    onTap: () => context.push('/profile/sessions/$id'),
                  ),
          ],
        ),
      ),
    );
  }
}

class _Comparison extends StatelessWidget {
  const _Comparison({
    required this.current,
    required this.previous,
    required this.unit,
  });

  final ActivityProgress current;
  final ActivityProgress previous;
  final UnitSystem unit;

  @override
  Widget build(BuildContext context) {
    final distanceDifference =
        current.distanceMeters - previous.distanceMeters;
    final distance = unit == UnitSystem.metric
        ? distanceDifference / 1000
        : distanceDifference / 1609.344;
    final durationDifference = current.activeSeconds - previous.activeSeconds;
    final durationSign = durationDifference > 0 ? '+' : '';
    final durationMinutes = (durationDifference / 60).round();
    final distanceSign = distance > 0 ? '+' : '';
    final distanceUnit = unit == UnitSystem.metric ? 'km' : 'mi';
    return Text(
      'Dibanding periode sebelumnya: '
      '${current.completedSessions - previous.completedSessions >= 0 ? '+' : ''}'
      '${current.completedSessions - previous.completedSessions} sesi · '
      '$distanceSign${distance.toStringAsFixed(1)} $distanceUnit · '
      '$durationSign$durationMinutes menit aktif',
      style: Theme.of(context).textTheme.bodySmall,
    );
  }
}

class _Value extends StatelessWidget {
  const _Value({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(value, style: Theme.of(context).textTheme.titleLarge),
      Text(label, style: Theme.of(context).textTheme.bodySmall),
    ],
  );
}

class _GoalCard extends StatelessWidget {
  const _GoalCard({
    required this.goal,
    required this.progress,
    required this.isSaving,
    required this.onEdit,
    required this.onDelete,
  });

  final ActivityGoal goal;
  final ActivityProgress progress;
  final bool isSaving;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final current = progress.valueFor(goal.metric);
    final target = goal.target;
    final unit = context.watch<UnitSettingsCubit>().state.unitSystem;
    final displayValue = switch (goal.metric) {
      GoalMetric.completedSessions =>
        '${current.toStringAsFixed(0)} / ${target.toStringAsFixed(0)} sesi',
      GoalMetric.distanceMeters => unit == UnitSystem.metric
          ? '${(current / 1000).toStringAsFixed(1)} / ${(target / 1000).toStringAsFixed(1)} km'
          : '${(current / 1609.344).toStringAsFixed(1)} / ${(target / 1609.344).toStringAsFixed(1)} mi',
      GoalMetric.activeSeconds =>
        '${(current / 3600).toStringAsFixed(1)} / ${(target / 3600).toStringAsFixed(1)} jam',
    };
    return SenapathCard(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${_goalLabel(goal.metric)} · ${goal.period == ProgressPeriod.week ? 'Mingguan' : 'Bulanan'}',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                IconButton(
                  tooltip: 'Edit target',
                  onPressed: isSaving ? null : onEdit,
                  icon: const Icon(Icons.edit_outlined),
                ),
                IconButton(
                  tooltip: 'Hapus target',
                  onPressed: isSaving ? null : onDelete,
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
            Text(displayValue),
            const SizedBox(height: 8),
            LinearProgressIndicator(value: progress.progressFor(goal)),
          ],
        ),
      ),
    );
  }
}

class _GoalDialog extends StatefulWidget {
  const _GoalDialog({this.existing});

  final ActivityGoal? existing;

  @override
  State<_GoalDialog> createState() => _GoalDialogState();
}

class _GoalDialogState extends State<_GoalDialog> {
  final _formKey = GlobalKey<FormState>();
  late GoalMetric _metric;
  late ProgressPeriod _period;
  late final TextEditingController _target;

  @override
  void initState() {
    super.initState();
    _metric = widget.existing?.metric ?? GoalMetric.completedSessions;
    _period = widget.existing?.period ?? ProgressPeriod.week;
    final initialTarget = widget.existing?.target;
    _target = TextEditingController(
      text: initialTarget == null ? '' : _formatTarget(initialTarget, _metric),
    );
  }

  @override
  void dispose() {
    _target.dispose();
    super.dispose();
  }

  double? _targetValue() {
    final value = double.tryParse(_target.text.trim().replaceAll(',', '.'));
    if (value == null || !value.isFinite || value <= 0) return null;
    return switch (_metric) {
      GoalMetric.completedSessions => value,
      GoalMetric.distanceMeters => value * 1000,
      GoalMetric.activeSeconds => value * 3600,
    };
  }

  String _formatTarget(double value, GoalMetric metric) => switch (metric) {
    GoalMetric.completedSessions => value.toStringAsFixed(0),
    GoalMetric.distanceMeters => (value / 1000).toStringAsFixed(1),
    GoalMetric.activeSeconds => (value / 3600).toStringAsFixed(1),
  };

  @override
  Widget build(BuildContext context) => SenapathAlertDialog(
    title: Text(widget.existing == null ? 'Buat target' : 'Ubah target'),
    content: Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<GoalMetric>(
            initialValue: _metric,
            decoration: const InputDecoration(labelText: 'Metrik'),
            items: [
              for (final metric in GoalMetric.values)
                DropdownMenuItem(
                  value: metric,
                  child: Text(_goalLabel(metric)),
                ),
            ],
            onChanged: (value) {
              if (value != null) setState(() => _metric = value);
            },
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<ProgressPeriod>(
            initialValue: _period,
            decoration: const InputDecoration(labelText: 'Periode'),
            items: const [
              DropdownMenuItem(
                value: ProgressPeriod.week,
                child: Text('Mingguan'),
              ),
              DropdownMenuItem(
                value: ProgressPeriod.month,
                child: Text('Bulanan'),
              ),
            ],
            onChanged: (value) {
              if (value != null) setState(() => _period = value);
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _target,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(labelText: _targetLabel(_metric)),
            validator: (_) => _targetValue() == null
                ? 'Masukkan target yang lebih besar dari nol.'
                : null,
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Batal'),
      ),
      FilledButton(
        onPressed: () {
          if (!_formKey.currentState!.validate()) return;
          Navigator.pop(
            context,
            ActivityGoal(
              id: widget.existing?.id ??
                  DateTime.now().microsecondsSinceEpoch.toString(),
              metric: _metric,
              target: _targetValue()!,
              period: _period,
            ),
          );
        },
        child: const Text('Simpan'),
      ),
    ],
  );
}

String _goalLabel(GoalMetric metric) => switch (metric) {
  GoalMetric.completedSessions => 'Jumlah sesi',
  GoalMetric.distanceMeters => 'Jarak',
  GoalMetric.activeSeconds => 'Durasi aktif',
};

String _targetLabel(GoalMetric metric) => switch (metric) {
  GoalMetric.completedSessions => 'Target sesi',
  GoalMetric.distanceMeters => 'Target jarak (km)',
  GoalMetric.activeSeconds => 'Target durasi (jam)',
};
