import 'package:flutter_test/flutter_test.dart';
import 'package:senapath/features/workouts/domain/interval_workout.dart';

void main() {
  group('WorkoutInterval.create', () {
    test('trims the name and keeps valid values', () {
      final interval = WorkoutInterval.create(
        name: '  Pemanasan  ',
        targetType: WorkoutTargetType.duration,
        targetValue: 300,
      );
      expect(interval.name, 'Pemanasan');
      expect(interval.isRecovery, isFalse);
    });

    test('rejects empty or too-long names', () {
      expect(
        () => WorkoutInterval.create(
          name: '   ',
          targetType: WorkoutTargetType.duration,
          targetValue: 60,
        ),
        throwsArgumentError,
      );
      expect(
        () => WorkoutInterval.create(
          name: 'x' * 41,
          targetType: WorkoutTargetType.duration,
          targetValue: 60,
        ),
        throwsArgumentError,
      );
    });

    test('rejects invalid target values', () {
      expect(
        () => WorkoutInterval.create(
          name: 'Sprint',
          targetType: WorkoutTargetType.duration,
          targetValue: 0,
        ),
        throwsArgumentError,
      );
      expect(
        () => WorkoutInterval.create(
          name: 'Sprint',
          targetType: WorkoutTargetType.duration,
          targetValue: 86401,
        ),
        throwsArgumentError,
      );
      expect(
        () => WorkoutInterval.create(
          name: 'Jarak',
          targetType: WorkoutTargetType.distance,
          targetValue: 1000001,
        ),
        throwsArgumentError,
      );
    });
  });

  group('WorkoutInterval JSON', () {
    test('round-trips through JSON', () {
      final interval = WorkoutInterval.create(
        name: 'Cool down',
        targetType: WorkoutTargetType.distance,
        targetValue: 2000,
        isRecovery: true,
      );
      final restored = WorkoutInterval.fromJson(interval.toJson());
      expect(restored.name, interval.name);
      expect(restored.targetType, interval.targetType);
      expect(restored.targetValue, interval.targetValue);
      expect(restored.isRecovery, isTrue);
    });

    test('rejects unknown target types and non-integer targets', () {
      expect(
        () => WorkoutInterval.fromJson({
          'name': 'Warm up',
          'targetType': 'magic',
          'targetValue': 60,
        }),
        throwsFormatException,
      );
      expect(
        () => WorkoutInterval.fromJson({
          'name': 'Warm up',
          'targetType': 'duration',
          'targetValue': 1.5,
        }),
        throwsFormatException,
      );
      expect(
        () => WorkoutInterval.fromJson({
          'name': 'x' * 60,
          'targetType': 'duration',
          'targetValue': 60,
        }),
        throwsFormatException,
      );
    });

    test('describes targets per type', () {
      expect(
        WorkoutInterval.create(
          name: 'Hold',
          targetType: WorkoutTargetType.duration,
          targetValue: 90,
        ).targetDescription,
        '90s',
      );
      expect(
        WorkoutInterval.create(
          name: 'Spin',
          targetType: WorkoutTargetType.distance,
          targetValue: 1500,
        ).targetDescription,
        '1.50 km',
      );
    });
  });

  group('IntervalWorkout', () {
    test('create validates the name and interval count', () {
      expect(
        () => IntervalWorkout.create(
          id: '',
          name: 'Valid',
          intervals: [
            WorkoutInterval.create(
              name: 'a',
              targetType: WorkoutTargetType.duration,
              targetValue: 10,
            ),
          ],
        ),
        throwsArgumentError,
      );
      expect(
        () => IntervalWorkout.create(id: 'w', name: ' ', intervals: const []),
        throwsArgumentError,
      );
      expect(
        () => IntervalWorkout.create(
          id: 'w',
          name: 'x' * 61,
          intervals: [
            WorkoutInterval.create(
              name: 'a',
              targetType: WorkoutTargetType.duration,
              targetValue: 10,
            ),
          ],
        ),
        throwsArgumentError,
      );
      expect(
        () => IntervalWorkout.create(
          id: 'w',
          name: 'Too many',
          intervals: List.generate(
            31,
            (index) => WorkoutInterval.create(
              name: 'i$index',
              targetType: WorkoutTargetType.duration,
              targetValue: 10,
            ),
          ),
        ),
        throwsArgumentError,
      );
    });

    test('round-trips through JSON preserving cue flags', () {
      final original = IntervalWorkout.create(
        id: 'w1',
        name: 'Threshold',
        intervals: [
          WorkoutInterval.create(
            name: 'Hard',
            targetType: WorkoutTargetType.duration,
            targetValue: 300,
          ),
        ],
        audioCueEnabled: false,
        hapticCueEnabled: false,
        visualCueEnabled: false,
      );

      final restored = IntervalWorkout.fromJson(original.toJson());
      expect(restored.id, 'w1');
      expect(restored.name, 'Threshold');
      expect(restored.intervals, hasLength(1));
      expect(restored.audioCueEnabled, isFalse);
      expect(restored.hapticCueEnabled, isFalse);
      expect(restored.visualCueEnabled, isFalse);
    });

    test('rejects malformed payloads', () {
      expect(
        () => IntervalWorkout.fromJson({'id': 'w', 'name': 'n', 'intervals': 'no'}),
        throwsFormatException,
      );
      expect(
        () => IntervalWorkout.fromJson({
          'id': 'w',
          'name': 'n',
          'intervals': ['not-a-map'],
        }),
        throwsFormatException,
      );
      expect(
        () => IntervalWorkout.fromJson({
          'id': '',
          'name': '',
          'intervals': <Object>[],
        }),
        throwsFormatException,
      );
    });
  });

  group('WorkoutCheckpoint', () {
    test('round-trips through JSON', () {
      const checkpoint = WorkoutCheckpoint(
        sessionId: 's1',
        workoutId: 'w1',
        intervalIndex: 2,
        intervalStartElapsedSeconds: 420,
        intervalStartDistanceMeters: 3210.5,
      );
      final restored = WorkoutCheckpoint.fromJson(checkpoint.toJson());
      expect(restored.sessionId, 's1');
      expect(restored.workoutId, 'w1');
      expect(restored.intervalIndex, 2);
      expect(restored.intervalStartElapsedSeconds, 420);
      expect(restored.intervalStartDistanceMeters, 3210.5);
    });
  });
}
