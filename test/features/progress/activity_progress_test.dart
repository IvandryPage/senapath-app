import 'package:flutter_test/flutter_test.dart';
import 'package:senapath/features/progress/domain/activity_progress.dart';
import 'package:senapath/features/session/domain/ride_session.dart';

RideSessionSnapshot _session({
  required String id,
  required DateTime startedAt,
  DateTime? endedAt,
  double distanceMeters = 0,
  RideSessionStatus status = RideSessionStatus.completed,
  int pausedMilliseconds = 0,
}) => RideSessionSnapshot(
  id: id,
  startedAt: startedAt,
  endedAt: endedAt,
  status: status,
  totalPausedMilliseconds: pausedMilliseconds,
  distanceMeters: distanceMeters,
  currentSpeedMetersPerSecond: 0,
);

void main() {
  group('ActivityGoal', () {
    test('round-trips through JSON', () {
      const goal = ActivityGoal(
        id: 'g1',
        metric: GoalMetric.distanceMeters,
        target: 50000,
        period: ProgressPeriod.week,
      );
      final restored = ActivityGoal.fromJson(goal.toJson());
      expect(restored.id, 'g1');
      expect(restored.metric, GoalMetric.distanceMeters);
      expect(restored.period, ProgressPeriod.week);
      expect(restored.target, 50000);
    });

    test('rejects non-positive or non-finite targets', () {
      expect(
        () => ActivityGoal.fromJson({
          'id': 'g1',
          'metric': 'completedSessions',
          'target': 0,
          'period': 'week',
        }),
        throwsFormatException,
      );
      expect(
        () => ActivityGoal.fromJson({
          'id': 'g1',
          'metric': 'completedSessions',
          'target': -5,
          'period': 'week',
        }),
        throwsFormatException,
      );
    });
  });

  group('ActivityProgress', () {
    test('reports values and clamped progress', () {
      final progress = ActivityProgress(
        period: ProgressPeriod.week,
        startsAt: DateTime(2026, 1, 5),
        endsAt: DateTime(2026, 1, 12),
        sessionIds: const ['a', 'b'],
        distanceMeters: 30000,
        activeSeconds: 3600,
      );

      expect(progress.completedSessions, 2);
      expect(progress.valueFor(GoalMetric.completedSessions), 2);
      expect(progress.valueFor(GoalMetric.distanceMeters), 30000);
      expect(progress.valueFor(GoalMetric.activeSeconds), 3600);
      expect(
        progress.progressFor(
          const ActivityGoal(
            id: 'g',
            metric: GoalMetric.distanceMeters,
            target: 60000,
            period: ProgressPeriod.week,
          ),
        ),
        0.5,
      );
      expect(
        progress.progressFor(
          const ActivityGoal(
            id: 'g',
            metric: GoalMetric.distanceMeters,
            target: 1000,
            period: ProgressPeriod.week,
          ),
        ),
        1,
        reason: 'progress is clamped to 1',
      );
    });
  });

  group('ActivityProgressCalculator.calculate', () {
    final calculator = ActivityProgressCalculator();
    // Wednesday 2026-01-07, so the current week starts Monday 2026-01-05.
    final now = DateTime(2026, 1, 7, 15);

    test('includes only completed sessions inside the week', () {
      final progress = calculator.calculate(
        [
          _session(
            id: 'in-range',
            startedAt: DateTime(2026, 1, 6, 8),
            distanceMeters: 10000,
            endedAt: DateTime(2026, 1, 6, 9),
          ),
          _session(
            id: 'too-early',
            startedAt: DateTime(2026, 1, 4, 8),
            distanceMeters: 5000,
            endedAt: DateTime(2026, 1, 4, 9),
          ),
          _session(
            id: 'recording',
            startedAt: DateTime(2026, 1, 6, 10),
            status: RideSessionStatus.recording,
          ),
          _session(
            id: 'outside-end',
            startedAt: DateTime(2026, 1, 12, 0),
            distanceMeters: 2000,
            endedAt: DateTime(2026, 1, 12, 1),
          ),
        ],
        now: now,
        period: ProgressPeriod.week,
      );

      expect(progress.startsAt, DateTime(2026, 1, 5));
      expect(progress.endsAt, DateTime(2026, 1, 12));
      expect(progress.sessionIds, ['in-range']);
      expect(progress.distanceMeters, 10000);
      expect(progress.activeSeconds, 3600);
    });

    test('deduplicates sessions that share an id', () {
      final progress = calculator.calculate(
        [
          _session(
            id: 'dup',
            startedAt: DateTime(2026, 1, 6),
            distanceMeters: 1000,
          ),
          _session(
            id: 'dup',
            startedAt: DateTime(2026, 1, 6, 1),
            distanceMeters: 9000,
          ),
        ],
        now: now,
        period: ProgressPeriod.week,
      );

      expect(progress.sessionIds, ['dup']);
      expect(progress.distanceMeters, 1000);
    });

    test('supports the previous week', () {
      final progress = calculator.calculate(
        [
          _session(
            id: 'last-week',
            startedAt: DateTime(2025, 12, 30),
            distanceMeters: 4000,
          ),
          _session(
            id: 'this-week',
            startedAt: DateTime(2026, 1, 6),
            distanceMeters: 1000,
          ),
        ],
        now: now,
        period: ProgressPeriod.week,
        previousPeriod: true,
      );

      expect(progress.startsAt, DateTime(2025, 12, 29));
      expect(progress.sessionIds, ['last-week']);
      expect(progress.distanceMeters, 4000);
    });

    test('supports the current and previous month', () {
      final current = calculator.calculate(
        [
          _session(
            id: 'jan',
            startedAt: DateTime(2026, 1, 2),
            distanceMeters: 7000,
          ),
          _session(
            id: 'feb',
            startedAt: DateTime(2026, 2, 1),
            distanceMeters: 1000,
          ),
        ],
        now: DateTime(2026, 1, 20),
        period: ProgressPeriod.month,
      );
      expect(current.startsAt, DateTime(2026, 1, 1));
      expect(current.endsAt, DateTime(2026, 2, 1));
      expect(current.sessionIds, ['jan']);

      final previous = calculator.calculate(
        [
          _session(
            id: 'dec',
            startedAt: DateTime(2025, 12, 31),
            distanceMeters: 3000,
          ),
          _session(
            id: 'jan',
            startedAt: DateTime(2026, 1, 1),
            distanceMeters: 1000,
          ),
        ],
        now: DateTime(2026, 1, 20),
        period: ProgressPeriod.month,
        previousPeriod: true,
      );
      expect(previous.startsAt, DateTime(2025, 12, 1));
      expect(previous.endsAt, DateTime(2026, 1, 1));
      expect(previous.sessionIds, ['dec']);
    });

    test('subtracts pauses from active time', () {
      final progress = calculator.calculate(
        [
          _session(
            id: 'paused',
            startedAt: DateTime(2026, 1, 6),
            endedAt: DateTime(2026, 1, 6, 1),
            pausedMilliseconds: const Duration(minutes: 10).inMilliseconds,
          ),
        ],
        now: now,
        period: ProgressPeriod.week,
      );
      expect(progress.activeSeconds, 3000);
    });

    test('uses startedAt when the session has no end time', () {
      final progress = calculator.calculate(
        [
          _session(
            id: 'no-end',
            startedAt: DateTime(2026, 1, 6),
            status: RideSessionStatus.paused,
          ),
        ],
        now: now,
        period: ProgressPeriod.week,
      );
      expect(progress.activeSeconds, 0);
    });
  });
}
