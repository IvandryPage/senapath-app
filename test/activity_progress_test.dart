import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:senapath/core/storage/app_database.dart';
import 'package:senapath/features/progress/data/activity_goals_repository.dart';
import 'package:senapath/features/progress/domain/activity_progress.dart';
import 'package:senapath/features/session/domain/ride_session.dart';

void main() {
  group('ActivityProgressCalculator', () {
    const calculator = ActivityProgressCalculator();
    final now = DateTime(2026, 6, 17, 12);

    test('calculates the current local week and traces source sessions', () {
      final result = calculator.calculate(
        [
          _session('mon', DateTime(2026, 6, 15, 8), 10000, 3600),
          _session('tue', DateTime(2026, 6, 16, 8), 5000, 1800),
          _session('previous', DateTime(2026, 6, 14, 23), 9000, 2400),
          _session(
            'not-completed',
            DateTime(2026, 6, 17, 9),
            9000,
            2400,
            status: RideSessionStatus.paused,
          ),
        ],
        now: now,
        period: ProgressPeriod.week,
      );

      expect(result.startsAt, DateTime(2026, 6, 15));
      expect(result.endsAt, DateTime(2026, 6, 22));
      expect(result.sessionIds, ['mon', 'tue']);
      expect(result.completedSessions, 2);
      expect(result.distanceMeters, 15000);
      expect(result.activeSeconds, 5400);
    });

    test('calculates month-to-date activity and caps goal progress', () {
      final result = calculator.calculate(
        [
          _session('june', DateTime(2026, 6, 1, 1), 30000, 7200),
          _session('may', DateTime(2026, 5, 31, 23), 7000, 1200),
        ],
        now: now,
        period: ProgressPeriod.month,
      );
      const goal = ActivityGoal(
        id: 'goal',
        metric: GoalMetric.distanceMeters,
        target: 20000,
        period: ProgressPeriod.month,
      );

      expect(result.startsAt, DateTime(2026, 6));
      expect(result.endsAt, DateTime(2026, 7));
      expect(result.sessionIds, ['june']);
      expect(result.progressFor(goal), 1);
    });

    test('counts each completed session only once', () {
      final session = _session(
        'duplicate',
        DateTime(2026, 6, 16, 8),
        12000,
        2400,
      );
      final result = calculator.calculate(
        [session, session],
        now: now,
        period: ProgressPeriod.week,
      );

      expect(result.sessionIds, ['duplicate']);
      expect(result.completedSessions, 1);
      expect(result.distanceMeters, 12000);
      expect(result.activeSeconds, 2400);
    });

    test('uses the matching previous calendar period for comparison', () {
      final result = calculator.calculate(
        [
          _session('this-week', DateTime(2026, 6, 16, 8), 8000, 1200),
          _session('last-week', DateTime(2026, 6, 9, 8), 6000, 1000),
        ],
        now: now,
        period: ProgressPeriod.week,
        previousPeriod: true,
      );

      expect(result.startsAt, DateTime(2026, 6, 8));
      expect(result.endsAt, DateTime(2026, 6, 15));
      expect(result.sessionIds, ['last-week']);
      expect(result.distanceMeters, 6000);
    });
  });

  test('persists validated local goals in app preferences', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final goalsRepository = ActivityGoalsRepository(database);
    const goals = [
      ActivityGoal(
        id: 'goal-1',
        metric: GoalMetric.completedSessions,
        target: 3,
        period: ProgressPeriod.week,
      ),
      ActivityGoal(
        id: 'goal-2',
        metric: GoalMetric.distanceMeters,
        target: 25000,
        period: ProgressPeriod.month,
      ),
    ];

    await goalsRepository.save(goals);

    final loaded = await goalsRepository.load();
    expect(
      loaded.map((goal) => goal.toJson()).toList(),
      goals.map((goal) => goal.toJson()).toList(),
    );
  });
}

RideSessionSnapshot _session(
  String id,
  DateTime startedAt,
  double distance,
  int duration, {
  RideSessionStatus status = RideSessionStatus.completed,
}) => RideSessionSnapshot(
  id: id,
  startedAt: startedAt,
  endedAt: startedAt.add(Duration(seconds: duration)),
  status: status,
  totalPausedMilliseconds: 0,
  distanceMeters: distance,
  currentSpeedMetersPerSecond: 0,
);
