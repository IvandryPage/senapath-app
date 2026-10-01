import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../domain/reaction_test_result.dart';
import 'reaction_test_cubit.dart';

class ReactionTestScreen extends StatefulWidget {
  const ReactionTestScreen({super.key});

  @override
  State<ReactionTestScreen> createState() => _ReactionTestScreenState();
}

class _ReactionTestScreenState extends State<ReactionTestScreen>
    with WidgetsBindingObserver {
  late final ReactionTestCubit _cubit;

  @override
  void initState() {
    super.initState();
    _cubit = context.read<ReactionTestCubit>();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_cubit.load());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed && _cubit.state.isRunning) {
      _cubit.cancelTest();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (_cubit.state.isRunning) _cubit.cancelTest();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<ReactionTestCubit, ReactionTestState>(
      listenWhen: (previous, current) => previous.error != current.error,
      listener: (context, state) {
        if (state.error == null) return;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(state.error!)));
      },
      child: BlocBuilder<ReactionTestCubit, ReactionTestState>(
        builder: (context, state) {
          if (state.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!state.isLoaded) {
            return Center(
              child: FilledButton.icon(
                onPressed: _cubit.load,
                icon: const Icon(Icons.refresh),
                label: const Text('Muat ulang riwayat'),
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
            children: [
              Text(
                'Latihan respons visual selama dua menit.',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 16),
              _buildGame(context, state),
              const SizedBox(height: 16),
              _buildSummary(context, state),
              const SizedBox(height: 24),
              Text('Riwayat', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              if (state.results.isEmpty)
                const Text('Hasil tes yang selesai akan tersimpan di sini.')
              else
                for (final result in state.results) _buildHistoryItem(result),
              const SizedBox(height: 16),
              Text(
                'Skor ini untuk latihan dan tidak menentukan kelayakan atau keselamatan balapan.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildGame(BuildContext context, ReactionTestState state) {
    final colors = Theme.of(context).colorScheme;
    final isReady = state.phase == ReactionTestPhase.ready;
    final isRunning = state.isRunning;
    final elapsedFraction = state.durationMilliseconds == 0
        ? 0.0
        : 1 - state.remainingMilliseconds / state.durationMilliseconds;
    final remainingSeconds = (state.remainingMilliseconds / 1000).ceil();
    final minutes = (remainingSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (remainingSeconds % 60).toString().padLeft(2, '0');
    final arenaColor = isReady
        ? const Color(0xFF1E7B52)
        : isRunning
        ? const Color(0xFFB64B32)
        : colors.surfaceContainerHighest;
    final textColor = isRunning ? Colors.white : colors.onSurface;

    return Column(
      children: [
        Row(
          children: [
            const Icon(Icons.timer_outlined),
            const SizedBox(width: 8),
            Text('$minutes:$seconds'),
            const Spacer(),
            Text('${state.attempts.length} respons'),
          ],
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(value: elapsedFraction.clamp(0.0, 1.0)),
        const SizedBox(height: 20),
        Center(
          child: SizedBox.square(
            dimension: 240,
            child: Material(
              color: arenaColor,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: isRunning ? _cubit.recordResponse : null,
                child: Center(
                  child: Text(
                    _instructionFor(state.phase),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: textColor,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (!isRunning)
          FilledButton.icon(
            onPressed: state.isSaving ? null : _cubit.startTest,
            icon: const Icon(Icons.play_arrow),
            label: Text(
              state.phase == ReactionTestPhase.completed
                  ? 'Ulangi tes'
                  : 'Mulai tes',
            ),
          )
        else
          OutlinedButton.icon(
            onPressed: _cubit.cancelTest,
            icon: const Icon(Icons.close),
            label: const Text('Batalkan tes'),
          ),
      ],
    );
  }

  Widget _buildSummary(BuildContext context, ReactionTestState state) {
    final result = state.latestResult;
    if (result == null) return const SizedBox.shrink();
    final average = result.averageReactionMilliseconds;
    final previous = state.results
        .where((entry) => entry.id != result.id)
        .firstOrNull;
    final previousAverage = previous?.averageReactionMilliseconds;
    final difference = average == null || previousAverage == null
        ? null
        : average - previousAverage;
    final comparison = difference == null
        ? null
        : difference == 0
        ? 'Sama dengan tes sebelumnya.'
        : '${difference.abs()} ms ${difference < 0 ? 'lebih cepat' : 'lebih lambat'} dari tes sebelumnya.';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Hasil tes', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Wrap(
          spacing: 20,
          runSpacing: 8,
          children: [
            _metric('Rata-rata', average == null ? 'Belum ada' : '$average ms'),
            _metric('Respons tepat', '${result.correctCount}'),
            _metric('Terlalu cepat', '${result.earlyCount}'),
          ],
        ),
        if (comparison != null) ...[
          const SizedBox(height: 8),
          Text(comparison),
        ],
        const SizedBox(height: 4),
        Text(
          state.isSaving
              ? 'Menyimpan hasil lokal...'
              : state.error != null
              ? 'Hasil belum tersimpan secara lokal.'
              : 'Tersimpan lokal · sinkronisasi belum aktif',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  Widget _metric(String label, String value) => SizedBox(
    width: 130,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        Text(value, style: Theme.of(context).textTheme.titleMedium),
      ],
    ),
  );

  Widget _buildHistoryItem(ReactionTestResult result) => Card(
    child: ListTile(
      title: Text(
        DateFormat('d MMM yyyy · HH:mm').format(result.completedAt.toLocal()),
      ),
      subtitle: Text(
        '${result.correctCount} tepat · ${result.earlyCount} terlalu cepat · tersimpan lokal',
      ),
      trailing: Text(
        result.averageReactionMilliseconds == null
            ? '—'
            : '${result.averageReactionMilliseconds} ms',
      ),
    ),
  );

  String _instructionFor(ReactionTestPhase phase) => switch (phase) {
    ReactionTestPhase.idle => 'Siap?',
    ReactionTestPhase.waiting => 'Tunggu sinyal',
    ReactionTestPhase.ready => 'KETUK',
    ReactionTestPhase.completed => 'Selesai',
  };
}
