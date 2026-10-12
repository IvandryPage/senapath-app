import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
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
  ProgressPeriod _selectedPeriod = ProgressPeriod.week;

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
        final goals = context.watch<ActivityGoalsCubit>().state.goals;
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
            SegmentedButton<ProgressPeriod>(
              segments: const [
                ButtonSegment(
                  value: ProgressPeriod.week,
                  label: Text('Minggu ini'),
                ),
                ButtonSegment(
                  value: ProgressPeriod.month,
                  label: Text('Bulan ini'),
                ),
              ],
              selected: {_selectedPeriod},
              onSelectionChanged: (selection) =>
                  setState(() => _selectedPeriod = selection.first),
              showSelectedIcon: false,
            ),
            const SizedBox(height: 12),
            _ProgressPeriodCard(
              title: _selectedPeriod == ProgressPeriod.week
                  ? 'Minggu ini'
                  : 'Bulan ini',
              progress: _selectedPeriod == ProgressPeriod.week ? week : month,
              previousProgress: _selectedPeriod == ProgressPeriod.week
                  ? previousWeek
                  : previousMonth,
              sessions: rideState.completedSessions,
              goals: goals
                  .where((goal) => goal.period == _selectedPeriod)
                  .toList(growable: false),
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
                      subtitle: Text(
                        'Buat target mingguan atau bulanan sendiri.',
                      ),
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
                        onDelete: () =>
                            context.read<ActivityGoalsCubit>().remove(goal.id),
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

  Future<void> _editGoal(BuildContext context, [ActivityGoal? existing]) async {
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
    required this.sessions,
    required this.goals,
  });

  final String title;
  final ActivityProgress progress;
  final ActivityProgress previousProgress;
  final List<RideSessionSnapshot> sessions;
  final List<ActivityGoal> goals;

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
    final periodLabel =
        '${DateFormat('d MMM').format(progress.startsAt)} – '
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
            _PeriodDistanceChart(
              progress: progress,
              sessions: sessions,
              unit: unit,
            ),
            const SizedBox(height: 16),
            Text(
              'Target & progres',
              style: Theme.of(context).textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            if (goals.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Belum ada target untuk periode ini. Buat target di bagian Target pribadi.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              )
            else
              for (final goal in goals)
                _GameGoalProgressBar(goal: goal, progress: progress),
            const SizedBox(height: 12),
            _Comparison(
              current: progress,
              previous: previousProgress,
              unit: unit,
            ),
          ],
        ),
      ),
    );
  }
}

class _PeriodDistanceChart extends StatelessWidget {
  const _PeriodDistanceChart({
    required this.progress,
    required this.sessions,
    required this.unit,
  });

  final ActivityProgress progress;
  final List<RideSessionSnapshot> sessions;
  final UnitSystem unit;

  @override
  Widget build(BuildContext context) {
    final bucketCount = progress.period == ProgressPeriod.week ? 7 : 5;
    final values = List<double>.filled(bucketCount, 0);
    final sessionsById = {
      for (final session in sessions) session.id: session,
    };
    for (final id in progress.sessionIds) {
      final session = sessionsById[id];
      if (session == null) continue;
      final startedAt = session.startedAt.toLocal();
      final index = progress.period == ProgressPeriod.week
          ? startedAt.weekday - DateTime.monday
          : (startedAt.day - 1) ~/ 7;
      values[index.clamp(0, bucketCount - 1)] += session.distanceMeters;
    }

    final maximum = values.fold<double>(
      0,
      (current, value) => value > current ? value : current,
    );
    final divisor = unit == UnitSystem.metric ? 1000.0 : 1609.344;
    final labels = progress.period == ProgressPeriod.week
        ? const ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min']
        : const ['P1', 'P2', 'P3', 'P4', 'P5'];
    final colors = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          progress.period == ProgressPeriod.week
              ? 'Jarak per hari'
              : 'Jarak per pekan',
          style: Theme.of(context).textTheme.labelLarge,
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 126,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var index = 0; index < bucketCount; index++)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          values[index] == 0
                              ? '–'
                              : (values[index] / divisor).toStringAsFixed(1),
                          maxLines: 1,
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(color: colors.onSurfaceVariant),
                        ),
                        const SizedBox(height: 4),
                        Expanded(
                          child: Align(
                            alignment: Alignment.bottomCenter,
                            child: FractionallySizedBox(
                              heightFactor: maximum == 0
                                  ? 0.04
                                  : (values[index] / maximum)
                                        .clamp(0.04, 1)
                                        .toDouble(),
                              child: Container(
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  color: values[index] == 0
                                      ? colors.surfaceContainerHighest
                                      : colors.primary,
                                  borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(6),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          labels[index],
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _GameGoalProgressBar extends StatelessWidget {
  const _GameGoalProgressBar({required this.goal, required this.progress});

  final ActivityGoal goal;
  final ActivityProgress progress;

  @override
  Widget build(BuildContext context) {
    final unit = context.watch<UnitSettingsCubit>().state.unitSystem;
    final current = progress.valueFor(goal.metric);
    final fraction = progress.progressFor(goal);
    final remaining = (goal.target - current).clamp(0, goal.target).toDouble();
    final completed = current >= goal.target;
    final elapsed = DateTime.now().difference(progress.startsAt).inSeconds;
    final periodLength = progress.endsAt
        .difference(progress.startsAt)
        .inSeconds;
    final expectedFraction = periodLength <= 0
        ? 1.0
        : (elapsed / periodLength).clamp(0, 1).toDouble();
    final onTrack = completed || fraction >= expectedFraction;
    final status = completed
        ? 'TARGET TERCAPAI'
        : onTrack
        ? 'ON TRACK · SISA ${_formatGoalValue(remaining, goal.metric, unit)}'
        : 'AYO TAMBAH KAYUHAN · SISA ${_formatGoalValue(remaining, goal.metric, unit)}';
    final color = completed
        ? Theme.of(context).colorScheme.primary
        : onTrack
        ? Theme.of(context).colorScheme.secondary
        : Theme.of(context).colorScheme.tertiary;

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _goalLabel(goal.metric),
                  style: Theme.of(context).textTheme.labelLarge
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              Text(
                '${_formatGoalValue(current, goal.metric, unit)} / '
                '${_formatGoalValue(goal.target, goal.metric, unit)}',
                style: Theme.of(context).textTheme.labelMedium,
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: fraction,
              minHeight: 11,
              color: color,
              backgroundColor: Theme.of(context)
                  .colorScheme
                  .surfaceContainerHighest,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            status,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.25,
            ),
          ),
        ],
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
    final distanceDifference = current.distanceMeters - previous.distanceMeters;
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
      GoalMetric.distanceMeters =>
        unit == UnitSystem.metric
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
              id:
                  widget.existing?.id ??
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

String _formatGoalValue(double value, GoalMetric metric, UnitSystem unit) =>
    switch (metric) {
      GoalMetric.completedSessions => '${value.toStringAsFixed(0)} sesi',
      GoalMetric.distanceMeters => unit == UnitSystem.metric
          ? '${(value / 1000).toStringAsFixed(1)} km'
          : '${(value / 1609.344).toStringAsFixed(1)} mi',
      GoalMetric.activeSeconds => '${(value / 3600).toStringAsFixed(1)} jam',
    };

String _targetLabel(GoalMetric metric) => switch (metric) {
  GoalMetric.completedSessions => 'Target sesi',
  GoalMetric.distanceMeters => 'Target jarak (km)',
  GoalMetric.activeSeconds => 'Target durasi (jam)',
};
