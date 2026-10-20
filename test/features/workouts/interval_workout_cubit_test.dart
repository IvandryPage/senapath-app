import 'package:flutter_test/flutter_test.dart';
import 'package:senapath/features/workouts/data/interval_workout_repository.dart';
import 'package:senapath/features/workouts/domain/interval_workout.dart';
import 'package:senapath/features/workouts/presentation/interval_workout_cubit.dart';

import '../../helpers/test_database.dart';

IntervalWorkout workout(String id, String name) => IntervalWorkout.create(
  id: id,
  name: name,
  intervals: [
    WorkoutInterval.create(
      name: 'Block',
      targetType: WorkoutTargetType.duration,
      targetValue: 60,
    ),
  ],
);

void main() {
  group('IntervalWorkoutRepository', () {
    test('returns empty state by default', () async {
      final repository = IntervalWorkoutRepository(createTestDatabase());
      expect(await repository.loadWorkouts(), isEmpty);
      expect(await repository.loadSelectedWorkoutId(), isNull);
      expect(await repository.loadCheckpoint('s1'), isNull);
    });

    test('persists workouts, selection and checkpoints', () async {
      final database = createTestDatabase();
      addTearDown(database.close);
      final repository = IntervalWorkoutRepository(database);

      await repository.saveWorkouts([workout('w1', 'Threshold')]);
      await repository.selectWorkout('w1');
      const checkpoint = WorkoutCheckpoint(
        sessionId: 's1',
        workoutId: 'w1',
        intervalIndex: 0,
        intervalStartElapsedSeconds: 10,
        intervalStartDistanceMeters: 50,
      );
      await repository.saveCheckpoint(checkpoint);

      final fresh = IntervalWorkoutRepository(database);
      final workouts = await fresh.loadWorkouts();
      expect(workouts, hasLength(1));
      expect(workouts.single.name, 'Threshold');
      expect(await fresh.loadSelectedWorkoutId(), 'w1');

      expect((await fresh.loadCheckpoint('s1'))?.intervalIndex, 0);
      expect(await fresh.loadCheckpoint('other'), isNull);

      await fresh.clearCheckpoint();
      expect(await fresh.loadCheckpoint('s1'), isNull);

      await fresh.selectWorkout(null);
      expect(await fresh.loadSelectedWorkoutId(), isNull);
    });
  });

  group('IntervalWorkoutCubit', () {
    test('loads workouts and the selected id', () async {
      final database = createTestDatabase();
      addTearDown(database.close);
      final repository = IntervalWorkoutRepository(database);
      await repository.saveWorkouts([workout('w1', 'Sweet spot')]);
      await repository.selectWorkout('w1');

      final cubit = IntervalWorkoutCubit(repository);
      addTearDown(cubit.close);
      await cubit.load();

      expect(cubit.state.workouts, hasLength(1));
      expect(cubit.state.selectedWorkoutId, 'w1');
      expect(cubit.state.selectedWorkout?.name, 'Sweet spot');
      expect(cubit.state.error, isNull);
    });

    test('clears a stale selection that no longer exists', () async {
      final database = createTestDatabase();
      addTearDown(database.close);
      final repository = IntervalWorkoutRepository(database);
      await repository.saveWorkouts([workout('w1', 'Existing')]);
      await repository.selectWorkout('gone');

      final cubit = IntervalWorkoutCubit(repository);
      addTearDown(cubit.close);
      await cubit.load();

      expect(cubit.state.selectedWorkoutId, isNull);
      expect(await repository.loadSelectedWorkoutId(), isNull);
    });

    test('saves, updates and removes workouts', () async {
      final database = createTestDatabase();
      addTearDown(database.close);
      final cubit = IntervalWorkoutCubit(IntervalWorkoutRepository(database));
      addTearDown(cubit.close);
      await cubit.load();

      await cubit.save(workout('w1', 'First'));
      expect(cubit.state.workouts.map((item) => item.id), ['w1']);

      await cubit.save(workout('w1', 'Renamed'));
      expect(cubit.state.workouts, hasLength(1));
      expect(cubit.state.workouts.single.name, 'Renamed');

      await cubit.select('w1');
      expect(cubit.state.selectedWorkoutId, 'w1');

      await cubit.remove('w1');
      expect(cubit.state.workouts, isEmpty);
      expect(cubit.state.selectedWorkoutId, isNull);
    });

    test('rejects selecting an unknown workout', () async {
      final database = createTestDatabase();
      addTearDown(database.close);
      final cubit = IntervalWorkoutCubit(IntervalWorkoutRepository(database));
      addTearDown(cubit.close);
      await cubit.load();

      expect(() => cubit.select('missing'), throwsArgumentError);
    });
  });
}
