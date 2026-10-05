import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:senapath/core/storage/app_database.dart';
import 'package:senapath/features/strategy_game/data/strategy_game_repository.dart';
import 'package:senapath/features/strategy_game/domain/strategy_scenario.dart';
import 'package:senapath/features/strategy_game/presentation/strategy_game_cubit.dart';

void main() {
  late AppDatabase database;
  late StrategyGameCubit cubit;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    cubit = StrategyGameCubit(
      StrategyGameRepository(database),
      clock: () => DateTime.utc(2026, 10, 5, 12),
    );
  });

  tearDown(() async {
    await cubit.close();
    await database.close();
  });

  test(
    'records the three scenario choices locally as a completed game',
    () async {
      await cubit.load();
      cubit.startGame();
      expect(cubit.state.isPlaying, isTrue);

      for (var index = 0; index < strategyScenarios.length; index++) {
        cubit.selectOption(strategyScenarios[index].recommendedOption);
        expect(cubit.state.selectedOption, isNotNull);
        await cubit.continueGame();
      }

      expect(cubit.state.phase, StrategyGamePhase.completed);
      expect(cubit.state.results, hasLength(1));
      expect(cubit.state.results.single.score, strategyScenarios.length);

      final restored = await StrategyGameRepository(database).loadRecent();
      expect(restored, hasLength(1));
      expect(restored.single.answers, hasLength(strategyScenarios.length));
      expect(restored.single.score, strategyScenarios.length);
    },
  );

  test('does not save a cancelled or incomplete challenge', () async {
    await cubit.load();
    cubit.startGame();
    cubit.selectOption(0);
    cubit.cancelGame();

    expect(cubit.state.phase, StrategyGamePhase.idle);
    expect(cubit.state.answers, isEmpty);
    expect(await StrategyGameRepository(database).loadRecent(), isEmpty);
  });
}
