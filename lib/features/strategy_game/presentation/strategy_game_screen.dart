import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../session/domain/ride_session.dart';
import '../../session/presentation/session_cubit.dart';
import '../domain/strategy_scenario.dart';
import 'strategy_game_cubit.dart';

class StrategyGameScreen extends StatefulWidget {
  const StrategyGameScreen({super.key});

  @override
  State<StrategyGameScreen> createState() => _StrategyGameScreenState();
}

class _StrategyGameScreenState extends State<StrategyGameScreen> {
  bool _loaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loaded) return;
    _loaded = true;
    unawaited(context.read<StrategyGameCubit>().load());
    unawaited(context.read<RideSessionCubit>().initialize());
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<StrategyGameCubit, StrategyGameState>(
      listenWhen: (previous, current) => previous.error != current.error,
      listener: (context, state) {
        if (state.error == null) return;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(state.error!)));
      },
      child: BlocBuilder<StrategyGameCubit, StrategyGameState>(
        builder: (context, state) {
          if (state.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          final sessionState = context.watch<RideSessionCubit>().state;
          final session = sessionState.session;
          final isSessionActive =
              !sessionState.isInitialized ||
              session?.status == RideSessionStatus.recording ||
              session?.status == RideSessionStatus.paused;

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
            children: [
              Text(
                'Latihan strategi rute dan balap berbasis skenario. '
                'Mainkan hanya saat sesi tidak merekam atau dijeda.',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 12),
              _buildSafetyNotice(
                context,
                isSessionActive,
                sessionState.isInitialized,
              ),
              const SizedBox(height: 16),
              if (state.isPlaying)
                _buildScenario(context, state)
              else if (state.phase == StrategyGamePhase.completed)
                _buildResult(context, state),
              if (!state.isPlaying) ...[
                const SizedBox(height: 8),
                FilledButton.icon(
                  onPressed: isSessionActive || state.isSaving
                      ? null
                      : context.read<StrategyGameCubit>().startGame,
                  icon: const Icon(Icons.play_arrow),
                  label: Text(
                    state.phase == StrategyGamePhase.completed
                        ? 'Mulai tantangan lagi'
                        : 'Mulai tantangan',
                  ),
                ),
              ],
              const SizedBox(height: 24),
              Text(
                'Riwayat latihan',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              if (state.results.isEmpty)
                const Text(
                  'Skor tantangan selesai akan tersimpan di perangkat.',
                )
              else
                for (final result in state.results.take(20))
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.route_outlined),
                      title: Text(
                        DateFormat('d MMM yyyy · HH:mm')
                            .format(result.playedAt.toLocal()),
                      ),
                      subtitle: const Text(
                        'Simulasi strategi · tersimpan lokal',
                      ),
                      trailing: Text('${result.score}/${result.scenarioCount}'),
                    ),
                  ),
              const SizedBox(height: 12),
              Text(
                'Skenario bersifat edukatif dan tidak mengukur kemampuan fisik, '
                'memberi instruksi real-time, atau menjamin strategi balap.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSafetyNotice(
    BuildContext context,
    bool isSessionActive,
    bool sessionIsInitialized,
  ) => Card(
    color: isSessionActive
        ? Theme.of(context).colorScheme.errorContainer
        : Theme.of(context).colorScheme.secondaryContainer,
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isSessionActive ? Icons.pause_circle_outline : Icons.info_outline,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              isSessionActive
                  ? !sessionIsInitialized
                        ? 'Memeriksa status sesi tersimpan… tantangan '
                              'belum tersedia.'
                        : 'Tantangan tidak tersedia selama sesi merekam '
                              'atau dijeda. Selesaikan sesi dan berhenti '
                              'di tempat aman.'
                  : 'Tidak ada timer atau ketukan cepat. Pertimbangkan '
                        'trade-off setiap pilihan.',
            ),
          ),
        ],
      ),
    ),
  );

  Widget _buildScenario(BuildContext context, StrategyGameState state) {
    final scenario = strategyScenarios[state.scenarioIndex];
    final selected = state.selectedOption;
    final isLast = state.scenarioIndex == strategyScenarios.length - 1;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Skenario ${state.scenarioIndex + 1} dari ${strategyScenarios.length}'
          ' · ${scenario.category}',
          style: Theme.of(context).textTheme.labelLarge,
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value:
              (state.scenarioIndex + (selected == null ? 0 : 1)) /
              strategyScenarios.length,
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  scenario.title,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(scenario.description),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        for (var index = 0; index < scenario.options.length; index++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: OutlinedButton(
              onPressed: selected == null
                  ? () => context.read<StrategyGameCubit>().selectOption(index)
                  : null,
              style: selected == index
                  ? OutlinedButton.styleFrom(
                      backgroundColor: Theme.of(context)
                          .colorScheme
                          .secondaryContainer,
                    )
                  : null,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(scenario.options[index].text),
                ),
              ),
            ),
          ),
        if (selected != null) ...[
          const SizedBox(height: 8),
          _buildAnswerFeedback(context, scenario, selected),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: state.isSaving
                ? null
                : context.read<StrategyGameCubit>().continueGame,
            child: Text(isLast ? 'Lihat hasil' : 'Lanjut'),
          ),
        ],
        TextButton(
          onPressed: context.read<StrategyGameCubit>().cancelGame,
          child: const Text('Akhiri tantangan'),
        ),
      ],
    );
  }

  Widget _buildAnswerFeedback(
    BuildContext context,
    StrategyScenario scenario,
    int selected,
  ) {
    final isRecommended = selected == scenario.recommendedOption;
    return Card(
      color: isRecommended
          ? Theme.of(context).colorScheme.secondaryContainer
          : Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isRecommended ? 'Pilihan terencana' : 'Pertimbangkan trade-off',
            ),
            const SizedBox(height: 4),
            Text(scenario.options[selected].explanation),
            const SizedBox(height: 8),
            Text(
              scenario.takeaway,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResult(BuildContext context, StrategyGameState state) {
    final score = state.answers.where((answer) => answer.wasRecommended).length;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Hasil simulasi',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Pilihan strategis: $score/${strategyScenarios.length}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              state.isSaving
                  ? 'Menyimpan hasil lokal…'
                  : state.error != null
                  ? 'Hasil belum tersimpan.'
                  : 'Tersimpan lokal.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
