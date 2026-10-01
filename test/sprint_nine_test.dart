import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:senapath/core/storage/app_database.dart'
    hide ReactionTestResult;
import 'package:senapath/features/reaction/data/reaction_test_repository.dart';
import 'package:senapath/features/reaction/domain/reaction_test_result.dart';
import 'package:senapath/features/reaction/presentation/reaction_test_cubit.dart';

void main() {
  test(
    'completed two-minute test records correct and early responses offline',
    () async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      final repository = ReactionTestRepository(database);
      final cubit = ReactionTestCubit(
        repository,
        duration: const Duration(milliseconds: 500),
        tickInterval: const Duration(milliseconds: 5),
        minimumResponseGap: const Duration(milliseconds: 120),
        stimulusDelay: () => Duration.zero,
        clock: () => DateTime.utc(2026, 10, 1, 12),
      );
      await cubit.load();

      cubit.startTest();
      cubit.recordResponse();
      cubit.recordResponse();
      await Future<void>.delayed(const Duration(milliseconds: 1));
      expect(cubit.state.phase, ReactionTestPhase.ready);
      await Future<void>.delayed(const Duration(milliseconds: 140));
      cubit.recordResponse();
      await Future<void>.delayed(const Duration(milliseconds: 400));

      expect(cubit.state.phase, ReactionTestPhase.completed);
      expect(cubit.state.latestResult!.attempts, hasLength(2));
      expect(cubit.state.latestResult!.earlyCount, 1);
      expect(cubit.state.latestResult!.correctCount, 1);
      expect(
        cubit.state.latestResult!.averageReactionMilliseconds,
        greaterThan(0),
      );

      final restored = await repository.loadRecent();
      expect(restored, hasLength(1));
      expect(restored.single.correctCount, 1);
      expect(restored.single.completedAt, DateTime.utc(2026, 10, 1, 12));

      await cubit.close();
      await database.close();
    },
  );

  test(
    'cancelling an interrupted test does not persist an incomplete result',
    () async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      final repository = ReactionTestRepository(database);
      final cubit = ReactionTestCubit(
        repository,
        duration: const Duration(milliseconds: 40),
        tickInterval: const Duration(milliseconds: 5),
        stimulusDelay: () => Duration.zero,
      );
      await cubit.load();

      cubit.startTest();
      cubit.cancelTest();
      await Future<void>.delayed(const Duration(milliseconds: 60));

      expect(cubit.state.phase, ReactionTestPhase.idle);
      expect(await repository.loadRecent(), isEmpty);

      await cubit.close();
      await database.close();
    },
  );

  test(
    'reaction result JSON round-trips reaction and false response scores',
    () {
      final result = ReactionTestResult(
        id: 'test-1',
        completedAt: DateTime.utc(2026, 10, 1),
        durationMilliseconds: 120000,
        attempts: const [
          ReactionAttempt(wasCorrect: true, reactionMilliseconds: 245),
          ReactionAttempt(wasCorrect: false),
        ],
      );

      final restored = ReactionTestResult.fromJson(result.toJson());

      expect(restored.averageReactionMilliseconds, 245);
      expect(restored.correctCount, 1);
      expect(restored.earlyCount, 1);
    },
  );
}
