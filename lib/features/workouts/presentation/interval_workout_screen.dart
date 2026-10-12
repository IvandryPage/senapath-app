import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../session/domain/ride_session.dart';
import '../../session/presentation/session_cubit.dart';
import '../domain/interval_workout.dart';
import 'interval_workout_cubit.dart';

class IntervalWorkoutScreen extends StatefulWidget {
  const IntervalWorkoutScreen({super.key});

  @override
  State<IntervalWorkoutScreen> createState() => _IntervalWorkoutScreenState();
}

class _IntervalWorkoutScreenState extends State<IntervalWorkoutScreen> {
  @override
  void initState() {
    super.initState();
    context.read<IntervalWorkoutCubit>().load();
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<RideSessionCubit>().state.session;
    final hasUnfinishedSession =
        session != null && session.status != RideSessionStatus.completed;
    return Scaffold(
      body: BlocBuilder<IntervalWorkoutCubit, IntervalWorkoutState>(
        builder: (context, state) {
          if (state.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
            children: [
              Text(
                'Buat rangkaian interval waktu atau jarak sesuai rencanamu. '
                'Workout tersimpan di perangkat dan tidak memberi resep '
                'intensitas.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              if (state.error != null) ...[
                const SizedBox(height: 12),
                Text(
                  state.error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: hasUnfinishedSession
                    ? null
                    : () => _createWorkout(context),
                icon: const Icon(Icons.add),
                label: const Text('Buat workout'),
              ),
              const SizedBox(height: 16),
              if (state.workouts.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(18),
                    child: Text('Belum ada workout interval tersimpan.'),
                  ),
                ),
              for (final workout in state.workouts)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                workout.name,
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                            ),
                            IconButton(
                              tooltip: 'Hapus workout',
                              onPressed: hasUnfinishedSession
                                  ? null
                                  : () => context
                                        .read<IntervalWorkoutCubit>()
                                        .remove(workout.id),
                              icon: const Icon(Icons.delete_outline),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        for (var index = 0;
                            index < workout.intervals.length;
                            index++)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 3),
                            child: Text(
                              '${index + 1}. ${workout.intervals[index].name} '
                              '· ${workout.intervals[index].targetDescription}'
                              '${workout.intervals[index].isRecovery ? ' · Pemulihan' : ''}',
                            ),
                          ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: state.selectedWorkoutId == workout.id
                              ? OutlinedButton.icon(
                                  onPressed: () async {
                                    await context
                                        .read<IntervalWorkoutCubit>()
                                        .select(null);
                                  },
                                  icon: const Icon(Icons.check_circle_outline),
                                  label: const Text('Workout dipilih · Hapus'),
                                )
                              : FilledButton.tonalIcon(
                                  onPressed: hasUnfinishedSession
                                      ? null
                                      : () async {
                                          await context
                                              .read<IntervalWorkoutCubit>()
                                              .select(workout.id);
                                          if (context.mounted) {
                                            context.pop();
                                          }
                                        },
                                  icon: const Icon(Icons.playlist_add_check),
                                  label: const Text('Pilih untuk sesi berikutnya'),
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _createWorkout(BuildContext context) async {
    final workout = await showDialog<IntervalWorkout>(
      context: context,
      builder: (_) => const _WorkoutEditorDialog(),
    );
    if (workout == null || !context.mounted) return;
    await context.read<IntervalWorkoutCubit>().save(workout);
  }
}

class _WorkoutEditorDialog extends StatefulWidget {
  const _WorkoutEditorDialog();

  @override
  State<_WorkoutEditorDialog> createState() => _WorkoutEditorDialogState();
}

class _WorkoutEditorDialogState extends State<_WorkoutEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final List<_IntervalDraft> _intervals = [_IntervalDraft()];
  bool _audioCueEnabled = true;
  bool _hapticCueEnabled = true;
  bool _visualCueEnabled = true;

  @override
  void dispose() {
    _nameController.dispose();
    for (final interval in _intervals) {
      interval.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Buat workout interval'),
      content: SizedBox(
        width: 520,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: _nameController,
                  maxLength: 60,
                  decoration: const InputDecoration(
                    labelText: 'Nama workout',
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Masukkan nama workout.'
                      : null,
                ),
                const SizedBox(height: 12),
                for (var index = 0; index < _intervals.length; index++)
                  _buildIntervalEditor(index),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: _intervals.length >= 30
                        ? null
                        : () => setState(() => _intervals.add(_IntervalDraft())),
                    icon: const Icon(Icons.add),
                    label: const Text('Tambah interval'),
                  ),
                ),
                const Divider(height: 24),
                Text(
                  'Cue saat interval berganti',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Suara'),
                  value: _audioCueEnabled,
                  onChanged: (value) =>
                      setState(() => _audioCueEnabled = value),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Getaran'),
                  value: _hapticCueEnabled,
                  onChanged: (value) =>
                      setState(() => _hapticCueEnabled = value),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Penanda visual'),
                  value: _visualCueEnabled,
                  onChanged: (value) =>
                      setState(() => _visualCueEnabled = value),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
        FilledButton(
          onPressed: _save,
          child: const Text('Simpan workout'),
        ),
      ],
    );
  }

  Widget _buildIntervalEditor(int index) {
    final draft = _intervals[index];
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Interval ${index + 1}',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                if (_intervals.length > 1)
                  IconButton(
                    tooltip: 'Hapus interval',
                    onPressed: () => setState(() {
                      _intervals.removeAt(index).dispose();
                    }),
                    icon: const Icon(Icons.remove_circle_outline),
                  ),
              ],
            ),
            TextFormField(
              controller: draft.nameController,
              maxLength: 40,
              decoration: const InputDecoration(labelText: 'Label'),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Masukkan label interval.'
                  : null,
            ),
            DropdownButtonFormField<WorkoutTargetType>(
              initialValue: draft.targetType,
              decoration: const InputDecoration(labelText: 'Jenis target'),
              items: const [
                DropdownMenuItem(
                  value: WorkoutTargetType.duration,
                  child: Text('Waktu (detik)'),
                ),
                DropdownMenuItem(
                  value: WorkoutTargetType.distance,
                  child: Text('Jarak (meter)'),
                ),
              ],
              onChanged: (value) {
                if (value != null) setState(() => draft.targetType = value);
              },
            ),
            TextFormField(
              controller: draft.targetController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: draft.targetType == WorkoutTargetType.duration
                    ? 'Durasi dalam detik'
                    : 'Jarak dalam meter',
              ),
              validator: (value) {
                final target = int.tryParse(value ?? '');
                final max = draft.targetType == WorkoutTargetType.duration
                    ? 86400
                    : 1000000;
                return target == null || target <= 0 || target > max
                    ? 'Masukkan angka 1–$max.'
                    : null;
              },
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Interval pemulihan'),
              value: draft.isRecovery,
              onChanged: (value) =>
                  setState(() => draft.isRecovery = value ?? false),
            ),
          ],
        ),
      ),
    );
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    try {
      final workout = IntervalWorkout.create(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        name: _nameController.text,
        intervals: _intervals
            .map(
              (draft) => WorkoutInterval.create(
                name: draft.nameController.text,
                targetType: draft.targetType,
                targetValue: int.parse(draft.targetController.text),
                isRecovery: draft.isRecovery,
              ),
            )
            .toList(growable: false),
        audioCueEnabled: _audioCueEnabled,
        hapticCueEnabled: _hapticCueEnabled,
        visualCueEnabled: _visualCueEnabled,
      );
      Navigator.pop(context, workout);
    } on ArgumentError catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Interval tidak valid: ${error.message}')),
      );
    }
  }
}

class _IntervalDraft {
  final nameController = TextEditingController();
  final targetController = TextEditingController();
  WorkoutTargetType targetType = WorkoutTargetType.duration;
  bool isRecovery = false;

  void dispose() {
    nameController.dispose();
    targetController.dispose();
  }
}
